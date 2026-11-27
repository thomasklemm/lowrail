Time per call, Ruby 4.1.0dev, ZJIT, 30 rounds of fresh processes on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `mash.description = value` | 1.21 µs | 1.23 µs | +2.5% |
| `mash.private?` | 0.53 µs | 0.49 µs | −5.6% |
| `mash.name` | 0.27 µs | 0.26 µs | −4.2% |
| `mash.name(1)` | 0.28 µs | 0.30 µs | +6.7% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/round2/wall/HM3-setter-master-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-base at 9e313f308f
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-mm at 282ebcbb82
- wall mash.description = value: +2.5% [+2.2%, +2.7%] with A/A −0.4% [−0.8%, +1.0%] (41582 calls × 30 windows per process), JIT-flat in 90 processes
- wall mash.private?: −5.6% [−6.3%, −5.1%] with A/A +0.7% [−0.5%, +1.4%] (87489 calls × 30 windows per process), JIT-flat in 90 processes
- wall mash.name: −4.2% [−4.4%, −3.9%] with A/A +0.1% [−0.2%, +0.4%] (178893 calls × 30 windows per process), JIT-flat in 90 processes
- wall mash.name(1): +6.7% [+6.5%, +6.9%] with A/A +0.2% [−0.2%, +0.4%] (169810 calls × 30 windows per process), JIT-flat in 90 processes
