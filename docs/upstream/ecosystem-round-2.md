# Ecosystem round 2: 26 more gem suites on Rails main (2026-11-04)

Second round of the gem-suite comparison started in round 1 (Lowrail branch `thomasklemm/ecosystem-tests`,
`bench/upstream/ecosystem`, whose harness `eco.sh`, `Gemfile.eco` and `eco-locks.rb` was reused unchanged).
Each gem's own test suite ran twice against Rails 8-1-stable and twice against Rails main, with Ruby 4.0.9 and
identical locks except Rails. A failure counts only if it fails in both main runs and passes in both 8-1 runs.

**Result:** 10 of 26 gems show failures that are new on main, from 17 distinct Rails commits. None is a plain
Rails regression worth a fix PR: one unintended behaviour change (R2-1) is too narrow for the change a full fix
needs; the rest are deliberate changes, private API or already fixed in the gem. No gem hit
the `DescendantsTracker::WeakSet` load-order NameError.

## Setup

| | |
| --- | --- |
| Rails 8-1-stable | `6e09124217` (8.1.4.1) |
| Rails main | `e64f5a4258` (2026-11-04); fix checks on `7a78da5a55` |
| Ruby | 4.0.9 (mise), Bundler 4.0.20 |
| Lock difference | only gems Rails main itself adds or bumps: herb, marcel 1.2.1 → 2.1.0, psych, ractor-dispatch, stringio |
| Databases | SQLite, PostgreSQL 15, MariaDB 10.11 (mysql2 and trilogy), Redis, Memcached |
| Seed | 4242 where the runner takes one |

MariaDB is new compared with round 1, so MySQL configurations ran this time. Bisects used the merge-base
`8ae3d84277` as the good end (verified good) unless noted.

## Gems

Round 1 already covered devise, pundit, cancancan, good_job, solid_queue, kaminari, pagy, paper_trail,
view_component, simple_form, draper, jbuilder and turbo-rails. This round took the rest of the suggested pool plus
seven widely used gems with deep Active Record or Action Pack integration.

| Gem | Version | DBs | 81 (both runs) | main (both runs) | New on main |
| --- | --- | --- | --- | --- | --- |
| acts_as_list | 1.2.6 | sqlite, pg, mysql | 231 runs 0F | same | – |
| ancestry | 5.1.0 | sqlite, pg, mysql × 2 formats, 16 configs | 133 runs 0F | 1F 28–31E per config | R2-5 |
| closure_tree | 9.8.0 | pg, mysql, sqlite | 369 runs 0F | same | – |
| counter_culture | 3.14.0 | sqlite, pg, mysql | 219 ex 0F | same | – |
| paranoia | 3.1.0 (a950fe4981) | sqlite | 101 runs 0F ¹ | fails to load | R2-6 |
| acts_as_tenant | 2.2.2 | sqlite | 186 ex 0F | same | – |
| activerecord-import | 3.0.1 | sqlite, pg, mysql2, trilogy | 263 / 376 / 318 / 318 runs 0F | same | – |
| pg_search | 2.4.0 | pg | 278 ex 0F | same | – |
| scenic | 1.9.0 | pg | 111 ex 2F, acceptance 3 0F | 19F, acceptance 2F | R2-2 |
| strong_migrations | 2.8.0 | pg, mysql2, trilogy | 233 runs 1F 0E | 1F 2E (pg), 1F 10E (mysql) | R2-7, R2-8 |
| groupdate | 6.8.0 | pg, mysql, trilogy, sqlite, enumerable | 259 runs 0F | same | – |
| delayed_job_active_record | 4.1.11 | sqlite, pg, mysql2, trilogy | 103 ex 0F | same | – |
| audited | 5.8.0 | sqlite, pg, mysql | 221–224 ex 1F | same | – |
| mobility | 1.3.2 | sqlite, pg, mysql | 748 / 1277 ex 1–2F | same | – |
| store_model | 4.6.1 | sqlite | 504 ex 0F | fails to load; with `RAILS_ENV=test` 11F / 5F | R2-9 to R2-12 |
| money-rails | 3.0.0 | sqlite | 268 ex 1F | same | – |
| aasm | 6.0.0 | sqlite | 617 ex 5F | same | – |
| will_paginate | 4.0.1 | sqlite, pg, mysql | 144 ex 0F | 144 ex 2F | R2-13, R2-18 (found later, by the readiness runner) |
| bullet | 8.3.1 | sqlite | 286 ex 0F | same | – |
| carrierwave | 3.1.4 | sqlite | 1788 ex 1F, 42 scenarios | same | – |
| shrine | 3.10.2 | sqlite | 1537 runs 0F | 2F | R2-14 |
| factory_bot_rails | 6.5.1 | sqlite | 12 ex, 2 runs, 26 scenarios 0F | same | – |
| shoulda-matchers | 8.0.1 | sqlite, pg | 3097 / 3159 ex 0F, acceptance 10 0F | 2F, acceptance 1F | R2-1, R2-15 |
| solid_cache | 1.0.10 | sqlite, pg, mysql (8 configs) | 3096 runs 0F | 8F 16E | R2-16, R2-17 |
| solid_cable | 4.1.0 | sqlite, pg, mysql | 39 runs 0F | same | – |
| lograge | 0.15.1 | – | 134 ex 3F | 134 ex 7F | R2-3, R2-4 |

