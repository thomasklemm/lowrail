# A second Duel job under ZJIT for hashie: calibration (2026-11-27)

Question: is a Duel job with `jit: zjit` (Ruby 4.0) as clean a gate as HD1's YJIT job, so it can follow #659 as its
own PR? Answer: **yes on this evidence**; ZJIT and YJIT never disagreed on which benchmarks a plant regressed.

Setup: fork base `duel-calibration` = `6aaf498`, one commit on #659's head `ef3b274` that adds a second reusable-workflow
call to `perf.yml` (`jit: zjit`, `report: zjit`, same pin, same `gemfiles/duel.gemfile`, same `.duel.rb`: one at a
time, 24 workers, CPU limit 1.05, warm 2 s). Both jobs judge the same PR in the same run, on separate runners. Fork
PRs #1–#5 A/A (comment-only `lib/` changes), #6 allocation plant (`convert_key` back to `Symbol#to_s`), #7 CPU plant
(`key?` three times in `method_missing`), #9 #656's change against `lib/` before it. `collect.sh` saves each job's log
and summary per attempt (`runs/yjit`, `runs/zjit`, logs in `logs.tar.gz`), `round.sh` reruns; `tally-*.txt` from
`../tally.py`. All timing is GitHub's runners (Ruby 4.0.10); no local timing, so no a1.xxlarge orb was needed.

| Cohort | YJIT job | ZJIT job |
|---|---|---|
| A/A, 20 runs | 0 failed, 0 re-measured, 16/540 unsettled, job 122–139 s (median 131) | 0 failed, 0 re-measured, 2/540 unsettled, job 123–153 s (median 131) |
| #656, 3 runs | 0 slower, faster on 5/6/6 | 0 slower, faster on 5/3/5 |
| Allocation plant, 2 runs | 13 regressed both; across-the-board CPU both | 13 regressed both; across-the-board CPU in run 2 only |
| CPU plant, 2 runs | 4 and 5 regressed | 4 and 5 regressed |

* Plants: the regressed benchmark sets are identical between the JITs in all four plant runs (`diff` of the sorted
  REGRESSION lines). The only difference: in allocation run 1 YJIT also confirmed an across-the-board CPU regression
  and ZJIT didn't; both confirmed it in run 2. The 13 allocation regressions don't depend on the JIT.
* CPU plant run 2 adds `Mash: read keys with suffixes` under both JITs; run 1 under neither.
* #656 under ZJIT: smaller gains (deep_merge 0.92 vs 0.83–0.85, Mash.new 0.91–0.94 vs 0.85–0.87, respond_to?
  0.81–0.88 vs 0.79–0.80), and overwrite isn't settled faster (YJIT 0.85). Never slower. Allocation drops are the same.
* Unsettled: YJIT's 16 are KeepOriginalKeys Symbol reads (11) and `respond_to?` (5), medians 1.036–1.060, as in round
  8. ZJIT's two are in one run (aa-3 a1): IndifferentAccess reads 1.036 and KeepOriginalKeys String reads 1.040.
  ZJIT's A/A intervals are generally narrower.
* Wall time: the jobs run in parallel, so a PR's Perf wait doesn't grow; runner minutes double. Plants cost 8.5–9 min
  per job (Duel re-measures CPU timings near the limit).

Follow-up PR, after #659 merges: the second job as above, `report: zjit`. Open question before building it: whether
the YJIT job then also needs `report: yjit` (Duel's docs name every call), which would rename its check from
`duel / Duel` to `duel / Duel (yjit)`; Perf Comment's handling of two reports wasn't exercised on the fork (it runs
only from the default branch).

## Perf Comment with two reports (2026-11-27)

The open question above, answered on the fork. The follow-up commit (`yjit` job with `report: yjit`, `zjit` job with
`report: zjit`) became the fork's default branch for the test, so Perf Comment ran from it; afterwards the default was
restored to `master` and the test PRs and branches removed. Run IDs in `comment-test/runs.tsv`.

* CPU plant PR (fork #19, `key?` three times in `method_missing`): Perf failed; Perf Comment posted **one** comment with
  a `## yjit` and a `## zjit` section, each "4 benchmarks failed" (`comment-test/plant-cpu-comment.md`). Checks are
  named `yjit / Duel (yjit)` and `zjit / Duel (zjit)`.
* A/A PR (fork #18, comment-only): Perf passed, Perf Comment succeeded and posted nothing (default
  `comment = :failures`).

So two reports need no change to Perf Comment. The follow-up renames the job key `duel` to `yjit`; keeping `duel` would
name the check `duel / Duel (yjit)`. Either way the YJIT check's name changes, which branch protection would notice.

## One matrix job (2026-11-27)

dblock's optional nit on #660: one `duel` job with a matrix `entry: [{jit: yjit}, {jit: zjit}]`, `fail-fast: false`,
`name: Duel (${{ matrix.entry.jit }})`, and `jit`/`report` from the entry. Taken as written: head `62f869a` (amends
`f6545d1`, only `perf.yml` and the message differ). Tested on the fork as above (`62f869a` as default branch
`duel-matrix-test`, default restored to `master`, probe PRs closed and branches deleted, Danger Comment stayed
disabled). Run IDs, jobs, artifacts and checks in `matrix-test/`.

* A/A PR (fork #30, comment-only): `Duel (yjit) / Duel (yjit)` pass 2m31s and `Duel (zjit) / Duel (zjit)` pass 2m38s,
  started within 6 s of each other; artifacts `duel-report-yjit` and `duel-report-zjit`; Perf Comment succeeded and
  posted nothing.
* CPU plant PR (fork #31): both checks fail and each ran to the end (4m8s, 4m4s), so `fail-fast: false` holds; one
  comment with `## yjit` and `## zjit`, each "4 benchmarks failed", the same four benchmarks
  (`matrix-test/plant-cpu-comment.md`).

Why it works: Duel's inner job is named `Duel (<report>)` and uploads `duel-report-<report>`; `report` per entry keeps
the artifacts apart, and Perf Comment downloads `duel-report*` into one comment. The check name is caller name plus
inner name, so it repeats: `Duel (yjit) / Duel (yjit)`. `name: ${{ matrix.entry.jit }}` would give the earlier
`yjit / Duel (yjit)`; a plain `jit: [yjit, zjit]` matrix behaves identically to `entry`. Kept his form.
