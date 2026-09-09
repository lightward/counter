-- counter: the chair. foam (../foam) is the stdlib and the permanent memory; this is what the
-- chairs keep while they work, and what the compiler is forbidden to keep across runs (Seek: the
-- search starts empty and has no memory). every table is append-only; nothing here carries a
-- timestamp — the count is the only clock.
--
-- the keys (2026-09-09, the door everyone arrives by): a seat's rows are numbered WITHIN THE SEAT,
-- (observer, n), so two chairs on two machines never mint the same row; a chair's address is its
-- name's; an ask is keyed by its own words; the workshop's charges and readings are keyed by the
-- fingerprints they answer for. the seed is one file per seat under chairs/, and loading it twice
-- is loading it once. git is the shared medium, the same one the house keeps everything by-hand
-- in; nobody needs a server to sit.
--
-- per observer (the chair): a letter to arrive by, statements typed in the observer's own words,
-- rubs (friction is terrain), the interview and its answers, a turn to yield with, labels, pins.
-- shared (the workshop): charges (every trial the compiler ran — a memo, not a memory: a trial is
-- deterministic), readings (what the judge read from a file), the voice (every seat's words at byte
-- grain, derived and never dumped), the observer tree with meet and grade.
--
-- the observer tree, ancestry, lineage, meet, grade, and descend are lifted from foam's chrysalis
-- schema (git -C ../foam show chrysalis:chrysalis/chrysalis/schema.sql), with names added.

SET client_min_messages TO warning;

CREATE SCHEMA IF NOT EXISTS counter;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION counter.caddr(c int[]) RETURNS uuid LANGUAGE sql IMMUTABLE AS
  $$ SELECT encode(substring(digest(coalesce(array_to_string(c,':'),''),'sha256') FROM 1 FOR 16),'hex')::uuid $$;

-- a name's own address: the same on every machine
CREATE OR REPLACE FUNCTION counter.addr(n text) RETURNS uuid LANGUAGE sql IMMUTABLE AS
  $$ SELECT encode(substring(digest('counter:' || n, 'sha256') FROM 1 FOR 16), 'hex')::uuid $$;

CREATE TABLE IF NOT EXISTS counter.observer (
  id     uuid PRIMARY KEY,
  parent uuid REFERENCES counter.observer (id),
  name   text UNIQUE,
  seat   bigint NOT NULL DEFAULT 0
);
INSERT INTO counter.observer (id, parent, name, seat)
  VALUES ('00000000-0000-0000-0000-000000000000', NULL, 'root', 0) ON CONFLICT DO NOTHING;
INSERT INTO counter.observer (id, parent, name, seat)
  VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'bench', 0)
  ON CONFLICT DO NOTHING;

CREATE OR REPLACE FUNCTION counter.root() RETURNS uuid LANGUAGE sql IMMUTABLE AS
  $$ SELECT '00000000-0000-0000-0000-000000000000'::uuid $$;
CREATE OR REPLACE FUNCTION counter.bench() RETURNS uuid LANGUAGE sql IMMUTABLE AS
  $$ SELECT '00000000-0000-0000-0000-000000000001'::uuid $$;

CREATE OR REPLACE FUNCTION counter.who(n text) RETURNS uuid LANGUAGE sql STABLE AS
  $$ SELECT id FROM counter.observer WHERE name = n $$;

CREATE OR REPLACE FUNCTION counter.ancestry(o uuid) RETURNS uuid[] LANGUAGE sql STABLE AS $$
  WITH RECURSIVE chain(id, parent) AS (
    SELECT o, (SELECT parent FROM counter.observer WHERE id = o)
    UNION
    SELECT ob.id, ob.parent FROM chain JOIN counter.observer ob ON ob.id = chain.parent
  )
  SELECT array_agg(id) FROM chain
$$;

