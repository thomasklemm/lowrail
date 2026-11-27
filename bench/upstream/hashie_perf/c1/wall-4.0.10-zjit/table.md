Time per call, Ruby 4.0.10, ZJIT, 30 rounds of fresh processes on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `read keys with suffixes` | 3.95 µs | 3.91 µs | not JIT-flat, no claim |
| `write a new key as a method` | 2.10 µs | 2.08 µs | not JIT-flat, no claim |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/c1/wall-4.0.10-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/workspace/repo/.amp/in/orb-backup/hashie-perf/hashie-base at 9e313f308f
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/workspace/repo/.amp/in/orb-backup/hashie-perf/hashie-c1 at d1f403e077
- wall read keys with suffixes: −1.0% [−1.3%, −0.6%] with A/A +0.1% [−0.2%, +0.4%] (12819 calls × 30 windows per process): not JIT-flat (r1 base compiled_side_exit_count missing, r1 candidate compiled_side_exit_count missing, r1 base2 compiled_side_exit_count missing, …), no claim
- wall write a new key as a method: −0.7% [−1.3%, −0.3%] with A/A +0.0% [−0.5%, +0.4%] (23376 calls × 30 windows per process): not JIT-flat (r1 base compiled_side_exit_count missing, r1 candidate compiled_side_exit_count missing, r1 base2 compiled_side_exit_count missing, …), no claim
