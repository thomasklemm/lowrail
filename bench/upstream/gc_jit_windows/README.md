# Compiles in GC windows, and GC in `--wall` (2026-11-27)

Follow-up to [wall_noise](../wall_noise/README.md), which found YJIT 4.0.10 compiling blocks in 57 of 640 warm timed
windows with GC on (45 of them with a GC) and none with GC off, and which made `script/upstream-bench --wall` measure
with GC off. Three questions: why compiles line up with GC, whether that costs anything in production, and what GC
off leaves out of `--wall`. Every number below comes from the runs in this directory; the method and the decisions are
in [bench.md](../../../docs/bench.md#gc-in-wall-windows-and-the-compiles-it-triggers-2026-11-27).

Rubies: current master `0d399335b7` (2026-11-27, ZJIT and YJIT), the wall_noise pin master `42a644f6e0` (ZJIT) and
4.0.10 `a704b7cd95` (YJIT). Rails main `088fc0cf61`; ruby-bench `43d41e22d7` (railsbench and lobsters on their locked
Rails 8.1.4.1). One a1.xxlarge orb (16 vCPUs). The counting runs (parts 1 and 2) ran up to 12 processes at once,
each pinned to its own core: compile and exit counts barely depend on timing, but the times and per-object GC costs
from these runs come from contended processes, not isolated timing. The timed cohorts (part 3) ran alone on
core 1 with its SMT sibling idle.

`study-2026-11-27.tar.gz` (directory `gcjit/`) holds every script and every process record (JSONL): `attr.rb` (the
E2 worker with per-window JIT counters, compiled ISEQ names and per-call GC/compile sampling), `adrive.rb`, `orig/`
(the wall_noise worker with window timestamps and the YJIT compile log), `rb_harness.rb` (a ruby-bench harness with
the same bookkeeping per iteration and per request), `an.rb`, `rban.rb`, the run scripts (`rep.sh`, `trig.sh`,
`rbrun.sh`, `rbstats.sh`, `lobsters-long.sh`, `validate.sh`, `build.sh`) and the analysis outputs (`data/an-*.txt`,
`data/rban-*.txt`). Data files: `rep.jsonl` and `orig.jsonl` (reproduction), `trig.jsonl` (triggers), `rb.jsonl`,
`rbstats.jsonl` and `lobsters-long.jsonl` (ruby-bench); the last two drop ZJIT's per-ISEQ `iseq_calls_count_*` stats
to fit.

## 1. Cause: GC-time finalization interrupts JIT code, and YJIT compiles the interpreter entry it then needs

**Reproduction.** The wall_noise worker reproduces on 4.0.10 YJIT: 26 of 320 windows compiled, 24 of them with a GC
(22 of 320 without the compile log). It doesn't reproduce on current master: 0 of 320 under YJIT, 0 of 320 under
ZJIT. A clean worker that reads no files in its windows compiles in no window at all, GC on or off, on every Ruby:

| worker, 16 processes × 20 windows × 200 calls, GC on | ZJIT master | ZJIT pin | YJIT master | YJIT 4.0.10 |
| --- | --- | --- | --- | --- |
| wall_noise worker (reads `/proc` files in every window) | 0 / 320 | – | 0 / 320 | 26 / 320 (24 with GC) |
| clean worker | 0 / 320 | 0 / 320 | 0 / 320 | 0 / 320 |
| clean worker + one `File.read` per window | 0 / 320 | 0 / 320 | 0 / 320 | 33 / 320 (20 with GC) |
| clean worker + one `ObjectSpace` finalizer per window | 1 / 320 (1 with GC) | 0 / 320 | 29 / 320 (29 with GC) | 26 / 320 (17 with GC) |
| clean worker, GC off per window | 0 / 320 | 0 / 320 | 0 / 320 | 0 / 320 |

Cells are windows whose compile counter moved (`compiled_iseq_count` for ZJIT, `compiled_block_count` for YJIT).
No window in any run moved an invalidation counter (YJIT `invalidation_count` and every `invalidate_*`; ZJIT
`invalidation_time_ns`, the only invalidation stat master has).

**Mechanism.** Objects that need deferred finalization (an `ObjectSpace` finalizer, a `T_DATA` without
`RUBY_TYPED_FREE_IMMEDIATELY`, and on 4.0.10 every `File`) become zombies when GC sweeps them, and GC registers a
postponed job that sets the interrupt flag. JIT code checks interrupts at sends, returns and backward branches and
side-exits there, so the rest of that frame runs in the interpreter, and every method it calls is entered from the
interpreter. Under YJIT that entry needs code of its own: an ISEQ entry, compiled once the method's interpreter-entry
counter `jit_entry_calls` reaches the call threshold (30, or 120 with more than 40,000 ISEQs; `vm.c` `yjit_compile`),
reusing an existing block 0 version where one fits. So an entry may compile some calls after the exit that started
the count. With `--yjit-stats` the chain is in the counters:

* 4.0.10, one `File.read` per window: 123 interrupt side exits (`leave_se_interrupt` 60, `guard_send_interrupted`
  50, `branchif_interrupted` 13), 93 of them in GC windows, and 23 `compiled_iseq_entry`; without the read, 0 and 0.
* master, one finalizer per window: 99 interrupt exits, all in GC windows, and 12 `compiled_iseq_entry`.
* The compiled blocks belong to methods that were hot for thousands of calls (`table_structures`,
  `table_info_pragma`, `block in build_foreign_keys`, `Instrumenter#start!`, `Fanout#start`, `quote`); 40 of 120
  (master, finalizer) and 40 of 86 (4.0.10, `File`) are block 0, the rest later blocks of the same methods.

Master doesn't reproduce with a `File.read`, because it frees an already closed IO immediately (ruby/ruby commit
`9c2ca0e1b7`, "Free already closed IO immediately", 2026-05-28); 4.0.10 makes every swept `File` a zombie. The
wall_noise worker read `/proc/stat` and `/proc/self/status` in every window, and that was its trigger.

