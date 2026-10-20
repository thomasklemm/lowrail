# Request costs and benchmark method

`bench/request_pairs.rb` isolates Lowrail's setup cost from its enabled passes.
Use the `script/corpus` pins and production database/assets/authentication
setup described in the [Campfire M0](m0/campfire.md). Ruby 3.4+ is required;
these runs use the repository's Ruby 4.0.7 and YJIT.

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

## Method

The driver starts one separate Ruby process per layer, then runs only one
worker at a time. It does not fork a warmed Rails process or share Ruby heaps.
Each worker eagerly loads Rails, disables request logging, warms 400 requests,
then performs two additional untimed blocks. A baseline calibration selects
one fixed request count corresponding to about 0.5 seconds of process CPU time
per block. All layers use that count. The default is 24 rounds; each round
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
single-cohort diagnostic run (the default), these resample **whole rounds**.
For reported comparisons use `BENCH_COHORTS=5` or more: each cohort boots new
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
hardware events **not supported**, even with `linux-perf` installed. No
instructions/request are available; do not divide whole-process perf totals
(including boot/warmup) by timed requests.
