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

## Results / JSON appendix

Pending the finite native cohorts. No speed direction is inferred from the
harness smoke runs or the accepted interpreter instruction result.