**Why GC and compile only loosely coincide.** Per-call sampling places each compile relative to the GC. With a
finalizer on master, 15 of 31 compile events fall in the very call whose allocation started the GC and the other 16
within the next 21 calls (presumably further methods entered from the frame that finishes in the interpreter).
On 4.0.10, 24 of 33 (`File`) and 21 of 27 (finalizer) fall more than 50 calls after the GC or in a window with no
GC before them. Two explanations fit and the sampling (GC count and compile count per call, no sweep, finalizer or
interrupt timestamps) can't separate them: lazy sweeping reaches the zombie later, and the entry counter needs
further interpreter entries before it hits the threshold. That is why
wall_noise saw 79% of compiling windows overlap a GC against 61% of all windows, not 100%.

**ZJIT.** ZJIT takes the same exit: with a finalizer per window, master logged 30 `exit_interrupt`, all in GC
windows, and none without. An ISEQ ZJIT already compiled doesn't compile again afterwards, because its interpreter
entry (`start_ptr` in `IseqCodePtrs`) exists from the first compile. The one compile in 320 windows was
`build_foreign_keys`' first: a method that had only run inlined reached the call threshold from the interpreter
after such an exit. What the exit itself costs (materializing frames, finishing the frame in the interpreter) was not
measured.

Other candidates, checked: GC-triggered invalidation (no invalidation counter moved in any window, shapes and
constant caches included); code GC or exec memory pressure (YJIT 4.0 has no code GC without `--yjit-code-gc`;
`code_gc_count` and `freed_page_count` stayed 0; ZJIT `compile_error_out_of_memory` 0); finalizer code itself being
compiled (the compiled ISEQs are Rails methods, not the finalizer procs); lazy paths that run only after a GC (none:
every compiled block is an entry of an already hot method).

## 2. Production: no GC-driven recompiles found under ZJIT, a warm-up cost under YJIT

ruby-bench railsbench (2,000 requests per iteration) and lobsters (114 requests per iteration), 40 iterations, the
first 15 not counted, 3 processes per configuration (A/A), `rb_harness.rb` counting per iteration and per request.
GC off means `GC.start`, then GC off for each iteration. Per 1,000 requests, one value per process:

