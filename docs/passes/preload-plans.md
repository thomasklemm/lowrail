# Active Record preload plans computed once

**Current status: sealed-only.** Suppressed model singleton hooks bypass
both the method certificate and AR epoch. Guarded selection and old/mixed
artifacts refuse; see the [audit](suppressed-hooks.md). Only production
research under the separate [sealed contract](../sealed.md) is eligible;
test processes stay original-only. The guarded commands/results below are
historical, not current support or accelerated L3 coverage.

PLAN §9.2b (preload portion), measured 2026-10-20. Ruby **4.0.7 +YJIT**, Campfire
[`af4dd9f`](https://github.com/basecamp/once-campfire/commit/af4dd9fd599c65e0e0fc1f614ee469f70156ddf5),
Rails **8.2.0.alpha** at
[`e3d5c56`](https://github.com/rails/rails/commit/e3d5c569d217c56c022b04acb127a8c24dbe9685).
The second corpus gate is generated real-blog on Rails **8.1.4**.

## Design and delivery

This is a **gem-level runtime pass**, `active_record/preload_plans`, not a
query-chain rewrite. It catches direct Preloader callers as well as
`Relation#preload_associations`, without analyzing every way an app builds
an includes spec. A prepended module leaves Rails' original Preloader in the
method lookup chain. Unsupported inputs or invalid facts call `super`.
The prepend is visible in `ancestors`; unlike a source splice, this pass
does not promise an unchanged method owner for Preloader itself.

`lowrail build APP --passes default,+preload_plans [--env production]` selects the preload
builder in `lowrail-runtime-build`, sharing one app boot with the other
selected runtime passes. Rust merges the returned units and ledger before
compilation, assigning ids after the source units; rebuilding is idempotent. There is no
activation without a compatible manifest. `LOWRAIL=0`, `LOWRAIL_UNITS`,
environment guards, verify bisection and the per-app denylist all apply.

At boot, an after-initialize hook checks Rails' version and the recorded
SHA-256s of the implementation files. Plans are filled lazily on first use,
keyed by **exact owner class + an order-preserving serialization of a copied
includes spec**. Ruby Hash equality ignores insertion order; Rails' loader
and SQL order do not. A process retains at
most 256 plans/fallback markers; further specs use Rails. The tree,
association/reflection scopes, loader-query equivalence groups and execution
schedule are shared. Structural scheduling declines retain only a marker:
always using Rails remains safe if metadata changes, so that marker needs no
edge validation and lasts until process restart. Transient guard failures
are not negative-cached.
**No owners, association targets, rows, loaded relations or query results are
retained in the cache.** The cached Relation prototypes are never loaded;
Rails spawns per-call `where(keys)` relations from them.

Each invocation still constructs real Rails
`Preloader::Association`/`LoaderRecords` instances. Rails handles owner-key
conversion, duplicate owners, loaded associations, missing-record queries,
inverses, collection/singular assignment, and preserving unsaved targets.
The pass does not reproduce that machinery. Each returned loader gets a
fresh scope clone: callers may load/mutate `loader.scope` without exposing a
cached prototype. Calls return the same root Rails Association loaders on
repeated calls to one Preloader, but in a fresh array each time as Rails does. A caller
preparing/inspecting loaders before `call` gets the original Rails tree and
execution path. Rails' branch tree is otherwise built lazily for fallback or
post-call inspection, with the actual per-call loaders bound into it. Once
the mutable branch tree is exposed, further calls use that Rails tree.

Plans accept only **data-independent Batch schedules**. Rails removes a
branch's runnable classes from its future classes before postponing other
loaders by table. A repeated class inside its own branch is not such a
dependency. If a multi-branch frontier still needs postponement, the whole
spec uses Rails: pruning empty branches could otherwise change query order
and query grouping. Independent frontiers can safely share precomputed
groups while Rails still handles empty owner sets at execution time.

### Guarded facts and invalidation

`preload_facts.rb` is shared by build and runtime. The runtime unit records:

- model table, primary key, connection specification, polymorphic name,
  inheritance column, columns/SQL types and attribute-type classes;
- reflection owner, macro, target, options, join keys, scope location, and
  the captured attachment/rich-text name;
- Rails version and implementation source digests;
- method-resolution facts for model association getters, association
  constructors, scope/relation constructors, concrete
  reflection classes, model-specific Relation classes, Rails Preloader,
  Branch, Batch, Association, LoaderQuery, LoaderRecords, and the wrapper
  itself. The shared runtime fact helper's source is pinned too;
- native types of constant scope predicates (polymorphic type and generated
  name), their serialization/metadata method chains, and those chains' source
  digests. Checking the resolved method alone would miss a change below
  `String#serialize` in its `super` chain.

These are additive runtime-unit fields in the v1 manifest, not a new
`facts.json` format. The main fact dumper/Rust schema is unchanged, avoiding
coupling this pass to the independently evolving boot-surface capture.

Existing `Lowrail::Guard` method/module hooks reset the unit's state and it
revalidates lazily. The additive `exact` method-fact flag checks the named
class, not every subclass: the pass explicitly instantiates that class and
checks actual owner classes. A CollectionProxy override must not veto an
unrelated model Relation; an override on that model Relation must. Object
singleton overrides remain conservatively guarded. Original Preloader
methods underneath the prepend are checked separately, so the prepend does
not invalidate its own unit or hide later patches below it.

Before use, every edge also checks model constant identity, reflection
identity/options/scope, schema/type-map identity, table/key/connection/inheritance settings, captured
names, default scopes, and current target scopes. This catches changes that
do **not** define a method. Schema/reflection changes discard a cached plan;
a replacement is accepted only if its recorded facts still hold. A transient
scope or stub can fall back and recover. Guard checks run again in `call`,
not only in `initialize`: changing an input between those calls cannot run a
stale plan. Each frontier revalidates before loading; all of that frontier's
scopes are snapshotted before its first query, just as Rails does. If an
`after_find` callback changes a later frontier's facts, execution resumes
through the original Rails tree with completed loaders preserved, not by
starting over. Guard/plan-construction errors decline without hiding
exceptions from actual row loading.

## Supported and declined shapes

| Supported | Conditions |
|---|---|
| `belongs_to`, `has_one`, `has_many` | Non-through, non-polymorphic target; scalar join keys |
| Plain nested arrays/hashes, symbols/strings | Every edge is certified, scheduling is data-independent; string and symbol hash keys and hash insertion order stay distinct |
| Loaded associations, missing keys/rows, duplicates, unsaved targets | Handled by Rails' per-call Association objects |
| Active Storage/Action Text generated name scopes | Precisely the generated `-> { where(name: name) }` closure, with its captured name guarded |
| Root STI instances | Homogeneous exact class; targets with an STI discriminator are declined |

Whole specs use the original Rails path for through associations,
polymorphic belongs_to, composite keys, owner-dependent scopes, arbitrary
app lambdas (even apparently literal ones), target default scopes, current
target scoping, abstract/STI targets, deprecated associations, unknown
reflections, mixed owner classes, explicit preload scopes (including strict
loading scopes), supplied available records, or `associate_by_default: false`.
Cross-level table dependencies between pending branches also decline.
Preexisting app/gem implementations wrapping Preloader, Batch or Branch
decline the whole runtime pass; a stable wrapper is not equivalent to the
Rails program being bypassed. Custom model association getters or association
constructors decline affected edges. These decisions are in the ledger.
Custom model/reflection/relation scope constructors are not certified just
because an association has no explicit lambda. Custom types on constant
scope predicates decline: QueryAttribute memoizes their serialized values,
and a type may depend on request state. Owner-key serialization remains in
Rails on every call. Container/string subclasses, identity-keyed hashes,
and singleton-customized specs decline; a custom association-name converter
must keep Rails' own semantics. Copies of ordinary strings retain only text,
not attached instance-variable payloads. New associations after the build are
not silently adopted. Empty record sets remain on Rails.

Campfire has **42 eligible associations and 18 declines**, not 42 lowered
units. A whole runtime tree still needs every edge to be eligible. real-blog
has two eligible associations. The ledger records eligibility/decline
reasons per association; the general input-boundary declines above happen
at runtime, not as per-request disk writes.

## Reference implementation studied

Roundhouse's
[`src/emit/futamura/futamura.rb`](https://github.com/rubys/roundhouse/blob/6b1931165fa3efc96163eb26feba3d2fc57c53a0/src/emit/futamura/futamura.rb),
`query.rs`, `scripts/futamura-suite`, and
[`docs/pipeline/specialization.md`](https://github.com/rubys/roundhouse/blob/6b1931165fa3efc96163eb26feba3d2fc57c53a0/docs/pipeline/specialization.md#specialization-2-preloads-planned-once)
were inspected. Futamura caches preload trees/scopes and implements a
per-request loader. It also certifies app scopes statically and compares
loaded-association signatures under `FUTAMURA_VERIFY=1`. Its suite gate
compares summaries and failing identities; Lowrail's gate compares **every
test outcome**, including skips, and requires real completed-plan hits.

Lowrail instead keeps Rails' loader implementation, adds boot-fact
invalidation, and certifies a narrower set of scopes. It does **not** include
Futamura's query-chain/StatementCache specialization. In particular,
`Account.first` is a negative control here: the reference's 167 → 98 µs
result cannot be attributed to this pass. Its 4.78 → 3.82 ms Campfire chain
is historical context on a different Campfire revision/machine, not an
expected result for this workload.

## Correctness evidence

The final combined route + preload build was verified with:

```sh
cargo test
ruby -Igem/lib -Igem/test -e 'Dir["gem/test/*_test.rb"].each { require_relative _1 }'
cargo build
target/debug/lowrail build .corpus/campfire --passes default,+preload_plans
PARALLEL_WORKERS=1 target/debug/lowrail verify .corpus/campfire -- bin/rails test --seed 35709
target/debug/lowrail build .corpus/real-blog --passes default,+preload_plans
PARALLEL_WORKERS=1 target/debug/lowrail verify .corpus/real-blog
```

| Gate | Result | New preload unit |
|---|---|---|
| Campfire | **634 identical**: 632 pass, 2 identical skips, 0 failures/errors; 3,856 assertions each | unit 34: **786 completed-plan hits** |
| real-blog | **21 identical**, all pass; 54 assertions each | unit 11: **2 completed-plan hits** |
| Gem tests | **45 tests, 563 assertions**, no failures/errors/skips | Real Rails 8.1.4 + SQLite differential regressions |
| Rust tests | **18 unit + 1 integration**, all pass | Existing tests unchanged |

Campfire's combined build has 11,902 hits across 28 exercised units;
real-blog has 116 across all 12. The preload counter increments only after
the complete planned load, not when a guard passes or a tree is declined.
The existing two libvips skips are retained. System/browser tests were not
rerun for this non-UI pass; the gate above is the requested 634-test suite.

The integration regression runs the same asymmetric rows through off, on,
unit-disabled and stale-source modes. It checks nested loaded flags and
targets, inverses, duplicate owners, unsaved targets, fresh rows on later
calls, one SQL query for equivalent aliases, dynamic/default/current scopes,
custom request-dependent constructors, method/module changes, schema reset,
reflection redeclaration, mutable specs, distinct string/symbol keys, reversed
hash insertion order, custom association-name conversion,
self-referential query order, sparse cross-branch schedules, caller
mutation/loading of returned scopes, preparing loaders before `call`, and
idempotent repeated calls. A custom reflection `join_scopes` that read thread
state reproduced stale scope reuse despite `reflection.scope` being nil;
it now declines, just like a custom model scope constructor.
Prepending a Batch `call` wrapper originally bypassed that wrapper on the
planned path; the Batch guard regression now requires Rails fallback.
The includes-order regression failed before the cache-key fix: a second hash
with reversed entries reused the first plan's root-loader order, because the
two hashes compared equal. Serialization preserves the difference.
The query-order regression failed before the scheduling fix: Rails selected
`writers, posts, writers`, while the initial plan selected
`posts, writers, writers`. The corrected pass preserves Rails' order.
Declining data-dependent schedules reduced Campfire hits from 1,054 to 786;
coverage is deliberately narrower rather than changing observable query order.

The final regression was also run against the preceding implementation:
it failed on identity-keyed hashes (one root instead of two), post-call branch
state, callback-added default scopes (stale unfiltered child rows), a custom
request-dependent type (`[1, 1]` instead of `[1, 0]`), and native serializer
changes (one row instead of none). The corrected implementation passes the
same scenario in all four modes, including a serializer override below the
resolved method in its superclass chain.

Additional before/after probes reproduced mutation of a reused return array
(later calls lost a loader), mutation of an exposed branch tree (ignored by
the cached result), and valid non-array constructor inputs (an exception on
`available_records: false`). A replaced `Post` constant hid a scope patch on
the still-live old class from name-based method facts: the original returned
only `second`, while the stale plan returned all three posts. Exact class
constant identities now reject that plan. Named Batch/model-association
wrappers installed **before build** are also tested: counters and outcomes
must match, with no preload fast path. Guarding an already-customized body
would not justify skipping it.

## Performance protocol

Use the disposable production setup in [Campfire M0](../m0/campfire.md):
local Redis, prepared SQLite, compiled assets, fixtures, and real authenticated
headers from `bench/campfire_setup.rb`. No app source/lockfile changes.

```sh
RAILS_LOG_LEVEL=error SECRET_KEY_BASE_DUMMY=1 \
  target/debug/lowrail build .corpus/campfire --env production --passes default,+preload_plans
# Set BENCH_HEADERS and ROOM_PATH from the private prepared fixture.
target/debug/lowrail bench .corpus/campfire --pass active_record/preload_plans \
  --counter native --micro-case already_loaded_creator --path "$ROOM_PATH" \
  --out /tmp/preload-micro
```

The removed per-pass runner's historical protocol follows below. New
measurements use the shared command's A/A/heap gates with the retained
`preload_paths.rb` operation worker. Repeat each prepared HTML/stream/JSON
path separately, with its private `BENCH_HEADERS`, in both default-cache and
`CAMPFIRE_RESPONSE_CACHE_MB=0` modes; the matrix is not a new measurement seam.

The production log level also keeps app boot log messages out of the
build-time oracle's stdout protocol. Timed code is Ruby +YJIT, sequential
in-process Rack, 200 warmups, 3 seconds per case, three **fresh-process**
measurements for each on/off case. Pair order alternates off/on, on/off.
Only the preload runtime unit is enabled through `LOWRAIL_UNITS`; stats and
other fast paths are off. Their guard/load-time plumbing remains installed
in the on process: this compares plain Rails with the Lowrail runtime and
only the preload unit enabled, not two otherwise identical Ruby programs.
Micro and request runs are sequential, without
profilers or concurrent test runs. Reported spread is **min–max across three
runs**, not a confidence interval or within-request percentiles.
Each run measures mean time per operation; tables show the median and range
of those three process means. The final measured code is
[`b110efd`](https://github.com/thomasklemm/lowrail/commit/b110efd).
Earlier five-pair diagnostic cohorts preceded the final compatibility
hardening and are not pooled with these measurements. Untimed production
probes separately check endpoint content and completed-plan hits.

Request runs use `bench/requests.rb` for all six M0 endpoints, with the
browser cookie for HTML/stream and separate bot authentication for JSON.
Default response/record caches are compared with
`CAMPFIRE_RESPONSE_CACHE_MB=0`; fragment caches remain warm in both modes.
This is not a cold-cache or concurrent-load simulation. Raw logs contain
fixture credentials and stay private in `/tmp`; only aggregate numbers are
reported.

### Microbenchmarks

Each query case selects ten fixture messages ordered by id. The creator
case preloads `creator: :avatar_attachment`; the presentation case uses
`Message.with_presentation`. The already-loaded case reuses ten owners whose
creator/avatar associations were loaded before timing, explicitly isolating
planning rather than data-fetch cost. `Account.first` has no preload and is
a negative control. Times below are **µs**, median [min–max]; allocations are
median objects per operation, off → on.

| Path | Off µs | On µs | Time change | Allocations |
|---|---:|---:|---:|---:|
| Creator query | 433.3 [381.3–446.6] | 424.7 [345.1–488.2] | −2.0% | 975 → 882 (−9.5%) |
| Presentation query | 2,411.8 [2,295.6–2,688.1] | 2,877.6 [2,399.3–3,122.7] | **+19.3%** | 4,878 → 4,580 (−6.1%) |
| Already-loaded creator | 66.2 [64.3–80.6] | 51.6 [46.6–56.7] | **−22.1%** | 317 → 224 (−29.3%) |
| `Account.first` control | 69.8 [68.5–74.2] | 75.5 [68.2–77.5] | +8.3% | 152 → 152 |

Already-loaded planning has separated ranges in this final cohort. Creator
and presentation ranges overlap, and the negative control also moves by
8.3%: the query medians do not establish a stable speedup. The presentation
regression is retained, not replaced with a favorable earlier cohort. Earlier diagnostic
cohorts ranged from a presentation gain to a regression of 2,257.7 → 2,936.3 µs
(+30.1%); those cohorts also predate the final correctness hardening. Per-edge
guard cost, JIT state and shared-orb timing variability remain performance
risks; more controlled repeated cohorts are needed for a strong presentation
or whole-app speed claim. These are warm, small-fixture results, not a claim
about every production database.

### Requests

Times are **ms/request**, median [min–max] of three process means. Allocations
are median objects/request, off → on. Endpoint labels omit fixture IDs and
the bot credential. Default response/record caches:

| Endpoint | Off ms | On ms | Time change | Allocations |
|---|---:|---:|---:|---:|
| Room | 3.017 [2.994–3.412] | 2.607 [2.427–2.750] | −13.6% | 6,161 → 6,161 |
| Messages | 2.840 [2.670–2.902] | 2.653 [2.646–2.867] | −6.6% | 6,097 → 6,097 |
| Sidebar | 3.082 [2.958–3.419] | 2.610 [2.525–3.096] | −15.3% | 6,031 → 6,031 |
| Search | 2.772 [2.674–2.948] | 2.585 [2.466–2.709] | −6.7% | 5,992 → 5,992 |
| Bot JSON | 9.321 [8.323–9.489] | 7.721 [7.610–8.002] | −17.2% | 12,915 → 12,616 |
| Turbo Stream | 9.923 [8.594–10.473] | 10.180 [9.715–11.272] | +2.6% | 15,757 → 15,456 |

With `CAMPFIRE_RESPONSE_CACHE_MB=0`:

| Endpoint | Off ms | On ms | Time change | Allocations |
|---|---:|---:|---:|---:|
| Room | 13.935 [13.125–14.637] | 15.362 [14.702–16.048] | **+10.2%** | 22,672 → 22,377 |
| Messages | 9.132 [8.646–9.472] | 10.601 [9.608–11.118] | **+16.1%** | 15,745 → 15,447 |
| Sidebar | 10.088 [9.127–10.359] | 9.745 [9.461–10.530] | −3.4% | 14,415 → 14,418 |
| Search | 11.844 [10.688–12.207] | 11.961 [10.690–12.777] | +1.0% | 16,188 → 16,076 |
| Bot JSON | 10.642 [9.472–10.877] | 6.922 [6.551–9.848] | −35.0% | 12,916 → 12,616 |
| Turbo Stream | 11.074 [9.938–11.214] | 11.600 [9.176–11.791] | +4.8% | 16,292 → 15,991 |

Untimed probes warmed each endpoint ten times, then checked HTTP 200 and
fixture content: ten JSON messages, the expected HTML/search/sidebar text,
and Turbo Stream append content. All six passed with Lowrail off and on in
both cache modes. Per measured request, the new unit completed:

| Endpoint | Default caches | Response cache disabled |
|---|---:|---:|
| Room | 0 | 3 |
| Messages | 0 | 3 |
| Sidebar | 0 | 0 |
| Search | 0 | 3 |
| Bot JSON | 3 | 3 |
| Turbo Stream | 3 | 3 |

Off had zero hits throughout. Thus the cached HTML improvements **cannot be
credited to saved preload work**. The no-response-cache room and messages
regressions have separated ranges despite lower allocation counts. Bot JSON
improved in both modes, but its disabled-cache ranges overlap. Control
movement, changed runtime/ISeq state and small sample size prevent a blanket
causal speed claim. The useful established result is structural reuse with
fewer allocations and a faster already-loaded micro path; guard-heavy query
and request workloads can still regress. Improving those costs is open work,
not a reason to omit the negative measurements.

## Risks and boundaries

- Private Rails preloader APIs and scheduling rules need rechecking on
  upgrades; exact version/source guards prevent reusing an old build with
  different files, but do not replace testing a newly built Rails version.
- The initial plan fill has cold cost, and one unit's conservative method
  guard can disable unrelated preload plans while a stub is active. Cached
  requests with no preload work have no planning win to collect.
- Normal Rails schema invalidation (`reset_column_information`) is observed;
  external DDL without Rails noticing it is not. Mutating private reflection
  internals or the internals of existing custom type objects is not a
  certified invalidation API. App code overriding definition hooks without
  `super`, visibility-only changes, refinements and C-side metaprogramming
  retain the guard system's documented limitations.
- Row reads, authorization, connection role/shard choice, association data,
  missing-record handling and SQL execution are not memoized. Database
  fixture sizes, SQL latency and cache hit ratios strongly affect the gain.
- Attribute/type-dispatch specialization, arbitrary app-scope certification,
  through plans and query-chain compilation remain separate future work.
