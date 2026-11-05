# Ecosystem tests against Rails main (2026-11-04)

Bug hunt through the ecosystem's own test suites. Each gem's suite runs twice, on Rails 8-1-stable (`6e09124217`) and on
main (`6c23cb8f2a`; fixes on `8b06b0eb98`), with Ruby 4.0.9 and the same lockfile otherwise. A failure counts only if it
fails twice on main and passes on 8-1-stable.

Harness: [`bench/upstream/ecosystem/`](../../bench/upstream/ecosystem). `eco.sh . LABEL CMD` runs inside a gem checkout
against `~/src/eco/rails-LABEL` through the wrapper `Gemfile.eco`, and `eco-locks.rb` compares the two locks. The
expected lock difference is herb, marcel 2.1.0, psych, ractor-dispatch and stringio, which main adds or bumps.

## Results

| Gem | 8-1-stable | main | Outcome |
| --- | --- | --- | --- |
| devise | 878 runs, 0F | 878 runs, 0F | same (assertion count depends on seed) |
| rspec-rails | 993 ex, 50F | 993 ex, 41F | nothing new on main (Ruby 4 frozen-literal warnings in generators, `bundle exec` sanity specs) |
| pundit | 184 ex, 0F | 184 ex, 0F | same |
| cancancan (SQLite, PG) | 712 ex, 0F | 712 ex, 0F | same |
| friendly_id (SQLite, PG) | 530 runs, 0E | 530 runs, 1E | **regression**, I1 |
| view_component | 892 runs, 0F | 6F 8E; rspec 1 load error | deliberate changes and gem-side causes, see below |
| simple_form | 806 runs, 2F 1E | same 2F 1E | same |
| ransack (SQLite, PG) | 1145 / 1146 ex, 0F | 32 load errors | **regressions**, E1 and E2; one gem-side cause |
| administrate | 642 ex, 0F | does not boot | **regression** E3; the rest deliberate or gem-side |
| jbuilder | 138 runs, 0F | 138 runs, 0F | same |
| good_job | 1265 ex, 2F | 1265 ex, 2F | same |
| solid_queue (SQLite, PG) | 402 runs, 2F | 402 runs, 2F | same |
| sidekiq (Rails tests) | 177 runs, 0F | 177 runs, 0F | same |
| paper_trail (SQLite, PG) | 444 / 510 ex, 0F | 444 / 510 ex, 0F | same (gem caps `ACTIVERECORD_LT "< 8.2"`) |
| active_model_serializers | 576 runs, 0F | NameError on load | **regression** E4; then deliberate route removal |
| pagy | 608 + 597 tests, 0F | same | same |
| turbo-rails | 247 runs, 0F (system tests included) | same | same |
| importmap-rails | 104 runs, 0F | same | same |
| propshaft | 170 runs, 0F | same | same |
| responders | 116 runs, 0F | same | same |
| rails-controller-testing | 46 runs, 2F 2E | 9F 28E | deliberate (92d809905b) |
| draper | 322 ex, 0F; dummy 50 ex | 1F; dummy 2 load errors | deliberate (baa1ca5f2f, c10c3c5bf4) |
| acts-as-taggable-on | 312 ex, 0F | same | same |
| kaminari | passed | passed | same (log not kept) |

MySQL, Trilogy and MongoDB configurations were skipped because this orb has none of those servers.

## Regressions and their fixes

