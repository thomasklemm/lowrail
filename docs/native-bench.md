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
  dependency-only wrapper as the hotspot study: Rails 8.1.4, Minitest 5.27.0,
  published at [28e4af5](https://github.com/thomasklemm/lowrail/commit/28e4af5eb3bc03f0e9a2dd89ae669a6c5f8e2af3),
  `fixtures/corpus/lobsters.Gemfile` and its lock. Exact SHA256 values are
  `6308f24386e443332c5663aba64fa7b6eae931b8d1de0b0a04eed4f031873fd3` /
  `105a3c0f736082a5714e1db0feb48dc96addb87dd9050051fc8b3d85e4f35fcf`.
  Do not load its historical schema (`unsigned` fails on SQLite). Four public
  anonymous GETs `/newest`, `/active`, `/recent`, `/hottest`, not the historical
  authenticated 114-request vector. The hotspot study instead visits `/`,
  `/newest`, `/comments`, `/u`, `/s/enr7ye`, `/hottest` (last JSON): same fixture
  family, **different route vector**, so its profile and these native timings
  must not be pooled. The expected zero-unit artifact is a
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
the queued twelve-round Fizzy and Lobsters cohorts after seeing its noise.
A screen is for killing/promoting an idea, never a README price or support claim.

```sh
CAMPFIRE_DISPOSABLE_REDIS=1 mise exec ruby@4.0.7 -- script/screen \
  "$PWD/.corpus/campfire-r81" /rooms/486777696 \
  --config PRIVATE_CONFIG.json --output NEW_PRIVATE_DIRECTORY \
  --exploration-setup /absolute/exploration.rb
```

**Recommendation:** keep the short defaults for exactness/allocation screening
and only coarse wall direction. They cannot certify 1–5% native effects in
this orb. The single longer calibration below used 6.89 minutes and still
missed the ±2% A/A target; do not spend twelve-round cohorts chasing it or
repeat the calibration until green. Use exact output plus allocation evidence
to prioritize small bets; an inconclusive wall screen is not proof of no gain.

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
4. **Not measured here:** Fizzy's long cohort canceled. The published production
   dispatch fixes
   [1c99962](https://github.com/thomasklemm/lowrail/commit/1c99962e3f8d83dc0c303c2a403f9453249182e0)
   and [62f8a6b](https://github.com/thomasklemm/lowrail/commit/62f8a6bbbecabb21df218a01b121299fee726eff)
   require rebuilt view-context certificates; the coordinator assigned the
   corrected blog screen/re-price to the sealed thread, not another cohort
   here. No pre-fix native speed number is promoted. Fizzy's accepted
   interpreter instruction increase is not a YJIT result.

The completed full CLI smoke took 53.94 seconds for two Lobsters routes and
correctly exited 2 for unnormalized raw entropy inequality. It verifies the
tool's refusal path, not a prototype win. The larger calibration below is
the single owner-requested settings experiment, not an optimization variant.

### One-shot Lobsters A/A calibration: ±2% target not reached

Frozen harness
[`bfc682b`](https://github.com/thomasklemm/lowrail/commit/bfc682b97dbebdb1082d4f54e8ed426e7ff27c27),
same pinned ruby-bench source/shipped DB and external dependency overlay.
No other benchmark worker ran in this orb. Governor/turbo/virtual host
contention remain outside our control. Protocol selected **once**, before
measurement: three off-A/on/off-B rounds, CPU 2, 1,000 full-request warmups
and 4,000 samples per timed worker, one GET `/` only. Twelve workers total
including three coverage workers. No outliers removed, alternate statistic
selected after seeing data, worker salvage, or retry-to-green.

```sh
mise exec ruby@4.0.7 -- script/screen \
  "$PWD/.corpus/ruby-bench/benchmarks/lobsters" / \
  --config LOBSTERS_NATIVE_CONFIG.json --output NEW_PRIVATE_DIRECTORY \
  --exploration-setup /absolute/lobsters-validation-setup.rb \
  --warmup 1000 --samples 4000 --cpu 2
```

The setup delegates to `LobstersNativeValidation` as shown above; config sets
the fixed request ID and pins the policy/helper in `exploration_sources`.
Timed requests use native, unpinned entropy, with the same installed observer
wrappers in all arms. It is not a no-observer ruby-bench price.

**A/A first:** paired median differences are **+4.3423%, −1.4690%, −1.1197%**.
Mean +0.5845%; bootstrap 95% interval **[−1.4690%, +4.3423%]**; maximum absolute
round spread and screen noise floor **4.3423%**. Median absolute round
difference 1.4690% is **not** an acceptable replacement for the full band:
that would hide the retained +4.3423% round. The ±2% target fails.

| Metric | off-A | off-B | on |
|---|---:|---:|---:|
| Mean worker median, ms | 7.2657 | 7.3067 | 7.3519 |
| Mean worker p90, ms | 9.6539 | 9.9229 | 9.7670 |
| Serial throughput, req/s | 132.76 | 130.79 | 130.34 |
| Integer allocation median/request | 14,188 | 14,188 | 14,188 |
| Allocation sample min…max | 14,178…14,273 | 14,178…14,277 | 14,178…14,275 |
| GC ms/request | 0.5374 | 0.5287 | 0.5339 |
| Post-window RSS, KiB | 179,076.00 | 178,909.33 | 178,873.33 |
| Boot, ms | 2,745.67 | 2,824.14 | 2,840.54 |

Elapsed **413.29 seconds (6.89 minutes)**. On/off median +1.2349%
[−1.9638%, +3.0077%], unresolved; public artifact has **zero units and zero
hits**, so no prototype win is claimed. Both validation seeds match actual
status/body/all headers across **all twelve fresh workers**, with no entropy
errors; seed 0 and seed 1 produce different bodies as expected. All workers
run production Ruby 4.0.7/Rails 8.1.4/YJIT on CPU 2, no refusals, immutable
captured pins. All nine timing workers have some nonflat JIT activity.

Independent Python audit recalculates all **36,000** timed samples' worker
median/p90/throughput, paired ratios/means, exact three-round bootstrap
endpoints, integer allocation ranges and all seed/worker output/control
evidence. The [JSON appendix](native-bench.json) retains this as
`calibrations.lobsters_aa`, separately from Campfire and earlier smoke.
Native hardware instructions remain unavailable (ENOENT); no Callgrind run.

**Decision:** larger warmup/sample settings improved this observed `/` A/A
floor from the initial smoke's 26.94% to 4.34%, but did **not** demonstrate
±2% resolution within the ten-minute budget. This is evidence about these
settings on this orb, not proof that no conceivable native method can do
better. There is no measured ±2% recommendation to publish. Prefer cheap
exactness/allocation screens and report wall as coarse/unresolved for small
bets; a tighter wall claim needs an independently justified environment or
predeclared method, not selective deletion or another run until green.

## Full-request HTTP throughput (`script/rps`)

Owner follow-up: real-server RPS is the final performance target; the Rack
medians and interpreter Ir above remain screens, not server capacity.

### Public Campfire methodology, checked at source

The shared public verification repository was inspected at
[`ec02debb`](https://github.com/basecamp/once-campfire-verification/commit/ec02debb3e44f40b8778a6a42db3c4515b2f9eaf).
Its [`bench/compare.rb`](https://github.com/basecamp/once-campfire-verification/blob/ec02debb3e44f40b8778a6a42db3c4515b2f9eaf/bench/compare.rb#L13-L18)
defaults to three alternating rounds, 16 concurrent clients, 8-second
samples. Per route it first uses **four clients for two seconds** of warmup
([loop](https://github.com/basecamp/once-campfire-verification/blob/ec02debb3e44f40b8778a6a42db3c4515b2f9eaf/bench/compare.rb#L167-L207)).
The external client is its own locked Rust/hyper `loadgen`, not wrk:
HTTP/1.1 keep-alive, one connection/client, gzip by default, route-contract
validation on every response. Apps run serially on CPUs 8–11; the generator
uses CPUs 12–15. The five headline routes are room, messages-before cursor,
sidebar, coffee search and POST message. Avatar, CSS and `/up` also appear
in the default eight-route run but not the headline table.

The harness launches the unchanged Rails Docker image: **Thruster → Puma**,
plus Redis and resque-pool. Harness defaults are three Puma workers × five
threads, overriding the env fixture. Importantly, the **current published
Rails table** instead uses **four workers × one thread**, three *solo*
rounds and source `0aa339d`, not one new alternating eight-app experiment.
The report pins its measured harness to `70e612c`, not the latest HEAD:
[topology and session distinctions](https://github.com/basecamp/once-campfire-verification/blob/ec02debb3e44f40b8778a6a42db3c4515b2f9eaf/docs/performance-review.md#L18-L35),
[reproduction env](https://github.com/basecamp/once-campfire-verification/blob/ec02debb3e44f40b8778a6a42db3c4515b2f9eaf/docs/performance-review.md#L229-L246).

Roundhouse's separate
[`scripts/bench-campfire`](https://github.com/rubys/roundhouse/blob/74dec12e287afae9ce50586c3bab709ec320f824/scripts/bench-campfire)
uses **wrk, two client threads, c=16, 20-second warmups and 3×20-second
samples**, median RPS, identity encoding by default, lanes measured
sequentially. Its deployed Rails lane uses Thruster/Puma with the app's
processor-derived worker count, not the emit lanes' `workers=1` diagnostic.
These are two different protocols and fixtures, neither reproduced by our
orb numbers.

### Reusable orb protocol

`script/rps --config CONFIG.json --output NEW_PRIVATE_DIRECTORY` supports
the retained blog and Campfire GET fixtures. It starts production Puma
**using the app's unchanged `config/puma.rb` and `config.ru`**, including
Campfire's Deflater. No app config patch, server stub, response cache or
in-process request timing. Services use `amp orb service start/stop` and are
stopped even on a failed gate. Dedicated disposable app/DB/Redis only.

- Pinned external **oha 1.14.0**, Linux amd64 release binary SHA256
  `6fc16b5f9901fd2266b1a2b49b1689f76f91ddc7c96f2d0d08b161a870f7ef18`:
  [release](https://github.com/hatoo/oha/releases/tag/v1.14.0),
  [JSON schema](https://github.com/hatoo/oha/blob/v1.14.0/schema.json).
  Download the `oha-linux-amd64` release asset and check that digest before
  running; the harness refuses other bytes. It normalizes `NO_COLOR=true`
  for oha's Boolean env parser (the orb supplies `1`).
- Defaults: **ten rounds**, each with all three fresh-server arms, order
  `off-A/on/off-B`, then rotated each round. Four workers × one request
  thread through the apps' existing env knobs; server CPU set 0–3, generator
  4–7. **16 closed-loop HTTP/1.1 keep-alive clients**, five-second warmup,
  20-second measured send window. `-w` drains in-flight requests and charges
  their completion time. Timeout 30 seconds, redirects disabled, identity
  encoding. RPS is completed responses / actual elapsed (including drain).
  All non-200 statuses and transport failures count as errors.
- Report per-window RPS and p50/p90/p99, median of each arm's window RPS and
  latency percentiles, plus paired-round percentage deltas and the existing
  fixed-seed 5,000-bootstrap 95% band. The A/A band is reported **first**;
  max absolute round spread is retained too. Latency summaries are medians
  of window percentiles, not a pretend pooled histogram.
- Exact preflight uses separate stats-enabled servers. Two-seed **actual
  HTTP requests**, including Campfire's natural CSRF/cookie login, enter
  the existing pinned `BlogProduction::Entropy` controls only during
  designated untimed samples. An outer Rack observer consumes/closes the
  real body and records literal status/body/all-Rack-header digests, without
  deleting or normalizing fields. The notification instrumenter is initialized
  on that Puma request thread before the controlled sample; otherwise its
  lazy, non-output `SecureRandom.hex(10)` would be an undeclared RNG site.
  Existing entropy policies are unchanged. Cold and post-warmup samples
  compare separately; failures refuse timing by default. An explicit
  `diagnostic_load_on_exact_failure: true` retains a failed gate and exit 2,
  allowing noise calibration only, never a speed/support claim.
- Puma-added transport headers (notably real `Date`) are separately digested
  exactly as received; no literal transport-header equality is claimed.
  The exact gate covers the Rack response actually served, not SQL, complete
  DB state, async completion or the app's own suite. Timed requests have no
  validation header, seed or clock/RNG pin; their cookies come from a separate
  natural login. Public hit counters are off in every timed server.

Start with the existing native app/seed/rebuilt-artifact config, replacing
its screening `rounds` value explicitly and adding:

```json
{
  "path": "/articles/1",
  "rounds": 10,
  "oha": "/absolute/oha-1.14.0",
  "validation_policy": "/absolute/repo/fixtures/corpus/blog-entropy-controls.json",
  "fixture_secret_key_base": "the disposable BlogProduction::Entropy::SECRET"
}
```

For Campfire use `/rooms/486777696`, `campfire-entropy-controls.json`, the
seed's existing secret (no blog secret override), and acknowledge the
dedicated localhost Redis with `CAMPFIRE_DISPOSABLE_REDIS=1`.

External prototypes may use the existing post-boot `exploration_setup` hook.
An optional **external Puma setup** file is required in every arm, after the
unchanged app Puma config is evaluated. It defines:

```ruby
module NativeRps::PumaSetup
  def self.configure(puma:, config:, arm:)
    # Explicit caller policy, not automatic production activation:
    return unless arm == "on"
    puma.before_fork { MyExperiment.prepare }
  end
end
```

Set `puma_setup` to its absolute path and list further dependencies in
`exploration_sources`. The setup, app/Puma config, runtime, artifact, lock,
seed and policies are hashed; any drift stops the run. Fizzy/Lobsters HTTP
login/validation adapters are not yet implemented by this bounded first
version; the existing Rack screen still supports them. Do not silently
substitute unauthenticated/zero-hit HTTP routes for those studies.
