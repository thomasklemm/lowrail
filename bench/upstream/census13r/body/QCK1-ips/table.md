benchmark-ips, Ruby 4.0.10, YJIT, best of 3 on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `find, miss` | 56.6k i/s | 60.9k i/s | +7.6% |
| `find, hit` | 77.2k i/s | 80.4k i/s | within noise |
| `where with 3 binds, miss` | 31.7k i/s | 32.3k i/s | not JIT-flat, no claim |
| `where with 3 binds, hit` | 40.5k i/s | 43.0k i/s | +6.3% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/census13r/body/QCK1-ips.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-main at 2e299253f9
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-qck1 at 40e4c9db8f
- ips find, miss: +7.6% with A/A 5.01% (best base 58.0k / 55.2k, candidate 60.9k), JIT-flat in 9 windows
- ips find, hit: +4.1% with A/A 6.19% (best base 79.6k / 74.9k, candidate 80.4k), JIT-flat in 9 windows: inside the A/A, no claim
- ips where with 3 binds, miss: +1.7% with A/A 1.72% (best base 32.0k / 31.5k, candidate 32.3k): not JIT-flat (r1 base compiled_iseq_count +1, r1 base compiled_block_count +10, r1 candidate compiled_block_count +12, …), no claim
- ips where with 3 binds, hit: +6.3% with A/A 5.57% (best base 41.6k / 39.3k, candidate 43.0k), JIT-flat in 9 windows
