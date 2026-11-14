# Active Record extension gems after rails/rails#59141 (2026-11-14)

Inventory of which widely used Active Record extension gems break on Rails main since tenderlove's
[rails/rails#59141](https://github.com/rails/rails/pull/59141) ("Use an Array for storing Active Record attributes",
merged 2026-11-11 as `1f32b09101`). Inventory only: nothing was opened, posted or filed.

**Result.** Of 22 gems run (33 suites), one breaks on main against #59141's parent: **activerecord-typedstore
1.6.0**, at its first model with `typed_store` (448 confirmed failures). tenderlove's fix
([byroot/activerecord-typedstore#114](https://github.com/byroot/activerecord-typedstore/pull/114)) landed on
2026-10-27 but is unreleased. With it the suite matches base. A grep of the top AR-related gems finds two database
adapters that break on #59141's new `slot` argument: **activerecord-postgis-adapter** (open PR fixes it) and
**activerecord-cockroachdb-adapter** (no fix or report). oracle-enhanced already followed. **No type (b) Rails
regression.** Every other suite gives identical results on both trees. mobility's large failure count comes from
rails/rails#59634, not #59141, and is already reported.

| Gem | Version / commit | Main vs parent | Class | Smallest repro | Existing report | Proposed next step |
| --- | --- | --- | --- | --- | --- | --- |
| activerecord-typedstore | 1.6.0 (`2f3fb98e65`); master `263050a196` | 1.6.0: 581 ex, 4/6F on parent, **454F** on main and on the merge `1f32b09101` (all `X has no attribute 'no_default' to define a reader for`). Master: 0/2F on both | (a) | [`03`](../../bench/upstream/ar59141/03-define-attribute-method.rb): `store :settings, accessors: [:color]`, then `Post.define_attribute_method("color")` raises `ArgumentError` from the merge on | fixed by tenderlove's [#114](https://github.com/byroot/activerecord-typedstore/pull/114) (merged 2026-10-27, unreleased; last release 1.6.0 is from 2024-02, and it allows `activerecord >= 6.1`, so it installs on 8.2) | none now; a 1.7.0 release is needed before 8.2. If none by the beta, Thomas decides whether to ask byroot |
| activerecord-postgis-adapter | 11.1.1 (28M downloads), not run | grep + repro: overrides private `new_column_from_field(table_name, field, _definitions)`; main passes a 4th `slot` | (a) | [`02`](../../bench/upstream/ar59141/02-adapter-new-column-from-field.rb): a 3-argument override → `ArgumentError (given 4, expected 3)` on every `columns` call, from the merge on | open [rgeo/activerecord-postgis-adapter#445](https://github.com/rgeo/activerecord-postgis-adapter/pull/445) "Compatibility with rails 8.2" takes `slot = nil` (head `f9f86dbb46`, updated 2026-11-13). Its released gemspec pins `activerecord ~> 8.1.0` anyway | none; #445 covers it |
| activerecord-cockroachdb-adapter | 8.1.2 (0.8M), not run | grep: same 3-argument override (`cockroachdb/schema_statements.rb:338`, master `e003ac3`) | (a) | `02` | none; open [#409](https://github.com/cockroachdb/activerecord-cockroachdb-adapter/issues/409) is another main break. Gemspec pins `~> 8.1.0` | record only (niche adapter, DECISIONS "Focus on Rails, central gems") |
| activerecord-oracle_enhanced-adapter | master `84c0563` | — | (a) | `02` | fixed by yahonda in [rsim/oracle-enhanced#2979](https://github.com/rsim/oracle-enhanced/pull/2979) (merged 2026-11-13) | none |
| mobility | 1.3.2 (`a776667737`) | same on both: SQLite 748 ex 91F, PG 1277 ex 190F (`no such column: articles.title`). 1F at `3b2702adea`, 91F at `06eae38e6e` | (a), from [#59634](https://github.com/rails/rails/pull/59634), not #59141 | [`04`](../../bench/upstream/ar59141/04-where-bang-override.rb): a `where!` override on an extended relation is skipped by `where`/`find_by` | kamipo merged #59634 with his `_where!` follow-up `c8490688d7`: "[overriding private APIs is at the gem's own risk](https://github.com/rails/rails/pull/59634#issuecomment-6648826279)". Reported as [shioyama/mobility#692](https://github.com/shioyama/mobility/issues/692) and [chaadow/active_record-acts_as#61](https://github.com/chaadow/active_record-acts_as/issues/61), both open, no reply ([api-regressions AR-4](api-regressions.md#ar-4-where-and-having-with-bind-values-merged-as-railsrails59634-2026-11-05)) | none (watched by W1) |
| activerecord-import | 3.0.1 | same: SQLite 263, PG 376 runs, 0F | – | — | — | none |
| paper_trail | `86ce1b8307` (17.0.0) | same: SQLite 444, PG 510 ex, 0F | – | — | — | none |
| audited | 5.8.0 | same: 221 ex, 1F on both | – | — | — | none |
| store_model | 4.6.2 | same: 549 ex, 11F on both (R2-10 to R2-12, before #59141) | – | — | [ecosystem round 2](ecosystem-round-2.md) | none |
| attr_json | 2.6.0 | same: 281 ex, 8F on both (`Invalid Timezone: US/Pacific`, 2 Capybara specs; environmental) | – | — | — | none |
| globalize | 7.1.3 | same: SQLite 304, PG 305 runs, 0F | – | — | — | none |
| enumerize | 3.0.0 | same: SQLite and PG 274 runs, 0F | – | — | — | none |
| ar_lazy_preload | 2.1.3 | same: 134 ex, 0F | – | — | — | none |
| active_record_query_trace | 1.9 | does not load on either tree: `CustomLogSubscriber.attach_to` | (c), rails#55900 | — | [#72](https://github.com/brunofacca/active-record-query-trace/pull/72) closed for inactivity; CI fails on ≥ 8.0 | none (log-subscriber change, [api-regressions](api-regressions.md)) |
| annotaterb | 4.26.0 | same: 900 ex, 0F | – | — | — | none |
| closure_tree | 9.8.0 | same: 369 runs, 0F (PG, MariaDB, SQLite) | – | — | — | none |
| ancestry | 5.1.0; [#770](https://github.com/stefankroes/ancestry/pull/770) head `68789a1903` | same: 5.1.0 133 runs 31/32F (R2-5); #770 head 259 runs, 7F (`leaves`) on both | – | — | [ecosystem round 2](ecosystem-round-2.md) R2-5 | none |
| acts_as_list | 1.2.6 | same: SQLite and PG 231 runs, 0F | – | — | — | none |
| discard | 2.0.0 | same: 92 ex, 0F | – | — | — | none |
| paranoia | 3.1.0 (`a950fe4981`) | same: 101 runs, 0F (with round 2's load shims, R2-6) | – | — | — | none |
| money-rails | 3.0.0 | same: 268 ex, 1F under seed 4242 on both | – | — | — | none |
| friendly_id | 5.7.0 (`4699c9791d`) | same: SQLite and PG 530 runs, 0F | – | — | — | none |
| counter_culture | 3.14.0 | same: SQLite and PG 219 ex, 1F under seed 1717 on both | – | — | — | none |
| activerecord-session_store | 2.3.0 | same: 62 runs, 0F | – | — | — | none |
| attr_encrypted | 4.2.0 (found by grep: writes `@attributes`) | same: 151 runs, 1F on both (`stub`) | – | — | — | none |

Not run: **annotate** (ctran) 3.2.0 is from 2022 and superseded by annotaterb. PostGIS and CockroachDB suites need servers the orb doesn't have, and their
released gemspecs refuse 8.2. MariaDB configurations ran only for closure_tree.

## What #59141 changed for gems

Classes: (a) the gem uses internal API that #59141 changed; (b) a Rails regression of documented or widely relied-on
behaviour; (c) unrelated to #59141.

* **Readers by slot.** Generated readers call `_read_attribute_at!(slot)`, and `define_method_attribute` raises
  `ArgumentError` for a name with no slot. `define_attribute_method` itself is public (Active Model), but in Active
  Record a reader only made sense for real attributes. The raise is deliberate: tenderlove fixed the only caller in
  the sample himself (#114). Overrides of `_read_attribute` or `read_attribute` were already bypassed by generated
  readers before #59141 (R2-11, rails#59140); `01-internals.rb` shows the same on both trees.
* **`new_column_from_field(table_name, field, definitions, slot)`.** A private adapter hook gains a required 4th
  argument. A Column without a slot is still laid out after the last column, so adapters that build columns their
  own way, such as sqlserver's own `columns`, are unaffected.
* **`instantiate`, `_load_from_sql`, `becomes`, `init_with`, `build_from_database`, `@attributes`.**
  [`01-internals.rb`](../../bench/upstream/ar59141/01-internals.rb) replays what the grepped gems do: activerecord-import's
  `build_from_database` + `instance_variable_set(:@attributes)`, `write_from_user`/`fetch_value` on another
  record's set, counter_culture and attr_encrypted writing through `@attributes`, globalize's `@attributes.reset`,
  mobility's `key?` on a select alias, annotaterb's `_default_attributes[name]`, paranoia's `@attributes.frozen?`,
  `becomes`/`becomes!` to a sibling and an STI subclass, `init_with`, YAML and Marshal round trips, and `instantiate`
  with a Hash, column types and STI. All 24 probes give the same output on parent and main.
* **Defaults cast and frozen at schema load** (the CHANGELOG entry).
  [`05-frozen-defaults.rb`](../../bench/upstream/ar59141/05-frozen-defaults.rb): mutating a `serialize` Array, a custom
  coder object without `initialize_copy`, a store accessor or a String default on a new record behaves the same on
  both trees, and a type whose `cast` doesn't handle `nil`, declared with `attribute`, fails the same way on both.
  No suite hit a `FrozenError`.
* **Aliases on abstract classes** are now generated per concrete model, and only where the target attribute exists.
  [`06-abstract-alias.rb`](../../bench/upstream/ar59141/06-abstract-alias.rb): `alias_attribute :name, :title` on
  `ApplicationRecord`, read on a model without `title`, gives `nil` on the parent and `NoMethodError` on main. The
  same alias on a concrete model raises `ArgumentError` on both trees, and the commit comments that the skip is
  intended. No suite hit it. Recorded, not a finding.

## Grep of the top AR-related gems

The 184 gems in bestgems' top 2000 by total downloads that depend on activerecord, activemodel, rails or railties.
Of the first 150, the 143 that aren't Rails components were unpacked at their current release and searched, outside
`spec/` and `test/`, for `instance_variable_{get,set}(:@attributes)`, `AttributeSet`, `LazyAttributeSet`,
`LazyAttributeHash`, `attributes_builder`, `build_from_database`, `_default_attributes`, `_load_from_sql`,
`instantiate_instance_of`, `init_with`, `init_with_attributes`, `becomes`, `instantiate`, `_read_attribute`,
`_write_attribute`, `@attributes.` calls, `new_column_from_field`, `define_attribute_method` and `where!`/`having!`.
Besides the gems listed above:

| Hit | Outcome |
| --- | --- |
| attr_encrypted (`@attributes.write_cast_value`/`write_from_user`) | run, same on both trees |
| activerecord-postgis-adapter (`new_column_from_field`, `Column#init_with`) | breaks, table above |
| activerecord-nulldb-adapter (own `columns`, `Column.new`) | builds Columns without a slot, which `index_default_attributes` lays out after the last column; not run, gemspec `< 8.2` |
| activerecord-sqlserver-adapter, activerecord-cockroachdb-adapter, oracle-enhanced (not in the top 150, checked as adapters) | table above |
| rack-mini-profiler, factory_bot, searchkick, solid_queue | own `@attributes` / `instantiate`, unrelated to Active Record's |

## Method and pins

| | |
| --- | --- |
| Base | Rails main `c48c154e3f`, the first parent of the #59141 merge |
| Candidate | Rails main `50c54eed06` (2026-11-14), 26 commits after the merge |
| Attribution | each candidate failure rerun on the merge `1f32b09101` (typedstore: 454F, the same as main; repros `02`, `03`) |
| Ruby | 4.0.9 (mise), Bundler 4.0.20 |
| Databases | SQLite, PostgreSQL 17.12 (not 15) on 127.0.0.1:5432, MariaDB 11.8 for closure_tree |
| Seeds | 4242 and 1717, two runs per tree |
| Locks | identical besides Rails on every suite (`eco-locks.rb`: "same") |

Harness: the [readiness runner](readiness.md) with the manifest
[`round-59141.yml`](../../bench/upstream/readiness/round-59141.yml), which reuses the settings of ecosystem rounds
1 and 2 where a gem ran there. Output in [`round-59141/`](../../bench/upstream/readiness/round-59141/summary.md); the
every candidate flag matches `known.yml` (A59-1 for typedstore, A59-qt for active_record_query_trace). `--jobs 1` on a 2-CPU, 3 GB orb; about an hour including fixes.
The plain Active Record repros are in [`bench/upstream/ar59141/`](../../bench/upstream/ar59141), run with
`run.sh SCRIPT base merge cand`.

Settings new in this round, the same on both trees: attr_json bumps rspec-rails to `570b2b0a79` (L1, frozen
`default_url_options`); globalize's test helper drops its `LogSubscriber.attach_to` line; enumerize skips its MongoDB
tests and drops the tables its PostgreSQL tests leave in `template1`, which every later `createdb` copied (closure_tree
failed with `relation "users" already exists` until then); typedstore and attr_encrypted relax their sqlite3
development pins to `>= 2.1`; paranoia's shims rebuild the frozen `ACTIONS` and pass the leading position to
`set_options_for_callbacks!`; ancestry adds #770's head as a separate suite, since 5.1.0's R2-5 hides 31 tests.

Runner fix: [`rspec_json.rb`](../../bench/upstream/readiness/rspec_json.rb) now also adds its formatter when a
`spec_helper` loaded from `.rspec` has already set the formatters up. paper_trail's RSpec deprecation does that, and
every paper_trail run had read as "no test totals".
