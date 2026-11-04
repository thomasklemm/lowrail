### Find SQLite tables by any ASCII case of their name in the schema readers

2cb3daba96 batched the SQLite schema readers. They now filter `sqlite_master` with `m.name IN (...)` and key the rows by the stored name. The `pragma table_info(name)` calls they replaced matched names the way SQLite does, ignoring ASCII case. So a model whose `table_name` is `"widgets"` can no longer read a table created as `Widgets`; ransack's suite hits this on `create!`.

Reading table `Widgets` (and view `WidgetsView`) by lowercase name, as in the test:

| | 8-1-stable | main | this PR |
|---|---|---|---|
| `columns` | id, number | StatementInvalid | id, number |
| `primary_key` | id | StatementInvalid | id |
| `indexes` / `foreign_keys` | 1 / 1 | 0 / 0 | 1 / 1 |
| view `columns` | id | StatementInvalid | id |

The readers now match with `COLLATE NOCASE`, then give each requested name the rows of its table, so a batch that asks for two ASCII-case spellings of the same table gets both. NOCASE folds only ASCII, like SQLite identifiers, so `Ärger` and `ärger` stay two tables.
