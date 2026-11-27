Time per call, Ruby 4.0.10, YJIT, 30 rounds of fresh processes on one core

| | master | flag-first | Change |
| --- | ---: | ---: | ---: |
| `Mash.new(repository)` | 67.72 µs | 68.79 µs | +2.0% |
| `Mash#merge` | 70.15 µs | 71.00 µs | +1.4% |
| `mash['description'] =` | 0.56 µs | 0.54 µs | −4.1% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/round2/wall/HM4-flagfirst-plain-only-4.0.10-yjit.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/hashie-base at 9e313f308f
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/hashie-g at 9e313f308f (dirty)
- wall Mash.new(repository): +2.0% [+1.7%, +2.3%] with A/A +0.2% [−0.3%, +1.1%] (700 calls × 30 windows per process), JIT-flat in 90 processes
- wall Mash#merge: +1.4% [+1.2%, +1.9%] with A/A −0.0% [−0.4%, +0.6%] (679 calls × 30 windows per process), JIT-flat in 90 processes
- wall mash['description'] =: −4.1% [−4.5%, −3.4%] with A/A −0.0% [−0.3%, +0.5%] (89230 calls × 30 windows per process), JIT-flat in 90 processes
