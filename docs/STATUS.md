# Status

Decisions on what to pursue, park or reject: [DECISIONS.md](DECISIONS.md).

Living summary of what works, what was learned, and what is next. Details
live in the linked docs; numbers come from executed runs, dated.

## At a glance (2026-10-21)

| Area | State |
|---|---|
| Token allocation / current blog price | Token-only +32/request traced and removed; now approximately allocation-neutral, not a standalone win. The one prospective `b059fc9` cohort is **accepted: −15.022961% total interpreter Ir [−15.051352,−14.996655]**, no-GC −15.021453%. Both A/A intervals wholly within preregistered ±0.1%; all other gates pass, no measurement retry/exclusions, slot 1 released. One three-unit endpoint/fixture only. [Trace](passes/token-allocation.md), [price and export](passes/production-aa01-reprice.md) |
| Production dispatch safety | Sealed token's preexisting private-helper / reflective-send P1 fixed with captured stock `BasicObject#instance_exec` fcalls; same primitive covers form helpers (except the named route's original public dispatch) and the separate link fix, collection unchanged. **−15.225536% remains defective-source only**. The [62f8a6b attempt](passes/production-dispatch-reprice.md) stays **rejected no-GC A/A**, not rescored by the later accepted cohort; YJIT seam paused, `835cf16` parked. [Sweep and gates](passes/sealed-production.md#helper-dispatch-safety) |
| Default build | lowers nothing: `view/link_to` and `route/path` quarantined (45fd07a); five-app manifests have 0 units |
| Correctness gates | original five-app outcomes/SQL and Rails 8.1.4 AP/AV/AR outcomes identical; hook-free delivery preserves loader selection; Redprints' strict load census passes with targeted Bundlebun refusal, **0 hits** ([compatibility report](compat.md)) |
| Opt-in passes | guarded selection: only props + endpoint; seven cached-fact passes sealed-only after suppressed-hook audit; see [DECISIONS](DECISIONS.md#passes) |
| Accepted request work | post-fix Starter `GET /dashboard` JSON config binding and [current-source blog form/token/collection](passes/production-aa01-reprice.md), each one endpoint/fixture, interpreter Ir not latency, sealed-only and not promoted. README/results refresh belongs to the docs owner. Blog's old defective-source price stays historical and its first corrected-source cohort stays rejected. No YJIT instruction claim |
| Real-Puma throughput | [Separate scoped result and tradeoffs](../README.md#full-request-throughput-real-puma): blog sealed opt-in, stock Ruby YJIT; preregistered RPS rule passes, **p99 and GC collections increase, cause not established**. One route, one orb, branch harness on older measured main; not whole-app, capacity or admission evidence |
| Not production request prices | production YJIT method stage 1 rejected; [reaper-driven late compilation](passes/production-yjit-method.md) explains the native rejection, not a price. [Frozen props](passes/props-native.md#accepted-combined-interpreter-micro-integration-deferred) is an isolated micro, integration deferred. Fizzy N=50 **INVALID** (heap); N=10 accepted only as a scoped warm bench price, an instruction increase, not production admission ([specimen](block-link-specimen.md#replacement-result-scoped-warm-bench-price-not-a-win)) |
| Verification-only test tier | AR Article/Comment coverage, not production admission; link/form/token/collection/preload remain refused. [Explicit-path eager-load coverage](test-certificate.md#documented-explicit-path-invocation-actual-eager-loading) at [9773980](https://github.com/thomasklemm/lowrail/commit/97739801174c015e948428c2f35fcb777a888b02); [ccea6df](https://github.com/thomasklemm/lowrail/commit/ccea6df6addc6958b6dbdadccc5e6c6f11727032) retains the fixed timeout diagnosis, without erasing the earlier failure |
| Campfire r81 | **KILLED after screen + one branch-only allocation variant; slot 2 released, no Ir.** Original adds ~52 objects/request; variant removes those but has no clear wall win (−4.168%, A/A 4.293%). Both screens reject body/headers even off/off. 52 warm hits + 2 STI fallbacks; cold 103 hits outside windows. Named browser/entropy/Redis-expiry rejections, blog feature exemption and 10 cached-bind gaps remain ([evidence](campfire-bench.md#13-screen-one-allocation-only-variant-then-kill)) |
| Historical upper bounds | endpoint render path, −26 %/−37 % handwritten specimens, not supported passes or current prices; caller-side certification loses (0fbb909) |
| Types/MCP | source-backed Sorbet + Rails signatures; blog slots 2/99/7/188, Wikino 0/1,715/1/1,129 (proven/static/observed/unknown); 517 original wrapped returns → static, forwarding placeholders removed; blog Steep 51 → 6 → 2, still non-gating ([details](types.md#sorbet-and-framework-signatures-follow-up--2026-10-21)) |
| Prism 2 | Ruby dev + Rust 2.0.0; explicit target grammar, unknown versions refuse. Census/delivered bytes and Rust facts/types/MCP match; both Ruby axes tested, named production-fixture skips preserved. No Prism.find witness adoption or speed claim ([evidence](prism-2.md)) |
| Rails 8.2 alpha | [Pinned corpus, source drift and fixed-count follow-up](rails-8.2.md); Campfire load/SQL variation reproduced off/off; Writebook lock corrected, baseline failures/Fizzy residuals retained; support blocked, sealed re-certification waits for beta/RC |
| Limits / next work | default/quarantine unchanged; broader sealed admission and active own-suite coverage remain incomplete; frozen-props integration deferred; Ruby 4.1/ZJIT remains a separate matrix |

## Blog prospective new-rule re-price: accepted (2026-10-21)

On clean detached `b059fc9`, **−15.022961% total Ir
[−15.051352,−14.996655]**, no-GC **−15.021453%
[−15.044109,−14.967704]**. Both A/A intervals lie wholly within the
prospectively published ±0.1%: total [−0.068389,+0.004169]%, no-GC
[−0.077337,+0.033586]%. All heap/exact-page/brk/mode and fresh pre/post cold,
192+192, native/deopt gates pass. Exactly 18 serial workers / six rounds;
72 dump totals/self sums, 36 subtractions, 18 certificates and 681 pins
independently reconcile. Launcher refusals outside counter work are retained;
no measurement retry/exclusions, service stopped and slot 1 released.

Token-only's traced +32 allocations/request is removed, leaving it neutral,
not a standalone win. The stack allocates 2281.25 → 1903.90/request
(diagnostic). This is a three-unit endpoint/fixture interpreter price, not
latency, YJIT, test-tier support or whole-app promotion. The prior rejection
below is unchanged, never rescored. [Protocol and complete accepted export](passes/production-aa01-reprice.md).

## Blog first dispatch-corrected re-price: rejected (2026-10-21)

The screen is exact and saves **343 objects/request** (2412/2412/2069
off-A/off-B/on), versus the earlier S reference saving 393. The single
authorized historical-method interpreter cohort at clean detached `62f8a6b`
then fails **GC-excluded A/A [+0.009283,+0.062511]%**, which excludes zero.
Total A/A, heaps/exact pages/brk/mode pass. **No accepted replacement price**:
raw total **−14.536782% [−14.552516,−14.507619]** and no-GC **−14.537277%**
are diagnostics only. All 72 dumps/self-cost sums, 36 subtractions, 18 source
certificates and 681 pins reconcile. Pre/post seeded cold, 192+192 observable
pairs and native/deopt gates pass; raw entropy still rejects. No retry,
exclusions, new cohort or YJIT; slot 1 released. The prior −15.225536% remains
defective-source only. [Protocol and complete data](passes/production-dispatch-reprice.md).

## Campfire r81: companions accepted, native bet killed (2026-10-21)

The shared three-round room screen adds about 52 allocations/request and
shows no resolved wall win. `ARShadow.enabled?` allocates one Array per hit
even with shadowing off. One branch-only allocation-free predicate brings
off-A/off-B/on medians to 15525.5/15525/15524.5, effectively a tie; wall
−4.168% does not clear 3× the 4.293% A/A floor. Both screens also reject body/
all-header identity off/off with valid entropy source pins: an unclassified
warm validation boundary, not a permitted cold exception. **Kill the Ir
cohort, release slot 2; no prototype code reaches main.** Bet A independently
finds allocation increases on all five routes, no resolved wall-time gain.
[Full screen results and private-receipt hashes](campfire-bench.md#13-screen-one-allocation-only-variant-then-kill).

One authorized rerun, exit 0: both seeds match HTTP status/header/body bytes,
SQLite schema/all rows, loads, ordered non-Lowrail features, observed events
and completed/post-exit state off/off/on. The 52-hit warm instantiation target
is unchanged; 103 cold login+room hits are outside the proposed windows.
**Named qualifications:** browser other-thread test nondeterminism; raw CSRF/
cookie/ETag/runtime/session-clock rejections; accepted off/off Redis absolute
expiry (`rate-limit:sessions` only, all 42 names/values and 41 other expiries
exact); exact blog Lowrail feature rule with path/content hashes; ten cached
lazy-Proc bind values unavailable/worker (153 SQL records retained, never
evaluated/recast). This is not active sealed own-suite or cold raw support.

All 16 exact-worker tool=none windows preserve frozen pages and the closed
52-hit/two-STI map. Slot 2 was assigned, but its launcher stops before any
counted Callgrind worker/window (initial log overwritten, cause unconfirmed).
The new screen-first policy led to the two rejected screens above, not pricing.
No speed claim, further attempt, app patch, runtime/default/quarantine change, or Oct-8-app
equivalence. [Full retained evidence and hashes](campfire-bench.md#12-one-authorized-companion-rerun-accepted-with-named-items).

## Fizzy block-link heap protocol (2026-10-21)

**Decision rule first:** any pin/mode/brk/exact-page/mix violation invalidates
the whole cohort; both total/no-GC A/A 95% intervals must contain zero wholly
within ±0.5%. The completed N=0/50 interpreter cohort is **INVALID**:
both off/on grow beyond the declared heap pages. **Diagnostics only, not a
price or direction claim:** total Δ +0.415777% [+0.364704, +0.733074],
no-GC Δ +0.413692% [+0.364724, +0.448149]. A/A, pins, mode, brk and exact
1200-hit mix pass, but heap failure invalidates the whole cohort. All 18
workers / 72 dumps / 36 subtractions reconcile; no retry/exclusions. Its
service/slot is released. [Complete INVALID export](fizzy-link-ir-invalid.json).

**N=0/10 accepted scoped warm bench price, not a win:** total Ir
**+0.403071% [+0.386235, +0.429585]**, GC-excluded Ir **+0.402000%
[+0.380081, +0.421142]** on these six Fizzy GETs with the stated floors only.
Cold off/off/on stays **RED**. Accepted named off/off rejections: nine
SolidCache `created_at` values and historical order-sensitive estimation SQL
interleaving. **Uncovered:** payload/assigns, lazy cached-bind values and
SolidCache completion. No production admission or cold-start claim.

Untimed **Valgrind tool=none** off-only whole-window budgeting at N=0/10
freezes the common init slots at `3350000,300000,460000,30000,20000` (254 MB of
slots), rather than mistaking init floors for hard caps. Fresh off/on workers
in both phase orders retain exact pages with zero page additions in all 16
windows. Full on windows have exactly **240 hits/19 identities**, preserving
the four explicit zeros. The one authorized replacement completes all 18
workers after the old slot release, six rounds / seed 41231 / off_a/off_b/on /
jobs=1. All 72 measured windows retain exact pages and zero additions; every
full on window has the exact 240-hit mix. A/A intervals contain zero within
±0.5%: total [−0.046920, +0.026381], no-GC [−0.042940, +0.026493].
Both 72 dumps and 36 subtractions independently reconcile. Same detached
harness and brk512 tool; no app/config/GC-policy change, higher-segment tool,
retry, exclusions, YJIT or pooling with N=50. Slot released.
[Complete scoped N=10 export](fizzy-link-ir-n10.json).
[Protocol and reproduction](block-link-specimen.md#untimed-heap-preconditioning-prefer-n10-on-the-existing-tool),
[all untimed evidence, including failed alternatives](fizzy-link-heap.json).

## Works (2026-10-20)

- **Production tracing fixed; promotion unchanged (2026-10-21):**
  [ed7cbbe](https://github.com/thomasklemm/lowrail/commit/ed7cbbe8f8ab6e9b7be24775ac76a94cebecd95e)
  removes global return observers from activation and cold delivery, using
  targeted initialization and a Loader witness. Native warmed Starter
  requests have **zero `exit_trace_leave`**. One finite six-round check per
  mode: interpreter **−10.156% [−10.219, −10.084]** accepted, 11 hits/request
  and no fallbacks in separate coverage; YJIT **rejected** both A/A and
  measured-window JIT flatness (10/24 workers). Raw −0.153% is not a speed
  claim. Untimed YJIT has 0 hits / 9,911 fallbacks because a JIT-disabled
  artifact certified a different `Array#each` implementation. That correct
  fact refusal must not be weakened. Config remains sealed-only, not
  promoted. Old cohorts, the CASA pre-flags SQL RED and the Redprints load
  boundary remain recorded separately. [Evidence and emit proposal](passes/yjit-regression.md).
- **JIT admission and drift (2026-10-21):** `build --jit MODE` certifies in
  the explicit mode; the manifest's actual `certification_jit` must match
  before installers. Missing/different metadata refuses the whole artifact.
  Actual mode changes by initialize! completion are debug/stats/verify/bench
  diagnostics, not uninstalls or forced app config. Doctor separately compares
  Lowrail-off startup/after-boot modes. Regressions cover both early mismatch
  directions and Rails late enablement; deploy YJIT at startup and rebuild
  `--jit yjit`. No new measurements or pass promotion.

Ruby 4.0+ (gemspec), developed on 4.0.7; the second target is Ruby 4.1
([separate compatibility matrix](ruby-4.1.md)). Ruby 3.4 was dropped by owner
decision on 2026-10-20. Historical, not current support evidence: real-blog
on Ruby 3.4.11 built the same 11 units and verified 21/21 identical with
114 hits.

**Quarantine supersedes the cached-fact results below.** Memo, file-digest
memo, all three AR passes and config binding are now sealed-only; their old
guarded commands refuse, and their previous hit maps are historical, not
current support. Defaults remain empty. Production sealed research requires
the separate contract; test processes refuse sealed artifacts. See the
[suppressed-hook audit and current maps](passes/suppressed-hooks.md).

- **Gem-breadth corpus:** four reproducible dependency-only Rails 8.1.4 /
  Ruby 4.0.7 overlays add CASA, Writebook, Fizzy and CodeTriage. CASA's I18n
  date formatting and Fizzy's Active Storage callback exposed genuine early
  loads; initialization, already-loaded-constant and lazy model/epoch gates
  fix them with regressions. Opt-in verify load censuses found further
  preload loads. Hook-free delivery fixes require-hooks/Bootsnap adapter
  selection; Bundlebun's unsorted integration enumeration requires a targeted
  delivery/activation refusal, so Redprints loses its 277 hits. Fresh
  framework artifacts recover all instantiate hits; an
  intermediate 118-hit loss was correct refusal of an old runtime source
  hash, not a missing `initialize!` path. Baseline failures, browser coverage,
  SQL controls, per-app hits/fallbacks, pins and boot/build timings:
  [compat.md](compat.md).

- **Post-registry cleanup:** all build selection now uses `--passes`; the five
  transitional per-pass flags are removed. Superseded cached-reader, preload
  and memo runners are removed, as are instantiate's request/micro branches.
  Its internal-cost/StackProf breakdown and the Lowrail-off AR implementation
  comparison remain diagnostic, with their operation workers unchanged.
  Application activation already has one owner; component-suite/test calls
  and AR dependency-invalidation hooks are not redundant activation paths.
  No gem runtime source changes are included in this cleanup.

  Fresh pre-K default/all-opt-in builds across all five corpus apps, including
  explicit browser gates, retain **1,626 identical gate outcomes / 34,042
  identical ordered own-thread SQL events** in 20 before/after cases (suite
  overlap is counted). Entire manifests and ledger identities/multiplicities
  match; non-system per-unit hit/fallback maps match exactly. Eighteen total
  maps are exact. The two Campfire browser controls are A/A on byte-identical
  runtime code and manifests, not counter-equality claims:

  | Browser build | Hits before → after | Fallbacks before → after |
  |---|---:|---:|
  | default | 4,169 → 4,193 | 0 → 0 |
  | all-opt-in | 9,904 → 9,840 | 847 → 843 |

  Default variance is at units 32/44/58 (+12/+4/+8); the all-opt-in map also
  varies in dependent AR work. All original maps and other-thread SQL
  advisories are [retained](cleanup-equivalence.json), alongside the earlier
  [request-count attribution](runtime-pass-equivalence.json). Rust **34 tests**,
  gem **90 tests / 1,575 assertions** (5 optional skips), bench **20 tests / 155
  assertions** pass. Retained breakdown worker arguments, environment and
  summary match the old diagnostic. No new speed/cold-cost claim; precompiling
  `passes.rb` remains a separate follow-up.

  After pulling main (including K), combined checks pass: Rust **34 tests**,
  gem **91 tests / 1,586 assertions** (5 optional skips), bench **21 tests /
  165 assertions**. A rebuilt default blog retains 21 identical outcomes and
  125 identical ordered queries at both seeds: **57/0** hits/fallbacks at
  41231, **55/1** at 14. The full cleanup matrix above remains explicitly
  pre-K, not relabeled as a post-integration corpus run.
- **Blog counter-order investigation:** archived runtimes `491ea27` and
  `f17790c` match exactly in 20 serial verifies each at `SEED=41231`
  (57 hits, zero fallbacks), and seed-by-seed for seeds 0–19:

  | Hits / fallbacks | Runs per runtime | Seeds |
  |---|---:|---|
  | 57 / 0 | 8 | 2, 11, 13, 15–19 |
  | 56 / 1 | 8 | 0, 4, 6–10, 12 |
  | 55 / 1 | 4 | 1, 3, 5, 14 |

  All 80 verifies retain 21 identical outcomes and 125 identical ordered
  same-thread queries; the complete per-unit maps match between runtimes.
  At seed 14, `CommentTest#test_belongs_to_article_association` creates a
  comment; its `after_create_commit` broadcasts the article before a controller
  request. At seed 0 the destroy-comment callback runs inside
  `ArticleTest#test_destroys_comments_when_article_is_destroyed` instead.
  Unit 0 correctly rejects `@self#article_path`: that method is **absent** on
  the anonymous view class. Tracing the original `link_to` shows it absent on
  entry and present on return at Rails' `route_set.rb:334`: lazy route loading,
  not an object-id cache collision or a registry regression. The fallback can
  also skip a nested unit 1 route hit. No guard is weakened or changed.
  [Retained per-seed maps and digests](guard-order-equivalence.json).

  Plain `lowrail verify` chooses a fresh seed on each invocation, prints
  `lowrail verify: test seed N for every run` to **stderr**, and shares it
  across off/on/bisect runs. Existing `SEED`, `TESTOPTS` or `SPEC_OPTS` takes
  precedence; it does not announce a generated seed in that case. Reproduce
  the 55/1 case with `SEED=14 PARALLEL_WORKERS=1 MT_CPU=1 lowrail verify
  .corpus/real-blog-r4`. The default seed policy is unchanged.
- **Compiled ERB investigation, no new pass** ([survey/profile/refusals](passes/erb.md)):
  literal-run fusion rejected (blog 1 / Campfire 0 / PingCRM 0 / Redprints 0 /
  starter 1 eligible templates). Off-only profiles assign 9.09% of blog edit
  to I18n and 5.72% of uncached Campfire room to URL generation, not savings.
  Blog has 11 key lookups/request (10 misses, 1 hit), all label/submit defaults;
  five result-changing mutation probes bypass the proposed I18n setter epoch.
  Campfire has 7 route guard hits but **zero completed specializations** per
  request: live controller defaults disable Rails' optimized route branch.
  The layout ledger gap is fixed diagnostically: rejected handlers are parsed
  in a method, then refused as `template_context` or `template_parse` rather
  than omitted. Campfire gains 14 refusal rows; its entire 60-unit manifest
  stays identical. Rust: 31 unit + 3 integration tests pass. No runtime fix
  or new pass was made. Three Action View before-gate groups retain 2,747 + 242 +
  173 identical outcomes in every layer. Tag/form attribute work belongs to
  candidate #4. No per-hit or request win claimed.
- **Template lookup surveyed and parked** ([survey](passes/template-lookup.md)):
  all five production HTML workloads already reuse filesystem/bound-template
  caches, with zero warm scans/builds. Rails 8.1.4 and the Campfire alpha both
  return new Templates after `clear_cache`/`DetailsKey.clear` while path and
  context-details identities remain unchanged. A complete filesystem-resolver
  epoch is needed for at most 0.42% opportunity before guards. No new pass.
- **Shared pass benchmark** (`lowrail bench APP --pass NAME [--path /path]`):
  fixed-heap Callgrind primary, independent mandatory A/A controls, actual-JIT
  attestation, general stale-build and activation rejection. Separate counted
  probes keep stats outside measurement windows; AR/preload method micros
  reuse their existing operations with shared off/off/on controls and
  guard-included per-hit budgets. Versioned `result.json` and `table.md` are
  the pass-thread handoff. Request-only or partially modeled measurements do
  not claim promotion. `--measure-budgets` now replays real emitted guarded
  route/link/memo/digest operations and real-controller Inertia bindings with
  independent off/off/on workers, per-operation A/A and the shared heap gates.
  Invocation budgets explicitly price guarded fallbacks without inventing hits.
  Complete instruction budgets explain blog default, Campfire default and
  Starter's opt-in binding effect. The current-K blog predicts/measures
  545k/549k saved instructions/request; uncached Campfire instead pays about
  195k for seven route attempts with zero completions. That default-route cost
  needs a separate exact fix. The current-K memo stack is rejected on two
  individual route A/A controls, not counted as a completed measurement.
  Fresh blog plus cached/uncached Campfire default and +instantiate instruction
  runs reproduce the base-cost result with both A/A and heap controls passing;
  the native guarded micro's failed A/A remains rejected. Exact numbers and
  run-to-run CI caveats are [recorded with the CLI validation](bench.md#cli-validation-against-the-base-cost-experiment).
  Stacked `--passes SET --default-build DIR` retains a separate default
  reference beside no-setup and the measured stack, with the same controls.
  Multi-unit/model `--budgets` input carries guarded operation replicates;
  the additivity residual resamples joint budget vectors and independent
  request boots, rather than adding CI endpoints. Missing budgets remain
  explicitly unmodeled; this does not manufacture instruction micros.
  First default+AR stacks pass all instruction A/A/heap gates: blog **+0.588%**
  versus default, Campfire uncached **−0.066%** (CI crosses zero); no incremental
  ≥2% win. Per-model instruction prices remain unmodeled. See
  [stacked validation](bench.md#stacked-cli-validation) and
  [genuine operation budgets](bench.md#capturing-genuine-instruction-budgets).
  See [the protocol and remaining adapters](bench.md#shared-command-lowrail-bench).
- **Boot facts** (`lowrail facts APP`): modules, methods with owner,
  source location, visibility and ISeq kind, models, controllers, routes and
  compiled template code. Prism classifies origins: real-blog has 13 source
  `def`s against 362 gem-generated methods on app classes.
- **Build-time oracle** (`gem/exe/lowrail-oracle`): a booted view context
  that evaluates helpers with marker strings; probes with special characters
  prove how each marker is escaped. Passes reuse Rails' own rules instead of
  re-implementing them.
- **View pass `link_to`** (`src/lower/view.rs`): per call site
  `((guard && type checks) ? inline : original)`, on the original line, with
  the original call verbatim as fallback.
- **Route pass `route/path`** (`src/lower/route.rs`,
  [docs/passes/route-helpers.md](passes/route-helpers.md)): named-route
  `*_path` calls in templates and in Ruby files under `app/` (the first
  Ruby-file pass, served as ISeqs); probes run the emitted code
  next to the real helper. Guards on `@self` facts are checked per class of
  `self` (`Lowrail.ok?`). Dynamic engine script completion stays in Rails;
  `_url` host normalization is memoized only on the request, keyed by its
  scalar inputs (including in-place string/encoding changes). `url_options`
  and application overrides remain live. `article_url` construction is
  3.71 → 2.21 µs, 25 → 9 allocations (YJIT; see pass notes).
  Block-backed `direct`/`resolve` helpers remain refused with block locations
  and operations: corpus blocks read current state, transform arguments or
  dispatch dynamically; a runtime probe rejects dropping their state/query.
  Arity refusals now identify default-backed parts and optional segments;
  Campfire's 17 such calls all default `user_id` to `"me"`, rather than
  simply recalling missing IDs. Generic generation's mapping, format and
  script-before-parameterization semantics remain an explicit boundary.
- **Active Record preload plans** ([design and measurements](passes/preload-plans.md)):
  guarded gem-level trees, scopes and loader groups computed once; fresh
  Rails Association loaders per call, no cached rows. Schema/reflection/scope
  changes and unsupported shapes retain the original Rails path. Already-loaded
  micro path −22.1% time/−29.3% allocations, but presentation +19.3% and
  response-cache-disabled room +10.2%: not a general application-speed win,
  so it is opt-in (`lowrail build APP --passes default,+preload_plans`) until it no longer
  slows real requests.
- **AR SQL plans** ([survey, guards and measurements](passes/ar-plans.md)),
  opt-in with `lowrail build APP --passes default,+ar_plans`: fixed scoped-association readers
  reuse Rails SQL builders/BindMaps; original relation loading, inverses,
  preloading, strict loading and query cache remain live. Five non-system
  corpus gates: **741 identical outcomes / 16,182 identical traced queries**.
  Campfire has eight eligible readers, **677 genuine hits / 367 explained
  scope/epoch fallbacks**; the other four apps have no eligible reader and
  zero AR-plan hits. Source refusals are in the ledger. Guarded logo reads
  save 21 objects but no measured time (79.14 → 90.66 µs); actual route
  coverage predicts **under 0.2%** time change everywhere. Request medians
  are noise-dominated, including 7–9% movement on zero-hit PingCRM controls.
  Keep opt-in. Attribute dispatch was a guarded negative result; general
  escaping app-chain plans remain unimplemented (SQL-only ceiling 21–22 µs).
- **Active Record instantiation** ([measurements and guards](passes/ar-instantiate.md)),
  opt-in `lowrail build APP --passes default,+ar_instantiate`: normal per-model singleton `def`s,
  lazy builder reuse, method facts and row-wise AR epoch guards; Rails still
  owns initialization, callbacks and STI. Five corpus apps: **779 outcomes
  and 17,261 ordered same-thread SQL events identical**, **3,363 pass hits**;
  Campfire's 3,129 fallbacks are 958 STI rows + 2,171 calls after a captured
  schema-test connection switch. Alpha 20/200-row load-only −38.9%/−37.0%,
  four fewer allocations/row; Rails 8.1 usually regresses. Five interleaved
  request pairs/app established **no request win**. Their blog +25.5% median
  did not control boot/heap phase; it is not an identified hot-path tax.
  See the [controlled instruction and GC diagnosis](bench.md) for the later
  default/instantiate comparison; no native YJIT request win is established.
  Keep it opt-in.
- **Inertia configuration binding** ([contract and measurements](passes/inertia-config.md)),
  opt-in `--passes default,+inertia/config_bind`: fresh controller-bound
  configurations, live shallow-copied options, shared method facts and exact
  ordered-schema/Hash-policy checks. Guarded bind micros save two objects
  and about 3 µs per hit; JSON requests save 10/18/22 objects in the three
  public apps. **Request speedup is unproven: native A/A control failed.**
  Runtime migration step 4 installs shared activation: integrated gates have
  **811 identical outcomes, 514 binding hits, zero fallbacks**, and all 12
  HTML/JSON byte comparisons pass. No temporary setup hook is needed.
- **Guarded memo** ([certificate/refusal details](passes/memo.md)), opt-in
  with `lowrail build APP --passes default,+memo`: fresh-return SHA-256 string reuse, bounded by
  runtime keys and guarded implementation facts. Campfire **634 identical**,
  **1,242 memo reuses** with its debugger disabled in both modes; default-debug
  verification also identical but correctly falls back. Four production HTML
  routes have byte-identical CSP headers in both cache modes. Rails' regexp
  timeout prevents URI memoization by default; file-backed version procs and
  whole importmap resolvers remain refused. real-blog **21 identical**, no memo
  candidate. Five interleaved pairs: cached medians −2.7…−6.1%, but cache-disabled
  medians **+3.9…+15.4% slower**, allocations +36…45/request. Not a general net
  win; keep it opt-in.
- **Exact file-digest memo** ([contract and public fixture](passes/digest-memo.md)),
  independent opt-in `lowrail build APP --passes default,+digest_memo`: reread the complete binary
  stream, reuse only after full byte equality; no stat-only shortcut or arbitrary
  Inertia-proc memo. RailsVite MD5 and vite_ruby SHA1 intrinsics retain original
  error/glob semantics. Public fixture: 7/7 identical, 65 reuses, no fallbacks.
  Private-app gates: 10,816 unit/request + 552 system outcomes identical,
  765/2,849 digest reuses, zero fallbacks. Five YJIT pairs: profile median −14.3%
  with narrowly separated ranges; overview/list −6.1%/−13.1% remain within
  overlapping noise. More allocations (+21/request), worse p95 tails, full file
  IO and guard limits remain. SQL-trace warnings also reproduce with every unit
  disabled; see the aggregate notes rather than assuming full SQL identity.
- **Runtime gem**: native translate / cache-output / ISeq eval seams, with
  no `load_iseq` definition (preserves Bootsnap and require-hooks/Freezolite
  method chains and adapter selection in every tested order), per-file compiler
  contracts captured from the booted app, unchanged-source/original-ISeq
  fingerprints, and original-only Bootsnap caches ([survey and tests](loaders.md));
  template seam (lowered handler code while the source digest matches),
  guards that reset on every definition path and revalidate lazily
  (including stubs on single objects), per-view-class checks, env check,
  stats, Minitest outcome reporter across forked workers and RSpec per-example
  outcomes via RUBYOPT (explicit `verify APP -- bundle exec rspec ...`). Setup
  loads no default gems, so apps pinning `json` still boot.
- **Layered request costs** ([method and results](bench.md)):
  `bench/request_pairs.rb` separates no setup, no manifest, zero units,
  all-disabled, default and optional instantiate builds. Primary Callgrind
  counts control all five heap-pool capacities, retain GC endpoints and
  report total/GC-excluded instructions with bootstrap CIs and independent
  off/off gates. Native YJIT CPU/wall and allocations remain secondary;
  failed controls are retained. Empty selections/manifests no longer install
  delivery/invalidation hooks. Disabled statistics leave the receiver guard
  hot path (1,295 → 663 instructions/check in a YJIT micro); class-identity
  caches and invalidation semantics are unchanged. Production-heap diagnosis
  finds allocation/GC-count changes driven by boot phase, with modest
  retained manifest/fact data, not a second application ISeq set. No runtime
  retention/GC tuning change was made. After-change interpreter total
  instructions, default vs no setup (95% bootstrap CIs): blog
  **−5.959% [−5.983, −5.949]**; Campfire uncached
  **+0.122% [+0.054, +0.151]**; cached
  **−0.045% [−0.110, +0.022], within noise**. All three after A/A gates pass;
  the before-cached gate fails and is not accepted. The all-disabled blog
  tax falls from +0.245% to below 0.1%. Optional instantiate uses −5.728%
  on blog / −0.126% uncached Campfire vs off, on the frozen pre-shadow AR
  runtime. No native YJIT speedup is established. Fresh builds after merging
  concurrent AR changes still verify identical outcomes/full SQL:
  blog 21/125 events, Campfire 634/15,108, default and instantiate, serial.
- **Rails' own compatibility gate** (`script/rails-suite`, [results and recipe](rails-suite.md)):
  pinned v8.1.4 component suites, setup-only / synthetic guarded fallback /
  existing AR-pass layers against independent off/off controls. SQLite AR
  **9240/9240**, PostgreSQL AR **10186/10186**, AP **4095/4095**, AV
  **3162/3162**, AM **1100/1100**, Mailer **268/268** in every layer;
  AS **5814/5815** and inline AJ **209/212** have four dynamic printed
  identities, not outcome failures. Railties is a bounded **125/125**.
  **Round 2** adds genuine coverage with zero shadow mismatches: preload
  **2 H / 650 F** in full SQLite, **1 / 652** in PG, **5 / 2** in AV-AR;
  one isolated, unmodified Rails association test has **1 reader H / 0 F**.
  Full AR still refuses 94 otherwise eligible readers because of genuine
  fake planners; no test-directory whitelist or guard weakening. Refusing
  144 noncanonical HABTM edges stops 546 unresolvable facts from disabling
  every ordinary preload. Full per-reason ledgers and per-unit H/F (including
  zeros) are retained. SQLite's **68,857/11,616** and AV's **118/0**
  instantiation controls remain exact. Five AR-only corpus gates retain
  **742 identical outcomes / 16,193 ordered same-thread queries**.
  Redis exercises **671 additional AS tests** (matching skips 1,068 → 397);
  full Railties generators and external AJ adapters remain unrun.
  These are bounded compatibility/coverage results, not speed claims.
- **AR visitor correctness fix**
  ([identity audit](ar-equivalence.md#connection-identity-audit-2026-10-20-round-2)):
  cached reader SQL is pinned to the certified visitor object; a connection
  visitor swap falls back without lazy re-certification. Published separately
  in [`9020e7a`](https://github.com/thomasklemm/lowrail/commit/9020e7a19ea5de9705f916e6b51add4e6c770831),
  after SQLite/PG/AV gates. Seven mutations across reader/preload/instantiate
  yield **21 identical exact row/query comparisons**; before, reader visitor
  replacement produced two strict shadow mismatches. Preload and instantiate
  are unaffected in the tested visitor/adapter/pool/role/shard/prepared cases.
- **Callbacks surveyed and parked**
  ([census and budgets](rails-suite.md#round-2-callbacks-are-parked-not-a-225-app-opportunity)):
  five apps have only **4–7 calls/request**, no nonempty symbol-condition-only
  chains. Eligible no-around machinery accounts for **0.141–0.975%** of eleven
  route captures before guards; the 22.5% Rails-suite inclusive figure wraps
  callback/action bodies and is not removable. Rails already caches compiled
  chains; upstream [PR59094](https://github.com/rails/rails/pull/59094) removes
  known-terminator thunks. No new runtime pass or ≥2% request claim. Revisit
  only as a stacking item with shared fixed-heap operation adapters/controls.
- **`lowrail verify [--bisect]`**: suite with `LOWRAIL=0` and `1`, per-test
  outcomes and fast-path hits. `--bisect` reruns with unit subsets
  (`LOWRAIL_UNITS`) and writes `.lowrail/denylist.json`, which `build`
  honors. Checked with a fault injected into one real-blog unit: found in 4
  reruns, the rebuild skips that template.
- **SQL-trace differential in `verify`** (`gem/lib/lowrail/sql_trace.rb`):
  per test, the ordered sql.active_record events of the test's thread
  (name, SQL with timestamps and 6+-digit literals masked, bind
  name:class, cached flag, row count) must match between `LOWRAIL=0` and
  `1`. Schema, fixture, connection-setup and internal-table queries are
  excluded; other threads' queries are advisory. Both runs share one seed
  (`SEED`/`SPEC_OPTS`); with several test processes the SQL check is
  advisory (run `PARALLEL_WORKERS=1` to gate). `LOWRAIL_SQL_TRACE=full`
  stores the lines, `=0` disables. When serial traces differ, verify runs
  `LOWRAIL=0` a second time and excludes tests whose traces already differ
  between the two off runs (inlined sequence ids, time, randomness). If
  differences remain, the on run is repeated too, so only differences that
  reproduce in both on runs against two agreeing off runs gate. On a large
  private app (10,816 tests, serial) the off-repeat-only check still left
  21 differences with every unit disabled, i.e. rare flakiness; with the
  symmetric check the same control passes: exit 0, 288 of 10,816 tests
  excluded as unstable (2.7 %, not SQL-gated), 0 remaining differences,
  identical outcomes in all four runs. Campfire: 634 tests, 15,103 queries,
  identical; real-blog: 21 tests, 125 queries, identical.
- **Build surface** (PLAN 9.4): `lowrail facts` materializes lazy
  surface before dumping (production eager load, attribute methods,
  relation delegation, lazy routes, view context classes, every template
  compiled), captures every eval'd script (`TracePoint(:script_compiled)`,
  `.lowrail/generated/`) and links methods to the exact generated `def`
  (`--show Mod#meth`). `lowrail observe APP` records a test run
  (definitions after boot, scripts, sampled argument/return classes) into
  `.lowrail/observed.json` and diffs it against the facts.
- **Types and MCP** (first iteration, other thread): boot-first types with
  provenance, RBS generation, stdio MCP server. See `docs/types.md`.

## Evidence

| App | Lowered | verify | Other |
|---|---|---|---|
| real-blog (Rails 8.1.4) | 9/9 `link_to` sites, 10/10 route sites (1 in a controller), 12 units including preload plans | 21/21 identical, 116 fast-path hits across all 12 units (2 preload hits) | 4 HTML routes byte-identical on/off (CSRF masked); request time within noise, allocs −1 to −6 %; `edit_article_path` 2.7 → 1.4 µs |
| Campfire (Rails 8.2 alpha) | 1/4 `link_to`, 108/162 route sites (51 `_url`) | 634/634 identical (2 skips both ways), 13238 hits across 52 units, 0 fallbacks; with `+preload_plans` 786 preload hits | M0 in `docs/m0/campfire.md`; preload results in [pass notes](passes/preload-plans.md) |
| ARGOS (private, Rails 8.1.4) | 235/280 route sites + one opt-in digest site, 62 units; `link_to` 0/0 | 10,816 unit/request + 552 system outcomes identical; route 794/226 + digest 765/2,849 hits, zero fallbacks; SQL-trace caveat in notes | [Aggregate measurements](m0/argos.md): digest 298.40 → 129.81 µs; profile −14.3%, overview/list within noise; 14,734 type signatures, 3,053 non-untyped returns |
| PingCRM (Rails 8.1.4, Ruby 4.0.7) | 30/30 route sites, 4 route units + preload | 26/26 identical, 11 route + 7 preload hits | [Public Inertia M0](m0/inertia.md); seed 41231, browser suite included |
| Redprints CFP (Rails 8.1.3, Ruby 4.0.7) | 25/27 route sites, 14 route units; 9 Ruby files compiled | 50/50 non-system + 12/12 browser outcomes identical; 25 + 19 fast-path hits, **zero fallbacks** in both runs | Freezolite delivery and dynamic mounted-engine script completion fixed ([loader survey](loaders.md)) |
| React Starter Kit (Rails 8.1.4, Ruby 4.0.7) | 23/26 route sites, 8 route units + preload | 36/36 identical, 25 route hits across 7 units; no preload hits | [M0](m0/inertia.md) includes healthy SSR HTML and authenticated JSON |

Public Inertia builds and `observe` completed on all three. Lowrail-off
production/YJIT baselines and StackProf area shares are in [the M0](m0/inertia.md),
not speedup claims. All three version digests are eager boot Strings: **zero
digest calls across 400 traced requests/app**, unlike ARGOS's version proc.
Configuration binding and serializer/prop descriptors are measured candidates;
dynamic users, props, SQL and SSR output must remain per request.

### Pass-build migration, steps 1–3 (2026-10-20)

The Rust registry owns pass selection (`--passes default,+name,-name`, with
legacy flags retained), ordering and summary. All selected runtime builders
share one boot and return data; Rust merges units and the shared reason-coded
ledger before the compiler writes the manifest. Runtime delivery, guards and
installation are unchanged; architecture step 4 remains separate.

Before/after evidence is saved in [build-pass-equivalence.json](build-pass-equivalence.json):
every pass's units, lowered/refused diagnostics, hits and fallbacks, including
explicit zeros, corpus pins, timings and comparison fingerprints. Ruby 4.0.7,
seed 41231, `PARALLEL_WORKERS=1`, local Redis/PostgreSQL, cached facts. Baseline
is [c57b26a](https://github.com/thomasklemm/lowrail/commit/c57b26a29ec4f13e053413f761ff8cfe77ca1acc).
Default and all-pass configurations each cover **779 outcomes**: blog 21,
Campfire 634 (2 skips), PingCRM 1 + 25 browser, Redprints 50 + 12 browser,
starter kit 36. Outcomes and ordered same-thread SQL match across all four
baseline/candidate × off/on runs. Diagnostic identities/multiplicities and
per-pass hits/fallbacks match, not just totals. No unit ids changed: traversal
and runtime pass order were retained. Manifest comparison allows Ruby's
method-fact enumeration order and the changed builders' own source hashes;
compiled-file entries, templates and other payload values match.

| App | Default build seconds, before → after | All passes, before → after |
|---|---|---|
| real-blog | 4.49 → 5.05 | 9.92 → 6.98 |
| Campfire | 16.44 → 17.44 | 27.79 → 19.12 |
| PingCRM | 4.61 → 4.89 | 9.61 → 6.09 |
| Redprints CFP | 10.88 → 10.70 | 23.54 → 14.22 |
| React Starter Kit | 4.12 → 3.97 | 9.88 → 5.16 |

Single wall-clock observations, not a controlled speed claim. Measured boots:
default **2 → 2**, all passes **6 → 3** (oracle, runtime builders, compiler);
fresh facts add one. Other-thread SQL remains advisory: nine PingCRM browser
tests in both versions, and one Campfire default test after migration. Their
own-thread traces match. Corpus digest/URI coverage is zero; Campfire's
default debugger keeps memo/preload hits at zero in both versions. Gem fixtures
exercise these behaviors; no new support claim follows from zero-hit gates.

`cargo test --locked`: **30 unit + 3 integration passed**; release build passed.
Full gem suite from the repository root: **77 runs, 1418 assertions, 0 failures,
0 errors, 3 skips** (optional minitest-mock and two tests expecting the separate
`real-blog-r4` directory). Selection and unit/ledger merging have Rust tests;
ledger normalization preserves detail, copies and survey metadata.

### Runtime migration, step 4 (2026-10-20)

`Lowrail::Passes` owns runtime selection and the single after-initialize
helper. Each present runtime receives only its units; absent runtimes are
not required. Source/template delivery and memo tracing remain eager; AR
epochs retain their own Active Record load hook. Existing runtime constants
and file paths remain available through aliases, preserving emitted code and
fact owners. Guard, Loader, Stats and Templates bodies are unchanged.

After integrating the stacked-benchmark and template-ledger publications,
combined checks pass: `cargo test --locked` **31 unit + 3 integration**;
`cd gem && rake test`
**90 tests / 1,502 assertions**, zero failures/errors and six optional skips;
all `bench/*_test.rb` **20 tests / 155 assertions**, zero failures/errors/skips.

The shared helper was exercised through a real cold Rails initialization:
two runtimes share one temporary TracePoint, activate in order, and leave
the trace disabled. Registration after initialization activates immediately.
Missing, incompatible and empty builds and empty selections load neither
pass/delivery/invalidation hooks nor default gems.

Serial `lowrail verify` before and after, seed 41231 and
`PARALLEL_WORKERS=1`, uses freshly rebuilt manifests for each runtime source
fingerprint. Both default and all-existing-pass builds have identical test
outcomes, ordered own-thread SQL, unit IDs and ledger identities/multiplicities:

| Corpus app (non-system + browser) | Identical outcomes per build | Own-thread SQL events per build |
|---|---:|---:|
| real-blog-r4 | 23 | 129 |
| Campfire (Redis) | 664 (2 existing skips) | 15,246 |
| PingCRM | 26 | 607 |
| Redprints | 62 | 778 |
| Starter Kit | 36 | 256 |
| Total | 811 | 17,016 |

The Starter's explicit one-test browser rerun is additional coverage, not
counted twice here. All ten non-system per-unit hit/fallback maps are exact;
seven browser maps are exact, with the three timing-dependent exceptions
attributed below. All original counts, including differences, are retained in
[runtime-pass-equivalence.json](runtime-pass-equivalence.json). Only checked
source certificates and moved, byte-identical wrapper-definition locations
are canonicalized; ledger details and ordered SQL are not masked.

Framework L3 also matches exactly, including per-unit maps and
duplicate-preserving shadow observations. SQLite AR: **9,240 outcomes,
68,857 instantiation hits, 11,616 fallbacks**. Action View groups: **2,747 +
242 + 173 outcomes**, with **118 AV-AR hits and zero fallbacks**. Manifests
remain built in a separate off process; there are zero shadow mismatches.

PingCRM's browser User-instantiation counter **85 → 83** is dispositioned
as request-count variance, not a changed instantiation path. Old/old is
**85/83** and new/new **83/83** at the same seed. Full instrumented browser
runs have **83 hits and zero outside-action hits on both runtimes**, with
identical counts and hit distributions for every controller action:

| PingCRM action | Old requests / User hits | New requests / User hits |
|---|---:|---:|
| `UsersController#index` | 9 / 43 | 9 / 43 |
| All other actions combined | 59 / 40 | 59 / 40 |

The original extra pair is one authentication User load plus one
`owner = false` filtered User load (one row each) in the deleted-user filter
test. The test already sees the deleted user after selecting “With Trashed”
and does not wait for the subsequent role filter. A teardown trace completed
without that role request, including a half-second post-run observation.
Ordered own-thread SQL and outcomes remain exact; other-thread SQL remains
advisory, not silently promoted to a strict gate.

Browser A/A controls (each pair uses the same runtime/code/seed; `H` is hits,
`F` is fallbacks) retain the following nondeterministic counts:

| App/build/unit | Old/old | New/new |
|---|---:|---:|
| Campfire default 32 H | 519 / 528 | 537 / 531 |
| Campfire default 44 H | 34 / 35 | 39 / 31 |
| Campfire default 58 H | 603 / 601 | 617 / 619 |
| Campfire all 32 H | 516 / 540 | 540 / 537 |
| Campfire all 45 H | 35 / 39 | 33 / 33 |
| Campfire all 59 H | 597 / 621 | 623 / 615 |
| Campfire all 62 H | 1,351 / 1,358 | 1,357 / 1,358 |
| Campfire all 64 H | 286 / 290 | 284 / 284 |
| Campfire all 70 H | 422 / 425 | 420 / 420 |
| Campfire all 71 H | 307 / 311 | 305 / 305 |
| Campfire all 73 F | 733 / 737 | 731 / 731 |
| Campfire all 78 H | 622 / 634 | 628 / 627 |
| Campfire all 79 H | 1,912 / 1,960 | 1,948 / 1,943 |
| Campfire all 81 H | 431 / 439 | 427 / 427 |
| PingCRM all 12 H | 85 / 83 | 83 / 83 |

The default unit 58 shift is larger than its A/A spread, so A/A alone is
**not** its disposition. Instrumented full browser runs attribute every
watched hit/fallback to a controller action or background work and reconcile
with global Stats totals. Per-request hit buckets are unchanged:

| Campfire build/action | Old/new requests | Hits per request (old/new) |
|---|---:|---|
| Default `Rooms#show`, unit 58 | 93 / 93 | 1 / 1 |
| Default `Users::Sidebars#show`, unit 32 | 180 / 180 | 3 / 3 |
| Default `Users::Sidebars#show`, unit 58 | 180 / 180 | both `{2:110, 4:54, 6:16}` |
| Default `Messages#update`, unit 44 | 37 / 34 | 1 / 1 |
| All `Rooms#show`, unit 59 | 93 / 93 | 1 / 1 |
| All `Users::Sidebars#show`, unit 32 | 174 / 180 | 3 / 3 |
| All `Users::Sidebars#show`, unit 59 | 174 / 180 | `{2:108, 4:51, 6:15}` / `{2:112, 4:53, 6:15}` |
| All `Messages#update`, unit 45 | 39 / 36 | 1 / 1 |

Histogram entries mean `hits:request_count`, not an average. Four extra
2-hit and two extra 4-hit sidebar requests explain the entire all-build
unit 59 **+16**; default unit 58 totals are **625/625** in the attribution
run. The three fewer low-count update requests each account for one
RichText/Membership/Message/Session hit, two User/AR-plan hits and one Room
fallback. Other actions and all watched background maps are exact, including
316 background Room fallbacks; there are no outside-action route hits.
Thus these are request-count/composition differences, not changed per-request
specializations. No waits or corpus test semantics were changed to hide them.

Inertia integration is separate from existing-pass equivalence: **811
identical outcomes, 17,014 identical ordered own-thread SQL events, 514
binding hits and zero fallbacks**, with empty off-mode counters. Hits are
PingCRM **218**, Redprints **36 + 216**, Starter **44**; the other apps have no
unit. All **12 production HTML/JSON byte comparisons** pass through standard
shared activation, including live Starter SSR. Two new/new PingCRM runs
both have **68 requests, 182 in-action + 36 outside bindings, zero fallbacks**,
with identical full action histograms. Replaying the original activation
shim on the archived published runtime gives the exact same distribution
and **218/0**. The historical **222** is an unattributed cohort that the
original activation path does not reproduce; an optional role-filter request
is plausible but not proven for that untraced cohort. The pass stays opt-in;
its failed native A/A controls remain failed.

Fixed-heap blog `GET:/articles`, six interleaved rounds × 50 requests with
50 warmups, compares the same source-only manifest against the archived
pre-refactor library (`BENCH_BASELINE_LIB` in `bench/request_pairs.rb`).
Both independent A/A instruction controls and all five heap capacities pass.
Candidate/old-runtime total instructions: **−0.02090% [−0.05032, −0.00626]**;
GC-excluded: **−0.01292% [−0.05570, +0.00183]**. Missing/empty/disabled
layers remain within noise of off. No added request tax is observed.
The initial before-only total A/A control failed and is retained, not used
as equivalence evidence. These interpreter counts are not a native YJIT
speed claim. The stats-disabled YJIT receiver-guard micro remains about
663 instructions/check: **662.482978 → 662.506856 (+0.00360%)** over
1.5 million checks; its implementation is unchanged.

Cold `require + setup` is measured separately because request windows exclude
boot. Six paired rounds with independent old/old and new/new workers and
identical, unchanged capacities in all five heap pools show **+0.758%**, about
**0.37–0.40 million instructions once per boot**, not per request. Three
segmented observations per runtime attribute the cost as follows (medians;
the extra segment seams mean their sum need not equal the whole-setup delta):

| Cold phase | Before instructions | After instructions | Delta |
|---|---:|---:|---:|
| Require `lowrail.rb` | 2,052,121 | 1,663,981 | −388,140 |
| Require `passes.rb` | 0 | 843,805 | +843,805 |
| Source delivery and pass selection | 3,029,117 | 2,951,341 | −77,776 |
| Manifest/Guard/Loader require, load and install | 47,116,759 | 47,107,789 | −8,970 |
| Segmented net | | | +368,919 |

The blog's 11 source units cause **zero runtime-pass requires, installs or
activations**. Only the registry's static descriptors and empty selections
are built for absent runtimes; the cost is loading/compiling the registry and
shared helper, not eager pass state. A later option is shipping `passes.rb`
as a precompiled ISeq; that is a follow-up, not part of this refactor. See
[benchmark method](bench.md#runtime-registry-cold-cost) for the measurement boundary.

### Per-file loader policy (2026-10-20)

Build captures the app's real compiler calls, including Freezolite's temporary
defaults and Bootsnap's selected per-file options. Runtime requires the same
recipe, original ISeq and source bytes before substituting lowered code;
Bootsnap caches only originals. Installation-order and ecosystem details are
in [loader composition](loaders.md). This is delivery/correctness work, not a
speed claim.

Executed on Ruby 4.0.7, using the `script/corpus` pins and seed 41231:

- real-blog: build 11 units, verify 21/21 identical, 56 hits across all
  11 units, 1 view fallback.
- Campfire: verify 634/634 identical (2 skips both ways), 6913 hits across
  52 units, zero fallbacks.
- Redprints: build 14 units and compile all 9 Ruby files with its own
  Freezolite policy. Non-system RSpec is 50/50 identical, 25 hits across
  9 units; browser RSpec is 12/12 identical, 19 hits across 8 units. Both
  report zero fallbacks. These runs include the separate
  [mounted-engine completion fix](https://github.com/thomasklemm/lowrail/commit/9fa9bd13313ad0314f606d37e221b66616751b8f):
  `find_script_name` remains dynamic instead of using a class-wide guard
  that engine singleton overrides could invalidate.

The full gem suite passes: 58 runs, 1583 assertions, 3 skips. Historical
Ruby 3.4.11 targeted compiler/loader/end-to-end tests passed: 20 runs,
483 assertions, 1 skip; Ruby 3.4 is no longer a target. Rust tests pass
(22 unit + 2 integration). The two loader-policy
regressions fail on pre-fix main and pass with the fix. A further cached-hijack
regression fails without the follow-up recipe guard and passes with it;
tests cover actual frozen-literal behavior and lowered-file delivery, not
just process success.

### Build surface (2026-10-20)

Materialize, as added modules / methods / generated scripts per step after
`config/environment` (real-blog 5210 / 36752 / 1155 at boot, Campfire 6840
/ 49628 / 1602):

| step | real-blog | Campfire |
|---|---|---|
| `eager_load!` | +1520 / +9114 / +693 | +791 / +2765 / +464 |
| production eager load (Zeitwerk all, namespaces) | +726 / +4203 / +144 | +955 / +5895 / +174 |
| models (schema, attribute methods) | +41 / +524 / +48 | +26 / +4110 / +266 |
| relation delegation (speculative) | 0 | +0 / +6 / +6 |
| lazy routes | +0 / +68 / 0 | +88 / +704 / +22 |
| controllers (`view_context_class`) | +7 / +145 / +32 | +7 / +145 / +31 |
| templates compiled | +1 / +30 / +28 | +2 / +154 / +104 |

Generated scripts: real-blog 2096 (0.75 MB), Campfire 2664 (1.2 MB); methods
compiled from one: 5657 / 8960; app-relevant methods with a linked
generated `def`: 299 / 2840. Capture costs ~15–25 ms of hook time
(boot +0.05 s on real-blog, within noise on Campfire's 2 s).

Observed test run against the materialized facts: real-blog defines 9942
methods after boot, Campfire 19524; all but 1438 / 4446 are in the facts
(by name, generated `def` text, or template). The rest is test-only code
(Minitest/Rails testing, fixtures, mocha, webmock, rexml, DRb), no app
method; the only templates are Campfire's 8 exception-page templates,
recompiled per rendered exception (80 methods). Suite overhead: definitions
only +0.4 s real-blog (fixed cost), +3–4 % Campfire; with type sampling (16
per method, 586 methods hooked) +3–6 %; uncapped sampling up to +9 %.

## Learned

1. **Speed is in framework code** (M0: real-blog app self time ≈0 %,
   Campfire 1.5–4.9 %), so lowering targets Rails and gem code as used by the
   app, not just `app/**/*.rb`.
2. **Two delivery kinds**: Ruby-file ISeqs at native compilation, cache output
   or explicit eval, and the handler call in
   `ActionView::Template#compiled_source` for templates. No `load_iseq` override.
3. **Per-call-site guards beat per-method guards** for a first pass: they
   keep line numbers, never evaluate arguments twice, and need no change to
   method tables.
4. **Partial evaluation through the booted app** (the oracle) is the robust
   way to "derive from the booted Rails app": constants come from Rails
   itself, and probes turn escaping assumptions into checked facts.
5. **Single helpers are small wins** (`link_to` 6.6 → 2.6 µs); measurable
   gains need many sites per request or framework paths per request
   (Campfire: CSP/importmap URL work 34.8 % inclusive on cached pages,
   Active Record dispatch and fragment keys when uncached).

6. **Boot is not the whole app, but materialize nearly is.** In test env
   `eager_load!` sees a quarter of what production eager load plus lazy
   generation build (Campfire: 2765 of 13779 added methods). After
   materialize, a full test run adds no app method; what it adds is test
   machinery. Generated code is only meaningful per `def`: Active Support's
   CodeGenerator shares method caches across models and batches them in
   run-dependent order, so script digests differ while `def` texts match.

## Next

Current priorities (2026-10-20):

1. **Endpoint, guarded tier:** price body-installed specialization, where
   normal VM dispatch keeps identity, visibility and redefinition exact, on
   the two show links before any runtime implementation.
2. **Sealed tier:** contract (`docs/sealed.md`), `lowrail seal-check` detector
   and five-app violation ledger, then a blog show sealed-endpoint pilot.
3. **Props pass** from the allocation survey (interpreter and YJIT micro gates
   pass), opt-in, with mutation regressions.
4. **Ruby 4.1 matrix column and ZJIT diagnostic mode,** plus a check for a
   public VM invalidation API.

Older follow-ups:

- Candidate #4 is **parked, upstream-solved**, with no Lowrail backport:
  Rails main's [49580d1d](https://github.com/rails/rails/commit/49580d1d041eb88adca2948b3592b43bd17c7d7b)
  fuses attribute appends (not yet in `8-1-stable` or 8.1.0–8.1.4).
  Estimated pre-guard saving is only ~0.3–0.45% blog edit / ~0.2–0.3%
  Campfire room. [Five-app census and per-site refusals](passes/tag-options.md):
  12/94/2/0/0 direct tag/form sites; 504 scratch controls per Rails pin,
  zero differences. It remains the cheapest later component pilot.
- **Campfire fragment caches stay** ([measurements](passes/campfire-fragments.md)):
  six native off/off/on cohorts find no uncached-all-pass render cheaper
  than its warm hit (roughly 1.8–9.6× the hit cost). Uncached off/on query
  counts and complete collection HTML agree; native A/A fails, so no precise pass gain is claimed.
  App recommendation only; no cache-policy or runtime changes.
- Route defaults and template lookup are parked. Revisit routes as a stacking
  item after shared per-hit budgets; argument-less conversion covers 1/4
  Campfire guarded path calls, full base-AR certification could cover 4/4.
- Generic route generation and guarded block-result mappings remain unsupported;
  host normalization is request-local, but Rails' `url_options` assembly and
  application overrides remain per call.
- Extend controlled instruction measurements to the other corpus apps and
  resolve native YJIT boot/GC sensitivity before claiming request speedups.
- Broader memo certificates for timeout-sensitive URI work; exact file-digest
  memo now works, but its byte-indexing/read cost remains measurable.
- Active Record attribute/reflection dispatch (ARGOS, Campfire uncached).
