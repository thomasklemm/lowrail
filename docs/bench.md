# Request costs and benchmark method

`bench/request_pairs.rb` isolates Lowrail's setup cost from its enabled passes.
Use the `script/corpus` pins and production database/assets/authentication
setup described in the [Campfire M0](m0/campfire.md). Ruby 3.4+ is required;
these runs use the repository's Ruby 4.0.7. **Callgrind instructions are the
primary work metric; native YJIT CPU/wall time and allocations are secondary.**

## Valgrind brk reservation correction (2026-10-20)

**The ordinary request worker is affected, not only a profiler.** A short
Lowrail-off interpreter diagnostic of the unmodified `bench/heap_requests.rb`
on real-blog-r4 `/articles` (N=2, stock Valgrind 3.19.0) emitted
`brk segment overflow`. All twelve ordinary off-A/off-B workers in the initial
hotspot index attempt emitted it too. This is a reproduced exposure of the
shared worker, **not a retrospective observation of every published cohort**.

On Linux, Valgrind 3.19.0's `ii_create_image` clamps its initial client data
reservation to 1–8 MiB, even with unlimited `RLIMIT_DATA`. In `do_brk`, exceeding
that reservation returns the **old** break; it does not relocate existing heap
memory or resize/reorder our request windows. glibc 2.36 can satisfy subsequent
allocations through noncontiguous `mmap` instead. That changes allocator layout
and potentially its instruction work; passing A/A and Ruby pool-capacity checks
does not prove neutrality. The warning is emitted only once per process, so
absence later in a window is insufficient. `--main-stacksize` is unrelated;
there is no 3.19.0 `--brk-size` option. The upstream manual explicitly prescribes
rebuilding with a larger cap (`manual-core.limits`).

### Historical results: preserve, flag, do not silently remeasure

Published numeric exports below do not retain Valgrind stderr or a complete
tool binary fingerprint, and their original private raw logs are unavailable
in this orb. They used the shared Callgrind path before the overflow check.
**Per-cohort overflow is unverified**, not confirmed absent or confirmed
present. Treat their instruction budgets/deltas as historical stock-tool
measurements with an unresolved allocator-layout caveat. An old “accepted”
verdict means its original gates passed, **not** the new brk gate. Existing
rejections remain rejected. No old number, A/A decision, correctness result or
allocation census is rewritten by this correction.

| Published evidence / documentation | Instruction measurements exposed to the old unchecked path |
|---|---|
| [bench-results.json](bench-results.json), [bench-cli-results.json](bench-cli-results.json) | Blog and Campfire base-cost/archived-runtime/named/stacked/request-budget comparisons, including retained rejections |
| [yjit-results.json](yjit-results.json) | Interpreter controls and all diagnostic YJIT request/guard instruction cohorts; prior JIT/heap/A/A failures still apply |
| [layer-ceiling-results.json](passes/layer-ceiling-results.json), [layer study](passes/layer-ceiling.md) | L0–L3, ordered ablation and L2_events interpreter request counts |
| [endpoint.md](passes/endpoint.md), [endpoint-sections.json](passes/endpoint-sections.json) | Endpoint deficit/composition/quarantine request counts and caller-side section instruction budgets |
| [speculation-ceilings.json](passes/speculation-ceilings.json), [speculation-evidence.json](passes/speculation-evidence.json), [speculation.md](passes/speculation.md) | Guard-elision request ceilings, K comparisons and interpreter/YJIT guard micros |
| [allocations-micros.json](passes/allocations-micros.json) | Conditional form/props/FrozenRecord/DOM instruction micros, not the separate allocation census |
| [importmap.md](passes/importmap.md), [campfire-fragments.md](passes/campfire-fragments.md) | Their Callgrind instruction comparisons/budgets; native timing and census-only observations are not brk-worker measurements |

The confirmed **new**, initial hotspot index attempt is rejected for this
protocol limitation; its partial data is retained, never salvaged as an
accepted cohort. A 512 MiB-tool diagnostic recorded 559 `brk` calls with zero
rejected growth, reaching `0x8b10000` from initial `0x4035000` (about 75 MiB),
and no overflow warning. This validates the correction's mechanism, not the
magnitude/sign of a historical result. Decision-critical old results require
separately authorized, finite new cohorts, not retry-until-green here.

### Pinned 512 MiB tool and refusal gate

```sh
# Toolchain/build work: do not run concurrently with a measurement.
bash script/bench-valgrind /tmp/NEW-valgrind-3.19-brk512
export PATH=/tmp/NEW-valgrind-3.19-brk512/bin:"$PATH"
export CPATH=/tmp/NEW-valgrind-3.19-brk512/include${CPATH:+:$CPATH}
# Retain share/lowrail/valgrind.json with the cohort evidence.
```

[`script/bench-valgrind`](../script/bench-valgrind) verifies upstream
`valgrind-3.19.0.tar.bz2` SHA-256
`dd5e34486f1a483ff7be7300cc16b4d6b24690987877c3278d797534d6738f02`, applies only
[`bench/valgrind-brk.patch`](../bench/valgrind-brk.patch), configures
`--enable-only64bit`, and installs to a **new**, explicit prefix. No system tool
or app/runtime source is overwritten. The manifest records source/patch/tool
SHA-256, compiler and libc; the rebuilt binary SHA is machine/build-specific,
not falsely equated with the source archive SHA. This pin targets Linux amd64.
The change reserves 512 MiB of **virtual address space**, not 512 MiB of live
Ruby objects. Keep `ulimit -d` unlimited; a lower soft limit still constrains
Valgrind's reservation. Ruby's five heap floors and all window/GC/A/A/JIT gates
remain unchanged.

The shared instruction driver performs an untimed app-boot/allocation preflight
under Valgrind before launching a cohort (heap-only for non-Rails operation
fixtures), retains `valgrind-preflight.json` and its logs, and refuses an
overflow or failed probe. Pure synthetic allocations did **not** reproduce
the stock-tool warning; the real blog boot does. Every actual Callgrind worker
log is checked too: an app can outgrow a clean preflight. A warning
rejects the **whole cohort**, regardless of A/A, with the offending log retained.
Explicit verbosity prevents a quiet default from hiding the warning. Never
silence it, change heap floors to evade it, or borrow clean workers from a
rejected batch. Native timing and allocation-only drivers are unchanged.

Validation: a clean-prefix scripted build completed; the stock-tool blog
preflight was refused and the pinned-tool blog preflight passed with matching
manifest/binary SHA. This orb's script-built Callgrind SHA-256 is
`59a6676a349d1ca1e70ddececa704384c2bdf957c189ab8211ab3f89ecb02096`
(not a universal binary hash). `ruby bench/request_pairs_test.rb` passes
**11 tests / 82 assertions** and `ruby bench/pass_test.rb` passes
**16 / 157**, no failures/errors/skips. The new public-driver regression
checks both preflight and worker warnings even when the tool exits 0;
it fails without the fix. No old result was remeasured.

### Decision-critical 512 MiB remeasurement (2026-10-20)

