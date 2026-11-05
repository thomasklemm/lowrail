---
id: E2b
repo: rails/rails
kind: fix
area: Active Record SQLite schema readers
reviewer: "ngan (author of 2cb3daba96, #58498), byroot (merged it)"
branch: thomasklemm/sqlite-schema-readers-temp-shadowing
head: "472c680d15"
base: main
built_on: "8b06b0eb98"
depends_on: []
stacked_on:
alternative_of:
impact: "a temporary SQLite table or view hides the permanent one again: columns and indexes no longer duplicated, primary key no longer composite"
rank: 5
risky: false
state: draft
pr: 59668
note: "opened as draft 2026-11-05; must land before E2; skeptic must-fix on 472c680d15 (same-named temp index), awaiting the coordinator before any change"
passes:
  - {reviewer: sol, head: "472c680d15", date: 2026-11-05, verdict: nits, open: applied}
  - {reviewer: sol, head: "472c680d15", date: 2026-11-05, verdict: approve, open: "20:07, no must-fix; body nit applied before opening"}
  - {reviewer: skeptic, head: "472c680d15", date: 2026-11-05, verdict: changes, open: "must-fix: sqlite_temp_master first makes index_details read a same-named temp index CREATE, so the permanent index loses where: (main keeps it); fix: keep sqlite_master first. Follow-up: pragma_index_info still resolves temp first (columns doubled, from 2cb3daba96). Nit: check constraints etc. also come from the temp CREATE, not only collation"}
---

# Let a temporary SQLite table or view hide a permanent one in the schema readers

The batched SQLite schema readers from 2cb3daba96 join each pragma to a list of `sqlite_master` and `sqlite_temp_master` rows. When a temporary table has the same name as a permanent one, both rows match, and the pragmas resolve both to the temporary table, as SQLite does. So columns and indexes are duplicated, and the primary key becomes composite:

| `shadowed`: permanent `(id, number)`, temporary `(temp_id, temp_name COLLATE NOCASE)` | 8-1-stable | main | this PR |
|---|---|---|---|
| `columns` | temp_id, temp_name | temp_id, temp_id, temp_name, temp_name | temp_id, temp_name |
| `primary_key` | temp_id | ["temp_id", "temp_id"] | temp_id |
| `indexes` | 1 | 2 (the same index twice) | 1 |
| `temp_name` collation | nil | nil | NOCASE |

The list now takes a permanent table or view only when no temporary table or view has its name, which is how SQLite resolves identically spelled names. Temporary indexes and triggers don't take part, so they hide nothing. The collation row goes beyond 8-1-stable: it read columns from the temporary table but the CREATE statement of the permanent one.

---

<sub>Found while fixing the table-name case lookup in the same readers, which [ransack's suite](https://github.com/activerecord-hackery/ransack/blob/fbc3baf164da2a80435d5678a77924c66472f694/spec/ransack/active_record/context_spec.rb#L73-L81) hit on Rails main ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-tests.md), part of my research project Lowrail).</sub>
