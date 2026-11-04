### Let a temporary SQLite table hide a permanent one in the schema readers

The batched SQLite schema readers from 2cb3daba96 join each pragma to a list of `sqlite_master` and `sqlite_temp_master` rows. When a temporary table has the same name as a permanent one, both rows match, and `pragma_table_xinfo(name)` resolves both to the temporary table, as SQLite does. So every reader returns the temporary table twice:

| `shadowed`: permanent `(id, number)`, temporary `(temp_id, temp_number)` | 8-1-stable | main | this PR |
|---|---|---|---|
| `columns` | temp_id, temp_number | temp_id, temp_id, temp_number, temp_number | temp_id, temp_number |
| `primary_key` | temp_id | ["temp_id", "temp_id"] | temp_id |
| `indexes` | 1 | 2 (the same index twice) | 1 |

The list now takes a permanent object only when no temporary one has its name, which is how SQLite resolves names, so each reader sees the table that queries use. The test fails on main and passes on 8-1-stable.
