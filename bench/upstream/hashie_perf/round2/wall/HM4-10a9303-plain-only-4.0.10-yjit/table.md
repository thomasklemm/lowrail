Time per call, Ruby 4.0.10, YJIT, 30 rounds of fresh processes on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `Mash.new(repository)` | 69.00 µs | 68.70 µs | +1.5% |
| `Mash#merge` | 71.51 µs | 70.82 µs | +1.0% |
| `mash['description'] =` | 0.56 µs | 0.54 µs | −3.6% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/round2/wall/HM4-10a9303-plain-only-4.0.10-yjit.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/hashie-base2 at 277e88e6cc
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/hashie-h at 10a9303397
- wall Mash.new(repository): +1.5% [+0.9%, +1.8%] with A/A −0.3% [−1.3%, +0.4%] (733 calls × 30 windows per process), JIT-flat in 90 processes
- wall Mash#merge: +1.0% [+0.2%, +1.5%] with A/A −0.3% [−2.1%, +0.7%] (702 calls × 30 windows per process), JIT-flat in 90 processes
- wall mash['description'] =: −3.6% [−4.1%, −2.7%] with A/A +0.1% [−0.2%, +0.6%] (88676 calls × 30 windows per process), JIT-flat in 90 processes
