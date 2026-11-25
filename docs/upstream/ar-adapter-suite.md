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

## Oldest supported versions (2026-11-25)

`script/min-versions` runs Rails test files for a head on the oldest versions Rails main supports, against its base
(the merge-base with rails/rails main), so a change that only works on newer SQLite, PostgreSQL, MySQL or Ruby shows
up before review. E2 (rails/rails#59671) passed several reviews and broke only on SQLite 3.35/3.36, which lack
`pragma_table_list`.

```sh
mise exec ruby@4.0.9 -- script/min-versions --repo https://github.com/thomasklemm/rails.git --head BRANCH_OR_SHA \
  activerecord/test/cases/adapters/sqlite3/sqlite3_adapter_test.rb bench/upstream/min-versions/sqlite_schema_readers_test.rb
mise exec ruby@4.0.9 -- script/min-versions --repo ~/src/rails --only sqlite,postgresql FILE...   # local checkout, its HEAD
```

The floors come from the base tree on every run: `check_version` in the SQLite, PostgreSQL and abstract MySQL
adapters and `required_ruby_version` in `rails.gemspec`. Each cell runs base and head; the table lists each version's
build time and any test that fails on head but not base (exit 1; exit 2 if a run crashed before minitest reported).
`--json FILE` keeps the report; `--mariadb TAG` adds a MariaDB image (Rails names no MariaDB floor). Builds are cached
in `~/.cache/lowrail-min-versions`, each with its recipe and time in `BUILD.json`; delete a directory to rebuild it.
Docker needs `sudo`; the script starts the daemon if it is down. Files under `activerecord/`'s adapter directories run
only on their database; other Active Record files run on every cell.

| Cell (Rails main `7c0f820c1a`) | Version | Build in an orb (2 CPUs) |
| --- | --- | --- |
| SQLite floor (3.35.0 → last 3.35 patch) | 3.35.5, sqlite3 gem 2.10.2 linked against it | 41 s |
| SQLite middle (between floor and newest 3.54) | 3.44.2 (3.44.3–3.44.5 have tags but no tarballs) | 44 s |
| PostgreSQL floor (10.0) | `postgres:10`, server 10.21 | 1–7 s pull |
| MySQL floor (5.7.9) | 5.7.9 from the cdn.mysql.com tarball (Docker Hub's image is schema-1, no longer pullable) | 63–85 s |
| Ruby floor (3.3.5) | ruby-build 3.3.5, the sqlite3 gem's own SQLite | 268 s |

**Rails' own test helper cannot boot on SQLite 3.35/3.36, on main too**: it calls `table_exists?`, whose
`data_source_sql` reads `pragma_table_list` (since Rails 8.0). The script reports such runs as crashed for base and
head alike. [`sqlite_schema_readers_test.rb`](../../bench/upstream/min-versions/sqlite_schema_readers_test.rb) checks
the schema readers on a plain connection instead; a file outside the Rails tree runs in its own process from
`activerecord/`. E2 proof, readers test:

| Head | SQLite 3.35.5 base / head | SQLite 3.44.2 base / head |
| --- | --- | --- |
| `d0ae80e186` | 6/6 pass / 6/6 pass | pass / pass |
| `6823de7e09` | 6/6 pass / **6 errors, `no such table: pragma_table_list`** (exit 1) | pass / pass |

`finder_test.rb` on `d0ae80e186` and `6823de7e09` passes base and head on PostgreSQL 10.21 (295 runs, 7 skips), MySQL 5.7.9
with mysql2 (292 runs, 6 skips), Ruby 3.3.5 (295 runs) and SQLite 3.44.2 (289 runs).
