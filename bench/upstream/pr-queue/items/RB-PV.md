---
id: RB-PV
repo: ruby/ruby-bench
kind: fix
area: run_benchmarks.rb --pvalue
reviewer: eightbitraptor
branch: thomasklemm/pvalue-across-processes
head: "e524dbca00"
base: main
built_on: "0e67be03ef"
depends_on: []
stacked_on:
alternative_of:
impact: identical builds no longer get significance stars; --runs N tests across processes
rank:
risky: false
state: ready
pr: 574
note: "2026-11-18 (rules review, docs/upstream/rules-review-2026-11-18-ecosystem.md): lean candidate thomasklemm/pvalue-across-processes-lean eab160f192 (comment to one line); body without the How-measured details, unposted. upstream CI 15/15 green on the 2026-11-14 head; 2026-11-14: rebased onto 0e67be03ef (#576/#577) with --pvalue refusing the callgrind harness and two comments deleted, force-pushed with a lease on 69767b3206, body gained one sentence (docs/upstream/ruby-bench-after-576.md); prepared 2026-11-06, held for Thomas's final review; claude-code passes are a skeptic subagent in the preparing orb, as asked; fork CI green 15/15 on same-tree 5e7f158 for aed07e8d8f and on f961b53 (run 42249192428) for b633985a3d (branch ci/pvalue-across-processes, deleted after; test.yml runs only on main and PRs)"
passes:
  - {reviewer: thermos-sol, head: "eab160f1927c03b4463a5792fb6171793e30c811", orb: T-01a1ee72-63d4-749a-a12d-decd033e6abc, date: 2026-11-18, verdict: approve, open: "Self-performed confirm under both Thermos rubrics. Ripper executable tokens are identical to live e524dbca00; the only delta is the one-line p-value comment. It explains the independence assumption that a reader could otherwise undo by pooling iterations. Traced CLI --runs through interleaved execution, merge_runs, per-run counts, first-iteration aggregation and p_value. Surviving guards: N>=1 rejects nonsensical run counts; Ractor and callgrind refusals protect unsupported result shape/distorted wall time; <2 warns of absent independent samples; failure key? rejects signal-killed partial runs even when status is nil; series/count-shape checks and nil fallbacks support runner-written single-process/older JSON; GC activity excludes run-size bookkeeping. These are format/statistical contracts, not arbitrary-object defenses. Existing alternating-order comment explains bias cancellation. No new structure or readability regression from the trim. Ruby 4.0.9 bundle exec rake test: 373 runs/1355 assertions, 0 F/E, 17 feature/platform skips; installed graph dependencies rather than suppressing graph tests. Proposed body/message checked against execution/tests and ruby-bench-improvements.md's process A/A and spin-loop records; historical cohorts not rerun. Body unchanged here. Thomas both, original 2026-11-06 author timestamp/zone, no trailers. No must-fix."}
  - {reviewer: claude-code, head: "b1da15b", date: 2026-11-06, verdict: changes, open: "body overstated the railsbench slowdown (measured 1.8%, not 5%); new behaviour untested; 1st itr from first process only; Ractor reason; all fixed"}
  - {reviewer: claude-code, head: "cca922aa81", date: 2026-11-06, verdict: nits, open: "--runs=1 interleave test, warmup_itrs_per_run assertion, table label; applied"}
  - {reviewer: claude-code, head: "aed07e8d8f", date: 2026-11-06, verdict: approve, open: "ratio is the pooled mean while the test uses unweighted process means; odd N ordering; kept"}
  - {reviewer: claude-code, head: "aed07e8d8f", date: 2026-11-06, verdict: nits, open: "independent Claude Code Thermos pass (correctness + maintainability), final head b633985a3d. Fixed: with --runs every benchmark got a GC row because run sizes counted as GC activity; tests did not catch a p-value over raw iterations, dropped GC run sizes or an even split (new asymmetric test, checked against scipy); Ractor refusal test asserts its message; body slowdowns as extra time (6.6%/11%/1.9%, were 1 − ratio). Kept: pooled ratio vs process-mean test; odd N balanced across the suite only; scalars (rss without samples, JIT stats) from process 1, as the commit message says; --pvalue alone now N/A, stated in the body"}
  - {reviewer: claude-code, head: "69767b3206", date: 2026-11-06, verdict: approve, open: "confirm pass on the delta from b633985a3d (signal-killed run: exitstatus nil made dig miss the failure; both sites use key?) and the body wording; new SIGKILL test fails on b633985a3d, passes on 69767b3206; full suite 360 runs green; fork CI 15/15 on 69767b3206 via draft PR #17 (run 42255909337), PR closed, branch kept"}
  - {reviewer: sol, head: "b633985a3d", date: 2026-11-06, verdict: changes, open: "P2 signal-killed run (exitstatus nil) admitted partial results via bench_failures.dig; fixed in 69767b3206 with a SIGKILL CLI test. Body: 'can't resolve 2%' became 'did not detect this 2% difference'. 103 of 2,000 is per mode (49 + 54), as the details say"}
  - {reviewer: sol, head: "69767b3206", date: 2026-11-06, verdict: approve, open: "confirm pass on the failure fix and body wording; none"}
  - {reviewer: opus, orb: T-01a1dabd-a56c-717b-8d0c-7b6b0f8b0bc6, head: "51bb8e0199", date: 2026-11-14, verdict: changes, open: "rebase onto 0e67be03ef plus --pvalue refusing the callgrind harness: refusal approved (aborts in 0.097 s before any process, no files; test fails without it after 22 s of real Valgrind, 373 runs green). Must-fix: merge_runs and split_runs comments said only what the code does (unchanged since 69767b3206), deleted in e524dbca00. Nits: --runs warning printed before the callgrind abort (moved below the refusals); refusal runs after CPUConfig like the Ractor one (kept)"}
  - {reviewer: opus, orb: T-01a1dabd-a56c-717b-8d0c-7b6b0f8b0bc6, head: "e524dbca00", date: 2026-11-14, verdict: approve, open: "confirm pass: range-diff shows only the two deleted comments and the moved warning; callgrind --pvalue without --runs prints only the abort; 373 runs green; PR head and body checked; none"}
  - {reviewer: thermos-sol, orb: "T-01a1ee72-6d4f-7377-b2ff-f1240d8bebeb", head: "eab160f1927c03b4463a5792fb6171793e30c811", date: 2026-11-18, verdict: approve, open: "body only; live/generated bodies, lean source, record and upstream template checked; both rubrics self-performed, no delegation. Cut experiment counts, methodology and raw experiment table; kept public runs/pvalue/JSON behavior and added actual Ractor harness limitation. Pass names lean candidate; item head/branch unchanged and code review separate."}
