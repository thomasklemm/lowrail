---
id: SQ37
repo: rails/rails
fork: thomasklemm/rails
kind: fix
area: Active Record, SQLite3 adapter
reviewer: "kamipo (author of #58284)"
branch: thomasklemm/sqlite-floor-3-37
head: "3e348f32bdc2b5b405d31f226e6de04aa3278dc9"
base: main
built_on: "088fc0cf61"
introduced_by: 52354
depends_on: []
stacked_on:
alternative_of:
impact: "Since #52354 (Rails 8.0) data_source_sql reads pragma_table_list (SQLite 3.37.0); main's check_version accepts 3.35.0 since #58284 (unreleased); 8.0.0 accepts 3.8.0; 8.1.4.1 accepts 3.23.0. On 3.35.5 and 3.36.0, table_exists?, data_source_exists?, view_exists?, data_sources, tables, views, Model.table_exists?, create!/find, the schema cache, MigrationContext#migrate, SchemaDumper.dump and bin/rails db:prepare raise 'no such table: pragma_table_list', on main and on 8.1.4.1; raw SQL, connection.columns and create_table still work. Model.column_names fails on main but works on 8.1.4.1. The fix makes those versions fail at connect with check_version's message, as #58284 did for RETURNING. Reach: only sqlite3 gem builds against a system SQLite 3.35/3.36 (the gem vendors a current SQLite by default); no distribution on repology ships either version today, EOL ones did (Alpine 3.14 3.35.5, Alpine 3.15 3.36.0, Fedora 35/36 3.36.0). Lifetime: Main refuses SQLite below 3.35.0; 8.1.4.1 checks 3.23.0 and 8.0.0 checks 3.8.0, despite sharing the 3.37.0 metadata dependency."
evidence: [bench/upstream/sq37, bench/upstream/sq37/rebuild-2026-11-27]
rank: 9
risky: false
state: built
note: "2026-11-27: rebuilt on main 088fc0cf61 as 3e348f32bd (check_version and data_source_sql unchanged since 183262f440; the old head conflicted only in the CHANGELOG; same code and test diff, entry on top of main's CHANGELOG, same message), force-pushed to sqlite-floor-3-37 (no PR). Body permalinks moved to 088fc0cf61. No merged or open PR covers it. min-versions, the new test on base, AR SQLite and PostgreSQL suites: bench/upstream/sq37/README.md#rebuild-on-main-088fc0cf61-2026-11-27. State built until thermos-sol and Astra approve 3e348f32bd. Earlier: 2026-11-25: thermos-sol approves 183262f440 (record-only must-fixes applied), so reviewed. Optional companion left out: the app generator's sqlite3.yml.tt still says \"Versions 3.8.0 and up\"; add it as a second line of the same commit if a maintainer asks or Thomas wants it. Earlier: 2026-11-25: built and verified in thread T-01a214ee-8570-7170-bee7-2daabcaecd72 (bench/upstream/sq37/README.md). Correctness fix for an already released gap (8.0+), not an unreleased regression of wide reach, so below the current rails/rails bar: keep it reviewed and queued, don't open in this round. Alternative considered and rejected: a sqlite_master fallback in data_source_sql for 3.35/3.36 would need a version branch and could not tell virtual and shadow tables apart, which #52354 relies on pragma_table_list for. #58284 added no test and named the floor only in check_version and the CHANGELOG; no guide states the SQLite floor."
ownership: {date: 2026-11-27, checked: ["open PRs cross-referencing #52354","open PRs naming check_version that change activerecord/CHANGELOG.md, activerecord/lib/active_record/connection_adapters/sqlite3_adapter.rb"], hits: []}
passes:
  - {reviewer: thermos-sol, head: "183262f44056c9b860cb0921b2c596a2e183653d", orb: "T-01a21502-d24f-743b-b975-de940480e1e3", date: 2026-11-25, verdict: approve, open: "Code, test, CHANGELOG, commit message and posted body approved against main f785381cca; body and commit claims checked (permalinks, SQLite 3.37.0 release log, #52354 and #58284 diffs, sqlite3 gem 2.10.2 vendors 3.54.1). Must-fixes were in the record only (impact: 8.0.0 checks 3.8.0; Model.column_names works on 8.1.4.1; the range is not main-only; For Thomas overstated what fails), applied on 2026-11-25 without a head change. Test fails on base, passes on head. sqlite_master fallback loses virtual/shadow classification (fallback-sql.txt). min-versions rerun: 3.37.0 and 3.44.2 110/111 adapter tests plus 15/15 standalone. Optional, not applied: generator sqlite3.yml.tt:1 says Versions 3.8.0 and up (pre-existing, #58284 left it too, three dummy configs repeat it); assert_nothing_raised { connect! } instead of assert_nil check_version. Evidence: bench/upstream/sq37/review-thermos-sol-2026-11-25/."}
---

# Bump the minimum supported SQLite version to 3.37.0

Since #52354 (Rails 8.0), [`data_source_sql`](https://github.com/rails/rails/blob/088fc0cf61e4ba0c7987decafacc69adb3e22eec/activerecord/lib/active_record/connection_adapters/sqlite3/schema_statements.rb#L218-L227) reads `pragma_table_list`, which SQLite added in 3.37.0. [`check_version`](https://github.com/rails/rails/blob/088fc0cf61e4ba0c7987decafacc69adb3e22eec/activerecord/lib/active_record/connection_adapters/sqlite3_adapter.rb#L518-L522) accepts 3.35.0 since #58284, so on SQLite 3.35 and 3.36 `table_exists?`, `tables`, the schema cache and migrations raise `no such table: pragma_table_list`, and with them `bin/rails db:prepare` and `Model.create!`.

This raises in `check_version` below 3.37.0, as #58284 did for `RETURNING`, so these versions fail at connect with a clear message instead. Only apps that build the `sqlite3` gem against an older system SQLite are affected, since the gem ships a current one.

## For Thomas

Rails reads the list of tables from a SQLite feature that only exists from 3.37 on, but its version check lets 3.35 and 3.36 through. On those versions, `db:prepare` and ordinary model reads and writes fail with "no such table: pragma_table_list". The change moves the version check to 3.37, so those apps get the usual "Your version of SQLite is too old" at connect instead of a confusing error later. Those ordinary Rails operations already fail today, and 3.37 came out in November 2021. Raw SQL and `create_table` still work on those versions now; with the change they are refused at connect too.
