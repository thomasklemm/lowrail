# Duel regression guards for hashie: calibration (HD1, 2026-11-26)

Port of ruby-grape/grape#3077 to hashie for hashie/hashie#658: fork branch
`thomasklemm/hashie:thomasklemm/duel` at `9c30091`, one commit on master `e1adebc`. Duel 0.3.1, reusable workflows
pinned to `3c0c99d95dc2d5620f59e4bb298179422086adf7` (the v0.3.1 tag), Ruby 4.0 with YJIT on `ubuntu-latest`.
Duel's defaults: CPU limit 1.02, confidence 0.99, 12 workers per version, warm-up 2 s (`.duel.rb`).

## Setup

Fork base branch `duel-calibration` = the port commit. Each calibration branch is one commit on it, opened as a PR
against `duel-calibration` inside the fork (thomasklemm/hashie#1–#8); `calibration-branches.sh` built them. The fork's
Actions had never run (0 runs) although the permissions API said enabled; `PUT /actions/workflows/{id}/enable` on CI
cleared the fork gate, then the PRs were closed and reopened. `perf-comment.yml` runs only from the default branch,
so it was not exercised on the fork (it is Duel's reusable workflow, as in Grape).

| PR | Branch | Change in `lib/` | Expected |
|---|---|---|---|
| #1–#5 | `calib/aa-1`…`aa-5` | one comment line (mash.rb ×4 at different methods, dash.rb ×1) | pass, nothing slower |
| #6 | `calib/plant-alloc` | `convert_key` back to `Symbol#to_s` (reverts #613's `Symbol#name`) | fail |
| #7 | `calib/plant-cpu` | `method_missing` checks `key?` three times for a stored key, no extra allocation | fail |
| #8 | `calib/hm1` | `lib/hashie/mash.rb` of fork commit `d874851d79` (hashie/hashie#656) | faster or same, never slower |

A/A PRs were rerun 4 times each (`gh run rerun`), hm1 twice: 25 A/A runs, 3 candidate runs, 1 run per plant.

## Results

`python3 -I tally.py` (raw: `calibration/*.summary.txt`, run metadata `*.json`, full job logs `logs.tar.gz`):

* **A/A false alarms: 0 of 25 runs.** 79 of 325 verdicts were "too close to the limit to settle", which Duel reports
  and doesn't fail. One run (aa-2 attempt 2) had `Dash.new: required properties and defaults` at 1.031 [1.021, 1.041]
  slower in the first measurement; Duel measured it again in fresh processes four times (1.019–1.025, each too close
  to call) and passed it. Identical code shows medians up to ~1.03 on some runners (Dash.new required in aa-2 a1/a2
  and aa-5 a3, respond_to?, to_hash), not tied to one branch: aa-2 went back to 0.988 in attempt 3. So the margin to
  the 1.02 limit is thin for CPU time, but Duel's measure-again rule held in every run. Not tuned: defaults kept.
* **Instruction counts: not available** on GitHub's runners (no `instructions` metric in any log; `perf_event_open`
  isn't offered), so CPU time and exact allocation counts judge. Same in this orb (gVisor): `local-aa-orb.txt`.
* **Allocation plant caught:** 8 regressed (every Mash benchmark through `convert_key`), each worse in CPU and
  allocations in every measurement, e.g. Mash.new 105.7 → 143.7 objects, read keys as methods 5 → 15, plus
  "slower across the board". The 4 Dash/Trash benchmarks, which don't call `convert_key`, stayed the same.
* **CPU plant caught:** `Mash: read keys as methods` 1.465–1.519× in all four measurements, allocations unchanged.
* **#656 candidate:** 0 regressed in 3 runs; faster on 6, 3 and 5 benchmarks; allocations down on the same 5 in each
  run: Mash.new 105.7 → 25.7, deep_merge 120.6 → 31.6, respond_to? 6 → 1, overwrite 9 → 6, new key 7 → 5.
* **Runtime:** A/A job 47–84 s (median 58 s), Duel's own measuring 33–64 s; candidate 53–94 s; a regression costs
  more because Duel measures again: 93 s (CPU plant), 248 s (allocation plant).
* The fork's regular CI passed on all A/A and candidate branches (lint included); the plants fail it as expected
  (allocation specs; RuboCop on `key? && key? && key?`).

Local check before pushing (`local-aa-orb.txt`): Ruby 4.0.9 + YJIT, `bundle exec duel --force --base HEAD`, 52 s,
0 regressed, 3 unsettled; `rake spec` 1,075 examples 0 failures, `rake rubocop` 157 files clean.

## Recalibration on the reviewed fix `c4303d5` (calibration-2)

After thermos-sol's changes (Trash `with:` → `transform_with:`, comments removed; `lib/` unchanged), the 8 fork
branches were rebased onto `c4303d5` and force-pushed (same PRs #1–#8), and the A/A runs rerun once
(`python3 -I tally.py calibration-2`):

* **A/A: 0 of 10 runs failed**, 26 of 130 verdicts unsettled, job 48–77 s (median 55 s). One run (aa-3 attempt 2)
  measured `Dash.new: required properties and defaults` again: 1.026 [1.020, 1.033] first, then 1.021–1.028 four
  times, each too close to call, and passed. That is the same benchmark as the first cohort's only re-measured run,
  so it is the one closest to a false alarm on identical code (2 of 35 runs re-measured it; 0 of 35 failed).
* Trash now transforms (`topics` joined): 4 allocations per call instead of 3.
* **Allocation plant:** 8 regressed, as before (Duel 220 s). **CPU plant:** method reads and suffix reads regressed
  (2), job 86 s. **#656 candidate:** faster on 5, none slower, the same allocation drops, job 50 s.
