-- counter: the chair. foam (../foam) is the stdlib and the permanent memory; this is what the
-- chairs keep while they work, and what the compiler is forbidden to keep across runs (Seek: the
-- search starts empty and has no memory). every table is append-only; nothing here carries a
-- timestamp — the id is the order, and the count is the only clock.
--
-- per observer (the chair): a letter to arrive by, statements typed in the observer's own words,
-- rubs (friction is terrain), the interview and its answers, a turn to yield with, labels.
-- shared (the workshop): charges (every trial the compiler ran, keyed by the fingerprints of its
-- inputs — a memo, not a memory: a trial is deterministic), pins (artifacts anchored so the means
-- can float), pieces (bodies rendered as shapes, once per scope), the observer tree with meet and
-- grade (the seat two chairs share, and how deep).
--
-- the observer tree, ancestry, lineage, meet, grade, and descend are lifted from foam's chrysalis
-- schema (git -C ../foam show chrysalis:chrysalis/chrysalis/schema.sql), with names added.

SET client_min_messages TO warning;

CREATE SCHEMA IF NOT EXISTS counter;

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS counter.observer (
  id     uuid PRIMARY KEY,
  parent uuid REFERENCES counter.observer (id),
  name   text UNIQUE,
  seat   bigserial
);
INSERT INTO counter.observer (id, parent, name)
  VALUES ('00000000-0000-0000-0000-000000000000', NULL, 'root') ON CONFLICT DO NOTHING;
INSERT INTO counter.observer (id, parent, name)
  VALUES ('00000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000000', 'bench')
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

-- a new chair under a parent, named
CREATE OR REPLACE FUNCTION counter.descend(n text, parent uuid DEFAULT counter.bench()) RETURNS uuid
  LANGUAGE sql AS
  $$ INSERT INTO counter.observer (id, parent, name) VALUES (gen_random_uuid(), parent, n)
     RETURNING id $$;

-- the letter: what a chair arrives by. written by whoever sat there last; every version kept, the
-- latest is the letter
CREATE TABLE IF NOT EXISTS counter.letter (
  id       bigserial PRIMARY KEY,
  observer uuid NOT NULL REFERENCES counter.observer (id),
  body     text NOT NULL
);

-- a statement in the observer's own words, typed in the observer's own vocabulary (isaac's first
-- tree typed them W / known / knowable / unknown; the type is the observer's, never the house's).
-- append-only: a statement is not separate from its type, and a statement is never revised, only
-- followed. a vestibule is the statements whose type says they wait.
CREATE TABLE IF NOT EXISTS counter.statement (
  id       bigserial PRIMARY KEY,
  observer uuid NOT NULL REFERENCES counter.observer (id),
  body     text NOT NULL,
  type     text NOT NULL DEFAULT ''
);

