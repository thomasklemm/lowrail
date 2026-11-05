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
| E2 | the batched SQLite readers match table names exactly (2cb3daba96), so a table created as `Widgets` is not found as `widgets` | `COLLATE NOCASE` plus rows keyed by each requested name, and E2b's hiding check `COLLATE NOCASE` too; stacked on E2b | `thomasklemm/sqlite-schema-readers-table-name-case-stacked` @ `c04df40d80` (unstacked `bf905ad4f6` before) | reviewed: Sol, Astra approve, Sol confirms c04df40d80 ([item](../../bench/upstream/pr-queue/items/E2.md)) |
| E2b | the same readers list a temporary table or view and the permanent table it hides, so columns and indexes are duplicated and the primary key becomes composite (2cb3daba96) | in `MASTER_CTE`, a temporary table or view hides a permanent one; temporary indexes and triggers hide nothing | `thomasklemm/sqlite-schema-readers-temp-shadowing` @ `472c680d15` | Sol: open with nits; queued |
| E2c | the same readers read index columns with an unqualified `pragma_index_info(name)` and match CREATE INDEX statements by name, so a permanent index with a temporary namesake reads the temporary index's columns twice (2cb3daba96; 8-1-stable read them once, also from the temporary index) | `MASTER_CTE` rows carry their schema, passed to `pragma_index_list` and `pragma_index_info`; index statements keyed by schema and name; stacked on E2b | `thomasklemm/sqlite-index-details-schema` @ `cd90c26ce8` | built ([item](../../bench/upstream/pr-queue/items/E2c.md)) |
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
- **E2 stacked on E2b:** Sol found that E2 alone, with a permanent `Widgets` and a temporary `widgets`, lists both,
  and the pragmas resolve both to the temporary table: columns, indexes and primary keys twice, and the CREATE
  statement of the permanent table. E2 is now one commit on E2b that also makes E2b's hiding check `COLLATE NOCASE`.
  Its test asks for both spellings and expects only the temporary columns, primary key, index and foreign key, with
  a collation only the temporary CREATE statement names. Without the NOCASE hiding check it fails on duplicated
  columns; with deduplicated rows instead, on the collation (nil). A second test fails if a Unicode-aware `lower()`
  lets a temporary `ärger` hide a permanent `Ärger`. Merges cleanly into rails/rails main `1e235cee11`.
- **E2c evidence:** a permanent `shared_index` on `permanent_items (number) WHERE number > 0` and a temporary one on
  `temporary_items (label)`. `indexes` gives `permanent_items` columns / `where`: `label` / `number > 0` on 8-1-stable,
  `label, label` / `number > 0` on main, `label, label` / nil on E2b, `number` / `number > 0` with the fix; for
  `temporary_items` `label` with `where` `number > 0` on 8-1 and main, nil with the fix. The test fails on main, on E2b, with the
  schema passed but statements keyed by name, and with statements keyed by schema but `pragma_index_info`
  unqualified. Merged with E2 `c04df40d80`, the sqlite3 adapter tests pass (237 runs). Full `test:sqlite3` on
  `cd90c26ce8`: 10,288 runs, 0 failures, 0 errors, 52 skips.
- **E4 evidence:** minitest 5.15.0 through 5.17.0 define neither `assert_pattern` nor `refute_pattern`; 5.18.0 adds both.
  Main without the alias loads with minitest 5.10.3. With the floor, AMS gets a Bundler conflict instead of a
  NameError. Its suite still runs 0 tests on main because of the deliberate route removal below.
- **Full `test:sqlite3`** on E2 and on E2b: 10,286 and 10,285 runs, 0 failures. The 5 errors are environmental:
  4 need the `sqlite3` CLI, 1 needs `pg`. On stacked E2 `c04df40d80` with the CLI installed: 10,291 runs, 0 failures,
  0 errors, 52 skips.

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
