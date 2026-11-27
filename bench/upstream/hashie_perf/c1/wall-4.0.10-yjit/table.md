Time per call, Ruby 4.0.10, YJIT, 30 rounds of fresh processes on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `read keys with suffixes` | 2.05 µs | 1.97 µs | −4.0% |
| `write a new key as a method` | 1.12 µs | 1.08 µs | −3.3% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/c1/wall-4.0.10-yjit.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/workspace/repo/.amp/in/orb-backup/hashie-perf/hashie-base at 9e313f308f
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/workspace/repo/.amp/in/orb-backup/hashie-perf/hashie-c1 at d1f403e077
- wall read keys with suffixes: −4.0% [−4.2%, −3.6%] with A/A −0.3% [−1.1%, +0.2%] (24814 calls × 30 windows per process), JIT-flat in 90 processes
- wall write a new key as a method: −3.3% [−4.0%, −2.7%] with A/A +0.3% [−0.6%, +1.1%] (43750 calls × 30 windows per process), JIT-flat in 90 processes
