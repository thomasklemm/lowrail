Objects and Callgrind instructions per call, Ruby 4.1.0dev, ZJIT

| | Objects, main | Objects, uncached | Instructions, main | Instructions, uncached | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `dequeue, idle` | – | – | 4,195,465 | 4,150,144 | −1.1% |
| `dequeue and perform one job` | – | – | 13,621,631 | 13,583,157 | not JIT-flat, no claim |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/uncached_survey/runs/ir-gj-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/main/good_job at e15ee79627
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/cand/good_job at e15ee79627 (dirty)
- zjit dequeue, idle: objects differ between the two base runs (1,635, 1634.5)
- zjit dequeue, idle: instructions −1.1% with A/A 0.00% (base 4,195,535 / 4,195,395, candidate 4,150,144), JIT-flat in 6 windows
- zjit dequeue and perform one job: objects differ between the two base runs (4751.8, 4752.1)
- zjit dequeue and perform one job: instructions −0.3% with A/A 0.00% (base 13,621,323 / 13,621,939, candidate 13,583,157): not JIT-flat (base n200 compiled_iseq_count +1, base n200 compiled_side_exit_count +13, candidate n200 compiled_iseq_count +5, …), no claim