| app | config | GCs | compiles (GC on) | compiles (GC off) | invalidations | JIT-flat iterations (GC on) |
| --- | --- | --- | --- | --- | --- | --- |
| railsbench | ZJIT master | 5.2 / 4.9 / 5.1 | 0.02 × 3 | 0.02 × 3 | 0 | 24/25 × 3 |
| railsbench | ZJIT pin | 5.0 / 5.1 / 5.0 | 0.02 × 3 | – | 0 | 24/25 × 3 |
| railsbench | YJIT 4.0.10 | 4.9 × 3 | 1.00 / 0.98 / 0.98 | 0.98 × 3 | 0 | 23/25, 24/25, 24/25 |
| lobsters | ZJIT master | 7.4 × 3 | 17.2 / 17.5 / 17.5 | 17.2 × 3 | 0 | 8/25, 8/25, 7/25 |
| lobsters | ZJIT pin | 7.7 / 7.4 / 7.4 | 16.8 × 3 | – | 0 | 9/25 × 3 |
| lobsters | YJIT master | 7.7 × 3 | 1,425 / 1,463 / 1,482 | – | 0 | 2/25, 3/25, 2/25 |
| lobsters | YJIT 4.0.10 | 8.1 × 3 | 1,440 / 1,491 / 1,484 | 1,417 × 3 | 0 | 5/25, 3/25, 6/25 |

Railsbench is steady: under ZJIT the two compiles left per process are driver code that runs once per iteration
and reaches the call threshold late (the harness's `Time.now` in iteration 24, the benchmark's iteration block in
29), and YJIT's one per 1,000 requests is the harness's own sampling block. No Rails or app ISEQ compiled.
Lobsters is still warming up at 1,700–4,560 requests: ZJIT compiles fall from 3,192 in the first iteration to 0–1
per iteration after the 33rd, identically with GC on and off. Its repeated template ISEQs (`rss.erb` in iterations 15,
24 and 32) are new template ISEQs with new names, and the `ccall_exit_recompile` (576 over 3,420 requests) and
lead-20 exits (`exit_patchpoint_method_redefined`) have the same counts GC on and off, so they are not GC's. YJIT
4.0.10 with GC on adds 23–74 blocks and 2.8–9.5 ISEQ entries per 1,000 requests over GC off (50.2): the entries of
part 1. A rough price, mixing runs: the stats run's 42–47 µs per block gives 1–3.5 ms per 1,000 requests, about
0.02–0.05% of lobsters' time; the counting run's own `compile_time_ns` is 88–91 µs per block with GC on, which
doubles that. It is a heuristic, not a measurement.

Interrupt exits with stats on (2 processes, GC on / off):

```diff
 lobsters, ZJIT master, per 1,000 requests (iterations 15–29)
-exit_interrupt:            0.00 /  0.00   (GC off)
+exit_interrupt:            7.60 /  6.43   (GC on, 7.6 GCs)
 compiled_iseq_count:      21.64 / 21.64   (both)
 invalidation_time_ns:         0 /     0   (both)
 side_exit_count:        84,307 / 84,314   (off / on)
```

Railsbench has no interrupt exits under ZJIT with GC on. YJIT 4.0.10 on lobsters had 50.3 / 48.5 interrupt exits
per 1,000 requests, against ZJIT master's 7: 4.0.10 also defers every swept `File`.

Because lobsters was still warming up, it ran again for 120 iterations (13,680 requests), counting iterations
60–119 (6,840 requests per process), 2 processes per configuration:

| config | GCs / 1k | compiles / 1k, GC on | compiles / 1k, GC off | last 10 iterations, on / off | invalidations |
| --- | --- | --- | --- | --- | --- |
| ZJIT master | 7.5 | 0.29 / 0.44 (stats run: 0.44 / 0.29) | 0.15 / 0.15 | 0 / 0 | 0 |
| YJIT master | 7.6 / 7.8 | 25.9 / 28.2 blocks | – | 121 / 94 | 0 |
| YJIT 4.0.10 | 8.2 / 7.9 | 29.2 / 26.8 blocks, 2.8 / 1.8 ISEQ entries | 13.2 / 13.2 blocks, 1.5 / 1.5 entries | 93 / 90 against 55 / 55 | 0 |

