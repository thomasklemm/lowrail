---
id: RB-PV
repo: ruby/ruby-bench
kind: fix
area: run_benchmarks.rb --pvalue
reviewer: eightbitraptor
branch: thomasklemm/pvalue-across-processes
head: "69767b3206"
base: main
built_on: "ad63bf8"
depends_on: []
stacked_on:
alternative_of:
impact: identical builds no longer get significance stars; --runs N tests across processes
rank:
risky: false
state: reviewed
pr:
note: "prepared 2026-11-06, held for Thomas's final review; claude-code passes are a skeptic subagent in the preparing orb, as asked; fork CI green 15/15 on same-tree 5e7f158 for aed07e8d8f and on f961b53 (run 42249192428) for b633985a3d (branch ci/pvalue-across-processes, deleted after; test.yml runs only on main and PRs)"
passes:
  - {reviewer: claude-code, head: "b1da15b", date: 2026-11-06, verdict: changes, open: "body overstated the railsbench slowdown (measured 1.8%, not 5%); new behaviour untested; 1st itr from first process only; Ractor reason; all fixed"}
  - {reviewer: claude-code, head: "cca922aa81", date: 2026-11-06, verdict: nits, open: "--runs=1 interleave test, warmup_itrs_per_run assertion, table label; applied"}
  - {reviewer: claude-code, head: "aed07e8d8f", date: 2026-11-06, verdict: approve, open: "ratio is the pooled mean while the test uses unweighted process means; odd N ordering; kept"}
  - {reviewer: claude-code, head: "aed07e8d8f", date: 2026-11-06, verdict: nits, open: "independent Claude Code Thermos pass (correctness + maintainability), final head b633985a3d. Fixed: with --runs every benchmark got a GC row because run sizes counted as GC activity; tests did not catch a p-value over raw iterations, dropped GC run sizes or an even split (new asymmetric test, checked against scipy); Ractor refusal test asserts its message; body slowdowns as extra time (6.6%/11%/1.9%, were 1 − ratio). Kept: pooled ratio vs process-mean test; odd N balanced across the suite only; scalars (rss without samples, JIT stats) from process 1, as the commit message says; --pvalue alone now N/A, stated in the body"}
---

# Test significance across processes with --runs

`--pvalue` runs Welch's t-test over the measured iterations of one process per Ruby. Those iterations share one heap layout, hash seed, GC schedule and set of JIT decisions, so the test only sees the noise inside a process. Two processes of the same Ruby differ by more than that, and the test reports that difference as significant. Comparing identical Rubies, about half the comparisons got a star:

| identical Rubies, p < 0.05 | main's single-process test | per-process means, 5 processes each |
|---|---:|---:|
| main, 10 processes per Ruby and benchmark | 214 of 450 pairs (48%) | about 5% of random 5-against-5 groupings |
| this branch, 4 Rubies with `--runs 5` | 566 of 950 pairs (60%) | 2 of 30 comparisons |
| expected | 5% | 5% |

This adds `--runs N`: each benchmark runs in N processes per Ruby, interleaved, with the order of the Rubies flipped every round, and the t-test compares the N per-process means. With one process, still the default, the p-value is N/A and `--pvalue` prints a warning, rather than showing stars it can't support. The default stays at one process because `--runs N` takes N times as long. The timing columns report all measured iterations of the N processes, the 1st itr ratio averages each process's first iteration, and the JSON records each process's iteration counts in `warmup_itrs_per_run` and `bench_itrs_per_run`.

The test still finds differences that are larger than the variation between processes. With `--runs 5` against YJIT, the interpreter got `***` on railsbench, fib and str_concat. An added spin loop made fib 6.6% slower (`***`, p = 4e-5) and str_concat 11% slower (`**`), but railsbench only 1.9%, where it was not detected (p = 0.31): railsbench processes vary by about 3% on the 4-vCPU VM used here, so five runs did not detect this 2% difference.

<details><summary>How this was measured</summary>

Ruby 4.0.9 with YJIT and the interpreter, `--no-sudo --interleave --pvalue`, default iterations, on main `ad63bf8` and on this branch; railsbench, lobsters, fib, respond_to and str_concat. Main: one run with `-e yjit01::ruby --yjit … -e yjit10::ruby --yjit`, one with ten interpreter executables. "Pairs" are all pairs of processes of a benchmark, tested with main's single-process test. "Groupings" are 1,000 random 5-against-5 splits of the same ten processes per mode, tested on their per-process means; they reuse processes, so they are not independent (103 of 2,000). Branch: `--runs 5 --pvalue -e A::ruby --yjit … -e D::ruby --yjit`, all 6 pairs per benchmark. Slowdown: a preloaded module that spins after each iteration for a set share of its time; the ratios above are measured, not nominal. Wall time grows with N: the branch A/A ran 100 benchmark processes in 2,156 s; one process per Ruby would have been 20 processes, about 430 s.
</details>
