Time per call, Ruby 4.1.0dev, YJIT, GC on, 30 rounds of fresh processes on one core

| | main | aa | Change |
| --- | ---: | ---: | ---: |
| `foreign_keys(t)` | 719.93 µs | 714.95 µs | within noise |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/gc_jit_windows/yjit-gc-aa.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC on and the default heap, the mean window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/rails-main at 088fc0cf61
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/rails-aa at 088fc0cf61
- wall foreign_keys(t): +0.1% [−2.1%, +2.6%] with A/A +1.6% [+0.2%, +4.9%] (71 calls × 30 windows per process), JIT-flat in 90 processes: A/A interval excludes 0, no claim
