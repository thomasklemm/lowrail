Time per call, Ruby 4.1.0dev, ZJIT, 30 rounds of fresh processes on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `hello` | 0.19 µs | 0.15 µs | −23.5% |
| `form key` | 0.84 µs | 0.25 µs | −70.1% |
| `form value` | 1.02 µs | 0.22 µs | −77.8% |
| `cookie` | 1.87 µs | 0.75 µs | −59.1% |
| `uri hello` | 0.19 µs | 0.14 µs | −27.5% |
| `uri user` | 0.63 µs | 0.22 µs | −65.6% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/outside_leads/ur1/body/UR1-d4ce0b0-master-time.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/uri-base at 48cda77031
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/uri-d4ce0b0 at d4ce0b0376
- wall hello: −23.5% [−24.1%, −22.2%] with A/A +0.3% [−0.2%, +2.2%] (232262 calls × 30 windows per process), JIT-flat in 90 processes
- wall form key: −70.1% [−70.5%, −69.6%] with A/A +0.8% [−0.7%, +2.5%] (55262 calls × 30 windows per process), JIT-flat in 90 processes
- wall form value: −77.8% [−78.2%, −77.5%] with A/A +0.7% [−0.3%, +2.1%] (46408 calls × 30 windows per process), JIT-flat in 90 processes
- wall cookie: −59.1% [−60.0%, −58.8%] with A/A +0.5% [−0.6%, +1.7%] (31709 calls × 30 windows per process), JIT-flat in 90 processes
- wall uri hello: −27.5% [−28.2%, −26.6%] with A/A +0.2% [−0.2%, +1.3%] (220326 calls × 30 windows per process), JIT-flat in 90 processes
- wall uri user: −65.6% [−65.9%, −65.1%] with A/A +0.5% [−1.2%, +2.1%] (73507 calls × 30 windows per process), JIT-flat in 90 processes
