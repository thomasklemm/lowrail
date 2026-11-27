Time per call, Ruby 4.1.0dev, ZJIT, 30 rounds of fresh processes on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `hello` | 0.21 µs | 0.17 µs | −20.3% |
| `form key` | 0.97 µs | 0.31 µs | −68.4% |
| `form value` | 1.16 µs | 0.28 µs | −76.1% |
| `cookie` | 1.75 µs | 0.76 µs | −56.3% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/outside_leads/ur1/body/UR1-master-time.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/w/uri-base at 48cda77031
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/w/uri at a3b201f05b
- wall hello: −20.3% [−20.6%, −19.7%] with A/A +0.2% [−0.6%, +0.6%] (180669 calls × 30 windows per process), JIT-flat in 90 processes
- wall form key: −68.4% [−68.5%, −68.3%] with A/A +0.3% [−0.4%, +0.5%] (40215 calls × 30 windows per process), JIT-flat in 90 processes
- wall form value: −76.1% [−76.2%, −76.0%] with A/A −0.3% [−0.8%, +0.2%] (22389 calls × 30 windows per process), JIT-flat in 90 processes
- wall cookie: −56.3% [−56.6%, −56.0%] with A/A +0.4% [−0.1%, +1.0%] (26875 calls × 30 windows per process), JIT-flat in 90 processes
