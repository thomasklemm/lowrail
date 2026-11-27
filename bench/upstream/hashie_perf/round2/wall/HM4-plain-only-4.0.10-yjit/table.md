Time per call, Ruby 4.0.10, YJIT, 20 rounds of fresh processes on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `Mash.new(repository)` | 67.65 µs | 67.57 µs | within noise |
| `Mash#merge` | 70.00 µs | 70.09 µs | within noise |
| `mash['description'] =` | 0.56 µs | 0.56 µs | within noise |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/round2/wall/HM4-plain-only-4.0.10-yjit.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/hashie-base at 9e313f308f
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/hashie-quiet at f41c3b2b27
- wall Mash.new(repository): +0.1% [−0.5%, +0.4%] with A/A −0.2% [−0.5%, +0.8%] (739 calls × 30 windows per process), JIT-flat in 60 processes: interval includes 0, no claim
- wall Mash#merge: +0.0% [−0.4%, +0.6%] with A/A +0.1% [−0.2%, +0.3%] (698 calls × 30 windows per process), JIT-flat in 60 processes: interval includes 0, no claim
- wall mash['description'] =: −0.3% [−0.6%, +0.2%] with A/A +0.2% [−0.1%, +0.6%] (86738 calls × 30 windows per process), JIT-flat in 60 processes: interval includes 0, no claim
