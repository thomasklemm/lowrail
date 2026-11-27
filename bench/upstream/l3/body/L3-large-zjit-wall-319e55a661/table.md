Time per call, Ruby 4.1.0dev, ZJIT, 30 rounds of fresh processes on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `Marshal.dump, 1 MiB string` | 330.12 µs | 326.70 µs | −1.1% |
| `attributes_for_database, 1 MiB serialized every call` | 501.91 µs | 499.36 µs | −0.8% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/l3/body/L3-large-zjit-wall-319e55a661.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T09:42:55Z master f3e180b5eb) +PRISM [x86_64-linux], /home/user/w/main at 088fc0cf61
- candidate: ruby 4.1.0dev (2026-11-27T09:42:55Z master f3e180b5eb) +PRISM [x86_64-linux], /home/user/w/l3 at 319e55a661
- wall Marshal.dump, 1 MiB string: −1.1% [−1.4%, −0.7%] with A/A +0.1% [−0.5%, +0.7%] (118 calls × 30 windows per process), JIT-flat in 90 processes
- wall attributes_for_database, 1 MiB serialized every call: −0.8% [−1.0%, −0.3%] with A/A −0.3% [−0.5%, +0.0%] (92 calls × 30 windows per process), JIT-flat in 90 processes