waived:
  - {reviewer: thermos, head: "69767b3206", by: coordinator, reason: "Thermos ran as the independent claude-code pass on aed07e8d8f (fixes to b633985a3d); the delta to 69767b3206 is the 2-line failure-key fix plus its test, approved by claude-code and Sol on this head"}
---

# Test significance across processes with --runs

`--pvalue` runs Welch's t-test over the measured iterations of one process per Ruby. Those iterations share one heap layout, hash seed, GC schedule and set of JIT decisions, so the test only sees the noise inside a process. Two processes of the same Ruby can differ by more than that, and the test reports the difference as significant even when comparing identical Rubies.

This adds `--runs N`: each benchmark runs in N processes per Ruby, interleaved, with the order of the Rubies flipped every round, and the t-test compares the N per-process means. With one process, still the default, the p-value is N/A and `--pvalue` prints a warning, rather than showing stars it can't support. `--pvalue` refuses the callgrind harness, whose times are measured under Valgrind. The default stays at one process because `--runs N` takes N times as long. The timing columns report all measured iterations of the N processes, the 1st itr ratio averages each process's first iteration, and the JSON records each process's iteration counts in `warmup_itrs_per_run` and `bench_itrs_per_run`.

Multiple runs are not supported by the Ractor harness, whose per-Ractor-count results are not yet merged across processes.