This is a separately authorized **finite recheck**, not a replacement of the
historical exports above. Measured checkout:
[`d7d62ba`](https://github.com/thomasklemm/lowrail/commit/d7d62ba).
**Publication boundary:** the final `pull --rebase` brought in subsequent
runtime work. “Current default” and “final runtime” below mean this measured
snapshot and its recorded fingerprints, **not certification of later main**.
No extra cohort was added after that rebase.
Ruby 4.0.7, Rails 8.1.4, production, the same corpus source pins and **identical
lockfile hashes** as the originals: blog `570c9c31…8596`, Starter
`e1819832…a2fb`. The blog uses its generated three-article/three-comment seed
and precompiled assets; Starter uses `bench/inertia_setup.rb`'s disposable
authenticated JSON `/dashboard` fixture. Cookies are regenerated locally,
never copied into the report. Props source files match final
[`c19ed7c`](https://github.com/thomasklemm/lowrail/commit/c19ed7c), not the
pre-safety-fix runtime in the rejected historical cohorts.

`script/bench-valgrind /tmp/vg` built source/patch pins above, with Callgrind
binary SHA-256
`5c05c41335b887309475b6ba4fc7d1484a1b6bd115c2989b18f06ba9448f3335`.
`PATH=/tmp/vg/bin:$PATH`, `CPATH=/tmp/vg/include${CPATH:+:$CPATH}` and unlimited
data limit apply throughout. Corpus/toolchain setup and app builds finish
before launching cohorts.
Fresh production artifacts include the post-`initialize!` activation change;
props is rebuilt separately for interpreter and YJIT. Endpoint body delivery
uses this checkout's compiler/loader, not an archived unsafe runtime.
These are current-runtime decision checks, **not an isolated causal estimate
of the tool change** (especially final props versus its pre-fix diagnostic).

Each request comparison/mode runs once: six fresh-process rounds, seed 41231,
unchanged five heap floors, both total/GC-excluded windows and the c9d2397
observer/settling protocol, independent A/A required to contain zero within
±0.5%, actual JIT-state checks and the full YJIT-flat gate. No failed worker
or cohort is replaced. Two jobs per shared-driver invocation, at most two
concurrent invocations: **maximum four Callgrind workers**, no native speed
claim. Guard runtimes each get exactly one six-round arm cohort per mode,
sequentially; they cannot share a runtime load path.

The unmodified `endpoint_sections.rb` and `endpoint_bodies.rb` drivers use
N=200 and their original captured two-link specimens; no unrelated operation
is substituted. Props uses `lowrail bench --pass props --path /dashboard`,
`--passes default,+props` at build time, N=50 and 50 initial warmup requests.
The empty current default uses `request_pairs.rb` directly, N=50, on index and
show: the CLI correctly refuses a zero-unit “accelerated” build. This checks
**current default versus off**, not a new measurement of the lost unsafe
default saving. Unlike the old quarantine cohort it uses c9d2397 settling.
L2_events uses the unchanged `blog_ablation.rb` / `blog_eventful.rb` specimen
with only `off_a`, `off_b`, `L2_events` and show selected through the same
`RequestPairs.heap_instructions`, N=50. Its isolated eight body/all-header/SQL
fixture pairs pass; known arbitrary-observer/assigns/mutation omissions stay.

`guard_breakdown.rb` keeps its original `loop,cached` or `loop,inline` cases,
N=100,000, 100,000-call warmup, independent loop/loop A/A and paired subtraction
of each runtime's **own** empty loop. Pre-K `GUARD_LOWRAIL_LIB` is archived
[`560bc64`](https://github.com/thomasklemm/lowrail/commit/560bc64), K is archived
[`690f64d`](https://github.com/thomasklemm/lowrail/commit/690f64d). Measuring
`cached` on today's runtime would not reproduce the old implementation.
The guard driver also gets the shared heap-only tool preflight and a scan of
every worker's combined stderr/stdout for either brk warning; the request
driver retains its real-app preflight and per-worker refusal gate.

The [numeric export](bench-brk512-results.json) retains all six samples per
arm, both metric/control summaries, JIT observations, source/runtime/tool
fingerprints, preflight and worker-log hashes, and the restricted orchestration
sources. Raw Callgrind/heap logs and authentication remain private. CIs below
are nominal round-bootstrap 95% intervals; changes/deficits are paired within
round, not differences of displayed medians. **A/H/J/B** mean both A/A gates,
all five heap checks, actual JIT/warmup/window checks, and preflight plus every
worker's brk-log check, respectively. Historical acceptance never implies
the old brk gate passed. Decisions are assessed in
[DECISIONS.md](DECISIONS.md#512-mib-decision-recheck-2026-10-20).

| Comparison | Historical stock-tool result [95% CI] | 512 MiB-tool result [95% CI] | New controls / verdict | Decision |
|---|---|---|---|---|
| Caller-side combined section checks, two show links | 93,649 vs 90,042 Ir; deficit **+3,607 [+3,441, +3,688]** | 93,649 vs 90,043 Ir; deficit **+3,607 [+3,589, +3,659]** | accepted; A/H/J/B pass | stop still holds |
| Body-installed internal checks, two show links | 94,466 vs 89,729 Ir; deficit **+4,720 [+4,695, +4,814]** | 94,182 vs 89,741 Ir; deficit **+4,419 [+4,337, +4,633]** | accepted; A/H/J/B pass | stop still holds; sealed contract / VM epoch needed |
| Starter JSON props, interpreter | draft **+0.873% [+0.788, +0.956]**, rejected final-runtime certification | final runtime **+4.364% [+4.292, +4.462]**; 5,121,108 → 5,345,304 Ir/request | accepted; A/H/J/B pass | no promotion still holds; larger regression |
| Starter JSON props, YJIT | draft **+0.976% [+0.845, +1.068]**, rejected final-runtime certification | **diagnostic +31.043% [+30.772, +31.104]**; 3,265,733 → 4,279,981 Ir/request | **REJECTED J**, 5/36 workers non-flat; A/H/B pass | no accepted YJIT result; no promotion / no retry |
| Current quarantined default vs off, blog index | −0.006% [−0.037, +0.013] | **−0.062% [−0.084, −0.052]** | accepted; A/H/J/B pass | quarantine holds; “within noise” observation changes |
| Current quarantined default vs off, blog show | −0.004% [−0.033, +0.046] | **−0.004% [−0.086, +0.014]** | accepted; A/H/J/B pass | quarantine and unresolved-from-off observation hold |
| L2_events show vs L0 | −37.287% [−37.316, −37.247] | **−37.297% [−37.323, −37.282]**; 8,748,023 → 5,484,235 Ir/request | accepted; A/H/J/B pass | large upper bound holds; not semantic certification |
| Guard old cached → K, interpreter, net Ir/check | 822 → 425 | **822.005 [822.005, 822.005] → 425.004 [425.004, 425.004]** | both arm cohorts accepted; A/H/J/B pass | shipped K decision holds; no request-win claim |
| Guard old cached → K, YJIT, net Ir/check | 371 → 140 | **371 [371, 371] → 140 [140, 140]** | both arm cohorts accepted; A/H/J/B pass | shipped K decision holds; no native-speed claim |

**No optimization decision flips. Changed observation:** current default is
still near off in magnitude, but index is **not statistically unresolved
from off** in this cohort. Its small resolved saving is not credited to an
accelerated source pass: the fresh default manifest has zero units. Show
remains unresolved. This does not remeasure the unsafe pre-quarantine saving
or justify reactivation. The body cost subtracts the measured unchanged-ISeq
delivery increment, +2,782 [+2,635, +2,819] Ir, before pricing guards; that
increment remains unattributed. Both endpoint prices still omit additional
certificate work, not just its runtime implementation.

Props' counted probes have **4 hits/request, 0 fallbacks** in both modes.
All 36 YJIT workers reach the three-flat-window warmup, but `0-disabled`,
`0-missing`, `1-disabled`, `1-off_a`, `3-off_b` compile respectively
21 / 18 / 18 / 4 / 2 extra blocks inside a measured window (no extra ISeq or
invalidation). **The whole cohort stays rejected**, even though the enabled
arm is flat; no clean-arm salvage. The old two fingerprint-rejected cohorts
also stay rejected. Deterministic guard costs yield point bootstrap intervals
across six identical net slopes; that is not a universal uncertainty bound.

The export audit independently recomputes raw-window slopes and paired
estimates/CIs: **11 finite cohorts / 294 Callgrind workers; 10 accepted,
one rejected (props YJIT); all eight distinct preflights and all worker brk
checks clean**. No cohort was rerun, and no runtime/pass/default changed.

## Shared command: `lowrail bench`

**Current quarantine:** the default selection is empty. A default-only build
correctly rejects `lowrail bench --pass default` with `no units`, rather than
claiming acceleration. Explicit route/link-to selectors and old artifacts are
also refused. The examples below describe the measurement protocol; use an
available opt-in build for active-pass measurements. The before/after loss
experiment uses `request_pairs.rb` with an archived pre-quarantine runtime,
as recorded in [endpoint quarantine](passes/endpoint.md#quarantine-cost-and-gates).

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

`--speculate unguarded` adds a **measurement-only unsafe** layer to the
fixed-heap Callgrind experiment (`--pass default` or a named pass). It first
runs the ordinary strict guarded preflight and coverage probe, then recompiles
a disposable snapshot with the selected generated source guards elided.
All build units must be selected: named passes need their own single-pass
build, not a guard mask over a mixed build. Otherwise the partial bypass
changes the cost of unselected sites and is not an isolated guard ablation.
Live argument/type/scope predicates remain. Runtime passes bypass shared
method facts and the instantiate epoch but retain dispatch and pass-specific
structural checks: this is not a zero-overhead runtime-pass ceiling.
The unsafe snapshot has an incompatible manifest marker; only the
ancestry-checked source-checkout experiment accepts it. Never deploy it.
Every guarded/original/off worker explicitly clears both unsafe ENV variables.
The unsafe layer gets its own full preflight and activation/JIT probe; all
ordinary A/A, heap and provenance checks remain mandatory. `request.guard_tax`
retains paired guarded-minus-unsafe Ir/request and percentages (including
negative estimates). `measurement_complete` remains false. This mode cannot
combine with stacked budgets, native timing or other comparison layers.
See [the speculation study](passes/speculation.md) for results and limits.

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

`LOWRAIL_JIT_DIAGNOSTICS=1` additionally saves process-wide JIT counters in
`coverage.jit_diagnostics`, **only in the untimed activation probe**. The flag
is cleared in timed request workers and micro probes. No new stats flags or
gate exceptions are introduced; unavailable per-ISeq counters/ratios are null.
See [scope and limitations](jit-shapes.md#diagnostic-counters-never-gates).
The reproducible Ruby version axis is `mise exec ruby@VERSION -- ...`; 4.0.7
remains the default. The [4.1 preview column](ruby-4.1.md) passes the five-app
correctness prerequisite with disposable dependency overlays.
`BENCH_JIT=zjit` selects a **diagnostic-only fixed-heap Callgrind mode**;
`0`/`interpreter` and `1`/`yjit` retain their existing meanings.
Both actual JIT enablement states are recorded and checked, including Rails'
late YJIT activation. Native and legacy-counter ZJIT modes refuse explicitly.
The preview exposes no invalidation count: the ZJIT flat gate therefore
**rejects with `missing_counters: ["invalidation_count"]`**, rather than
equating flat invalidation time with no invalidations or inventing zero.
Compilation counts, generated exit-stub counts and compile/invalidation times
are retained as observations, never substituted for the missing count.
Three flat warm windows, every measured window, A/A, heap and brk controls
remain mandatory. ZJIT cannot promote a pass even if a later VM supplies the
missing counter.

Ruby 4.1 preview has **12 pools** (32–1024 bytes), not 4.0's five (40–640).
Heap preparation and matching cover every actual pool. Defaults retain the
published slot floors by size band: ≤40 bytes: 1M; ≤80: 250k; ≤160: 100k;
≤320: 20k; larger: 10k. Thus 4.0's defaults are unchanged. An explicit
`BENCH_HEAP_SLOTS` must provide one positive floor per actual pool. The
32-byte pool uses Object fillers; the others use embedded Arrays. Capacity
matching still allows at most one page per pool, never an ignored new pool.
Observer prewarm also runs the exact pool-loop ISeq used at both endpoints.
The 12-pool regression caught that loop compiling in the third window:
compiled ISeqs 21 → 23, blocks 176 → 188, with unchanged workload. A shared
endpoint observer warms that code outside all windows; the gate is unchanged.

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

### Stacked pass sets

Many sub-2% passes may add up to a worthwhile set. `--passes SET` is mutually
exclusive with `--pass NAME`, uses the build selector's aliases/groups/modifiers,
and adds a **stacked** layer alongside no-setup, independent off/off A/A and
a **separate default reference**. `all-opt-in` selects every registered pass,
including defaults, in both `build` and `bench` through the same selector.
Passes without eligible units stay listed in the selection
but contribute no measured coverage; selecting them is not a support claim.

```sh
app=.corpus/real-blog-r4
RAILS_LOG_LEVEL=error SECRET_KEY_BASE_DUMMY=1 mise exec -- \
  target/debug/lowrail build "$app" --env production --passes default
cp -a "$app/.lowrail" /tmp/blog-default-build # NEW directory
RAILS_LOG_LEVEL=error SECRET_KEY_BASE_DUMMY=1 mise exec -- \
  target/debug/lowrail build "$app" --env production --passes default,+ar_instantiate
mise exec -- target/debug/lowrail bench "$app" \
  --passes default,+ar_instantiate --default-build /tmp/blog-default-build \
  --path /articles --out /tmp/blog-stack
# Add --budgets /absolute/budgets.json for the per-hit/additivity comparison.
# With a matching build, also accepted:
# --passes default,+ar_instantiate,+inertia/config_bind
# --passes all-opt-in
```

`--default-build` points at the saved **.lowrail directory**, not its parent.
Both complete builds get strict source/certificate, activation, actual-JIT and
end-of-run fingerprint checks. The reference must contain only registry-default
passes, from the same app. Build it with `--passes default`; the manifest does
not yet certify which absent sites the builder refused. The stacked build must
contain no unselected passes. Masking their guards is **not** sufficient: emitted
fallback sites and optional runtime wrappers still cost instructions. The
reference and stack are copied privately; the app's build is never renamed or
edited by bench. Other extra-build/archived-runtime/app-fix layers cannot be
combined with stacked mode. All existing A/A and fixed-heap gates apply to
**every** layer, unchanged; native runs retain five independent boot cohorts.

#### Multi-unit/model expected budgets

`--budgets FILE` imports independently measured, guard-included operations,
not a percentage fitted to the request result. Schema 1 contains:

```json
{
  "schema_version": 1,
  "manifest_sha256": "exact stacked manifest digest",
  "runtime_fingerprint_sha256": "exact runtime digest from result.json",
  "request_context_sha256": "exact private-header/cache/route digest from result.json",
  "route": "GET:/articles",
  "metric": "instructions_total",
  "yjit": false,
  "units": [
    {
      "id": 11, "pass": "active_record/instantiate", "model": "Article",
      "guard_included": true, "source": "path to measured operation/counter evidence",
      "hits_per_iteration": 20,
      "samples": [
        {"off_a": 1000, "off_b": 1000, "on": 960},
        {"off_a": 1000, "off_b": 1000, "on": 961},
        {"off_a": 1000, "off_b": 1000, "on": 959},
        {"off_a": 1000, "off_b": 1000, "on": 958},
        {"off_a": 1000, "off_b": 1000, "on": 962},
        {"off_a": 1000, "off_b": 1000, "on": 960}
      ]
    }
  ]
}
```

**Format illustration only; these are not measured corpus numbers.** Add one
entry for each unit/model/operation being modeled, with distinct IDs; never
reuse Article's price for Comment. Operation values are **per iteration**, in
the named metric. `(off_a − on) / hits_per_iteration` gives saved cost per
completed hit, including its guard. The denominator comes from a separate
counted operation, never inferred from row count or iterations alone. Keep
negative savings. `source` identifies reviewable raw evidence, including heap
controls for instruction micros; a label is provenance, not proof supplied by
this importer. The importer recomputes every operation's A/A CI: contains zero
and inside ±0.5% for instructions or ±2% for native µs. Failed controls reject
the whole run rather than silently dropping unfavorable models.

Every entry's sample array needs at least six **independent replicate
measurements**, with equal array lengths aligned across operations. A shared
control must use the same replicate index. The tool resamples those vectors
together, not each unit independently, then sums individual median expectations.
For native inputs, use independently booted samples, not within-boot blocks.
Metric, manifest, runtime, request context and **actual** JIT must match.
Instruction totals, GC-excluded instructions and native CPU/wall µs are distinct
metrics. Fingerprints are exposed in any result for the unchanged build;
budgets are copied into the final JSON, so later input edits cannot rewrite it.
Request context fingerprints bind completion frequencies to the route, private
authentication headers and Campfire cache setting without publishing headers.

Known runtime completion counters supply hits/request from the warmed coverage
probe. Source guard counts do **not** certify completed specializations: source
budgets must additionally supply `completed_hits_per_request_samples`, aligned
with their operation samples and collected separately on this exact route.
Runtime budgets may also supply these samples when frequency varies. Otherwise
the report conditions its uncertainty on the observed ten-request frequency;
it does not infer a population CI for request frequency from a constant count.

The short table and `result.stack` report signed measured saving versus
**no setup** and **default**. The expected sum against no setup includes all
supplied budgets; the incremental sum against default includes only opt-in
budgets, not the default savings a second time. Default-work frequency changes,
setup cost, overlap and unmodeled operations remain in the residual. Thus
`measured_minus_expected` is an additivity diagnostic, **not** an automatic
attribution of all unexplained work to interactions. Its CI independently
resamples request rounds/boot cohorts and the joint budget vectors; adding CI
endpoints or arbitrarily pairing unrelated experiments is not valid.

Without budgets the real request comparison still runs, but the expected sum
is **unmodeled**, never zero. Missing hit units are enumerated and partial
budgets keep `measurement_complete: false`. Removing default passes also marks
the default reference's removed work as unmodeled, not as an opt-in gain.
Fallback-only units (for example Campfire's STI Room loads) are separately
listed as unpriced; zero fast-path hits do not make their guards free. These
also keep the budget partial, even if all successful-hit units have prices.
The importer does not convert old unguarded timings into valid inputs.
Nominal bootstrap CIs still understate independent run-to-run variance; inspect
controls and repeat evidence before promotion, not just a narrow interval.

#### Capturing genuine instruction budgets

Add `--measure-budgets` instead of `--budgets FILE` to generate the input with
the same fixed-heap Callgrind runner. Automatic generation requires interpreter
Callgrind. Both single-pass and stacked reports accept budgets; a single pass
compares its enabled `default` arm against no setup, without a separate
default-build reference. Stacked mode still requires that reference:

```sh
BENCH_MICRO_ROUNDS=12 mise exec -- target/debug/lowrail bench "$app" \
  --passes default --default-build /tmp/blog-default-build \
  --measure-budgets --path /articles --out /tmp/blog-default-budget
```

The operation worker warms the real request and captures its actual receivers,
arguments, locals, lexical scope and `CurrentAttributes`. Rails clears ambient
request attributes after completion; replay restores the captured context
outside each unit's measured windows. A memo may run before the controller
populates `Current`, while a route runs afterwards; each retains its own
context. Different contexts within one unit are refused rather than silently
replayed under one snapshot. Live-request and
replay completion counts must agree; returned values must also match the actual
captured result, not just each other. Replay closures contain the guarded expression
or original expression, not counting/capture wrappers. Route and link sites,
`memo/uri_join`, `memo/sha256`, and `digest/file_memo` use this source capture;
file captures must reproduce the delivered ISeq before instrumentation.
Both direct guards and the newer receiver-class `Lowrail::K` prefix are parsed;
the prefix remains in the measured expression, including hot and cold checks.
Capture is installed after `config/boot` locks gems but before
`config/application` can load targeted gem methods. Booting first would miss
already-loaded methods such as `RailsVite::Manifest#version`.
Instrumentation is worker-local and never modifies an app or its build.
There is no TracePoint: constructing one would disable memo reuse. Nested
route lowering is removed from the link operation price, then priced separately
at its actual post-link request frequency, avoiding double-counting.

`inertia/config_bind` replays the installed variant and its `super_method`
against the real controller/configuration. Both arms use `Method#call`, so
they pay the same dispatch adapter. The operation includes the
variant's full guard; no runtime registry hook or private activation is added.
Original/on values are compared before timing. Separate counted calls establish
completed hits, and stats are restored before measurement.

`sealed/form_scaffold` captures the actual ERB block/view at its certified
source site using a temporary worker-local helper method, removed before
replay. No TracePoint or capture callback runs in the measured operations.
Both original and installed-variant arms use `Method#call`, the real captured
block and a fresh `Comment.new`/model array on every invocation. The full
production predicate remains in the variant. Real masked tokens are decoded
and validated independently against their emitted action/method before
normalizing their mask for the untimed bytes/safety/encoding comparison.
Request and replay completion counts come from the runtime's actual stats.

`BENCH_OPERATION_CHECK=1` runs the operation worker's native equivalence and
count checks, then exits with `untimed:true`, without a Callgrind extension or
measurement windows. This validates capture, **not** a numeric budget. After
worker authorization, an interpreter-certified sealed artifact can be priced
with `LOWRAIL_SEALED=1 lowrail bench APP --pass sealed/form_scaffold
--measure-budgets --path /articles/1 --out NEW_DIR`. All existing request,
per-operation A/A, heap, mode, provenance and completion-mix gates still apply.
Only a fully modeled accepted new run can set `measurement_complete:true`;
adding the adapter never retroactively completes a historical request cohort.

Runtime facts must be built for the measured JIT state too. On Ruby 4.0,
enabling YJIT replaces native `Array#each` with an internal Ruby method;
Inertia's exact constructor facts legitimately distinguish these. For an
interpreter instruction build, use:

```sh
LOWRAIL_BUILD_JIT=0 RAILS_LOG_LEVEL=error SECRET_KEY_BASE_DUMMY=1 mise exec -- \
  target/debug/lowrail build .corpus/react-starter-kit --env production \
  --passes default,+inertia/config_bind
```

This optional runtime-builder hook disables `config.yjit` **before** boot,
rejects a boot that nevertheless enabled YJIT, and certifies the actual methods.
Unset behavior stays unchanged. It does not edit facts, mask a failed guard,
or make interpreter and native-YJIT budgets interchangeable. Build a normal
production manifest again before native measurement/deployment.

All three arms boot the **same active build**; off_a/off_b replay original
operations and on replays guarded operations. Six independent rounds are the
minimum (`BENCH_MICRO_ROUNDS`); request rounds remain separately controlled.
`BENCH_MICRO_ITERATIONS` defaults to 200 operation iterations per window,
independent of whole-request `BENCH_REQUESTS`. Small operations need longer
windows than requests; changing this count never relaxes the A/A gates.
Every operation must pass both total and GC-excluded A/A gates, not just their
aggregate. All five actual heap capacities must match under the existing gate.
Raw windows, counts, controls and generated schema-1 input are saved under
`budgets/`, including when rejected. The harness fingerprint is checked too.

Successful guards are not necessarily completed specializations. If every
captured invocation completes, the adapter reports instructions/hit. Otherwise
it explicitly uses `count_kind: invocation`, `invocations_per_iteration` and
aligned `invocations_per_request_samples`, while retaining separate
`completed_hits_per_request_samples`. The resulting price includes guarded
fallback attempts; it must not be labeled a completed-hit saving. A negative
price remains a cost. The same importer accepts this explicit invocation basis
and rejects completion counts exceeding invocation counts.
If replay's completed/invoked mix differs from the actual warmed request,
the unit is unmodeled with a reason: warming a captured cache input cannot
stand in for genuine misses on changing request inputs.

The context-validated blog default budget (Ruby 4.0.7, actual YJIT off,
12 independent operation rounds, six request rounds, N=0/10 in both and
50 warmups, runtime pinned to
[491ea27](https://github.com/thomasklemm/lowrail/commit/491ea2771624464ff420672c0a8bcd8688d97346),
before the K-prefix lowering) models all four exercised units. Guard-included savings are
44,318 and 37,136 instructions/link hit (9 and 1 hits/request), and 10,448
and 3,716/route hit (9 and 1). Their sum predicts **533,746**
instructions/request [533,426, 534,239]; the request saves **538,901**
[534,825, 542,234]. Measured minus expected is **+5,154** [918, 8,542],
not zero: a useful additivity residual, not a fitted identity. Identical
default/reference builds give +1,581 [−3,692, 3,798] saved instructions against
one another, consistent with no incremental effect. Per-unit and request A/A
and all heap gates pass. These N=10 measurements precede the separate default
of 200 micro iterations; raw provenance retains their actual counts.

The earlier six-round blog micro is retained **rejected**: aggregate A/A and
heaps pass, but one link site's individual A/A interval exceeds the ±0.5% gate.
The twelve-round experiment does not erase that result or imply that bootstrap
intervals cover all independent run-to-run variance.

A fresh K-prefix default build at
[8e23fa2](https://github.com/thomasklemm/lowrail/commit/8e23fa23f25c213db02a1671a6efb65c31ab8aa4)
also passes all per-unit/request A/A and heap gates: twelve micro rounds at
N=200 predict **545,244** [544,575, 546,185] saved instructions/request;
six request rounds at N=10 measure **548,821** [545,019, 551,180]. The
residual is **+3,577** [−221, 6,048]. All four exercised units are modeled;
this is a new measurement, not a replacement for the pre-K record above.

Campfire uncached initially exposed why replay context is checked: its seven
successful route guards complete **zero** optimized routes inside the request.
Without restoring `CurrentAttributes`, a replay after executor cleanup would
falsely complete them. That experiment is quarantined, not a hit budget.
The corrected N=10, twelve-round experiment is also retained **rejected**:
unit 16's GC-excluded A/A CI is [−0.552, +0.090]%, outside ±0.5%, although
aggregate controls, the other units and heap capacities pass. This motivated
decoupling micro iteration count from request count, not widening controls.

With N=0/200 operation windows (twelve independent rounds) and N=0/10 request
windows (six rounds), uncached Campfire default on the same pinned runtime passes every operation/request
A/A and heap gate. The seven fallback attempts cost **195,151**
[194,741, 196,175] instructions/request; the measured request cost is
**197,068** [134,750, 283,036]. Signed measured saving minus expected saving
is **−1,917** [−87,633, +60,169], consistent with the budget. Both completed
hit counts stay zero. All exercised work is priced (`measurement_complete`
true), but this is a measured default-route **cost**, not a route-speed claim.

Starter `/dashboard`, `default,+inertia/config_bind`, uses a rebuilt interpreter
certificate and the **real registry**, not the old private activation shim.
Twelve operation replicates give **45,613** [45,535, 45,794] saved
instructions/completed bind × **5 binds/request** = **228,067**
[227,676, 228,971] expected. Six request replicates, N=0/10 and 50 warmups,
save **230,259** [222,219, 234,287] against default. The residual is
**+2,192** [−5,795, 6,060], consistent with the operation budget.
Against no setup, saving is **226,699** [222,612, 235,344], residual
**−1,368** [−5,596, 7,118]. All request/operation A/A and heap gates pass;
`measurement_complete` is true. This is instruction-work evidence, **not a
native-YJIT speed or automatic promotion claim**.

The public `fixtures/digest-app` also exercises the real file-digest adapter:
copy `public/vite-test/manifest.json` to `public/vite/manifest.json` for its
production build, and use `HTTP_X_INERTIA: true` with
`HTTP_X_INERTIA_VERSION` equal to that manifest's MD5. On runtime
[8e23fa2](https://github.com/thomasklemm/lowrail/commit/8e23fa23f25c213db02a1671a6efb65c31ab8aa4),
six micro rounds at N=200 and six request rounds at N=10 pass all A/A and heap
gates. Seven completed hashes/request cost **12,215** [12,199, 12,246]
instructions/hit: expected saving **−85,506** [−85,721, −85,393], measured
**−84,891** [−87,087, −82,938] against default, residual **+615**
[−1,526, +2,568]. The tiny asset manifest makes memo validation more expensive
than hashing. This is complete **negative fixture evidence**, not a corpus
speed claim. No digest site is lowered on the measured Campfire workload.

The current-K Campfire `default,+memo,+digest_memo` capture confirms two
`memo/sha256` completions/request, before the controller populates `Current`.
Its twelve-round experiment is **rejected before request measurement**:
aggregate and memo A/A plus heaps pass, but route units 21 and 59 have total
A/A CIs [+0.0303, +0.1768]% and [+0.00795, +0.1240]%, excluding zero.
There is no accepted measured-vs-expected memo-stack claim from that run.
An earlier memo stack failed request A/A; neither is retried to green or
silently counted as complete. URI joins on this workload retain 22 builder
refusals (11 call certificates, 10 method certificates, one regexp timeout);
there is no exercised URI-join or digest operation to price on Campfire.
Sanitized scalar samples, unit counts, controls, runtime/harness fingerprints
and accepted/rejected verdicts are retained in
[`bench-cli-results.json`](bench-cli-results.json), under `genuine_budgets`.

#### Stacked CLI validation

Fresh production `default,+ar_instantiate` runs on 2026-10-20, on the runtime
at [6f9e27a](https://github.com/thomasklemm/lowrail/commit/6f9e27ad2f986671d21c9d843c89ea9d43268bc9)
before migration step 4: Ruby 4.0.7, **actual YJIT off**, six independent
fixed-heap rounds × seven layers, 50 warmup and N=0/50 windows in each mode.
Both total/GC-excluded A/A controls and all five heap gates **passed on both
apps**. Default references are actual separately built default-only snapshots.

| App / total instructions | Default vs no setup Δ% [95% CI] | Stack vs no setup Δ% [95% CI] | Stack vs default Δ% [95% CI] |
|---|---:|---:|---:|
| real-blog `/articles` | −5.954 [−5.986, −5.911] | −5.393 [−5.463, −5.370] | +0.588 [+0.535, +0.604] |
| Campfire uncached room | +0.136 [+0.055, +0.196] | +0.067 [+0.037, +0.100] | −0.066 [−0.142, +0.026] |

Blog's stack saves 492,646 total instructions/request against no setup, but
**adds 50,440** relative to default. Campfire saves 66,216 against default
(CI −26,143 to +141,506 saved), while adding 66,598 against no setup. These
are not an incremental ≥2% win. GC-excluded stack deltas against default are
blog **+0.592%** [+0.546, +0.631] and Campfire **−0.125%** [−0.163, −0.073].
Instruction results are not native YJIT speed claims.

Blog completes three Article and three Comment instantiations/request.
Campfire completes 34: Account 5, ActionText::RichText 10, Boost 2, Message 10,
Session 1 and User 6; its two Room STI rows remain fallbacks. No model borrows
another model's price. **Comparable per-hit instruction inputs are absent**,
so these corpus runs deliberately report expected sums as unmodeled and
`measurement_complete: false`, not invented additivity evidence.

The current reporter and paired estimators replay both retained sets of raw
samples exactly. Deterministic multi-model tests independently check signed,
fractional prices, shared-control covariance, partial/zero-budget distinction
and native whole-boot uncertainty. Synthetic arithmetic/table smoke checks
are labeled as such, not published as corpus prices. A deliberately +10%
integer-valued budget A/A is **rejected**, preserving its raw input; so is an
optional build mislabeled as the default reference. Wrong JIT, metric, model,
request context and stale budget fingerprints are also rejected by tests.
Retained estimates, controls, heap bounds, per-model counts and round samples:
[`bench-cli-results.json` → `stacked`](bench-cli-results.json).

That earlier AR batch preceded the runtime registry. Real-registry Starter
`+inertia/config_bind` activation and its genuine budget are now validated
above; the benchmark does not bypass activation with a private hook.

### Remaining per-pass adapters

The shared command supersedes `ar_cached_runs.rb`, `preload_runs.rb` and
`memo_runs.rb` (removed), plus the instantiate request/micro branches. Repeat
the prepared paths/formats with their private `BENCH_HEADERS` and cache
settings instead of adding per-pass orchestration. Operation workers
`ar_cached_reader.rb`, `ar_instantiate.rb` and `preload_paths.rb` remain the
shared native adapters. Historical tables retain their original protocols;
new results use the shared controls. Still per-pass:

| Pass/tool | Remaining work, not supplied by the shared driver |
|---|---|
| route/path, view/link_to | shared `--measure-budgets` captures guarded emitted operations; `routes.rb` remains an unguarded diagnostic and is not imported as a guarded saving |
| memo, digest | shared source capture supplies guarded replay and separate completion counts; cache population/eviction and changing inputs still require workload-specific interpretation; `memo_check.rb` and digest fixtures remain diagnostic recipes |
| inertia/config_bind | shared real-controller variant/original replay; not a synthetic configuration or an unguarded builder timing |
| preload | mixed-query/result budgets; format/cache request sweeps use the shared command per prepared path, and the narrow native micro uses its shared controls |
| AR instantiate | per-model/row-shape budgets; do not apply one model's saving to another model or STI fallback; `ar_instantiate_runs.rb` retains only the internal-cost/StackProf breakdown (not a pass gate) |
| AR plans | reader selection, completion frequency and cold/missing-attachment interpretation; `ar_plans_runs.rb` is a diagnostic implementation comparison, not an installed-pass gate |
| new passes | attest runtime activation and add an operation adapter after defining a genuine completed-hit counter; shared request, rejection, A/A and report machinery needs no new copy |

For a new **native** operation adapter, retain the original method/fallback
and guard in the timed operation. Write `BENCH_JSON` as rows with `case`/`us`
(or `route`/`us_per_req`); snapshot `PassProbe.counts` before timing and attach
`PassProbe.sample(iterations, before)` after timing for the separate counted
worker. Register the operation in `PassBench.micro` and attest activation in
`PassProbe.active!` if it is a runtime pass. The shared driver supplies the
fresh workers, actual-JIT check, A/A, hit denominator and budget.

For an **instruction** operation adapter, use the existing shared seam rather
than copying the heap/counter protocol:

```ruby
# Worker, after app boot, activation/JIT checks, warmup and untimed counting:
windows = HeapWindows.windows(n, operation_ids)
anchors = HeapWindows.run(windows) do |count, id|
  count.times { operations.fetch(id).call }
end
# Print LOWRAIL_BENCH JSON: ruby, actual yjit, windows, heap_anchors,
# and operations keyed by unit ID with invocation/completion metadata.

# Driver, with independent off_a/off_b/on environments:
RequestPairs.heap_instructions(environments, app, out, route, metadata,
  worker: "your_worker.rb", requests: n)
```

Require `heap_windows.rb` and `ENV.fetch("BENCH_CALLGRIND_EXTENSION")` in the
worker. `metadata` contains `seed`, `rounds` and an initially empty `workers`.
The worker's `n` comes from the driver's `BENCH_REQUESTS`; the `requests:`
keyword overrides its default without changing whole-request experiments.
The worker path may be absolute (for a scratch experiment) or relative to
`bench/`. Optional `HeapWindows.run(windows, prepare: callback)` calls
`callback.call(unit_id)` before the full GCs and client window, for restoring
ambient context without charging it to the operation.
The driver provides the five pool floors and alternated total/GC-excluded
phases, subtracts N−0, and retains per-unit metrics under each sample arm's
`operations`. It enforces aggregate A/A and heap gates; additionally require
**every unit's** total/GC-excluded A/A, as `instruction_budget.rb` does.
Allocation/GC diagnostics sum the full windows for all operation IDs, not
just the first. Zero-allocation comparisons retain absolute counts, with
undefined percentage changes and GC-per-allocation rates encoded as `null`.
Counters, capture wrappers and fallback-equivalence checks stay outside client
windows. Experimental fixtures are diagnostics, not installed-pass coverage.

There is **no built-in callback-chain/compiled-template operation adapter
yet**. Add that operation boundary to the shared Callgrind runner
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
bash script/bench-valgrind /tmp/NEW-valgrind-3.19-brk512
export PATH=/tmp/NEW-valgrind-3.19-brk512/bin:"$PATH"
export CPATH=/tmp/NEW-valgrind-3.19-brk512/include${CPATH:+:$CPATH}
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
compiler. It is not a steady-state comparison. The gated mode below supersedes
that diagnostic; historical interpreter results remain interpreter results.
Neither interpreter nor YJIT instructions are native latency claims.

### Quiescent YJIT instruction mode

`BENCH_JIT=1 lowrail bench ...` uses the same fixed heaps, N=0/50 subtraction,
six fresh-process rounds and unchanged total/GC-excluded A/A gates. The
historical method, retained for all older cohorts, warmed **before** heap
preparation in 200-request windows until
`RubyVM::YJIT.runtime_stats` reports **all three** of `compiled_iseq_count`,
`compiled_block_count` and `invalidation_count` unchanged for **three consecutive
windows**. Three full GCs precede each observation. Warmup is bounded at 20,000
additional requests; hitting the limit without convergence rejects the cohort.
The full counter history, including unsuccessful warmups, is retained.

#### v2 declaration: prepared heap, idle boundary, 2,000 quiet requests

This is a **new measurement method**, declared before its one finite off/off
A/A validation. Old rejected cohorts remain rejected and are never re-scored.
The single validation below passes; this is not a pass/default promotion.
The declared validation is Ruby 4.0.7 / Rails 8.1.4 blog `GET:/articles/1`,
two identical no-setup/off arms, six fresh-process rounds, seed 41231, N=50,
alternating total/no-GC phase order, the existing 1,000,000 / 250,000 / 100,000 /
20,000 / 10,000 heap floors and 0.5% A/A tolerance. Use the pinned 512 MiB
Valgrind below the four-worker cap, with no call-threshold/config change,
one cohort and no retry. Pin the published method SHA and source fingerprints
before launch; retain a failed result just as completely as a passed one.

The retained config/link cohorts have 17 non-flat workers (10/24 Starter,
6/36 blog index, 1/36 show). All 17 changed windows have zero measured GC,
compaction and invalidation deltas; 14 add blocks without a new ISeq. They
did not log compilation identities, so those counters do not identify sites
or establish worker-order causality. New **untimed native** compilation-log
probes (`--yjit-log`, drained with `RubyVM::YJIT.log`) on all three routes
find no late framework/app targets in an immediate 5,000-request tail. A
separate deliberate 65-second idle test compiles two targets on **request 1
after the pause**, in each app: AR 8.1.4 `abstract_adapter.rb`, block in
`with_raw_connection`, bytecode indexes **83/87**, source lines **1075/1076**.
These are the aged/unverified-connection branch, not a cold method crossing
its call threshold; effective `verify_timeout` is 2 seconds in these fixtures.
This proves an elapsed-time lazy-target mechanism, **not** the identities of
all old failures. Logger/introspection-loop compilations are not app evidence.
The logs identify no additional cache-expiry/session/CSRF/time-policy targets;
no wider time-dependent-behavior claim or speculative app change is made.

The standard request worker now follows this sequence:

1. Boot/eager-load and issue the ordinary 50 initial requests; prepare the
   fixed heap and warm the exact endpoint observer/clock signatures.
2. Read effective timeouts from already-open AR connections, idle longer
   than their maximum (2.05 seconds for these fixtures), then issue one
   request to exercise the aged branch. Do not change a timeout or YJIT option.
3. Only **after** that step certify at least **2,000 consecutive quiet
   requests**, in 200-request batches (ten flat observations). Every compile
   or invalidation resets the quiet streak. The cap remains **20,000**;
   missing counters/cap exhaustion are fail-closed, with history/stop reason.
   Larger configured batches still require at least three flat observations.
   Each batch exercises the zero-work endpoint too: the public operation
   regression and an untimed compilation log caught Integer#times' lazy
   zero-iteration exit at bytecode index 38 otherwise compiling in N=0.
   These zero-work calls add no requests to the count or quiet-budget claim.
4. Preserve three full GCs and the symmetric settling request before each
   N=0/N=50 total/no-GC window. All original JIT-flat/A/A/heap/brk gates remain.

`jit_warmup.method=quiet-2000-v2` plus
`stage=post_heap_observer_idle` records this request protocol. Captured-operation
workers also certify after preparation, but preserve their captured context;
they do **not** issue an unrelated idle/settling request. Bespoke historical
experiment scripts are not certified as the new request protocol just because
they call the longer quiet-streak helper.

There are **no trace hooks in measured workers**. Monotonic nanosecond stamps
are recorded before/after the last pre-window request, at window start and at
window end, strictly outside the instruction region. Loaded connections'
actual `@last_activity` and effective timeout are observed outside it too.
Reject any worker whose conservative request-start-to-window gap, or actual
connection age at window start, reaches its timeout. Certify absence of the
aged path only when **age at start + the entire window duration < timeout**
for every observed connection. Separate gap/duration tests are insufficient
near a boundary. Duration includes reporting/dump overhead conservatively.

After **all** Ir workers finish, separate untimed companion processes replay
the same four-window idle/GC/request schedule, tracing only the AR 8.1.4
aged-decision line (1075). Their positive idle exercise must fire the counter;
per-window counts must be symmetric across arms within each round or the
cohort rejects. They are labeled `untimed_companion_not_measured_counts`,
never reported as measured-window counts. If the whole-window time bound is
too long, `companion_required=true` records that the only path-count evidence
for that window is supplementary; it is **not an exact zero-path proof**.
The main pre-window timing gate still cannot be rescued by a companion.
`samples.json`, `summary.json` and the request export retain timestamps,
actual ages/timeouts, conservative bounds, companion counts and symmetry.
No compiler freezing, call-threshold change, app setting change, filtering,
retry-until-flat or tolerance relaxation is part of v2.

**One finite off/off validation, 2026-10-21: accepted.** Measured and
predeclared published head
[`2b57bc8`](https://github.com/thomasklemm/lowrail/commit/2b57bc84ccebd990918743d70033e1b16d4ffdce),
not the later form-operation adapter or collection micro. Two identical
`LOWRAIL=0`, no-setup arms, six fresh-process rounds; the two-arm schedule
uses at most two of the four reserved Callgrind workers. No retry or changed
setting. Full source/fixture pins match before/after. The
[numeric export](bench-yjit-v2.json) retains method/tool/source pins, complete
warmup histories, measured counters, timestamps, conservative timing bounds
and explicitly separate companion evidence. Raw data and responses stay private.

| Control | Result |
|---|---|
| Total Ir A/A, off-B vs off-A | **+0.0147% [−0.1192, +0.0717]**, passes unchanged ±0.5% gate, contains zero |
| GC-excluded Ir A/A | **+0.0460% [−0.1064, +0.1082]**, passes the same gate |
| JIT mode / warmup / measured flatness | **12/12 workers, 48/48 windows pass**; convergence at 2,200–10,600 requests, ten quiet batches; no changed/missing measured counter |
| Heap / brk / measured GC | **pass**; fixed pools matched, no overflow; 48/48 windows have zero minor/major/compaction deltas |
| Main pre-window timing | **48/48 pass**; conservative request-start gap 0.0187–1.3993 s, actual connection age 0.0110–0.5599 s, unchanged timeout 2 s |
| Whole-window timing bound | **24/48 prove absence**, all N=0; **24/48 require the declared companion fallback**, all N=50; whole-window duration 0.0814–6.3479 s |
| Separate untimed companions | **48 zero window counts**, symmetric in every round/arm; every companion's idle-boundary exercise count is 1 |

This validates **one blog-show off/off cohort** under v2, not universal
flatness, a pass saving or native latency. In particular the 24 long windows
have **no exact measured-path-count proof**; their zero counts are companion
observations only. Future pass comparisons keep the strict per-window JIT,
A/A, heap/brk and timing/symmetry gates and may still reject. No historical
config/link cohort is re-scored or used as a newly accepted speed claim.
Benchmark tests: 4.0.7 **15/166**, 4.1-preview1 **15/180**, no failures/errors/
skips; final upstream rebase also passed the five focused gate tests, **89
assertions** on each VM. No app/runtime/default or timeout policy changed.

#### v3 declaration: rehearse harness helpers and target eden pages

**Declared before measurement; one multi-arm validation is authorized after
publication, with at most four workers and no retry.** The accepted v2 off/off
result above remains accepted, but does not generalize to the first real
six-arm form cohort. That cohort on
[`ab8e4df`](https://github.com/thomasklemm/lowrail/commit/ab8e4dfced319e95527ba480bea845ff330d33bb)
is **rejected**, without retry or re-scoring. Its A/A and idle controls pass;
heap matching and JIT stability do not. There are 36 workers / 144 windows:

| Rejected observation | Diagnosis from retained data and untimed native probes |
|---|---|
| `3-off_a`, `4-off_a` hit 20,000 requests; last reset at 19,200, only four flat batches | Both histories acquire four ISeqs with +3/+4/+9/+6 blocks. An unchanged-worker native probe with 50-request observation batches instead of 200 names `GC.start` (`<internal:gc>:44`), the GC block in `JitStability.warm`, `counted_requests`, and its warm callback, at requests 1,950/2,000/2,950/3,000: the same block deltas at one quarter the request positions. The harness's batch-call thresholds, not just app request thresholds, need preparation. Not every later block-only reset has an archived site identity. |
| `0-disabled no_gc N50 +50`, `2-missing no_gc N50 +8`, `5-missing total N50 +14` | **Unattributed.** Original-harness native disabled/missing probes have flat windows. Their activation paths differ from off, but the retained counters do not establish refusal/fallback sites; no such cause is claimed. |
| `5-default no_gc N0 +7` | An original-harness native default probe reproduces a +7-block empty window in `Integer#times`, indexes 0/11/12/31/31/34/38. It proves another harness-context mechanism, not the unlogged historical window's identity. |
| Default has 611/245 pages in pools 0/2, other arms 612/246 | Slot ranges exceed the unchanged one-page gates by 9/12 slots; no window grows capacity. Staged native probes reach the same 611/245 immediately after preparation, then show observers consuming the nearly full, uncollected filler heap: disabled grows before collection, while default collects earlier. This is a preparation/GC-phase mechanism, not in-window growth. |

Cap exhaustion already **fails closed at acceptance**:
`stable=false`, `stop_reason=warmup_cap` rejects both workers and the cohort.
Execution is not fail-fast: their four windows and histories are retained,
not dropped or counted as accepted workers. v3 preserves that accounting.

Default's different setup is real. `Passes.install` skips the runtime-only
form installer when its units are disabled. Default instead runs
`FormScaffold.activate` / `FormScaffoldInventory.check`, hashes the stock
source inventory, materializes/certifies methods, and retains **42 compiled
source-file roots** in `@compiled`. A separate full-GC census before preparation
finds pool-0 live slots **229,688 default vs 220,730 disabled**, and pool-2
**27,362 vs 25,114**. These are instrumented native setup observations, not
measured allocations or noise to subtract. Canonical `.lowrail` is not used:
the retained runtime-only YJIT artifact has manifest SHA-256
`2bd964cf1d666756287822a9f351d7007bf428d54b9f71ab143b8cd1756b3096`,
unit 18, no delivered files/templates, and independently pinned runtime sources.

**v3 changes the harness only:**

1. Grow to an explicit **eden-page count**, not `floor − live_slots` objects.
   For each pool use the ceiling of its slot floor divided by
   `HEAP_PAGE_SIZE / slot_size − 1` (integer division, a conservative
   header/alignment allowance). Ruby 4.0.7's unchanged five slot floors give
   **611 / 306 / 246 / 99 / 100 pages**. Prepare small-slot pool 0 last, retain
   sparse anchors, then collect discarded fillers **before observers**.
   Pre-existing excess pages, failed growth or lost anchors refuse preparation.
   Workers export `heap_page_targets`; every N=0/N=50 before/after endpoint
   must retain those identical targets across arms. The original slot-floor
   and **one-page slot-range gate remain**, additionally to this page check.
2. Preserve the exact observer/clock prewarm, unchanged effective-timeout idle
   exercise and request-only settling. After the idle exercise, run **200
   preparatory cycles** of N=50 and N=0 through the **same workload Proc and
   two-argument callback signature** used by windows. Use the same GC helper,
   counter observations and batch-loop exit as certification. That is 10,000
   untimed requests for N=50, separately reported, not quiet-budget credit.
   A pure-harness probe caught +3 callback-entry blocks when warmup passed one
   argument but windows passed two; another probe caught a lazy warm-loop exit.
   Neither is fixed by merely issuing more requests through a different body.
   Client START/ZERO/DUMP requests are **not** rehearsed: these C methods have
   no Ruby ISeq/call threshold, and extra dumps would corrupt window indexing.
3. Only then begin a fresh certification history: **≥2,000 quiet requests**,
   default ten 200-request batches, cap **20,000 certification requests**.
   Any changed/missing counter still rejects; no quiet-budget borrowing from
   preparation. The fixed preparatory budget is additional and explicit, not
   a silent increase to the certification cap. `jit_warmup.method` is
   `rehearsed-pages-quiet-2000-v3`; `rehearsal` retains its own history/counts.
   Captured operations reuse their exact replay Proc and restore captured
   context; they never substitute an unrelated app request.

The pure no-app native YJIT check uses the real C client extension without a
Valgrind process: all four windows and the interval from final certification
to them have **zero new ISeqs, blocks or invalidations**. A kept native regression
also checks this invariant and exact page retention. Compilation-log probes
are untimed diagnostics, **not accepted instruction/latency cohorts**. Neither
flat native results nor a proposed v3 cure attribute the three unlogged
disabled/missing windows. Those remain a reason to require multi-arm validation.

**Predeclared validation:** one finite Ruby 4.0.7 / Rails 8.1.4 blog-show
cohort, six rounds, seed 41231, N=50, alternating phase order, with **off-A,
off-B, empty artifact, missing artifact, disabled units, active form-only
default**. Preserve the retained `2bd964cf…` artifact for diagnosis. The later
app-namespace certificate change makes it stale against current main: build
a **fresh `--jit yjit` artifact in a disposable identical app copy**, leaving
canonical interpreter `.lowrail` untouched. Pin both artifact digests, the
published method/runtime SHA, tool, identical fixture and source hashes
before/after. Before measurement require an untimed native YJIT check on
that fresh artifact: nonzero form hits, zero fallbacks, `exit_trace_leave=0`,
and `certification_jit=yjit`. If the separately published boot-root-release
change lands before launch, pull and build on that head; otherwise record
its later arrival without waiting or retrying. This reproduces the
six-arm setup structure rather than validating off/off alone. At most four
Callgrind workers, only after explicit slot authorization; no retry. Keep the
pinned 512 MiB brk-only Valgrind, ±0.5% off/off A/A gate, every-window JIT gate,
strict heap gates, brk checks, outside-window timestamps and separate companion
symmetry checks. Long windows still have only supplementary companion counts,
never exact measured aged-path counts. No app, timeout or YJIT setting changes;
no pass promotion or renewed YJIT measurement authorization follows from native
checks. Old rejected config/link/form cohorts stay rejected.

#### v3 result: one finite six-arm cohort rejected

The declared cohort ran unchanged on
[`86672e5`](https://github.com/thomasklemm/lowrail/commit/86672e5411f8c0af881ecabd2852925a7536b444),
Ruby 4.0.7 / Rails 8.1.4, seed 41231, six rounds, N=50, at most four
Callgrind workers, without retry or early stop. It used the fresh disposable
app's YJIT artifact `b68764be83bb60ee000f89d67f80e5425cffbe769bb25d10e64dd5ad7d1956cf`;
the canonical interpreter artifact and retained `2bd964cf…` diagnosis artifact
were not rebuilt. The later form source-root release on `411eb71` is not part
of this run. A refused missing-parent-RAILS_ENV launch ran **zero windows** and
is retained separately; the corrected launch is the sole measured cohort.

**Rejected, not a YJIT performance result.** All 36 workers certify in
2,000–16,000 requests, with no cap exhaustion. Every pool endpoint retains
exactly 611/306/246/99/100 eden pages, without widening the one-page slot
gate. A/A passes: total **+0.064310% [−0.050859,+0.205778]**, excluded
**−0.044404% [−0.123620,+0.146327]**. Strict heap, brk and native
idle-companion/symmetry controls pass. Fixture, canonical artifact, runtime
and harness pins are unchanged at completion. The [numeric export](bench-yjit-v3.json)
retains complete worker warmup/rehearsal histories, every window's
counters/pages/timestamps and preceding gaps, source/tool pins and native
diagnostic summaries. Three of 144 windows fail the unchanged compilation gate:

| Arm | Total/N0 | Total/N50 | no_gc/N0 | no_gc/N50 |
|---|---|---|---|---|
| off-A | all six flat | all six flat | all six flat | all six flat |
| off-B | all six flat | round 1: +9 blocks; other five flat | all six flat | all six flat |
| missing | all six flat | all six flat | all six flat | all six flat |
| empty | all six flat | round 3: +45 blocks; other five flat | all six flat | all six flat |
| disabled | all six flat | round 0: +15 blocks; other five flat | all six flat | all six flat |
| active form default | all six flat | all six flat | all six flat | all six flat |

Rounds are zero-based. All 144 windows have zero GC segments; all three
events have zero new ISeqs and invalidations. In particular **all 72 no_gc
windows and all 72 N0 windows are flat**. The total-only pattern is an
observation, not a lead or attribution at this event count.

The Ruby total/no_gc path is identical: same collect/settle, observers,
workload Proc, two-argument callback and loop. Only the C client's
`exclude_gc` flag differs; it toggles collection on GC ENTER/EXIT, which
never occurs in these windows. Rehearsal runs 200 N50/N0 cycles through
the same Ruby workload/GC/counter path; neither C START/DUMP variant is
rehearsed, deliberately preserving dump indexing. Even rounds run total
first, odd rounds no_gc first: the failed total/N50 is earlier in round 0,
later in rounds 1/3. Each N50 follows its own N0 and the same collect/settle.
No total-only Ruby helper or uniquely long pause was found. Full per-window
gap/duration data are retained; no certification-end timestamp exists for
the first window, so its preceding gap is unknown, not invented.

Three untimed disabled-arm compile-log diagnostics do **not** reproduce the
failed windows: ordinary native certifies at 2,000, native padded to the
failed window's 0.11513955102 s/request at 2,200, and `--tool=none` at 3,200;
all four windows are flat in each. Native padding identifies genuine
background Reaper / `sequential_maintenance` / delegate compilation during
preparation around 600/800 s, **not the identities of +15/+9/+45**.

All four configured blog pools have reaping 20 s, idle timeout 300 s,
keepalive 600 s, maximum age Infinity; only primary is connected. Rails
sleeps after maintenance, so ticks drift: birth time + k × period cannot
predict their overlap with old windows. Callgrind's global START/STOP and
default shared thread tables mean the parsed trailing `totals:` can include
background threads; they are not request-thread-only counts. YJIT counters
are process-global too. No retained Reaper activity endpoints establish
which rejected window contained a maintenance pass.

A separate traced companion validates the proposed hook-free `/proc` proxy,
not an in-window hook: native observed two passes with +1 voluntary switch
each; Nulgrind observed +1 and +92. Idle intervals had zero switches/runtime
movement. Under Valgrind, switches are **not a tick count**. If used later,
any positive Reaper-task switch/runtime delta means only **background
activity present**; false positives cost windows. Zero is evidence, not
proof of inactivity. Late blocks with zero activity would remain unexplained
by that mechanism. No Reaper gate, separate-thread accounting or v4 cure is
declared here. **The late-window cause remains open.**

#### v3 + compile log: diagnostic addition, not a cure

Declared after the finite v3 result, before the next cohort. Opt in with
`BENCH_YJIT_LOG=1` and `BENCH_JIT=yjit` (or `1`) on fixed-heap Callgrind.
The driver passes Ruby 4.0.7 `--yjit-log=OUT/ROUND-ARM.yjit.log` to **every
measured arm**, retaining each entire file and its SHA-256. No rotation,
memory-only log, window deletion, retry or relaxed gate. The next authorized
cohort is the sealed thread's form-only show run with a **fresh form-only
`--sealed --env production --jit yjit` artifact built on its exact published
measurement head**, not another validation cohort. The earlier `411eb71`
artifact is stale: the subsequent link fix changes its `sealed.rb` source
pin. Do not bypass the stale-source gate or use a historical runtime override.
Pin the fresh artifact/runtime/harness, pass the untimed native admission
(form hits > 0, zero fallbacks, `exit_trace_leave=0`, `certification_jit=yjit`)
and preflight before the one finite four-worker cohort. If all gates pass,
it counts; otherwise the files supply late-site identities. The old rejected
cohort is not re-scored.

Ruby initializes its fixed 1,024-entry Rust ring and output file at boot.
In file mode every attempted block compilation is synchronously written and
flushed **as it happens**, in addition to updating that ring. A long warmup
may wrap the ring but cannot discard file entries; the native control file
retains 43,478 lines. Do not use `--yjit-log=quiet` / `RubyVM::YJIT.log` as
the retained stream. There is no log callback on flat execution. The source
does not change call thresholds, app configuration or JIT codegen policy
([pinned Ruby logging source](https://github.com/ruby/ruby/blob/229531a6cf/yjit/src/log.rs),
[compilation call site](https://github.com/ruby/ruby/blob/229531a6cf/yjit/src/core.rs)).

Qualification: a log line precedes possible abandoned/failed compilation,
while `compiled_block_count` counts installed blocks. A failed attempt can
write without moving any of the three old counters. Consequently logged
snapshots additionally retain **`compile_log_bytes`** outside the measured
region, during rehearsal/certification and at every window endpoint. Growth
or a missing byte counter rejects a logged window even if installed-block
counters are flat. This only strengthens acceptance; it never certifies
logging work as steady-state instructions.

Outside-region `jit_log_start_realtime_ns` / `jit_log_end_realtime_ns` place
the file's Unix-realtime ISeq/location/bytecode-index entries into conservative
window envelopes. Byte offsets also identify the exact file slice between
snapshots independently of wall-clock adjustment. The builtin log has no
thread/request IDs; none are inferred or required. Logs contain attempts,
not a one-to-one list of installed blocks. All existing A/A, JIT, heap,
brk, activation and idle-boundary gates remain. Native idle companions remain
separate controls, not an exact measured-path census.

Before relying on this addition, one untimed native log-off/log-on pair on
the pinned disabled specimen both certified at 2,000 after 200 rehearsals,
retained 2,178 anchors and the identical explicit page targets, and had four
flat windows. Preparation was not bit-identical: log-on minus log-off had
five fewer live pool-0 slots (other pools equal), 39 fewer allocated objects
to that point, and 269 rather than 270 pre-fill pool-0 pages; post-fill targets
were identical. These are observations, not noise to subtract or a claim of
universal equivalence. A further native real-app check of the diagnostic
observer certifies at 2,000 with no byte growth or counter changes in any
window. Kept no-app native checks cover both log-off and log-on, explicit
pages, zero post-certification compilation, and realtime envelopes. A gate
regression rejects byte growth with flat installed-block counters.

Driver flags for the next authorized form cohort, with its own fresh output
directory and correctly pinned artifact/runtime. These flags are head-agnostic:
`APP` must point to that fresh disposable app/artifact, not a retained old build.

```sh
PATH="/tmp/vg/bin:$PATH" CPATH="/tmp/vg/include${CPATH:+:$CPATH}" \
RAILS_ENV=production LOWRAIL_SEALED=1 SECRET_KEY_BASE_DUMMY=1 \
BENCH_JIT=yjit BENCH_YJIT_LOG=1 BENCH_JOBS=4 \
BENCH_ROUNDS=6 BENCH_REQUESTS=50 BENCH_SEED=41231 \
ruby bench/pass.rb "$APP" --pass sealed/form_scaffold \
  --path /articles/1 --counter callgrind --out "$NEW_OUT"
```

Use the repository-pinned Ruby. Parent `RAILS_ENV` must explicitly match
the manifest; preflight now rejects missing/mismatched values **before
manifest activation or setup**, rather than silently defaulting them.

**Native late-entry finding; no gate relaxation.** The next form-only
v3+log cohort on
[`88506d9`](https://github.com/thomasklemm/lowrail/commit/88506d9b10a5177fee768b64fa6f02440e7f0d47)
finished rejected: only `0-off_b / total / N50` fails among 144 windows
(+17 blocks/+3,260 log bytes, no new ISeq/invalidation, all windows GC-free).
Its log names five stylesheet/preload/response methods at previously logged
locations. A native v3 replay finds all five at **119/120 interpreter-entry
calls, with compiled payloads but no interpreter entries** after windows.
A controlled native `Method#call` on the unchanged nonce reader reproduces
entry installation at 120 with +1 block but no new ISeq/invalidation.
This supports a mechanism, not the historical caller/trigger or exact
17-block group; the historical entry counters were not recorded. See the
[mechanism, limitations and executable-pinned probe sources](passes/yjit-regression.md#late-asset-helper-entries-native-mechanism-historical-trigger-still-open).

Excluding compiler instructions would not preserve steady-state execution:
the isolated call executes 27 YJIT bytecodes before entry installation,
29 afterwards. That is an execution-mix change, **not** two machine
instructions or a request price. No compiler-exclusion relaxation and no
longer-quiet-only cohort is declared. Existing v3+log gates stay unchanged.

Longer warmup alone is not a demonstrated cure: JIT-to-JIT repetition can
leave the native-entry counters untouched. The 36 workers consumed 253,000
certification requests plus 360,000 rehearsal requests; none of their
retained prefixes establishes 10,000 quiet requests. Eight would need at
least 20,600–26,000 certification requests for that quiet suffix, even
without future changes, exceeding the 20,000 cap. For 36 workers the
current maximum is 1,080,000 rehearsal+certification requests and 32,400
explicit warmup GC calls; a hypothetical 40,000 cap permits 1,800,000 and
43,200. Neither bounds wall time; uncapped quiet certification is unbounded.
Pending-entry census remains native-only research, not v4 certification.

The [bounded native census study](passes/yjit-regression.md#bounded-pending-entry-census-useful-warning-unsuitable-admission-predicate)
now covers all 36 configurations. It flags all five named methods at 119/120
before `0-off_b`'s windows, but **all 36 configurations warn**, including
34 with four flat native windows. There are 1,346–1,527 pending normal
entries with payload per process; 35/36 have all five named entries pending.
Two native windows compile (including a no_gc window); 142/144 are flat.
This is a companion diagnosis, not historical memory inspection or pricing.
Wrapper-only ObjectSpace enumeration is incomplete; the full internal-ISeq
dump changes GC/heap state and must stay out of measured workers. Optional
argument/branch and rescue-entry controls also show the proposed predicate
is not sufficient. No generic app-invisible completion API is demonstrated.
Decision: **secondary YJIT repricing is parked; interpreter Ir remains the
primary metric**. The v4 proposal is **UNIMPLEMENTED and parked**: its screen
refuses all 36 configurations and has no discriminating power in this study.
The retained proposal would keep all gates, use capped native negative
admission (not a flatness proof), and strengthen entry/attempt visibility.
No v4 implementation, compiler exclusion, method change or cohort follows.

Warm the observer too: after heap preparation, an enabled observer gets 200
untimed rounds of the **exact** `GC.stat_heap(pool, existing_hash)`,
`GC.stat(existing_hash)` and JIT snapshot signatures used at the endpoints.
The one-argument heap queries used during setup do not warm the two-argument
Ruby wrapper. The allocation survey identified this residual compilation as
`stat_heap@<internal:gc>`; a shared operation regression reproduces flat request
warmup followed by a failed window gate without observer warmup. Nil observers
do none of this work, and no operation or captured CurrentAttributes is changed.

Request workers also issue **one untimed settling request after each pre-window
GC**, symmetrically for N=0/N=50 and total/GC-excluded modes, before either
allocation or instruction endpoints. This is deliberately not an operation
worker default: a request would replace the operation's captured context.
Workers record `request_settle: true`; earlier cohorts retain their original
protocol, not retrospectively corrected numbers.

The worker snapshots the three counters immediately outside the GC/instruction
endpoints. Every N=0 and N=50
window, in both modes, must have identical before/after counters. A changed or
missing counter rejects the **entire comparison**, even when its A/A and heap
controls pass. Counts from rejected windows remain available as diagnostics;
there is no filtering, automatic retry or widened tolerance. The untimed
observer may compile during heap preparation, but not inside a measured window.

`BENCH_JIT_WINDOW` and `BENCH_JIT_MAX_WARMUP` change the warmup window and bound;
v2/v3 require at least 2,000 quiet workload iterations and three windows.
v3 separately rehearses 200 N=0/N=50 cycles before that certification budget.
`BENCH_JIT_CALL_THRESHOLD` optionally
passes a positive `--yjit-call-threshold` to instruction workers. Default leaves
Ruby's production threshold unchanged. Do not compare different thresholds as
if they were one production configuration. YJIT statistics instrumentation is
**not** enabled: these counters are available in ordinary Ruby 4.0.7 YJIT.
No code-GC disabling, compiler freezing or application config change is used to
manufacture stability. Interpreter workers still explicitly disable Rails'
`config.yjit` before boot. Requested and **observed** JIT modes are separate
metadata; observed state and the failed JIT gate appear even on a rejected run.

A build must match that mode too. On this Ruby, `Array#each.source_location` is
`nil` with YJIT off and `<internal:array>:219` with it on. For an interpreter
cohort whose facts include it, use the existing `LOWRAIL_BUILD_JIT=0` build hook;
otherwise activation should reject the build. Do not weaken the fact check or
price a silently declined pass. YJIT cohorts keep production boot behavior.

```sh
# A currently available pass and its matching production build:
BENCH_JIT=1 mise exec -- target/debug/lowrail bench APP \
  --pass PASS --path /path --out /tmp/NEW-yjit
# Historical source-cost study: disposable pre-quarantine checkout only.
BENCH_JIT=1 mise exec -- ruby bench/experiments/yjit_study.rb /tmp/NEW-yjit-layers
```

The historical study pins the runtime/artifact before
[`45fd07a`](https://github.com/thomasklemm/lowrail/commit/45fd07a851da4ecee8856a1fc2ea41c4843934d4),
at
[`c9d2397`](https://github.com/thomasklemm/lowrail/commit/c9d2397f1748579b04f6bddff48bc3bfc53d79b0).
Both source passes are now wholly quarantined, including opt-in and old
artifacts. Its `default` arm prices the **legacy guarded-source build**, not
today's supported default. Do not bypass quarantine to recreate it in an app;
use an isolated historical checkout. The published ceiling specimens themselves
are unchanged by quarantine. Manifest, lockfile, runtime and harness hashes
record the exact measured state.

The study driver uses the published L1/L2/L2_events specimens **unchanged** in
disposable app copies and the exact shared heap counter/estimators. Each route
has its own independent off/off controls. It performs the same strict default
build/activation probe and end-of-run build/runtime/harness fingerprint checks.
Its finite fixture byte/header/SQL checks do not repair the specimens' known
semantic omissions: L2_events lacks observable controller assigns and misses
mid-request helper mutation. These remain conditional **upper bounds**, not
supported passes or generator targets.

Operation workers using `HeapWindows` opt in by warming their actual operation
with `JitStability.warm { |count| ... }`, emitting that `jit_warmup` record and
passing `observe: JitStability.method(:snapshot)` to `HeapWindows.run` when
YJIT is actually enabled. The shared runner refuses YJIT workers without this
proof; a long fixed iteration count alone is insufficient. The guard-cost
driver uses the same gate. Interpreter's nil observer does no measured work.

### YJIT protocol attribution and retained failures

The initial finite blog study used six arms × six fresh processes on each of
index/show. **All 72 workers failed the JIT window gate**, although both routes'
total/GC-excluded A/A and all five heap controls passed. Ordinary request warmup
was flat; this was not evidence of a steady measured path. A threshold-one
native probe compiled over 11,000 ISeqs rather than about 2,800 at the production
threshold; it was not promoted into a different production comparison.

Two separate cold paths mattered. Compilation logging first identified
ActiveRecord's `with_raw_connection` retry branch at bytecode offsets 83/87.
The three-GC pause crosses its two-second idle threshold. An instrumented
interpreter probe saw first-query ages **3.775 / 1.579 seconds** in total /
GC-excluded windows; N=50 made the ordinary **150 SQL/raw-connection calls**,
with **zero `verify!` or `active?` calls**, while N=0 made none. This read path
uses `allow_retry: true`: the observed difference is retry-branch work, not an
extra verification round-trip. It **does not cancel in N−0**.

The request-only settling callback reduced the observed interpreter ages to
**0.459 / 0.455 seconds**, and YJIT ages to **1.669 / 1.756 seconds**, still with
150 ordinary queries and zero verification calls. These are attribution probes,
not latency estimates. The separate six-round settled interpreter control
**fails** GC-excluded A/A: **[−0.03980, −0.00157]%** misses zero; total A/A and
heaps pass. It is retained, not rerun or represented as a corrected historical
result. The corresponding YJIT baseline control passes both A/A gates, heaps,
three-window warmup and all 48 measured counter comparisons.

A complete throwaway N=0/N=50 run in both modes did not reliably remove the
remaining +1 ISeq/+1 block, even with another 600 requests of flat warmup.
The allocation survey then traced it to the GC-stat observer's cold signature,
not an operation. Exact-signature observer warmup fixes the shared regression
without relaxing the gate. Thus **warmup must exercise the measurement helpers,
not only application requests**. Original rejections, intermediate controls,
counter histories and raw per-window Ir are retained in
[yjit-results.json](yjit-results.json).

### Matched interpreter / YJIT request study

**Neither full-request YJIT comparison is accepted.** After the observer and
settling corrections, every worker reaches three flat warmup windows in
800–1,800 additional requests, but measured windows still compile blocks:

- Index: **4/36 workers reject**, adding 2, 16, 5 and 13 blocks. Both A/A
  controls and all five heap gates pass.
- Show: **5/36 workers reject**, adding 119, 16, 5, 28 and 13 blocks. Heaps
  pass, but GC-excluded A/A also rejects: **[−0.10156, +0.72995]%**, beyond
  ±0.5%. Total A/A passes.

These additions change neither the compiled-ISeq count nor invalidations;
watching ISeqs alone would miss them. One separate `--yjit-log=quiet` L1
diagnostic did not reproduce the residual additions, so their sites remain
**unattributed**. Do not assign them to request code or the observer without
evidence. No further tuning or cohorts were used to obtain a passing result.
Even arms whose own windows are flat remain part of the rejected comparison;
they are not salvaged as accepted endpoint results.

The matched interpreter comparisons use the same corrected request protocol,
frozen runtime/build/specimens, six rounds, N=0/50 windows and seed 41231.
Both routes pass total/GC-excluded A/A and all five heap gates. The separate
failed two-arm interpreter control above remains in the record: acceptance of
these planned multi-arm comparisons does not erase independent run variance.
All workers report the actual intended JIT state, not merely its launch flag.

Paired total-instruction Δ% versus the same round's no-Lowrail `off_a`;
brackets are coarse nominal 95% bootstrap CIs. **Every YJIT cell is diagnostic
only**, including its interval. Interpreter results are controlled work
comparisons, not semantic certification of these historical specimens.

| Route / comparison | Interpreter Δ% [95% CI] | YJIT Δ% [95% CI], rejected |
|---|---:|---:|
| `/articles`, legacy source build | −6.057 [−6.082, −6.029] | −5.463 [−5.487, −5.442] |
| `/articles`, L1 | −2.232 [−2.254, −2.185] | −2.219 [−2.300, −1.752] |
| `/articles`, L2 | −33.367 [−33.384, −33.342] | −31.835 [−31.878, −31.789] |
| `/articles`, L2_events | −26.200 [−26.217, −26.171] | −22.897 [−22.962, −22.868] |
| `/articles/1`, legacy source build | −1.048 [−1.084, −1.016] | −1.022 [−1.074, −0.981] |
| `/articles/1`, L1 | −2.517 [−2.547, −2.490] | −2.440 [−2.511, −2.402] |
| `/articles/1`, L2 | −40.869 [−40.881, −40.863] | −38.699 [−38.740, −38.259] |
| `/articles/1`, L2_events | −37.289 [−37.316, −37.271] | −35.120 [−35.144, −35.097] |

The diagnostic eventful ceiling moves from roughly −26/−37% to −23/−35%,
but **this does not establish that the endpoint ceiling shrinks under YJIT**.
The required quiescent-window condition failed, and the specimen still omits
observable state/mutation behavior. No architecture-priority change, current
source-pass support claim or native speed claim follows. Starter Kit's
default/+inertia comparison was not run; the blog did not yield an accepted
full-request YJIT measurement to extend.

### Accepted YJIT guard micro and next-best proxies

The guard micro is independently accepted: six interleaved fresh-process
rounds per runtime, N=0/100,000, both modes, unchanged A/A and five-pool gates,
and flat warmup/window counters in every worker. Subtract each round's empty
loop from its guard arm, not separately estimated medians:

| Cached guard implementation | Interpreter net Ir/check (published) | YJIT net Ir/check |
|---|---:|---:|
| Old cached dispatch | 822 | 371 |
| Monomorphic K | 425 | 140 |
| Change | −48.30% | **−62.26%** |

Every new YJIT round gives exactly 371 / 140 in both modes. The old library is
the unchanged archive of
[`e01e496`](https://github.com/thomasklemm/lowrail/commit/e01e4968f022231cfd4c38d67b631399ceef4ab0);
the K runtime matches the frozen request study's runtime fingerprint. The
interpreter column is the earlier published micro, not a native timing or a
new request-effect claim. K is not erased by YJIT, but a cheaper guard does not
establish a material endpoint win.

For now, use **allocations plus independently gated leaf-operation Ir**, with
full-request YJIT Ir explicitly diagnostic when its compiler-state gate fails.
For example, the matched interpreter eventful specimens allocate
2358.37 → 1674.56 objects/index request and 2244.02 → 1277.44/show; the rejected
YJIT comparisons record 2378.75 → 1688.69 and 2254.25 → 1282.27. These count
objects, not bytes, retained memory or production GC cost, and do not repair
the specimens' semantic omissions or certify a rejected cohort.

A direct user-only hardware-cycles `perf_event_open` probe returned **ENOENT**:
this orb exposes no usable event for that probe. There is no perf-stat-like
cycles estimate to report, nor a validated native-time control. A quieter
machine with independent native-YJIT cohorts/PMU counters is the next route to
a production speed conclusion; converting interpreter Ir, emulated time or
allocation counts into cycles would invent one. Sanitized evidence retains
all eight request trials (including failures), per-window Ir/GC/allocation
endpoints and five-pool capacities, warmup histories, runtime/build/harness
fingerprints, idle-branch probes and the accepted guard comparisons in
[yjit-results.json](yjit-results.json). No runtime or lowering change is part
of this study.

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
`--passes default,+ar_instantiate` build to the same rounds. Unit ids are not assumed.

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

## Runtime registry cold cost

The runtime-registry refactor keeps the same warmed request and guard
implementations. A same-round fixed-heap comparison on real-blog uses
`BENCH_BASELINE_LIB` to add an archived-runtime worker against the **same
source-only manifest**. Six rounds × 50 requests, 50 warmups, interpreter
mode: total instructions **−0.02090% [−0.05032, −0.00626]** and GC-excluded
instructions **−0.01292% [−0.05570, +0.00183]**. Both independent A/A controls
and all five heap capacities pass. The initial before-only A/A failure is
retained, not used as evidence. The stats-off YJIT guard micro remains
**662.482978 → 662.506856 instructions/check (+0.00360%)**. These are not
native request-speed claims.

Those request windows exclude boot. A separate cold probe brackets the
first `require "lowrail/setup"` on the blog's unchanged 11-unit manifest,
with statistics disabled. Six interleaved rounds each use independent
before-a/b and after-a/b processes. All 24 have identical actual capacities
in all five heap pools, unchanged through setup. The paired increase is
**+0.758%**, about **0.37–0.40 million instructions paid once per boot**.
Three segmented observations per runtime give this breakdown:

| Cold phase | Before instructions | After instructions | Delta |
|---|---:|---:|---:|
| Require `lowrail.rb` | 2,052,121 | 1,663,981 | −388,140 |
| Require `passes.rb` | 0 | 843,805 | +843,805 |
| Source delivery and pass selection | 3,029,117 | 2,951,341 | −77,776 |
| Manifest/Guard/Loader require, load and install | 47,116,759 | 47,107,789 | −8,970 |
| Segmented net | | | +368,919 |

Entries are medians; segment boundaries introduce different seams from the
whole-setup probe, so their net is diagnostic, not an exact reconciliation.
The loaded-feature audit contains only manifest, guard, compilation, loader,
registry, routes, templates and setup: **no memo, digest, AR or Inertia runtime
is required, installed or activated** for this source-only manifest. Static
registry descriptors and six empty selections are not runtime plans. The
increase is the cold load/compilation/definition of the registry and shared
activation helper, not an eager-loading regression or a per-request tax.
Shipping `passes.rb` as a precompiled ISeq is a possible follow-up; no such
delivery change is included here.
