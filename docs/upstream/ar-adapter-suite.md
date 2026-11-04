# Active Record suite on MySQL, MariaDB and PostgreSQL (2026-11-04)

Bug hunt: the full Active Record suite (`rake test:<adapter>`) on rails main `6c23cb8f2a` against 8-1-stable
`6e09124217` as the control, same orb, same server image per pair, Ruby 4.0.9. A failure counts only if
8-1-stable passes in the same setup.

| Server | Adapter | main | 8-1-stable |
|---|---|---|---|
| MySQL 8.4.13 | mysql2 | 10422 runs, 0 F, 2 E (env) | 9586 runs, clean |
| MySQL 8.4.13 | mysql2, `MYSQL_PREPARED_STATEMENTS` | 10456 runs, 0 F, 1 E (env) | 9612 runs, clean |
| MySQL 8.4.13 | trilogy | 10439 runs, 0 F, 2 E (env) | 9608 runs, clean |
| MySQL 9.7.4 | mysql2 | 10419 runs, 0 F, 2 E (env) | 9583 runs, clean |
| MySQL 9.7.4 | trilogy | 10436 runs, 0 F, 2 E (env) | 9605 runs, clean |
| MariaDB 11.8.9, snapshot isolation off | mysql2 | 10392 runs, 0 F, 2 E (env) | 9559 runs, clean |
| MariaDB 11.8.9, snapshot isolation off | trilogy | 10409 runs, 0 F, 1 E (env) | 9581 runs, clean |
| PostgreSQL 17.11 | postgresql | 11202 runs, 0 F, 1 E (env) | 10208 runs, 1 E (env) |
| PostgreSQL 18.6 | postgresql | 11220 runs, 0 F, 1 E (env) | 10209 runs, 1 E (env) |

**No regression on main.** Every main error is environment-only:

* `MySQLStructureDumpTest` / `MySQLStructureLoadTest` and `PostgreSQLStructureDumpTest#test_structure_dump`: the orb
  had no `mysql`/`mysqldump` and only `pg_dump` 15. With the MariaDB client and `postgresql-client-18` installed,
  the rake test files pass on main and 8-1-stable for every server above (main 32 / 43 runs, 8-1 28 / 38, all green).
* MariaDB 11.8 with its default `innodb_snapshot_isolation=ON`: main has 10 errors (`SAVEPOINT active_record_N does
  not exist`, `CreateOrFindByWithinTransactions`), 8-1-stable aborts in `ConcurrentTransactionTest` ("Record has
  changed since last read"). Both fail, so it doesn't count; it is the known server default from rails/rails#53727,
  and Rails CI runs `mariadb:11.4`.
* A first PostgreSQL attempt had duplicate-key and deadlock errors because two runners shared one database; it was
  discarded and rerun on fresh databases.

Not covered: MySQL 5.7 and MariaDB 11.4 (the CI images), `sqlite3_mem`, Ruby master, PostgreSQL without prepared
statements as a whole suite.
