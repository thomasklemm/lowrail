# Request costs and benchmark method

`bench/request_pairs.rb` isolates Lowrail's setup cost from its enabled passes.
Use the `script/corpus` pins and production database/assets/authentication
setup described in the [Campfire M0](m0/campfire.md). Ruby 3.4+ is required;
these runs use the repository's Ruby 4.0.7. **Callgrind instructions are the
primary work metric; native YJIT CPU/wall time and allocations are secondary.**

## Shared command: `lowrail bench`

Migration step 5 uses the existing harness, not a second measurement method:

```sh
# Build once; bench never rebuilds or modifies the app's manifest.
RAILS_LOG_LEVEL=error SECRET_KEY_BASE_DUMMY=1 mise exec -- \
  target/debug/lowrail build .corpus/real-blog-r4 --env production
mise exec -- target/debug/lowrail bench .corpus/real-blog-r4 \
  --pass default --path /articles --out /tmp/blog-bench

# A pass name or its Rust-registry alias selects only that pass's unit IDs.
# Build with --passes default,+ar_instantiate first for this example.
mise exec -- target/debug/lowrail bench .corpus/real-blog-r4 \
  --pass ar_instantiate --path GET:/articles --out /tmp/blog-ar-bench \
  --micro-case load_20 --model Article

# Campfire fixture authentication remains private, as in the M0 setup.
export BENCH_HEADERS="$(cat .corpus/campfire/tmp/m0/headers.json)"
path=$(jq -r .room .corpus/campfire/tmp/m0/paths.json)
CAMPFIRE_RESPONSE_CACHE_MB=0 mise exec -- target/debug/lowrail bench \
  .corpus/campfire --pass default --path "$path" --out /tmp/campfire-uncached
# Repeat with a NEW output directory and CAMPFIRE_RESPONSE_CACHE_MB unset
# for the cached endpoint. No failed A/A run is retried to obtain a green run.
```

`--path` defaults to `/` and accepts `/path` or `VERB:/path`. It must return
2xx, not an authentication redirect. `--out` defaults to `APP/tmp/lowrail-bench`
and must not exist. `--pass default` measures **all units in the existing
build**, including optional ones if present; named passes select their own
IDs through `BENCH_UNITS` on the harness's enabled/default layer. Other layers
stay intact. This is guard selection, not a rebuild: other emitted sites
still pay their fallback guards. For a single-pass build without that cost,
exclude the other passes at build time, e.g.
`--passes default,-link_to,-path,+ar_instantiate`.
`BENCH_INSTANTIATE_DIR` still adds a second complete build to a
default/base-cost experiment. It too gets a strict activation probe.

`BENCH_BASELINE_LIB=/absolute/archived/gem/lib` adds the existing same-manifest
before-runtime instruction layer and `runtime_change_pct`. Use a source-only
build with `--pass default`: named selection would otherwise compare different
unit sets. The archived library gets its own strict preflight, activation/JIT
probe and end-of-run fingerprint check. Optional GC diagnostics still describe
the current runtime, not this instruction-only archived comparison.

The default counter is fixed-heap Callgrind, interpreter, six fresh rounds;
all heap/GC/window controls and bootstrap CIs below apply unchanged. The CLI
rejects legacy heap mode and tolerance overrides. `--counter native` selects
the existing YJIT CPU/wall experiment (at least five independent cohorts;
one-boot diagnostics are refused); `--diagnostics` additionally
runs `gc_requests.rb` through the existing GC driver. The same environment
settings below control requests, warmup, cohorts, jobs, seed and pool floors.
Do not run builds or other native benchmarks concurrently with a measurement.

Before measuring, the command rejects incompatible Ruby/format/environment,
changed source/templates, absent/corrupt ISeqs or loader contracts and changed
pass certificates (including the library actually selected by
`BENCH_LOWRAIL_LIB`). A separate warmed, counted process checks activation,
loaded-file delivery, actual JIT state and per-unit hits/fallbacks. Runtime AR
variants must actually be installed. Every measured request worker's **actual**
JIT state is checked too; Ruby flags alone do not override production
`config.yjit`. A second fingerprint check rejects concurrent build/source
changes. None of these probes runs in a measured window. A zero-hit cached
route is valid coverage evidence, not evidence that its pass improved anything.

Outputs, also on rejection:

- **`result.json`**, schema version 1, recursively sorted object keys: verdict,
  pass selection, corpus/lock/runtime/manifest fingerprints, actual JIT state,
  counted coverage, layered estimates, both A/A gates, heap checks and optional
  micro/budget. Missing quantities are not invented; `measurement_complete`
  is false for request-only, mixed-metric or partially modeled measurements.
- **`table.md`** and the same short stdout table: total/GC-excluded instructions
  (or CPU/wall µs), paired deltas/CIs, verdict and the per-hit budget if measured.
  Copy this plus the relevant JSON into `docs/passes/`; include rejected controls.
- Private `requests/` samples/client dumps and worker logs, optional
  `diagnostics/`, and micro samples. Headers/cookies are never serialized by the
  runner. Paths, app logs and heap diagnostics can still contain secrets; review
  them before publishing. The CLI exits nonzero on a failed control or build.

### Guard-included micros and expected effect

`--micro-case CASE` reuses `ar_instantiate.rb`, `preload_paths.rb` or
`ar_cached_reader.rb`, depending on the selected pass. `--model MODEL` is
required for instantiate, e.g. `load_20`/`Article` or `load_20`/`Message`.
Preload's `already_loaded_creator` is a narrow Campfire case; SQL readers use
their exact output label (and `BENCH_READER=logo|avatar` where appropriate).
Only operations with genuine completed hits are accepted, not component-only
builder/epoch timings or zero-hit controls.

