Time per call, Ruby 4.0.10, YJIT, 20 rounds of fresh processes on one core

| | master | flag-first | Change |
| --- | ---: | ---: | ---: |
| `quiet.new(repository)` | 64.69 µs | 30.83 µs | −52.2% |
| `quiet.new(auth hash)` | 21.30 µs | 11.10 µs | −47.7% |
| `quiet merge` | 67.05 µs | 32.30 µs | −51.8% |
| `quiet []=` | 0.46 µs | 0.15 µs | −67.1% |
| `Mash.new(repository)` | 69.31 µs | 70.32 µs | +1.4% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/round2/wall/HM4-flagfirst-4.0.10-yjit.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/hashie-base at 9e313f308f
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/hashie-g at 9e313f308f (dirty)
- wall quiet.new(repository): −52.2% [−52.4%, −52.0%] with A/A +0.3% [−0.2%, +0.6%] (775 calls × 30 windows per process), JIT-flat in 60 processes
- wall quiet.new(auth hash): −47.7% [−48.0%, −47.5%] with A/A +0.4% [−0.1%, +0.9%] (2375 calls × 30 windows per process), JIT-flat in 60 processes
- wall quiet merge: −51.8% [−52.0%, −51.5%] with A/A +0.4% [−0.0%, +0.8%] (748 calls × 30 windows per process), JIT-flat in 60 processes
- wall quiet []=: −67.1% [−67.3%, −66.5%] with A/A +0.3% [−1.7%, +1.4%] (109879 calls × 30 windows per process), JIT-flat in 60 processes
- wall Mash.new(repository): +1.4% [+1.1%, +1.7%] with A/A +0.2% [−0.1%, +0.6%] (713 calls × 30 windows per process), JIT-flat in 60 processes
