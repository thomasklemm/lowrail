benchmark-ips, Ruby 4.0.10, YJIT, best of 3 on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `belongs_to load` | 30.9k i/s | 31.5k i/s | within noise |
| `has_one load` | 28.7k i/s | 29.0k i/s | within noise |
| `has_many load` | 23.9k i/s | 25.0k i/s | not JIT-flat, no claim |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/census13r/body/ASC1-ips.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-main at 2e299253f9
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-asc1 at 2b46f50bda
- ips belongs_to load: +2.0% with A/A 6.83% (best base 31.9k / 29.8k, candidate 31.5k), JIT-flat in 9 windows: inside the A/A, no claim
- ips has_one load: +1.3% with A/A 2.60% (best base 29.0k / 28.3k, candidate 29.0k), JIT-flat in 9 windows: inside the A/A, no claim
- ips has_many load: +4.4% with A/A 9.41% (best base 25.1k / 22.8k, candidate 25.0k): not JIT-flat (r1 base compiled_iseq_count +1, r1 base compiled_block_count +14, r1 candidate compiled_block_count +30, …), no claim