Six randomized, fresh-process off/off/on native-YJIT rounds include the real
method's guard and original fallback. Their A/A wall-time CI must contain zero
and fit within ±2%. `BENCH_MICRO_ROUNDS` (minimum six) and
`BENCH_MICRO_SECONDS` (default 0.5 per process/case) control the micro only.
A separate counted micro obtains completed hits/iteration; each case must
exercise exactly one selected unit. The tool subtracts paired off/on µs and
divides by those hits, then multiplies by that **same unit's** independently
counted request frequency. Savings are signed: a regression stays negative.
Other hit units are listed as unmodeled rather than borrowing this unit's cost.

Use `--counter native --micro-case ...` for a same-metric comparison of that
expected µs/request with the measured request saving and its A/A control.
Interpreter instructions cannot be converted into YJIT µs; the default run
keeps these separate and cannot constitute a complete promotion measurement.
Request-only acceptance is not pass promotion or a native speed claim.

### Immediate follow-up: stacked pass sets

The current CLI accepts `--pass NAME`, **not** `--passes`. Stacked measurement
is the immediate follow-up, not a claim that every individual pass must save
2% by itself. Many smaller passes may add up to a worthwhile set.

The intended interface is `--passes default,+ar_instantiate,+inertia/config_bind`
or `--passes all-opt-in`, against a build containing all requested units. It
needs a **separate stacked layer alongside no-setup, default and independent
A/A workers**. Reusing today's selected/default layer would erase the default
comparison and make the result ambiguous. The output must show stacked saving
against both references, the sum of comparable individual guard-included
expected effects, the difference from that sum, and per-unit coverage/fallbacks
to reveal overlap or interference. Missing budgets must remain unmodeled;
µs/YJIT and interpreter instructions must not be added together. Controls keep
their present gates. Native uncertainty must account for independent boots,
not treat blocks from one worker as independent experiments.

This also needs multi-operation/model budget input, whereas today's guarded
micro adapter deliberately models one unit at a time. It is therefore a
report/measurement-contract extension, not just another selector spelling.
`--pass default` over an optional build does measure its complete enabled set
against no setup, but does **not** provide the separate default reference or
additivity report and must not be presented as that feature.

### Remaining per-pass adapters

The request branches of `ar_instantiate_runs.rb` and `ar_cached_runs.rb` now
delegate to this command's Ruby entry point and produce its reports. Historical
micro/breakdown entry points remain available as diagnostics. Still per-pass:

| Pass/tool | Remaining work, not supplied by the shared driver |
|---|---|
| route/path, view/link_to | guarded emitted-operation micros and site-specific budgets; `routes.rb` explicitly excludes the call-site guard and is not imported as a guarded saving |
| memo, digest | guarded micro adapters and completed-hit denominators; `memo_runs.rb`, `memo_check.rb` and digest pass-specific fixtures remain diagnostic recipes |
| preload | mixed-query/result workloads and the legacy multi-format/cache `preload_runs.rb` sweep; the narrow micro already uses the shared controls |
| AR instantiate | per-model/row-shape budgets; do not apply one model's saving to another model or STI fallback |
| AR plans | reader selection, completion frequency and cold/missing-attachment interpretation; `ar_plans_runs.rb` is a diagnostic implementation comparison, not an installed-pass gate |
| new passes | attest runtime activation and add an operation adapter after defining a genuine completed-hit counter; shared request, rejection, A/A and report machinery needs no new copy |

For a new **native** operation adapter, retain the original method/fallback
and guard in the timed operation. Write `BENCH_JSON` as rows with `case`/`us`
(or `route`/`us_per_req`); snapshot `PassProbe.counts` before timing and attach
`PassProbe.sample(iterations, before)` after timing for the separate counted
worker. Register the operation in `PassBench.micro` and attest activation in
`PassProbe.active!` if it is a runtime pass. The shared driver supplies the
fresh workers, actual-JIT check, A/A, hit denominator and budget.

There is **no generic callback/compiled-template fixed-heap instruction micro
adapter yet**. Add that operation boundary to the shared Callgrind runner
(client windows, N−0 subtraction, independent rounds and the existing A/A
gate), rather than introducing another timing protocol. Request instructions
already use this method; the existing native micro is not an instruction
budget for it.

### CLI validation against the base-cost experiment

The migration replays all six published primary datasets through the shared
summary code: default/instantiate medians and CIs agree to 1e−10, and the
historical **before-cached A/A remains rejected**. This checks analysis
compatibility; it is not a fresh application measurement.

Fresh production runs use Ruby 4.0.7, the same corpus pins and fixed-heap
six-round/50-request/50-warmup method. The archived after-runtime library
matches every runtime digest in the published dataset. The new real-blog-r4
lockfile is byte-identical to the original real-blog lockfile. Default and
optional builds are held unchanged within each fresh comparison. The table
compares total instruction deltas against no setup, in percent:

| Route/layer | Published after median [95% CI] | Fresh CLI median [95% CI] | Point difference (percentage points) |
|---|---:|---:|---:|
| real-blog-r4 default | −5.959 [−5.983, −5.949] | −5.935 [−5.964, −5.901] | +0.024 |
| real-blog-r4 +instantiate | −5.728 [−5.746, −5.681] | −5.669 [−5.699, −5.640] | +0.059 |
| Campfire uncached default | +0.122 [+0.054, +0.151] | +0.098 [+0.072, +0.109] | −0.024 |
| Campfire uncached +instantiate | −0.126 [−0.133, −0.102] | −0.116 [−0.142, −0.103] | +0.010 |
| Campfire cached default | −0.045 [−0.110, +0.022] | −0.041 [−0.088, +0.049] | +0.004 |
| Campfire cached +instantiate | +0.029 [−0.046, +0.081] | +0.051 [+0.028, +0.116] | +0.022 |

