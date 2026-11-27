Time per call, Ruby 4.1.0dev, ZJIT, 20 rounds of fresh processes on one core

| | master | reorder | Change |
| --- | ---: | ---: | ---: |
| `quiet.new(repository)` | 83.48 µs | 37.30 µs | −55.0% |
| `quiet.new(auth hash)` | 27.69 µs | 14.18 µs | within noise |
| `quiet merge` | 84.79 µs | 39.07 µs | −53.2% |
| `quiet []=` | 0.50 µs | 0.17 µs | −65.3% |
| `Mash.new(repository)` | 106.62 µs | 117.70 µs | +11.1% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/round2/wall/HM4-reorder-master-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-base at 9e313f308f
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/hashie-f at 9e313f308f (dirty)
- wall quiet.new(repository): −55.0% [−55.7%, −53.7%] with A/A −0.5% [−2.6%, +2.4%] (619 calls × 30 windows per process), JIT-flat in 60 processes
- wall quiet.new(auth hash): −48.8% [−49.0%, −48.4%] with A/A −0.5% [−1.4%, −0.1%] (1800 calls × 30 windows per process), JIT-flat in 60 processes: A/A interval excludes 0, no claim
- wall quiet merge: −53.2% [−54.5%, −52.5%] with A/A −0.1% [−1.8%, +1.2%] (583 calls × 30 windows per process), JIT-flat in 60 processes
- wall quiet []=: −65.3% [−65.5%, −65.1%] with A/A +0.0% [−1.0%, +2.0%] (100569 calls × 30 windows per process), JIT-flat in 60 processes
- wall Mash.new(repository): +11.1% [+10.1%, +11.9%] with A/A −0.0% [−1.4%, +0.9%] (467 calls × 30 windows per process), JIT-flat in 60 processes
