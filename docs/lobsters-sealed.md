# Bet L: sealed lowering on Lobsters

Branch-only exploration. The app is ruby/ruby-bench at
[`351a39b`](https://github.com/ruby/ruby-bench/commit/351a39b77e6c06f4f4fa03148639b10a6bb0c716),
Ruby 4.0.7 / Rails 8.1.4, anonymous `GET /` and `GET /s/enr7ye`.
These are the front/story pair from bet H, not observed production traffic.
No app source/configuration patch, cache-policy change or upstream action.

## Result: killed after one extension (2026-10-22)

**No second accepted price. No Ir, RPS, retry or main promotion.** The
branch-only prototype is retained for inspection, not recommended for merging.
The runtime baseline is
[`a9a71db`](https://github.com/thomasklemm/lowrail/commit/a9a71dbf3d93b7b881d2833e7ebf6756ebf5d967);
the published extension is
[`bb0a61c`](https://github.com/thomasklemm/lowrail/commit/bb0a61c41b97615f3efc35afee629e85740426c3).
Its entire tree is identical to the pre-measurement local commit recorded in
the raw pins: only an automatically injected commit-message trailer was
removed before first publication. The export preserves that original local
revision and supplies the published revision separately; no runtime remeasure.

Each screen has three serial off-A/on/off-B rounds, 500 warmups and 600
requests/route/worker, plus three separate 10-request coverage workers.
Every seeded status/body/all-header comparison passes: 36 response companions
in measured workers and 12 in coverage workers per screen, seeds 0/1. These
are controlled companions, not a raw-entropy equality claim.

| Screen / route | Median objects/request, off-A / off-B / on | Wall on/off | A/A max round spread | Clear win? |
|---|---:|---:|---:|---|
| Main tiers `/` | 14,188 / 14,188 / 14,188 | −2.702% | 4.974% | no |
| Main tiers `/s/enr7ye` | 3,549 / 3,549 / 3,555 | −3.300% | 9.946% | no |
| Extended collection `/` | 14,188 / 14,188 / 14,188 | −1.111% | 4.098% | no |
| Extended collection `/s/enr7ye` | 3,549 / 3,549 / 3,555 | −1.400% | 7.406% | no |

All three extension rounds have front on medians of 14,188. The off-A/off-B
pairs are 14,188/14,188, 14,189/14,188 and 14,188/14,189: on is never below
**both** controls. The prospective strict reduction fails in every round,
without needing the CI condition. Story medians are 3,549/3,549/3,555 in
each round. Front collection coverage becomes **1 hit/request**, zero collection
fallbacks. Story coverage stays **4 instantiate hits + 3 preload fallbacks**
per request. The +6 objects are observed, not causally attributed to those
fallbacks; this bet did not attempt a second preload variant.

The [data export](lobsters-sealed-data.json) retains all worker request/wall/
allocation samples, response digests, coverage maps, schedule, source pins,
screen summaries, full off-only profiles, caller-line census and build ledger.
Large artifact-file lists and entropy traces have canonical JSON hashes;
responses, DB contents and credentials are not published. Raw result/protocol
hashes identify the private originals. There are no discarded measured workers.

## Why a collection hit saves zero objects

This is **branch deletion, not partial-render elimination**. Both stock and
lowered paths retain the existing locals and allocate the same cache,
PartialIteration and map/result machinery, assign the same per-item locals,
and call live `Template#render` and `build_rendered_template` for every item.
The only removed alternatives
are `template || find_template(...)` and `if layout`. For this nonnil-template,
nil-layout input, neither alternative executes in stock Rails, so neither
allocates anything to remove. The admission extension changes eligibility,
not that loop or the rendered partial.

Off-only StackProf finds collection inclusive allocations **203,780/283,049
(72.00%)**, but its method self is **540/20 = 27 objects/request (0.191%)**.
Its inclusive CPU is 1,060/1,471 samples (72.06%); self is only 2 samples.
The one hit covers the collection invocation, not a claim that 72% of the
request is simplified. Even those 27 self objects are retained, not a saving
ceiling achieved by this variant. The measured zero median allocation delta
agrees with the two source paths; it is not evidence that partial work is free.

## Ranked refusals and remaining exposure

These are **request-work shares**, not production request-frequency weights.
Inclusive rows overlap and must not be added. Off-only discovery used 20
requests/route at object interval 1 and 300 CPU requests at 1,000 µs interval.

| Context / rank | Front page | Story page | Refusal or disposition |
|---|---:|---:|---|
| Collection/partial context | 72.00% inclusive allocation samples; 1 call/request | no warm collection call | Main demanded the blog inventory. The one generic collection extension admits it exactly but removes zero allocating work; killed. |
| Generated URL helpers | generic 10.75% inclusive; optimized 4.30% | optimized 5.47%; generic 3.75% | `route/path` quarantined, unchanged. These contexts include live path/parameter work, not certified removable credit. |
| `link_to` context | 3.14% inclusive; 61 calls/request | 2.40%; 13 calls/request | Guarded pass quarantined; sealed pass requires eager-loaded ArticlesController. No generalized link certificate attempted. |
| AR loading/preloading | no warm `_load_from_sql` calls or AR hits; warm cached model restoration remains | `_load_from_sql` 1.69% inclusive, 4 calls; preload 1.10% | Build has 24 instantiate variants and 71 eligible preload edges; 86 readers refuse (76 no-scope, 6 dynamic-scope, 3 planning-implementation, 1 through). Fifteen preload edges refuse (6 scope, 9 through). Build counts do not imply request coverage. |
| Form/token | zero calls | zero calls | Article/Comment/ArticlesController inventory is absent, not an eager-loading failure in Lobsters. Broadening form/token would not hit these anonymous routes. |

## Off-arm allocation sites, grouped by subsystem

This additional **off-only, untimed census** uses the same two routes, DB,
headers and validation hooks: 500 warmups, ten requests/route, then
`ObjectSpace.trace_object_allocations` with GC disabled during collection.
Counts are observed allocations, **not removable budgets**. Site rows below
sum classes at the same source line; the export retains every class/site.
Groups follow source ownership; AR includes query/association work, not just
instantiation. App model slug/URL code remains in Other; Rails routing/URL
sources are separate. Rack includes ActionDispatch HTTP/middleware and the
MockRequest client. Do not infer production Puma overhead from that group.

| Source ownership | `/`, objects/request | `/s/enr7ye`, objects/request |
|---|---:|---:|
| AR/model, including instantiation/query/associations | 1,886.0 | 873.4 |
| Views/helpers | 2,558.0 | 419.0 |
| Rails routing/URL | 1,504.0 | 206.0 |
| Rack/HTTP | 335.8 | 338.8 |
| Other source-attributed | 6,709.1 | 1,380.6 |
| GC counter residual, not enumerated/source-attributed | 1,194.2 | 334.0 |
| **Census total** | **14,187.1** | **3,551.8** |
| **Original off-arm screen median** | **14,188** | **3,549** |

The totals deliberately are not forced to match the separate screen's
medians: this is a traced, GC-disabled mean with a different collection
boundary. Attributed totals are exactly 129,929/141,871 and 32,178/35,518
counter objects across ten requests. The residual is left unattributed,
not silently assigned to Rails. Stock VM-internal objects are not all
enumerable by `ObjectSpace.each_object`.

| Subsystem | Top `/` source sites, objects/request | Top `/s/enr7ye` source sites, objects/request |
|---|---|---|
| AR/model | `active_model/type/string.rb:39` **275**; `active_record/associations.rb:60` **176**; `attribute_set/builder.rb:16,22,28` **121 each** | `relation/where_clause.rb:29` **48**; `relation/delegation.rb:139` **26**; `relation.rb:77` **25**; `where_clause.rb:111` **24**; `typed_store/typed_hash.rb:16` **24** |
| Views/helpers | `tag_helper.rb:309` **370**; `erb/util.rb:143` **229**; `tag_helper.rb:237` **114**; `asset_url_helper.rb:208,217` **101 each** | `tag_helper.rb:309` **44**; `erb/util.rb:143` **22**; `tag_helper.rb:237` **20**, `:232` **15**; render event `structured_event_subscriber.rb:61` **10** |
| Routing/URL | Journey `visitors.rb:40` **220**, `:51` **137**; `http/url.rb:170` **137**; `route_set.rb:214,248` **89 each** | Journey `visitors.rb:40` **34**, `:51` **20**; `http/url.rb:170` **20**; `route_set.rb:214,248` **16 each** |
| Rack/HTTP | `static.rb:145` **27**; Rack `utils.rb:511` **22**, `:507` **15**; static `:156,146` **9 each** | `static.rb:145` **27**; Rack `utils.rb:511` **22**, `:507` **15**; static `:156,146` **9 each** |
| Other | `<internal:marshal>:34` **1,517**; app `story.rb:848,849` slug work **270 each**, `:867` **216**; TZInfo `timestamp.rb:208` **248** | `<internal:marshal>:34` **143**; validation `blog_entropy.rb:116` **57**; `<internal:array>:246` **51**; TZInfo `timestamp.rb:208` **30**; SafeBuffer `output_safety.rb:242` **30**; SQLite `statement.rb:143` **29** |

Marshal includes cached model reconstruction, so zero warm instantiate hits
does **not** mean zero model/attribute allocation on `/`. Its StackProf
inclusive context is 2,599 objects/request but its caller-line census site is
1,517; these are different attribution methods, not additive savings. The
validation adapter itself contributes **219 / 87 source-attributed objects**
per front/story request even outside controlled companions (e.g. caller
locations in live clock/random wrappers). That shared off/on harness cost is
explicitly included, not mislabeled as a Lobsters optimization opportunity.
No hook-free or third specialization screen was run.

## One bounded extension: prospective screen rule

The current-main tier screen is allocation-neutral on `/` and adds six
objects on the story. There are no warm form/token calls on either route.
The chosen extension removes collection's **blog-specific inventory**, not
its stock-body/source, exact-renderer-holder, epoch or no-layout conditions.
The view is opaque: it is passed to live `Template#render` unchanged.
Token/form and quarantined link/route lowering remain unchanged.

Run exactly one extension screen with the same three off-A/on/off-B rounds,
500 warmups and 600 samples/route/worker. Require both seeds' exact status,
whole body and **all** headers in every round. To advance the chosen front
page, require fewer median allocations than both off arms in every round and
an allocation-effect 95% interval wholly below the A/A noise envelope.
No retry, filtering or second variant. Otherwise stop with no Ir/RPS cohort.
Only a clear screen win could advance to one interpreter cohort, with both
total/no-GC A/A 95% intervals wholly within **±0.1%**, fixed before counting;
RPS would additionally require a clear win and the 44a33c4/544ad8d protocol,
A/A first. No counted instruction or RPS work has been launched.

## Reused fixture and tooling

The dependency-only Puma 8.0.2 Gemfile, lock and entropy policy, validation
adapter, `script/native-bench` and `script/screen` are copied from
[`6510cd2`](https://github.com/thomasklemm/lowrail/commit/6510cd2f2cd4384fcf648c638f5f720d00c8d9c8).
The only shared-driver change retains upstream's SQLite `:memory:` instead
of overriding `DATABASE_URL` to a disk copy. The external setup performs
the same SQLite backup as upstream `benchmark.rb` and bet H. The shipped DB is
SHA256
`d9817ef63aed4989d504d26e341b33d163448cb123f10981082718876227a820`.
The disposable boot/build copy's physical SQLite SHA256 is
`b90816703504429b1926c97c50a960ce9a29235b7543f3159fbc441ed1e9406b`;
that is the actual seed pin in every worker and profile, not the shipped-file
hash. Read-only SQLite logical dumps of both have **105,150 statements** and
the identical SHA256
`fde8d90435dab9be21dc493fe2f1823dd62a30d561333074265fac37c2e07bdf`.
No rows/schema were replaced or normalized. Both screens use the same copy.
The overlay and policy bytes are unchanged. Untimed exact companions alone
control declared entropy/clocks; the timed screen retains live inputs.

The public build runs against a disposable disk copy of that same schema:
runtime-builder subprocesses intentionally strip RUBYOPT, so they cannot
receive a fixture-restoring preloader. A direct default-memory build produces
zero AR units because its new DB is empty. No app config is changed to evade
this. Runtime screening restores the original in-memory fixture after boot,
and proves actual AR/collection hits independently of build counts.

Both native screens are direction-finding YJIT diagnostics, not JIT-flat,
Ir, RPS, production admission, whole-app or own-suite certificates.

## Verification and limitations

The public-CLI nonblog collection regression passes: **1 run, 14 assertions,
zero failures/errors/skips**, including escaping, live helpers, counters,
iteration, a second controller and layout fallback. Its commands are:

```sh
mise exec ruby@4.0.7 -- ruby -Igem/lib:gem/test gem/test/form_scaffold_test.rb \
  --name /collection_admission_outside/ --seed 1729
(cd gem && mise exec ruby@4.0.7 -- rake test)
```

The broader gem command is **not green**: 194 runs / 2,342 assertions,
9 failures / 1 error / 31 named skips. Failures group into Bootsnap policy
refusal, mixed Minitest 5/6 recorder loading, late-YJIT status, and the missing
Sorbet prerequisite's broken skip helper. One representative of each group
reproduces on unchanged `a9a71db` sources: 4 runs / 17 assertions,
3 failures / 1 error / zero skips. This is not proof about every failing test.
The blog production and other corpus prerequisites are absent; no whole-app
`lowrail verify`, full gate or Thermos certification is claimed. Do not merge
the exploratory admission extension on these bounded checks.

## Reproduction

From a checkout with `mise install ruby@4.0.7` and `cargo build --locked`:

```sh
git clone https://github.com/ruby/ruby-bench .corpus/ruby-bench
git -C .corpus/ruby-bench checkout 351a39b77e6c06f4f4fa03148639b10a6bb0c716
BUNDLE_GEMFILE="$PWD/fixtures/corpus/lobsters-rps.Gemfile" mise exec ruby@4.0.7 -- bundle install
(cd gem && mise exec ruby@4.0.7 -- rake compile)
mkdir -p .lowrail/lobsters/seed
cp .corpus/ruby-bench/benchmarks/lobsters/db/production.sqlite3 .lowrail/lobsters/seed/primary.sqlite3
BUNDLE_GEMFILE="$PWD/fixtures/corpus/lobsters-rps.Gemfile" \
  DATABASE_URL="sqlite3:$PWD/.lowrail/lobsters/seed/primary.sqlite3" \
  mise exec ruby@4.0.7 -- target/debug/lowrail build \
  "$PWD/.corpus/ruby-bench/benchmarks/lobsters" --sealed --env production --jit yjit
mise exec ruby@4.0.7 -- ruby script/screen "$PWD/.corpus/ruby-bench/benchmarks/lobsters" / /s/enr7ye \
  --config PRIVATE_CONFIG --output NEW_PRIVATE_DIRECTORY \
  --exploration-setup "$PWD/bench/experiments/lobsters_sealed_screen.rb" --warmup 500 --samples 600
```

Private config supplies `workload: "lobsters"`, absolute `app`, `seed`,
`artifact` (app's `.lowrail`), `gemfile`, `exploration_only: true`, headers
`{"HTTP_X_REQUEST_ID":"lowrail-lobsters-sealed"}`, and `exploration_sources`
containing `lobsters_native_validation.rb`, `lobsters-rps-entropy.json` and
`blog_entropy.rb`. All are source-pinned before workers launch.

The off-only CPU/allocation ranking uses
`bench/experiments/lobsters_sealed_profile.rb APP SEED NEW_JSON` with
`LOWRAIL=0 RAILS_ENV=production BUNDLE_GEMFILE=... ruby --yjit`.
It retains every StackProf frame and denominator, not just selected totals.

The caller-line census is reproducible with the same environment and seed:

```sh
LOWRAIL=0 RAILS_ENV=production BUNDLE_GEMFILE="$PWD/fixtures/corpus/lobsters-rps.Gemfile" \
  mise exec ruby@4.0.7 -- ruby --yjit bench/experiments/lobsters_allocation_sites.rb \
  "$PWD/.corpus/ruby-bench/benchmarks/lobsters" "$PWD/.lowrail/lobsters/seed" NEW_JSON
```