All three fresh experiments pass total and GC-excluded A/A and all five heap
capacity controls. These reproduce the base-cost result under an independent
run-to-run comparison, **not** a requirement that a new point estimate fall
inside an old narrow interval. Nominal six-round bootstrap CIs understate
run-to-run variance; retain both intervals and the point differences rather
than rerunning controls or widening their tolerance. This is an instruction
result, not a YJIT latency claim.

The native-YJIT `Article/load_20` micro also exercises the budget: exactly
20 completed hits/iteration and 3 Article hits/request. The other 3
Comment hits/request remain explicitly unmodeled. Its A/A is **rejected**:
+3.714% [−4.171, +17.045], outside ±2%. The diagnostic −0.258 µs/hit × 3 =
−0.774 µs/request is therefore **not an accepted effect estimate**. No control
was retried. Sanitized reports, exact comparisons, coverage and the failed
micro are in [bench-cli-results.json](bench-cli-results.json).

After pulling the shared archived-runtime seam, a current-runtime named
`ar_instantiate` CLI run passes both instruction A/A and heap controls:
+0.588% [+0.559, +0.634] total, +0.587% [+0.577, +0.654] GC-excluded.
This selection retains other emitted fallback guards; it is not the complete
default/+instantiate comparison above. Its probe attests all 17 model variants,
3 Article + 3 Comment hits/request and zero completed route specializations.
`--diagnostics` completes three rounds/36 GC workers, all actually interpreter.
The five-cohort native CLI check is correctly **rejected**: CPU A/A CI
[−3.590, +4.760]%, wall [−3.610, +4.792]%, outside ±2%; all workers actually
enable YJIT. It produces no accepted request saving or micro budget.

The source-only `BENCH_BASELINE_LIB` CLI comparison also passes: both current
and archived activation probes complete 10 route specializations/request;
same-manifest current-versus-archived total change is +0.0037%
[−0.0608, +0.0514], excluded −0.0289% [−0.0390, +0.0167]. This validates the
wrapper against the pre-registry runtime on main, not the separately gated
step-4 runtime refactor. Both A/A and heap controls pass. All of these reports
are included in the sanitized JSON above; failed native controls are retained.

Deliberately stale Ruby/format metadata and an invalid original-ISeq
fingerprint in the real blog build are rejected before measurement; the
manifest is restored afterward. A boot fixture that explicitly enables YJIT
despite interpreter intent is rejected too. The probes require JSON only
after Bundler locks the app's version (Campfire provides the real-app check).

## Primary: executed instructions

```sh
sudo apt-get install valgrind # includes the client-request headers
BENCH_COUNTER=callgrind mise exec -- ruby bench/request_pairs.rb \
  .corpus/real-blog /tmp/blog-instructions GET:/articles
# Campfire uses the same private BENCH_HEADERS/path setup shown below.
# BENCH_JIT=1 enables YJIT; interpreter is the controlled default.
```

`BENCH_VARIANT_APP=/absolute/prepared/fork` adds an `app_fix` layer, with
Lowrail off, to either the instruction or native experiment. It boots that
checkout rather than loading a handwritten benchmark replacement. Keep its
lockfile, assets, fixture database and authentication identical to baseline;
the original A/A workers and gates remain mandatory. See the
[Campfire importmap investigation](passes/importmap.md) for an example with
**failed controls**, plus the method micro and actual HTML/CSP byte checks.

Build production first (see below). Interpreter mode sets Rails' `config.yjit`
to false before initialization: Rails otherwise enables it even when Ruby
starts with `--disable-yjit`. Every worker reports its actual JIT state and
the driver rejects a mismatch. Do not infer interpreter mode from command flags.

Each of six independent rounds boots a fresh process per layer, with a
seeded randomized order and at most four concurrent workers. Each process
warms 50 requests, then measures N=0 and N=50 windows in both total and
GC-excluded modes. Their order alternates by round. Before **each** window,
three full GCs mature survivors and clear garbage. All five size pools have
the same explicit `RUBY_GC_HEAP_0_INIT_SLOTS` through `_4_INIT_SLOTS` floors:
1,000,000 / 250,000 / 100,000 / 20,000 / 10,000. These oversized floors
are experimental controls, **not a proposed production GC setting**. The
settings alone do not reserve pages. Untimed preparation fills each pool
with disposable Arrays and retains sparse page anchors (about 2,200 small
Arrays, counted in worker metadata) so full GC cannot move empty pages out
of eden. GC is disabled only while building these fillers; it is enabled
for every warmup/measured request. This is a 64-bit MRI diagnostic, not a
production-heap retention measurement. The driver checks actual starting
capacities across all layers/windows: they must reach the target and match
within one page per pool, or the experiment exits 2. It also records every
pool's live/free slots and allocated-page/object counters.

