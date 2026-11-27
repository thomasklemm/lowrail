Time per call, Ruby 4.0.10, YJIT, 20 rounds of fresh processes on one core

| | master | reorder | Change |
| --- | ---: | ---: | ---: |
| `quiet.new(repository)` | 65.14 µs | 30.73 µs | −52.3% |
| `quiet.new(auth hash)` | 21.23 µs | 11.06 µs | −47.7% |
| `quiet merge` | 67.33 µs | 32.20 µs | −51.9% |
| `quiet []=` | 0.46 µs | 0.15 µs | −67.2% |
| `Mash.new(repository)` | 69.72 µs | 72.56 µs | +4.8% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/round2/wall/HM4-reorder-4.0.10-yjit.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/hashie-base at 9e313f308f
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/hashie-f at 9e313f308f (dirty)
- wall quiet.new(repository): −52.3% [−52.8%, −52.1%] with A/A +0.1% [−0.4%, +0.5%] (775 calls × 30 windows per process), JIT-flat in 60 processes
- wall quiet.new(auth hash): −47.7% [−48.2%, −47.3%] with A/A −0.1% [−0.7%, +0.6%] (2380 calls × 30 windows per process), JIT-flat in 60 processes
- wall quiet merge: −51.9% [−52.4%, −51.6%] with A/A +0.2% [−0.8%, +0.7%] (749 calls × 30 windows per process), JIT-flat in 60 processes
- wall quiet []=: −67.2% [−67.4%, −66.8%] with A/A +0.0% [−1.0%, +1.5%] (101000 calls × 30 windows per process), JIT-flat in 60 processes
- wall Mash.new(repository): +4.8% [+4.2%, +5.7%] with A/A −0.0% [−0.8%, +0.4%] (715 calls × 30 windows per process), JIT-flat in 60 processes
