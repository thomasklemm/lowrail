Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, main | Objects, main+59717 | Instructions, main | Instructions, main+59717 | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `find_by, logger at debug` | 95 | 90 | 390,247 | 385,774 | −1.1% |
| `find_by, logger at info` | 38 | 38 | 220,422 | 220,479 | +0.0% |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, main | Objects, main+59717 | Instructions, main | Instructions, main+59717 | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `find_by, logger at debug` | 97 | 92 | 203,083 | 197,869 | not JIT-flat, no claim |
| `find_by, logger at info` | 38 | 38 | 92,008 | 92,103 | within noise |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/test_overhead/body/sql-log-main-vs-59717.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /tmp/pt2/rails-main at 2e299253f9
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /tmp/pt2/rails-59717 at 2e299253f9 (dirty)
- interp find_by, logger at debug: instructions −1.1% with A/A 0.01% (base 390,226 / 390,268, candidate 385,774)
- interp find_by, logger at info: instructions +0.0% with A/A 0.00% (base 220,423 / 220,421, candidate 220,479)
- yjit find_by, logger at debug: instructions −2.6% with A/A 0.06% (base 203,140 / 203,026, candidate 197,869): not JIT-flat (base n2000 compiled_block_count +3, candidate n2000 compiled_block_count +3, base2 n2000 compiled_block_count +3), no claim
- yjit find_by, logger at info: instructions +0.1% with A/A 0.16% (base 91,932 / 92,083, candidate 92,103), JIT-flat in 6 windows: inside the A/A, no claim
