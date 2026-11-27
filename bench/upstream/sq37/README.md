# SQ37: SQLite 3.35/3.36 accepted but unusable (2026-11-25)

Rails main `f785381cca`: [`check_version`](https://github.com/rails/rails/blob/f785381cca8621772cba659ff93f825eb7f99942/activerecord/lib/active_record/connection_adapters/sqlite3_adapter.rb#L518-L522)
accepts SQLite >= 3.35.0 (#58284, merged 2026-07-29, unreleased), but
[`data_source_sql`](https://github.com/rails/rails/blob/f785381cca8621772cba659ff93f825eb7f99942/activerecord/lib/active_record/connection_adapters/sqlite3/schema_statements.rb#L216-L225)
reads `pragma_table_list` (SQLite 3.37.0, 2021-11-27) since #52354 (Rails 8.0). 8.0.0 and 8.1.4.1 read it too; 8.0.0
accepts 3.8.0 and 8.1.4.1 accepts 3.23.0, so the broken range there starts lower. Fix: [thomasklemm/sqlite-floor-3-37](https://github.com/thomasklemm/rails/tree/thomasklemm/sqlite-floor-3-37)
`183262f440`, queue item [SQ37](../pr-queue/items/SQ37.md).

## Public APIs

[`sqlite_data_sources_test.rb`](sqlite_data_sources_test.rb), a plain in-memory connection with one table and one view,
run by `script/min-versions` (sqlite3 gem 2.10.2 compiled against each SQLite with `--enable-system-libraries`, every
run checks `sqlite_version()`). Reports: [main vs fix](min-versions-main-vs-fix.md) ([json](min-versions-main-vs-fix.json)),
[8.1.4.1](min-versions-8.1.4.1.md) ([json](min-versions-8.1.4.1.json)).

| Check | main, 3.35.5 / 3.36.0 | 8.1.4.1, 3.23.1 / 3.35.5 / 3.36.0 | 3.37.0 (main, 8.1.4.1) |
| --- | --- | --- | --- |
| raw SQL, `connection.columns`, `create_table force: true` | pass | pass | pass |
| `table_exists?`, `data_source_exists?`, `view_exists?` | no such table: pragma_table_list | same | pass |
| `data_sources`, `tables`, `views` | no such table | same | pass |
| `Model.table_exists?`, schema cache `data_source_exists?` | no such table | same | pass |
| `Model.column_names` | no such table | pass | pass |
| `Model.create!` / `find` (primary key lookup) | no such table | same | pass |
| `MigrationContext#migrate` (creates `schema_migrations`) | no such table | same | pass |
| `SchemaDumper.dump` | no such table | same | pass |

With the fix, every check on 3.35.5 and 3.36.0 raises `Your version of SQLite (3.36.0) is too old. Active Record
supports SQLite >= 3.37.0.` at connect; on 3.37.0 and 3.44.2 base and head pass alike, Rails'
`sqlite3_adapter_test.rb` 110 runs on base, 111 on head (the new test). Rails' own test helper cannot boot below 3.37
on base (it calls `table_exists?` for `schema_migrations`), so that file reports as crashed there for base and head.

```sh
mise exec ruby@4.0.9 -- script/min-versions --repo ~/src/rails --head thomasklemm/sqlite-floor-3-37 --only sqlite \
  --sqlite 3.36.0,3.37.0 --json bench/upstream/sq37/min-versions-main-vs-fix.json \
  activerecord/test/cases/adapters/sqlite3/sqlite3_adapter_test.rb bench/upstream/sq37/sqlite_data_sources_test.rb
mise exec ruby@4.0.9 -- script/min-versions --repo https://github.com/rails/rails.git --head v8.1.4.1 --base v8.1.4.1 \
  --only sqlite --sqlite 3.35.5,3.36.0,3.37.0 --json bench/upstream/sq37/min-versions-8.1.4.1.json \
  bench/upstream/sq37/sqlite_data_sources_test.rb
```

## A new app

`rails _8.1.4.1_ new --minimal --database=sqlite3`, `gem "sqlite3", force_ruby_platform: true` built with
`--enable-system-libraries` against the same SQLite prefixes, `bin/rails g model Post title:string`, then
`bin/rails db:prepare` on a fresh `storage/`. The main and fix apps are copies with `gem "rails", path:` the tree (so
their queries carry `application='App81'`). Transcripts in [app/](app).

| Rails | 3.35.5 | 3.36.0 | 3.37.0 |
| --- | --- | --- | --- |
| 8.1.4.1 | not run | aborted: no such table: pragma_table_list | not run |
| main `f785381cca` | aborted: no such table | aborted: no such table | migrated, exit 0 |
| fix `183262f440` | not run | aborted: Your version of SQLite (3.36.0) is too old … >= 3.37.0. | migrated, exit 0 |

The SQLite builds are sqlite.org autoconf tarballs installed into a prefix (script/min-versions' recipe), standing in
for a distribution's system library; no distribution image was used.

## Ownership and reach

* No rails/rails issue or PR, open or closed, mentions `pragma_table_list` other than #52354 itself; searches for
  SQLite 3.35/3.36/3.37 and "Your version of SQLite" find only #42641 (explain test on 3.36), #45937 (strict tables),
  #58284, #42955, #41671, #35154 and #32923, none about this. #52354's discussion and reviews never mention an SQLite
  version; #58284 has no comments or reviews. `script/ownership SQ37`: no hits; no open PR names `data_source_sql`
  except #56764 (PostgreSQL).
* System SQLite 3.35/3.36: Alpine 3.14 (3.35.5, EOL 2023-05) and 3.15 (3.36.0, EOL 2023-11), Fedora 35 and 36
  (3.36.0, EOL 2022-12 and 2023-05), from aports and Fedora dist-git. Repology lists no current distribution with 3.35
  or 3.36 (only cross-compilation and legacy package entries); the maintained ones nearest the floor are Ubuntu 22.04,
  Slackware 15.0 and openEuler 22.03 with 3.37.2, while RHEL/Alma/Rocky 9 and Debian 11 (3.34.1) are below 3.35 and already refused on
  main. The sqlite3 gem vendors a current SQLite unless built with `--enable-system-libraries`.

## Choice of fix

Raising the floor, as #58284 did for `RETURNING`: the versions it refuses cannot run a migration or create or find a record today (raw SQL and `create_table` still work, and are
now refused at connect too). A `sqlite_master` fallback in `data_source_sql` for 3.35/3.36 would need a version branch, and `sqlite_master`
cannot tell virtual and shadow tables apart, which is why #52354 moved to `pragma_table_list`. #58284 changed only
`check_version`, the `supports_*` predicates and the CHANGELOG, with no test; no guide names the SQLite floor. The
fix adds a test of the message and the 3.37.0 boundary next to `test_connect`.

## Review

thermos-sol on `183262f440` approves the code, test, body and commit; its must-fixes were record wording (applied).
Evidence: [review-thermos-sol-2026-11-25](review-thermos-sol-2026-11-25/README.md).

## Rebuild on main 088fc0cf61 (2026-11-27)

Main moved 104 commits since `f785381cca`. `check_version` and `data_source_sql` are unchanged (same text; the
method moved two lines down to schema_statements.rb L218-L227); the only SQLite adapter commit since is the
temporary-table shadowing fix, which changes `MASTER_CTE` (sqlite_master/sqlite_temp_master, no 3.37 feature). The
old head conflicted only in `activerecord/CHANGELOG.md`. Rebuilt by hand as one commit `3e348f32bd` on
`088fc0cf61`: the same code and test diff (patch-id `4deab600` outside the CHANGELOG, equal to `183262f440`), the
same CHANGELOG entry on top of main's file, the same message, Thomas as author and committer, no trailers.
Force-pushed to `thomasklemm/sqlite-floor-3-37` with a lease on `183262f440` (no PR on that branch). The body's two
permalinks now point at `088fc0cf61`.

No merged PR covers it: none of the 2026-11-25..27 merges touch `check_version` or the SQLite floor, and
`script/ownership SQ37` finds no open PR (2026-11-27).

* `script/min-versions` base `088fc0cf61` vs head, SQLite 3.35.5 / 3.36.0 / 3.37.0 / 3.44.2:
  [rebuild-2026-11-27/min-versions-main-vs-fix.md](rebuild-2026-11-27/min-versions-main-vs-fix.md). As on
  2026-11-25: 3.35.5 and 3.36.0 fail with `no such table: pragma_table_list` on base and with check_version's
  message at connect on head; 3.37.0 and 3.44.2 pass on both (`sqlite3_adapter_test.rb` 115 runs on base, 116 on
  head).
* The new test fails on main and passes on head:
  [rebuild-2026-11-27/new-test-base-vs-head.txt](rebuild-2026-11-27/new-test-base-vs-head.txt).
* Full Active Record suites on head, Ruby 4.0.9: SQLite (sqlite3 gem 2.5.0 from Rails' Gemfile.lock, SQLite 3.47.2) 10,460
  runs, 37,402 assertions, 0 failures, 0 errors, 52 skips; PostgreSQL 17 11,391 runs, 41,340 assertions, 0
  failures, 0 errors, 31 skips (the change is SQLite-only; PostgreSQL is the control).
