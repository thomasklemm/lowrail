Time per call, Ruby 4.0.10, YJIT, 30 rounds of fresh processes on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `belongs_to load` | 26.72 µs | 25.58 µs | −3.5% |
| `has_one load` | 28.86 µs | 27.76 µs | −2.8% |
| `has_many load` | 34.01 µs | 33.38 µs | −2.2% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/census13r/body/ASC1-wall-yjit.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-main at 2e299253f9
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-asc1 at 2b46f50bda
- wall belongs_to load: −3.5% [−5.0%, −2.1%] with A/A −0.3% [−2.8%, +0.9%] (1733 calls × 30 windows per process), JIT-flat in 90 processes
- wall has_one load: −2.8% [−4.4%, −1.7%] with A/A −0.5% [−3.5%, +2.3%] (1587 calls × 30 windows per process), JIT-flat in 90 processes
- wall has_many load: −2.2% [−3.4%, −1.0%] with A/A −0.5% [−3.3%, +2.0%] (1285 calls × 30 windows per process), JIT-flat in 90 processes
