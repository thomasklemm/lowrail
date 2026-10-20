# Active Record SQL plans (opt-in)

`lowrail build APP --ar-plans [--env test|production]` enables a narrow
gem-level pass. It caches **plans, not rows**. Rails' existing `find_by` and
unscoped-association StatementCaches are not Lowrail hits. This is not yet
a demonstrated request-level optimization, nor support for arbitrary query
chains.

Measured 2026-10-20 with MRI 4.0.7 + YJIT, the `script/corpus` apps and their
unchanged dependency locks. Campfire's pinned branch uses Rails 8.2 alpha,
Redprints uses 8.1.3, and the other apps use 8.1.4. PostgreSQL is local for PingCRM; the others
use SQLite. Campfire uses local Redis and `PARALLEL_WORKERS=1`.

## Target selection: profile before implementation

Production Rack requests, 200 warmups/route, four seconds/route for the
baseline, then a **separate** StackProf wall profile at 100 µs. Campfire
response caching is disabled with `CAMPFIRE_RESPONSE_CACHE_MB=0` throughout.
The Inertia app is PingCRM, not the inaccessible private app mentioned in
the original motivation.

Percent of all raw samples, not percent of AR time:

| Slice | Campfire inclusive | PingCRM inclusive | Campfire disjoint | PingCRM disjoint |
|---|---:|---:|---:|---:|
| SQL planning / Arel / predicate building | 9.862% | 7.356% | 8.459% | 6.900% |
| SQL execution | 8.758% | 19.641% | 8.588% | 19.618% |
| Type conversion / instantiation | 15.595% | 5.605% | 14.738% | 5.482% |
| Association loading | 31.131% | 12.570% | 16.562% | 4.768% |

Inclusive columns overlap and **must not be added**. Disjoint attribution
uses the deepest recognized boundary in each stack, leaving other AR/AM
and non-AR work separate. Categories are heuristics, not exact CPU accounting:
see `bench/ar_profile_summary.rb` and its synthetic-stack regression.
Campfire has 182,525 raw samples (183,741 reported, 5,192 missed);
PingCRM 60,072 (60,292 reported, 1,163 missed).

More narrowly, `build_arel` plus SQL visitors account for **4.417% / 3.168%**
inclusive. Preloader frames account for **19.971% / 5.072%** and
AssociationScope for **3.173% / 1.072%**. These are overlapping ceilings,
not predicted wins. The pass below retains relation/scope construction,
instantiation and preloading; it cannot eliminate the broad AR categories.
Instantiation and the preloader are outside this pass's scope.

## What is implemented

Rails' `Association#find_target` declines its own StatementCache for a scoped
reflection. Lowrail leaves that method and the skip decision **unchanged**.
An after-boot hook tags only the final internal relation passed to `to_a`.
At `exec_main_query`, a valid tag reuses Rails' `cacheable_query` and
StatementCache `BindMap`, binding the current owner ID and polymorphic type.
The live model's `_query_by_sql` still executes the query. Rails' original
`exec_queries` performs instantiation, inverses, preloading, readonly and
strict-loading propagation. No shared records, prototype model objects or
cached results are returned.

Scope certification reads the lambda's actual source location with Prism.
Only a uniquely located, zero-argument lambda with one literal
`where/order/limit/select/includes/preload` chain is accepted. Keys and values
inside the reflection's scope must be literals. Owner-dependent scopes,
`Time.current`, `Current`/thread-local reads, `where.not`, joins, through
associations, extensions, composite keys, STI targets, default scopes and
custom/enum/serialized predicate types are refused. Rails-generated
ActiveStorage/ActionText captured-name scopes have a separate exact source
certificate and a live captured-name check. A custom owner `_read_attribute`
is refused: a regression reproduced four observable reads instead of Rails'
one before that refusal. Stable boot-time replacements of framework planners,
visitors or quoters are not treated as pure merely because their source is
unchanged; unsupported implementation sources are recorded in the ledger.

