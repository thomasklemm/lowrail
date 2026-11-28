# ruby/ruby#17251 split: commit 1, commit 2 and the 1.25× cadence, sequential (2026-11-28)

Follow-up to [11-27](../ruby-17251-2026-11-27/README.md), whose numbers came from four concurrent lanes. This run has
one lane, nothing else running, and builds that take the PR apart. It answers whether the PR still adds value on
current master and whether our posted numbers
([issuecomment-7229891094](https://github.com/ruby/ruby/pull/17251#issuecomment-7229891094)) hold.

**Result.** (Revised after Astra's review on 39377167; medians of 6 shipit rounds unless stated.)

* **The brief's split was wrong.** All behaviour, including the 1.25× oldgen cadence, is in commit 1. Commit 2 only
  removes the now-unread `RUBY_GC_HEAP_FREE_SLOTS` (unused parameter plumbing). c1 and head run similar shipit majors
  (c1 8.5 / 8.5 / 8.5, head 8 / 9 / 8; c1 − head 0 or ±1 per round). c1 was not run in the suite or on Rails. To
  separate the cadence, the extra build **nocad** is the head with the cadence switched off.
* **The hypothesis does not hold.** Commit 1 alone does not cut shipit to 1–2 majors: 8.5 / 8.5 / 8.5 (interp / YJIT /
  ZJIT) against base's 6 / 6 / 7. Without the cadence (nocad) the head runs 6 / 6 / 6.5, all `nofree`. The extra
  shipit majors come with the 1.25× cadence: head − nocad paired medians +2 / +3 / +2 (ranges +1…+3 / +2…+3 / +1…+2), higher in every pair. No measured cost of
  commit 2 was found; the runs do not prove it is zero.
* **Most RSS changes remain without the cadence.** For the nine ruby-bench rows in the comment draft, nocad's paired
  median after-GC RSS change is within 5 percentage points of the head's (largest gap 4.9 pp, liquid-render interp).
  hexapdf and ruby-lsp are left out: their A/A reaches 35% and 12%. Better than master (after-GC RSS, paired median,
  interp / YJIT / ZJIT): liquid-c −42 / −42 / −38%, liquid-render −19 / −20 / −16%, mail −14 / −21 / −10%, sequel
  −11 / −11 / −9%, lobsters −6 / −6 / −3%, activerecord −5 / −8 / 0%. Worse: gcbench +40 / +40 / +7% (VmHWM about
  +30% in every mode), liquid-compile +2 / +5 / +5%, railsbench +1 / +1 / +2%. On shipit the cadence lowers the sampled
  peak against nocad by paired medians of 2.4 / 4.5 / 3.3 MiB (lower in 5/6, 6/6, 5/6), and costs paired medians of +2 / +3 / +2 majors.
* **The 11-27 GC-time signs repeat in a sequential run.** Shipit head − base: YJIT +168 ms (higher in 5/6; 11-27:
  +139, 6/6), ZJIT −224 ms (lower in 6/6; 11-27: −166, 6/6), interp −65 ms (overlaps the A/A). Concurrent lanes alone
  don't explain them; this does not exclude every contention effect. Under ZJIT most of the decrease appears without
  the cadence (nocad − base −196 ms, 5/6); under YJIT the increase comes with it (head − nocad +206 ms).
* **Corrections to our posted comment** (sequential run; failures to reproduce, not proof the earlier run was wrong):
  * Rails ZJIT RSS, posted "rises in four of five pairs against base (median +9.8 MiB), and all five against its copy
    (+17.7 MiB)": over 2 rounds −2.3 MiB against base (lower in 1/2), +3.3 MiB against base2, A/A −5.6 MiB.
  * Rails YJIT majors, posted 1 → 0, are now 1 → 2 in both rounds.
  * Shipit interpreter GC time, posted head − base median +47 ms, is now −65 ms (both overlap the A/A).
  * Shipit ZJIT sampled peak RSS, posted +1.2 MiB, is now −0.8 MiB.
  * Reproduced: shipit majors 6 / 6 / 7 against 8 / 9 / 8, the YJIT and ZJIT GC-time signs, Rails ZJIT majors higher
    on the head (3.5 against 2). Absolute GC ms are about 20% higher than on 11-27 (base interp 2,761 against 2,294);
    absolute times are not comparable across runs.
* **Not covered by #20110:** on base, `nofree` majors remain on shipit (all 6–7 per run), hexapdf (about 20 per run in
  every mode; head per run interp 5–6, YJIT 5–26, ZJIT 7–8) and gcbench under ZJIT (about 35 per run; head 6). The 35
  Rails workloads take at most 1 per round, ruby-bench lobsters about 2 per run, activerecord and ruby-lsp about 1.
* **gcbench:** base takes one `nofree` major during warmup that drops old objects from about 469k to 150k (all 6
  interp and YJIT runs, record 96 of 838 warmup GCs). Under interp and YJIT, the head and nocad take no major during
  warmup or the measured iterations; the cadence only acts after a major. The higher RSS remains after the harness's
  final full GC, so it is not explained by unswept garbage alone. Measured-window GC time head − base −11% interp,
  +4% YJIT; minors 370 against 520.
* **The author's ruby-bench table** (YJIT, pre-#20110 master and an older head) matches on liquid-c (−42% / ours
  −42%), mail (−18 / −21%), lobsters (−7.5 / −6%), activerecord (−5 / −8%) and railsbench (+0.2 / +1%). It shows less
  here on liquid-render (−41 / −20%) and sequel (−26 / −11%). gcbench steady RSS is reversed (−9% there; here steady
  +37% and after-GC +40% under YJIT), while its warmup peak (56 → 73 MiB there) matches our VmHWM (55 → 72). On shipit
  (+7% there) our sampled peak, a different measure, is −4.2 MiB (about −2%). hexapdf (+16% there) is inconclusive
  here: YJIT after-GC −25% lies outside its observed A/A range (−19.7% to +2.7%), but the three-round head − base and A/A ranges overlap.
* `report.rb` first computed suite GC-time percentages with integer division (−100/0/+100); fixed before this
  revision, report.txt regenerated. No RSS or shipit number changed.

A draft comment for the author is in [comment-draft.md](comment-draft.md). Not posted.

## Key table

Shipit, 6 rounds, median (min–max). Every cell loads the `gcmajors` records; "by reason" counts completed majors over
all 6 rounds.

| mode | build | majors | minors | GC ms | sampled peak RSS MiB | completed majors by reason, limit after |
| --- | --- | ---: | ---: | ---: | ---: | --- |
| interp | base | 6 (6–6) | 196 (190–215) | 2761 (2315–3147) | 151 (149–151) | nofree 36, limit 2.0x 36 |
| interp | base2 (A/A) | 6 (6–6) | 198 (192–204) | 2771 (2501–3075) | 151 (149–152) | nofree 36, limit 2.0x 36 |
| interp | c1 (commit 1) | 8 (8–9) | 166 (147–178) | 2783 (2512–3153) | 148 (146–151) | oldgen 48, limit 1.25x 48 |
| interp | head | 8 (8–9) | 160 (152–178) | 2644 (2615–3046) | 149 (145–150) | nofree 2, oldgen 46, limit 1.25x 48 |
| interp | nocad (head, 2x limit) | 6 (6–7) | 180 (174–208) | 2566 (2363–2941) | 151 (148–153) | nofree 37, limit 2.0x 37 |
| yjit | base | 6 (6–6) | 204 (197–224) | 3080 (2735–3208) | 200 (197–202) | nofree 36, limit 2.0x 36 |
| yjit | base2 (A/A) | 6 (6–7) | 212 (197–226) | 2887 (2444–3233) | 198 (196–199) | nofree 37, limit 2.0x 37 |
| yjit | c1 (commit 1) | 8 (8–9) | 166 (154–175) | 3196 (2622–3575) | 197 (195–200) | nofree 2, oldgen 48, limit 1.25x 50 |
| yjit | head | 9 (8–9) | 175 (161–178) | 3214 (2875–3379) | 195 (194–197) | oldgen 51, limit 1.25x 51 |
| yjit | nocad (head, 2x limit) | 6 (6–7) | 184 (169–197) | 3117 (2540–3299) | 201 (198–202) | nofree 36, limit 2.0x 36 |
| zjit | base | 7 (7–7) | 216 (212–223) | 3134 (2833–3480) | 181 (179–181) | nofree 42, limit 2.0x 42 |
| zjit | base2 (A/A) | 7 (6–7) | 220 (197–225) | 3194 (2827–3444) | 180 (179–181) | nofree 41, limit 2.0x 41 |
| zjit | c1 (commit 1) | 8 (8–9) | 149 (142–153) | 2920 (2555–3017) | 181 (180–183) | nofree 2, oldgen 49, limit 1.25x 51 |
| zjit | head | 8 (8–9) | 154 (147–176) | 2959 (2601–3185) | 180 (177–181) | nofree 1, oldgen 48, limit 1.25x 49 |
| zjit | nocad (head, 2x limit) | 6 (6–7) | 174 (165–184) | 3042 (2769–3090) | 183 (181–184) | nofree 39, limit 2.0x 39 |

Shipit paired by round (median, min–max; rounds where the first build is lower), GC ms:

| mode | head − base | head − base2 | base2 − base (A/A) | head − nocad | nocad − base | c1 − head |
| --- | --- | --- | --- | --- | --- | --- |
| interp | -65 (-229–+324) lower 4/6 | +0 (-240–+212) lower 3/6 | -84 (-313–+397) lower 3/6 | +116 (-322–+472) lower 2/6 | -216 (-573–+452) lower 4/6 | +68 (-311–+389) lower 2/6 |
| yjit | +168 (-310–+460) lower 1/6 | +180 (-29–+641) lower 1/6 | -39 (-559–+51) lower 4/6 | +206 (-424–+545) lower 2/6 | -4 (-463–+564) lower 3/6 | +100 (-463–+425) lower 2/6 |
| zjit | -224 (-503–-10) lower 6/6 | -282 (-632–+166) lower 5/6 | +134 (-344–+295) lower 2/6 | -30 (-489–+224) lower 3/6 | -196 (-423–+257) lower 5/6 | -110 (-438–+405) lower 3/6 |

ruby-bench suite, 3 rounds, paired by round, head − base in % (median, min–max), with the A/A base2 − base and the
cadence-off nocad − base beside it. RSS after the final full GC (ruby-bench's RSS column); VmHWM for the true peak;
whole-run majors are medians. Full per-cell table and steady RSS: [report.txt](report.txt).

| bench | mode | majors whole run b / b2 / h / n | nofree, 3 runs b / h | itr % | after-GC RSS % | A/A base2 − base % | nocad − base % | VmHWM % | VmHWM MiB b / h |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| activerecord | interp | 0 / 0 / 0 / 0 | 2 / 0 | +3 (+0 to +5) | −5 (−7 to −2) | +4 (+0 to +5) | −6 (−7 to −2) | −5 (−6 to −2) | 63 / 59 |
| activerecord | yjit | 0 / 1 / 0 / 0 | 3 / 0 | +7 (−4 to +11) | −8 (−9 to −5) | −0 (−5 to +0) | −8 (−8 to −4) | −8 (−9 to −5) | 77 / 70 |
| activerecord | zjit | 2 / 2 / 1 / 1 | 5 / 0 | −4 (−4 to −1) | −0 (−1 to −0) | −0 (−1 to +1) | −1 (−1 to −1) | −0 (−1 to −0) | 76 / 75 |
| hexapdf | interp | 44 / 44 / 31 / 29 | 67 / 16 | −3 (−4 to +1) | +2 (+1 to +3) | −15 (−30 to −10) | +10 (−6 to +23) | +0 (−0 to +5) | 325 / 324 |
| hexapdf | yjit | 43 / 46 / 31 / 29 | 68 / 37 | −1 (−8 to +7) | −25 (−30 to −10) | −4 (−20 to +3) | +6 (+2 to +12) | −2 (−17 to +8) | 333 / 338 |
| hexapdf | zjit | 39 / 36 / 31 / 33 | 57 / 22 | −3 (−7 to +5) | +32 (−28 to +42) | +30 (−3 to +35) | −13 (−20 to +40) | +7 (−1 to +8) | 323 / 348 |
| liquid−c | interp | 1 / 1 / 1 / 1 | 0 / 0 | +1 (−3 to +3) | −42 (−45 to −36) | −0 (−39 to +0) | −42 (−45 to −38) | −43 (−45 to −36) | 62 / 34 |
| liquid−c | yjit | 1 / 1 / 1 / 1 | 0 / 0 | +2 (+1 to +6) | −42 (−42 to −40) | −13 (−36 to −4) | −42 (−42 to −40) | −42 (−42 to −40) | 67 / 39 |
| liquid−c | zjit | 1 / 1 / 1 / 1 | 0 / 0 | +3 (+3 to +8) | −38 (−41 to −34) | −5 (−5 to +6) | −39 (−40 to −34) | −39 (−41 to −34) | 64 / 38 |
| liquid−compile | interp | 2 / 2 / 2 / 2 | 0 / 0 | +1 (+1 to +1) | +2 (+1 to +6) | +0 (−1 to +1) | +2 (+1 to +2) | +2 (+2 to +6) | 34 / 34 |
| liquid−compile | yjit | 2 / 2 / 2 / 2 | 0 / 0 | +1 (−0 to +1) | +5 (+5 to +5) | −1 (−1 to +0) | +2 (+1 to +2) | +5 (+5 to +5) | 38 / 40 |
| liquid−compile | zjit | 3 / 3 / 2 / 2 | 3 / 0 | −3 (−3 to −3) | +5 (+4 to +5) | +1 (−0 to +1) | +5 (+5 to +6) | +5 (+4 to +5) | 37 / 39 |
| liquid−render | interp | 0 / 0 / 0 / 0 | 0 / 0 | +4 (+0 to +12) | −19 (−22 to −14) | −1 (−8 to +4) | −14 (−26 to −12) | −19 (−22 to −15) | 41 / 35 |
| liquid−render | yjit | 0 / 0 / 0 / 0 | 0 / 0 | −2 (−2 to +1) | −20 (−20 to −12) | +8 (−8 to +13) | −19 (−20 to −11) | −19 (−20 to −12) | 45 / 36 |
| liquid−render | zjit | 0 / 0 / 0 / 0 | 0 / 0 | +0 (−2 to +5) | −16 (−16 to −12) | +3 (+0 to +14) | −14 (−15 to −12) | −16 (−16 to −12) | 41 / 35 |
| lobsters | interp | 1 / 1 / 1 / 1 | 6 / 4 | −1 (−2 to +3) | −6 (−8 to −4) | −2 (−2 to −0) | −7 (−7 to −2) | −6 (−8 to −4) | 295 / 277 |
| lobsters | yjit | 1 / 1 / 1 / 1 | 5 / 4 | +2 (−13 to +10) | −6 (−9 to −2) | −0 (−1 to +1) | −7 (−9 to −6) | −6 (−9 to −2) | 342 / 315 |
| lobsters | zjit | 1 / 1 / 1 / 1 | 3 / 3 | −2 (−3 to +0) | −3 (−3 to −0) | +1 (+0 to +2) | −3 (−4 to −1) | −7 (−10 to −3) | 338 / 312 |
| mail | interp | 2 / 2 / 1 / 1 | 0 / 0 | +3 (+2 to +8) | −14 (−16 to −13) | +2 (+0 to +3) | −14 (−16 to −13) | −1 (−1 to −1) | 52 / 51 |
| mail | yjit | 2 / 2 / 1 / 1 | 0 / 0 | +3 (+2 to +4) | −21 (−21 to −21) | −1 (−2 to −0) | −21 (−22 to −21) | −11 (−11 to −11) | 61 / 54 |
| mail | zjit | 1 / 1 / 1 / 1 | 0 / 0 | −1 (−1 to +2) | −10 (−11 to −9) | +0 (−3 to +1) | −9 (−12 to −9) | −11 (−11 to −9) | 60 / 54 |
| railsbench | interp | 0 / 0 / 0 / 0 | 0 / 0 | −0 (−4 to +0) | +1 (−1 to +2) | +1 (−1 to +1) | +1 (−2 to +2) | +1 (−1 to +2) | 103 / 104 |
| railsbench | yjit | 0 / 0 / 0 / 0 | 0 / 0 | −2 (−4 to +0) | +1 (+1 to +2) | +0 (−0 to +1) | +1 (−0 to +1) | +1 (+1 to +2) | 129 / 130 |
| railsbench | zjit | 0 / 0 / 0 / 0 | 0 / 0 | −1 (−2 to +4) | +2 (+1 to +2) | −0 (−1 to +1) | +2 (+1 to +3) | +2 (+1 to +2) | 118 / 120 |
| sequel | interp | 0 / 0 / 0 / 0 | 0 / 0 | +4 (+0 to +5) | −11 (−12 to −11) | +0 (−1 to +0) | −11 (−11 to −11) | −12 (−12 to −11) | 38 / 33 |
| sequel | yjit | 0 / 0 / 0 / 0 | 0 / 0 | +2 (−4 to +3) | −11 (−12 to −10) | +0 (−2 to +0) | −11 (−11 to −11) | −10 (−12 to −10) | 42 / 38 |
| sequel | zjit | 0 / 0 / 0 / 0 | 0 / 0 | −1 (−1 to +1) | −9 (−10 to −9) | +1 (+0 to +1) | −10 (−10 to −9) | −9 (−10 to −9) | 40 / 37 |
| ruby−lsp | interp | 2 / 1 / 3 / 3 | 3 / 9 | −2 (−4 to −1) | +0 (−1 to +4) | +3 (−2 to +5) | −4 (−4 to +2) | +1 (+0 to +4) | 66 / 67 |
| ruby−lsp | yjit | 2 / 1 / 2 / 3 | 4 / 7 | −0 (−5 to +6) | +6 (−0 to +7) | +12 (+7 to +12) | +4 (−1 to +7) | +6 (+0 to +7) | 69 / 73 |
| ruby−lsp | zjit | 0 / 0 / 0 / 0 | 0 / 0 | +0 (−4 to +1) | +0 (−0 to +1) | −0 (−1 to +0) | +0 (−0 to +0) | +0 (−0 to +1) | 64 / 64 |
| gcbench | interp | 1 / 1 / 0 / 0 | 3 / 0 | +2 (+1 to +4) | +40 (+40 to +41) | −0 (−0 to +0) | +41 (+40 to +41) | +30 (+30 to +31) | 55 / 72 |
| gcbench | yjit | 1 / 1 / 0 / 0 | 3 / 0 | −2 (−4 to +2) | +40 (+40 to +41) | +0 (−1 to +0) | +40 (+40 to +41) | +30 (+30 to +31) | 55 / 72 |
| gcbench | zjit | 47 / 47 / 50 / 34 | 105 / 18 | +7 (+6 to +9) | +7 (+7 to +8) | −1 (−1 to +0) | +12 (+12 to +12) | +29 (+29 to +30) | 56 / 73 |

Rails workloads (35), 2 rounds, sums over Blog, Fizzy and Lobsters, median (min–max):

| mode | build | majors (nofree) | minors | GC ms | RSS at end MiB |
| --- | --- | --- | ---: | ---: | ---: |
| interp | base | 0 (0–0) (0 (0–0)) | 732 (628–835) | 10952 (10926–10977) | 668 (655–682) |
| interp | base2 (A/A) | 0 (0–0) (0 (0–0)) | 732 (663–801) | 10684 (10422–10946) | 658 (637–679) |
| interp | head | 0 (0–0) (0 (0–0)) | 731 (699–763) | 10728 (10109–11348) | 656 (651–661) |
| interp | nocad (head, 2x limit) | 0 (0–1) (0 (0–1)) | 705 (622–788) | 10566 (10415–10716) | 669 (657–680) |
| yjit | base | 1 (1–1) (1 (1–1)) | 646 (537–755) | 11187 (10507–11867) | 898 (888–908) |
| yjit | base2 (A/A) | 1 (0–2) (0 (0–1)) | 815 (807–823) | 11698 (11196–12201) | 876 (869–882) |
| yjit | head | 2 (2–2) (2 (2–2)) | 696 (674–717) | 11336 (11135–11538) | 883 (876–890) |
| yjit | nocad (head, 2x limit) | 0 (0–0) (0 (0–0)) | 713 (689–737) | 10802 (10526–11077) | 870 (863–877) |
| zjit | base | 2 (2–2) (0 (0–0)) | 614 (572–656) | 11492 (10697–12287) | 888 (887–888) |
| zjit | base2 (A/A) | 2 (2–2) (0 (0–0)) | 615 (560–670) | 12072 (11490–12654) | 882 (881–883) |
| zjit | head | 4 (3–4) (1 (1–1)) | 608 (550–666) | 11868 (11124–12613) | 885 (876–894) |
| zjit | nocad (head, 2x limit) | 3 (3–3) (0 (0–1)) | 663 (653–673) | 11842 (11540–12143) | 879 (873–885) |

Paired by round: majors are higher on the head than on base in both rounds under YJIT (+1, +1) and ZJIT (+1, +2), and
equal under the interpreter. GC time and RSS directions are mixed; with two rounds the A/A range (e.g. interp GC
−555 to +20 ms, YJIT RSS −38.8 to −6.2 MiB) is as wide as the head − base range. See report.txt.

## Setup

* **Builds** ([`build.sh`](../../../fixtures/corpus/ruby-41-watch/gcstep/vs17251-split-2026-11-28/build.sh)), all from
  master `f6278067b6`, one in-tree build, `--enable-yjit --enable-zjit`, base Ruby 4.0.9, differing only in
  `gc/default/default.c`:
  * **base** = `f6278067b6`; **base2** = a byte-identical copy of the base install (A/A; `bin/ruby` and
    `libruby-static.a` md5-identical).
  * **c1** = base + [`c1.diff`](../../../fixtures/corpus/ruby-41-watch/gcstep/vs17251-split-2026-11-28/c1.diff)
    (`git diff f6278067b6 b4cb7e52d8 -- gc/default/default.c`, commit 1 only).
  * **head** = base + [`head.diff`](../../../fixtures/corpus/ruby-41-watch/gcstep/vs17251-split-2026-11-28/head.diff)
    (both commits; byte-identical to 11-27's `head.diff`).
  * **nocad** = head with `GC_HEAP_OLDOBJECT_RECLAIM_RATIO` 2.0 instead of 0.1. A major's yield is at most 1, so
    `gc_oldgen_limit_update` never enters the 1.25× cadence and the old-object limit stays at 2×. Everything else in
    the head (per-heap deficit counter, the 1.25×-growth `nofree` trigger, `min_free_slots` without the init floor,
    the removed `gc_marks_finish` decision) is unchanged. Measurement-only variant, not a proposal.
* **How the PR splits** (`git range-diff f6278067b6..b4cb7e52d8 f6278067b6..9715d0224e`): commit 1 `b4cb7e52d8`
  "Trigger nofree majors on a per-heap basis" holds all behaviour, including the 1.25× oldgen cadence
  (`gc_oldgen_limit_update`, `GC_HEAP_NOFREE_OLDOBJECT_FACTOR`, `GC_HEAP_OLDOBJECT_RECLAIM_RATIO`). Commit 2
  `9715d0224e` "Remove RUBY_GC_HEAP_FREE_SLOTS" only removes the parameter, which nothing reads after commit 1
  (`git grep heap_free_slots b4cb7e52d8 -- gc/`: the struct field and the env parsing only). So c1 and head should
  behave identically; c1 − head is a second control for the PR.
* **c1 tests:** `make test-all TESTS="test/ruby/test_gc.rb test/ruby/test_gc_compact.rb"` in-tree on c1: 131 tests,
  0 failures, 0 errors, 10 skips. (Run out of tree, base, c1 and head all have the same 2 errors, `-test-/stack` not
  installed.)
* **One lane, strictly sequential** ([`queue.sh`](../../../fixtures/corpus/ruby-41-watch/gcstep/vs17251-split-2026-11-28/queue.sh)),
  nothing else running, a1.xxlarge orb (16 CPUs, 31 GB). Per round: shipit in all modes, then the suite, then Rails;
  build order rotated by one each round. 2026-11-27 23:39 to 2026-11-28 08:00 UTC, 558 cells, no cell failed, no orb pause.
* **shipit**: ruby-bench `73918b2`, `HARNESS=gcstep`
  ([`gcstep-harness.rb`](../../../fixtures/corpus/ruby-41-watch/gcstep/vs17251-split-2026-11-28/gcstep-harness.rb):
  11-27's harness plus two reads, VmHWM at the end and the per-iteration RSS it already read), 15 warmups + 40
  measured iterations, 6 rounds × 5 builds × interp / YJIT / ZJIT, with the
  [`gcmajors`](../../../fixtures/corpus/ruby-41-watch/gcstep/vs17251-split-2026-11-28/gcmajors/gcmajors.c) per-GC
  records in every cell (so attribution covers all rounds, not 3 extra ones as on 11-27).
* **ruby-bench suite**: activerecord, hexapdf, liquid-c, liquid-compile, liquid-render, lobsters, mail, railsbench,
  sequel, ruby-lsp, gcbench (shipit above), `HARNESS=split`
  ([`harness.rb`](../../../fixtures/corpus/ruby-41-watch/gcstep/vs17251-split-2026-11-28/harness.rb)): 15 warmups,
  then a fixed number of measured iterations per benchmark
  ([`suite.tsv`](../../../fixtures/corpus/ruby-41-watch/gcstep/vs17251-split-2026-11-28/suite.tsv): ≥ 25 iterations
  and ≥ 10 s under YJIT on base in the pilot, as the default harness's minimums), the same for every build. Per cell:
  median iteration time, GC counts and time over the measured iterations, majors and `major_by` over the whole run,
  **VmHWM** (true peak RSS of the process), **steady RSS** (median of RSS after each measured iteration) and
  **after-GC RSS** (Rss from `smaps_rollup` after a final full GC: ruby-bench's own RSS column, the one in the PR
  description). 3 rounds × 4 builds (base, base2, head, nocad; c1 left out as it matches head) × 3 modes.
* **Rails**: Blog, Fizzy, Lobsters on Rails main `50c54eed06` with the 11-25 overlays
  ([`setup.sh`](../../../fixtures/corpus/ruby-41-watch/gcstep/vs17251-split-2026-11-28/setup.sh)), 35 workloads,
  `CENSUS_GC_OPS=1000 CENSUS_GC_MAJOR_BY=1 CENSUS_REQUESTS=0`, one app copy (sequential), **2 rounds** × 4 builds × 3
  modes (cut from 5: a sequential Rails round takes about 95 minutes; rounds were cut before modes).
* **Pilot** ([`pilot.sh`](../../../fixtures/corpus/ruby-41-watch/gcstep/vs17251-split-2026-11-28/pilot.sh)): every
  benchmark 5 + 5 iterations per mode on base, for the iteration counts and the budget.

## Files

* [`report.txt`](report.txt): `report.rb` (all tables and pairs) and `suite.rb` (paired percentages), both regenerated
  byte for byte from the archive (`CENSUS_DIR=receipts/census ruby report.rb receipts`).
* [`receipts.tar.gz`](receipts.tar.gz): every cell's JSON with per-GC records and log (`gcstep/`, `split/`), the
  census JSONs (`census/sp*`), the pilot, queue, build, setup and test logs, the four `default.c` variants and the
  build checksums.
* Scripts: [`vs17251-split-2026-11-28/`](../../../fixtures/corpus/ruby-41-watch/gcstep/vs17251-split-2026-11-28/).

## Reviews

* **Astra** (`openai/gpt-6-astra`, thread T-01a22130-6784-7267-a72f-8daf4cbe82f0) on 39377167: changes required, with
  an exact replacement text, which is now comment-draft.md, with its own gcbench correction ("during warmup or the
  measured iterations") and one antecedent fix ("that full GC" → "the final full GC"). Regenerated report.txt byte
  for byte. Findings: half medians hidden by rounding (c1 8.5, nocad ZJIT 6.5), hexapdf A/A 35% not 30%, head hexapdf
  nofree up to 26, iteration-time and causality claims overstated, two more posted numbers reversed in sign, the
  report.rb integer-division bug. I rechecked the medians, hexapdf counts and A/A figures from the receipts.
* **thermos-sol** (`openai/gpt-6.1-sol`, xhigh, thread T-01a22130-6014-7780-afc1-9d29239fdd53) on 07dcda56: the exact
  text after `---` approved unchanged. Re-ran report.rb and suite.rb on the archive (byte-identical), recomputed all 27
  RSS cells and the previous archive's Rails ZJIT pairs (+9.81 / +17.70 MiB then, −2.28 / +3.29 now, A/A −5.56). Two
  README wording notes (paired-median scope of +2 / +3 / +2; "observed A/A range") applied.

Both reviews accept the draft as it stands at 07dcda56. Astra wrote that text; the one antecedent fix it got afterwards
was in the text thermos-sol approved. Posting needs Thomas's approval of the exact text (brief of 2026-11-28).