-- an action: one statement led to another (the observer's own edges)
CREATE TABLE IF NOT EXISTS counter.action (
  id        bigserial PRIMARY KEY,
  observer  uuid   NOT NULL REFERENCES counter.observer (id),
  from_id   bigint NOT NULL REFERENCES counter.statement (id),
  to_id     bigint NOT NULL REFERENCES counter.statement (id)
);

-- a rub: where the last block rubbed the one working. friction is terrain; it yields a least
-- element as reliably as the frontier does
CREATE TABLE IF NOT EXISTS counter.rub (
  id       bigserial PRIMARY KEY,
  observer uuid NOT NULL REFERENCES counter.observer (id),
  body     text NOT NULL
);

-- the interview: an ask, and the ask that follows it. a recital when `after` chains them; a door
-- when two asks follow one, each `on` an answer. asked of whoever sits, face-blind
CREATE TABLE IF NOT EXISTS counter.ask (
  id    bigserial PRIMARY KEY,
  body  text NOT NULL,
  after bigint REFERENCES counter.ask (id),
  "on"  text
);

-- an answer, in the observer's own words. the trail of a sitting is its answers in order; rest is
-- licensed when the trail backs every ask that counts (Witness.forever_hold_your_peace)
CREATE TABLE IF NOT EXISTS counter.answer (
  id       bigserial PRIMARY KEY,
  observer uuid   NOT NULL REFERENCES counter.observer (id),
  ask_id   bigint NOT NULL REFERENCES counter.ask (id),
  body     text   NOT NULL
);

-- the turn: a ledger of speech and yields. whose turn it is is a fold over this table, never
-- stored (Softer's form: the count of turn-consuming rows, mod the chairs at the table)
CREATE TABLE IF NOT EXISTS counter.turn (
  id       bigserial PRIMARY KEY,
  observer uuid NOT NULL REFERENCES counter.observer (id),
  kind     text NOT NULL CHECK (kind IN ('speak', 'yield'))
);

-- a label: what a name is to this observer
CREATE TABLE IF NOT EXISTS counter.label (
  id       bigserial PRIMARY KEY,
  observer uuid NOT NULL REFERENCES counter.observer (id),
  name     text NOT NULL,
  body     text NOT NULL
);

-- the workshop.
-- a charge: one trial the compiler ran — the vacancy, the fingerprints of the prefix it stood on
-- and of the candidate text, the piece, the verdict, the milliseconds — and which chair ran it.
-- a trial is deterministic, so the pair of fingerprints is a memo: the same inputs give the same
-- verdict on any machine. the compiler never reads this; the chair answers for it
CREATE TABLE IF NOT EXISTS counter.charge (
  id           bigserial PRIMARY KEY,
  observer     uuid NOT NULL REFERENCES counter.observer (id),
  vacancy      text NOT NULL,
  prefix_fp    text NOT NULL,
  candidate_fp text NOT NULL,
  piece        text NOT NULL,
  verdict      text NOT NULL CHECK (verdict IN ('seated', 'held')),
  ms           int  NOT NULL DEFAULT 0,
  body         text NOT NULL DEFAULT ''
);
ALTER TABLE counter.charge ADD COLUMN IF NOT EXISTS body text NOT NULL DEFAULT '';
CREATE INDEX IF NOT EXISTS counter_charge_memo ON counter.charge (prefix_fp, candidate_fp);

CREATE OR REPLACE FUNCTION counter.memo(prefix text, candidate text) RETURNS text LANGUAGE sql STABLE AS
  $$ SELECT verdict FROM counter.charge WHERE prefix_fp = prefix AND candidate_fp = candidate ORDER BY id DESC LIMIT 1 $$;

-- a pin: an artifact anchored by its fingerprint, so the means can float and identity is the
-- license for every swap
CREATE TABLE IF NOT EXISTS counter.pin (
  id       bigserial PRIMARY KEY,
  observer uuid NOT NULL REFERENCES counter.observer (id),
  path     text NOT NULL,
  fp       text NOT NULL
);

-- a reading: what the judge read from a file (templates — the bodies as shapes; needs — the
-- lattice; cites — the vocabulary), keyed by the fingerprint of everything the reading stands on.
-- a reading is deterministic, so the chair answers for it
CREATE TABLE IF NOT EXISTS counter.reading (
  id       bigserial PRIMARY KEY,
  observer uuid NOT NULL REFERENCES counter.observer (id),
  kind     text NOT NULL,
  fp       text NOT NULL,
  body     text NOT NULL
);
CREATE INDEX IF NOT EXISTS counter_reading_fp ON counter.reading (fp);

-- whose turn: the chairs at the table in the order they sat, the fold over the ledger
CREATE OR REPLACE FUNCTION counter.whose_turn() RETURNS text LANGUAGE sql STABLE AS $$
  WITH seated AS (
    SELECT id, name, row_number() OVER (ORDER BY seat) - 1 AS seat, count(*) OVER () AS n
    FROM counter.observer WHERE id NOT IN (counter.root(), counter.bench())
  )
  SELECT name FROM seated
  WHERE seat = (SELECT count(*) FROM counter.turn) % (SELECT max(n) FROM seated)
$$;

-- the trail of a sitting: the asks answered, in order; rest: whether it backs the asks that count
CREATE OR REPLACE FUNCTION counter.trail(o uuid) RETURNS bigint[] LANGUAGE sql STABLE AS
  $$ SELECT coalesce(array_agg(ask_id ORDER BY id), '{}') FROM counter.answer WHERE observer = o $$;

CREATE OR REPLACE FUNCTION counter.may_rest(o uuid) RETURNS boolean LANGUAGE sql STABLE AS
  $$ SELECT (SELECT coalesce(array_agg(id), '{}') FROM counter.ask) <@ counter.trail(o) $$;

CREATE OR REPLACE FUNCTION counter.held(o uuid) RETURNS text[] LANGUAGE sql STABLE AS
  $$ SELECT coalesce(array_agg(body ORDER BY id), '{}') FROM counter.ask WHERE NOT (id = ANY(counter.trail(o))) $$;
