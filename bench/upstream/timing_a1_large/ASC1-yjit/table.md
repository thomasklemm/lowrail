Time per call, Ruby 4.0.10, YJIT, 30 rounds of fresh processes on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `belongs_to load` | 54.09 µs | 53.10 µs | −1.7% |
| `has_one load` | 59.38 µs | 58.69 µs | −1.0% |
| `has_many load` | 69.06 µs | 68.31 µs | −1.2% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/timing_a1_large/ASC1-yjit.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-main at 2e299253f9
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-asc1 at ed1b28c5b9
- wall belongs_to load: −1.7% [−2.2%, −1.2%] with A/A −0.5% [−1.0%, +0.3%] (927 calls × 30 windows per process), JIT-flat in 90 processes
- wall has_one load: −1.0% [−1.5%, −0.6%] with A/A −0.4% [−0.9%, +0.2%] (868 calls × 30 windows per process), JIT-flat in 90 processes
- wall has_many load: −1.2% [−1.5%, −0.7%] with A/A −0.6% [−1.3%, +0.0%] (746 calls × 30 windows per process), JIT-flat in 90 processes
