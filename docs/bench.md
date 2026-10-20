# Request costs and benchmark method

`bench/request_pairs.rb` isolates Lowrail's setup cost from its enabled passes.
Use the `script/corpus` pins and production database/assets/authentication
setup described in the [Campfire M0](m0/campfire.md). Ruby 3.4+ is required;
these runs use the repository's Ruby 4.0.7. **Callgrind instructions are the
primary work metric; native YJIT CPU/wall time and allocations are secondary.**

## Primary: executed instructions

```sh
sudo apt-get install valgrind # includes the client-request headers
BENCH_COUNTER=callgrind mise exec -- ruby bench/request_pairs.rb \
  .corpus/real-blog /tmp/blog-instructions GET:/articles
# Campfire uses the same private BENCH_HEADERS/path setup shown below.
# BENCH_JIT=1 enables YJIT; interpreter is the controlled default.
```

Build production first (see below). Interpreter mode sets Rails' `config.yjit`
to false before initialization: Rails otherwise enables it even when Ruby
starts with `--disable-yjit`. Every worker reports its actual JIT state and
the driver rejects a mismatch. Do not infer interpreter mode from command flags.

Each of three independent rounds runs fresh N=0 and N=200 processes per
layer, with a seeded randomized order and at most four concurrent workers.
Each process boots production Rails, warms 50 requests, then runs `GC.start`.
A tiny Ruby extension (`bench/callgrind.c`, compiled into the private output
directory) uses Callgrind's client requests to start instrumentation **after**
warmup/GC, zero counters and dump **before** reporting/exit. Read the client
dump (`.callgrind.1`), not the process-exit total. `(Ir200 − Ir0) / 200`
also subtracts the fixed measurement seam. Boot is not counted or estimated;
ordinary request-loop GC remains included. Warmup and measurement call the
same loop ISeq. `--smc-check=all-non-file` handles generated machine code.

This refines whole-process N=200 minus N=0 subtraction: it avoids subtracting
two large, potentially different boot/GC/JIT totals and is much cheaper than
instrumenting the boot. All non-2xx responses fail. Every round has independent
off/off workers. Their nominal 95% bootstrap difference CI must include zero
and fit within ±0.5%, otherwise exit 2. Do not rerun or widen the margin to
make a control pass. These are **software-executed instructions**, not PMU
counts, CPU cycles or latency; syscall/kernel work is not counted. Interpreter
counts do not capture YJIT execution, compiler, code-layout or cache effects.

`BENCH_REQUESTS=200`, `BENCH_ROUNDS=3`, `BENCH_JOBS=4`, `BENCH_WARMUP=50`,
`BENCH_JIT=0` and `BENCH_SEED=41231` are the counter defaults. Samples retain
both raw totals, so the subtraction is auditable. Bootstrap whole independent
rounds (5,000 resamples), not requests or individual instructions. With only
three rounds these are coarse nominal intervals, not calibrated 95% coverage.
Use `BENCH_LOWRAIL_LIB=/absolute/old/gem/lib` for a complete old runtime snapshot
without changing the app/build; before/after must use identical manifests.
The optional AR build below works in both modes.

YJIT **does run** under this orb's Valgrind 3.19: a small correct-result probe
compiled three ISeqs, and Rails compiled thousands. However, the initial
50-warmup YJIT diagnostic still compiled roughly 700 additional ISeqs during
its 200 measured requests; Callgrind attributed substantial work to the JIT
compiler. It is not a steady-state comparison. Interpreter counts are primary
here; `BENCH_JIT=1 BENCH_WARMUP=400` is available for longer-warmup investigation.
No interpreter result below is a native YJIT speed claim.

## Secondary: native YJIT time and allocations

