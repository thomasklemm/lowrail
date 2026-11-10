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
| E3 | `ActiveSupport::LogSubscriber.colorize_logging` removed without a deprecation (aebcb61520); awesome_print 1.9.2 raises on load, administrate does not boot | deprecated delegators to `ActiveSupport.colorize_logging` | `thomasklemm/log-subscriber-colorize-logging-deprecation` @ `a1f602b82e` | rails/rails#59628 closed 2026-11-10 (few callers outside vendored copies) |
| E4 | `alias :assert_not_pattern :refute_pattern` (23420be739) needs minitest 5.18; the gemspec allows 5.1 | define the alias only if `refute_pattern` exists; no dependency bump | `thomasklemm/activesupport-minitest-floor` @ `b36c144182` | draft rails/rails#59676; conditional requested by matthewd; exact head/body approved by skeptic and pushed, awaiting coordinator Sol/Astra |
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
- **E4 evidence (original floor proposal, superseded by the conditional below):** minitest 5.15.0 through 5.17.0
  define neither `assert_pattern` nor `refute_pattern`; 5.18.0 adds both. Main without the alias loads with minitest
  5.10.3. The floor changed AMS's NameError into a Bundler conflict; the conditional restores loading instead.
  AMS's full suite has a separate deliberate route-removal blocker below; no full-suite pass is claimed.
- **Full `test:sqlite3`** on E2 and on E2b: 10,286 and 10,285 runs, 0 failures. The 5 errors are environmental:
  4 need the `sqlite3` CLI, 1 needs `pg`. On stacked E2 `c04df40d80` with the CLI installed: 10,291 runs, 0 failures,
  0 errors, 52 skips.

## SQLite schema readers: follow-up candidates, not in E2/E2b/E2c

Found by Sol and Astra on the E2 stack; investigated through public APIs on 2026-11-05. **None merits a new PR
in this round.** The attached-only table failure is a real regression in an incompletely supported configuration;
the index parser limitation was explicitly declined upstream; the old CREATE lookup is bypassed by production
schema readers on main. E2b, E2 and E2c remain unchanged. No new topic branch or queue item, and no upstream post.

Pins: Rails main `1e235cee11b0a7aecb189d8837534807626287aa`, 8-1-stable
`6e091242176c322edc5a8907583c01b08b8a60bc`, and the complete E2b → E2 → E2c stack
`6c80a5583bcaf5f0f869eb8efa6ec7e210f3b51f`. The same probes also ran immediately before and after the batching
change: `c8d223147de1907b4bd3779b5733a55ab9ba9858` and `2cb3daba96decf29d1009621a244677630aad9a4`.
All used Ruby 4.0.9 (`3e93b23afc`) and sqlite3 gem 2.10.2, SQLite 3.54.1, with independent in-memory connections.

### Attached databases: regression, but not a support expansion

With `ATTACH DATABASE ':memory:' AS extra`, a table created as `extra.attached_items` is usable as unqualified
`attached_items` in SQL. Both `tables` and `SELECT * FROM attached_items` see it on every tested tree, but:

| Public reader of unqualified `attached_items` | 8-1-stable / parent of batching | batching commit / main / complete stack |
| --- | --- | --- |
| `columns` | id, number | StatementInvalid: Could not find table |
| `primary_key` | id | StatementInvalid: Could not find table |
| `indexes` | attached_number, columns [number], **where nil** | [] |
| `check_constraints` | [] | [] |

Reproducer setup (then call the readers above):

```ruby
connection.execute("ATTACH DATABASE ':memory:' AS extra")
connection.execute('CREATE TABLE extra.attached_items ("id" integer PRIMARY KEY, "number" integer, CONSTRAINT positive CHECK (number > 0))')
connection.execute('CREATE INDEX extra.attached_number ON attached_items (number) WHERE number > 1')
```

This isolates the regression to `2cb3daba96`: `MASTER_CTE` cannot supply the table row for the joined pragma.
It does **not** establish that attached schemas were supported before: 8-1-stable already loses the partial
predicate and check constraint, and `columns("extra.attached_items")` raises a SQLite syntax error (main raises
Could not find table). Conversely, ordinary model CRUD really did work: with an attached-only `(id, number)` table,
`AttachedItem.create!(number: 4)` followed by `AttachedItem.find(item.id).number` returns 4 on stable and the parent
of batching; batching/main/the stack raise Could not find table. Incomplete schema introspection did not prevent
that useful behavior.

