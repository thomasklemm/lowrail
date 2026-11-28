# Wall-time stability on a1.large compared with a1.xxlarge (2026-11-27/28)

Question from the coordinator: is a1.large stable enough for wall-time cohorts, so timing does not always need
a1.xxlarge (DECISIONS, Benchmark tables)? To test it, I reran two recorded a1.xxlarge cohorts on one a1.large orb
with the same script, Ruby pin, warm-up and `script/upstream-bench` settings. The same orb ran nothing else while
the cohorts ran (`runs.sh`, serially).

* **SCB1** (solid_cable listener poll): base 40dd29ffdc, candidate 2cb1842043, which has the same tree and parent as
  the measured ef534cc941/155a2fbe98. References: `solid_stack/body/SC1-xxl` (YJIT, Ruby 4.0.10, warm-up 500,
  plus benchmark-ips over 5 rounds) and `solid_stack/body/SC1-zjit-wall` (ZJIT, master 0d399335b7, warm-up 2000).
* **ASC1** (association loads, small effect): Rails main 2e299253f9 against ed1b28c5b9, whose lib tree is the same as
  the measured 2b46f50bda. References: `census13r/body/ASC1-wall-yjit` and `ASC1-wall-zjit`, warm-up 3000.

Every cohort ran 30 rounds of base/candidate/base2 fresh processes on `taskset -c 1`. Third-party locks match the
references. Master was built here from 0d399335b7 (`--enable-zjit --enable-yjit --disable-install-doc`); 4.0.10
comes from mise. Raw data is in `SC1-yjit`, `SC1-zjit`, `ASC1-yjit` and `ASC1-zjit`, each with commands.sh,
results.json and table.md. Orb data is in `orb/`. `compare.rb` and `steal.rb` produce `orb/compare.txt` and
`orb/steal.txt`.

## Orb

8 vCPUs, one socket, 4 cores × 2 threads (KVM, Intel Xeon @ 2.60 GHz, kvm-clock). **cpu1, the bench core, is the SMT
sibling of cpu0.** Steal from /proc/stat, sampled every 15 s across all 382 samples: 0.019% on all CPUs (max 0.21%)
and 0.06% on cpu1. cpu1 was 95–99% busy and cpu0 1–2%. `orb/system-metrics.md` holds `amp orb system-metrics` for this
thread. Its one 99.9% sample is the Ruby build, which ran before the cohorts.

## Results (change, 95% interval; A/A median and interval; width in percentage points)

| Cell | xxlarge change | a1.large change | in xxl CI | xxl A/A (width) | a1.large A/A (width) | JIT-flat xxl / large |
| --- | --- | --- | --- | --- | --- | --- |
| SC1 YJIT idle | −14.8% [−15.3, −14.3] | −14.9% [−15.3, −14.3] | yes | −0.9% [−1.5, +0.1] (1.6) | +0.1% [−0.5, +1.0] (1.5) | 90/90 / 90/90 |
| SC1 YJIT one message | −6.6% (no claim) | −6.8% (no claim) | yes | −0.3% (2.3) | −0.1% (2.2) | 47/90 / 38/90 |
| SC1 ZJIT idle | −15.0% [−15.4, −14.5] | −16.0% [−16.7, −15.4] | no (−1.0 pp) | −0.1% [−0.9, +0.9] (1.8) | +0.4% [−0.3, +1.3] (1.6) | 90/90 / 90/90 |
| SC1 ZJIT one message | −6.9% [−8.0, −5.7] | −8.0% [−8.9, −7.0] | no (−1.1 pp) | +0.3% (2.2) | +0.8% (2.5) | 90/90 / 90/90 |
| ASC1 YJIT belongs_to | −3.5% [−5.0, −2.1] | −1.7% [−2.2, −1.2] | no | −0.3% (3.7) | −0.5% (1.3) | 90/90 / 90/90 |
| ASC1 YJIT has_one | −2.8% [−4.4, −1.7] | −1.0% [−1.5, −0.6] | no | −0.5% (5.7) | −0.4% (1.1) | 90/90 / 90/90 |
| ASC1 YJIT has_many | −2.2% [−3.4, −1.0] | −1.2% [−1.5, −0.7] | yes | −0.5% (5.3) | −0.6% (1.3) | 90/90 / 90/90 |
| ASC1 ZJIT belongs_to | −1.9% [−2.7, −0.5] | −1.9% [−2.1, −1.1] | yes | −0.5% (3.1) | +0.4% (1.4) | 90/90 / 90/90 |
| ASC1 ZJIT has_one | −3.2% [−4.0, −2.2] | −2.0% [−2.6, −1.1] | no | +0.2% (2.4) | +0.4% (1.5) | 90/90 / 90/90 |
| ASC1 ZJIT has_many | −1.7% [−2.5, −1.0] | −0.5% [−1.2, +0.4] (no claim) | no | −0.0% (2.4) | +0.6% (2.2) | 90/90 / 90/90 |

