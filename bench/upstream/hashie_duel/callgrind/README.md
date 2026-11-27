# Duel under Callgrind on GitHub's runners: calibration on hashie (DUEL1, 2026-11-27)

Question: does counting instructions under Callgrind make Duel a better gate on GitHub's runners than CPU time,
which HD1 uses ([../README.md](../README.md))? Answer: **no, not for hashie**. It is quieter, but it catches no
more of the CPU plant and takes 2.5× as long to pass and 3.5–4× as long to fail.

## Why Callgrind and not the CPU's counters

Duel already has an `instructions` metric (perf_event_open on Linux), and GitHub's runners don't offer it. The
`counters` job (23 jobs, `runs/*.counters.summary.txt`) and 12 probe runs (`probe/`, `probe-loop.sh`) landed on Azure
AMD EPYC 7763 (8), 9V74 (7) and 9V45 (5), where perf_event_open fails at the default `perf_event_paranoid` 4 (EACCES) and
there is no PMU at ≤ 2 (ENOENT), and on AWS Xeon 6975P-C (3), where it works after `sudo sysctl
kernel.perf_event_paranoid=2` and reads 124,045,0xx instructions per loop. The runner type is not chosen by the
workflow, so perf counters can't gate. There Duel's `Native::Linux#read` fails: `IO#pread` on a perf fd raises
`Errno::ESPIPE` (`probe/probe-a6.log`, `probe-a12.log`), so its Linux counter breaks wherever counters exist (a
separate one-line bug, `read(2)` works; not part of DUEL1).

## The mode (fork `thomasklemm/duel-ruby:callgrind`)

`duel --callgrind`, off by default: every worker runs under `valgrind --tool=callgrind --instr-atstart=no
--collect-atstart=no`, and a new `Native::Callgrind` counter turns instrumentation on at open and toggles
collection around each measured block through Valgrind client requests (x86-64 sequence in an mmap'd page,
through Fiddle), dumping and reading `totals:` at each stop. Instructions judge (Duel's limit 1.01), allocations as
ever, CPU time only sizes samples. A sample is one run, warm-up is 10 samples (counts fall for about 6, then are
exact within a worker; across processes ±0.3%, one benchmark ±1%). GC: Duel's own per-sample `GC.start` +
`GC.disable` already gives identical counts with a fixed heap. JIT: refused, as YJIT under Callgrind keeps
compiling millions of instructions per sample after 50+ samples. The reusable workflow gains a `callgrind` input
(apt Valgrind, `--callgrind`).

Calibrated on the pilot commit `cef26e5`; the fork head `7d15f05` adds the workflow input, docs, the JIT refusal
and an mmap return-type fix. Duel suite on Ruby 4.0.9: 936 runs, 0 failures, 100% line/branch/method coverage,
rubocop, standardrb and steep clean. Mutant (`--since origin/main`, 18 subjects): 0 alive in the 509 of 2,642
mutations run before the orb's 4 GB ran out twice; not completed, as the mode isn't proposed.

## Setup

hashie fork base `cg-calibration` (`19e7efb`) = HD1's `bcf21e7` with `gemfiles/duel.gemfile` on the pilot commit
and a second Perf job `instructions` (`callgrind: true`, Ruby 4.0, no JIT, report `instructions`) beside HD1's
CPU-time job (YJIT, jobs=1), plus the `counters` probe. Both jobs judge the same PR in the same run. Fork PRs
#10–#14 A/A (comment-only changes to `lib/`), #15 allocation plant, #16 CPU plant (`key?` three times in
`method_missing`), #17 #656 against a base with `mash.rb` from before it (`cg-calibration-pre656`); `branches.sh`
built them, `round.sh` reran them and collected every attempt, `tally.py` counts (`tally.txt`; raw summaries and
run metadata in `runs/`, full job logs in `logs.tar.gz`).

## Results

| Cohort | CPU-time job (YJIT) | Instructions job (Callgrind) |
|---|---|---|
| A/A, 19 runs | 0 failed, 65/399 unsettled, job 84–111 s (median 93) | 0 failed, 1/399 unsettled, job 184–259 s (median 229) |
| #656, 3 runs | 0 slower, faster 6/8/8, 11/63 unsettled, job median 88 s | 0 slower, faster 6/6/6, 0 unsettled, job median 207 s |
| Allocation plant, 1 run | 13 regressed + across the board, job 419 s | 13 regressed + across the board, job 1,637 s |
| CPU plant, 2 runs | 6 and 5 regressed, job 215 and 184 s | 5 and 5 regressed, job 734 and 915 s |

* The CPU plant reaches 5 benchmarks (those through `method_missing`); instructions flagged exactly those
  (1.067–1.584×, intervals ±0.002), and CPU time caught them too. CPU time's sixth, `[] and dig` at 1.035 in all four
  measurements of run 1, doesn't call `method_missing` (0.999 in instructions): a YJIT effect off the plant's path.
* Widest A/A instructions interval [0.990, 1.010] (`KeepOriginalKeys: read String keys as methods`); all others
  within ±0.003, against the 1.01 limit.
* #656's faster set is the same 6 in every run under instructions (0.935–0.978), 6–8 under CPU time.
* A regression costs most: Duel measures each slower benchmark again 3–4 times in fresh workers, each under
  Callgrind. The allocation plant's instructions job took 27 minutes of Duel's 60-minute default timeout.
* Local A/A in this orb (2 CPUs, Ruby 4.0.9): 21/21 same, 0 unsettled, 241 s.

## Verdict

Not worth proposing as a gate for hashie: HD1's CPU-time gate already had 0 false alarms at jobs=1 and caught
every benchmark both plants reach, so the quieter verdicts buy no catches, and every job gets 2.5–4× slower.
The case Callgrind would win, a change of 1–2% that CPU time leaves unsettled, wasn't planted; it would need its own
calibration before anyone argued it. No reviews were run (the brief stops here).