This is a late-run sample, not a proven steady state. ZJIT compiles 2–3 ISEQs per 6,840 requests with GC on and 1
with GC off: a `_recent.html.erb` template in iteration 65 in every process, GC on or off (the template ISEQ is
rebuilt every 17 iterations, at 14, 31, 48 and 65, in every process; that is lobsters' Action View, not GC), and 1–2
more per GC-on process (`MessageEncryptor`,
`Preloader`, psych `TreeBuilder`), each the first compile of a rarely called method: two of them 6 and 17 requests
after a GC, one in an iteration without a GC. Nothing compiles in the last 10 iterations, nothing invalidates. The
stats run gives the exit counts (two processes each, GC off then GC on):

```diff
 lobsters, ZJIT master 0d399335b7, iterations 60–119, 6,840 requests per process
-exit_interrupt:           6 / 0          (GC off; presumably from the GC.start before an iteration)
+exit_interrupt:          48 / 53         (GC on, 51 GCs each)
-compiled_iseq_count:      1 / 1
+compiled_iseq_count:      3 / 2
 invalidation_time_ns:     0 / 0          (both)
-side_exit_count:    576,306 / 576,300
+side_exit_count:    576,348 / 576,353
```

So in this sample GC adds about 50 interrupt exits and 1–2 first compiles of rare methods per 6,840 requests, and no
GC-dependent repeat compile or invalidation was found under ZJIT. The count doesn't price the exits: what each one
costs (materializing frames, finishing in the interpreter) was not measured. YJIT is not steady at 13,680 requests
either way (55 blocks per 1,000 requests in the last 10 iterations even with GC off), and part of the GC-on excess
there is the harness's own blocks (60 in iteration 119 of each GC-on process, from `rb_harness.rb`'s sampling); GC
on adds 0.3–1.3 ISEQ entries per 1,000 requests over GC off.

A census app was not run: setting one up on Rails main for counting would cost more than the two ruby-bench apps
already show (no GC-driven repeat compiles under ZJIT in either sample).

## 3. `--wall` and GC

**What GC off leaves out.** GC work per allocated object, from `GC.stat[:time]` over `total_allocated_objects`
in GC-on windows and iterations: E2's micro 32 ns on master (`z-base` of wall_noise's round 1; 82 ns on 4.0.10,
`y-base`), railsbench 57–58 ns and lobsters 53 ns on master, 66–68 ns on 4.0.10 (part 2's processes, run
concurrently). These are total GC time over total allocations, averages, not the marginal saving of one object.
GC is 0.9% of the micro's time under ZJIT and 5.5–6.8% of railsbench's. E2's 7 objects per call are therefore about
0.2–0.5 µs of GC, 0.03–0.07% of its 0.69 ms call: GC off hides nothing a cohort could resolve there. It matters for
short calls: at 60 ns per object, saving 2 objects would be about 6% of a 2 µs call, if the average held at the margin.

**A GC-on mode, tried and not kept.** [wall-gc.diff](wall-gc.diff) adds `--wall-gc` to `script/upstream-bench`:
GC on in every window, no heap floors, and each process's mean window instead of its 10th-percentile one (a low
quantile would pick the GC-free windows). Validated as wall_noise was, 30 rounds each, E2's micro, Rails main
against a second checkout of main (`aa`), [wall_noise's plant](../wall_noise/plant.diff) (`plant`, 150 `Integer#to_s`
per call) and the same with 75 (`plant75`):

