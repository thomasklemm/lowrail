Time per call, Ruby 4.1.0dev, ZJIT, 30 rounds of fresh processes on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `hello` | 0.19 µs | 0.15 µs | −25.0% |
| `form key` | 0.90 µs | 0.28 µs | −69.6% |
| `form value` | 1.10 µs | 0.23 µs | −78.7% |
| `cookie` | 1.62 µs | 0.76 µs | −54.1% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/outside_leads/ur1/body/UR1-cecaed1-master-time.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/w/uri-base at 48cda77031
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/w/uri-cecaed1 at cecaed123f
- wall hello: −25.0% [−26.0%, −24.0%] with A/A −0.7% [−2.1%, +1.0%] (185764 calls × 30 windows per process), JIT-flat in 90 processes
- wall form key: −69.6% [−69.9%, −68.8%] with A/A −0.1% [−1.3%, +0.6%] (55836 calls × 30 windows per process), JIT-flat in 90 processes
- wall form value: −78.7% [−79.2%, −78.2%] with A/A +0.0% [−1.8%, +1.2%] (38913 calls × 30 windows per process), JIT-flat in 90 processes
- wall cookie: −54.1% [−55.0%, −53.0%] with A/A −0.7% [−2.0%, +0.2%] (28954 calls × 30 windows per process), JIT-flat in 90 processes