| ID | Cause (first bad commit) | Fix | Branch @ SHA on thomasklemm/rails | State |
| --- | --- | --- | --- | --- |
| E1 | `DescendantsTracker` uses `WeakSet` without requiring it (3c77803ec0); `require "active_support/core_ext/class/subclasses"` raises NameError and ransack does not load | one `require` | `thomasklemm/descendants-tracker-require-weak-set` @ `1d1fbb6410` | superseded: rails/rails#59623 closed by skipkayhil ("You must require active_support before cherry picking core extensions"); fixed in ransack instead, G1 `thomasklemm/require-active-support-before-core-ext` @ `4713d2d697`, open as activerecord-hackery/ransack#1792 |
| E2 | the batched SQLite readers match table names exactly (2cb3daba96), so a table created as `Widgets` is not found as `widgets` | `COLLATE NOCASE` plus rows keyed by each requested name, and E2b's hiding check `COLLATE NOCASE` too; stacked on E2b | `thomasklemm/sqlite-schema-readers-table-name-case-stacked` @ `63d1880397` (unstacked `bf905ad4f6` before) | reviewed on `63d1880397` (skeptic, Sol, Astra); opens when Thomas asks ([item](../../bench/upstream/pr-queue/items/E2.md)) |
| E2b | the same readers list a temporary table or view and the permanent table it hides, so columns and indexes are duplicated and the primary key becomes composite (2cb3daba96) | in `MASTER_CTE`, a temporary table or view hides a permanent one; temporary indexes and triggers hide nothing; `sqlite_master` stays first | `thomasklemm/sqlite-schema-readers-temp-shadowing` @ `bc90b487f2` (`472c680d15` before) | draft rails/rails#59668; reviewed on `bc90b487f2` (skeptic, Sol, Astra), ready when a slot frees ([item](../../bench/upstream/pr-queue/items/E2b.md)) |
| E2c | the same readers read index columns with an unqualified `pragma_index_info(name)` and match CREATE INDEX statements by name, so a permanent index with a temporary namesake reads the temporary index's columns twice (2cb3daba96; 8-1-stable read them once, also from the temporary index) | `MASTER_CTE` rows carry their schema, passed to `pragma_index_list` and `pragma_index_info`; index statements keyed by schema and name; stacked on E2b | `thomasklemm/sqlite-index-details-schema` @ `6c80a5583b`, stacked on E2 | reviewed (skeptic, Sol, Astra; thermos waived by the coordinator); opens when Thomas asks ([item](../../bench/upstream/pr-queue/items/E2c.md)) |
| E3 | `ActiveSupport::LogSubscriber.colorize_logging` removed without a deprecation (aebcb61520); awesome_print 1.9.2 raises on load, administrate does not boot | deprecated delegators to `ActiveSupport.colorize_logging` | `thomasklemm/log-subscriber-colorize-logging-deprecation` @ `8672567e15` | open as rails/rails#59628 |
| E4 | `alias :assert_not_pattern :refute_pattern` (23420be739) needs minitest 5.18; the gemspec allows 5.1 | gemspec floor `>= 5.18` | `thomasklemm/activesupport-minitest-floor` @ `0a69eb6cce` | Sol: open with nits |
| I1 | `Model.all.find(id)` ignores an overridden `self.primary_key` (55406a9794) | issue with a repro, since the code is under active rework | — | posted as rails/rails#59622; fix proposed by MIbtehajNasar in #59631. Reviewed with Thomas's approval on 2026-11-04 ([review](https://github.com/rails/rails/pull/59631#pullrequestreview-5775467814)): the cached override result doubles a `super`-based key (`"foo_#{super}"` → `foo_foo_id`, 8-1: `foo_id`), runtime-dynamic overrides go stale, and the test doesn't cover the issue's `id: false` table; checked by script against 8-1-stable |

Patches, bodies and the issue text are in [`bench/upstream/ecosystem/patches`](../../bench/upstream/ecosystem/patches) and
[`issues`](../../bench/upstream/ecosystem/issues).

- **E2 evidence:** reading table `Widgets` as `widgets` on 8-1, main and the fix gives columns `id, number` /
  StatementInvalid / `id, number`, and indexes and foreign keys 1 / 0 / 1. ransack loads with the fix and passes except
  for its gem-side `SelectManager` failure. A non-ASCII test keeps `Ärger` and `ärger` apart, because SQLite folds only
  ASCII. Mutation checks: an unchanged foreign-key reader, an `index_by` helper and plain `downcase` each fail a test.
- **E2b evidence:** on 8-1 every reader sees the temporary table once; on main `primary_key` becomes
  `["temp_id", "temp_id"]` and a temporary view's columns come back twice. The tests fail on main. A temporary index
  named like the table leaves it readable on all three trees. The temp table's `COLLATE NOCASE` column reads as nil on
  8-1 and main (both parse the permanent CREATE statement) and as NOCASE with the fix; that assertion catches a fix
  that lets the permanent table win. Mutations of the first E2b (any temp object hides) and of a type filter on one
  side only fail the index/trigger test.
