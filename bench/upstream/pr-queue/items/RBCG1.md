---
id: RBCG1
repo: ruby/ruby-bench
kind: fix
area: harness/callgrind.rb (#576 follow-up)
reviewer: tekknolagi
branch: thomasklemm/callgrind-summary-matches-totals
head: "d1ab8607b7"
base: main
built_on: "0e67be03ef"
depends_on: []
stacked_on:
alternative_of:
impact: the Callgrind dump's summary line equals its totals, so callgrind_annotate and scripts reading summary (ruby/ruby#19851) see the measured instruction count instead of a number near 2^64
rank:
risky: false
state: ready
pr: 579
note: "built 2026-11-14 in T-01a1da97 (docs/upstream/ruby-bench-after-576.md); suite 360 runs green on Ruby 4.0.9; the three reordered harness tests fail on main's harness; Opus changes on 9e04df158d applied in d1ab8607b7. Not opened: Thomas decides; Max's ruby/ruby#19851 reads summary:, so this is worth telling him about either way. Thomas approved opening; opened as #579 on 2026-11-14 after the claude-code pass"
passes:
  - {reviewer: opus, orb: T-01a1dabd-a56c-717b-8d0c-7b6b0f8b0bc6, head: "9e04df158d", date: 2026-11-14, verdict: changes, open: "reorder correct and needed, reproduced (main .1 summary 2^64-2063, branch summary = totals; atstart yes too; each of the three steps needed; partial dump on failure has summary = totals, instrumentation always stops; 2,234 more Ir than main, the first dump request's lazy binding, constant). Must-fix: 'exit dump empty, as before' false when other threads ran (ZERO_STATS resets only the calling thread): commit message and comment qualified in d1ab8607b7. Nits applied: 71K claim dropped, ~2K dump overhead named, README reflowed, puts uses name"}
  - {reviewer: opus, orb: T-01a1dabd-a56c-717b-8d0c-7b6b0f8b0bc6, head: "d1ab8607b7", date: 2026-11-14, verdict: approve, open: "confirm pass: ensure code unchanged, message matches measurements, fib .1 summary = totals, exit dump 0/0, 360 runs green. Optional: comment 'its exit dump' could say 'this thread's share of the exit dump' (not applied)"}
  - {reviewer: claude-code, head: "d1ab8607b70bf0330e69bb81560e7647ac467af3", orb: T-01a1db37-b49c-75d5-b46b-0c791fa496e1, date: 2026-11-14, verdict: nits, open: "reproduced with Valgrind 3.24.0, Ruby 4.0.9, fib --warmup=1 --bench=1 (direct and run_benchmarks.rb): interpreter main .1 summary 18446744073709549767 / totals 1959670074, branch 1959671789 = totals (+1,715); atstart=yes same; callgrind_annotate PROGRAM TOTALS 18,446,744,073,709,549,767 with 0.00% on main, 1,959,671,789 with 37.05% vm_exec_core on branch. YJIT main summary 18446744073709549440, branch summary = totals, +1,861, but absolute Ir here 458,200,674 / 458,202,535, not the body's 454,676,097 / 454,677,958 (stable across 1/10 warmups, env size, runner; likely host CPU). Threads (2 created per iteration; 2-thread pool from setup), atstart no and yes: branch .1 summary = totals, main wraps; branch exit dump totals 0 but summary wraps by the other threads' cost (main 0/0), as the body says. --separate-threads=yes: branch .1-01 summary = totals, main wraps. Failure in iteration 3: branch partial .1 summary = totals. Final zero only drops the dump-to-stop tail (986 Ir on fib, unrecorded on main too); without it the exit summary wraps by -1.96e9. Tests: the three reordered stub-sequence tests fail on main's harness (3 failures), branch 8/8, suite 360 runs 0 failures 17 skips; they pin request order rather than summary = totals, acceptable since CI has no Valgrind. ruby/ruby#19851 (open, head 3500842d15) zjit_callgrind.rb reads summary: of the .1 dump, rejects only <= 0, pins ruby-bench 01e54d3307 whose harness has main's order. Author/committer Thomas Klemm, no trailers, one commit on 0e67be03ef (= main). Nits, optional: the added comment is 113 chars, wider than the rest of the file (98), could be one shorter line; the body's YJIT absolutes are one machine's."}
---

# Make the Callgrind profile's summary line match its totals

`harness/callgrind.rb` starts instrumentation, zeroes the counters, runs the measured iterations, stops instrumentation and then dumps. In that order Callgrind writes a wrapped-around negative `summary:` line into the dump. `fib`, `--warmup=1 --bench=1`, Ruby 4.0.9, Valgrind 3.24.0:

| | `summary:` | `totals:` |
| --- | ---: | ---: |
| main, interpreter | 18446744073709549767 | 1959670074 |
| this PR, interpreter | 1959671789 | 1959671789 |
| main, YJIT | 18446744073709549440 | 454676097 |
| this PR, YJIT | 454677958 | 454677958 |

`callgrind_annotate` takes the summary as the program total, so on main it prints `18,446,744,073,709,549,767 (100.0%)  PROGRAM TOTALS` and every function at 0.00%. A script that reads `summary:`, as `zjit_callgrind.rb` in ruby/ruby#19851 does, gets a number near 2^64 for every benchmark.

This zeroes before starting and dumps before stopping. The summary then equals the totals, with and without `--instr-atstart=no`. The profile now also counts the dump request itself: +1,715 instructions (interpreter) and +1,861 (YJIT) against main's totals on fib. Zeroing again after stopping keeps the dump at exit at 0, as on main, unless other threads ran during the measured iterations: Callgrind's zero request resets only the calling thread. The benchmark name is computed before instrumentation starts, so its regexp match stays out of the profile now that the dump comes first.
