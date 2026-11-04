### Find SQLite tables by any ASCII case of their name in the schema readers

2cb3daba96 batched the SQLite schema readers. They now filter `sqlite_master` with `m.name IN (...)` and key the rows by the stored name. The `pragma table_info(name)` they replaced matched table names the way SQLite does, ignoring ASCII case. So a table created as `Widgets` with a model whose `table_name` is `"widgets"` now fails on `create!` with `Could not find table 'widgets'`. ransack's suite hits this.

| `"widgets"` for table `Widgets` | 8-1-stable | main | this PR |
|---|---|---|---|
| `columns` | id, name, owner_id | StatementInvalid | id, name, owner_id |
| `primary_key` | id | StatementInvalid | id |
| `indexes` | 1 | 0 | 1 |

The readers now match with `COLLATE NOCASE` and key the rows by the name that was asked for. NOCASE folds only ASCII, as SQLite does for identifiers, so `Ärger` and `ärger` stay two tables. A test covers that too.
