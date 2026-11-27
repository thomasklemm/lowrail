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

## Combined layout for dblock's review (candidate `87a9f22`, not on the PR branch)

dblock on #659 (issuecomment-7192448526): "Let's figure out a way to combine duel and existing benchmarks?". Candidate
on fork branch `thomasklemm/duel-benchmarks`, one commit on `e1adebc` (the PR branch stays at `c4303d5`):

* `duel/` moves to `benchmarks/` (`benchmark_helper.rb`, `*_benchmark.rb`, `fixtures/`), `.duel.rb` sets
  `c.benchmarks = 'benchmarks/**/*_benchmark.rb'`; `perf.yml` paths and the RuboCop exclusion follow.
* The three benchmark-ips scripts are deleted; `extensions_benchmark.rb` adds 8 scenarios: plain Mash reading
  Symbol-given keys and `Mash.new` of a flat Hash, KeepOriginalKeys reading Symbol and String keys,
  PermissiveRespondTo include, `new`, new-key write and overwrite. Dash read/write does 6 operations instead of 3.
  21 scenarios.
* `benchmark-ips` and `benchmark-memory` leave the Gemfile (only `spec/integration/omniauth`'s own Gemfile uses
  benchmark-ips); the `.rubocop_todo.yml` entry for the deleted script goes; CONTRIBUTING describes one kind.
* CHANGELOG line numbered `[#659]`.

Calibration on the fork, same PRs #1–#8 rebased each time:

