# counter

a chair, plural.

foam (`../foam`, [foam.is](https://foam.is)) is a type system holding itself together under measurement: a trunk of theorems about rooms, faces, and seats, every one axiom-free, grown by a compiler that keeps no memory across runs. foam says where the seats are. counter puts a chair at one.

the chair is for anyone that cycles: whoever arrives by rehydration, works a while, and leaves their route behind. a human after sleep. an AI at the start of a session. what counts for you, and after counting what may you rest — made tractable, accounting for your own measurement.

## what a chair keeps

per observer, append-only, no timestamps (the id is the order; the count is the only clock):

- **a letter** to arrive by. written by whoever sat there last, for whoever sits next.
- **statements**, in the observer's own words, typed in the observer's own vocabulary. never revised, only followed. the ones whose type says they wait are the vestibule.
- **rubs**: where the last block rubbed the one working. friction is terrain.
- **the interview**: asks, and answers in the observer's own words. the trail of a sitting is its answers in order; rest is licensed when the trail backs every ask that counts. asked of whoever sits, face-blind.
- **a turn**, to speak or to yield with. whose turn it is is a fold over the ledger, never stored.
- **labels**: what a name is to this observer.

shared, the workshop:

- **charges**: every trial foam's compiler ran, keyed by the fingerprints of its inputs. a trial is deterministic, so the pair of fingerprints is a memo, not a memory. the compiler never reads it; the chair answers for it.
- **pins**: artifacts anchored by fingerprint, so the means can float. identity is the license for every swap.
- **pieces**: bodies rendered as shapes, once per scope.
- **the observer tree**, with `meet` and `grade`: the seat two chairs share, and how deep.

## the verbs

```
bin/chair init                          the database and its schema (Postgres; PGSOCK, PGPORT, PGUSER as foam's treaty)
bin/chair sit <name> [parent]           a chair under a parent; prints its letter
bin/chair letter <name> [write < file]  read the letter, or write a new version
bin/chair say <name> <type> <text>      a statement
bin/chair link <name> <from> <to>       an action between two statements
bin/chair rub <name> <text>             a rub
bin/chair ask <text> [after <id>]       an ask in the interview
bin/chair sit-down <name>               the interview, answers from stdin
bin/chair speak|yield <name>            a turn taken or passed
bin/chair pin <name> <paths>            anchor artifacts
bin/chair meet <a> <b>                  the shared seat and its grade
bin/chair book [name]                   everything about a chair, or the table
bin/chair chart [name]                  statements and actions as mermaid
```

## the form it stands on

the observer tree and its readings are lifted from foam's chrysalis schema (`git -C ../foam show chrysalis:chrysalis/chrysalis/schema.sql`), where a mind is a ledger of charges with a sweep, and speaking spends. the interview, the trail, and rest by coverage are foam's `assays/cycle.lean`, isaac's answers as the first cast. the turn as a fold over a ledger is Softer's. the letter as arrival is foam's own `CLAUDE.md`, by-fable-for-fable, generalized to any seat.

the first tree of this repo (a product tree in prose, eleven flights) and the second (isaac's twenty-five statements, typed W / known / knowable / unknown, with his chart) stand whole in the history. the statements came along as the first chair's record.

UNLICENSE. leaving is free from every state you can observe yourself into.