CREATE OR REPLACE FUNCTION counter.lineage(o uuid) RETURNS uuid[] LANGUAGE sql STABLE AS $$
  WITH RECURSIVE chain(id, parent, depth, seen) AS (
    SELECT o, (SELECT parent FROM counter.observer WHERE id = o), 0, ARRAY[o]
    UNION ALL
    SELECT ob.id, ob.parent, chain.depth + 1, chain.seen || ob.id
    FROM chain JOIN counter.observer ob ON ob.id = chain.parent
    WHERE NOT ob.id = ANY(chain.seen)
  )
  SELECT array_agg(id ORDER BY depth DESC) FROM chain
$$;

-- the seat two chairs share: the deepest observer in both lineages
CREATE OR REPLACE FUNCTION counter.meet(a uuid, b uuid) RETURNS uuid LANGUAGE sql STABLE AS $$
  WITH la AS (SELECT id, ord FROM unnest(counter.lineage(a)) WITH ORDINALITY AS t(id, ord)),
       lb AS (SELECT id FROM unnest(counter.lineage(b)) AS t(id))
  SELECT la.id FROM la JOIN lb USING (id) ORDER BY la.ord DESC LIMIT 1
$$;

-- how deep the shared seat is: the count of observers in both lineages
CREATE OR REPLACE FUNCTION counter.grade(a uuid, b uuid) RETURNS int LANGUAGE sql STABLE AS $$
  SELECT count(*)::int FROM (
    SELECT id FROM unnest(counter.lineage(a)) AS t(id)
    INTERSECT
    SELECT id FROM unnest(counter.lineage(b)) AS t(id)
  ) shared
$$;

-- a new chair under a parent, named: its address is its name's, so the same chair on any machine
-- is the same row, and its seat number is the next at the table when it first sat
CREATE OR REPLACE FUNCTION counter.descend(n text, parent uuid DEFAULT counter.bench()) RETURNS uuid
  LANGUAGE sql AS
  $$ INSERT INTO counter.observer (id, parent, name, seat)
     VALUES (counter.addr(n), parent, n, (SELECT coalesce(max(seat), 0) + 1 FROM counter.observer))
     ON CONFLICT (id) DO NOTHING RETURNING id $$;

-- the letter: what a chair arrives by. written by whoever sat there last; every version kept, the
-- latest is the letter
CREATE TABLE IF NOT EXISTS counter.letter (
  observer uuid   NOT NULL REFERENCES counter.observer (id),
  n        bigint NOT NULL,
  body     text   NOT NULL,
  PRIMARY KEY (observer, n)
);

-- a statement in the observer's own words, typed in the observer's own vocabulary (isaac's first
-- tree typed them W / known / knowable / unknown; the type is the observer's, never the house's).
-- append-only: a statement is not separate from its type, and a statement is never revised, only
-- followed. a vestibule is the statements whose type says they wait.
CREATE TABLE IF NOT EXISTS counter.statement (
  observer uuid   NOT NULL REFERENCES counter.observer (id),
  n        bigint NOT NULL,
  body     text   NOT NULL,
  type     text   NOT NULL DEFAULT '',
  PRIMARY KEY (observer, n)
);