A tiny Ruby extension (`bench/callgrind.c`, compiled into the private output
directory) uses Callgrind's client requests to start instrumentation **after**
warmup/GC, zero counters and dump **before** reporting. Read the four client
dumps (`.callgrind.1` through `.4`), not the process-exit total. Use each
dump's trailing `totals: Ir`: Valgrind 3.19 can wrap `summary:`
after repeated zero/dump requests; `totals:` agrees with summed self costs.
Each mode reports `(Ir50 − Ir0) / 50`, removing the measurement seam. Total mode
includes ordinary request-loop GC; the second mode suspends collection only
between Ruby's internal `GC_ENTER`/`GC_EXIT` events, for every incremental
mark/lazy-sweep segment. `GC_START` through `GC_END_SWEEP` would incorrectly
exclude Ruby work between segments. Barrier/entry/exit fringe remains in
the GC-excluded count. A Valgrind regression checks that incremental GC work
is removed while intervening arithmetic remains counted, against a separate
GC-disabled synthetic control. **GC stays enabled in all request windows.**
Total and excluded modes use separate windows, not simultaneous counters.
Ordinary request variation can put an excluded median slightly above total
when neither window collects; their difference is not an exact GC-cost estimate.

Both windows retain absolute `GC.stat` endpoints: minor/major counts,
live/old objects, allocated objects and collector time. The summary includes
collections/request and collections/1,000 allocations. A fixed-heap slice
can contain zero GCs: it isolates request work at that capacity, not the
steady-state GC tax of a production heap. Compare total and excluded counts
rather than silently presenting the latter as total work. Warmup and
measurement call the same loop ISeq. `--smc-check=all-non-file` handles
generated machine code.

This refines whole-process N=200 minus N=0 subtraction: it avoids subtracting
two large, potentially different boot/GC/JIT totals and is much cheaper than
instrumenting the boot. All non-2xx responses fail. Every round has independent
off/off workers. Their nominal 95% bootstrap difference CI must include zero
and fit within ±0.5%, otherwise exit 2. Do not rerun or widen the margin to
make a control pass. These are **software-executed instructions**, not PMU
counts, CPU cycles or latency; syscall/kernel work is not counted. Interpreter
counts do not capture YJIT execution, compiler, code-layout or cache effects.

`BENCH_REQUESTS=50`, `BENCH_ROUNDS=6`, `BENCH_JOBS=4`, `BENCH_WARMUP=50`,
`BENCH_JIT=0` and `BENCH_SEED=41231` are the counter defaults. Samples retain
all raw totals, so the subtraction is auditable. `BENCH_HEAP_SLOTS` overrides
the five comma-separated floors; keep them identical across comparisons.
Bootstrap whole independent rounds (5,000 resamples), not requests or
individual instructions. Six rounds still give coarse nominal intervals,
not calibrated 95% coverage. `BENCH_HEAP_MODE=legacy` retains the earlier
N=200, three-round diagnostic without heap-phase normalization; do not use
its total counts as the primary comparison.
Use `BENCH_LOWRAIL_LIB=/absolute/old/gem/lib` for a complete old runtime snapshot
without changing the app/build; before/after must use identical manifests.
The optional AR build below works in both modes.
All comparisons check every AR source certificate before boot; primary
counter and native workers also require installed model entries afterward. A manifest that
silently declines is not an active-pass measurement. Rebuild after changing
its certified builder/runtime files; do not edit certificate hashes by hand.

YJIT **does run** under this orb's Valgrind 3.19: a small correct-result probe
compiled three ISeqs, and Rails compiled thousands. However, the initial
50-warmup YJIT diagnostic still compiled roughly 700 additional ISeqs during
its 200 measured requests; Callgrind attributed substantial work to the JIT
compiler. It is not a steady-state comparison. Interpreter counts are primary
here; `BENCH_JIT=1 BENCH_WARMUP=400` is available for longer-warmup investigation.
No interpreter result below is a native YJIT speed claim.

### Controlled instruction results (2026-10-20)