Every A/A interval contains 0 on both sizes. The one-message case under YJIT compiles during its windows at warm-up
500 on both sizes, so it is not JIT-flat and carries no claim on either; the same warm-up gives the same failure.

**Noise floor.** On a1.large the A/A interval is 1.1–2.5 pp wide and the change interval 0.8–2.0 pp. On xxlarge they
are 1.6–5.8 pp and 0.9–2.8 pp. Spread per round (sd of the log A/A ratio): SC1 2.7–3.2% on large against 2.3–2.9%
on xxlarge; ASC1 1.9–3.4% on large against 4.2–5.8% on xxlarge. Median window over p10 window within a process: SC1
2.7–6.4% against 2.7–7.8%; ASC1 1.2–1.6% against 4.8–6.5%. Within a run, a1.large is at least as quiet as xxlarge.

**Effect between orbs.** The intervals miss each other by about 1 pp for SC1 under ZJIT, and by 1–2 pp for ASC1. The
within-run interval does not cover the difference between orbs. No second xxlarge run exists, so I can't say whether
xxlarge would differ from itself by as much.

**ASC1 base time differs (not explained).** On a1.large, ASC1 takes 2.0–2.2× as long per call as on xxlarge (YJIT
belongs_to 54.1 µs against 26.7 µs; the calibrate logs show the same), and the same holds for my master build. SC1
is within 2% of xxlarge (201 µs against 205 µs). The saving in µs per call agrees: YJIT belongs_to 0.91 against
0.93 µs, has_many 0.81 against 0.75 µs. The ASC1 percentages are smaller because the base is slower, not because a1.large
measures differently. Allocations per call match (96/96/116). I don't know the cause. clock_gettime here takes 82 ns
(monotonic) and 288 ns (thread CPU time), which is too little to explain ~27 µs. A different CPU model on the xxlarge
host is possible but unchecked, because the reference orbs recorded only `nproc` (16).

**benchmark-ips (SC1, YJIT, 5 rounds).** Idle: +16.7% with A/A 1.3% on large, +15.9% with A/A 1.8% on xxlarge. One
message: A/A 4.6% on large against 1.9% on xxlarge, so no claim on large. This is one sample, but benchmark-ips was
noisier on a1.large where the wall cohort was not.

**Duration** (bundle, objects pass, calibrate, 30 rounds): SC1 YJIT with ips 26.0 min, SC1 ZJIT 22.0 min (xxlarge
~24–25), ASC1 YJIT 24.7 min (xxlarge 15.3), ASC1 ZJIT 22.8 min (xxlarge 14.2). For SC1 the run time matches. ASC1's
longer runs follow its slower calls during warm-up.

## Conclusion

On a1.large the wall cohort (`--wall 30`, p10 thread CPU time per process, pinned to one core, nothing else running
on the orb) resolved effects of about 1% within a run. The A/A half-width is ≤1.25 pp, and has_one at −1.0% [−1.5, −0.6]
was claimed. Comparing orbs adds about 1 pp, and on ASC1 a 2× difference in base time shifted the percentages. So the
smallest effect that a1.large reproduces reliably is **about 3%**: twice the worst A/A half-width plus the 1 pp drift
between orbs (2 × 1.25 + 1 ≈ 3.5 pp). The same formula on the xxlarge references gives about 3 pp for SC1 and up to
about 7 pp for ASC1, whose A/A widths reach 5.7 pp. In these cohorts xxlarge was no more precise than a1.large.

Suggested rule for the coordinator to decide; DECISIONS is unchanged:

* Wall cohorts on a1.large count for records and triage when the effect is ≥ 3% and A/A and JIT-flat pass, with
  nothing else running on the orb during the cohort, because cpu1 shares a physical core with cpu0.
* Every timing number that goes into an upstream body stays on a1.xxlarge. Smaller effects (< 3%) stay there too,
  as do benchmark-ips/`make benchmark` tables: this test did not cover BT1's `make benchmark` failure, and
  benchmark-ips had the wider A/A on a1.large.
* Reported timings should name the orb's CPU model (`lscpu`). The 2× ASC1 base time shows that hosts can differ for
  some workloads.