- **E2b fix:** a skeptic found that `472c680d15`, which listed `sqlite_temp_master` first, made a permanent partial
  index lose its `where` when a temporary index shared its name (main kept it), because `index_details` takes the
  first statement per index name. `52c21b2fa4` lists `sqlite_master` first again; the "not hidden" test's partial
  index fails on `472c680d15` and passes on main. That first-statement order is a tie in `ORDER BY m.name, i.seqno`
  and comes out of order with `PRAGMA threads > 0` on a spilling batch (328 of 1000 `where`s lost, the same on main);
  E2c removes the dependence. Full `test:sqlite3` on `3029db3847` (same code as `52c21b2fa4`): 10,287 runs, 0
  failures, 0 errors.
- **E2 stacked on E2b:** Sol found that E2 alone, with a permanent `Widgets` and a temporary `widgets`, lists both,
  and the pragmas resolve both to the temporary table: columns, indexes and primary keys twice, and the CREATE
  statement of the permanent table. E2 is now one commit on E2b that also makes E2b's hiding check `COLLATE NOCASE`.
  Its test asks for both spellings and expects only the temporary columns, primary key, index and foreign key, with
  a collation only the temporary CREATE statement names. Without the NOCASE hiding check it fails on duplicated
  columns; with deduplicated rows instead, on the collation (nil). A second test fails if a Unicode-aware `lower()`
  lets a temporary `ärger` hide a permanent `Ärger`. On `d9e614dcab` the hiding test runs with the permanent table in
  either case, because a mutant that kept the last stored-name group passed with one pairing. Merges cleanly into
  rails/rails main `1e235cee11`; full `test:sqlite3` 10,291 runs, 0 failures, 0 errors.
- **E2c evidence:** a permanent `shared_index` on `permanent_items (number) WHERE number > 0` and a temporary one on
  `temporary_items (label)`. `indexes` gives `permanent_items` columns / `where`: `label` / `number > 0` on 8-1-stable,
  `label, label` / `number > 0` on main and on the fixed E2b, `number` / `number > 0` with the fix; for
  `temporary_items` `label` with `where` `number > 0` on 8-1, main and E2b, nil with the fix. The test fails on main, on E2b, with the
  schema passed but statements keyed by name, and with statements keyed by schema but `pragma_index_info`
  unqualified, and passes with the CTE's UNION order reversed. Merged with E2 `d9e614dcab`, the sqlite3 adapter tests
  pass (237 runs). Full `test:sqlite3` on `201397231e` (tree of `4d1fa492ce`): 10,288 runs, 0 failures, 0 errors.
- **Round 3 (Sol, Astra on `52c21b2fa4` / `d9e614dcab` / `4d1fa492ce`):** all three rebuilt on main `1e235cee11`.
  E2b `bc90b487f2` drops the tie-order `where` assertion (E2c asserts it deterministically), adds a permanent view
  hidden by a temporary table and by a temporary view (the mutant `type != 'table'` fails it; main returns the
  columns twice), and asserts that check constraints come from the temporary CREATE statement. E2 `63d1880397` is
  rebased; E2c `6c80a5583b` is now stacked on E2, because with schema-qualified index pragmas but E2b's case-sensitive
  hiding, a permanent `Gizmos` beside a temporary `gizmos` read the permanent table's indexes (main reads the
  temporary one's); its new test fails without E2's NOCASE hiding. Full `test:sqlite3`: 10,293 / 10,297 / 10,299 runs,
  0 failures, 0 errors. Buildkite build 136240 on `52c21b2fa4`: the failed "activerecord postgresql (4.0)" job had 21
  `FieldOrderedValuesTest` FK errors, fixed on main by a712a0a9bc, which `8b06b0eb98` lacked; the stack now includes it.
  Skeptic on the three heads: no must-fix. Dropping the schema from `pragma_index_list` is an equivalent mutant: the
  hiding already makes the unqualified name resolve to the row's table, and SQLite allows no temp index on a permanent
  table; the argument stays for symmetry, guarded by `test_indexes_logs`.
