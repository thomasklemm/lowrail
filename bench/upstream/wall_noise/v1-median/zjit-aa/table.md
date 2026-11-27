Time per call, Ruby 4.1.0dev, ZJIT, 30 rounds of fresh processes on one core

| | main | aa | Change |
| --- | ---: | ---: | ---: |
| `foreign_keys(t)` | 681.80 µs | 683.28 µs | within noise |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/wall_noise/zjit-aa.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median over rounds of candidate / geometric mean of the round's two base runs, A/A = base2 / base, 95% bootstrap intervals over rounds
- base: ruby 4.1.0dev (2026-11-25T19:18:44Z HEAD 42a644f6e0) +PRISM [x86_64-linux], /home/user/w/rails-main at 088fc0cf61
- candidate: ruby 4.1.0dev (2026-11-25T19:18:44Z HEAD 42a644f6e0) +PRISM [x86_64-linux], /home/user/w/rails-aa at 088fc0cf61
- wall foreign_keys(t): −0.0% [−0.8%, +0.5%] with A/A +0.6% [−0.3%, +1.2%] (66 calls × 30 windows per process), JIT-flat in 90 processes: interval includes 0, no claim
