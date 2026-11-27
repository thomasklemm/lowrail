Time per call, Ruby 4.1.0dev, ZJIT, 30 rounds of fresh processes on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `find, miss` | 14.79 µs | 13.79 µs | −6.6% |
| `find, hit` | 11.54 µs | 10.70 µs | −7.4% |
| `where with 3 binds, miss` | 24.14 µs | 23.20 µs | −4.1% |
| `where with 3 binds, hit` | 21.00 µs | 20.21 µs | −4.1% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/census13r/body/QCK1-wall-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/rails-main at 2e299253f9
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/rails-qck1 at 40e4c9db8f
- wall find, miss: −6.6% [−7.1%, −5.8%] with A/A −0.2% [−1.0%, +0.5%] (3119 calls × 30 windows per process), JIT-flat in 90 processes
- wall find, hit: −7.4% [−7.7%, −7.0%] with A/A −0.1% [−0.4%, +0.3%] (4309 calls × 30 windows per process), JIT-flat in 90 processes
- wall where with 3 binds, miss: −4.1% [−4.7%, −3.6%] with A/A +0.0% [−0.6%, +0.5%] (2069 calls × 30 windows per process), JIT-flat in 90 processes
- wall where with 3 binds, hit: −4.1% [−4.3%, −3.6%] with A/A +0.3% [−0.1%, +0.7%] (2350 calls × 30 windows per process), JIT-flat in 90 processes
