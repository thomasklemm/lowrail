Time per call, Ruby 4.1.0dev, ZJIT, GC on, 30 rounds of fresh processes on one core

| | main | aa | Change |
| --- | ---: | ---: | ---: |
| `foreign_keys(t)` | 728.65 µs | 721.43 µs | within noise |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/gc_jit_windows/zjit-gc-aa.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC on and the default heap, the mean window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/rails-main at 088fc0cf61
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/rails-aa at 088fc0cf61
- wall foreign_keys(t): +0.1% [−2.2%, +1.6%] with A/A −2.4% [−3.7%, +0.1%] (69 calls × 30 windows per process), JIT-flat in 90 processes: interval includes 0, no claim
