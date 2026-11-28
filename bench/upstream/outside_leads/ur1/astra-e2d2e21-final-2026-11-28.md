# UR1 Astra final head and numbers confirm

**Approve** `e2d2e21a570516424a3a935e5ab2a67db0ac53d0` and the body after front matter in
`bench/upstream/pr-queue/items/UR1.md` at Lowrail `f2365d60`. No remaining fix requested.
Reviewer: astra, thread `T-01a21efb-d5e7-75fa-9191-e49b123b5747`, 2026-11-28.

## Exact head and message

Fetched the URI review branch and verified parent `48cda77031e343d35213c36fe164b2a46ffbefa7` and tree
`3621b78834d9d699a0d8266887720d8ba6ffdfc8`. `git diff d4ce0b0 e2d2e21` is empty. The earlier eight-runtime
code/test approval therefore applies without another behavior-matrix run. No new boundary is introduced.

Read the complete final message: it correctly attributes TruffleRuby subclass preservation to
`CGI.unescapeURIComponent` and removes the unqualified speed clause. Both message findings are resolved.
The body differs from the previously approved nonnumeric draft only in its six table rows; its citations
and other prose are unchanged. Exact body SHA-256, including leading whitespace:
`44d2727dbc020c16a9db6044b335962f0f585d5949af3bfdfa0afcecc082207e`.

## Every table cell agrees with the raw benchmark-ips output

Read all nine interpreter benchmark-ips logs in `body/UR1-d4ce0b0-4010-time`, not just results.json.
For each input, before is the mean of the maxima of the two three-run base series; after is the candidate
three-run maximum. All twelve printed cells match the existing formatter. The cookie is actually 248 bytes.

| Case | Before, unrounded i/s | After, unrounded i/s | Body before → after | A/A spread |
| --- | ---: | ---: | --- | ---: |
| Form hello | 2,845,000 | 3,434,000 | 2.84M → 3.43M | 2.32% |
| Form key | 880,762 | 2,487,000 | 880.8k → 2.49M | 1.87% |
| Form value | 739,846.5 | 2,921,000 | 739.8k → 2.92M | 0.24% |
| Cookie | 493,948.5 | 1,083,000 | 493.9k → 1.08M | 7.87% |
| URI hello | 2,828,000 | 3,396,000 | 2.83M → 3.40M | 1.63% |
| URI user | 1,131,000 | 2,844,000 | 1.13M → 2.84M | 1.77% |

Every improvement exceeds its A/A spread. The cookie A/A is comparatively large, but remains far below
its measured improvement; it is not concealed or substituted with another run. These are interpreter
benchmark-ips rates, not the YJIT/ZJIT time reductions below.

## Timing, controls and JIT-flat gates agree

Independently parsed all 180 raw wall-process logs in `body/UR1-d4ce0b0-{4010,master}-time`. Verified their
30 windows per case, calibrated/executed call counts, core pinning and YJIT/ZJIT command flags. Recomputed
all twelve point estimates and seeded 5,000-resample, whole-round bootstrap intervals from raw samples.
They agree with results.json. Every A/A 95% interval contains zero; every change interval excludes zero.

| Case | Ruby 4.0.10 YJIT time change | Master 0d399335b7 ZJIT time change |
| --- | ---: | ---: |
| Form hello | −29.523653% | −23.536647% |
| Form key | −71.911894% | −70.132840% |
| Form value | −79.985611% | −77.835680% |
| Cookie | −61.363200% | −59.129542% |
| URI hello | −30.435532% | −27.507322% |
| URI user | −68.592941% | −65.590236% |

The combined point-estimate reduction range is **23.536647%–79.985611%**: the body's **23%–80%** is supported.
This is the harness's thread-CPU time per call with GC off, using the 10th-percentile window per process
and median paired log ratios; it is not an end-to-end request or GC-on claim.

All 1,080 process/case JIT records have every required counter present and zero absolute accumulated
movement, covering **32,400 timed windows**. Read the worker implementation to verify that `0>0` records
accumulated absolute deltas rather than silently replacing absent counters with zero. YJIT checks ISEQ/
block compilation and invalidation; ZJIT checks ISEQ compilation, failed compilation, compiled side exits
and invalidation time. No missing or moved counter was accepted. Base/candidate use the same Ruby pin
within each cohort and record clean base/d4ce0b0 checkouts; the measured candidate tree equals final head.

## Allocation claim agrees with raw object logs

Parsed all nine object logs: interpreter and YJIT on 4.0.10, ZJIT on the same pinned master. Both base
runs are identical in all eighteen case/backend comparisons. In table order, raw counts are
`[3.999, 7, 8, 7, 4, 6]` before and `[2.999, 2, 2, 2, 3, 2]` after on all three backends. The first
entry's 0.001 finite-window discrepancy is retained, not hidden. The harness's integer rounding supports
**2 or 3 objects instead of 4 to 8**. Object passes are separate from timed-window JIT-flat records.

## Retained receipt

Adjacent `astra-e2d2e21-final-2026-11-28.tar.gz` contains the independent audit, complete audit output,
body/message snapshots, empty tree diff, reviewed worker and SHA-256 manifest of all consumed inputs.
Raw logs are already committed at `f2365d60` (introduced by `dff62932`); they are not duplicated.
To replay, extract the archive's `ur1-final-confirm` directory under `.amp/in/orb-backup/` in this repo
with those benchmark directories present, and run `ruby .amp/in/orb-backup/ur1-final-confirm/audit.rb`
using Ruby 4.0.10. It reports `PASS: all 12 table cells, 12 wall cells, A/A intervals, 32,400 JIT-flat
windows and object logs`. This confirm audits the kept measurements; it does not claim a new timing run.
No queue edit, URI push or upstream comment was made.
