# P-MAP: request CPU beyond Rails

2026-11-05. Ruby **4.0.9**, Rails main, YJIT and interpreter, two independent same-base processes per cell.
This is a **diagnostic stack map, not a certified steady-state price or a speed claim**. It adds native C,
GC and kernel work to the Ruby census. It does **not** finish an exact, fully inclusive YJIT accounting:
native unwinding stops at some Ruby/JIT boundaries, side exits cannot be separated reliably, most measured
YJIT pairs change compilation counters, and window-end heap capacities were not captured. Those are missing
evidence, not zero costs or passed gates. No failed pair was rerun until green.

**Outcome:** SQLite's engine/driver, the real Puma/kernel boundary and response hashing deserve attention.
GC alone is 5–12% of observed YJIT CPU samples. The obvious exact hashing change already exists as
[rack/rack#2522](https://github.com/rack/rack/pull/2522); the other large regions do not yet identify an exact
removable operation. **No candidate built, no fork branch, no PR-queue item, and no upstream action.**
Building a duplicate or a tiny speculative change would contradict the effect/reach rule. No ruby/ruby work.

The [44-window receipt](../../bench/upstream/stack_map/results.json) contains raw partition counts, overlapping
inclusive counts, per-request normalization, allocations, compilation deltas, losses and SHA-256 fingerprints.
The private raw profiles and setup logs remain in `.lowrail/private/stack-map/` in this orb. The public receipt
contains no authentication cookies, response bodies or SQL.

## What was measured

| Workload | Work per iteration/window | Boundary |
|---|---|---|
| ruby-bench railsbench | 2,000 seeded GETs, HTML and JSON | Existing `app.call` benchmark; **not Puma** |
| ruby-bench lobsters | 114 seeded GETs | Existing route generator, login outside the window; **not Puma** |
| ruby-bench shipit | 57 seeded GETs, HTML and API | Existing route generator; **not Puma** |
| ruby-bench erubi-rails | 10,000 renders | Existing unrouted `FakeDiscourseController.render`; **not a request** |
| corpus Blog, `/articles` | 500 real HTTP GETs per native batch; 20 per instruction batch | TCP → Puma → Rack → Rails → socket write |
| corpus Writebook, authenticated handbook leaf | Same batch sizes | TCP → Puma → Rack → Rails → socket write |

Native measured windows contain **20 iterations/batches**. Instruction windows contain **one** iteration/batch.
The two corpus servers each have one worker thread; the HTTP client is a separate, unprofiled process, using a
persistent TCP connection. Every response must be 200 with a nonempty body. Auth and fixture preparation are
outside the window. This is serial keep-alive traffic, not a throughput or saturation experiment.

Pins (frozen at setup, not a claim that these are still today's latest heads):

* Ruby `4.0.9`, revision `3e93b23afc`, x86_64 Linux, PRISM; YJIT `--yjit --yjit-perf`, interpreter explicitly
  `--disable-yjit` with Rails' auto-enabling disabled.
* Rails main [`1e235cee11b0a7aecb189d8837534807626287aa`](https://github.com/rails/rails/commit/1e235cee11b0a7aecb189d8837534807626287aa).
* ruby-bench main [`ad63bf8cac618032adefdd1c5219636a52b47e5e`](https://github.com/ruby/ruby-bench/commit/ad63bf8cac618032adefdd1c5219636a52b47e5e).
* Blog uses `fixtures/corpus/real-blog-r4-retained.tgz`, archive SHA-256
  `b1dd980b6689bf2b3912691e527d74e0b7699fb32cb53169791c24879f0c0a99`, before the census overlay;
  Writebook source [`7478e2c7b109e688a6fa4745bac123e72b5cef84`](https://github.com/basecamp/writebook/commit/7478e2c7b109e688a6fa4745bac123e72b5cef84).
  Both were prepared through `script/census setup --corpus censuspm`.

| Workload | Rack | sqlite3 | concurrent-ruby | JSON | Puma actually serving |
|---|---|---|---|---|---|
| railsbench | 3.1.17 | 2.7.3 | 1.3.5 | 2.17.1 | — |
| lobsters | 2.2.19 | 2.7.3 | 1.3.5 | 2.13.2 | — |
| shipit | 2.2.22 | 2.7.3 | 1.3.6 | 2.19.1 | — |
| erubi-rails | 3.2.0 | — | 1.3.5 | 3.1.0 | — |
| Blog | 3.2.7 | 2.10.1 | 1.3.8 | 3.1.0 | 8.0.2 |
| Writebook | 3.2.7 | 2.9.6 | 1.3.8 | 2.21.2 | 7.2.1 |

All database workloads here use **SQLite**. **pg/libpq is unmeasured, not 0%.** A PostgreSQL corpus request is
still needed before calling this a cross-driver map. Libraries are the setups' resolved versions, not a claim
that an old ruby-bench lock represents current gem main.

The disposable ruby-bench setups use local Rails component paths. They reuse the existing
[Rails-main config and Shipit ReviewStack setup](../../bench/upstream/index_with_ruby_bench/README.md).
Shipit initially reproduced the known frozen `ActiveModel::Name` failure; the already-recorded setup patch
was reused on vendored shipit-engine 0.45.0. The failed attempts remain logged. No new compatibility fix was
developed, queued or priced. Lobsters uses the benchmark's `ANALYZE` setup before measuring its in-memory DB.

## Why two profilers, not one invented combined percentage

**Native CPU reference: Linux perf's software `cpu-clock` event at 997 Hz**, all threads of the server/benchmark
PID, user and kernel, `--call-graph dwarf,16384`, Ruby's `--yjit-perf` maps. Hardware cycles and instructions
were not available in this orb. A separate kernel-symbol probe recovered named syscall frames, so kernel work
is measured rather than inferred by subtracting Ruby time. FIFO enable/disable commands are acknowledged at
the window boundaries; boot and warmup are excluded.

This gives a CPU-sample distribution, not retired instructions, latency, wall time, or exact CPU milliseconds.
The kernel bucket includes syscalls, scheduling and interrupt/profiling work; it is **not all avoidable HTTP
syscall cost**. Samples are counted equally at the requested sampling frequency. Work in another process,
including the client and Redis, is outside this server-PID map.

**Inclusive Ruby instruction reference: the existing census 8 patched Callgrind and `rb_profile_frames`
sampler.** It captures the Ruby semantic stack which native DWARF cannot fully unwind, including interpreter
frames. Exact client Ir excludes the sampler handler and retained-frame GC marking. Instruction samples are
assigned to the nearest Ruby owner, except recognized SQLite/PG C frames and JSON. Thus core String/Hash/regexp
C work remains charged to its Ruby caller. A driver bucket includes SQLite's C engine **and** Ruby-value
conversion, not just extension glue. Callgrind does not execute/count the kernel.

The Callgrind instruction partition and native CPU partition answer different questions; **never add their
percentages**. Even GC differs: a one-iteration Lobsters instruction window collects no GC, while twenty native
iterations do. An instruction is not a CPU cycle; database and SHA code have different costs per instruction.

Fixed heap floors are 1,000,000 / 250,000 / 100,000 / 20,000 / 10,000 slots, prepared with the existing
`HeapWindows.prepare_heap` in every arm. Initial pools were retained, but **window-end capacity snapshots were
not recorded**. This is not the full fixed-heap admission certificate from [bench.md](../bench.md).

Warmup is five benchmark iterations/batches, followed under YJIT by at most 50 single-iteration windows looking
for three consecutive flat compilation-counter windows. Measured endpoints are checked as well. The receipt
retains the measured deltas; a warmup observation never overrides a failing measured window.

### Attribution checks and limitations

Native ownership is the closest **recovered** JIT caller plus its native descendants, with GC, compiler and
kernel separated first. A C extension below an interpreter frame is **not** assigned the interpreted callback's
work. Otherwise Shipit's JSON generator would falsely get its nested Active Record serialization CPU.
Seven asymmetric classifier controls cover this distinction, direct JSON/SQLite C work, a JIT caller, GC and
kernel precedence. Unknown or interpreted frames stay unresolved. The corrected native unresolved share is
**6.7–11.8%** in the A/YJIT windows, not a proportional redistribution onto Rails.

Native inclusive counts in the receipt are **lower bounds from the recovered callchain**, not complete virtual
Ruby stacks. Instruction inclusive counts count a layer once per sampled Ruby stack. They include nested
layers and cannot be summed; GC is counted separately, without reconstructing its Ruby ancestors. Native
compiler samples identify recognized compilation/branch-stub symbols, not every possible compiler instruction.
**Side-exit CPU is not separately identifiable with this collection:** the minimal YJIT counters do not expose
exit counts, and native unwinding cannot distinguish all interpreter fallback from exit machinery. It remains
in recovered callers or unresolved VM work, never reported as zero.

The YJIT Writebook/Puma Callgrind smoke crashed **inside Valgrind's AMD64 decoder**, `dis_ESC_NONE` /
`disInstr_AMD64`, while decoding generated code near a page boundary (`0x3FE26FE0`, fault `0x3FE27000`), before a result.
This is not an app crash or a Ruby correctness diagnosis. There is **no corpus YJIT instruction map** and no
second attempt to turn that failed cohort green. Native perf remains usable. Analysis with inline expansion
also exhausted memory; re-decoding the same immutable profiles with `--no-inline`, serially, fixed analysis
memory use without collecting replacement cohorts.

## Native YJIT CPU map

Percent of **all observed samples**, A window. A/A variation is below. `0.00` means no sample in that bucket,
not proof of no cost. Other includes app code, remaining gems and stdlib. No Puma runs in the ruby-bench cells.

| Layer | railsbench | lobsters | shipit | erubi-rails | Blog | Writebook |
|---|---:|---:|---:|---:|---:|---:|
| Puma | 0.00 | 0.00 | 0.00 | 0.00 | 7.76 | 2.13 |
| Rack | 11.19 | 4.27 | 0.57 | 2.30 | 5.76 | 2.33 |
| Routing | 4.31 | 1.75 | 2.69 | 0.38 | 1.75 | 2.40 |
| Controller | 6.30 | 2.76 | 0.70 | 6.89 | 3.45 | 1.42 |
| Callbacks | 2.61 | 0.52 | 0.70 | 0.00 | 1.12 | 0.66 |
| Active Record / Active Model Ruby | 11.35 | 29.42 | 50.80 | 0.00 | 12.38 | 32.32 |
| SQLite C engine + driver | 5.95 | 14.94 | 8.32 | 0.00 | 4.36 | 8.00 |
| Action View / templates | 10.40 | 7.06 | 1.28 | 45.58 | 11.79 | 9.31 |
| JSON | 0.68 | 0.22 | 0.54 | 0.00 | 0.33 | 0.40 |
| AS instrumentation | 2.42 | 0.65 | 1.02 | 0.39 | 0.78 | 0.94 |
| Logging | 2.72 | 0.39 | 0.29 | 0.02 | 1.17 | 0.30 |
| AS IsolatedExecutionState | 0.89 | 0.36 | 0.76 | 0.00 | 0.38 | 0.46 |
| Other Active Support | 6.91 | 9.38 | 5.12 | 11.34 | 9.60 | 8.62 |
| Middleware / Action Dispatch | 8.90 | 1.74 | 0.95 | 4.74 | 3.74 | 2.04 |
| concurrent-ruby | 3.47 | 1.02 | 1.60 | 5.48 | 1.11 | 1.12 |
| GC | 6.07 | 5.07 | 9.64 | 12.27 | 6.00 | 6.54 |
| Recognized YJIT compiler | 0.05 | 0.17 | 0.10 | 0.00 | 0.11 | 0.15 |
| Kernel / syscalls / scheduling | 2.25 | 1.06 | 1.18 | 0.40 | 10.19 | 2.73 |
| VM / native unresolved | 7.77 | 9.60 | 7.78 | 6.72 | 11.76 | 8.60 |
| Other | 5.76 | 9.63 | 5.95 | 3.49 | 6.49 | 9.54 |

Direct native interpreter observations, **interpreter / YJIT**, same A windows:

| Layer | railsbench | lobsters | shipit | erubi-rails | Blog | Writebook |
|---|---:|---:|---:|---:|---:|---:|
| SQLite C | 3.07 / 5.95 | 8.14 / 14.94 | 4.33 / 8.32 | 0 / 0 | 2.06 / 4.36 | 4.46 / 8.00 |
| GC | 2.48 / 6.07 | 3.03 / 5.07 | 4.34 / 9.64 | 6.09 / 12.27 | 3.35 / 6.00 | 3.27 / 6.54 |
| Kernel | 1.38 / 2.25 | 0.95 / 1.06 | 0.77 / 1.18 | 0.38 / 0.40 | 2.86 / 10.19 | 2.66 / 2.73 |
| VM / native unresolved | 93.00 / 7.77 | 87.83 / 9.60 | 90.27 / 7.78 | 93.53 / 6.72 | 91.62 / 11.76 | 89.46 / 8.60 |

Most interpreter Ruby work cannot be separated natively; the next map supplies the semantic attribution rather
than falsely calling it all VM overhead. Larger YJIT percentages are not evidence that a component got slower.

## Instruction ownership and inclusive map

Percent of sampled client instructions, **interpreter / YJIT**. YJIT railsbench, Lobsters and Shipit are
**diagnostic/rejected pairs** because at least one arm compiled; their numbers are retained, not pooled with
the flat erubi pair. `—` is unmeasured. Kernel and separately resolved compiler/exit costs are unavailable here.

| Layer | railsbench | lobsters | shipit | erubi-rails | Blog | Writebook |
|---|---:|---:|---:|---:|---:|---:|
| Puma | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 3.43 / — | 0.91 / — |
| Rack | 13.22 / 17.00 | 9.47 / 14.23 | 0.73 / 1.12 | 1.69 / 1.86 | 9.61 / — | 4.29 / — |
| Routing | 7.54 / 5.91 | 2.72 / 2.14 | 3.02 / 3.78 | 0.50 / 0.41 | 4.99 / — | 3.76 / — |
| Controller | 5.94 / 6.11 | 1.34 / 1.26 | 0.31 / 0.39 | 6.51 / 6.63 | 5.56 / — | 1.21 / — |
| Callbacks | 3.02 / 2.84 | 0.40 / 0.31 | 0.54 / 0.41 | 0 / 0 | 1.03 / — | 0.44 / — |
| Active Record / Active Model Ruby | 16.10 / 12.24 | 38.78 / 27.78 | 70.07 / 59.97 | 0 / 0 | 24.38 / — | 43.54 / — |
| SQLite C engine + driver | 1.66 / 2.99 | 10.70 / 19.11 | 3.53 / 6.99 | 0 / 0 | 1.55 / — | 2.92 / — |
| Action View / templates | 12.84 / 11.44 | 8.21 / 8.00 | 0.94 / 0.93 | 56.91 / 50.92 | 17.31 / — | 12.44 / — |
| JSON | 1.61 / 1.44 | 0.27 / 0.25 | 0.47 / 0.79 | 0 / 0 | 0.19 / — | 0.22 / — |
| AS instrumentation | 3.77 / 2.54 | 0.88 / 0.50 | 1.67 / 1.32 | 0.79 / 0.44 | 1.39 / — | 1.29 / — |
| Logging | 2.26 / 2.94 | 0.21 / 0.21 | 0.15 / 0.15 | 0.14 / 0.05 | 0.64 / — | 0.18 / — |
| AS IsolatedExecutionState | 1.83 / 1.59 | 0.90 / 0.54 | 2.38 / 1.74 | 0 / 0 | 0.77 / — | 1.13 / — |
| Other Active Support | 10.38 / 9.91 | 11.60 / 10.76 | 6.36 / 7.74 | 13.65 / 14.34 | 15.22 / — | 11.26 / — |
| Middleware / dispatch | 9.47 / 7.78 | 1.41 / 1.17 | 0.63 / 0.69 | 8.26 / 8.71 | 3.85 / — | 1.94 / — |
| concurrent-ruby | 3.87 / 6.20 | 1.03 / 1.33 | 1.87 / 2.73 | 3.78 / 6.31 | 1.51 / — | 1.13 / — |
| GC | 2.01 / 3.55 | 0 / 0 | 2.48 / 4.97 | 4.82 / 7.82 | 0 / — | 0 / — |
| Other | 4.45 / 5.52 | 12.10 / 12.42 | 4.85 / 6.29 | 2.95 / 2.52 | 8.55 / — | 13.33 / — |

Overlapping **inclusive** shares, same denominator and interpreter / YJIT convention:

| Layer on stack | railsbench | lobsters | shipit | erubi-rails | Blog | Writebook |
|---|---:|---:|---:|---:|---:|---:|
| Puma | 0 / 0 | 0 / 0 | 0 / 0 | 0 / 0 | 100 / — | 100 / — |
| Rack | 94.04 / 92.22 | 99.56 / 99.55 | 97.39 / 94.87 | 1.94 / 1.89 | 94.10 / — | 98.51 / — |
| Routing | 76.96 / 71.44 | 88.66 / 83.59 | 96.44 / 93.38 | 2.68 / 2.53 | 81.29 / — | 93.66 / — |
| Controller | 74.16 / 69.13 | 88.58 / 83.54 | 96.18 / 93.11 | 95.06 / 92.03 | 81.36 / — | 93.33 / — |
| Callbacks | 88.67 / 85.20 | 99.23 / 99.23 | 97.29 / 94.72 | 0 / 0 | 93.72 / — | 98.42 / — |
| Active Record / Active Model | 71.11 / 66.17 | 88.23 / 83.32 | 96.08 / 92.99 | 0 / 0 | 79.94 / — | 93.10 / — |
| Action View / templates | 70.82 / 65.90 | 88.18 / 83.26 | 96.06 / 92.97 | 85.09 / 83.22 | 80.07 / — | 93.13 / — |
| JSON | 6.18 / 5.27 | 3.37 / 2.93 | 73.67 / 69.57 | 0 / 0 | 0.19 / — | 0.22 / — |
| AS instrumentation | 64.74 / 60.31 | 87.79 / 82.95 | 95.93 / 92.85 | 55.53 / 50.10 | 78.04 / — | 92.60 / — |

Example: Shipit has JSON on 73.67% of interpreter instruction stacks but only 0.47% assigned to JSON itself.
Its generator invokes model serialization; the work occurs largely in Active Record/Active Model. Likewise
instrumentation enclosing nearly all a request does not mean instrumentation itself consumes nearly all CPU.

## Per-request quantities and A/A

Ir and objects below are divided by the **actual route count**, not the ruby-bench iteration count. Erubi is
per render. Allocation figures are A's Callgrind window and include small observer/batch overheads; native
allocation values and each AA are also in the receipt. These are baseline quantities, not candidate savings.

| Workload | Ir/unit I, A → AA | A/A | Ir/unit YJIT, A → AA | A/A | Objects/unit I / YJIT |
|---|---:|---:|---:|---:|---:|
| railsbench | 2,563,211.6 → 2,564,925.5 | +0.067% | 1,430,800.2 → 1,429,537.9 | −0.088%, not flat | 482.64 / 485.32 |
| lobsters | 29,304,177.8 → 29,310,216.3 | +0.021% | 18,740,751.4 → 18,799,432.9 | +0.313%, not flat | 4,694.97 / 4,726.25 |
| shipit | 102,414,645.9 → 102,428,149.3 | +0.013% | 52,665,821.8 → 52,664,511.9 | −0.002%, not flat | 15,573.40 / 15,802.32 |
| erubi-rails | 635,775.5 → 635,280.9 | −0.078% | 376,180.1 → 375,751.6 | −0.114%, flat | 162.00 / 164.00 |
| Blog/Puma | 9,162,157.2 → 9,158,771.7 | −0.037% | — | — | 1,945.20 / — |
| Writebook/Puma | 45,583,877.2 → 45,574,108.8 | −0.021% | — | — | 8,337.15 / — |

YJIT compilation block deltas across measured endpoints, **A / AA**:

| Workload | Callgrind | Native perf | Native samples/unit A / AA | Largest native layer-share drift |
|---|---:|---:|---:|---|
| railsbench | 19 / 0 | 9 / 0 | 0.4104 / 0.4381 | 0.57 percentage points, AR |
| lobsters | 7 / 0 | 413 / 365 | 5.0417 / 5.0544 | 1.02 pp, AR |
| shipit | 3 / 9 | 165 / 454 | 17.2904 / 16.6868 | 1.26 pp, AR |
| erubi-rails | 0 / 0 | 0 / 0 | 0.0541 / 0.0505 | 1.05 pp, GC |
| Blog/Puma | — | 76 / 15 | 1.8730 / 1.7548 | 3.73 pp, Puma |
| Writebook/Puma | — | 345 / 241 | 7.6680 / 7.7008 | 2.86 pp, kernel |

The native YJIT sample counts are respectively **16,418 / 17,525**, **11,495 / 11,524**, **19,711 / 19,023**,
**10,822 / 10,108**, **18,730 / 17,548**, **76,680 / 77,008**. None loses samples. Interpreter native A loses
9 / 218 / 123 samples in railsbench / Shipit / Writebook; all other interpreter cells and all AA lose zero.
Losses and the noisy server boundary prohibit small native comparisons. Native sample totals are **not a
passing wall-time A/A**. There is no timing claim, and these are not admissions under the finite ±0.1% request
protocol. Every instruction partition reconciles; no instruction samples are empty, dropped or truncated.

## Largest uncovered costs and candidate decision

There is no defensible fleet-wide top three without traffic weights: Shipit is AR-heavy, Lobsters spends much
more in SQLite, and the small Blog endpoint exposes server overhead. These are the three large **non-Rails
follow-up targets**, rather than another ranking of already-worked Rails lines. GC is recorded separately.

| Target and reach | Evidence | Is an exact upstream change plausible? | Decision |
|---|---|---|---|
| **SQLite engine/driver**: every executed query in all five request workloads | 4.36–14.94% native YJIT CPU; Lobsters' native leaves include `sqlite3BtreeTableMoveto`, `sqlite3VdbeExec`, `walFindFrame`, and mutexes. Its instruction `Statement#step` includes actual SQL execution and value conversion. | Possibly in sqlite3-ruby or SQLite, but this profile does not isolate redundant driver work. Query/planner changes would be app-specific. | **No candidate.** Older ruby-bench sqlite3 2.7.3 also predates our merged [#758](https://github.com/sparklemotion/sqlite3-ruby/pull/758); do not resubmit the completion-array change. Current main still constructs each required row/value. |
| **Puma/kernel request boundary**: every real HTTP request, especially small endpoints | Blog A / AA: Puma 7.76 / 11.49%, kernel 10.19 / 6.61%; Writebook A: 2.13 / 2.73%. Mock requests miss this boundary entirely. | Possibly in Puma's parser/header/write path, but the broad bucket and 3.73 pp A/A movement do not identify an exact removable operation. Kernel includes profiler/interrupt and scheduling work. | **No candidate.** Need a focused server-path attribution before promising a whole-request effect. No kernel or VM patch inferred from a layer total. |
| **Rack ETag hashing**: Rails' default middleware, cacheable 200/201 bodies without an existing validator | `digest_body`: 3,069/43,673 = **7.03%** of railsbench and 4,242/32,598 = **13.01%** of Lobsters YJIT instruction samples (both diagnostic pairs). Native SHA-256 transform alone is **289/11,495 = 2.51%** of Lobsters A CPU samples; Blog AA **306/17,548 = 1.74%**. | **Yes, Rack:** use accelerated OpenSSL SHA-256 when already loaded, preserving the digest and lazy dependency behavior. | **Do not duplicate.** Open [rack/rack#2522](https://github.com/rack/rack/pull/2522), head `97ace17c00381f3e42e1930e87d4c7a04ec12d9c`, already implements exactly that lead. It is another contributor's work, not a candidate built here. |

**GC/VM evidence only.** GC is 6.07% / 5.07% / 9.64% / 12.27% / 6.00% / 6.54% of the native YJIT A samples.
Allocation/dispatch/malloc leaves are prominent too. This establishes CPU mass, **not a GC regression or a
particular Ruby bug**. No ruby/ruby change, branch, issue or PR was made.

Other rejected leads, one line each:

* **concurrent-ruby map lookup:** 5.48% erubi native CPU / 6.31% sampled YJIT instructions, but current
  `get_or_default` is already one `Hash#fetch`; erubi's hot caller is `DetailsKey.details_cache_key`, hashing the
  structural details key. A cache/identity shortcut would need mutation/Ractor semantics and a whole-benchmark
  win, not just fewer allocations. No exact gem change identified.
* **Action View details/format/output-buffer work:** already in [Action View CPU work](actionview-cpu.md) and the
  census records; not a newly discovered outside-Rails candidate, and new Rails items are held unless urgent.
* **HTMLEntities, TZInfo and YAML:** visible in Lobsters, but no broad exact new operation established; no niche
  micro-PR or per-call-only build under the reach rule.
* **JSON native optimization:** only 0.22–0.68% native YJIT samples on the request benchmarks here; Shipit's high
  inclusive serialization share is mostly model work, not evidence for a native JSON rewrite.
* **Shipit/Rails-main boot compatibility:** known setup failure, recorded and existing adapter reused; excluded
  from this performance-only round.

### Overlap search

Read [merged-sum](merged-sum.md), [contributions](contributions.md), [census backlog](census-backlog.md), census 7/8
and Action View CPU records before selecting leads. Inspected canonical current-main snapshots of Rack
`da90464e3fa93e3cb49dc2d4ede798e6c6b70b4f`, concurrent-ruby `cdb9082c494aa597c439c85ded4969cb2150e37c`,
sqlite3-ruby `48091f4694f4f1d6b6cf7b92991aac4be3ce3ec0`, and Puma
`c0df0c19dde943c3f5c25cd67caa984dfa84e3da`.
Searched open/closed PRs for ETag/digest/SHA256, map/fetch/get_or_default/compute_if_absent,
Statement/step/column_count/performance, Puma response/header performance and Rails details_cache_key.
Relevant results besides #2522: SQLite [#758](https://github.com/sparklemotion/sqlite3-ruby/pull/758) already merged;
[#528](https://github.com/sparklemotion/sqlite3-ruby/pull/528) is a GVL-release proof of concept, not evidence for
less single-thread CPU; concurrent-ruby [#1109](https://github.com/ruby-concurrency/concurrent-ruby/pull/1109)
already handles Ractor compute-if-absent. Search receipts are retained privately. No post/search result is
treated as proof of exactness or savings.

There is consequently no candidate `impact`/review record to fabricate and no head for skeptic/Sol/Astra.
If a follow-up isolates an exact large operation, it must first measure whole-workload instructions and a
YJIT number with A/A, state reach in `impact`, run differential boundary probes, and obtain exact-head reviews.

## Reproduction and checks

The [adapters and analyzer](../../bench/upstream/stack_map/) reuse census boot/fixtures, census 8's sampler,
`HeapWindows.prepare_heap` and ruby-bench's own blocks; they do not substitute synthetic controller work.
`ruby_bench.rb` adds an optional raw-stack export to the existing census harness. The sampler gains start/finish
around a Puma worker window; the original block API remains. A real patched-Callgrind probe passed block mode,
cross-thread start/finish, exception cleanup, interval rejection and sample reconciliation.

On prepared copies with the pins above:

```sh
export PATH="$HOME/.local/share/mise/installs/ruby/4.0.9/bin:$PATH"
ruby script/cpu-census build --prefix "$PWD/.lowrail/private/stack-map/valgrind"
export VALGRIND_PREFIX="$PWD/.lowrail/private/stack-map/valgrind"
export CENSUS_CPU_EXT="$(ruby -e 'load "./script/cpu-census"; puts CpuCensus.extension(File.dirname(RbConfig.ruby), ".lowrail/private/stack-map")')"
# Existing ruby-bench/census setup instructions above supply bundles and fixtures.
bash bench/upstream/stack_map/run-ruby-bench.sh railsbench interpreter callgrind a
bash bench/upstream/stack_map/run-ruby-bench.sh railsbench interpreter callgrind aa
bash bench/upstream/stack_map/run-ruby-bench.sh railsbench yjit perf a
bash bench/upstream/stack_map/run-ruby-bench.sh railsbench yjit perf aa
```

Repeat the finite pair for each benchmark/mode/counter; never overwrite a result or replace a failed arm.
The recorded sampler caches were ruby-bench `sampler-156a2dffe0d5` and Puma `sampler-25278fbc9ff9`.
The command above builds/selects the current source-keyed extension, not a claim to recreate the old binary.
Server launch is through supervised `amp orb service start`, command
`bash ABSOLUTE_ROOT/bench/upstream/stack_map/start-puma.sh APP MODE COUNTER LABEL` and a chosen `--port`.
Once its `.json.info` exists, run `STACK_MAP_BATCH=500 ruby bench/upstream/stack_map/puma_client.rb OUTPUT_JSON`
outside the server (20 for Callgrind). Stop the service after the result; the supervisor otherwise restarts it.
These are measurement servers, not public application previews. No service remains running from this task.

Analyze completed profiles serially with `ruby bench/upstream/stack_map/report.rb perf PROFILE.json.perf`, or
`ruby bench/upstream/stack_map/report.rb ruby PROFILE.json.stacks`; save beside each as `PROFILE.layers.json`.
Perf files created by sudo need ownership transferred to the measuring user before the receipt exporter can
hash them. Export with `ruby bench/upstream/stack_map/export.rb PRIVATE_DIRECTORY OUTPUT_JSON`.
The final export reports **44 windows; every exclusive partition reconciles**. Syntax checks for all Ruby and
shell adapters and `git diff --check` pass. All 20 instruction windows have zero empty/dropped/truncated stacks.
The Callgrind logs contain no brk-overflow warning. The decoder crash is retained separately, not suppressed.

Tool SHA-256: Callgrind `1bf396db827bd5c7ff29beab07ffa1412d4673d36e3f1a7726ea18803b306960`;
original sampler `ec88e9b06748213b953a1460831c20fd5c35932ed64b4c91845be0a88270123b`;
async sampler `0ac6b29b459c728b3cdc817451f771054e76a34b204ea3386de34530c7bd8be2`.
The underlying tool is Valgrind 3.19.0 plus the existing census 8 instruction-sampling/512 MiB brk patch.

**Still needed for the original full-map goal:** a PostgreSQL request cell; complete JIT-aware virtual-stack
unwinding or an independently validated bridge; separately observable side-exit cost; actual window heap
snapshots; and a prospectively specified stationary, non-compiling cohort. These gaps do not authorize
compatibility work, a Ruby VM PR, or retrying these rejected pairs until green.