Each manifest records model/reflection/schema facts, Rails version, source
digests, and method facts for the skipped planning machinery. Model-specific
relation class names are read with core `Module#name`, because Rails' `.name`
deliberately disguises them as `ActiveRecord::Relation`. Guard facts include
the actual delegated relation and association classes and the relevant type
method ancestor chains, not unrelated instantiation type wrappers. Concrete
adapter compilation/quoting methods are guarded too, including class-level
table/column quoting; a warmed-table-quoting regression fails without this
guard even though the records remain identical.

`Lowrail::AR.install` supplies invalidation epochs for schema, attribute,
default-scope, callback, reflection and connection changes. Plans store both
owner and target epochs. `Lowrail::Guard` invalidates method facts and checks
them lazily; no method/source snapshot is reconstructed on each query.
Per execution, the pass checks live class identities, epoch/schema/type
identities, current/global scoping, default-scope state, role/shard and query
transformers. Plans are connection-specific and require the certified concrete
adapter, with separate construction when prepared-statement mode changes.
Epoch changes conservatively retain Rails until rebuild/restart; they do not
silently certify a new scope.

Dynamic strict loading, inverse setup, query-cache on/off and instrumentation
stay in Rails' live execution path. Query log transformers disable reuse.
Cloning/spawning or a bang mutation through `assert_modifiable!` clears the
tag. Async queries and eager-loading joins stay on Rails. Plan-construction
errors decline the optimization; execution exceptions are not rescued or
retried. Missing/stale/incompatible manifests are silent no-ops.

## Survey and deliberately unsupported app chains

`bench/ar_survey.rb` inventories **query primitives**, not independently
eligible sites; chained `includes.order` counts twice. With `--ar-plans`, the
same source inventory is written to `ledger.json` under
`active_record/ar_plans_survey`, alongside reflection decisions under
`active_record/ar_plans`. Fixed keys alone are not a certificate.

| App | Source primitives | Eligible reflection readers (test build) | Reader refusals | Genuine pass hits |
|---|---:|---:|---|---:|
| real-blog | 2 | 0 | 2 without reflection scope | 0 |
| Campfire | 66 | 8 | 52 without reflection scope | 677 |
| PingCRM | 13 | 0 | 19 without scope; 3 unsupported/dynamic scope | 0 |
| Redprints CFP | 31 | 0 | 45 without scope; 4 unsupported/dynamic scope | 0 |
| React Starter Kit | 3 | 0 | 2 without reflection scope | 0 |

These are per-model reflection entries, including inherited/framework
reflections, not eight distinct app-written lambdas. Campfire's accepted
readers are `Account#logo_attachment`, `User#avatar_attachment`,
`Message#attachment_attachment`, `Message#rich_text_body`,
`ActiveStorage::Blob#preview_image_attachment`,
`ActiveStorage::VariantRecord#image_attachment`, and the inherited
`ActionText::{RichText,EncryptedRichText}#embeds_attachments` entries.
The pinned Campfire has **no app-written scoped reflection**; its numerous
named scopes are a different target. Final test and production PingCRM builds
both have 19 unscoped and three unsupported scoped reflections, zero eligible.

Source refusal breakdown (the per-site file/line/shape remains in the ledger):

| App | Existing Rails `find_by` candidate | Fixed syntax, uncertified association/dynamic receiver | Fixed syntax, uncertified constant | Fixed syntax, implicit scope | Other refusals |
|---|---:|---:|---:|---:|---|
| real-blog | 0 | 1 | 1 | 0 | none |
| Campfire | 1 | 26 | 5 | 15 | 7 SQL/dynamic hashes; 8 WhereChain; 3 array/range/nested predicates; 1 dynamic limit |
| PingCRM | 0 | 4 | 0 | 5 | 3 SQL/dynamic hashes; 1 WhereChain |
| Redprints CFP | 5 | 17 | 1 | 3 | 2 SQL/dynamic hashes; 1 WhereChain; 2 dynamic order |
| React Starter Kit | 1 | 1 | 0 | 0 | 1 WhereChain |

