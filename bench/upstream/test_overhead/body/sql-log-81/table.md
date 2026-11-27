Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, 81 | Objects, 81-copy | Instructions, 81 | Instructions, 81-copy | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `find_by, logger at debug` | 95 | 95 | 341,828 | 341,902 | within noise |
| `find_by, logger at info` | 50 | 50 | 236,588 | 236,676 | +0.0% |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, 81 | Objects, 81-copy | Instructions, 81 | Instructions, 81-copy | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `find_by, logger at debug` | 97 | 97 | 189,733 | 189,327 | within noise |
| `find_by, logger at info` | 50 | 50 | 120,515 | 120,435 | −0.1% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/test_overhead/body/sql-log-81.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /tmp/pt2/rails-81 at 3f290b759c
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /tmp/pt2/rails-81b at 3f290b759c
- interp find_by, logger at debug: instructions +0.0% with A/A 0.05% (base 341,745 / 341,910, candidate 341,902): inside the A/A, no claim
- interp find_by, logger at info: instructions +0.0% with A/A 0.01% (base 236,604 / 236,571, candidate 236,676)
- yjit find_by, logger at debug: instructions −0.2% with A/A 0.44% (base 189,316 / 190,151, candidate 189,327), JIT-flat in 6 windows: inside the A/A, no claim
- yjit find_by, logger at info: instructions −0.1% with A/A 0.01% (base 120,511 / 120,519, candidate 120,435), JIT-flat in 6 windows
