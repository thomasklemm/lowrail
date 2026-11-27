Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, main | Objects, uncached | Instructions, main | Instructions, uncached | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `dequeue, idle` | – | – | 4,231,107 | 4,190,881 | −1.0% |
| `dequeue and perform one job` | – | – | 13,809,467 | 13,775,988 | not JIT-flat, no claim |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/uncached_survey/runs/ir-gj.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/main/good_job at e15ee79627
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/cand/good_job at e15ee79627 (dirty)
- yjit dequeue, idle: objects differ between the two base runs (1,682, 1681.9)
- yjit dequeue, idle: instructions −1.0% with A/A 0.12% (base 4,233,616 / 4,228,598, candidate 4,190,881), JIT-flat in 6 windows
- yjit dequeue and perform one job: objects differ between the two base runs (4939.7, 4,940)
- yjit dequeue and perform one job: instructions −0.2% with A/A 0.05% (base 13,812,593 / 13,806,342, candidate 13,775,988): not JIT-flat (base n200 compiled_block_count +6, candidate n200 compiled_iseq_count +4, candidate n200 compiled_block_count +63), no claim
