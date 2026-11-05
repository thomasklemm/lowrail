# ruby/ruby#19685 GC time on ruby-bench (`--harness=gc`)

ruby/ruby#19685 ("ZJIT: Mark each JITFrame ISEQ once per GC") was closed on 2026-11-04 because it had only
Callgrind instruction counts and no `run_benchmarks.rb` result. tekknolagi then wrote on the closed PR
([comment 6664809433](https://github.com/ruby/ruby/pull/19685#issuecomment-6664809433)): "we should try to measure
GC time on benchmarks because it *does* matter at scale". This directory records that measurement. Nothing was posted,
and the PR was not reopened.

## Result

The patch cuts marking time per minor GC on all three benchmarks: 44% on railsbench, 11% on lobsters and 15% on shipit.
The per-run means for the patch don't overlap the base or A/A ranges. The saving is about 6 ns per JITFrame, using the
frame counts from the PR body (38k, 150k, 119k). Whole-iteration time and total GC time per iteration don't move
beyond the A/A spread, because the marking time saved is only 0.1–0.2% of an iteration.

Mark ms per minor GC is the total marking time divided by the minor GC count, over iterations that had at least one
minor GC and no major GC. Every other column is a mean over 90 measured iterations (3 rounds × 30); ranges are the
3 per-round means.

| bench | build | mark ms per minor GC | mark ms/iter | sweep ms/iter | GC total ms/iter | GCs/iter (minor + major) | iteration ms |
|---|---|---|---|---|---|---|---|
| railsbench | base | 0.500 (0.491–0.507) | 4.62 (4.47–4.73) | 70.7 (66.9–73.6) | 75.3 (71.3–78.2) | 9.24 + 0 | 1575 (1546–1605) |
| | A/A | 0.502 (0.486–0.514) | 4.79 (4.67–4.93) | 72.9 (69.4–74.9) | 77.7 (74.1–79.7) | 9.54 + 0 | 1587 (1562–1622) |
| | patch | **0.279 (0.273–0.284)** | **2.58 (2.47–2.73)** | 72.0 (71.0–72.9) | 74.6 (73.5–75.6) | 9.26 + 0 | 1587 (1576–1607) |
| lobsters | base | 9.01 (8.83–9.30) | 12.1 (9.9–13.6) | 21.6 (20.4–23.3) | 33.7 (30.4–36.8) | 0.80 + 0.06 | 814 (787–865) |
| | A/A | 9.30 (8.96–9.50) | 13.0 (8.2–16.4) | 22.8 (22.1–23.6) | 35.8 (31.9–38.5) | 0.82 + 0.06 | 839 (810–854) |
| | patch | **8.04 (7.96–8.15)** | 10.5 (7.1–15.2) | 21.6 (21.1–21.9) | 32.2 (28.9–37.1) | 0.83 + 0.04 | 803 (788–820) |
| shipit | base | 4.37 (4.29–4.51) | 46.4 (42.7–51.1) | 35.2 (34.8–35.7) | 81.6 (77.6–86.7) | 3.94 + 0.38 | 1297 (1274–1320) |
| | A/A | 4.35 (4.27–4.46) | 45.2 (43.8–46.6) | 35.2 (34.8–35.8) | 80.5 (78.9–82.5) | 3.98 + 0.37 | 1301 (1293–1309) |
| | patch | **3.72 (3.51–4.09)** | 44.7 (43.4–46.8) | 35.6 (34.0–38.4) | 80.3 (77.4–82.3) | 3.83 + 0.39 | 1340 (1283–1431) |

Per-iteration standard deviations, the minor-GC sample sizes and the A/A deltas are in [data/summary.txt](data/summary.txt).

- **How often marking runs:** railsbench does about 9 minor GCs per iteration and no major GCs. lobsters does under
  one GC per iteration, with a major GC in about 1 of 16 iterations. shipit does about 4 minor GCs per iteration and a
  major GC in about 2 of 5.
- **Why mark ms/iter is noisy on lobsters and shipit:** a major GC marks far more than a minor one, and only some
  iterations include one, so marking time per iteration swings with the major count. Per minor GC it is stable, which is
  why that column comes first.
- **Saving per iteration:** the per-minor-GC saving times minor GCs per iteration gives 2.0 ms on railsbench (0.13% of
  an iteration), 0.8 ms on lobsters (0.10%) and about 2.6 ms on shipit (0.2%). Major GCs are not counted in this
  estimate.
- **The shipit outlier:** the patch run in round 3 slowed down partway through, from about 1,260 ms per iteration to
  1,400–1,960 ms. That run gives the high end of the patch's iteration time (1,431 ms) and of its mark ms per minor GC
  (4.09). No run was dropped.

## Setup

- **Base:** ruby/ruby master `aed61e36b3`.
- **Patch:** #19685 head `aa82ba85e1`, rebased locally onto `aed61e36b3` as `3372d2a9b8`. The rebase applied cleanly,
  and the range-diff differs only in context lines. It was not pushed.
- **Builds:** both use `--enable-yjit --enable-zjit --disable-install-doc` (release builds).
- **A/A:** `base2` is the same base binary run as a separate executable.
- **ruby-bench:** main `00f0f8beab`.
- **Runs:** [rounds.sh](rounds.sh) runs three rounds of
  `run_benchmarks.rb --harness=gc --interleave --warmup=15 --bench=30 --no-sudo --turbo --no-pinning --name_filters=railsbench,lobsters,shipit`.
  Each round runs `base`, `base2` and `patch`, all with `--zjit --zjit-exec-mem-size=512 --zjit-mem-size=1024`, the
  flags from the PR body. `--interleave` randomizes the order of the executables for each benchmark.
- **Machine:** an Amp orb with 8 vCPUs. No CPU pinning and no turbo control, so whole-iteration times are noisy.
- **Analysis:** [agg.rb](agg.rb) produces the summary from the JSON files, with `ruby agg.rb data/round*.json`. The
  files in `data/` are ruby-bench's output reduced to the timing and GC fields; the full JSON also contains heap
  deltas, about 1 MB per round. The `round*.txt` files include ruby-bench's own "GC time ratios" and "GC counts"
  tables.
- **Timer resolution:** `GC.stat(:marking_time)` and `:sweeping_time` are whole milliseconds. The harness takes their
  delta per iteration, so each iteration's value is rounded, but the means over many iterations are not biased.
  `GC total ms` comes from `GC.total_time`, in nanoseconds. The harness prints its "Average marking time" with integer
  division, so `agg.rb` uses the JSON values instead.

## Reply draft (not posted)

> Thanks for the nudge to measure GC time. With ruby-bench's GC harness, this cuts marking time per minor GC by 44% on
> railsbench, 11% on lobsters and 15% on shipit, about 6 ns per JITFrame:
>
> ```
>             mark ms per minor GC (range of 3 run means)              GCs per iteration
>             master           master again (A/A)  this PR             minor + major
> railsbench  0.500 (0.49-0.51)  0.502 (0.49-0.51)  0.279 (0.27-0.28)  9.2 + 0
> lobsters    9.01 (8.83-9.30)   9.30 (8.96-9.50)   8.04 (7.96-8.15)   0.8 + 0.06
> shipit      4.37 (4.29-4.51)   4.35 (4.27-4.46)   3.72 (3.51-4.09)   3.9 + 0.4
> ```
>
> On railsbench, where every GC is minor, marking time per iteration goes from 4.62 ms to 2.58 ms (A/A 4.79 ms).
> On lobsters and shipit, marking time per iteration depends mostly on whether a major GC happened in that iteration,
> so the per-minor-GC number is the stable one. Iteration time and total GC time per iteration stay within the A/A
> spread: the saving is 0.1–0.2% of an iteration.
>
> This is master `aed61e36b3` vs. this PR rebased onto it, three interleaved rounds of
> `./run_benchmarks.rb --harness=gc --interleave --warmup=15 --bench=30 --name_filters=railsbench,lobsters,shipit`
> with `-e "master::<ruby> --zjit --zjit-exec-mem-size=512 --zjit-mem-size=1024"`, the same binary again as the A/A,
> and the patched ruby. Mark ms per minor GC counts only iterations with no major GC.
