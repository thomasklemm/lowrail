---
id: DUEL1
repo: sferik/duel-ruby
fork: thomasklemm/duel-ruby
kind: feature
area: Native counters, Lane sampling, CLI, reusable perf workflow (duel --callgrind)
reviewer: sferik
branch: callgrind
head: "7d15f05b47a51d3457bdac87f90589f5e0b79c4d"
base: main
built_on: "a09111e"
tracker: []
depends_on: []
stacked_on:
alternative_of:
impact: "Opt-in duel --callgrind counts each benchmark's instructions under Valgrind's Callgrind on runners without CPU counters. On hashie's 21 benchmarks on GitHub runners, next to HD1's CPU-time job: A/A 0/19 failed both, unsettled 1/399 vs 65/399; CPU plant 5 and 5 regressed vs 6 and 5 (all 5 it reaches either way); allocation plant 13 vs 13; #656 faster 6/6/6 vs 6/8/8; passing job median 229 s vs 93 s, failing 734-1,637 s vs 184-419 s. Not worth proposing."
evidence: [bench/upstream/hashie_duel/callgrind]
rank:
risky: false
state: held
pr:
note: "2026-11-27 held: the numbers say it isn't worth it (no more CPU-plant catches, 2.5-4x job time), so no reviews were started and nothing goes upstream unless Thomas decides otherwise; if he does, an issue with the numbers first (draft below), not a 459-line PR. Fork branch callgrind at 7d15f05 (one commit on main a09111e; calibrated on its pilot cef26e5, kept as callgrind-pilot). Duel suite on Ruby 4.0.9: 936 runs 0 failures, 100% coverage, rubocop/standardrb/steep clean; mutant 0 alive in 509 of 2,642 before OOM, not completed. Side finding, separate: Native::Linux#read uses IO#pread, which raises ESPIPE on a perf fd (AWS Xeon runners after sysctl, bench/upstream/hashie_duel/callgrind/probe/), so Duel's Linux instructions counter fails wherever counters exist; read(2) works. Ownership check by hand 2026-11-27: Duel's 8 issues and PRs, open and closed, and its history name no Valgrind, Callgrind, perf counters on CI or instruction counting beyond the existing metric."
ownership: {date: 2026-11-27, checked: ["sferik/duel-ruby issues and PRs, open and closed, and commit history, for Valgrind, Callgrind, perf_event and instruction counting"], hits: []}
passes: []
---

# Count instructions under Callgrind on runners without CPU counters?

On GitHub's runners Duel judges CPU time and allocations, since `perf_event_open` isn't offered there. I tried counting instructions under Callgrind instead (`duel --callgrind`, [a branch on my fork](https://github.com/thomasklemm/duel-ruby/tree/callgrind)), next to the CPU-time job, on Hashie's 21 benchmarks:

- identical code, 19 runs: 0 failed either way; 1 of 399 verdicts unsettled, against 65 with CPU time
- a CPU-only regression reaching 5 benchmarks: those 5 regressed, as they did with CPU time
- allocation regression: 13 regressed in both
- a passing job: 229 s against 93 s; a failing one 734–1,637 s against 184–419 s

So it's quieter, but catches no more and is 2.5–4× slower. Is that worth a pull request?
