Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, main | Objects, head | Instructions, main | Instructions, head | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `serializable_hash` | 32 | 32 | 191,241 | 178,894 | −6.5% |

Objects and Callgrind instructions per call, Ruby 4.0.9, YJIT

| | Objects, main | Objects, head | Instructions, main | Instructions, head | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `serializable_hash` | 32 | 32 | 194,977 | 192,662 | −1.2% |

benchmark-ips, Ruby 4.0.9, YJIT, best of 3 on one core

| | main | head | Change |
| --- | ---: | ---: | ---: |
| `serializable_hash` | 50.4k i/s | 52.3k i/s | +3.7% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/docs/upstream/data/rails-main-census-9/lead6/review-thermos-sol-2026-11-27/body-rerun.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/workspace/repo/.amp/in/orb-backup/l6-review/base at 088fc0cf61
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/workspace/repo/.amp/in/orb-backup/l6-review/head at 8b1c6428ea
- interp serializable_hash: instructions −6.5% with A/A 0.18% (base 191,413 / 191,068, candidate 178,894)
- yjit serializable_hash: instructions −1.2% with A/A 0.58% (base 195,546 / 194,408, candidate 192,662), JIT-flat in 6 windows
- ips serializable_hash: +3.7% with A/A 0.76% (best base 50.2k / 50.6k, candidate 52.3k), JIT-flat in 9 windows
