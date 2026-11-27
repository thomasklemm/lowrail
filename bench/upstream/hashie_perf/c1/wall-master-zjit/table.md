Time per call, Ruby 4.1.0dev, ZJIT, 30 rounds of fresh processes on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `read keys with suffixes` | 1.97 µs | 1.97 µs | within noise |
| `write a new key as a method` | 1.38 µs | 1.36 µs | −1.1% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/c1/wall-master-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/workspace/repo/.amp/in/orb-backup/hashie-perf/hashie-base at 9e313f308f
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/workspace/repo/.amp/in/orb-backup/hashie-perf/hashie-c1 at d1f403e077
- wall read keys with suffixes: −0.3% [−0.5%, +0.3%] with A/A +0.3% [−0.3%, +0.8%] (25369 calls × 30 windows per process), JIT-flat in 90 processes: interval includes 0, no claim
- wall write a new key as a method: −1.1% [−1.2%, −0.9%] with A/A −0.1% [−0.3%, +0.4%] (36479 calls × 30 windows per process), JIT-flat in 90 processes
