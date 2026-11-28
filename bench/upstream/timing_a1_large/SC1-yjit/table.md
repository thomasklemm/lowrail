benchmark-ips, Ruby 4.0.10, YJIT, best of 5 on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `listener poll, idle` | 4.5k i/s | 5.3k i/s | +16.7% |
| `listener poll, one message` | 1.8k i/s | 1.9k i/s | within noise |

Time per call, Ruby 4.0.10, YJIT, 30 rounds of fresh processes on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `listener poll, idle` | 201.39 µs | 172.61 µs | −14.9% |
| `listener poll, one message` | 468.30 µs | 436.13 µs | not JIT-flat, no claim |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/timing_a1_large/SC1-yjit.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/sc-base at 40dd29ffdc
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/sc-cand at 2cb1842043
- ips listener poll, idle: +16.7% with A/A 1.28% (best base 4.6k / 4.5k, candidate 5.3k), JIT-flat in 15 windows
- ips listener poll, one message: +2.8% with A/A 4.62% (best base 1.9k / 1.8k, candidate 1.9k), JIT-flat in 15 windows: inside the A/A, no claim
- wall listener poll, idle: −14.9% [−15.3%, −14.3%] with A/A +0.1% [−0.5%, +1.0%] (246 calls × 30 windows per process), JIT-flat in 90 processes
- wall listener poll, one message: −6.8% [−7.5%, −6.2%] with A/A −0.1% [−0.8%, +1.4%] (104 calls × 30 windows per process): not JIT-flat (r1 candidate compiled_block_count +1, r2 base compiled_block_count +1, r2 base2 compiled_block_count +1, …), no claim
