# Active Record read path beyond C11 and #59141 (2026-11-04)

A round looking for small, exact rails/rails candidates in the parts of the Active Record read path that the census apps run per
request:
* association loading: the preloader, has_many through, and inverse_of setup;
* scoping and `default_scope` application;
* `Relation#load` and record instantiation, outside `LazyAttributeSet`.

C11 (write path, Arel) and #59141 (attribute storage) were left alone. Nothing was built, opened or posted, and no
`gh pr create` was attempted.

**Result: no candidate.** In this area every census 8 line above 0.06% is one of three things: covered by an open or merged
PR, deliberate on main, or already a single read or guard. One lead, `ThroughReflection#options` through
`delegate`, was measured and parked.

## Pins and method

* Rails main [`9cf3693a0a`](https://github.com/rails/rails/commit/9cf3693a0a). Ruby 4.0.9, interpreter and YJIT.
* CPU ranking: census 8 (20 apps, Rails `1105756f42`), `rank-cpu409-{interpreter,yjit}-line.tsv`.
* Overlap: 57 open rails/rails PRs touch `associations/`, `scoping/`, `reflection.rb`, `relation.rb`,
  `relation/{delegation,spawn_methods,merger}.rb`, `core.rb`, `querying.rb` or `result.rb` (2026-11-04). They
  include kamipo's #59612, #58814 and #58815, matthewd's #59530, kehra's #59377 and #59593, and ours #59564 and #59569.
  `reflection.rb` alone had 12 commits since 2026-10-01.

## Where the read path's time goes

| Census 8 line(s) | Apps | % of all Ir, interp / YJIT | Disposition |
| --- | ---: | ---: | --- |
| `Querying#_load_from_sql` (querying.rb:99) | 20 | 0.62 / 0.88 | Our #59568 (reads `attribute_types` once); the column loop is #59141's. |
| `Result#column_types`, `#indexed_rows`, `#initialize_copy` | 15–20 | 0.06–0.43 | Result storage; #59141 rewrites `result.rb`. |
| `Relation::Merger#merge` (:64–65) | 20 | 0.45 / 0.65 | Our merged #59554. `extending!` was declined upstream (#57246). Open #59612 (kamipo) changes merging. |
| `Delegation::ClassMethods#create`, `Relation#initialize`/`initialize_copy`, `SpawnMethods#spawn` | 15–20 | 0.06–0.31 | The Relation objects themselves. Required (census 4–8, activerecord-cpu). |
| `_reflections`, `_reflect_on_association`, `MacroReflection#klass`/`_klass`, `class_name`, `association_route`, `current_default_association_route?` | 16–20 | 0.06–0.24 each | Cached reads and identity checks; `association_route` was reworked 2026-10-09 (4af9822fae, matthewd). |
| `Associations#association`, `association_instance_get`, `association_cache`, `Association#target`/`#loaded?`/`#stale_target?`/`#klass`, `deprecated_associations_api_guard` | 14–18 | 0.08–0.17 each | Each is a hash read, an ivar read or one guard. `BelongsTo#stale_state` / `ThroughAssociation#stale_state` is our merged #59583. |
| `ThroughReflection#options` (reflection.rb:1528) | 16 | 0.12 / 0.11 | Lead below; parked. |
| `has_default_scope?`, `build_default_scope` (`method(:default_scope).owner`) | 20 | 0.08 / 0.13 | Deliberate (#59234, kamipo); a cache is not exact ([R6 lead 2](rails-r6-leads.md#lead-2-has_default_scope--build_default_scope-methoddefault_scopeowner)). |
| `ScopeRegistry.current_scope`/`instance`/`value_for`/`set_value_for` | 15–19 | 0.06–0.13 | `IsolatedExecutionState` reads; call overhead (ar-request-paths). |
| `schema_context`, `current_schema_context`, `schema_loaded?`, `SchemaContext#attributes`, `table_name` | 14–20 | 0.07–0.18 | Open #59530 (matthewd) splits `SchemaContext`. |
| Preloader `Branch#build_children`, `preloaders_for_reflection`, `future_classes`, `runnable_loaders`, `done?`, `LoaderQuery#hash`, `Preloader::Association#initialize` | 9–15 | 0.06–0.10 | Our open #59564, plus active fixes (#59599, #59593, #59528, #58815). |

## Lead: `ThroughReflection#options` through `delegate` (parked)

`ThroughReflection` forwards dozens of public `AssociationReflection` methods with one `delegate` call, so each
`options` call goes through the generated `def options(...)` with its `DelegationError` rescue before reaching
`@delegate_reflection.options`. `through_reflection` (`active_record._reflect_on_association(options[:through])`)
calls it on every hop: in a has_many through probe (load, preload, eager_load, a scoped count), 45 of 71 calls came
from `through_reflection`.

Per call, 4.0.9, pinned, best of 5 × 2,000,000:

| | interpreter | YJIT |
| --- | ---: | ---: |
| `through.options` (delegated) | 96 ns | 70 ns |
| `delegate_reflection.options` | 40 ns | 30 ns |
| `through.through_reflection` | 300 ns | 154 ns |

The delegation is about 56 / 40 ns per call, which puts it at most about 0.07% of the census's instructions. Saving it means
defining `options` by hand next to a `delegate` of every other public method. A reader would ask why `options` is special,
so the change needs a comment (L2–L3). It would also go into `reflection.rb` while that file is being reworked. Not built.

## Limits

* Census shares are from census 8 on Rails `1105756f42`; changed files were read on `9cf3693a0a`.
* The only measurements are [`through_options_micro.rb`](../../bench/upstream/ar_read/through_options_micro.rb) and the caller probe [`through_options_callers.rb`](../../bench/upstream/ar_read/through_options_callers.rb). Nothing was built, so there was no Callgrind, ruby-bench or review round.