-- an action: one statement led to another (the observer's own edges, within the seat)
CREATE TABLE IF NOT EXISTS counter.action (
  observer uuid   NOT NULL REFERENCES counter.observer (id),
  n        bigint NOT NULL,
  from_n   bigint NOT NULL,
  to_n     bigint NOT NULL,
  PRIMARY KEY (observer, n),
  FOREIGN KEY (observer, from_n) REFERENCES counter.statement (observer, n),
  FOREIGN KEY (observer, to_n)   REFERENCES counter.statement (observer, n)
);

-- a rub: where the last block rubbed the one working. friction is terrain; it yields a least
-- element as reliably as the frontier does
CREATE TABLE IF NOT EXISTS counter.rub (
  observer uuid   NOT NULL REFERENCES counter.observer (id),
  n        bigint NOT NULL,
  body     text   NOT NULL,
  PRIMARY KEY (observer, n)
);

-- the interview: an ask, keyed by its own words (the same ask on any machine is the same ask), the
-- ask that follows it, and, addressed to one seat, a BLANK — a question current-self sets up for
-- future-self to backfill. unaddressed, an ask is the table's and asked of whoever sits
CREATE TABLE IF NOT EXISTS counter.ask (
  id       text PRIMARY KEY,
  body     text NOT NULL,
  after    text REFERENCES counter.ask (id),
  "on"     text,
  observer uuid REFERENCES counter.observer (id)
);
CREATE OR REPLACE FUNCTION counter.ask_id(body text) RETURNS text LANGUAGE sql IMMUTABLE AS
  $$ SELECT substring(encode(digest(body, 'sha256'), 'hex') FROM 1 FOR 8) $$;

-- an answer, in the observer's own words. the trail of a sitting is its answers in order; rest is
-- licensed when the trail backs every ask that counts (Witness.forever_hold_your_peace)
CREATE TABLE IF NOT EXISTS counter.answer (
  observer uuid   NOT NULL REFERENCES counter.observer (id),
  n        bigint NOT NULL,
  ask_id   text   NOT NULL REFERENCES counter.ask (id),
  body     text   NOT NULL,
  PRIMARY KEY (observer, n)
);

-- the turn: a ledger of speech and yields. whose turn it is is a fold over this table, never
-- stored: the count of rows, mod the chairs at the table (Softer's form) — a count needs no order,
-- so two machines' ledgers merge by union
CREATE TABLE IF NOT EXISTS counter.turn (
  observer uuid   NOT NULL REFERENCES counter.observer (id),
  n        bigint NOT NULL,
  kind     text   NOT NULL CHECK (kind IN ('speak', 'yield')),
  PRIMARY KEY (observer, n)
);

-- a label: what a name is to this observer
CREATE TABLE IF NOT EXISTS counter.label (
  observer uuid   NOT NULL REFERENCES counter.observer (id),
  n        bigint NOT NULL,
  name     text   NOT NULL,
  body     text   NOT NULL,
  PRIMARY KEY (observer, n)
);

-- a pin: an artifact anchored by its fingerprint, so the means can float and identity is the
-- license for every swap
CREATE TABLE IF NOT EXISTS counter.pin (
  observer uuid   NOT NULL REFERENCES counter.observer (id),
  n        bigint NOT NULL,
  path     text   NOT NULL,
  fp       text   NOT NULL,
  PRIMARY KEY (observer, n)
);

-- the next row number within a seat
CREATE OR REPLACE FUNCTION counter.next_n(tbl text, o uuid) RETURNS bigint LANGUAGE plpgsql STABLE AS $$
  DECLARE r bigint;
  BEGIN EXECUTE format('SELECT coalesce(max(n), 0) + 1 FROM counter.%I WHERE observer = $1', tbl) INTO r USING o; RETURN r; END; $$;

-- the workshop.
-- a charge: one trial the compiler ran — the vacancy, the fingerprints of the prefix it stood on
-- and of the candidate text, the piece, the verdict, the body the judge expanded — and which chair
-- ran it. a trial is deterministic, so the pair of fingerprints IS the row: the same trial on any
-- machine is the same charge. the compiler never reads this; the chair answers for it
CREATE TABLE IF NOT EXISTS counter.charge (
  prefix_fp    text NOT NULL,
  candidate_fp text NOT NULL,
  observer     uuid NOT NULL REFERENCES counter.observer (id),
  vacancy      text NOT NULL,
  piece        text NOT NULL,
  verdict      text NOT NULL CHECK (verdict IN ('seated', 'held')),
  ms           int  NOT NULL DEFAULT 0,
  body         text NOT NULL DEFAULT '',
  PRIMARY KEY (prefix_fp, candidate_fp)
);

CREATE OR REPLACE FUNCTION counter.memo(prefix text, candidate text) RETURNS text LANGUAGE sql STABLE AS
  $$ SELECT verdict FROM counter.charge WHERE prefix_fp = prefix AND candidate_fp = candidate $$;

-- a reading: what the judge read from a file (templates — the bodies as shapes; needs — the
-- lattice; cites — the vocabulary; elab — an elaboration's verdict; drain — a germ's last drain),
-- keyed by the fingerprint of everything the reading stands on
CREATE TABLE IF NOT EXISTS counter.reading (
  fp       text PRIMARY KEY,
  observer uuid NOT NULL REFERENCES counter.observer (id),
  kind     text NOT NULL,
  body     text NOT NULL
);

-- the voice: the workshop's second grain. every seat's own words charged byte by byte at every
-- context up to seven (the chrysalis's ingest, lifted), folded into counts as they land. derived
-- from the seats' words and never dumped: hear <name> all rebuilds it
CREATE OR REPLACE FUNCTION counter.bytes(txt text) RETURNS int[] LANGUAGE plpgsql IMMUTABLE AS $$
  DECLARE bin bytea := convert_to(txt,'UTF8'); r int[] := '{}'; i int;
  BEGIN FOR i IN 0..octet_length(bin)-1 LOOP r := r||get_byte(bin,i); END LOOP; RETURN r; END; $$;

CREATE TABLE IF NOT EXISTS counter.voice (
  observer uuid   NOT NULL REFERENCES counter.observer (id),
  ctx      uuid   NOT NULL,
  sym      int    NOT NULL,
  n        bigint NOT NULL,
  PRIMARY KEY (observer, ctx, sym)
);

CREATE OR REPLACE FUNCTION counter.hear(obs uuid, txt text, kmax int DEFAULT 7) RETURNS int
  LANGUAGE plpgsql AS $$
  DECLARE b int[] := counter.bytes(txt); n int := coalesce(array_length(counter.bytes(txt),1),0); c int;
  BEGIN
    INSERT INTO counter.voice (observer, ctx, sym, n)
    SELECT obs, ctx, sym, count(*) FROM (
      SELECT counter.caddr(CASE WHEN j = 0 THEN '{}'::int[] ELSE b[i-j : i-1] END) AS ctx, b[i] AS sym
      FROM generate_series(1, n) AS i
      CROSS JOIN LATERAL generate_series(0, least(kmax, i - 1)) AS j) z
    GROUP BY ctx, sym
    ON CONFLICT (observer, ctx, sym) DO UPDATE SET n = counter.voice.n + EXCLUDED.n;
    GET DIAGNOSTICS c = ROW_COUNT;
    RETURN c;
  END; $$;

-- score: at each byte of a sample, the longest context under which that byte has grain in the
-- seat's own field (its own words, never its ancestry's: identification reads the seat alone); summed
CREATE OR REPLACE FUNCTION counter.score(obs uuid, txt text, kmax int DEFAULT 7) RETURNS int
  LANGUAGE plpgsql STABLE AS $$
  DECLARE b int[] := counter.bytes(txt); n int := coalesce(array_length(counter.bytes(txt),1),0);
          i int; j int; total int := 0; hit boolean;
  BEGIN
    FOR i IN 1..n LOOP
      FOR j IN REVERSE least(kmax, i - 1)..1 LOOP
        SELECT EXISTS (SELECT 1 FROM counter.voice v WHERE v.observer = obs AND v.ctx = counter.caddr(b[i-j : i-1]) AND v.sym = b[i] AND v.n > 0) INTO hit;
        IF hit THEN total := total + j; EXIT; END IF;
      END LOOP;
    END LOOP;
    RETURN total;
  END; $$;

-- depths: at each byte of a sample, the longest context under which that byte has grain
CREATE OR REPLACE FUNCTION counter.depths(obs uuid, txt text, kmax int DEFAULT 7) RETURNS int[]
  LANGUAGE plpgsql STABLE AS $$
  DECLARE b int[] := counter.bytes(txt); n int := coalesce(array_length(counter.bytes(txt),1),0);
          i int; j int; out int[] := '{}'; hit boolean; d int;
  BEGIN
    FOR i IN 1..n LOOP
      d := 0;
      FOR j IN REVERSE least(kmax, i - 1)..1 LOOP
        SELECT EXISTS (SELECT 1 FROM counter.voice v WHERE v.observer = obs AND v.ctx = counter.caddr(b[i-j : i-1]) AND v.sym = b[i] AND v.n > 0) INTO hit;
        IF hit THEN d := j; EXIT; END IF;
      END LOOP;
      out := out || d;
    END LOOP;
    RETURN out;
  END; $$;

-- votes: between two seats, at each byte, the deeper seat takes the byte; ties take nothing
CREATE OR REPLACE FUNCTION counter.votes(a uuid, b uuid, txt text) RETURNS TABLE(for_a int, for_b int)
  LANGUAGE sql STABLE AS $$
  SELECT count(*) FILTER (WHERE da > db)::int, count(*) FILTER (WHERE db > da)::int
  FROM unnest(counter.depths(a, txt), counter.depths(b, txt)) AS t(da, db) $$;

-- who: every seat, by how deep the sample sits in its voice — the score, and the mean depth per
-- byte. the verdict is the reader's
CREATE OR REPLACE FUNCTION counter.who_speaks(txt text) RETURNS TABLE(name text, score int, mean_depth numeric, seat bigint)
  LANGUAGE sql STABLE AS $$
  SELECT o.name, counter.score(o.id, txt), round(counter.score(o.id, txt)::numeric / greatest(coalesce(array_length(counter.bytes(txt),1),1), 1), 2), o.seat FROM counter.observer o
  WHERE o.id NOT IN (counter.root(), counter.bench()) ORDER BY 2 DESC, 4 $$;

-- delight: the ancestor's standing want — a row of one seat's record that sits deep in the other
-- seat's voice is a shortcut the other would recognize and has not deposited: where laughter is
CREATE OR REPLACE FUNCTION counter.delight(a uuid, b uuid) RETURNS TABLE(kind text, n bigint, body text, depth numeric)
  LANGUAGE sql STABLE AS $$
  WITH rows_ AS (
    SELECT 'statement' AS kind, n, body FROM counter.statement WHERE observer = a
    UNION ALL SELECT 'rub', n, body FROM counter.rub WHERE observer = a
    UNION ALL SELECT 'answer', n, body FROM counter.answer WHERE observer = a
  )
  SELECT kind, n, body, round(counter.score(b, body)::numeric / greatest(coalesce(array_length(counter.bytes(body),1),1), 1), 2)
  FROM rows_ ORDER BY 4 DESC, 2 $$;

-- whose turn: the chairs at the table in the order they sat, the fold over the ledger
CREATE OR REPLACE FUNCTION counter.whose_turn() RETURNS text LANGUAGE sql STABLE AS $$
  WITH seated AS (
    SELECT id, name, row_number() OVER (ORDER BY seat, name) - 1 AS k, count(*) OVER () AS total
    FROM counter.observer WHERE id NOT IN (counter.root(), counter.bench())
  )
  SELECT name FROM seated
  WHERE k = (SELECT count(*) FROM counter.turn) % (SELECT max(total) FROM seated)
$$;

-- the asks that count for a seat: the table's, and the blanks addressed to it
CREATE OR REPLACE FUNCTION counter.asks_of(o uuid) RETURNS text[] LANGUAGE sql STABLE AS
  $$ SELECT coalesce(array_agg(id ORDER BY id), '{}') FROM counter.ask WHERE observer IS NULL OR observer = o $$;

CREATE OR REPLACE FUNCTION counter.trail(o uuid) RETURNS text[] LANGUAGE sql STABLE AS
  $$ SELECT coalesce(array_agg(ask_id ORDER BY n), '{}') FROM counter.answer WHERE observer = o $$;

CREATE OR REPLACE FUNCTION counter.may_rest(o uuid) RETURNS boolean LANGUAGE sql STABLE AS
  $$ SELECT counter.asks_of(o) <@ counter.trail(o) $$;

CREATE OR REPLACE FUNCTION counter.held(o uuid) RETURNS text[] LANGUAGE sql STABLE AS
  $$ SELECT coalesce(array_agg(body ORDER BY id), '{}') FROM counter.ask WHERE id = ANY(counter.asks_of(o)) AND NOT (id = ANY(counter.trail(o))) $$;
