Time per call, Ruby 4.1.0dev, ZJIT, 20 rounds of fresh processes on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `Mash.new(repository)` | 82.17 µs | 82.36 µs | within noise |
| `Mash#merge` | 85.18 µs | 84.81 µs | within noise |
| `mash['description'] =` | 0.54 µs | 0.54 µs | within noise |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/round2/wall/HM4-plain-only-master-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-base at 9e313f308f
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-quiet at c28e722982
- wall Mash.new(repository): +0.0% [−1.4%, +1.1%] with A/A −2.5% [−3.0%, −1.4%] (634 calls × 30 windows per process), JIT-flat in 60 processes: A/A interval excludes 0, no claim
- wall Mash#merge: +0.3% [−1.2%, +1.7%] with A/A −2.2% [−2.8%, −1.1%] (592 calls × 30 windows per process), JIT-flat in 60 processes: A/A interval excludes 0, no claim
- wall mash['description'] =: +0.1% [−0.4%, +0.6%] with A/A +0.2% [−0.3%, +0.9%] (92493 calls × 30 windows per process), JIT-flat in 60 processes: interval includes 0, no claim