The [earlier investigation by the author of an attached-schema patch](https://github.com/rails/rails/pull/35339#issuecomment-466265426)
describes discovering that support had not actually worked as claimed; this is not a formal maintainer support
ruling. The [separate open proposal](https://github.com/rails/rails/pull/57337) would add automatic attachment and
cross-database model joins, not fix this reader alone.

**Decision:** park this real regression pending an affected production caller. Searches found raw-SQL/SQLite
ATTACH users, not a confirmed app or released gem relying on these Active Record readers. Blindly appending every
attached schema to the CTE would need schema identity, attachment order and shadowing handled correctly. A narrow
fallback to the old pragmas for missing column/primary-key results is plausible, but has not been established as
an exact fix for all affected readers. Do not claim that a narrow restoration is impossible, or that the older
metadata limitations made model CRUD unusable. No support expansion or speculative fallback is built this round.

### Quoted table names: long-standing, explicitly declined

For each of `assessments/quizzes`, `line items` and `quote"items`, public `create_table` and `add_index` succeed.
After `add_index(name, :number, name: "partial", where: "number > 0")`, `indexes(name)` reports columns `["number"]`
but `where: nil`. Add `add_index(name, "number % 10", name: "expression", where: "number > 1")` and `indexes(name)`
raises `NoMethodError: undefined method 'size' for nil`; `change_column_default(name, :number, 2)` then raises the
same error while copying indexes. The ordinary-name control `ordinary_items` preserves both predicates and the
expression, and changing its default succeeds. These results are identical on all five pinned trees above.

The `ON\b\s*"?(\w+?)"?\s*\(` regex predates batching; `build_index` merely inherited it. This is not a new E2-stack
regression. A real user already reported the slash-name partial-index loss in
[rails/rails#55627](https://github.com/rails/rails/issues/55627); fatkodima
[identified this exact regex and said it was not worth fixing](https://github.com/rails/rails/issues/55627#issuecomment-3262902799),
recommending underscores instead. The issue is closed as not planned.

**Decision:** no regex PR. A broader identifier matcher might repair these examples, but would reopen a known
maintainer decision without new real-application evidence. The expression-index exception is recorded, not hidden
as merely a missing `where`. No patch, passing-fix claim or mutation-test claim is made for this declined lead.

### `table_structure_sql`: old limitation, not a separate public regression on main

The helper still has an exact-name, main-first lookup. However, since batching, public `columns` uses
`fetch_column_definitions` → `table_structures`, and public primary/foreign-key readers use `table_structures` too.
`copy_table` calls those public readers. The surviving `table_structure` / `column_definitions` alias goes through
the old helper, but main overrides the generic `fetch_column_definitions` that would call it. The only direct
Rails caller found outside that helper chain is the test-only `column_names` helper in
[`copy_table_test.rb`](https://github.com/rails/rails/blob/1e235cee11b0a7aecb189d8837534807626287aa/activerecord/test/cases/adapters/sqlite3/copy_table_test.rb#L100-L102),
which sends the private `table_structure` method to get column names.

Public repro: create `Widgets` with an auto-increment id, `label COLLATE NOCASE`, `number`, and named check
`positive` (`number > 0`), then `change_column_default("widgets", :number, 2)`:

| | 8-1-stable / parent of batching | batching commit / main | complete stack |
| --- | --- | --- | --- |
| Result | succeeds | StatementInvalid: Could not find table 'widgets' | succeeds |
| label collation / named check after copy | nil / absent | no copy | NOCASE / positive |
| id auto-increment after copy | true (re-created) | no copy | true |
| stored table name after copy | widgets | Widgets (unchanged) | widgets |

`TracePoint(:call)` around that public operation records **zero** `table_structure_sql` calls on main and the
stack (3 and 8 `table_structures` calls respectively); 8-1-stable calls the old helper 7 times. An ordinary
`change_column_default("items", :number, 7)` control succeeds on every tree: main/stack call `table_structures`
8 times and the old helper zero times; stable calls the old helper 7 times. The lowercase-name failure belongs
to E2 and is already fixed by it, not by changing `table_structure_sql`. The earlier note that stable drops
auto-increment after this copy was too broad: the copied id is re-created with auto-increment.

As a sensitivity control, replacing `table_structure_sql` with a method that always raises leaves every public
probe's JSON result identical on main and the stack; the ordinary stable default-change control then raises.
This is a reachability check, not a passing mutation-tested fix.

**Decision:** no independent PR, and no stack dependency to add. Changing an unused private lookup would not fix
an additional demonstrated public bug. Keep the helper and existing private-API tests untouched rather than mix
cleanup or new compatibility promises into the E2 stack.

### Follow-up verification

Full `activerecord` `rake test:sqlite3`, Ruby 4.0.9, sqlite3 2.10.2 / SQLite 3.54.1, with
`PARALLEL_WORKERS=2 MT_CPU=2`, each checkout's component `lib` directories on `RUBYLIB`, and the same installed
gem environment (unbundled): main **10,289 runs, 36,772 assertions, 0 failures, 0 errors, 52 skips** (seed 42172);
8-1-stable **9,454 runs, 32,213 assertions, 0 failures, 0 errors, 45 skips** (seed 62823). Main's SQLite adapter file
alone: 110 runs, 269 assertions, 0 failures, 0 errors. These are clean-baseline suites, not tests of a new fix.
No new Rails patch means no new fix-versus-main or fix-mutant claims. A skeptical subagent independently reproduced
the five-tree probes and identified the attached-table model CRUD regression above; that evidence is included in
the decision to park it rather than dismiss it as unusable before batching. Sol and Astra remain the coordinator's
responsibility if any of these leads is reconsidered.

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

## Queue skeptic refresh (2026-11-05)

**E4: skeptic approved exact head `0a69eb6cce5fa6a7956d2ceddaa207e14fbdc459`; ready for the coordinator's Sol
pass, not yet fully reviewed.** The fork branch is unchanged. Against fetched Rails main
`1e235cee11b0a7aecb189d8837534807626287aa`, the two-line patch still applies and merges cleanly: the gemspec
and PATH lockfile dependency both become `minitest >= 5.18`; the locked minitest stays 6.0.6. Original commit
`23420be739d255f51b00f3c8eb54248e0d21d06d` introduced the unconditional alias, and
`07ac43aaefa1451c3076c317034880561b3c8e23` is the cited dependency-floor precedent. No runtime method changes,
new comments or method-complexity delta.

Fresh public loading checks on **Ruby 3.3.13** (minitest 5.18.0 declares Ruby < 4.0):

| Active Support source | minitest 5.10.3 | minitest 5.17.0 | minitest 5.18.0 |
| --- | --- | --- | --- |
| released 8.1.4.1 | loads | not rerun | loads |
| fetched main | NameError | NameError | loads |
| exact E4 head | NameError when bypassing resolution | NameError when bypassing resolution | loads |
| same main + E4 | NameError when bypassing resolution | NameError when bypassing resolution | loads |
| main with only the alias removed in memory | loads | not rerun | loads |

The negative case is `undefined method 'refute_pattern' for class 'ActiveSupport::TestCase' (NameError)` at
`active_support/test_case.rb:372`. The alias-removal control clears the `ActiveSupport::TestCase` autoload
before evaluating the file without that one alias; otherwise evaluating the class can autoload the original
file and invalidate the control. Checks load the real component through `-I <tree>/activesupport/lib`:

```ruby
gem "minitest", "5.10.3"
require "active_support"
require "active_support/test_case"
```

Minimal resolver reproduction, **Bundler 2.5.22 on Ruby 3.3.13**, using the actual source gemspec:

```ruby
source "https://rubygems.org"
gem "activesupport", path: "#{ENV.fetch('RAILS')}/activesupport"
gem "minitest", ENV.fetch("MT", "5.10.3")
```

`RAILS=<main> bundle lock --local` exits 0, then `bundle exec ruby` with the public loading code above raises
the NameError. With `RAILS=<E4>` or `<main+E4>`, the same `bundle lock --local` exits **6**:

```
Because every version of activesupport depends on minitest >= 5.18
  and E4.Gemfile depends on activesupport >= 0,
  minitest >= 5.18 is required.
So, because E4.Gemfile depends on minitest = 5.10.3,
  version solving has failed.
```

With `MT=5.18.0`, main+E4 resolves and loads. A fresh lockfile under **Bundler 4.0.20, Ruby 4.0.9** and
`MT='>= 5.18'` selects installed minitest **6.0.6** and loads exact E4. The floor is an API floor, not a claim
that minitest 5.18.0 installs on every supported Ruby.

The skeptical reviewer independently checked minitest's release history/API, the original Rails commits,
the lockfile consistency, and the exact AMS 0.10.16 caller permalink at line 42 (also the current
`0-10-stable` SHA). Its two wording nits were applied: label the load-only table and Ruby pin; do not present a
path-source-specific solver quotation as a universal statement about Active Support history. The revised body
received `approve` on the same exact head. Cold read: declare the version already required by the unconditional
alias, so incompatible combinations fail at resolution rather than test-case loading. This does **not** fix AMS's
separate deliberate dynamic-route removal. No upstream PR or issue action; no Sol/Astra run here.

## Queue Sol follow-up (2026-11-05)

The coordinator reported Sol `changes` on `0a69eb6cce5fa6a7956d2ceddaa207e14fbdc459`. Added an attributed
entry at the top of Active Support's changelog: "Active Support now requires minitest 5.18 or newer."
New head **`3386b8e5bf002a930dca960f6a4ecd49659dc9df`** changes only those four lines from the previous
head; the gemspec and lockfile patch is unchanged. The body now scopes the conflict to incompatible pins
such as AMS's `< 5.11`, says Ruby 4 resolution must select a later Ruby-compatible release, identifies the
tested main SHA in the load-only table and removes the precedent discussion and excess footer wording.

Fresh resolver controls on the exact new head, against the same fetched main
`1e235cee11b0a7aecb189d8837534807626287aa`, use separate Gemfiles/lockfiles and the actual source gemspec:

```ruby
source "https://rubygems.org"
gem "activesupport", path: "#{ENV.fetch('RAILS')}/activesupport"
gem "minitest", *ENV.fetch("MT", ">= 0").split(",")
```

With `BUNDLE_GEMFILE=<case> RAILS=<tree> MT='<constraints>'` set for both commands, run `bundle lock --local`,
then on success `bundle exec ruby -e 'require "active_support"; require "active_support/test_case"; puts "loads minitest #{Gem.loaded_specs.fetch("minitest").version}"'`.
The explicit Active Support prelude matches the earlier loading checks; omitting it on Ruby 4 instead fails
on the unrelated `DescendantsTracker::WeakSet` dependency before reaching the alias.

| Ruby / Bundler | Tree and minitest constraint | Resolve exit | Public load |
| --- | --- | ---: | --- |
| 3.3.13 / 2.5.22 | main, `~> 5.0,< 5.11` | 0 | NameError: `refute_pattern`, exit 1 |
| 3.3.13 / 2.5.22 | exact E4, `~> 5.0,< 5.11` | 6 | not run: incompatible `>= 5.18` and `< 5.11` |
| 3.3.13 / 2.5.22 | exact E4, `5.18.0` | 0 | loads minitest 5.18.0 |
| 3.3.13 / 2.5.22 | exact E4, `>= 0` | 0 | loads minitest 5.20.0 |
| 4.0.9 / 4.0.20 | exact E4, `>= 0` | 0 | loads minitest 6.0.6 |

A fresh skeptic reviewed the complete new-head patch and revised body: **approve, no remaining nits**;
every Sol finding is addressed. `git diff --check` passes and `git merge-tree --write-tree <main> <head>`
succeeds. No runtime change or new full-suite claim; only coordinator Sol confirmation remains. No upstream
PR/issue action, and no Sol/Astra execution by this orb.

## E4 conditional follow-up (2026-11-06)

After [matthewd reopened the draft and requested a conditional](https://github.com/rails/rails/pull/59676#issuecomment-6681047216),
replaced the floor proposal with one clean commit, `b36c144182e41dcc676da3c6a51344d6f66da97a`, on current Rails
main `cadf0fc8d6d48cefaa07e4bd6cc5dcd8347821b2`. The gemspec and lockfile are identical to main: minitest remains
`>= 5.1`. `assert_not_pattern` is aliased only if `method_defined?(:refute_pattern)`, matching Rails' existing
capability checks for minitest API differences (`run_order`, `load`, `run_one_method`). The existing pattern test
skips only when `assert_pattern` is unavailable and now also checks rejection of a matching pattern. No tests of
method ownership, alias identity, or other internals were added. A top-of-file, attributed Active Support changelog
entry is warranted: the fix restores loading with declared-supported dependencies rather than requiring an upgrade.

### Public loading and assertion behaviour

On Ruby 3.3.13, activate the exact minitest version, add the checkout's `activesupport/lib` to the load path, then:

```ruby
gem "minitest", ENV.fetch("MT")
require "active_support"
require "active_support/test_case"
```

| minitest | Unmodified current main | Conditional fix | `assert_not_pattern` with fix |
| --- | --- | --- | --- |
| 5.1.0 | `refute_pattern` NameError | loads | absent |
| 5.10.3 | same NameError | loads | absent |
| 5.17.0 | same NameError | loads | absent |
| 5.18.0 | loads | loads | mismatch passes; matching pattern raises `Minitest::Assertion` |
| 6.0.6 | loads | loads | same passing and failing behaviour |

Checked all `refute_*` alias targets against a representative release of every minor from minitest 5.1 through
5.17. Only `refute_pattern` is absent; the original `23420be739` introduced no other aliases. For 5.13.0 and 5.14.0,
whose gem metadata restricts Ruby to 2.x, this was a source/API inspection, not an installed-gem loading claim.
The minitest 5.18.0 `History.rdoc` confirms that both pattern assertions were added in that release. Inspection of
the recent helper conditionals and execution of the notification and event reporter assertion tests found no
additional version-dependent loading failure to include in this patch.

### Active Support tests

Ran the real `test/test_case_test.rb`, `test/testing/notification_assertions_test.rb`,
`test/testing/event_reporter_assertions_test.rb` and `test/testing/after_teardown_test.rb` together, with
`PARALLEL_WORKERS=1`. A temporary minimal `BUNDLE_GEMFILE` uses the actual Active Support path gemspec, the exact
minitest version, rake and (for minitest 6) minitest-mock. Both `activesupport/lib` and `railties/lib` are on the
load path, so the real Rails minitest plugin runs; no framework methods or reporters are stubbed.

| Ruby | minitest | Runs | Assertions | Failures / errors / skips |
| --- | --- | ---: | ---: | --- |
| 3.3.13 | 5.1.0 | 93 | 378 | 2 / 0 / 1 |
| 3.3.13 | 5.10.3 | 93 | 378 | 2 / 0 / 1 |
| 3.3.13 | 5.17.0 | 93 | 385 | 0 / 0 / 1 |
| 3.3.13 | 5.18.0 | 93 | 389 | 0 / 0 / 0 |
| 3.3.13 | 6.0.6 | 93 | 390 | 0 / 0 / 0 |
| 4.0.9 | 6.0.6 | 93 | 390 | 0 / 0 / 0 |

The single skip is the unavailable pattern assertion. The two failures on 5.1.0 and 5.10.3 are
`ExceptionsInsideAssertionsTest#test_warning_is_logged_if_caught_internally` and
`#test_fails_and_warning_is_logged_if_wrong_error_caught`. Old minitest defines `UnexpectedError#exception`, so
Ruby's `raise` unwraps the original `ArgumentError`. Public probes reproduce both outcomes unchanged on Rails
v8.1.4.1: `assert_nothing_raised { raise ArgumentError }` raises `ArgumentError`, and an outer
`assert_raises(ArgumentError)` around `assert_no_changes` passes. Those tests date to `4b42beb3b8` (2021), not the
pattern-alias regression; they are not suppressed or changed here. The three other helper files alone on minitest
5.10.3 pass: **26 runs, 119 assertions, no failures, errors or skips**.

### AMS caller and review scope

Checked active_model_serializers **v0.10.16**, exact source
`6934c8bd31f4025fe7548a07d50a82f18df8e689`, with its actual runtime dependencies, current Rails path gems and
minitest **5.10.3**, which satisfies its development pin. The test helper's require chain is:

```ruby
require "rails"
require "action_controller"
require "action_controller/test_case"
require "action_controller/railtie"
require "active_model_serializers"
```

On unmodified current main this raises the `refute_pattern` NameError from `ActionController::TestCase` loading
`ActiveSupport::TestCase`. On the fix it loads AMS 0.10.16 / Rails 8.2.0.alpha / minitest 5.10.3, and an inherited
`assert_not_equal` passes. This checks the failing load path, **not the full AMS suite**; no dummy routes or gem
source were patched. The earlier deliberate dynamic-route-removal blocker remains outside this fix.

The proposed title/body is two short prose paragraphs plus the unchanged research footer, retaining the exact
AMS dependency permalink. The live draft title/body matched the old queue item byte-for-byte before replacement;
they matched again immediately before the GitHub update. The fork branch is force-pushed with an exact old-head
lease and the live title/body updated; the PR remains an open draft, with no comment posted. Independent skeptic:
**approve on the exact head and body, no must-fixes, should-fixes or nits**. The reviewer independently ran the
cross-version alias API audit and inspected source and execution logs, but did not rerun the suites or AMS probe.
Old queue passes stay as history, not coverage of this new patch. Sol and Astra remain the coordinator's next
step. No hosted CI pass is claimed; this thread subscribes to completion for the exact pushed fork head.
