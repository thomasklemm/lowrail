Stacked on #59668, which should merge first; only the last commit (`6ffd1872fe`) is new here.

### Read each SQLite index from its own schema in the schema readers

A temporary index may have the name of a permanent one, since the two live in different schemas. The batched SQLite schema readers from 2cb3daba96 look up the columns of each index with an unqualified `pragma_index_info(name)`, which resolves the name to the temporary index, and match the CREATE INDEX statements by name alone, so both rows match. Both tables' indexes then read the temporary index's columns twice, and the permanent one can take the temporary one's CREATE INDEX statement:

| `shared_index`: permanent on `permanent_items (number) WHERE number > 0`, temporary on `temporary_items (label)` | 8-1-stable | main | this PR |
|---|---|---|---|
| `indexes("permanent_items")` columns | label | label, label | number |
| `indexes("permanent_items")` `where` | number > 0 | number > 0 | number > 0 |
| `indexes("temporary_items")` columns | label | label, label | label |
| `indexes("temporary_items")` `where` | number > 0 | number > 0 | nil |

8-1-stable was wrong too, one index at a time: it read the columns from the temporary index and the statement from the permanent one. The rows of `MASTER_CTE` now carry their schema, `'main'` or `'temp'`, which goes to `pragma_index_list` and `pragma_index_info`, and the index statements are keyed by schema and name.

---

<sub>Found while reviewing the temporary-table fix in the same readers, #59668 (record: [Lowrail](https://github.com/thomasklemm/lowrail/blob/b3a61013abd6aae10409a2cb6f51020e692fc6c2/docs/upstream/ecosystem-tests.md), part of my research project).</sub>