Production builds held identical across runtime snapshots. Before entry point:
[22466cf](https://github.com/thomasklemm/lowrail/commit/22466cf0a56dbe1c5e32948745e8724618e0cd0f);
after runtime:
[ed4169e](https://github.com/thomasklemm/lowrail/commit/ed4169e972091cc7db33655619eeb2f7eaa38b1e).
The baseline snapshot's statistics file already contains the opt-in counting
module, but it is never loaded in these statistics-disabled workers. Other
baseline runtime files match the before commit. AR helpers are frozen before
the concurrent upstream shadow/epoch changes; these are not measurements of
that later AR runtime. Full runtime digests, estimates and diagnostic endpoints
are in [bench-results.json](bench-results.json).

Corpus: real-blog `/articles` from Roundhouse
[bb90df2](https://github.com/rubys/roundhouse/commit/bb90df2514f80817f98d89848dd0a6baa8df20a9),
Campfire's authenticated M0 room at
[af4dd9f](https://github.com/basecamp/once-campfire/commit/af4dd9fd599c65e0e0fc1f614ee469f70156ddf5).
Uncached means `CAMPFIRE_RESPONSE_CACHE_MB=0`; cached uses its default 64 MB.
Tables show millions of instructions/request and percent changes against
the same-round **no-setup** process, median [nominal 95% bootstrap CI].
Allocations come from the total window. The independent A/A row is not
another setup layer. Small nonzero residuals comparable to A/A variation,
especially on paths with no Lowrail calls, are not optimization wins.

**Before:** blog and uncached Campfire pass both A/A gates. Cached Campfire
fails: its total A/A interval is [−0.0563%, −0.0016%], GC-excluded
[−0.0466%, −0.0072%]. These are tiny differences, but neither interval includes
zero, so **all before-cached rows are descriptive, not accepted pass comparisons**.
No control was retried or tolerance widened. All actual heap-capacity checks pass.

| Before app/layer | Total M Ir/request | Total Δ% [95% CI] | GC-excluded M Ir/request | Excluded Δ% [95% CI] | Objects/request |
|---|---:|---:|---:|---:|---:|
| blog no setup | 9.116181 | reference | 9.116012 | reference | 2,358.64 |
| blog A/A | 9.115508 | -0.0100 [-0.0412, +0.0324] | 9.115415 | -0.0208 [-0.0388, +0.0244] | 2,358.90 |
| blog no manifest | 9.113436 | -0.007 [-0.059, +0.016] | 9.113841 | -0.002 [-0.080, +0.022] | 2,358.71 |
| blog zero units | 9.115876 | -0.014 [-0.049, +0.014] | 9.114429 | -0.022 [-0.056, +0.025] | 2,358.24 |
| blog all disabled | 9.139336 | +0.245 [+0.225, +0.265] | 9.138198 | +0.246 [+0.208, +0.268] | 2,358.71 |
| blog default | 8.592069 | -5.759 [-5.780, -5.721] | 8.592494 | -5.749 [-5.766, -5.710] | 2,235.29 |
| blog + instantiate | 8.610147 | -5.556 [-5.575, -5.524] | 8.612189 | -5.533 [-5.573, -5.497] | 2,234.78 |
| Campfire uncached no setup | 99.533238 | reference | 93.080259 | reference | 22,564.40 |
| Campfire uncached A/A | 99.557027 | +0.0308 [-0.0011, +0.0521] | 93.103733 | +0.0305 [-0.0002, +0.0591] | 22,564.36 |
| Campfire uncached no manifest | 99.519876 | -0.007 [-0.034, +0.005] | 93.076590 | -0.010 [-0.026, +0.015] | 22,563.99 |
| Campfire uncached zero units | 99.506223 | -0.020 [-0.046, -0.008] | 93.046583 | -0.044 [-0.068, -0.012] | 22,565.05 |
| Campfire uncached all disabled | 99.506437 | -0.033 [-0.074, +0.017] | 93.067517 | -0.013 [-0.039, +0.019] | 22,563.50 |
| Campfire uncached default | 99.660419 | +0.135 [+0.085, +0.170] | 93.246972 | +0.174 [+0.142, +0.211] | 22,592.52 |
| Campfire uncached + instantiate | 99.388782 | -0.113 [-0.171, -0.092] | 92.974509 | -0.113 [-0.151, -0.075] | 22,455.69 |
| Campfire cached no setup | 17.044085 | reference | 17.044064 | reference | 6,159.35 |
| Campfire cached A/A | 17.036842 | -0.0390 [-0.0563, -0.0016] | 17.040560 | -0.0173 [-0.0466, -0.0072] | 6,158.54 |
| Campfire cached no manifest | 17.062484 | +0.100 [+0.046, +0.155] | 17.057214 | +0.088 [+0.043, +0.201] | 6,158.93 |
| Campfire cached zero units | 17.039935 | -0.031 [-0.049, +0.011] | 17.039076 | -0.016 [-0.053, +0.014] | 6,158.51 |
| Campfire cached all disabled | 17.038020 | -0.024 [-0.051, +0.012] | 17.044273 | -0.004 [-0.036, +0.023] | 6,158.77 |
| Campfire cached default | 17.037746 | -0.028 [-0.053, -0.016] | 17.038956 | -0.033 [-0.050, -0.005] | 6,158.73 |
| Campfire cached + instantiate | 17.058217 | +0.075 [+0.035, +0.092] | 17.060559 | +0.118 [+0.037, +0.211] | 6,158.52 |

**After:** all three experiments pass both A/A gates and the heap checks.

| After app/layer | Total M Ir/request | Total Δ% [95% CI] | GC-excluded M Ir/request | Excluded Δ% [95% CI] | Objects/request |
|---|---:|---:|---:|---:|---:|
| blog no setup | 9.114348 | reference | 9.114436 | reference | 2,358.51 |
| blog A/A | 9.116245 | +0.010 [-0.020, +0.038] | 9.118641 | +0.010 [-0.017, +0.067] | 2,358.24 |
| blog no manifest | 9.113769 | -0.027 [-0.044, +0.008] | 9.114013 | -0.010 [-0.032, +0.009] | 2,358.20 |
| blog zero units | 9.117842 | +0.010 [-0.013, +0.055] | 9.116120 | +0.018 [+0.008, +0.033] | 2,358.35 |
| blog all disabled | 9.111781 | -0.038 [-0.059, -0.014] | 9.112329 | -0.033 [-0.056, -0.007] | 2,357.76 |
| blog default | 8.571585 | -5.959 [-5.983, -5.949] | 8.573076 | -5.950 [-5.966, -5.935] | 2,235.18 |
| blog + instantiate | 8.594770 | -5.728 [-5.746, -5.681] | 8.594305 | -5.713 [-5.744, -5.702] | 2,235.36 |
| Campfire uncached no setup | 99.526772 | reference | 93.083091 | reference | 22,564.51 |
| Campfire uncached A/A | 99.533335 | -0.003 [-0.016, +0.017] | 93.071316 | -0.008 [-0.026, +0.002] | 22,564.16 |
| Campfire uncached no manifest | 99.512512 | -0.018 [-0.031, -0.005] | 93.068327 | -0.013 [-0.030, +0.007] | 22,564.13 |
| Campfire uncached zero units | 99.570279 | +0.038 [+0.009, +0.074] | 93.101260 | +0.033 [-0.002, +0.063] | 22,563.93 |
| Campfire uncached all disabled | 99.488576 | -0.042 [-0.056, -0.015] | 93.054634 | -0.036 [-0.059, -0.017] | 22,563.92 |
| Campfire uncached default | 99.634945 | +0.122 [+0.054, +0.151] | 93.221525 | +0.138 [+0.113, +0.187] | 22,593.03 |
| Campfire uncached + instantiate | 99.402175 | -0.126 [-0.133, -0.102] | 92.943689 | -0.155 [-0.170, -0.119] | 22,458.04 |
| Campfire cached no setup | 17.045931 | reference | 17.048568 | reference | 6,158.87 |
| Campfire cached A/A | 17.039339 | -0.031 [-0.065, +0.012] | 17.044127 | -0.024 [-0.069, +0.012] | 6,158.66 |
| Campfire cached no manifest | 17.055089 | +0.046 [-0.026, +0.109] | 17.050962 | +0.037 [-0.026, +0.109] | 6,158.79 |
| Campfire cached zero units | 17.059574 | +0.050 [-0.008, +0.109] | 17.052948 | +0.050 [-0.019, +0.126] | 6,158.77 |
| Campfire cached all disabled | 17.052515 | +0.042 [-0.030, +0.065] | 17.050499 | +0.041 [-0.025, +0.061] | 6,158.76 |
| Campfire cached default | 17.037368 | -0.045 [-0.110, +0.022] | 17.037540 | -0.054 [-0.114, +0.022] | 6,159.13 |
| Campfire cached + instantiate | 17.046951 | +0.029 [-0.046, +0.081] | 17.047151 | +0.013 [-0.047, +0.047] | 6,158.72 |

Blog's all-disabled overhead shrinks from +0.245% to a tiny −0.038%
residual, not a claim of negative setup cost. Default work falls from
−5.759% to −5.959% relative to off. Campfire uncached's default adds a
small, reproducible +0.122% total / +0.138% GC-excluded work; it does not
complete route specializations on this endpoint (see profiles below).
Cached default and instantiate results are **within noise**. No-manifest,
zero-unit and disabled residuals across the accepted experiments stay below
0.1% in magnitude; the small signed estimates are not meaningful speedups.

The optional instantiate build is compared against off, not against default.
On blog it uses slightly more instructions than default; on uncached Campfire
it changes the sign to a small −0.126% total / −0.155% excluded difference.
A fresh counted probe confirms six instantiate hits/request on blog and
34 hits plus two STI fallbacks/request on uncached Campfire. Cached requests
have no AR work. These source-pinned counts do not establish a native win.

All fixed-heap blog and cached windows have zero minor and major collections
(including every layer and both runtime versions). Every uncached window
with 50 requests has exactly one minor and one major collection: each rate
is 0.020 [0.020, 0.020]/request. In the after total windows, combined
collections/1,000 allocations are 0.001773 [0.001773, 0.001773] off,
0.001770 [0.001770, 0.001771] default, and
0.001781 [0.001781, 0.001781] instantiate. All raw rates/intervals and
minor/major/live/old/allocation endpoints are in the numeric export.
The fixed experiment equalizes phase; these artificial capacities and
50-request rates are not a production steady-state GC prediction.

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

### Observed native results

Five fresh-boot cohorts × eight rotated rounds, 0.6 CPU-second blocks,
400 warmup requests, YJIT on, CPU 2. Values are percent changes relative
to the same-round no-setup worker, median [nominal 95% CI]. Off/off is the
independent A/A control. **All three before controls fail; after, only
uncached Campfire passes.** Failed controls are retained, not rerun away.

| App/layer | Before CPU Δ% | After CPU Δ% | Before wall Δ% | After wall Δ% |
|---|---:|---:|---:|---:|
| blog A/A | −0.02 [−4.07, +5.40] | −0.39 [−2.09, +1.09] | −0.03 [−4.08, +5.73] | −0.39 [−2.11, +1.09] |
| blog no manifest | +1.68 [−3.67, +6.06] | −0.78 [−1.17, +2.38] | +1.68 [−3.66, +6.04] | −0.63 [−1.17, +2.39] |
| blog zero units | +1.46 [−2.41, +3.38] | +0.85 [−2.65, +3.58] | +1.49 [−2.42, +3.35] | +0.86 [−2.65, +3.60] |
| blog all disabled | +16.94 [+3.68, +21.28] | −0.57 [−2.13, +0.68] | +16.94 [+3.85, +21.30] | −0.57 [−2.12, +0.67] |
| blog default | +10.66 [−2.22, +16.80] | +4.64 [−2.95, +8.72] | +10.41 [−2.24, +16.81] | +4.63 [−2.95, +8.73] |
| Campfire uncached A/A | +1.18 [−1.96, +3.07] | +0.59 [−1.64, +1.51] | +1.24 [−1.98, +3.02] | +0.56 [−1.67, +1.49] |
| Campfire uncached no manifest | +14.39 [+6.88, +16.32] | +13.68 [+7.18, +15.20] | +14.37 [+6.92, +16.28] | +13.66 [+7.21, +15.20] |
| Campfire uncached zero units | +0.23 [−5.57, +2.24] | +0.95 [−0.76, +15.66] | +0.09 [−5.56, +2.15] | +0.98 [−0.81, +15.59] |
| Campfire uncached all disabled | −0.26 [−3.32, +3.24] | +10.23 [−1.69, +14.97] | −0.41 [−3.35, +3.21] | +10.08 [−1.70, +14.93] |
| Campfire uncached default | −2.87 [−5.21, −1.01] | +0.64 [−7.30, +4.25] | −2.70 [−5.34, −1.14] | +0.64 [−7.30, +4.20] |
| Campfire cached A/A | +0.36 [−4.75, +7.12] | +0.34 [−2.16, +0.78] | +0.37 [−4.78, +7.13] | +0.32 [−2.12, +0.53] |
| Campfire cached no manifest | +15.00 [+10.11, +25.47] | +15.28 [+12.34, +20.14] | +15.00 [+10.11, +25.62] | +15.30 [+12.35, +20.17] |
| Campfire cached zero units | −6.31 [−6.34, −1.49] | +7.17 [+0.54, +20.11] | −6.36 [−6.38, −1.49] | +7.10 [+0.49, +20.15] |
| Campfire cached all disabled | −4.01 [−9.85, −3.39] | +15.33 [+12.90, +16.79] | −4.04 [−10.25, −3.38] | +15.30 [+12.87, +16.85] |
| Campfire cached default | −6.92 [−11.12, −4.07] | −2.34 [−3.82, +3.62] | −6.96 [−11.13, −4.49] | −2.42 [−3.86, +3.62] |

Baseline off CPU medians before → after are 2,048 → 1,920 µs on blog,
18,642 → 15,849 µs on uncached Campfire and 3,342 → 2,822 µs cached.
These between-experiment shifts are **not** runtime-fix gains. The one accepted
default timing comparison, uncached Campfire after, is plainly **within noise**.
Blog/cached timings remain inconclusive because their A/A gates fail.
No native default-build speedup is established.

Even the accepted uncached native experiment shows +13.68% CPU for setup
with no manifest, despite zero request-time Lowrail calls. Native boot/JIT/GC
sensitivity is unresolved; do not claim universal zero native setup cost
from interpreter instruction counts. The after native AR build was found to
have stale source certificates and silently declined. It is omitted here,
not reported as active AR performance; the primary counter uses fresh builds
and verifies their installation.

## GC and retained-memory diagnosis

```sh
BENCH_COUNTER=gc BENCH_HEAP_DUMPS=1 mise exec -- ruby bench/request_pairs.rb \
  .corpus/real-blog /tmp/blog-memory GET:/articles
# Same headers/cache/AR-build/old-runtime options as above. BENCH_JIT=1 also
# permits a separate native YJIT diagnosis; default is interpreter, 3 rounds.
```

This runs the same layers in independent **diagnostic** workers, not the
instruction/time workers: enumeration and its reports would perturb those
heaps. For each layer/round, one worker boots, warms 50 requests, full-GCs,
and records `GC.stat` before/after 200 requests. Both stat hashes are populated
before that GC; endpoint observation does not allocate a new Hash in the
window. The output keeps absolute endpoints and differences, including
minor/major collections, marking/sweeping time, live slots, old objects and
total allocated objects. No GC is suppressed and no collector cost subtracted.

A second worker records boot and post-warmup full-GC snapshots:
`ObjectSpace.memsize_of_all`, `count_objects_size`, `count_imemo_objects`,
live Ruby `InstructionSequence` wrappers, and Lowrail's manifest/facts/template
containers, class caches and weak-map storage. Within each attribution, shared
and cyclic containers count once; sections overlap and must **not** be summed.
Weak referents, classes and arbitrary object edges are not traversed. This is
bounded ownership evidence, not a dominator/retained-size analysis of the heap.

On Ruby 4.0.7, `memsize_of_all` excludes internal objects, including **all
IMEMOs**, whereas `count_objects_size` includes them. Thus the former is not
the total retained heap. Both are size hints, not RSS; typed native allocations
may be incomplete. ISeq Ruby wrappers are not all VM ISeqs: use
`imemo_counts.imemo_iseq` for the latter. Also, `count_objects_size` counts an
ISeq body's bytes on both its native IMEMO and its Ruby wrapper when one exists.
For native ISeq bytes, sum only heap-dump `IMEMO/imemo_type=iseq` records, not
the `DATA/struct=T_IMEMO/iseq` duplicates. See Ruby's
[size walker](https://github.com/ruby/ruby/blob/v4.0.7/ext/objspace/objspace.c#L59-L69),
[unfiltered category walker](https://github.com/ruby/ruby/blob/v4.0.7/ext/objspace/objspace.c#L179-L184)
and [wrapper size](https://github.com/ruby/ruby/blob/v4.0.7/iseq.c#L1545-L1548).

Optional full heap dumps are emitted only for round-zero off/default memory
workers, after their snapshots. **They can contain credentials and response
data: keep them private, never commit or publish them.** Raw stat/snapshot
results live in `samples.json`; these diagnostics are not latency samples and
do not claim an A/A instruction-control verdict.

### Observed production-heap diagnosis (2026-10-20)

Three independent interpreter workers per layer, 50 warmup + 200 requests,
**without** fixed-heap preparation. Medians below; ranges show all collection
counts. Slots/old objects are thousands. End-window live slots include
uncollected garbage and are **not** retained sizes.

| App/layer | Live slots start → end, k | Old objects start → end, k | Allocations/request | Minor / major GCs in 200 requests |
|---|---:|---:|---:|---:|
| blog off | 297.4 → 381.1 | 284.6 → 297.4 | 2,358.5 | 3 / 0 |
| blog default | 300.6 → 339.1 | 300.6 → 300.6 | 2,235.4 | 7–8 / 0–1 |
| Campfire uncached off | 372.7 → 479.0 | 372.6 → 372.6 | 22,572.8 | 32–33 / 0 |
| Campfire uncached default | 382.7 → 581.2 | 382.6 → 382.6 | 22,596.1 | 17–18 / 0 |
| Campfire cached off | 372.8 → 497.9 | 372.7 → 372.7 | 6,158.8 | 6–8 / 0–1 |
| Campfire cached default | 382.8 → 597.2 | 380.0 → 382.7 | 6,158.3 | 4 / 0 |

Blog allocates **5.2% fewer objects** but collects more often. Campfire's
direction reverses despite almost unchanged allocation counts. Blog's
one-full-GC start leaves about 13k surviving baseline objects not yet old;
the fixed protocol's three full GCs remove that age difference. A separate
pool probe found the default blog heap starting with about 62–65k free
40-byte slots versus 84–94k off; major collection reasons included `nofree`.
Thus short-window collection counts are strongly boot/heap-phase dependent.
They do not establish a guard tax, and old-object age is not retention.

Independent ObjectSpace workers, median decimal MB, off → default:

| App | `memsize_of_all` after boot | After warmup | Warm Ruby ISeq wrappers | Warm native VM ISeqs |
|---|---:|---:|---:|---:|
| blog | 17.730 → 17.937 | 18.022 → 18.215 | 264 → 277 | 40,602 → 40,746 |
| Campfire uncached | 21.106 → 22.290 | 22.200 → 23.397 | 9 → 21 | 49,038 → 49,182 |
| Campfire cached | 21.106 → 22.289 | 22.335 → 23.531 | 9 → 21 | 49,038 → 49,182 |

Boot Ruby ISeq-wrapper counts are 262 → 262 on blog and 5 → 7 on Campfire;
boot native ISeqs are 40,086 → 40,230 and 48,080 → 48,224 respectively.
Separate YJIT-enabled diagnostics give nearly identical retained sizes:
post-warmup `memsize_of_all` is 18.032 → 18.227 MB on blog,
22.599 → 23.794 MB on uncached Campfire, and 22.358 → 23.555 MB cached.
Those native runs are still short-window GC diagnostics, not latency controls.

Warm retained live-object differences are about **3.2k blog / 10.1k Campfire**,
not a second app heap. Both add exactly 144 native ISeqs, rather than
another application-sized set of 40k/49k ISeqs. Largest `count_objects_size` categories
after warmup, off → default, decimal MB:

| Category | blog | Campfire uncached |
|---|---:|---:|
| IMEMO (ISeqs and VM metadata) | 43.519 → 43.788 | 54.097 → 54.478 |
| typed DATA (includes duplicate ISeq-wrapper bodies) | 9.896 → 9.998 | 12.141 → 12.239 |
| Strings | 6.402 → 6.516 | 7.424 → 8.325 |
| Arrays | 5.039 → 5.057 | 5.943 → 5.978 |
| Classes | 3.139 → 3.141 | 3.753 → 3.756 |
| Hashes | 1.833 → 1.870 | 2.064 → 2.291 |

Lowrail's deduplicated manifest container graphs occupy 0.133 / 1.110 MB;
facts account for 0.107 / 0.925 MB of those, chiefly strings and hashes.
Guard's override Hash plus WeakMap shallow storage is 368 bytes in either app;
Compilation's weak-key storage is 192 / 928 bytes and receiver caches
1,216 / 3,224 bytes. Container sections share references: do not add them,
or add the duplicate ISeq-wrapper category, to claim retained bytes.
This is modest genuine retention, not evidence that it explains the much
larger collection-count differences. No retention/runtime GC fix was made.

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
  **1,294.967 → 662.956 instructions/check (−48.805%)**, with less than
  0.02 instruction/check spread within each version. This is a guard micro,
  **not a 49% request speedup**. Late activation, both aliases, two classes,
  invalidation and restoration are regression-tested.

`bench/guard_cost.rb` keeps the micro reproducible. Select the old/new library
with Ruby's `-I`; it reports actual YJIT state. For the instruction micro,
set `GUARD_REQUESTS=100000` and `BENCH_CALLGRIND_EXTENSION` to the shared library
produced by the request counter, then run under the same Callgrind flags.
Divide the client-dump `totals: Ir` by the reported 1,500,000 checks. The tiny
fixed clock/loop seam is included in both versions; emulated CPU time is not
a native time result.

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
cost. The fixed-heap protocol above replaces that confounded short-window
comparison and reports both total and GC-excluded work, with collection
rates. No runtime retention/GC tuning change follows from this diagnosis.

Correctness after both changes, repeated after integrating main's
[AR shadow/epoch changes](https://github.com/thomasklemm/lowrail/commit/d9fd466afac5de38c30ecb5d4b56f475ed4dd840)
with fresh builds: `lowrail verify`, `PARALLEL_WORKERS=1`,
`LOWRAIL_SQL_TRACE=full`, test seed 41231:

| App/build | Identical outcomes | Identical SQL events | Guard/pass hits | Fallbacks |
|---|---:|---:|---:|---:|
| real-blog default | 21 | 125 | 57 / 11 units | 0 |
| real-blog + instantiate | 21 | 125 | 98 / 13 units | 0 |
| Campfire default | 634 (2 skips) | 15,108 | 7,200 / 52 units | 0 |
| Campfire + instantiate | 634 (2 skips) | 15,108 | 9,851 / 65 units | 3,129 / 17 units |

AR fallbacks preserve the pre-existing STI/schema-switch boundaries. The gem
suite passes (84 tests, 1,302 assertions, four optional-dependency/corpus skips),
as do Rust tests (30 unit, one types/MCP integration and two verification
tests) and the benchmark's control tests (8 tests, 43 assertions, including
the Valgrind regression). No hooks or facts were weakened. Hardware PMU
counters and a validated native latency improvement remain unavailable.