- **E4 evidence:** minitest 5.15.0 through 5.17.0 define neither `assert_pattern` nor `refute_pattern`; 5.18.0 adds both.
  Main without the alias loads with minitest 5.10.3. With the floor, AMS gets a Bundler conflict instead of a
  NameError. Its suite still runs 0 tests on main because of the deliberate route removal below.
- **Full `test:sqlite3`** on E2 and on E2b: 10,286 and 10,285 runs, 0 failures. The 5 errors are environmental:
  4 need the `sqlite3` CLI, 1 needs `pg`. On stacked E2 `c04df40d80` with the CLI installed: 10,291 runs, 0 failures,
  0 errors, 52 skips.

## SQLite schema readers: follow-up candidates, not in E2/E2b/E2c

Found by Sol and Astra on the E2 stack (2026-11-05). All are on rails/rails main already; the stack doesn't make
them worse.

- **Attached databases:** `MASTER_CTE` reads `sqlite_master` (= `main`) and `sqlite_temp_master` only, so a table
  that exists only in an attached schema is invisible to the batched readers (`columns`, `indexes` give nothing).
- **`build_index` regex:** `ON\b\s*"?(\w+?)"?\s*\(` matches only `\w+` table names, so the `where` and expression
  columns of partial and expression indexes on quoted names with other characters are lost.
- **`table_structure_sql`** (`sqlite3_adapter.rb`, used by `table_structure` in the alter/copy paths) looks up the
  CREATE statement with its own exact-name, main-first `UNION ALL`. Through the public API: `change_column_default`
  on table `Widgets` named as `widgets` raises `Could not find table 'widgets'` on main; with E2 it succeeds and keeps
  the collation, auto-increment and check constraint (8-1-stable drops all three). On 8-1 and with E2 the copied table
  comes back named `widgets`, not `Widgets` (pre-existing rename in `alter_table`).

## Deliberate changes, recorded without a Rails PR

- **Frozen `default_url_options`** (baa1ca5f2f) breaks rspec-rails 8.0.4 mailer and feature specs. rspec-rails main
  already merges instead of mutating, but no release includes it.
- **Frozen `ViewPaths#_prefixes`** (fd5ffed45b) breaks rspec-rails 8.0.4 view specs. rspec-rails main handles it
  (#2915, 570b2b0a79), unreleased.
- **`PathSet#find` returns one template** (9987431315), so rspec-rails 8.0.4's `ResolverDecorator`, which nullifies only
  Enumerable results, renders real templates in controller specs. rspec-rails main adapted (#2927, 2d5985ea6e), unreleased.
- **Dynamic `:controller` routes removed** (92d809905b, CHANGELOG): the dummy apps of rails-controller-testing and AMS.
- **Frozen `Relation::VALUE_METHODS`** (c10c3c5bf4): a draper spec stubs it.
- **Frozen dependency-tracker registry** (73bdeced4f, CHANGELOG): view_component's tests write the private ivar.
- **`Arel::Table.new` keyword name** (b1650993b0): covered by #59574. With it applied, administrate's
  `order_spec.rb` passes (24 examples; 14 failures on main), and `lib/administrate/order.rb:134` gets the deprecation.

## Gem-side leads (not filed)

- ransack requires `active_support/core_ext` without `active_support` first (E1, now G1; see above).
- ransack calls `Arel::SelectManager.new(Class)`. Since dd25a8150f the argument must respond to `klass`.
- view_component: `TemplateDetails::Requested#locale` (621b50a9a3, `:nodoc:`), allocation counts pinned per Rails
  version (main allocates fewer), and `with_request_url` doesn't reset the host memos added in 5edbac28ff. Its
  nokogiri pin 1.19.4 can't resolve against loofah ≥ 2.25.3.
- AMS pins `minitest < 5.11` for development. cancancan caps bundler at `~> 2.0` and needs `ostruct` on Ruby 4.
  paper_trail caps Active Record below 8.2.
- Harness: `Appraisal::Gemfile` has no `eval_gemfile`, so gems that require appraisal at runtime need `require: false`
  or `CI=1`.
