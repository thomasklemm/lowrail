Time per call, Ruby 4.1.0dev, ZJIT, 20 rounds of fresh processes on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `Mash#to_hash` | 34.12 µs | 29.42 µs | −13.6% |
| `Mash#to_json` | 39.09 µs | 34.61 µs | −11.3% |
| `to_hash(symbolize_keys: true)` | 40.79 µs | 35.81 µs | −11.8% |
| `auth info to_hash` | 2.26 µs | 2.10 µs | −3.6% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/round2/wall/HM5-master-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-base at 9e313f308f
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-th at e10dce085d
- wall Mash#to_hash: −13.6% [−14.4%, −12.9%] with A/A −0.5% [−1.4%, +1.2%] (1431 calls × 30 windows per process), JIT-flat in 60 processes
- wall Mash#to_json: −11.3% [−11.7%, −11.0%] with A/A −0.4% [−0.8%, +0.7%] (1222 calls × 30 windows per process), JIT-flat in 60 processes
- wall to_hash(symbolize_keys: true): −11.8% [−12.6%, −11.3%] with A/A +0.4% [−0.6%, +1.3%] (1214 calls × 30 windows per process), JIT-flat in 60 processes
- wall auth info to_hash: −3.6% [−6.7%, −1.9%] with A/A +0.2% [−3.7%, +5.2%] (18776 calls × 30 windows per process), JIT-flat in 60 processes
