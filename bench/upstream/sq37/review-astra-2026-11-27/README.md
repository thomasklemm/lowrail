# SQ37 independent Astra review, 2026-11-27

Verdict: **changes**, one wording/compatibility-disclosure must-fix; no demonstrated code defect.

Reviewed `3e348f32bdc2b5b405d31f226e6de04aa3278dc9`, exactly one commit on
`088fc0cf61e4ba0c7987decafacc69adb3e22eec`. The fetched canonical main was still that base.
The review was performed directly, without other agents or threads. The upstream branch and queue item were not changed.
`reviewed.diff` contains the exact commit and diff; `item-snapshot.md` preserves the text reviewed.

## Must-fix: disclose working cached-model operations that the new floor refuses

The body and commit message present model operations/schema-cache reads as failing on 3.35/3.36 without
qualifying the need for schema discovery. The record's assertion that these versions cannot create/find a record
is too broad. I demonstrated a working supported configuration, not an override of adapter methods:

1. On base with SQLite 3.44.2, create the database and dump its schema cache.
2. Use the same database and cache on base with SQLite 3.35.5 or 3.36.0, setting
   `config.active_record.check_schema_cache_dump_version = false` and `schema_cache_path`.
3. Through the real `bin/rails runner`, create a model, find it and check its value, update and check it,
   destroy it and check absence. All pass on both older SQLite versions.
4. The same configuration and operations on head fail in `check_version` before any CRUD SQL.
5. Both sides pass on 3.37.0. The standalone control with default cache-version checking enabled fails on
   old SQLite because validating the cache itself needs schema discovery.

Evidence: `cached_crud_probe.rb`, `cached-crud-build.txt`, `cached-crud-{base,head}-*.txt`,
`cold-crud-base-*.txt`, the minimal `app/` fixture, and `rails-cached-crud-{base,head}-*.txt`.
The actual Railtie initializes and forwards this configuration in `activerecord/lib/active_record/railtie.rb`
lines 32 and 155. No method was replaced in these probes. The cache was built on a newer SQLite;
it was not fabricated by mutating Rails internals.

This does not show that a 3.37 floor is wrong: migration/schema-discovery support already needs it.
It does show that this is not only replacing an error for every affected caller. Under the PR-description
and claims rules, state the compatibility boundary instead of calling all model operations broken.

Exact replacement for the body's second sentence (the whole sentence beginning with the `check_version` link):

