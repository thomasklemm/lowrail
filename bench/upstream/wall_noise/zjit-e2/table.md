Time per call, Ruby 4.1.0dev, ZJIT, 30 rounds of fresh processes on one core

| | main | e2 | Change |
| --- | ---: | ---: | ---: |
| `foreign_keys(t)` | 687.00 µs | 686.51 µs | within noise |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/wall_noise/zjit-e2.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-25T19:18:44Z HEAD 42a644f6e0) +PRISM [x86_64-linux], /home/user/w/rails-main at 088fc0cf61
- candidate: ruby 4.1.0dev (2026-11-25T19:18:44Z HEAD 42a644f6e0) +PRISM [x86_64-linux], /home/user/w/rails-e2 at d29055285a
- wall foreign_keys(t): −0.0% [−0.7%, +0.5%] with A/A +0.4% [−0.8%, +1.7%] (74 calls × 30 windows per process), JIT-flat in 90 processes: interval includes 0, no claim
