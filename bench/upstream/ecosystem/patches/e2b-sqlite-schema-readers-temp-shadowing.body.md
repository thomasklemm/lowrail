### Let a temporary SQLite table or view hide a permanent one in the schema readers

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