```sh
RAILS_LOG_LEVEL=error SECRET_KEY_BASE_DUMMY=1 mise exec -- \
  target/debug/lowrail build .corpus/real-blog --env production
# Include independently booted processes in uncertainty, not just block noise.
export BENCH_COHORTS=5 BENCH_ROUNDS=8 BENCH_SECONDS=0.6
mise exec -- taskset -c 2 ruby bench/request_pairs.rb \
  .corpus/real-blog /tmp/blog-costs GET:/articles

# Campfire: private fixture cookie, never put it in a report or commit.
export BENCH_HEADERS="$(cat .corpus/campfire/tmp/m0/headers.json)"
path=$(jq -r .room .corpus/campfire/tmp/m0/paths.json)
CAMPFIRE_RESPONSE_CACHE_MB=0 mise exec -- taskset -c 2 ruby \
  bench/request_pairs.rb .corpus/campfire /tmp/campfire-costs "GET:$path"
# Repeat without CAMPFIRE_RESPONSE_CACHE_MB for the default response cache.
```

### Method

The driver starts one separate Ruby process per layer, then runs only one
worker at a time. It does not fork a warmed Rails process or share Ruby heaps.
Each worker eagerly loads Rails, disables request logging, warms 400 requests,
then performs two additional untimed blocks. A baseline calibration selects
one fixed request count corresponding to about 0.5 seconds of process CPU time
per block. All layers use that count. The default is five cohorts of eight rounds; each round
visits every layer once, rotating and reversing a seeded initial order.
Processes stay alive across rounds: these are **warm steady-state** costs,
not boot costs, fresh-boot distributions, cold caches or a load test.

Layers are no `lowrail/setup` (two independent off/off workers), setup with
no manifest, a compatible zero-unit/file/template manifest, the normal build
with `LOWRAIL_UNITS=""`, and the normal default build. Builds are copied to
private temporary roots; the app's manifest is never renamed or edited. An
optional `BENCH_INSTANTIATE_DIR=/absolute/copied/.lowrail` adds a production
default + `--ar-instantiate` build to the same rounds. Unit ids are not assumed.

Timing uses `CLOCK_PROCESS_CPUTIME_ID` and `CLOCK_MONOTONIC`, alongside the
delta of `GC.stat(:total_allocated_objects)`, divided by completed requests.
Explicit GC, pipe IO, boot and warmup are outside the sample. GC during the
request loop remains included. Each request goes through Rack and consumes
its response body; a non-2xx response fails. Stats/reporters/profilers are off
during timing. Default-cache Campfire repeats the same authenticated path;
cache-disabled Campfire still retains warm fragment caches.

The summary reports medians of block means, not request latency percentiles.
95% percentile-bootstrap CIs use 5,000 resamples with a fixed seed. In a
single-cohort diagnostic run (`BENCH_COHORTS=1`), these resample **whole rounds**.
For reported comparisons use the default `BENCH_COHORTS=5` or more: each cohort boots new
workers, uses a different order seed and runs `BENCH_ROUNDS` rounds. The final
estimator is the median of cohort medians, bootstrapping **cohorts**, so a
process-specific JIT/heap bias is not mistaken for many independent samples.
Changes first take same-round ratios to `off_a`, not ratios of aggregate
medians. All cohorts, including individually failed controls, are retained;
there is no retry-until-green. Five cohorts still give coarse bounds and are
not a guarantee against host interference. The off/off control must
include zero in its CPU and wall difference CIs, **and both entire intervals
must fit inside ±2%**. Otherwise the driver exits 2 and results are not accepted
as a pass comparison. This is a practical noise gate, not proof of exact
equality or a correction for process-specific JIT layout and host interference.

`BENCH_COHORTS`, `BENCH_ROUNDS`, `BENCH_SECONDS`, `BENCH_WARMUP` and `BENCH_SEED` configure the
experiment. Keep them fixed between before/after runs; do not widen
`BENCH_AA_TOLERANCE` just to pass a failed control. `samples.json` records all
rounds, Ruby/YJIT/process identities, request count and manifest digest;
`summary.json` contains estimates, CIs and the control verdict. Output must be
a new directory. Raw logs/headers stay private, outside Git.

`BENCH_PROFILES=1` additionally records CPU (1 ms) and object (1/100 allocations,
aggregate frames only to bound memory)
StackProf profiles **after the first cohort's timing**, then traces Lowrail Ruby call counts
and invalidation names for 100 warmed requests. Profiles are explanatory, not
timing samples. `bench/profile_summary.rb` can summarize raw profiles. The
ordinary `bench/requests.rb` one-shot interface remains available.

