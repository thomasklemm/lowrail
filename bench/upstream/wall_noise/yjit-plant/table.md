Time per call, Ruby 4.0.10, YJIT, 30 rounds of fresh processes on one core

| | main | plant | Change |
| --- | ---: | ---: | ---: |
| `foreign_keys(t)` | 708.06 µs | 717.51 µs | +1.2% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/wall_noise/yjit-plant.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-main at 088fc0cf61
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-plant at 3f282787ff
- wall foreign_keys(t): +1.2% [+0.3%, +2.0%] with A/A +0.6% [−0.3%, +1.1%] (63 calls × 30 windows per process), JIT-flat in 90 processes
