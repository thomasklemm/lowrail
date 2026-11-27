Time per call, Ruby 4.1.0dev, ZJIT, 20 rounds of fresh processes on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `read 5 keys as methods` | 1.27 µs | 1.21 µs | −3.9% |
| `auth.info.email, auth.uid` | 0.79 µs | 0.75 µs | −5.5% |
| `description = and private?` | 1.74 µs | 1.76 µs | +0.8% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/round2/wall/HM3-master-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-base at 9e313f308f
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-mm at 202c478705
- wall read 5 keys as methods: −3.9% [−4.4%, −3.5%] with A/A −0.1% [−0.3%, +0.5%] (38753 calls × 30 windows per process), JIT-flat in 60 processes
- wall auth.info.email, auth.uid: −5.5% [−6.0%, −4.4%] with A/A +0.5% [−0.2%, +0.9%] (63213 calls × 30 windows per process), JIT-flat in 60 processes
- wall description = and private?: +0.8% [+0.5%, +1.3%] with A/A −0.2% [−0.9%, +0.4%] (28319 calls × 30 windows per process), JIT-flat in 60 processes
