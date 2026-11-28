# UR1 final numbers confirmation — thermos-sol, 2026-11-28

**Approve. No requested fix.** This closes the numerical reservation in the
[code/prose review](thermos-sol-e2d2e21-2026-11-27.md) for URI
[e2d2e21](https://github.com/thomasklemm/uri/commit/e2d2e21a570516424a3a935e5ab2a67db0ac53d0).
I checked the body after the front matter at Lowrail
[f2365d60](https://github.com/thomasklemm/lowrail/commit/f2365d603be004da21cac879f9299b50252bb6fa), not an older table.
The measured d4ce0b0 and final e2d2e21 have the same tree, `3621b78834d9d699a0d8266887720d8ba6ffdfc8`.

Own reconstruction from the raw logs in `body/UR1-d4ce0b0-4010-time` and
`body/UR1-d4ce0b0-master-time`, not just their generated JSON/tables:

| Case | Mean of the two base IPS maxima | Candidate IPS maximum | Body before → after |
| --- | ---: | ---: | --- |
| form hello | 2,845,000 | 3,434,000 | 2.84M → 3.43M |
| form key | 880,762 | 2,487,000 | 880.8k → 2.49M |
| form value | 739,846.5 | 2,921,000 | 739.8k → 2.92M |
| cookie | 493,948.5 | 1,083,000 | 493.9k → 1.08M |
| URI hello | 2,828,000 | 3,396,000 | 2.83M → 3.40M |
| URI user | 1,131,000 | 2,844,000 | 1.13M → 2.84M |

All **12** displayed rate cells match the raw best-of-three calculation and the driver's formatting. These
are MRI **4.0.10, no JIT**. A/A spreads are **2.3199%, 1.8666%, 0.2418%, 7.8654%, 1.6266%, 1.7683%**, respectively;
every gain exceeds its own A/A by several times. The cookie is **248 bytes** in the actual benchmark source.

I independently recomputed all **12** time-change estimates and **24** bootstrap intervals from the **180**
raw timing-process logs: 30 base/candidate/base rounds on each Ruby, 30 windows per case/process. The metric is
the documented thread-CPU time with GC off, not monotonic elapsed time or a whole-request estimate. The
per-process 10th-percentile selection and seeded 5,000 whole-round resamples reproduce the saved results.
Every A/A interval contains zero, and every change interval is wholly below zero.

* **YJIT on 4.0.10:** reductions **29.523653%–79.985611%** (displayed **29.5%–80.0%**).
* **ZJIT on pinned master 0d399335b7:** reductions **23.536647%–77.835680%** (displayed **23.5%–77.8%**).
* Therefore **“23% to 80%” is valid**: 23% deliberately floors the minimum point estimate instead of rounding
  23.536647% up to 24%; 80% is the ordinary whole-percent rounding of 79.985611%. This summarizes point
  estimates, not the endpoints of their confidence intervals.

All recorded sums of absolute JIT-counter deltas are zero: three YJIT counters and four master-ZJIT counters,
covering **32,400 timed windows**. The raw gate records agree with the saved JSON; no missing or moving counter
was counted flat. The retained commands also confirm the JIT flags, CPU pin, fixed heaps, calibration and same
Ruby executable per comparison; both input trees are recorded clean and third-party bundles agree.

The **54** raw allocation observations, in interpreter/YJIT/ZJIT modes, give the same six-case vectors:
**4, 7, 8, 7, 4, 6 → 3, 2, 2, 2, 3, 2** objects/call, with exact base/base A/A. Raw first-hello readings are
**3.999 → 2.999** and round to **4 → 3** under the documented display rule. Thus **“2 or 3 objects instead of
4 to 8”** is accurate for these calls, independently of the time result.

The adjacent `thermos-sol-e2d2e21-numbers-2026-11-28.tar.gz` retains my audit, successful output, exact body
snapshot and SHA-256 input manifest. Raw timing inputs are already committed at the cited Lowrail pin; no
timing was rerun or sample discarded. No queue edit, URI push or upstream post was made.
