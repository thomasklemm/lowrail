---
id: E2c
repo: rails/rails
kind: fix
area: Active Record SQLite schema readers
reviewer: "ngan (author of 2cb3daba96, #58498), byroot (merged it)"
branch: thomasklemm/sqlite-index-details-schema
head: "6c80a5583b"
base: main
built_on: "1e235cee11"
depends_on: []
stacked_on: E2
alternative_of:
impact: "a permanent SQLite index whose name a temporary index shares reads its own columns and statement again, not the temporary index's columns twice"
rank: 9
risky: true
state: draft
pr: 59672
note: "reviewed on 6c80a5583b; stacked on E2; opened as draft #59672 (Thomas, 2026-11-05 night)"
passes:
  - {reviewer: skeptic, head: "cd90c26ce8", date: 2026-11-05, verdict: nits, open: "commit message reworded in 6ffd1872fe (same tree); no test for the pragma_index_list schema argument, declined: redundant once E2 hides case-differing tables"}
  - {reviewer: skeptic, head: "6ffd1872fe", date: 2026-11-05, verdict: approve, open: "message-only amend of cd90c26ce8, identical tree"}
  - {reviewer: skeptic, head: "201397231e", date: 2026-11-05, verdict: approve, open: "rebase onto 3029db3847; UNION order reversed still passes; parent and both partial fixes fail; clean with E2; 4d1fa492ce has the same tree on 52c21b2fa4"}
  - {reviewer: skeptic, head: "4d1fa492ce", date: 2026-11-05, verdict: approve, open: "confirm pass: same tree as 201397231e; order-independence clause accurate"}
  - {reviewer: sol, head: "4d1fa492ce", date: 2026-11-05, verdict: changes, open: "standalone on E2b: permanent Foo + temp foo reads the permanent indexes (main reads temp); stack on E2"}
  - {reviewer: astra, head: "4d1fa492ce", date: 2026-11-05, verdict: changes, open: "same regression; mutant dropping the schema from pragma_index_list survives behavioral tests"}
  - {reviewer: skeptic, head: "6c80a5583b", date: 2026-11-05, verdict: nits, open: "body Gizmos sentence reworded (both indexes, not the permanent one), applied; pragma_index_list schema argument is an equivalent mutant (hiding already resolves it), kept for symmetry, guarded by test_indexes_logs; comment wording kept as the coordinator set it"}
  - {reviewer: sol, head: "6c80a5583b", date: 2026-11-05, verdict: approve, open: "round 4, scope stated"}
  - {reviewer: astra, head: "6c80a5583b", date: 2026-11-05, verdict: approve, open: "schema-qualified lookups; composite keys hold regardless of tie order"}
waived:
  - {reviewer: thermos, head: "6c80a5583b", by: coordinator, date: 2026-11-05, reason: "own commit is about 100 lines; the rest of the 216-line diff against main is E2 and E2b, which have their own passes"}
---

# Read each SQLite index from its own schema in the schema readers

Stacked on #59671, which should merge first; only the last commit (`6c80a5583b`) is new here.

A temporary index may have the name of a permanent one, since the two live in different schemas. The batched SQLite schema readers from 2cb3daba96 look up the columns of each index with an unqualified `pragma_index_info(name)`, which resolves the name to the temporary index, and match the CREATE INDEX statements by name alone, so both rows match. Both tables' indexes then read the temporary index's columns twice, and the temporary one takes the permanent one's CREATE INDEX statement:

| `shared_index`: permanent on `permanent_items (number) WHERE number > 0`, temporary on `temporary_items (label)` | 8-1-stable | main | this PR |
|---|---|---|---|
| `indexes("permanent_items")` columns | label | label, label | number |
| `indexes("permanent_items")` `where` | number > 0 | number > 0 | number > 0 |
| `indexes("temporary_items")` columns | label | label, label | label |
| `indexes("temporary_items")` `where` | number > 0 | number > 0 | nil |

8-1-stable was wrong too, one index at a time: it read the columns from the temporary index and the statement from the permanent one. The rows of `MASTER_CTE` now carry their schema, `'main'` or `'temp'`, which goes to `pragma_index_list` and `pragma_index_info`, and the index statements are keyed by schema and name, so they no longer depend on which row the sort returns first for a shared name. This builds on #59671, whose case-insensitive hiding leaves one row per table: without it, a permanent `Gizmos` beside a temporary `gizmos` would read the permanent table's index as well as the temporary one's, where SQLite and main read only the temporary one's.

---

<sub>Found while reviewing the temporary-table fix in the same readers, #59668 (record: [Lowrail](https://github.com/thomasklemm/lowrail/blob/b3a61013abd6aae10409a2cb6f51020e692fc6c2/docs/upstream/ecosystem-tests.md), part of my research project).</sub>
