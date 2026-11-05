---
id: E2b
repo: rails/rails
kind: fix
area: Active Record SQLite schema readers
reviewer: "ngan (author of 2cb3daba96, #58498), byroot (merged it)"
branch: thomasklemm/sqlite-schema-readers-temp-shadowing
head: "bc90b487f2"
base: main
built_on: "1e235cee11"
depends_on: []
stacked_on:
alternative_of:
impact: "a temporary SQLite table or view hides the permanent one again: columns and indexes no longer duplicated, primary key no longer composite"
rank: 5
risky: false
state: draft
pr: 59668
note: "opened as draft 2026-11-05; round 3 on main 1e235cee11: tie-order where assertion dropped, permanent-view hiding test, check-constraint assertion; body via REST; E2 stacked on it, E2c on E2"
passes:
  - {reviewer: sol, head: "472c680d15", date: 2026-11-05, verdict: nits, open: applied}
  - {reviewer: sol, head: "472c680d15", date: 2026-11-05, verdict: approve, open: "20:07, no must-fix; body nit applied before opening"}
  - {reviewer: skeptic, head: "472c680d15", date: 2026-11-05, verdict: changes, open: "must-fix: sqlite_temp_master first makes index_details read a same-named temp index CREATE, so the permanent index loses where: (main keeps it); fix: keep sqlite_master first. Follow-up: pragma_index_info still resolves temp first (columns doubled, from 2cb3daba96). Nit: check constraints etc. also come from the temp CREATE, not only collation"}
  - {reviewer: skeptic, head: "3029db3847", date: 2026-11-05, verdict: nits, open: "no must-fix; comment overstated the sort order (ties unordered with PRAGMA threads > 0, main equally exposed), reworded in 52c21b2fa4; check constraints, auto-increment and generated columns from the temp CREATE confirmed and named in the body"}
  - {reviewer: skeptic, head: "52c21b2fa4", date: 2026-11-05, verdict: approve, open: "confirm pass: comment-only delta accurate; posted body checked (temp index sentence, check constraints, auto-increment, generated columns)"}
  - {reviewer: sol, head: "52c21b2fa4", date: 2026-11-05, verdict: changes, open: "partial-index where assertion depends on sort tie order; comment claims a guarantee; check constraints sentence untested"}
  - {reviewer: astra, head: "52c21b2fa4", date: 2026-11-05, verdict: changes, open: "type != 'table' mutant passes (permanent views not hidden); fixed in bc90b487f2"}
  - {reviewer: skeptic, head: "bc90b487f2", date: 2026-11-05, verdict: approve, open: "no tie-order assertion left; type != 'table' mutant and permanent-wins mutant fail; posted body checked"}
---

# Let a temporary SQLite table or view hide a permanent one in the schema readers

The batched SQLite schema readers from 2cb3daba96 join each pragma to a list of `sqlite_master` and `sqlite_temp_master` rows. When a temporary table has the same name as a permanent one, both rows match, and the pragmas resolve both to the temporary table, as SQLite does. So columns and indexes are duplicated, and the primary key becomes composite:

| `shadowed`: permanent `(id, number)`, temporary `(temp_id, temp_name COLLATE NOCASE)` | 8-1-stable | main | this PR |
|---|---|---|---|
| `columns` | temp_id, temp_name | temp_id, temp_id, temp_name, temp_name | temp_id, temp_name |
| `primary_key` | temp_id | ["temp_id", "temp_id"] | temp_id |
| `indexes` | 1 | 2 (the same index twice) | 1 |
| `temp_name` collation | nil | nil | NOCASE |

The list now takes a permanent table or view only when no temporary table or view has its name, which is how SQLite resolves identically spelled names. Temporary indexes and triggers don't take part, so they hide no table or view. A temporary index that shares a permanent index's name still gives its columns, twice, to the permanent one, as on main; that is a separate fix. The collation row goes beyond 8-1-stable, which read the columns from the temporary table but the CREATE statement of the permanent one. Check constraints are read from that statement too, so they now come from the temporary table as well.

---

<sub>Found while fixing the table-name case lookup in the same readers, which [ransack's suite](https://github.com/activerecord-hackery/ransack/blob/fbc3baf164da2a80435d5678a77924c66472f694/spec/ransack/active_record/context_spec.rb#L73-L81) hit on Rails main ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-tests.md), part of my research project Lowrail).</sub>
