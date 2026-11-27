Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, main | Objects, main-copy | Instructions, main | Instructions, main-copy | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `find_by, logger at debug` | 95 | 95 | 389,924 | 390,241 | +0.1% |
| `find_by, logger at info` | 38 | 38 | 220,421 | 220,488 | within noise |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, main | Objects, main-copy | Instructions, main | Instructions, main-copy | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `find_by, logger at debug` | 97 | 97 | 202,954 | 203,252 | not JIT-flat, no claim |
| `find_by, logger at info` | 38 | 38 | 92,036 | 91,952 | −0.1% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/test_overhead/body/sql-log-main.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /tmp/pt2/rails-main at 2e299253f9
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /tmp/pt2/rails-mainb at 2e299253f9
- interp find_by, logger at debug: instructions +0.1% with A/A 0.01% (base 389,912 / 389,935, candidate 390,241)
- interp find_by, logger at info: instructions +0.0% with A/A 0.03% (base 220,386 / 220,456, candidate 220,488): inside the A/A, no claim
- yjit find_by, logger at debug: instructions +0.1% with A/A 0.15% (base 203,107 / 202,801, candidate 203,252): not JIT-flat (base n2000 compiled_block_count +3, candidate n2000 compiled_block_count +3, base2 n2000 compiled_block_count +3), no claim
- yjit find_by, logger at info: instructions −0.1% with A/A 0.00% (base 92,038 / 92,035, candidate 91,952), JIT-flat in 6 windows
