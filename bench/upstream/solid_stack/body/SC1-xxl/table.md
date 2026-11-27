benchmark-ips, Ruby 4.0.10, YJIT, best of 5 on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `listener poll, idle` | 4.6k i/s | 5.3k i/s | +15.9% |
| `listener poll, one message` | 1.8k i/s | 2.0k i/s | not JIT-flat, no claim |

Time per call, Ruby 4.0.10, YJIT, 30 rounds of fresh processes on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `listener poll, idle` | 204.67 µs | 174.20 µs | −14.8% |
| `listener poll, one message` | 476.80 µs | 442.69 µs | not JIT-flat, no claim |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/solid_stack/body/SC1-xxl.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/sc-base at 40dd29ffdc
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/sc-cand at ef534cc941
- ips listener poll, idle: +15.9% with A/A 1.82% (best base 4.6k / 4.7k, candidate 5.3k), JIT-flat in 15 windows
- ips listener poll, one message: +6.7% with A/A 1.90% (best base 1.9k / 1.8k, candidate 2.0k): not JIT-flat (r5 base2 compiled_block_count +6), no claim
- wall listener poll, idle: −14.8% [−15.3%, −14.3%] with A/A −0.9% [−1.5%, +0.1%] (240 calls × 30 windows per process), JIT-flat in 90 processes
- wall listener poll, one message: −6.6% [−7.3%, −5.9%] with A/A −0.3% [−1.8%, +0.5%] (102 calls × 30 windows per process): not JIT-flat (r1 candidate compiled_block_count +1, r2 base compiled_block_count +1, r2 base2 compiled_block_count +1, …), no claim
