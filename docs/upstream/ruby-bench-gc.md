# Making GC cost measurable in ruby-bench (2026-11-05)

**Trigger.** We closed ruby/ruby#19685 ("ZJIT: Mark each JITFrame ISEQ once per GC") because `run_benchmarks.rb`
showed nothing beyond noise. Under Callgrind, though, it cuts `rb_zjit_root_mark` from 28.5 M to 2.0 M instructions per
railsbench iteration, which is −0.64% of the iteration. On the closed PR tekknolagi wrote
([comment](https://github.com/ruby/ruby/pull/19685#issuecomment-6664809433)): "we should try to measure GC time on
benchmarks because it *does* matter at scale". Today, a change that cuts GC work without touching mutator work is
invisible in ruby-bench. This page asks what ruby-bench should add so that such a change can be measured and compared.

**Recommendation.** Two small draft branches on our fork, both unopened:

1. [`thomasklemm/gc-time-by-collection-type`](https://github.com/thomasklemm/ruby-bench/tree/thomasklemm/gc-time-by-collection-type).
   On Ruby 4.1+, `--harness=gc` records the marking time of each minor and each major GC from `GC::Profiler`.
   The GC tables show the mean marking time of one minor and of one major collection.
2. [`thomasklemm/gc-harness-average-precision`](https://github.com/thomasklemm/ruby-bench/tree/thomasklemm/gc-harness-average-precision).
   `harness/gc.rb` printed its marking and sweeping averages with Integer division; this prints them unrounded.

Also:

* For #562, write XrXr a proposal; don't open a competing PR.
* Report a rubybench parsing hazard to the coordinator, who decides who fixes it.

Rejected: GC recording in the default harness, a forced-GC probe as a metric, per-allocation or per-live-slot
normalisation, a least-squares split, and Callgrind or perf harnesses. The reasons are [below](#rejected-options).

**Why.** Marking time per collection is the only metric that showed #19685 clearly on all three benchmarks and
stayed flat when the patch's code didn't run.

* **This orb:** −54 / −9 / −28% on railsbench / lobsters / shipit, with ZJIT. Every round agrees.
* **U3's 8-vCPU orb, on newer master:** −44 / −11 / −15%.
* **A/A:** within 9% everywhere.
* **Iteration time, GC time per iteration and wall − GC:** none of them separate the patch from the A/A.

The data is already in the process: Ruby 4.1's `GC::Profiler` records `GC_MARK_WALL_TIME` and `major_by` for each
collection (ruby/ruby#17431, eightbitraptor). So the change lives in the harness ruby-bench already has for GC, and
on Ruby 4.0 its output stays as it is.

## Branches and state

| branch | head | fork PR (CI only) | CI |
|---|---|---|---|
| `thomasklemm/gc-time-by-collection-type` | `c18af102db` | thomasklemm/ruby-bench#12 | queued at the time of writing, behind 42 queued runs on thomasklemm/ruby |
| `thomasklemm/gc-harness-average-precision` | `23f47c96b3` | thomasklemm/ruby-bench#13 | same |

Both branches are one commit on ruby-bench main `00f0f8b`. Locally, the full test suite passes on master 9b30fd2
(353 runs; the only error is the rmagick graph test, which also fails on main here). Draft bodies:
[collection type](../../bench/upstream/ruby_bench_gc/collection-type-body.md),
[average precision](../../bench/upstream/ruby_bench_gc/average-precision-body.md). Nothing is opened upstream.

## What exists upstream

* **`--harness=gc`** (eightbitraptor, #488, #489, #517, 6364711, #558). Per iteration it records deltas of
  `GC.stat(:marking_time)` and `GC.stat(:sweeping_time)` (whole ms), `GC.total_time` (ns), minor, major and global
  counts, and heap deltas. `lib/results_table_builder.rb` turns them into:
  * a "GC summary" table for a single ruby;
  * "GC time ratios" (`gc/iter`, `gc/GC`, `mark/iter`, `mark/GC`, …) and "GC counts" tables for comparisons.

  `mark/GC` divides by minor and major collections together, so one major GC (about 20–60 ms) outweighs ten minor
  ones (0.3–8 ms).
* **ruby/ruby-bench#562** (XrXr, draft). `misc/zjit_diff.rb` prints "BENCHMARK TIMINGS WITHOUT GC TIME": iteration time
  minus `gc_marking_time_bench + gc_sweeping_time_bench`, for results recorded with `--harness=gc`. Thread R5's
  findings ([thread](https://ampcode.com/threads/T-01a1accc-4131-728a-87e0-c815ddc00d8f)):
  * The CI failure comes from the WIP second commit 211380e5f3, not from the zjit_diff commit, which passed CI on its
    own.
    * It calls `RubyVM::ZJIT.stats(:side_exit_count)` without checking that ZJIT is there and enabled. That fails when
      ZJIT is off (the stat is nil), on Windows (no `RubyVM::ZJIT`), on TruffleRuby (no `RubyVM`), and on 4.0.9 even
      with `--zjit` unless `--zjit-stats` is set.
    * Its delta subtracts the previous delta instead of the previous total: [95, 1, 96, 2, 98] instead of [0, 1, 1, 1, 2].
    * gcbench and string_malloc_pressure fail the same way.
  * The ms fields are truncated cumulative values. Per iteration, mark + sweep minus `GC.total_time` is −1.3 to
    +1.5 ms out of 150–240 ms of GC (gcbench). `gc_total_time_bench` is already recorded in ns.
  * GC time is CPU time. On 4.0 it is process CPU time, so other Ractors' work leaks in. On master it is the
    collecting thread's CPU time.
* **ruby/ruby-bench#541** (eightbitraptor, open). Adds a "GC per ruby" table with the absolute GC summary columns for
  each ruby in a comparison. Any column added to the GC summary therefore shows up there as well.
* **ruby/ruby-bench#539** (luke-gruber, open). `gc_balloon` benchmark for the Ractor harness. Not related to timing.
* **rubybench** (`rubybench/rubybench`, the published site). Its runner runs
  `./run_benchmarks.rb BENCH [--warmup=30] -e 'ruby [--yjit|--zjit]'` and reads one number per benchmark and
  configuration from stdout: the last line that starts with the benchmark name, second column
  (`find_benchmark_line`). It also reads `RSS:`. It ignores the results JSON. The ruby-bench submodule is pinned at
  17dcac9 (2026-09-17).

### The rubybench hazard (verified, not posted)

ruby-bench 6364711 (2026-10-07) prints a "GC summary" table for single-ruby runs. That table's rows also start with
the benchmark name. For the two `default_harness: gc` benchmarks, gcbench and string_malloc_pressure,
`find_benchmark_line` therefore picks the GC row:

```
gcbench  2834.0 ± 0.3%          ← main table
gcbench      81.830  …          ← GC summary, last match → rubybench records 81.83
```

At the pin (17dcac9), the GC table is printed only for comparisons, so the published numbers are still right. After
the next submodule bump, those two benchmarks would publish GC ms per iteration as iteration time in all three
configurations. The skeptical reviewer reproduced this on main 00f0f8b. The smallest fix is in rubybench: match only
the main-table row, e.g. `/\A#{Regexp.escape(name)}\s+[\d.]+ ± /`, or read the JSON. This is a coordinator decision.
It concerns rubybench, not our fork, and any GC-reporting change in ruby-bench has to keep it in mind. Branch 1
doesn't change column 2 or add rows.

## Method

* **Builds.** Ruby master [`9b30fd2`](https://github.com/ruby/ruby/commit/9b30fd207ffca8f8acd7c17bd1efb8f815eac5ae)
  (base) and #19685's head [`aa82ba8`](https://github.com/ruby/ruby/commit/aa82ba85e1d11cbbb616a6b44decc26d9eed6160)
  (patch, one commit on that base). Both built with `--enable-yjit --enable-zjit optflags=-O3 debugflags=-ggdb3`
  ([`build_ruby.sh`](../../bench/upstream/ruby_bench_gc/build_ruby.sh)). ruby-bench main `00f0f8b`.
* **Harness.** [`harness_gcsplit.rb`](../../bench/upstream/ruby_bench_gc/harness_gcsplit.rb) runs 15 warmup and 10
  measured iterations.
  * Per iteration: wall time, `GC.total_time`, and minor and major counts.
  * Per collection, from `GC::Profiler` (GC time, mark and sweep wall time, minor or major).
  * After the window, a probe: 10 forced minor and 10 forced major GCs on the warmed heap, timed with `GC.total_time`.
* **Matrix.** [`matrix.sh`](../../bench/upstream/ruby_bench_gc/matrix.sh): 3 rounds × {base-a, base-b, patch} ×
  {interpreter, YJIT, ZJIT `--zjit-exec-mem-size=512 --zjit-mem-size=1024`} × {railsbench, lobsters, shipit}, 81
  processes.
  * The orb has 2 cores × 2 threads, so two processes ran at a time on separate physical cores (CPUs 1 and 3), under
    `setarch -R`.
  * The variant order rotated each round, and each slot ran from its own copy of ruby-bench.
  * A first matrix that pinned three processes to CPUs 1–3 put two of them on hyperthread siblings. It is discarded,
    not used.
* **Summary.** [`summarize.rb`](../../bench/upstream/ruby_bench_gc/summarize.rb) →
  [`data/matrix/summary.md`](../../bench/upstream/ruby_bench_gc/data/matrix/summary.md). Raw JSON is next to it.
* **Controls.** Positive: the patch under ZJIT. Negative: the patch binary under the interpreter and YJIT, where none
  of its code runs; this only differs in binary layout. A/A: base-b against base-a, the same binary.
* **Check of the branch.** One `run_benchmarks.rb --harness=gc --pvalue` run of base, base and patch with branch 1
  ([`data/e2e/`](../../bench/upstream/ruby_bench_gc/data/e2e/)).

## Measurements

ZJIT, the patch and the A/A against base-a in the same round, per round (r1 / r2 / r3). In ms, base-a's
`mark ms/minor` is 0.34–0.36 on railsbench, 6.9–7.6 on lobsters and 2.7–3.5 on shipit.

| metric | railsbench A/A | railsbench patch | lobsters A/A | lobsters patch | shipit A/A | shipit patch |
|---|---|---|---|---|---|---|
| iteration ms | −0.9 / +3.1 / −2.7% | −4.1 / +6.3 / −3.1% | +3.3 / −1.6 / +0.4% | +2.8 / +0.7 / −3.1% | +3.6 / −2.8 / −3.4% | +0.6 / −0.9 / +1.6% |
| GC ms per iteration | +5.7 / +12.6 / −7.1% | −3.6 / +9.2 / −11.6% | +16.7 / +23.8 / +4.0% | +17.3 / +3.7 / −20.1% | +3.6 / −10.8 / +11.4% | −8.6 / −11.2 / −0.6% |
| iteration − GC ms | −1.2 / +2.8 / −2.6% | −4.1 / +6.2 / −2.8% | +2.7 / −2.6 / +0.2% | +2.2 / +0.6 / −2.3% | +3.6 / −2.2 / −4.4% | +1.3 / −0.1 / +1.7% |
| **mark ms per minor GC** | +2.8 / +8.4 / −8.8% | **−54.2 / −48.9 / −58.6%** | +1.2 / −2.0 / +1.9% | **−9.5 / −7.7 / −10.2%** | +4.5 / −4.4 / −4.6% | **−22.8 / −29.7 / −33.0%** |
| mark ms per major GC | – | – | (1 major) | – | −4.4 / −2.1 / +9.5% | −4.9 / +5.4 / +5.1% |
| forced minor GC (probe) | +0.5 / +18.6 / −0.3% | −21.3 / −14.5 / −19.1% | −5.9 / +7.6 / +0.1% | −5.1 / −1.1 / −11.0% | −25.1 / −21.9 / −2.7% | −41.3 / −32.2 / −23.7% |
| minor GCs per iteration | +5.0 / −1.2 / +1.2% | +20.0 / +21.2 / +22.2% | ±12.5% (0.8/iter) | ±14% | +7.3 / +2.4 / +2.4% | +14.6 / +4.8 / +2.4% |

**Negative control.** Pooled over the 6 base and 3 patch processes, `mark ms per minor GC` under the interpreter
and YJIT moves +6.4 / −13.0% (railsbench), −4.5 / −1.1% (lobsters) and +0.3 / −0.2% (shipit). The base processes
vary by 5–14% (coefficient of variation), so all of these are inside the spread. Our first summary also flagged shipit YJIT
`mark ms per major GC` (−6.3%) and railsbench YJIT probe major (+14.4%). That summary divided by the base spread
alone; with the patch processes' own spread included (−9.0 / −14.1 / +3.9% and +36.5 / +4.3 / +0.5%), both are about
1.2 standard errors, which is noise.

**U3's run** ([thread](https://ampcode.com/threads/T-01a19d14-4f82-70ee-a23a-924089ab2b46),
[record](../../bench/upstream/zjit_root_mark_gc/README.md)). Stock `--harness=gc`, master `aed61e36b3` with #19685
rebased onto it, ZJIT only, an 8-vCPU orb, 3 interleaved rounds × 30 iterations. Mark ms per minor GC, counting only
iterations without a major GC:

| | base | A/A | patch |
|---|---|---|---|
| railsbench | 0.500 | 0.502 | **0.279** |
| lobsters | 9.01 | 9.30 | **8.04** |
| shipit | 4.37 | 4.35 | **3.72** |

The patch's per-round ranges don't overlap the base or A/A ranges. U3 also found that ruby-bench's own
`mark/iter` and `mark/GC` show railsbench but not lobsters or shipit. That is the major-GC mixing described above.

**What the numbers say.**

* The saving is in ms per minor collection: 0.34 → 0.16 ms on railsbench in both the natural minors and the forced
  probe. The percentages differ only because the probe divides by the whole GC, not just marking. That is about
  6 ns per JITFrame, using the JITFrame counts in [zjit-yjit-gap](zjit-yjit-gap.md#3-gc-515-of-the-gap).
* Over a whole iteration it is 1.5–2 ms out of 1,300–1,600 ms (0.1–0.2%), well under the 1.4–4% process-to-process
  spread of iteration time on these orbs. That is why the default harness can't show it. Callgrind's −0.64% is
  deterministic and includes cache effects that wall time on a noisy VM can't resolve.
* GC time per iteration doesn't separate either. Sweeping is 70–95% of GC time on these benchmarks, and it
  moves with how much garbage each iteration leaves for the next.
* The patch runs 20% more minor GCs per iteration on railsbench with ZJIT (+5% shipit, consistent across rounds; not
  on the interpreter or YJIT). This is not explained. One hypothesis is that the `HashSet` of ISEQs that the patch
  adds raises malloc-triggered minors. Not checked: it would need `GC.latest_gc_info(:gc_by)` counts. Either way, it
  is why mark ms per minor GC has to be read next to the counts, and why the branch's legend says so.

**End-to-end check of branch 1** (one process per build, before the reviewer fixes):

* GC time ratios: railsbench `mark/minor` patch **2.489 (\*\*\*)**, A/A 1.047; lobsters 1.110 against A/A 0.953.
* shipit: 0.956 against A/A 1.131 in that single process. The patch process compiled slowly in its first measured
  iterations (iteration time ± 34.5%, three 14 ms minor collections), and the A/A pair differed by 13%.
* The per-collection p-values counted collections as independent samples, which is wrong (reviewer, fixed).
* Conclusion: one process per build isn't enough on lobsters and shipit, and the PR body quotes the three-process
  numbers.

## Directions evaluated

| direction | shows #19685 (positive control) | flat on the negative control / A/A | cost | verdict |
|---|---|---|---|---|
| Iteration time (default harness) | no (0.1–0.2% against 1.4–4% spread) | – | – | status quo |
| Iteration − GC time (#562's view) | no, and it shouldn't: the saving is in GC | same spread as iteration time | small | right for mutator changes; **#562 proposal** |
| GC ms per iteration (`gc/iter`) | no (−4 / −7 / −8%, A/A up to ±24%) | no | exists | keep |
| `mark/iter`, `mark/GC` (existing) | railsbench only | lumpy: majors dominate | exists | keep, add per-type columns |
| **Mark ms per minor / major GC** | **yes, all three, every round** | **yes** | small (Ruby 4.1+) | **branch 1** |
| Forced-GC probe after the window | yes, minor (−21 / −6 / −27%) | minor ok; major A/A up to ±33% | +0.1–1 s per benchmark, artificial heap state | validation method, not a column |
| Least-squares split of GC time into minor and major | not determinable: 0–1 majors per iteration | – | – | rejected |
| GC per allocated object or byte, marking per live slot | root marking scales with GCs, not objects | – | – | rejected (wrong denominator) |
| Long fixed run (more iterations) | dilutes the major-GC noise slowly | – | run time | `--bench=N` exists |
| Instructions with GC separated (Callgrind + GC_ENTER/EXIT hook, perf) | yes (that is how we found it) | yes (A/A 0.03–0.08%) | compiled extension, 50× slower; perf needs a PMU: none on Actions, orbs or macOS | not for ruby-bench; developer recipe |
| GC stats in the default harness's JSON | data only | – | touches the timing path rubybench publishes | rejected now |
| Dedicated GC-roots benchmark (many JIT frames) | would show it directly | – | new benchmark, ZJIT-internal | not now; see below |

### Rejected options

* **Default-harness GC recording.** In our data, iteration − GC has the same spread as iteration time, so the main
  benefit (#562 without `--harness=gc`) buys little. It would also touch the loop whose numbers rubybench publishes,
  and the planner pointed out that `gc_*_bench` keys in the default results would turn the GC tables on there too
  (the rubybench hazard above). Revisit only if the maintainers ask for GC numbers on rubybench, together with a
  rubybench parser fix.
* **Forced-GC probe as a column.** It is the only measurement that holds heap state fixed, and its minor reading agreed
  with the natural minors. But its major reading varied by up to ±33% across same-binary processes, and it adds forced
  GCs to every run. It is better named in a PR as a way to validate a GC change.
* **Least-squares split.** With 10 iterations of 0–1 majors and whole-ms inputs, the major coefficient isn't
  determined (`fit ms/major` came out blank or meaningless in [summarize.rb](../../bench/upstream/ruby_bench_gc/summarize.rb)'s
  output). Per-collection records make it unnecessary on 4.1.
* **Per-object, per-byte, per-live-slot normalisation.** Root marking is a cost per GC. Dividing by allocations or
  live slots mis-attributes it and adds a second noise source.
* **Callgrind or perf harnesses.** As in [ruby-bench-improvements](ruby-bench-improvements.md#5-callgrindir-mode):
  * perf needs a PMU, which only the bare-metal machines have, and `HARNESS=perf` already exists;
  * splitting GC from mutator needs a compiled GC-hook extension, and ruby-bench has none;
  * Callgrind is 50× slower.
* **A GC-roots benchmark.** It would show ZJIT root marking directly, but it measures one ZJIT internal and isn't an
  application workload. If the ZJIT team wants one, it belongs with them.

## The subagents

**Planner** (read-only, before the measurements). Ranked four PRs:

1. Per-collection minor/major GC cost in `--harness=gc`.
2. Finishing #562 with `gc_total_time_bench`, as XrXr's PR.
3. GC counters in the default harness, written to the JSON only, under a key that doesn't turn the GC tables on.
4. A forced-GC probe, only if 1 proved noisy.

It found the rubybench parsing hazard, rejected the least-squares fit, per-object normalisation and Callgrind, and
named its own first choice's weakness: Ruby 4.1 only and opt-in. The measurements settled 1 against 4 its way:
natural mark ms per minor GC showed ≥ 2× on railsbench with A/A within 9%. Item 3 was dropped after the data showed
no spread benefit.

**Skeptical reviewer** (read-only, after the first branch draft). Verdict: right direction, not ready as a PR.

* **Blockers, all fixed in `c18af102db`:**
  * TruffleRuby has no `GC::Profiler.raw_data`, so the support check raised `NoMethodError` and would have failed
    the truffleruby CI job.
  * The p-values counted collections as independent samples; with about 80 minors per process, process-to-process
    differences came out as \*\*\*. Now one mean per iteration.
  * The legend claimed the columns "don't depend on how many collections of each kind ran". That is false: more
    frequent minors find fewer young objects, and promotion changes the remembered set. Rewritten to say what moves
    them.
* **Follow-ups fixed:**
  * The GC state is now read before `raw_data` allocates. The reviewer measured 2,516 of 5,048 calls changing state
    during the call; no wrong value had resulted yet.
  * The harness doesn't re-enable a profiler the user already enabled, because re-enabling drops the record of a
    collection that is still marking.
  * Iterations with a global GC are left out, because its record has no `major_by`.
  * The first call takes every record whatever its sequence number.
  * A test with real `GC.start` minor and major collections, and a table test that tells per-iteration means from a
    pooled mean.
* **Not changed:**
  * `mark/major` stays, though it rests on 0–5 majors in a 10-iteration run. Its column says so via the counts table.
  * On Ruby 4.1, gc-harness numbers move by a few µs per GC from the profiler's clock reads: −3 to +6 µs per forced
    minor of ~250 µs ([`profiler_cost.rb`](../../bench/upstream/ruby_bench_gc/profiler_cost.rb)). The profiler's
    record buffer is up to 4,096 records.
* **Evidence corrections, applied above:**
  * The negative-control "failures" came from the effect/SE formula.
  * Lobsters' major-GC numbers rest on about one major.
  * −54% and −21% are the same 0.18 ms.
  * The YJIT minor-count drift (+10.8% on railsbench) means "flat" holds for mark ms per minor GC, not for counts.

## Proposal for XrXr on #562 (not posted)

Not a PR, and not a comment unless Thomas decides otherwise. #562 is his draft, and these are suggestions for when
he returns to it:

* Drop the WIP side-exit commit, or redo it with this guard:

  ```ruby
  last = RubyVM::ZJIT.stats(:side_exit_count) if defined?(RubyVM::ZJIT.enabled?) && RubyVM::ZJIT.enabled?
  ```

  Subtract the previous total, not the previous delta (R5 verified this fix on 4.0.9 and master; on 4.0.9 the stat
  needs `--zjit-stats`).
* Subtract `gc_total_time_bench` (ns) when it is present instead of the whole-ms marking + sweeping sum. That drops
  the "min is approximate" caveat.
* Print each ruby's GC ms per iteration next to the "without GC" row, so a GC-only change reads as "mutator flat, GC
  −X ms". Branch 1's per-collection columns are the view for that case.

## For Lowrail's own GC-sensitive claims

[bench.md](../bench.md) prices interpreter Ir with a fixed heap and separate total and GC-excluded runs. Two
consequences:

* **A change whose effect is GC work** (roots, retention, write barriers, the remembered set) disappears from the
  GC-excluded count. The total count, meanwhile, is decided by where collections land in the window. The
  [perf round](perf-round-main.md) saw this as shipit windows following GC counts (7/2 against 9/2 minor/major).
  Such a claim needs:
  * per-collection marking time on Ruby 4.1+, minor and major separately, from at least 3 processes per build with
    an A/A;
  * the counts per iteration next to it.

  Under Callgrind, the same split is possible by toggling collection only inside GC segments in
  [`bench/callgrind.c`](../../bench/callgrind.c). That is a follow-up, not built.
* **Wall time and GC time per iteration** are not evidence for or against such a change, at these sizes, on orbs.

bench.md links here from its GC section.