**App call-site chain rewriting/tagging is not implemented.** In particular,
`@messages = room.messages.ordered.limit(n)` is still a normal Rails relation,
not a supported escaping-plan site. `first/last/pluck/exists?/count` are not
replaced with StatementCache array execution. They change projection,
ordering, limits or aggregation, sometimes by spawning another relation;
silently sharing the reader's plan would be wrong.

Campfire's request path is not just `ordered.limit`: `with_presentation`
expands nested scopes and generated attachment scopes, then `last_page` /
`Page.load` changes relation state and returns a custom Array. Its
`page_before/after` scopes use SQL fragments and timestamp values. PingCRM's
index is CanCan's relation followed by dynamic `search`, `trash_filter`,
ordering and Pagy pagination. A generic tag must prove that whole chain,
capture values once in Ruby evaluation order, and invalidate at each spawn /
mutation; accepting a fixed final `order` is insufficient. real-blog's
`Article.includes(:comments).order(created_at: :desc)` is a simpler future
candidate, not a fabricated hit in this implementation.

`bench/ar_chain_ceiling.rb` distinguishes SQL-only reuse **after building the
live relation** from the overly optimistic direct-StatementCache diagnostic
in `bench/ar_plans.rb`. It uses real association/named-scope chains, retains
Rails instantiation, checks records first, and has **no production guards**.
It deliberately fixes one owner's ID and is a ceiling experiment, not a
variable-bind implementation or an eligible corpus site.

Five alternating-order, fresh YJIT processes give these SQL-only ceilings
(µs/call; median of cohort means, min–max in parentheses):

| Diagnostic chain | Rails | SQL-only reuse, no guards | Difference | Objects/call |
|---|---:|---:|---:|---:|
| Campfire `room.messages.ordered.limit(10)` | 139.06 (134.15–147.19) | 117.95 (108.55–120.80) | 21.11 µs | 566 → 528 |
| PingCRM `account.organizations.not_trashed.order(:name).limit(10)` | 232.67 (226.15–241.27) | 210.49 (198.64–234.75) | 22.18 µs | 380 → 336 |

This **clears the 10 µs exploration threshold**, not the correctness or
profitability gate for shipping an escaping-relation pass. Neither probe
certifies the real controller's complete chain. No guarded, variable-owner
app-chain implementation or speedup is claimed here. That widening remains
open work; CanCan and custom pagination were not changed. These numbers do
not justify a generic rewrite of the most common syntactic `order` suffix.

## Correctness gates

The real SQLite runtime regression compares exact rows and ordered
`sql.active_record` events including SQL, bind names, **values and type
classes**, and cached flags. Asymmetric owners/order/filters catch accidental
owner capture. Each mutation runs in a fresh process with a warmed fast path,
so an earlier invalidation cannot conceal a later broken guard:
default scope added after boot, column type changed, attribute type replaced,
delegated relation `build_arel` replaced, association constructor replaced,
and query transformers enabled. It also checks scoping/unscoped blocks,
query cache, dynamic-scope refusal, inverse identity, strict-loading exceptions
and lazy relation extension.

Corpus `lowrail verify` uses the shared SQL-trace differential and identical
seeds with one worker. That gate compares SQL/name, bind name:class, cached
flag and row count, **not bind values**; timestamps and long numeric literals
are masked. The runtime regression above is the stronger bind-value control.
Other-thread SQL is advisory because thread interleaving is nondeterministic.

Final **non-system** suites, seed 41231, `PARALLEL_WORKERS=1`,
`LOWRAIL_SQL_TRACE=full`, after pulling the shared `define_attribute` /
`reset_primary_key` epoch events:

| App | Identical outcomes | Identical traced queries | AR-plan hits / fallbacks |
|---|---:|---:|---:|
| real-blog | 21 | 125 | 0 / 0 |
| Campfire | 634 (632 pass, same 2 libvips skips) | 15,108 | 677 / 367 |
| PingCRM | 1 | 4 | 0 / 0 |
| Redprints CFP | 50 | 692 | 0 / 0 |
| React Starter Kit | 35 | 253 | 0 / 0 |

