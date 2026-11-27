Time per call, Ruby 4.0.10, no JIT, 30 rounds of fresh processes on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `read keys with suffixes` | 3.79 µs | 3.78 µs | within noise |
| `write a new key as a method` | 2.03 µs | 1.99 µs | −1.9% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/c1/wall-4.0.10-interp.
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/workspace/repo/.amp/in/orb-backup/hashie-perf/hashie-base at 9e313f308f
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/workspace/repo/.amp/in/orb-backup/hashie-perf/hashie-c1 at d1f403e077
- wall read keys with suffixes: −0.3% [−0.7%, +0.5%] with A/A +0.1% [−0.3%, +1.3%] (13435 calls × 30 windows per process): interval includes 0, no claim
- wall write a new key as a method: −1.9% [−2.6%, −0.8%] with A/A +0.5% [−0.5%, +1.6%] (24610 calls × 30 windows per process)