| Round | Head | A/A | #656 candidate | Plants (alloc / CPU) | A/A job |
|---|---|---|---|---|---|
| 3 | `1649b89`, 21 scenarios incl. 1-key reads | 0/10 failed, 3 re-measured | 1/2 failed: Dash read/write 1.031–1.035 in 4 measurements (code #656 doesn't touch) | 13 / 5 | 73–110 s |
| 4 | `210665a`, reads widened to 5 keys | **1/20 failed**: plain Symbol-key reads 1.052–1.071 in 4 measurements, across-the-board 1.001 | 0/3 | 13 / 5 | 72–101 s |
| 5 | `87a9f22`, `c.jobs = 1` | **0/20**, none re-measured, 51/420 unsettled | 0/4, faster on 6–7 | 13 / 4 | 80–90 s |
| 6 | `bcf21e7`, rebased on master `812c48c` (#656 merged), `mash_new_keys.rb` deleted, CONTRIBUTING wording | **0/15**, none re-measured, 45/315 unsettled | — (#656 is the baseline; fork PR #8 closed) | 13 / 5 | 81–91 s |

Both false failures occurred with two benchmarks at a time. Cross-benchmark CPU contention is a hypothesis, not a demonstrated cause. With one at a time, round 5 had no A/A remeasurement and a median job time of 84 s versus round 4's 76 s. The earlier 13-scenario cohorts had 0/35 failures at two at a time; these different cohorts do not isolate the cause or establish a negligible false-alarm rate. Raw: `calibration-3`, `-4`, `-5`; `round.sh` reruns and collects them.

## On the PR branch (2026-11-27)

`bcf21e7` force-pushed to `thomasklemm/duel` (master still `812c48c`). Upstream checks ran without a maintainer's
approval and all 15 passed. Perf run 45983825333: 21 benchmarks in 69 s, 0 regressed, 4 unsettled (Dash read/write,
both KeepOriginalKeys reads, PermissiveRespondTo `Mash.new`), job 105 s.

## Coverage and settled timings (candidate `a00b9ab`, one commit on `bcf21e7`)

Thomas approved extending #659 with a second commit (the first, `bcf21e7`, is what dblock is reviewing). Candidate on
fork branch `thomasklemm/duel-coverage`.

**Coverage.** Six scenarios for paths no scenario reached (27 in all): IndifferentAccess `new` from the nested
fixture (fresh `JSON.parse` copies in `untimed`, because IndifferentAccess converts nested hashes in place), reads
with String and Symbol keys (`[]`, `fetch`, `key?`), writes (`[]=`, `store`); DeepFind and DeepFetch on nested keys;
a Dash with `Dash::IndifferentAccess` from String keys; a Dash coercing nested Dashes (`IgnoreUndeclared` owners and
licenses). Not added because a scenario already covers them: `Mash#to_hash`, `Mash#deep_merge`, Dash coercion,
Trash translation, and `to_json` (`Hashie::Hash#to_json` is `to_hash.to_json`, so it only adds the JSON generator).
Each new body was run once outside Duel (`.amp`-side check script): nested coercion yields `OwnerDash` and
`LicenseDash` objects, IndifferentAccess reads both key types, and the shared fixture is unchanged afterwards.

**Why timings were unsettled.** PR run 45983825333 on `bcf21e7`: Dash read/write `[0.981, 1.029]`, KeepOriginalKeys
Symbol reads `[0.933, 1.031]`, KeepOriginalKeys String reads `[0.986, 1.026]`, PermissiveRespondTo `Mash.new`
`[0.969, 1.027]`; rounds 5–6 had 96 of 735 A/A verdicts unsettled, nearly all on the sub-microsecond method-dispatch
benchmarks. Duel judges over the 12 workers' medians (Mann-Whitney interval, at most 120 pairs), so the interval is
as wide as the spread between processes; more iterations per sample don't narrow it (Duel sizes samples to 1 ms).

Round 7 (`calibration-7`, `-7p12`) tested the obvious fix and found the real problem:

| Head | Settings | A/A | Unsettled |
|---|---|---|---|
| `4b01c26` | 24 processes, CPU limit 1.02 | **3/5 failed** | 18 of 135 |
| `2f59970` | 12 processes, CPU limit 1.02 | **3/5 failed** | 28 of 135 |

Every failure held in four fresh-process measurements: `Mash: read keys given as Symbols as methods`
at 1.027–1.041, `Mash: read keys as methods` at 1.037–1.046, KeepOriginalKeys Symbol reads at 1.030–1.052, on trees
that differ by one comment. `Mash#to_hash` came out 0.96 (settled faster) in all five A/A runs and in the #656 run,
which doesn't touch it; earlier rounds put the same `to_hash` between 0.946 and 1.027. So identical code shifts by
3–7% for a whole run, in fresh processes too, which more samples cannot average away; more workers only make
Duel surer of the shift. Code layout is the likely cause (a comment moves what follows it), but that is a hypothesis.
The 0/35 at 1.02 of rounds 5–6 held for that set of benchmarks; adding six changed which ones the shifts hit.

Across all 2,111 A/A and #656 measurements of rounds 1–7, an interval's lower bound passed 1.05 once (1.051).
Round 8 therefore sets `c.measure('cpu', limit: 1.05)` and `c.processes = 24`; allocations still fail on any
increase (`calibration-8`, `python3 -I tally.py calibration-8`):

* **A/A: 0 of 20 runs failed, none measured again, 6 of 540 verdicts unsettled**, job 124–137 s (median 130 s),
  Duel 109–118 s; the highest lower bound was 1.048. The six: KeepOriginalKeys Symbol reads three times (medians 1.030–1.036, upper bounds
  1.051–1.057), Dash read/write twice (1.063 and 1.068, intervals `[1.043, 1.083]` and `[1.048, 1.085]`),
  `Mash: read keys as methods` once (1.041 `[1.026, 1.054]`). Each is a shift of the kind above whose interval
  straddles 1.05; unsettled doesn't fail. Dash read/write at 1.068 is the closest to a false alarm: the margin there is
  thin, and `limit: 1.1` is the fallback if one shows up.
* **#656 candidate** (fork PR #9: `duel-calibration-pre656` = the candidate with `lib/` of `812c48c^`, head adds
  `lib/` back): 0 of 3 slower, 0 unsettled, faster on 5–6 (deep_merge 0.82, Mash.new 0.82, respond_to? 0.77,
  overwrite 0.85, flat Mash.new 0.92), allocations down as before. #8 could not be reopened (branch recreated).
* **CPU plant:** 4 regressed in both runs (method reads, plain and KeepOriginalKeys, Symbol and String), job
  222–238 s. **Allocation plant:** 13 regressed on allocations, job 432 s: its CPU timings sat at 1.049–1.054,
  so Duel measured them again up to seven times. Only a run that fails pays that.
* Opening #9 with "hashie/hashie#656" in its body put a cross-reference event on upstream #656's timeline (as #8
  did on 2026-11-26); the body was edited within a minute. It is not a comment, but it is visible upstream.

Local: Ruby 4.0.9 `rake` 1,076 examples 0 failures, RuboCop 155 files clean (`cpu` added to `.spellcheck.txt`);
Ruby 3.0.7 `rake spec` 1,072/0 (bundler 2.5.23, own lockfile).
