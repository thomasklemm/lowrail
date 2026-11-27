Objects and Callgrind instructions per call, Ruby 4.1.0dev, ZJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `serializable_hash` | 32 | 32 | 125,153 | 123,884 | not JIT-flat, no claim |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/lead6/body/L6-master-zjit-serializable-hash-2026-11-27.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.1.0dev (2026-11-27T09:42:55Z master f3e180b5eb) +PRISM [x86_64-linux], /home/user/w/main at 088fc0cf61
- candidate: ruby 4.1.0dev (2026-11-27T09:42:55Z master f3e180b5eb) +PRISM [x86_64-linux], /home/user/w/l6 at 8b1c6428ea
- zjit serializable_hash: instructions −1.0% with A/A 0.07% (base 125,194 / 125,111, candidate 123,884): not JIT-flat (base n0 invalidation_count missing, base n1000 invalidation_count missing, candidate n0 invalidation_count missing, …), no claim