That is **741 outcomes and 16,182 queries**. These are not new browser-suite
claims. All five builds completed; only Campfire has an AR-plan runtime unit.
The corpus gates compare all enabled passes, but the hits above are only
`active_record/ar_plans`, never Rails' own caches or other Lowrail units.
Rust: 26 unit tests (including fake-oracle lowering tests) and three integration
tests pass. Gem: 77 runs, 1,856 assertions, no failures/errors, three optional
skips. The AR regression contributes 116 assertions; the diagnostic tooling
test contributes another 16.

The 367 Campfire fallbacks are now counted at execution, rather than silently
dropping a tag before counting. A scratch, method-targeted TracePoint confirmed
current-scope/scope-attribute refusals and epoch invalidation. In particular,
the database-task tests purge/re-establish a SQLite connection, invoking
`AR.bump_all`; old plans conservatively stay disabled afterwards. Boot traces
also contain lazy schema/primary-key initialization events. Epoch snapshots
are taken after reading the plan's metadata. No guard was relaxed to remove
fallbacks, and the untimed production request probe has zero AR-plan fallbacks.

## Measured effect and route budget

Single execution-time guard, no duplicate check at tagging. Five fresh-process
interleaved off/on pairs, YJIT, 1,000 warmups and three seconds/case, query cache
off, stats/profiler off while timing. Medians of cohort means, min–max:

| Actual reader | Off, µs | On, µs | Signed saving/hit | Objects/call |
|---|---:|---:|---:|---:|
| `Message#rich_text_body`, reset scope + read | 251.05 (238.34–273.91) | 264.44 (241.06–303.61) | −13.38 µs | 473 → 452 |
| `Account#logo_attachment`, reset scope + read | 79.14 (77.92–84.77) | 90.66 (71.90–106.28) | −11.52 µs | 228 → 207 |

The fixture has no logo attachment; the query and its empty result are still
real. A separate stats-enabled positive control recorded 2,387 logo-plan
executions, zero fallbacks. The allocated-object reduction is repeatable;
**neither median demonstrates a time saving**, and the time spreads overlap.

An independent warmed Rack probe (200 warmups, ten counted requests/route)
finds only `Account#logo_attachment` hits on the measured Campfire routes:
room **2/request**, sidebar **1**, search **1**, messages **0**. Both PingCRM
routes have zero hits. No app sites were added to produce these counts.
The request benchmark uses five interleaved off/on process pairs, YJIT,
200 warmups/route, three seconds/route, no profiler/stats, only this pass
enabled, and `CAMPFIRE_RESPONSE_CACHE_MB=0`.

Request pairs precede the final conservative adapter/boot-customization
hardening. The microbenchmarks and hit probe were rerun afterwards; the old
request pairs are retained as the noise comparison, not a current-head speed
claim. No further request cohorts were collected to chase those differences.

Use the **matching logo reader**, not a different expensive association, for
the expected-effect budget: signed saving −11.5201 µs × hits/request ÷ the
route's off median. The table displays the resulting **time change** (positive
means slower); the signed saving is its negative. This is an estimate, not
a confidence bound or a promise that microseconds add exactly in a request.

| Route | Hits/request | Off ms, median (min–max) | On ms, median (min–max) | Expected time Δ | Measured time Δ |
|---|---:|---:|---:|---:|---:|
| Campfire room | 2 | 14.098 (13.526–14.779) | 14.559 (12.616–14.785) | +0.163% | +3.27% |
| Campfire messages | 0 | 9.329 (8.237–10.389) | 8.870 (7.856–9.704) | 0% | −4.92% |
| Campfire sidebar | 1 | 8.965 (8.584–9.695) | 10.163 (8.819–10.551) | +0.128% | +13.35% |
| Campfire search | 1 | 10.529 (8.477–10.824) | 10.668 (9.055–11.420) | +0.109% | +1.32% |
| PingCRM organizations | 0 | 3.273 (3.115–3.552) | 2.977 (2.859–3.029) | 0% | −9.03% |
| PingCRM contacts | 0 | 3.933 (3.481–4.107) | 3.655 (3.557–3.886) | 0% | −7.09% |

