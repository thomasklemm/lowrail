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
state: built
pr:
note: "built 2026-11-14 in T-01a1da97 (docs/upstream/ruby-bench-after-576.md); suite 360 runs green on Ruby 4.0.9; the three reordered harness tests fail on main's harness; Opus changes on 9e04df158d applied in d1ab8607b7. Not opened: Thomas decides; Max's ruby/ruby#19851 reads summary:, so this is worth telling him about either way"
passes:
  - {reviewer: opus, orb: T-01a1dabd-a56c-717b-8d0c-7b6b0f8b0bc6, head: "9e04df158d", date: 2026-11-14, verdict: changes, open: "reorder correct and needed, reproduced (main .1 summary 2^64-2063, branch summary = totals; atstart yes too; each of the three steps needed; partial dump on failure has summary = totals, instrumentation always stops; 2,234 more Ir than main, the first dump request's lazy binding, constant). Must-fix: 'exit dump empty, as before' false when other threads ran (ZERO_STATS resets only the calling thread): commit message and comment qualified in d1ab8607b7. Nits applied: 71K claim dropped, ~2K dump overhead named, README reflowed, puts uses name"}
  - {reviewer: opus, orb: T-01a1dabd-a56c-717b-8d0c-7b6b0f8b0bc6, head: "d1ab8607b7", date: 2026-11-14, verdict: approve, open: "confirm pass: ensure code unchanged, message matches measurements, fib .1 summary = totals, exit dump 0/0, 360 runs green. Optional: comment 'its exit dump' could say 'this thread's share of the exit dump' (not applied)"}
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
