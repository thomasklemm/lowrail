Objects and Callgrind instructions per call, Ruby 4.1.0dev, ZJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `update! of one column` | – | – | 665,053 | 652,542 | not JIT-flat, no claim |
| `find, then changed?` | 88 | 88 | 281,411 | 277,681 | not JIT-flat, no claim |
| `serializable_hash` | 32 | 32 | 124,340 | 126,141 | not JIT-flat, no claim |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/lead6/body/L6-master-zjit-2026-11-27.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.1.0dev (2026-11-27T09:42:55Z master f3e180b5eb) +PRISM [x86_64-linux], /home/user/w/main at 088fc0cf61
- candidate: ruby 4.1.0dev (2026-11-27T09:42:55Z master f3e180b5eb) +PRISM [x86_64-linux], /home/user/w/l6 at 8b1c6428ea
- zjit update! of one column: objects differ between the two base runs (210, 210)
- zjit update! of one column: instructions −1.9% with A/A 0.02% (base 665,124 / 664,982, candidate 652,542): not JIT-flat (base n0 invalidation_count missing, base n200 invalidation_count missing, candidate n0 invalidation_count missing, …), no claim
- zjit find, then changed?: instructions −1.3% with A/A 0.23% (base 281,739 / 281,082, candidate 277,681): not JIT-flat (base n0 invalidation_count missing, base n200 invalidation_count missing, candidate n0 invalidation_count missing, …), no claim
- zjit serializable_hash: instructions +1.4% with A/A 0.65% (base 124,743 / 123,937, candidate 126,141): not JIT-flat (base n0 invalidation_count missing, base n200 invalidation_count missing, candidate n0 invalidation_count missing, …), no claim
