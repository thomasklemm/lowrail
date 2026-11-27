# Bump the minimum supported SQLite version to 3.37.0

Since #52354 (Rails 8.0), [`data_source_sql`](https://github.com/rails/rails/blob/088fc0cf61e4ba0c7987decafacc69adb3e22eec/activerecord/lib/active_record/connection_adapters/sqlite3/schema_statements.rb#L218-L227) reads `pragma_table_list`, added in SQLite 3.37.0. On main, [`check_version`](https://github.com/rails/rails/blob/088fc0cf61e4ba0c7987decafacc69adb3e22eec/activerecord/lib/active_record/connection_adapters/sqlite3_adapter.rb#L518-L522) accepts 3.35.0 after #58284 (unreleased), so SQLite 3.35 and 3.36 fail during uncached schema discovery with `no such table: pragma_table_list`, breaking `bin/rails db:prepare` and model operations that need it.

Raise the connection-time check to 3.37.0 to report the missing requirement clearly. Raw SQL and model operations using a preloaded schema cache can still work on these versions; this change refuses those connections too. Only apps building the `sqlite3` gem against an older system SQLite are affected; the gem bundles a current SQLite.

## For Thomas

Rails reads the list of tables from a SQLite feature that only exists from 3.37 on, but its version check on main (raised to 3.35 in an unreleased change) lets 3.35 and 3.36 through. Migration and uncached model-schema discovery fail on these versions, so `db:prepare` and a plain model read fail with "no such table: pragma_table_list". The change moves the check to 3.37, so those apps get the usual "Your version of SQLite is too old" at connect. Raw SQL, direct table creation, and model CRUD with a preloaded schema cache and cache-version checking disabled can still work; the new floor refuses those connections too. 3.37 came out in November 2021, and no current distribution ships 3.35 or 3.36.