¹ paranoia 3.1.0 does not load on released Rails 8.1.4 either: `set_options_for_callbacks!` (private) gained a
leading `position` argument on 8-1-stable (b8d9773853). The comparison ran with a local arity check on both trees.

Failures on both trees are gem-side or environmental (Ruby 3.4 `Hash#inspect`, a test expectation for 8.1.4,
sequel and Mongoid specs without a server, a carrierwave Active Record spec) and are not counted.

Local edits, identical on both trees: gemspec upper bounds `< 8.2` relaxed (audited), `gem "ostruct"`
(activerecord-import, mobility), `appraisal require: false` (acts_as_tenant, shoulda-matchers, solid_cache), sqlite3
pin relaxed (will_paginate), Bundler `~> 2.0` relaxed and Bundler 4 test-helper adjustments (shoulda-matchers),
`aruba < 3` (factory_bot_rails), `minitest-mock` (solid_cache), database ports and credentials. Not run: postgis and
spatialite (activerecord-import), minio/S3 (shrine), Mongoid, DynamoDB and sequel variants.

## Findings

Classes: (a) Rails regression, (b) deliberate change, (c) private or nodoc API, (d) already fixed in the gem.

| ID | Gem | What breaks on main | First bad Rails commit | Class |
| --- | --- | --- | --- | --- |
| R2-1 | shoulda-matchers | `belongs_to` whose target table has no primary key: `record.user` and `record.user = nil` raise `UnknownPrimaryKey` on a record with a nil foreign key (8-1: `nil`) | 4af9822fae "Write association keys through routes" (rails/rails#59120) | (a), not built |
| R2-2 | scenic (and every gem extending `CommandRecorder` the same way) | `record(:create_view, args)` raises `wrong number of arguments (given 2, expected 3)`; `invert_*` now receive `(args, kwargs)`; `db:rollback` of a view migration fails | 3efea4e061 "Refactor `CommandRecorder` to store args and kwargs separately" (rails/rails#58239) | (b) + (c) |
| R2-3 | lograge | `remove_existing_log_subscriptions` finds nothing, so apps log Rails' `Processing by …` and `Completed 200 OK …` lines next to lograge's line | 4a4aae797d "Convert log subscribers in Action Pack to consume structured events" (rails/rails#55900), Action View in 46b8605fe8 | (b) + (c) |
| R2-4 | lograge (spec only) | `ExceptionWrapper.rescue_responses[...] =` raises `FrozenError` | 2a28075803 (rails/rails#57483) | (b) |
| R2-5 | ancestry | `self.validation_context =` is gone (`NoMethodError`), 770 failures across configs | 0f9d127083 "Remove unused private `validation_context=` writer" (rails/rails#58220) | (c); reported as ancestry#766, fixes in #769/#770 |
| R2-6 | paranoia | `ActiveRecord::Transactions::ACTIONS << :restore` raises `FrozenError` at load | 5700c17cb7 "Enable `Style/MutableConstant` cop with `literals` style" (rails/rails#57323) | (c) (`ACTIONS` is `# :nodoc:`) |
| R2-7 | strong_migrations 2.8.0 | `alphabetize_schema` wrapper calls `.sort_by(&:name)` on `columns(tables)`, which now returns a Hash for an Array argument | 23bb4cdd4b "Read the columns of many tables in one query" (rails/rails#58494) | (b) + (d) (fixed in d52e4ac) |
| R2-8 | strong_migrations 2.8.0 | session timezone stays `Etc/UTC` when that is the server default, and the gem only treats `"UTC"` as safe | 1e40c1fe66 "Only set Postgres timezone when needed" (rails/rails#57087) | (b) + (d) (fixed in eb88bcf) |
| R2-9 | store_model | dummy app boots in development without `environments/development.rb` and now raises | 5cffb7cf7e "Add environment config file existence check" (rails/rails#55813) | (b) (CHANGELOG) |
| R2-10 | store_model (spec only) | `connection.query` removed | c42b09d3d3 (rails/rails#56129) | (c) (`# :nodoc:`) |
| R2-11 | store_model | parent not set on read: generated readers no longer call the overridden `_read_attribute` | 2e191e5491 "Extract missing_attribute from generated reader" (rails/rails#59140) | (c) (`# :nodoc:`) |
| R2-12 | store_model | parent not set on write: generated writers no longer call the overridden `_write_attribute` | 0f6c0a05e2 "Inline `_write_attribute` in generated writer methods" (rails/rails#59191) | (c) (`# :nodoc:`) |
| R2-13 | will_paginate (spec only) | `helper.default_url_options[:controller] =` raises `FrozenError` | baa1ca5f2f "Freeze the Controller `default_url_options`" (rails/rails#58483) | (b), as in round 1 |
| R2-14 | shrine (spec only) | spec stubs `@columns_hash`; main reads `schema_context` | ae739c3854 "Extract model schema state into a schema context" (rails/rails#58437) | (c); a real json column behaves the same |
| R2-15 | shoulda-matchers (spec only) | `_reflections.delete` raises `FrozenError` | a791f84224 "Introduce CoW when adding Active Record reflections" (rails/rails#58668) | (c) (`Reflection # :nodoc:`) |
| R2-16 | solid_cache (spec only) | private `bypass_local_cache` removed | 4f594320e4 (rails/rails#57932) | (c) + (d) (fixed in 679c457) |
| R2-17 | solid_cache (spec only) | error reporter context gains a `:rails` key | a82c877c95 "Add Rails.app.revision" (rails/rails#56490) | (b) + (d) (fixed in 6ab8bdb) |
| R2-18 | will_paginate (spec only), pg and mysql | `associations should paginate` counts 4 queries instead of 2: two `SCHEMA` queries its SQL-text filter no longer recognizes | 23bb4cdd4b "Read the columns of many tables in one query" (rails/rails#58494), then ae739c3854 "Extract model schema state into a schema context" (rails/rails#58437) | (b), test-side |

### R2-1: belongs_to to a table without a primary key (held)

Since 4af9822fae, `BelongsToAssociation#initialize` takes the foreign key from the full association route, which
also resolves the target's primary key. When the target table has none, building the association raises, even
where nothing needs the target key:

| Call (users has no primary key) | 8-1-stable | main |
| --- | --- | --- |
| `Profile.new.user` | `nil` | `UnknownPrimaryKey` |
| `Profile.new.user = nil` | `nil` | `UnknownPrimaryKey` |
| `Profile.new(user_id: 1).user`, `user = User.new`, `build_user`, `includes(:user)` | `UnknownPrimaryKey` | `UnknownPrimaryKey` |
| saving or validating without touching the association | works | works |

The commit has no CHANGELOG entry and its PR does not mention the case. It is unintended, but narrow: such an
association can never load a record on either tree. **Not built.** Restoring the 8-1 line in `initialize`
(`reflection.foreign_key_definition.resolve_aliases(owner.class)`) brings back `Profile.new.user # => nil`, but
`user = nil` still raises: `replace_keys` now clears the reference through `route.write`, and building that route
resolves the target key. shoulda-matchers fails on the assignment, so the one-line change would not fix the gem.
A full fix needs a nil-write path that does not build the destination half of the route, which reshapes the
route design matthewd introduced (last touched by him on 2026-10-21, no open PR of his on these files). For an
association that cannot load anything on either tree, that is more change than the case is worth; an issue for
matthewd would need Thomas's OK. Repro:
`~/src/eco/agentD/no_pk_variants.rb` in the round-2 orb; the shoulda-matchers spec is
`spec/acceptance/active_record_integration_spec.rb:80`.

### R2-18: will_paginate's query count sees schema queries (found 2026-11-05)

Found by the [readiness runner](readiness.md) on main `7a78da5a55`, after this round: it fails
`./spec/finders/active_record_spec.rb:290` (`associations should paginate`, `execute(2).queries`) with
`expected 2 queries, got 4`.

| Run of that spec | 8-1-stable `6e09124217` | main `7a78da5a55` |
| --- | --- | --- |
| alone, seed 4242 or 1717, postgres or mysql | passes | fails (4 queries) |
| alone, either seed, sqlite3 | passes | passes |
| full suite, seed 4242 | passes | passes |
| full suite, seed 1717, postgres or mysql | passes | fails |

So order hides it. When an earlier example has already loaded the schema of the `developers_projects` join table
(seed 4242), the block runs only its two data queries on both trees. The round's single default-order run did
not see it either.

The block's data queries are the same on both trees: the `projects` join and the `topics` preload. The extra
two are `SCHEMA` queries for the join table, which will_paginate's counter drops only by SQL text
(`FROM pg_attribute`, `SHOW FULL FIELDS`, `PRAGMA`, …), not by the payload name:

| | 8-1-stable | main |
| --- | --- | --- |
| columns, postgres | `SELECT a.attname … FROM pg_attribute a …` (filtered) | `… FROM (SELECT DISTINCT ON (cls.relname) …) r JOIN pg_attribute a …` (counted) |
| columns, mysql | `SHOW FULL FIELDS FROM developers_projects` (filtered) | `SELECT … FROM information_schema.columns …` (counted) |
| primary key | not read in the block | `WITH tables AS (…) … pg_constraint … contype = 'p'`, or `information_schema.statistics … 'PRIMARY'` on mysql (counted) |

Bisected with the spec alone on postgres between the merge-base `8ae3d84277` and `7a78da5a55`, in two steps:

* 2 → 3: 23bb4cdd4b "Read the columns of many tables in one query" (rails/rails#58494, also R2-7). It changes
  the column query's shape for a list of tables; SQLite still reads `PRAGMA`, which is why sqlite3 passes.
* 3 → 4: ae739c3854 "Extract model schema state into a schema context" (rails/rails#58437, also R2-14).
  `SchemaContext::Attributes` builds the attribute builder at schema load, and that reads
  `primary_key_definition`, so the join model's primary key is now read when its schema loads, not when a
  record is first built. The commit says so ("Schema loading now populates most of the context").

Both are intended. The schema is read once per model and process, as before, and a schema cache dump still
covers it. The only cost an app could see is one primary-key query at schema load for a model whose primary key
it never used, such as a `has_and_belongs_to_many` join table. The fix belongs in will_paginate's spec:
filter on `payload[:name] == "SCHEMA"`. Open rails/rails PRs don't change it: #59530 ("Split SchemaContext and
SchemaContext::MappedTable") at `eabd9f003f` still counts 4. Not reported.

### Breadth notes for the coordinator

* **R2-2** is the widest break: `record` and `inverse_of` were made private and their arguments split in one
  release, with CHANGELOG entries. Gems that extend `CommandRecorder` this way break on `revert` and rollback: scenic
  (run here) and fx, whose default branch calls `record(:create_function, args, &block)` and defines
  `invert_create_function(args)` (read from source, not run). Neither scenic's default branch nor its tracker has
  a fix or report yet. **Reported 2026-11-04 as [scenic#466](https://github.com/scenic-views/scenic/issues/466)** (Thomas's OK).
* **R2-3** changes what every lograge user sees in their logs on upgrade. The Rails PR calls the old subscribers
  private API, so it is the gem's change to make; lograge has no issue or PR for it yet. **Reported 2026-11-04 as [lograge#407](https://github.com/roidrage/lograge/issues/407)** (Thomas's OK).
* No comment was posted anywhere; any comment on these gems' trackers needs Thomas's approval.