> [`check_version`](https://github.com/rails/rails/blob/088fc0cf61e4ba0c7987decafacc69adb3e22eec/activerecord/lib/active_record/connection_adapters/sqlite3_adapter.rb#L518-L522) accepts 3.35.0 since #58284, so on SQLite 3.35 and 3.36 uncached schema discovery raises `no such table: pragma_table_list`, breaking `bin/rails db:prepare` and model operations that need it.

Add this exact sentence to the body's second paragraph and the commit message's final paragraph:

> Raw SQL and model operations using a preloaded schema cache can still work on those versions; this change refuses those connections too.

Exact replacement for the commit message's paragraph beginning `On SQLite 3.35.x`:

> On SQLite 3.35.x and 3.36.x, which `check_version` still accepts, uncached schema discovery fails with "no such table: pragma_table_list". This breaks `db:prepare` and model operations that need that information.

Keep the record and For Thomas consistent. Suggested replacement for the record's assertion that the versions
cannot create/find a record, and for the corresponding unqualified sentence in For Thomas:

> Migration and uncached model-schema discovery fail on these versions. Raw SQL, direct table creation, and model CRUD with a preloaded schema cache and cache-version checking disabled can still work; the new floor refuses those connections too.

Changing the commit message creates a new head and requires the coordinator to record/review that head.
The builder owns all changes to the item and upstream branch.

## Optional point

The generated database configuration still advertises SQLite 3.8.0 at
`railties/lib/rails/generators/rails/app/templates/config/databases/sqlite3.yml.tt:1`.
This predates SQ37 and the earlier 3.35 floor change, so it is not a blocker for this diff.
If included, the exact replacement is `# SQLite. Versions 3.37.0 and up are supported.`

## Executed checks

Ruby 4.0.9 throughout; sqlite3 gem 2.10.2 compiled against each actual SQLite library by `script/min-versions`.
The tool verifies the runtime `SELECT sqlite_version()` against each requested library.
No timing, allocation, instruction, or performance claim is made from the incidental test-run timings.

* `min-versions.json` and `min-versions.txt`: actual base/head runs on SQLite 3.35.5, 3.36.0, 3.37.0 and
  3.44.2. The 15 public-API probes have 12 errors on base below 3.37; raw SQL, `columns`, and direct
  `create_table` still pass. Head refuses all 15 at connect. Both supported versions pass all 15.
  The upstream test helper cannot boot below 3.37; these crashes are retained, not called passing tests.
  `script/min-versions` consequently exits 2. The repeated 3.35.5 cell is the tool's floor plus explicit extra.
* `new-test-base.txt` / `new-test-head.txt`: the exact new upstream test run against each production tree.
  Base: one failure, "RuntimeError expected but nothing was raised". Head: one test, three assertions, passing.
* All 15 SQLite-specific test files, not only the changed file, through `run-cell.sh`:

  | SQLite | Base | Head |
  | --- | --- | --- |
  | 3.37.0 | 235 runs, 615 assertions, 0 failures/errors, 1 skip | 236 runs, 618 assertions, 0 failures/errors, 1 skip |
  | 3.44.2 | 235 runs, 618 assertions, 0 failures/errors, 0 skips | 236 runs, 621 assertions, 0 failures/errors, 0 skips |

  Raw `sqlite-suite-*.txt`. The 3.37 skip is the existing temporary-index naming case explicitly gated on 3.40.
  Initial runs lacked the sqlite3 CLI on PATH and had four structure dump/load errors on both sides;
  those outputs remain as `*-no-cli.txt`. Adding the matching built SQLite bin directory fixed the environment;
  no test was skipped or changed to obtain the final results.
* `app-{base,head}-3.35.5.txt` and `app-{base,head}-3.36.0.txt`: `bin/rails db:prepare` fails with
  `no such table: pragma_table_list` on base and the new version message on head. Both sides migrate on 3.37.0;
  `app-base-3.44.2.txt` is another passing control. Each command uses a fresh scratch database.
* `boundary_probe.rb`, `boundary-{base,head}.json`, `boundary-comparison.txt`: 77 inputs per side, including
  numeric Version objects, subclasses, frozen objects, duck-typed comparables, Strings and String subclasses.
  Only the 3.35/3.36 values become newly refused. Already-refused inputs receive the updated message.
  Accepted cases return nil; the comparisons return -1, 0 or 1. Real `get_database_version` constructs
  numeric Version objects. Artificial String returns retain pre-existing lexical ordering on both sides;
  they are not the adapter's actual return contract.

## Other skeptical checks

* Inspected the SQLite adapter, schema statements, schema creation, database statements and SQLite
  Arel visitor. No mandatory newer-than-3.37 dependency was demonstrated. The complete SQLite-specific tests
  pass at 3.37.0. This is not a claim that arbitrary SQL or every Arel node works there: I deliberately executed
  Arel RIGHT and FULL OUTER JOIN nodes, which fail on 3.37; LEFT OUTER JOIN succeeds
  (`optional-joins-3.37.0.txt`). These are optional generic SQL nodes, not required schema/bootstrap operations,
  and do not justify raising the universal adapter floor further.
* Version comparison and error class/message remain in the existing method's idiom; only the numeric floor and
  message floor change. Test stubbing already exists in this file. The new test covers both sides of the boundary
  and fails on base. Its `assert_nil` observes the current method result; no extra comment was added.
* Exactness checklist: no new user-object calls, conversions, ownership changes, caches, mutation, iteration,
  callbacks, thread/fiber state, or load hooks. Numeric comparison dispatch is unchanged. Subclass, duck and
  frozen-input comparisons were executed; connect/error paths were executed with actual libraries. The intentional
  contract change is refusing connections below 3.37, including previously working paths described above.
* The merged-PR query returned all 71 results since 2026-11-25, with `incomplete_results: false`.
  The fetched canonical main is still 088fc0cf61. The only SQLite adapter change in that interval is
  `90c9862850` (temporary-table shadowing), which changes `MASTER_CTE`, not this floor or `data_source_sql`.
  `history-check.txt`, `recent-commits.json`, `merged-prs.json`; no covering merge was found.
  Targeted open-PR searches for `pragma_table_list` and `3.37.0` both returned zero (`open-*-prs.json`).
* Read the earlier floor change and introducing change as first-parent diffs (`previous-floor.diff`,
  `introduced.diff`). Verified the introducing commit is an ancestor of v8.0.0 and the released source uses the
  pragma (`history-check.txt`). Opened both body permalinks over HTTP, fetched their exact source, and checked
  the cited lines (`permalinks.txt`, `linked-*.rb`). Opened SQLite's official 3.37 release log, which explicitly
  introduces `PRAGMA table_list` (`sqlite-release-3.37.html`). The live old/new library probes confirm the
  table-valued spelling. The previous floor change explicitly names RETURNING; that analogy is accurate.

## Currency and reach of cited projects

Checked live GitHub and RubyGems APIs, not stale metadata. Raw `rails-{repo,gem}.json` and
`sqlite3-{repo,gem}.json` preserve the responses.

| Project, in body's order | GitHub stars | Gem downloads | Last push | Latest gem release |
| --- | ---: | ---: | --- | --- |
| Rails | 59,174 | 823,128,659 | 2026-11-27 | 8.1.4.1, 2026-11-04 |
| sqlite3-ruby | 848 | 203,666,215 | 2026-11-25 | 2.10.2, 2026-10-26 |

Both repositories are active and unarchived; the Rails-first order fits reach and subject. No niche caller/app
is cited. Rails main is the explicit target, not a stale release offered as current evidence. The current sqlite3
release's v2.10.2 commit is `1d2aa7ab53f1bb98a5dd64e51220ff9a83cd07f5`; its installation guide says packaged
SQLite is the default and system libraries require an explicit flag. Its dependencies file vendors SQLite 3.54.1.
Current default branch `5df1c541c5e43b84527d31f59205a1f64a07f158` also vendors 3.54.1. Sources retained as
`sqlite3-INSTALLATION.md`, `sqlite3-dependencies.yml`, `sqlite3-main.json`, `sqlite3-main-dependencies.yml`.
The body's narrow system-library reach is supported; this review does not establish large current-app impact
or override the item's existing held-opening rationale. I did not independently audit the record's distribution
inventory, which the posted body does not cite.

## Reproduction

Clone the given branch to `.amp/in/orb-backup/sq37-rails`, then from Lowrail root:

```sh
LOWRAIL_MIN_VERSIONS_CACHE="$PWD/.amp/in/orb-backup/min-versions" mise exec ruby@4.0.9 -- script/min-versions \
  --repo "$PWD/.amp/in/orb-backup/sq37-rails" \
  --head 3e348f32bdc2b5b405d31f226e6de04aa3278dc9 --base 088fc0cf61e4ba0c7987decafacc69adb3e22eec \
  --only sqlite --sqlite 3.35.5,3.36.0,3.37.0 --json .amp/in/orb-backup/sq37-min-versions.json \
  activerecord/test/cases/adapters/sqlite3/sqlite3_adapter_test.rb bench/upstream/sq37/sqlite_data_sources_test.rb
e="$PWD/bench/upstream/sq37/review-astra-2026-11-27"
bash "$e/run-cell.sh" head 3.37.0 -e 'Dir.glob("test/cases/adapters/sqlite3/*_test.rb").sort.each { |f| require File.expand_path(f) }' -- --seed 41231
bash "$e/run-cell.sh" base 3.44.2 "$e/boundary_probe.rb"
bash "$e/run-cell.sh" head 3.44.2 "$e/boundary_probe.rb"
db="$PWD/.amp/in/orb-backup/repro-crud.sqlite3"
cache="$PWD/.amp/in/orb-backup/repro-cache.yml"
bash "$e/run-cell.sh" base 3.44.2 "$e/cached_crud_probe.rb" build "$db" "$cache"
bash "$e/run-cell.sh" base 3.36.0 "$e/cached_crud_probe.rb" cached "$db" "$cache"
bash "$e/run-cell.sh" head 3.36.0 "$e/cached_crud_probe.rb" cached "$db" "$cache"
cp -R "$e/app" .amp/in/orb-backup/repro-app
SQ37_DATABASE="$db" SQ37_SCHEMA_CACHE="$cache" bash "$e/run-cell.sh" base 3.36.0 \
  -C "$PWD/.amp/in/orb-backup/repro-app" bin/rails runner \
  'class Widget < ActiveRecord::Base; end; w=Widget.create!(name: "cached rails runner"); raise unless Widget.find(w.id).name == "cached rails runner"; w.update!(name: "updated"); raise unless Widget.find(w.id).name == "updated"; w.destroy!; raise if Widget.exists?(w.id); puts "PASS: create/find/update/destroy through Rails runner"'
SQ37_DATABASE="$PWD/.amp/in/orb-backup/repro-prepare.sqlite3" bash "$e/run-cell.sh" base 3.36.0 \
  -C "$PWD/.amp/in/orb-backup/repro-app" bin/rails db:prepare
```

Repeat with the sides/versions named in the output filenames. Use a fresh database path for each `db:prepare`.
The first cache-dump harness attempt omitted `require "fileutils"`; it failed before producing a cache, was fixed,
and all cache cases rerun. Those setup-only outputs stay in `.amp/in/orb-backup/initial-cached-probe/`.
No non-SQLite database suite or full cross-component Rails suite was rerun in this independent pass.
