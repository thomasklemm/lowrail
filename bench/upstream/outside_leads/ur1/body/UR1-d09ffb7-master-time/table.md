Time per call, Ruby 4.1.0dev, ZJIT, 30 rounds of fresh processes on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `hello` | 0.20 µs | 0.15 µs | −23.3% |
| `form key` | 0.86 µs | 0.25 µs | −70.7% |
| `form value` | 1.04 µs | 0.23 µs | −78.4% |
| `cookie` | 1.94 µs | 0.78 µs | −59.6% |
| `uri hello` | 0.20 µs | 0.14 µs | −27.3% |
| `uri user` | 0.65 µs | 0.22 µs | −65.6% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/outside_leads/ur1/body/UR1-d09ffb7-master-time.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/uri-base at 48cda77031
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/uri-d09ffb7 at d09ffb7376
- wall hello: −23.3% [−23.8%, −22.1%] with A/A −0.1% [−2.1%, +2.3%] (221151 calls × 30 windows per process), JIT-flat in 90 processes
- wall form key: −70.7% [−71.1%, −70.3%] with A/A +0.5% [−2.1%, +2.2%] (52855 calls × 30 windows per process), JIT-flat in 90 processes
- wall form value: −78.4% [−78.6%, −78.0%] with A/A +0.5% [−0.6%, +2.1%] (44824 calls × 30 windows per process), JIT-flat in 90 processes
- wall cookie: −59.6% [−60.0%, −58.9%] with A/A +0.3% [−1.5%, +1.4%] (29733 calls × 30 windows per process), JIT-flat in 90 processes
- wall uri hello: −27.3% [−28.0%, −25.9%] with A/A −0.3% [−1.4%, +1.3%] (218268 calls × 30 windows per process), JIT-flat in 90 processes
- wall uri user: −65.6% [−66.1%, −65.3%] with A/A +0.2% [−1.7%, +1.2%] (69771 calls × 30 windows per process), JIT-flat in 90 processes
