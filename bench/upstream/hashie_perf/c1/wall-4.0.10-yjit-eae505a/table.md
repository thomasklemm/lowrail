Time per call, Ruby 4.0.10, YJIT, 30 rounds of fresh processes on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `read keys with suffixes` | 2.05 µs | 1.95 µs | −4.8% |
| `write a new key as a method` | 1.12 µs | 1.09 µs | −2.7% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/c1/wall-4.0.10-yjit-eae505a.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/workspace/repo/.amp/in/orb-backup/hashie-perf/hashie-base at 9e313f308f
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/workspace/repo/.amp/in/orb-backup/hashie-perf/hashie-c1 at eae505a846
- wall read keys with suffixes: −4.8% [−5.2%, −4.5%] with A/A +0.3% [−0.3%, +0.5%] (25012 calls × 30 windows per process), JIT-flat in 90 processes
- wall write a new key as a method: −2.7% [−3.5%, −2.1%] with A/A −0.2% [−1.4%, +1.1%] (44753 calls × 30 windows per process), JIT-flat in 90 processes
