# Native YJIT direction-finding

2026-10-21. **Exploration branch only. Not a published price, pass promotion,
production support claim, or replacement for the instruction-count gates.**
Lowrail off/on both run Ruby 4.0.7 with startup YJIT and Rails 8.1.4.
No Callgrind cohort is launched. No application implementation/configuration
is patched. Dependencies alone may be overlaid.

## Method, fixed before measurement

[`script/native-bench`](../script/native-bench) borrows ruby-bench's native,
in-process production Rack approach, not a network/Puma load generator.
Reference source: ruby/ruby-bench at
[`351a39b`](https://github.com/ruby/ruby-bench/commit/351a39b77e6c06f4f4fa03148639b10a6bb0c716),
particularly `harness/default.rb`, `lib/harness.rb`, `railsbench`, `lobsters`
and `erubi-rails`. The last is render-only, not an HTTP workload. Our controls
compare **Lowrail**, not interpreter versus YJIT.

- Twelve independent fresh-process rounds, three serial arms each: off-A,
  off-B (A/A), on. Rotate all three positions and reverse alternating rounds;
  seed 41231. All 36 measured workers remain in the export. No retry-to-green,
  outlier removal, stopped-round salvage or pooling of smoke runs.
- Pin workers to logical CPU 2 with `taskset`; record observed affinity.
  This orb exposes no cpufreq/turbo controls. ASLR and host policy remain
  unchanged. It is a virtualized host, not an isolated bare-metal machine.
- Both arms preload the same Lowrail setup; `LOWRAIL=0` selects original
  Rails. Public units have counters disabled during timing. Separate fresh
  statistics-enabled coverage workers run before timing. Fizzy's bench-only
  specimen keeps its existing internal counters/seams in all arms.
- Untimed fixed warmup, then 300 individual requests per route per worker.
  Route windows are in a fixed order. Full GC is **not** forced, GC is **not**
  disabled, and normal app fragment/collection caches stay enabled. A warm
  benchmark is not a cold-cache workload. Each process restores fresh copies
  of the same seed DBs and clears only its dedicated disposable app cache.
- `CLOCK_MONOTONIC` surrounds the full Rack/MockRequest call and status check,
  including body consumption/close. Every response must be 200. Median/p90
  use linearly interpolated empirical quantiles. Throughput is serial
  completed requests / sum of their elapsed times, **not concurrent server
  capacity**. Request construction/status-check overhead stays in both arms.
- `GC.stat(:total_allocated_objects)`, `GC.total_time` and collection counts
  bracket each complete route window, outside per-request clocks. Allocation
  and GC figures include process-wide/background work during that window and
  tiny symmetric harness costs; they are not thread-local app allocations.
  RSS and high-water RSS come from `/proc/self/status` at window boundaries.
  Boot is parent launch → `config/environment` return, including Ruby,
  Bundler, preload and Rails, excluding login, fixture preparation and warmup.
- Record actual JIT state/counters before/after each window, without requiring
  flat compilation for this **exploratory native** study. Compilation that
  happens during requests is charged, not subtracted. This cannot pass an
  interpreter-Ir or strict YJIT-flat published-price gate by implication.
- First report A/A. Compare paired per-round percentage differences, average
  those differences, and bootstrap **whole paired rounds** 5,000 times (fixed
  seed) for percentile 95% intervals. Do not treat 10,800 correlated requests
  as independent replicates. Noise floor is the maximum absolute endpoint
  of the corresponding A/A interval. A directional label requires the entire
  on/off interval beyond that floor. An unresolved result does not prove
  equality. Zero-baseline metrics retain absolute differences rather than
  dividing by zero. No multiple-comparison correction: rankings are exploratory.

## Workloads and boundaries

- **Blog:** retained original source, archive SHA256
  `b1dd980b6689bf2b3912691e527d74e0b7699fb32cb53169791c24879f0c0a99`,
  production source pin `86ebd4a8c0b4acd8ecb302f81ee61e593bc2288ea8a44cb532c00c43a2c5f1cf`,
  lock `570c9c31129469dc2679780a9f7f7d26aca93e57e4e119250735322741ac8596`.
  Fresh `BlogShowGetOnly` schema/rows, not a transferred seed. Public sealed
  form/token/collection artifact rebuilt with `--jit yjit`; `GET /articles/1`.
  The raw cold entropy comparison remains rejected; declared two-seed
  companions plus both 192-pair seams are checked separately. A smoke run
  before the `view.send` P1 fix is **pre-fix**, not an interpreted speed result.
- **Campfire:** `script/corpus campfire-r81`, dependency-only overlay and
  original external `CampfireScenario` fixture/authentication. Public sealed
  instantiation-only artifact, not the zero-unit all-opt-in selection.
  Room, pagination, sidebar, search and POST from [the route study](campfire-bench.md).
  Native YJIT smoke coverage: room 52 completions, pagination 46, sidebar 8,
  search 19, POST 3 per request; two Room STI fallbacks on room. Other routes
  are not zero-hit controls. Dedicated localhost Redis only; reset
  its disposable DB between processes. No worker drains queued push jobs;
  POST measures the response path, not eventual delivery/completion. Its
  increasing HQ rows are not a fixed-size write steady state. Cold entropy
  and browser SQL rejections in the route study are not resolved here.
- **Fizzy:** unchanged corpus source and external fixtures, six GETs from
  [the block-link study](block-link-specimen.md), natural CSRF/password sign-in.
  Bench-only symmetric block-link delivery rebuilt in actual YJIT mode;
  newly discovered/frozen contexts. Not production admission. The existing
  cold cache-clock/interleaving rejections and uncovered payload/assigns,
  lazy binds and SolidCache completion remain. These are exploratory warm
  route windows, not the strict interpreter six-GET vector price.
- **Lobsters:** ruby-bench pin above, exact shipped 41 MB production SQLite DB,
  SHA256 `d9817ef63aed4989d504d26e341b33d163448cb123f10981082718876227a820`;
  1,003 users / 11,000 stories / 26,638 comments / 183 tags. Same external
  dependency-only wrapper as the hotspot study: Rails 8.1.4, Minitest 5.27.0.
  Do not load its historical schema (`unsigned` fails on SQLite). Four public
  anonymous GETs `/newest`, `/active`, `/recent`, `/hottest`, not the historical
  authenticated 114-request vector. The expected zero-unit artifact is a
  Lowrail startup/delivery overhead control, not a lowering opportunity.

## Reuse

Prepare dependencies with `script/corpus` and [compat.md](compat.md). Use a
dedicated disposable copy under `.corpus/`; the runner deliberately refuses
arbitrary app paths, existing output directories and non-YJIT artifacts.
Prepare data with the existing `BlogShowGetOnly`, `campfire_scenario.rb` or
`fizzy_link_fixture.rb` drivers. Build public sealed artifacts using their
normal denylists; never prune a manifest. Fizzy uses
`BlockLinkDelivery.build(app, new_artifact, jit: "yjit")` in a `ruby --yjit`
build process, then natural original discovery to freeze its contexts.

Example config (all paths absolute; `gemfile` is optional for an external
dependency wrapper; `contexts` is required only for Fizzy):

```json
{
  "workload": "campfire",
  "app": "/absolute/repo/.corpus/campfire-r81",
  "seed": "/absolute/repo/.lowrail/native/campfire-seed",
  "artifact": "/absolute/repo/.corpus/campfire-r81/.lowrail",
  "rounds": 12,
  "warmup": 200,
  "samples": 300,
  "seed_number": 41231,
  "cpu": 2
}
```

```sh
CAMPFIRE_DISPOSABLE_REDIS=1 mise exec ruby@4.0.7 -- \
  script/native-bench run CONFIG.json NEW_PRIVATE_OUTPUT
mise exec ruby@4.0.7 -- ruby bench/native_bench_test.rb
```

Other exploration branches may set `exploration_setup` to an absolute Ruby
file defining `NativeBench::Exploration.install(config:, state:, arm:)`.
It is required and invoked **in every arm**, after production boot and before
route construction/login/warmup. `arm` is exactly `off_a`, `off_b` or `on`.
An optional `NativeBench::Exploration.counts` returns JSON-safe snapshots,
replacing the ordinary coverage provider. Its counters/guards must charge
the same real hot-path work in all arms; the runner does not authorize an
unchecked specialization. `exploration_setup_ms` records require/install
cost separately from Rails boot. List any further setup dependencies in
`exploration_sources`; the setup file, listed files and effective lock are
hashed before execution and checked after every worker. The callback is
bench-only and gives no production admission authority.

Output retains protocol/schedule before execution, per-worker request samples,
GC/RSS/boot/JIT metrics and raw-log digests, source/lock/artifact/runtime/native
hashes, coverage workers, and the final paired summary. Raw logs/fixture secrets
stay private. A public JSON appendix must omit cookies/keys/response bodies;
none is needed for these native measurements. These timings are not a fresh
own-suite or exact output/DB-state certification; main integration and any
README performance number still require all owner gates and Thermos review.

## Cheap screen first (owner policy, 2026-10-21)

New ideas use [`script/screen`](../script/screen), not a twelve-round price
cohort. The already-running Campfire cohort is retained; the owner canceled
the queued twelve-round Fizzy and Lobsters cohorts after seeing its noise. A screen
is for killing/promoting an idea, never a README price or support claim.

```sh
CAMPFIRE_DISPOSABLE_REDIS=1 mise exec ruby@4.0.7 -- script/screen \
  "$PWD/.corpus/campfire-r81" /rooms/486777696 \
  --config PRIVATE_CONFIG.json --output NEW_PRIVATE_DIRECTORY \
  --exploration-setup /absolute/exploration.rb
```

The native config supplies `workload`, `seed`, `artifact`, and optional
`gemfile`, `contexts`, `exploration_sources` and `headers`. All fixture/artifact
paths are absolute. An explicit app and one or more routes are required.
Blog/Lobsters/Fizzy routes are GET paths. Campfire routes are existing scenario
IDs or exact fixture paths (its POST keeps its scenario method/parameters).
No app source/config edit is authorized. Prepare dependencies/data first:
the screen is not a ten-minute corpus installer. The artifact must certify
YJIT, including for zero-unit controls; do not reuse interpreter ISeqs.

- Three short fresh-process **off-A/on/off-B** rounds, preceded by one
  coverage worker per arm. Defaults: 20 vector warmups, 30 requests/route;
  `--warmup N`, `--samples N`, `--cpu N` override these explicitly. Nine timing
  workers, not a long cohort. No reruns/exclusions to obtain a win.
- State is restored by the native harness. Per-request allocation deltas
  use integer `GC.stat(:total_allocated_objects)` counts, not statistical
  allocation sampling. Report median **and full min/max**: background work,
  cache changes and framework activity can prevent deterministic counts.
  GC is not disabled/forced. The added clocks/count reads are symmetric.
- Print the maximum absolute paired A/A round difference and the bootstrap
  A/A envelope **before** on/off. The larger is the screen noise floor.
  `clear_wall_win` requires exact checks plus the complete on/off interval
  below minus three times that floor. Three rounds are screening evidence,
  not precision inference or permission to publish a price.
- Print status/body/all-header digest equality, allocation counts, native
  YJIT median, GC time, RSS and separate coverage-worker deltas (including
  per-unit hits/fallbacks when supplied). `screen.json` also retains p90,
  throughput, GC counts, boot and all paired summaries. `result.json` and
  raw worker JSON retain individual samples, pins and JIT state.
- Exact checks compare **actual unnormalized** status/body/header digests
  across off-A/off-B/on within every round, separately for seeds 0 and 1.
  They execute outside timed windows. A mismatch is retained and exits 2;
  failed output equivalence must not be interpreted as a speed win.
  This is not a DB/own-suite certificate. Main still needs those gates.

The existing `NativeBench::Exploration.install(config:, state:, arm:)` and
optional `.counts` hooks are unchanged. An optional
`.validation_request(route:, seed:, request:)` wraps **only untimed exact
requests** and returns `[actual_response, evidence_hash]`, with string-keyed
`evidence_hash["passed"] == true`. Use the existing source-pinned fixture
entropy validator/install/with in all arms; include trace/errors and the
validated pins in evidence, and list extra source files in
`exploration_sources`. Never normalize digests, widen an entropy policy, or
pin native timed entropy. Without the hook checks are explicitly raw and
can fail A/A on entropy. For the blog's request-ID input, set
`"headers": {"HTTP_X_REQUEST_ID": "native-screen-validation"}` in config;
the blog/Lobsters Rack driver merges these ordinary headers in all arms.
An adapter may also preserve its existing `NativeBench.routes` wrapper.

Blog validation must also supply `fixture_secret_key_base` in config before
boot (the disposable `BlogProduction::Entropy::SECRET` companion value).
With that input DUMMY is unset and the identical fixture secret is supplied
in every arm; without it the original DUMMY behavior stays unchanged.
Never put a deployment secret in the config/export. Campfire/Fizzy already
restore their disposable seed's `secret_key_base`. Their natural login is
outside `validation_request`: a custom adapter can wrap the external driver's
login with the existing pinned controls during `install`/route construction,
then end that context before warmup/timing. No app/config edits are needed.

### Lobsters exact-response companion

There was no existing Lobsters policy. The blog validator correctly refuses
its source/lock/Rack versions. Reuse the **mechanism**, not the blog policy:
[`lobsters-native-entropy.json`](../fixtures/corpus/lobsters-native-entropy.json)
has independent Lobsters source/lock, external overlay/lock and runtime pins.
[`LobstersNativeValidation`](../bench/experiments/lobsters_native_validation.rb)
validates them and delegates to the unchanged `BlogProduction::Entropy`
validator/install/with. It declares no new random sites. A two-seed, three-arm
fresh-process probe of `/` matches actual status/body/all headers with no
entropy errors. Raw entropy still differs and remains explicitly rejected.

The shortest exploration setup (also compose these calls with a prototype):

```ruby
require "/absolute/repo/bench/experiments/lobsters_native_validation"
module NativeBench::Exploration
  def self.install(config:, state:, arm:)
    LobstersNativeValidation.install(config.fetch("app"))
    # Install the same observer/guards in every arm; activate only on as needed.
  end
  def self.validation_request(**args) = LobstersNativeValidation.validation_request(**args)
end
```

Set config `headers.HTTP_X_REQUEST_ID` to a fixed ordinary request ID and add
the policy plus `fixtures/corpus/blog_entropy.rb` to `exploration_sources`.
Do not edit upstream's benchmark secret/config. These fixed RNG/clock inputs
are active only inside the two untimed validation requests per route; real
reads/traces/errors are retained, and all timed entropy remains native.
This is exact-response evidence for executed routes, not DB/own-suite admission.

Fizzy AR-only exploration sets `"exploration_only": true` (or
`--exploration-only`) to skip **only** BlockLinkSpecimen installation and its
dependencies. Contexts are then unnecessary. Supply an independently built
appropriate public/empty artifact: a block-link artifact still contains its
delivery source and cannot work without its specimen. Public Lowrail preload,
production mode, native guards, fixture login, and source pins are unchanged.
Optional config `paths` also works in `native-bench`; absent keys preserve
its original route vector and block-link behavior.

One Linux hardware instruction probe in this orb (`perf_event_open`,
hardware instructions, user-space calling process) returned **ENOENT (2)**;
`perf_event_paranoid=2`, and `perf` is not installed. No native instruction
counts are claimed. The screen records the probe once per invocation; it
does not substitute elapsed time or a process-startup count for request Ir.
If a different host exposes counters, the current tool reports availability
but does not yet collect them. Callgrind remains separately authorized and
reserved for a promoted result to publish, not these screens.

## Results / JSON appendix

### Campfire: no resolved native latency win; allocations increase

**Noise first.** Frozen harness
[`54d92f1`](https://github.com/thomasklemm/lowrail/commit/54d92f1e1068eb4e0b1ba60d68f2fc776e08cd52),
19 public sealed instantiation units, CPU 2, 200 vector warmups and 300
requests/route/worker. All 36 timing and 3 coverage workers completed;
54,000 individual request samples independently recalculated in Python.
Observed Ruby/Rails/JIT/affinity and all captured source/artifact/runtime
pins match. All 36 timing workers are nonflat: not a strict YJIT price.

| Route | A/A median Δ, 95% interval | Noise floor | On/off median Δ, 95% interval | Decision |
|---|---:|---:|---:|---|
| room | +3.99% [−1.55, +8.88] | 8.88% | +1.44% [−2.02, +4.57] | unresolved |
| pagination | +1.53% [−2.59, +5.69] | 5.69% | +0.89% [−2.34, +4.52] | unresolved |
| sidebar | +2.31% [−4.31, +9.63] | 9.63% | −1.46% [−8.73, +6.65] | unresolved |
| search | +1.73% [−3.78, +7.62] | 7.62% | −2.29% [−7.59, +2.93] | unresolved |
| POST | +1.09% [−2.27, +4.32] | 4.32% | −2.84% [−5.61, −0.28] | unresolved |

Even POST's nominal interval excluding zero does **not** clear the A/A floor.
Do not rank these five wall-time point estimates as demonstrated speedups.

| Route | Median ms off → on | p90 ms off → on | Serial req/s off → on | Allocations/request off → on | Paired allocation Δ |
|---|---:|---:|---:|---:|---:|
| room | 14.542 → 14.717 | 18.950 → 18.974 | 59.97 → 58.75 | 15,428.32 → 15,479.49 | +0.332% |
| pagination | 6.974 → 7.016 | 8.701 → 8.507 | 130.25 → 133.18 | 6,771.02 → 6,816.84 | +0.677% |
| sidebar | 7.410 → 7.224 | 9.289 → 8.980 | 128.25 → 132.71 | 8,982.01 → 8,989.63 | +0.085% |
| search | 8.980 → 8.715 | 11.392 → 10.824 | 99.49 → 102.46 | 7,968.86 → 7,987.82 | +0.238% |
| POST | 11.679 → 11.329 | 14.851 → 14.441 | 80.47 → 83.83 | 10,523.55 → 10,609.79 | +0.819% |

Arm values are means of the twelve per-worker metrics, not pooled requests.
Paired percentage changes need not equal ratios of these displayed means.
Allocation increases clear their corresponding tiny A/A bands on all routes.
Coverage workers retain 52/46/8/19/3 warm hits/request; two Room STI fallbacks
on room. Counters were disabled in the public timed arm.

| Route | GC ms/request off → on | Post-window RSS KiB off → on |
|---|---:|---:|
| room | 2.670 → 2.856 | 275,148.67 → 272,363.67 |
| pagination | 0.904 → 0.715 | 272,529.33 → 269,563.67 |
| sidebar | 0.710 → 0.520 | 269,064.67 → 266,651.33 |
| search | 1.283 → 1.241 | 269,022.67 → 267,002.67 |
| POST | 1.100 → 0.854 | 267,651.33 → 264,565.00 |

GC/RSS differences are unresolved against their A/A floors. Boot is
2,784.18 → 2,919.08 ms (+134.90 ms); paired +5.10% [1.54, 9.25], also
unresolved by its A/A floor. This response-only POST does not establish
async completion or a write steady state. No new own-suite/output/DB-state
certificate follows from timing success.

The [JSON appendix](native-bench.json) retains all 39 workers' metrics,
coverage/JIT records, schedule, per-round deltas and pinned inputs; private
sample/log/full-result hashes preserve provenance without public fixture
secrets or response bodies. A display-only RSS mean bug used integer division
in the frozen summary. The appendix explicitly preserves those original
means and independently recomputes fractional means from unchanged worker
records. Differences, intervals and decisions are unaffected. The harness
now uses floating-point means; its regression test fails on the old code.

### Ranked view and remaining scope

1. **Demonstrated help:** none from this native cohort.
2. **Demonstrated cost:** Campfire allocations increase on all five routes,
   +0.085–0.819%; no resolved wall-time, GC or RSS direction.
3. **No-op/control:** Lobsters' public artifact has zero units. Initial short
   smoke has a 20.61–26.94% A/A spread and raw entropy rejection, not evidence
   of equality or a lowering win. A fixed larger calibration is recorded
   separately, not pooled or rerun until green.
4. **Not measured:** Fizzy's long cohort canceled; blog waits for the published
   production `view.send` fix SHA. No pre-fix native speed number is promoted.
   Fizzy's accepted interpreter instruction increase is not a YJIT result.

The completed full CLI smoke took 53.94 seconds for two Lobsters routes and
correctly exited 2 for unnormalized raw entropy inequality. It verifies the
tool's refusal path, not a prototype win. The larger calibration below is
the single owner-requested settings experiment, not an optimization variant.
