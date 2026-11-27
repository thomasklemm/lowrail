Draft follow-up on ruby/ruby#17251 (not posted; Thomas approves the text). Numbers: [README](README.md). Text as
approved by Astra (255deaf8 review) and thermos-sol (69d69b29), unchanged.

---

Completing the rebased comparison missing from the previous reply: base `f6278067b6` versus the GC patch from head `9715d0224e`. The head does not lower shipit's major count; GC time differs by mode.

Linux x86_64, alternating builds; six shipit rounds (15 warmups, 40 measured iterations), five rounds of the same 35 Rails workloads (1,000 operations each). Rounded medians, interpreter / YJIT / ZJIT:

| | base | head |
| --- | ---: | ---: |
| shipit, majors | 6 / 6 / 7 | 8 / 9 / 8 |
| shipit, GC time ms | 2,294 / 2,326 / 2,576 | 2,385 / 2,496 / 2,376 |
| shipit, sampled peak RSS MiB | 150 / 199 / 180 | 148 / 196 / 181 |
| Rails workloads, majors | 0 / 1 / 2 | 0 / 0 / 3 |
| Rails workloads, GC time ms | 8,998 / 8,817 / 9,899 | 9,005 / 8,997 / 9,961 |
| Rails workloads, RSS MiB | 677 / 883 / 867 | 666 / 866 / 878 |

Shipit GC time rises in all six YJIT pairs (median +139 ms), and falls in all six ZJIT pairs (−166 ms). Against a second copy of base, those directions hold in five and six pairs respectively. Interpreter differences overlap the A/A range.

Rails GC-time directions are mixed. ZJIT RSS rises in four of five pairs against base (median +9.8 MiB), and all five against its copy (+17.7 MiB). Rails RSS sums the three apps after each app's last window.

These runs used concurrent benchmark groups on a different machine from the earlier sequential runs, so cross-run changes cannot be attributed to Ruby alone.
