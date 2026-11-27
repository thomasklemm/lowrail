# ruby/ruby#17251 rebased: head `9715d0224e` against its base `f6278067b6` (2026-11-27)

The rebased comparison our 2026-11-25 comment said was missing
([comment](https://github.com/ruby/ruby/pull/17251#issuecomment-7152413475),
[record](../../../docs/upstream/ruby-4.1-regression-watch.md#against-rubyruby17251-new-head-57eb4b4274-2026-11-24-re-tested-2026-11-25)).

**Result: on its current base the PR no longer lowers major counts; GC time differs by mode.** Base `f6278067b6`
runs median 6–7 shipit majors (range 6–8; all completed records `nofree`) and at most 3 per round on the 35 Rails
workloads. (The 11-25 base `dec1bb786f` ran medians 28–29, range 27–31, on a different orb and sequentially, so the
cross-run change is not attributed to Ruby alone.) On shipit the head runs 8–9 majors, 76 of 77 completed records
`oldgen` at the PR's 1.25× limit: 1–3 more than the base in 17 of 18 round pairs, tied once, never fewer. Shipit GC
time: interpreter overlaps the A/A; YJIT higher in 6/6 pairs against base (median +139 ms, +2.1% to +13.4%) and 5/6
against base2; ZJIT lower in 6/6 against both (median −166 ms, −4.6% to −19.5%). Rails: GC-time directions are mixed
in every mode; ZJIT majors are higher on the head in 4/5 rounds (+1, +2, +2, +1, 0) and ZJIT RSS is higher in 4/5
against base and 5/5 against base2. Review corrections (Astra, 2026-11-27): the first draft's "about 6%" (a paired
median, not every round) and blanket "inside the A/A" claims were cut.

## Setup

* **PR.** Head [`9715d0224e`](https://github.com/ruby/ruby/commit/9715d0224e) (force-pushed 2026-11-26 22:25 UTC):
  the same two commits as before, rebased onto master
  [`f6278067b6`](https://github.com/ruby/ruby/commit/f6278067b6) (2026-11-26, 234 commits after `760125a4c5`,
  so it includes ruby/ruby#20110). `git range-diff dec1bb786f..57eb4b4274 f6278067b6..9715d0224e`: the second commit
  is unchanged; the first now keeps #20110's "smaller than its initial size" guard as an early return inside the
  deficit branch, and it drops `MAX(total_slots, init_slots)` from `min_free_slots`.
* **Builds** ([`build.sh`](../../../fixtures/corpus/ruby-41-watch/gcstep/vs17251-2026-11-27/build.sh)): base =
  `f6278067b6`; head = base + [`head.diff`](../../../fixtures/corpus/ruby-41-watch/gcstep/vs17251-2026-11-27/head.diff)
  (`git diff f6278067b6 9715d0224e -- gc/default/default.c`; the head's other changes are NEWS, the man page and one
  test); base2 = a byte-identical copy of the base install (A/A). One in-tree build, `--enable-yjit --enable-zjit`,
  base Ruby 4.0.9. No gcstep patch (as on 11-25).
* **shipit**: ruby-bench `73918b2`, `HARNESS=gcstep`
  ([`ruby-bench-harness.rb`](../../../fixtures/corpus/ruby-41-watch/gcstep/ruby-bench-harness.rb)), 15 warmups +
  40 measured iterations, 6 rounds × interp / YJIT / ZJIT, build order rotated each round. Sampled peak RSS =
  max of RSS read after each iteration. Then 3 attribution rounds
  ([`attrib.sh`](../../../fixtures/corpus/ruby-41-watch/gcstep/vs17251-2026-11-27/attrib.sh)) with the
  [`gcmajors`](../../../fixtures/corpus/ruby-41-watch/gcstep/vs17251-2026-11-24/gcmajors/gcmajors.c) tracepoint,
  base and head, alternating.
* **Rails** ([`setup.sh`](../../../fixtures/corpus/ruby-41-watch/gcstep/vs17251-2026-11-27/setup.sh),
  [`queue.sh`](../../../fixtures/corpus/ruby-41-watch/gcstep/vs17251-2026-11-27/queue.sh)): Blog, Fizzy, Lobsters on
  Rails main `50c54eed06` with the 11-25 overlays, 35 workloads, `CENSUS_GC_OPS=1000 CENSUS_GC_MAJOR_BY=1
  CENSUS_REQUESTS=0`, 5 rounds × interp / YJIT / ZJIT, build order rotated per round. RSS = sum over the three apps
  of RSS after each app's last window (`rss_kb_end`); peak = `VmHWM`.
* **Difference from 11-25:** a 16-CPU, 31 GB orb instead of 2 CPUs and 3.9 GB, and four lanes at once (shipit, and one
  Rails lane per mode, each in its own app copies `census5`, `census5y`, `census5z`), each lane sequential with
  builds alternating. Every comparison is within one lane, so lane contention hits all builds of a lane alike;
  absolute times are not comparable with 11-25's. All three Rails lanes append to one `meta.json` per label (may
  lose entries); the report reads only the per-app JSONs. 20:41–22:50 UTC, no cell failed, no orb pause.

## shipit (6 rounds; median, min–max)

| mode | build | majors | minors | GC ms | sampled peak RSS MiB |
| --- | --- | ---: | ---: | ---: | ---: |
| interp | base | 6 (6–7) | 204 (197–225) | 2,294 (2,201–2,414) | 150 (148–152) |
| interp | base2 (A/A) | 6 (6–6) | 206 (198–209) | 2,415 (2,170–2,489) | 150 (148–151) |
| interp | head | 8 (8–9) | 168 (147–189) | 2,385 (2,170–2,486) | 148 (144–151) |
| YJIT | base | 6 (6–6) | 199 (192–211) | 2,326 (2,250–2,456) | 199 (196–199) |
| YJIT | base2 (A/A) | 6 (6–7) | 208 (202–231) | 2,289 (2,235–2,513) | 197 (194–198) |
| YJIT | head | 9 (8–9) | 164 (151–176) | 2,496 (2,369–2,574) | 196 (195–198) |
| ZJIT | base | 7 (7–8) | 222 (219–233) | 2,576 (2,467–2,661) | 180 (178–181) |
| ZJIT | base2 (A/A) | 6 (6–8) | 212 (199–234) | 2,534 (2,364–2,874) | 181 (176–182) |
| ZJIT | head | 8 (8–9) | 150 (145–152) | 2,376 (2,084–2,506) | 181 (181–183) |

Paired by round (median, min–max; rounds where the first build is lower):

* interp head − base: majors +2 (+1 to +3); GC ms +47 (−31 to +123), lower 2/6; peak RSS −2.8 MiB (−6.3 to +1.4).
  A/A base2 − base: GC ms +65 (−31 to +196); head − base2 GC ms −1.5 (−166 to +111), lower 3/6.
* YJIT head − base: majors +3 (+2 to +3); GC ms +139 (+49 to +304), lower 0/6; peak RSS −2.2 MiB (−3.6 to +1.2).
  A/A base2 − base: GC ms −7 (−132 to +140); head − base2 GC ms +150.5 (−91 to +329), lower 1/6.
* ZJIT head − base: majors +1 (0 to +2); GC ms −166 (−504 to −115), lower 6/6; peak RSS +1.2 MiB (+0.2 to +3.8).
  A/A base2 − base: GC ms +1.5 (−224 to +230); head − base2 GC ms −193 (−368 to −100), lower 6/6.

Head − base majors per round: interp 2, 1, 2, 3, 2, 3; YJIT 3, 2, 3, 3, 3, 3; ZJIT 1, 1, 2, 1, 0, 2.

**Attribution** (3 rounds, completed per-GC records; the 11-25 caveats on partial times apply):

| mode | build | completed majors by reason | limit after each major | ms per major | majors per round (`GC.stat`) | GC ms per round |
| --- | --- | --- | --- | ---: | --- | ---: |
| interp | base | nofree 18 | 2× | 61 | 6, 6, 6 | 2,253 |
| interp | head | oldgen 24, nofree 1 | 1.25× | 63 | 9, 9, 9 | 2,448 |
| YJIT | base | nofree 18 | 2× | 79 | 6, 6, 6 | 2,262 |
| YJIT | head | oldgen 25 | 1.25× | 78 | 9, 9, 8 | 2,318 |
| ZJIT | base | nofree 21 | 2× | 64 | 7, 7, 7 | 2,502 |
| ZJIT | head | oldgen 27 | 1.25× | 64 | 9, 9, 9 | 2,366 |

Head majors without a completed record: interp 2 (`GC.stat` 9, 9, 9 against 9, 8, 8 records), YJIT 1 (9, 9, 8
against 8, 9, 8). None on the base or under ZJIT.

## Rails workloads (35 workloads, 5 rounds; median, min–max; RSS summed over the three apps)

| mode | build | majors | GC ms | RSS at end MiB | peak RSS MiB |
| --- | --- | ---: | ---: | ---: | ---: |
| interp | base | 0 (0–1) | 8,998 (8,780–9,667) | 677 (660–684) | 680 (660–684) |
| interp | base2 (A/A) | 0 (0–1) | 9,304 (8,821–9,731) | 675 (638–683) | 679 (638–683) |
| interp | head | 0 (0–1) | 9,005 (8,406–9,202) | 666 (662–673) | 671 (662–673) |
| YJIT | base | 1 (0–1) | 8,817 (8,604–9,182) | 883 (876–892) | 883 (876–892) |
| YJIT | base2 (A/A) | 0 (0–1) | 8,978 (8,154–9,190) | 873 (858–898) | 873 (858–898) |
| YJIT | head | 0 (0–2) | 8,997 (8,464–9,678) | 866 (865–883) | 866 (865–883) |
| ZJIT | base | 2 (2–3) | 9,899 (9,685–10,094) | 867 (858–879) | 867 (858–879) |
| ZJIT | base2 (A/A) | 2 (0–2) | 9,586 (9,412–10,557) | 865 (825–876) | 865 (825–876) |
| ZJIT | head | 3 (3–4) | 9,961 (9,331–10,231) | 878 (860–890) | 878 (860–890) |

`major_by` over all 5 rounds (at most one major per operation is seen): interp base nofree 2, base2 nofree 1 +
oldmalloc 1, head nofree 1; YJIT base oldmalloc 2 + nofree 1, base2 nofree 1, head nofree 2 + oldmalloc 1; ZJIT base
oldmalloc 11, base2 oldmalloc 8, head oldmalloc 12 + nofree 5.

Paired by round, all apps (median, min–max; lower in):

* interp: GC ms head − base −164 (−465 to +7) 4/5, A/A +279 (−337 to +524), head − base2 −272 (−898 to −37) 5/5;
  RSS at end head − base −10.7 (−22.5 to +12.5) 3/5, A/A −2.4 (−23.8 to +15.7).
* YJIT: GC ms head − base +41 (−291 to +496) 2/5, A/A +198 (−450 to +337); RSS head − base −15.7 (−18.7 to +7.0)
  4/5, A/A −10.3 (−34.0 to +20.0).
* ZJIT: GC ms head − base +68 (−354 to +137) 2/5, A/A −99 (−481 to +463); RSS head − base +9.8 (−0.9 to +22.3) 1/5,
  head − base2 +17.7 (+2.2 to +35.5) 0/5, A/A −3.2 (−33.0 to +4.6). ZJIT RSS is higher on the head than the base in
  4/5 rounds (per round +0.3, +2.6, +1.1, +2.2, −0.1%) and than base2 in 5/5; the A/A's signed range does not show
  this is noise. Interp head − base GC −465 ms and YJIT +496 ms fall outside the A/A's signed range.

Full report: [`report.txt`](report.txt) (from
[`report.rb`](../../../fixtures/corpus/ruby-41-watch/gcstep/vs17251-2026-11-27/report.rb)); raw data (shipit
JSONs with per-GC records, census JSONs and logs per workload, queue logs):
[`receipts.tar.gz`](receipts.tar.gz).

## Draft comment (not posted; Thomas approves)

See [`comment.md`](comment.md).
