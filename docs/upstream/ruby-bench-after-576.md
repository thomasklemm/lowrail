# Our ruby-bench PRs after #576 and #577 (2026-11-14)

**Trigger.** ruby/ruby-bench main moved three commits past `ad63bf8`, the base of all six of our open PRs:
#577 (Kevin Menard, `34d4d2201b`) loads the macOS RSS/Fiddle code when the harness loads, because loading it after
`Bundler.setup` during iterations invalidated JIT code; #576 (Max Bernstein, `0e67be03ef`) adds a `callgrind`
harness that runs `valgrind --tool=callgrind --instr-atstart=no` and instruments only the measured iterations.
Thomas asked what our PRs need now, what the callgrind harness does against Lowrail's Valgrind experience, and for
the smallest follow-ups to #576 that Max would want.

**Short answer.**

* All six PRs are rebased onto `0e67be03ef` and force-pushed with a lease. Five are clean rebases; #574 also refuses
  `--pvalue` with the callgrind harness. None of them loads code during measured iterations, so #577 needs nothing
  from them.
* The callgrind harness writes a **wrapped negative `summary:` line** into every profile it dumps
  (`18446744073709549767` for fib). `callgrind_annotate` then prints garbage totals and 0.00% for every function,
  and Max's own ruby/ruby#19851 reads that line. The fix reorders the harness's Callgrind requests and adds one zero: fork branch
  `thomasklemm/callgrind-summary-matches-totals` (queue item [RBCG1](../../bench/upstream/pr-queue/items/RBCG1.md)).