All expected effects are **below 0.2%, much less than 2%**. The sidebar is
not a zero-hit control, but one guarded logo read's measured extra ~11.5 µs
does not explain ~1,197 µs/request. Its earlier +12.8% and final +13.35%
request differences are not evidence of a guard-cost regression of that size.
The zero-hit controls move substantially too. These request comparisons are
**noise-dominated; no request-level gain or causal slowdown is established**.
Stop collecting more pairs to chase that noise. Keep `--ar-plans` opt-in.

## Attribute dispatch: measured, not implemented

Five fresh YJIT processes, alternating case order, uncached reads of real hot
models. Median µs/call:

| Model / operation | Rails generated | Direct attribute storage | Guarded direct |
|---|---:|---:|---:|
| Campfire Message read `room_id` | 0.1132 | 0.0856 | 0.4228 |
| Campfire Message write `room_id` | 0.2366 | 0.1843 | 0.5512 |
| PingCRM Organization read `name` | 0.1142 | 0.0778 | 0.3021 |
| PingCRM Organization write `name` | 0.2206 | 0.1894 | 0.4436 |

The direct path's 0.03–0.05 µs opportunity is smaller than this guard's cost.
The prototype checked class/type identity and reader/writer definitions;
those guards are not a proof that every faster possible invalidation design
must lose. They are enough to reject **this implementation**, not Rails'
generated methods. No attribute specialization was shipped.

The earlier full per-call method-snapshot guard cost about 931 µs on Campfire
and was discarded. That result says nothing against invalidation epochs:
the implemented reader pass uses the latter.

## Reproduce

Prepare with `script/corpus`; keep corpus credentials/headers in each app's
private `tmp/m0`, populated by `bench/campfire_setup.rb` and
`bench/inertia_setup.rb`. Use the pinned Ruby (`mise exec -- ruby -v`). The
production commands use `RAILS_LOG_LEVEL=error`, as did the timed controls.

```sh
cargo test
ruby -Igem/lib -Igem/test -e 'Dir["gem/test/*_test.rb"].sort.each { require_relative _1 }'
ruby bench/ar_diagnostics_test.rb
ruby bench/ar_survey.rb .corpus/{real-blog,campfire,pingcrm,redprints-cfp,react-starter-kit}

lowrail build .corpus/campfire --ar-plans
PARALLEL_WORKERS=1 lowrail verify .corpus/campfire
# RSpec apps need their actual test runner, not the default rails test:
PARALLEL_WORKERS=1 lowrail verify .corpus/redprints-cfp -- bundle exec rspec
PARALLEL_WORKERS=1 lowrail verify .corpus/react-starter-kit -- bundle exec rspec --exclude-pattern 'spec/system/**/*_spec.rb'

RAILS_LOG_LEVEL=error SECRET_KEY_BASE_DUMMY=1 lowrail build .corpus/campfire --env production --ar-plans
ruby bench/ar_cached_runs.rb .corpus/campfire /tmp/ar-reader-micro micro
BENCH_READER=logo ruby bench/ar_cached_runs.rb .corpus/campfire /tmp/ar-logo-micro micro
ruby bench/ar_cached_runs.rb .corpus/campfire /tmp/ar-reader-requests requests
# Repeat the production build + two runners for PingCRM (zero-hit control).
# Untimed counts, from inside the production app with its actual manifest:
# LOWRAIL=1 LOWRAIL_STATS=/tmp/ar-hits RUBYOPT='-I/abs/lowrail/gem/lib -rlowrail/setup' \
#   BENCH_JSON=/tmp/ar-hits.json ruby --yjit /abs/lowrail/bench/ar_request_hits.rb
```

`ar_cached_runs.rb` runs five alternating fresh-process on/off pairs, only
this pass enabled; timing has stats/profiler disabled. The request runner
calls `bench/requests.rb` with YJIT and 200 warmups/route, three seconds/route,
and disables Campfire response caching. Report medians and min–max spreads,
not the fastest cohort. A separate stats run verifies genuine executions;
timing movement in a zero-hit control is not a speedup from the pass.
