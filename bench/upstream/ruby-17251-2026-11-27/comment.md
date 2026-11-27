Draft follow-up on ruby/ruby#17251 (not posted; Thomas approves the text). Numbers: [README](README.md).

---

@eightbitraptor A follow-up with the rebased comparison: on its current base `f6278067b6`, this PR no longer reduces major GCs or GC time, and RSS stays about the same. Master alone now runs 6–7 majors on shipit, where `dec1bb786f` ran 28–29 in the earlier runs.

Compared base `f6278067b6` with head `9715d0224e` on Linux x86_64, alternating builds, on the same workloads as before: six shipit rounds of 40 measured iterations after 15 warmups, and five rounds of 35 Rails workloads in Blog, Fizzy and Lobsters, 1,000 operations per workload. Medians, interpreter / YJIT / ZJIT:

| | base | head |
| --- | ---: | ---: |
| shipit, majors | 6 / 6 / 7 | 8 / 9 / 8 |
| shipit, GC time ms | 2,294 / 2,326 / 2,576 | 2,385 / 2,496 / 2,376 |
| shipit, sampled peak RSS MiB | 150 / 199 / 180 | 148 / 196 / 181 |
| Rails workloads, majors | 0 / 1 / 2 | 0 / 0 / 3 |
| Rails workloads, GC time ms | 8,998 / 8,817 / 9,899 | 9,005 / 8,997 / 9,961 |
| Rails workloads, RSS MiB | 677 / 883 / 867 | 666 / 866 / 878 |

On shipit, the head never ran fewer majors than the base in the same round. In three additional rounds with per-GC records, every base major reports `nofree` at a 2× oldgen limit, while all but one recorded head major report `oldgen` at the 1.25× limit. GC time is within run-to-run noise in the interpreter. Under YJIT it is about 6% higher in all six rounds, and under ZJIT about 6% lower in all six.

On the Rails workloads, both builds run at most four majors per round in every mode. Differences in GC time and RSS (summed over the three apps after each app's last window) stay within the spread between two copies of the base build, though under ZJIT the head's RSS is higher in four of five rounds (median +10 MiB, about 1%).