| run | mode | GC | candidate | change [95% CI] | A/A [95% CI] | verdict |
| --- | --- | --- | --- | --- | --- | --- |
| `zjit-gc-aa` | ZJIT master | on | A/A | +0.1% [−2.2%, +1.6%] | −2.4% [−3.7%, +0.1%] | no claim |
| `zjit-gc-plant` | ZJIT master | on | plant (150) | +3.9% [+1.6%, +7.2%] | −3.3% [−5.6%, +1.6%] | claimed |
| `zjit-gc-plant75` | ZJIT master | on | plant75 | −0.4% [−0.9%, +2.3%] | +0.1% [−1.7%, +2.7%] | no claim |
| `zjit-plant` | ZJIT master | off | plant (150) | +1.5% [+1.0%, +2.0%] | −0.4% [−1.0%, +0.1%] | claimed |
| `yjit-gc-aa` | YJIT master | on | A/A | +0.1% [−2.1%, +2.6%] | +1.6% [+0.2%, +4.9%] | A/A excludes 0, no claim |
| `yjit-gc-plant` | YJIT master | on | plant (150) | +2.2% [+0.5%, +3.8%] | −0.5% [−1.6%, +1.4%] | claimed |
| `y4010-gc-aa` | YJIT 4.0.10 | on | A/A | +0.5% [−1.1%, +2.4%] | −0.2% [−2.3%, +2.0%] | no claim |
| `y4010-gc-plant` | YJIT 4.0.10 | on | plant (150) | +1.6% [+0.0%, +3.4%] | +0.2% [−2.7%, +6.4%] | claimed |

wall_noise's GC-off plant on the pinned master and 4.0.10 gave +1.3% [+0.7%, +2.2%] (ZJIT) and +1.2% [+0.3%, +2.0%]
(YJIT 4.0.10). Each directory has `table.md`, `results.json` and `commands.sh`; process logs are in
`raw-2026-11-27.tar.gz`.

Every cell was JIT-flat in all 90 processes, YJIT 4.0.10 included: the tool's worker reads no files, so part 1's
trigger is absent. With GC on the intervals are 3–9 points wide against about 1 with GC off, one A/A failed
(YJIT master), and the 4.0.10 plant was claimed with its lower bound at +0.0%. So the mode resolves about 3–4%,
not the ~1% of a planted regression: the 75-string plant (about 0.5% of
work plus 0.3–0.6% of GC) is missed. The 150-string plant shows the GC share exists (+3.9% against +1.5% GC off),
but its interval can't price it: anything from about 5 to 280 ns per object fits. Only the ratios compare across
modes: the base's time per call (729–758 µs GC on, 688 µs GC off) also differs by estimator, mean against 10th
percentile. The estimator also has a blind spot: per-process means go into an outer median of round ratios, so a GC
cost that lands in a minority of processes is dropped. With the tool's own `wall_cell`, 30 rounds of equal windows
and one 7× window in 9 of the 30 candidate processes (+6% total cost) give 0% [0%, 0%]. So `--wall-gc` failed the
bar for a tool change and is not in the tool; the cohort directories were run with the diff applied, and their
`commands.sh` need it. Their `results.json` `heap` field still lists the heap floors, which the diff unset for the
wall workers (it applies to the objects pass only).

All of this is one workload, E2's `foreign_keys` micro: 3–4% is what a GC-on cohort resolved here, not a floor for
every workload.

**Proposals** (in bench.md, body-numbers.md and DECISIONS' Evidence bullets):

1. `--wall` stays GC off. It measures the work a change does; it is the only mode that resolves ~1%.
2. An allocation-reducing change claims its objects per call (the objects pass, exact, deterministic). The record
   may add an illustrative GC figure, Δobjects × the average GC time per object of a named heap (about 50–70 ns on
   railsbench and lobsters here), stating Ruby, JIT and heap; it is an average, not a measured saving, and never
   time in a body.
3. Wall time with GC on is claimed only from a GC-on cohort whose own A/A passes and whose change interval excludes
   0, with the estimator's blind spot for sparse GC named; this record's 3–4% is one workload's resolution, not a
   threshold.
4. Timed windows never read files, open IO or create finalizable objects (part 1's trigger). `upstream-bench`'s
   worker doesn't; any hand-written harness checks this.
5. The JIT-flat gate stays as it is. With GC off it hides GC-triggered interrupt exits and YJIT's entry compiles;
   part 2 found no GC-dependent repeat compiles under ZJIT, but the exits' cost is unmeasured, so this is not a claim
   that GC off hides nothing.