* Ir is exact run to run on fib, within 0.11% on lobsters, but **1.5% on railsbench** without a fixed heap (0.04%
  with one) and 3.3% on railsbench under YJIT. Stock Valgrind 3.24.0 still hits `brk segment overflow` on railsbench
  and lobsters. None of this needs a ruby-bench change now; see [Not built](#not-built).
* #571 and #572 both stay open as alternatives, as Thomas asked; their cross-references are still accurate.

## Per PR

Old heads were built on `ad63bf8`; new heads sit on `0e67be03ef`. `git range-diff` is identical (`=`) for the five
clean rebases. Commits: Thomas Klemm as author and committer, no trailers. Tests: `BUNDLE_VERSION=system bundle exec
rake test`, Ruby 4.0.9, on each rebased head; main alone is 360 runs, 0 failures, 17 skips.

| PR | old → new head | change | tests | body |
| --- | --- | --- | --- | --- |
| #569 marking time per minor/major | `081b17e3ae` → `83dd344c99` | clean rebase | 368 runs, 0 failures | unchanged |
| #570 GC averages without truncation | `2c2c695e69` → `ddfe6908cf` | clean rebase | 361 runs, 0 failures | unchanged |
| #571 lobsters fixed clock | `33e9aa45be` → `30fbcd9df6` | clean rebase | 360 runs, 0 failures | unchanged |
| #572 lobsters clock near fixture | `f94d3a10df` → `ffbf5a0051` | clean rebase | 360 runs, 0 failures | unchanged |
| #574 p-values across processes | `69767b3206` → `e524dbca00` | rebase + `--pvalue` refuses the callgrind harness; two what-comments deleted, `--runs` warning moved below the refusals (Opus) | 373 runs, 0 failures | one sentence added |
| #575 blog benchmark (draft) | `537f5752f5` → `d761531b83` | clean rebase | 360 runs, 0 failures | unchanged |

**Why rebase at all.** None of them conflicted (`git merge-tree` clean on all six). Thomas asked for the rebase so
each PR runs CI against the harness code it would merge into; #574 also needed the callgrind change, which only
exists on the new main.

**#569, #570 (harness/gc.rb).** Nothing to change for #577: `harness/gc.rb` calls `get_rss` after each iteration,
which on Linux reads `/proc/self/smaps_rollup` and on macOS now uses the Fiddle function #577 loads up front. #569's
per-iteration `GC::Profiler.raw_data` is a C method; `GCStats` is required at load. A `script_compiled` TracePoint
over railsbench with #569's `harness/gc.rb` (Ruby 4.0.9, 3 + 3 iterations) saw 3,545 compiles, all before the end of
the first iteration (railsbench defines attribute methods on its first requests), none after. Ruby 4.0.9 has no
`raw_data(since:)`, so #569's record path did not run there; that path is from reading the code. Still relevant:
#569 conflicts with #541 and with XrXr's #562 (both touch `harness/gc.rb` or `lib/benchmark_runner.rb`), as before;
#570 conflicts with #541 only, and so does #574. The body already says #569 will rebase if #541 lands first.

**#571, #572 (lobsters).** Main did not touch lobsters after `ad63bf8`. The DST cost they remove is still live: on
main today lobsters makes 1,474 `ActiveSupport::TimeZone#period_for_local` calls per pass
([dst_harness.rb](../../bench/upstream/ruby_bench_dst/dst_harness.rb), `COUNT=1`); #571's body counted 1,476 extra
lookups on 2026-11-05 and none in July. Both bodies' "merge one of the two" stays true and both stay open.

**#574 (--runs, --pvalue).** With `--harness=callgrind`, the timing columns are wall times under Valgrind.
`--runs 3 --pvalue` on fib with two identical Rubies (both `ruby`) printed `11678.5 ± 5.5%` against
`11249.6 ± 2.7%`, ratio 1.038, p = 0.455, while all six profiles had identical totals (1,959,670,074 Ir). A p-value
over those times says nothing about the instruction counts, which are what the harness is for; a p-value over Ir
would need Ir in the results JSON, which #576 doesn't record. So `--pvalue` now aborts before any process starts
when a benchmark uses the callgrind harness, next to the existing Ractor refusal; `--runs` alone still runs N
profiled processes per Ruby. The new CLI test fails on the old head (control with Valgrind off `PATH`) and passes on
the new one. Body: one sentence after "rather than showing stars it can't support": "`--pvalue` refuses the
callgrind harness, whose times are measured under Valgrind."

**#575 (blog).** A per-iteration probe (default harness, 10 warmups, then 5 iterations, each followed by `get_rss`)
counted the change in `$LOADED_FEATURES`, `RubyVM.stat(:constant_cache_invalidations)` and, under YJIT,
`invalidation_count` and `compiled_iseq_count`: blog +0 / +0 / +0 in every iteration, YJIT compiled 5 ISEQs in the
5th. Railsbench and lobsters on main: +0 features and +0 invalidations too (lobsters keeps compiling 1–39 ISEQs per
iteration under YJIT, a main property). Nothing to change.

## The callgrind harness against Lowrail's Valgrind experience

Setup: this orb (2 vCPUs, the system's Valgrind 3.24.0), Ruby 4.0.9, ruby-bench `0e67be03ef`, one process per run started
exactly as `run_benchmarks.rb --harness=callgrind` starts it (`setarch x86_64 -R valgrind --tool=callgrind
--instr-atstart=no …`), `WARMUP_ITRS=3 MIN_BENCH_ITRS=1` (YJIT: 10 warmups). "Patched" is Valgrind 3.24.0 with
Lowrail's [`bench/valgrind-brk.patch`](../../bench/valgrind-brk.patch) (512 MiB brk reservation; it applies to 3.24.0
with a 45-line offset). "Fixed heap" is `RUBY_GC_HEAP_{0..4}_INIT_SLOTS=1000000/250000/100000/20000/10000`, as in
[census 9](rails-main-census-9.md). Ir is the `totals:` line of the measured-iteration dump. Spread = (max − min) /
min. Scripts and raw numbers: [`bench/upstream/ruby_bench_callgrind576/`](../../bench/upstream/ruby_bench_callgrind576/).

| benchmark | config | processes | Ir per measured iteration | spread | brk overflow |
| --- | --- | ---: | --- | ---: | --- |
| fib | stock | 4 | 1,959,670,074 in all four | 0 | no |
| lobsters | stock | 4 | 3,660,994,752 – 3,665,083,628 | 0.11% | every run |
| lobsters | patched | 3 | 3,663,074,871 – 3,664,340,855 | 0.035% | none |
| railsbench | stock | 4 | 7,755,671,686; 7,867,105,927 – 7,874,731,113 | 1.54% | every run |
| railsbench | patched | 3 | 7,748,579,834 – 7,767,376,431 | 0.24% | none |
| railsbench | stock, fixed heap | 3 | 7,398,191,144 – 7,401,335,739 | 0.04% | every run |
| railsbench | stock, YJIT | 3 | 4,782,765,104; 4,827,896,646; 4,939,063,218 | 3.27% | every run |

* **brk overflow.** Stock Valgrind 3.24.0 still caps the client brk segment at 8 MiB: every railsbench and lobsters
  run printed `brk segment overflow in thread #1` (e.g. `can't grow to 0x484e000`), fib never did. The run still
  exits 0 and dumps a profile; glibc falls back to `mmap`. Lowrail rejects such cohorts
  ([bench.md](../bench.md#valgrind-brk-reservation-correction-2026-10-20)); for ruby-bench it is a caveat, not a
  failure.
* **Without a fixed heap, railsbench's Ir varies by GC work.** The stock railsbench runs fall into two clusters:
  three at 7,867–7,875 M and one at 7,756 M, next to the patched runs (7,749–7,767 M). Self Ir in
  `gc/default/default.c` and `gc.c` is 760–765 M in the high cluster against 679–694 M in the others, and the rest
  is 0.5% higher too ([gcshare.sh](../../bench/upstream/ruby_bench_callgrind576/gcshare.sh)). The three high runs ran
  back to back, so I can't attribute the cluster to the brk overflow; the stock run at 7,756 M overflowed too. A
  fixed heap brings three stock runs within 0.04%, but it also changes the workload: GC is 6.0% of Ir instead of
  8.8–9.7%.
* **YJIT.** Railsbench's YJIT Ir varied 3.27% over three processes (stock Valgrind, no fixed heap), twice the
  interpreter's spread, mostly in GC (443–545 M Ir in the GC files, 9.3–11.0% of the total). Outside Valgrind, railsbench compiled nothing in four of five iterations after 10 warmups
  (+1 ISEQ in the fifth); lobsters kept compiling 1–39 ISEQs per iteration. Under YJIT a profile can include
  compilation and JIT-dependent GC timing, and nothing in the harness says so.
* **Summary line.** See the next section; the runs above read `totals:`, which is right on main.
* **Runner times.** The table `run_benchmarks.rb` prints for `--harness=callgrind` is in ms of instrumented time.
  The README says so ("these are instrumented times").

## Follow-up built: the summary line (RBCG1)

`harness/callgrind.rb` on main does start → zero → iterations → stop → dump. Callgrind computes `summary:` as the
current cost minus the cost at the last dump or zero; starting or stopping instrumentation zeroes the current cost
but not that baseline. A small Ruby script under Valgrind 3.24.0
([t3.rb](../../bench/upstream/ruby_bench_callgrind576/t3.rb)) tried the orders:

| order (`--instr-atstart=no`) | `summary:` | `totals:` |
| --- | ---: | ---: |
| start, zero, work, stop, dump (main) | 18446744073709548750 | 212,369,119 |
| zero, start, work, stop, dump | 0 | 212,368,919 |
| start, work, dump, stop | 212,383,701 | 212,383,701 |
| zero, start, work, dump, stop | 212,371,159 | 212,371,159 |
| zero, start, work, dump, stop, zero | 212,358,590 | 212,358,590 (exit dump 0/0) |

With `--instr-atstart=yes`, zero, start, work, dump, stop also gives summary = totals; start, work, dump, stop
does not (totals keep the setup).

Why it matters: `callgrind_annotate` uses `summary:` as PROGRAM TOTALS, so on main it prints
`18,446,744,073,709,549,767 (100.0%)` and 0.00% for every function. Max's ruby/ruby#19851
(`.github/scripts/zjit_callgrind.rb`, "ZJIT: Add a GitHub action to comment perf differences") reads the Ir from
`summary:` of the `.1` dump and rejects 0. On main's harness it gets ~1.8e19 for every benchmark, so base and PR
compare as ~0%. On this branch it gets the real count.

Branch `thomasklemm/callgrind-summary-matches-totals`, head `d1ab8607b7`, one commit on `0e67be03ef`: zero → start
→ iterations → dump → stop → zero, and `benchmark_name` computed before instrumentation starts, so its regexp match
stays out of the profile now that the dump comes first. The profile now counts the dump request too (~2K Ir). Fib: summary = totals = 1,959,671,789 (interpreter) and 454,677,958 (YJIT), against main's totals
1,959,670,074 and 454,676,097; the exit dump stays 0/0 unless other threads ran during the measured iterations
(Callgrind's zero request resets only the calling thread; the `.1` dump is right either way); direct `valgrind --tool=callgrind ruby -r
./harness/callgrind` (atstart yes) gives the same 1,959,671,789. Suite 360 runs green; the three reordered tests in
`test/callgrind_harness_test.rb` fail against main's harness. Draft body in the queue item. Max should hear about
this soon either way, because #19851 is open.

## Not built

* **Ir in the results JSON and table.** What Max wants from #576 ("I want to measure callgrind instructions too").
  The runner would read `totals:` of each process's `.1` dump into the result and the table would compare Ir instead
  of instrumented ms; with #574, `--runs` could then test Ir across processes. It touches the suite, the table
  builder and #574's code, and #19851 already reads the dumps itself, so it's a design question for Max rather than
  a small follow-up. Recommend asking him once RBCG1 is in front of him.
* **brk overflow.** Valgrind prints the warning itself, the run completes, and here the overflow did not visibly
  move lobsters' Ir (stock 0.11%, patched 0.035%, ranges overlapping). A patched Valgrind is a Lowrail
  measurement-protocol need, not a ruby-bench one.
* **Fixed-heap option or README note.** It took railsbench from 1.5% to 0.04%, but on three processes, and it
  removes a third of the GC work, which hides GC changes. Worth mentioning to Max with the numbers if #19851's
  railsbench deltas turn out noisy; not a PR now.
* **JIT-flat check.** Lobsters under YJIT keeps compiling, so its Ir includes compilation. A check would need JIT
  stats in the harness for YJIT and ZJIT; that matters for JIT comparisons but is larger than a small follow-up.

## Lowrail's ruby-bench pins

Lowrail pins no ruby-bench SHA: scripts take a checkout path (`RUBY_BENCH_DIR`, `RUBY_BENCH`, default `~/w/…` or
`~/src/ruby-bench`); docs name the SHAs historical runs used (e.g. byroot/ruby-bench `bf1afb2` in
[combined-effect](combined-effect.md)), which stay as records. Smoke checks on `0e67be03ef`:
[`harness_gcsplit.rb`](../../bench/upstream/ruby_bench_gc/harness_gcsplit.rb) on fib (JSON written) and
[`dst_harness.rb`](../../bench/upstream/ruby_bench_dst/dst_harness.rb) on lobsters (counts printed) both ran.

## Review and CI

* **Opus 5.5** (claude-code orb, effort high,
  [thread](https://ampcode.com/threads/T-01a1dabd-a56c-717b-8d0c-7b6b0f8b0bc6)):
  * #574 `51bb8e0199`: the refusal is approved (aborts in 0.097 s, before any process runs and without writing
    files; the test fails without it). Changes: the `merge_runs` and `split_runs` comments only said what the code does.
    Both are deleted in `e524dbca00`, and the `--runs` warning moved below the refusals. Confirm pass on `e524dbca00`:
    approve.
  * RBCG1 `9e04df158d`: the reorder is approved and was reproduced; each of the three steps is needed. Must-fix: "the
    exit dump stays empty" is false when other threads ran. That claim is narrowed in `d1ab8607b7`, which also
    drops the 71K claim and names the ~2K dump overhead. Confirm pass on `d1ab8607b7`: approve.
* **Upstream CI on the new heads:** 15/15 green on each of #569 `83dd344c99`, #570 `ddfe6908cf`, #571 `30fbcd9df6`,
  #572 `ffbf5a0051`, #574 `e524dbca00` and #575 `d761531b83` (Linux, Windows, ruby, head, TruffleRuby).