In this x86-64 E2B orb, `perf stat -e instructions,cycles true` reports both
hardware events **not supported**, even with `linux-perf` installed. No PMU
instructions/request are available. Callgrind supplies the software counts
above; do not divide whole-process perf totals (including boot/warmup) by
timed requests.

## Profiles and safe reductions

The production manifests are held fixed across runtime changes (11 default
units on real-blog, 60 on Campfire; the optional build adds AR instantiate).
These fixes change runtime delivery/counting, not lowering decisions:

- An explicitly empty selection now serves original source without installing
  the loader, template or invalidation hooks. A compatible zero-unit manifest
  also needs no hooks. Outcome/statistics reporters still boot independently;
  partial selections still load the code and enforce each unit's guard.
- Receiver guards keep their class-identity hashes, false caches and exact
  invalidation semantics. Counting is prepended only by `Stats.enable!`,
  removing `defined?(Stats)`/`Stats.enabled?` from normal calls. Three YJIT
  Callgrind micro runs (1.5 million cached checks each) measured about
  **1,294.537 → 662.488 instructions/check (−48.824%)**, with less than
  0.001 instruction/check spread within each version. This is a guard micro,
  **not a 49% request speedup**. Late activation, both aliases, two classes,
  invalidation and restoration are regression-tested.

Across 100 warmed native requests per layer, tracing found **no definition
hooks, invalidations, file-loader calls or template compilation**. There is
no evidence to weaken those hooks or replace the class cache. Before the fix,
real-blog disabled/default invoked 14/20 receiver guards per request; its
default completed 10 routes plus HTML escaping. Uncached Campfire invoked
seven guards; cached Campfire invoked **no Lowrail method**, including with
AR instantiate. The response cache bypasses presentation/AR work.

On uncached Campfire, those seven guard decisions are true, but **zero route
completions** occur: the live `optimize_routes_generation?` predicate returns
false. A counted probe observes 14 true RouteSet returns, 14 false UrlFor,
14 false RoutingUrlFor and seven false OptimizedUrlHelper returns. The
generated branch and original fallback both call the live predicate. Therefore
guard-hit counters alone do not prove a completed route specialization on
this endpoint. Do not cache that predicate or move it ahead of argument
evaluation just to eliminate the fallback cost.

CPU samples attribute little self time to guard lookups and sampled allocation
profiles attribute no allocation to them. Cached Campfire's allocation profile
is dominated by the unchanged `InlineScriptHashes#script_locations` stack
(4,529/6,162 sampled allocations inclusive), regexp and string work, not Lowrail.

Instruction counts do **not** eliminate GC-phase effects. In the first
interpreter real-blog pair, baseline/default total 200-request work is
1.914/2.068 billion instructions. Self instructions attributed just to Ruby
GC source files rise from 115.5 to 289.3 million—more than the entire net
increase. The top positive differences are marking, sweeping and ISeq/IMEMO
marking; VM dispatch work falls. No-manifest outliers show the same GC signature
despite zero request-time Lowrail calls. This establishes collection work in
the measured difference, not a universal 8% guard tax or proof of a zero base
cost. Primary results **include** this GC work; do not subtract it away or
disable GC to turn a comparison green.

Correctness after both changes: `lowrail verify`, `PARALLEL_WORKERS=1`,
`LOWRAIL_SQL_TRACE=full`, test seed 41231:

| App/build | Identical outcomes | Identical SQL events | Guard/pass hits | Fallbacks |
|---|---:|---:|---:|---:|
| real-blog default | 21 | 125 | 57 / 11 units | 0 |
| real-blog + instantiate | 21 | 125 | 98 / 13 units | 0 |
| Campfire default | 634 (2 skips) | 15,108 | 7,200 / 52 units | 0 |
| Campfire + instantiate | 634 (2 skips) | 15,108 | 9,851 / 65 units | 3,129 / 17 units |

AR fallbacks preserve the pre-existing STI/schema-switch boundaries. The gem
suite passes (79 tests, 1,269 assertions, four optional-dependency/corpus skips),
as do Rust tests and the benchmark's control tests. No hooks or facts were
weakened. Hardware PMU counters and a validated native latency improvement
remain unavailable.
