Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, main | Objects, both | Instructions, main | Instructions, both | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `find_by, logger at debug` | 95 | 90 | 390,192 | 385,791 | −1.1% |
| `find_by, logger at info` | 38 | 38 | 220,432 | 220,354 | −0.0% |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, main | Objects, both | Instructions, main | Instructions, both | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `find_by, logger at debug` | 97 | 92 | 202,775 | 197,822 | not JIT-flat, no claim |
| `find_by, logger at info` | 38 | 38 | 92,469 | 92,022 | within noise |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/test_overhead/body/sql-log-main-vs-both.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /tmp/pt2/rails-main at 2e299253f9
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /tmp/pt2/rails-both at 2bb5d3df1c (dirty)
- interp find_by, logger at debug: instructions −1.1% with A/A 0.04% (base 390,118 / 390,266, candidate 385,791)
- interp find_by, logger at info: instructions −0.0% with A/A 0.00% (base 220,436 / 220,428, candidate 220,354)
- yjit find_by, logger at debug: instructions −2.4% with A/A 0.03% (base 202,741 / 202,808, candidate 197,822): not JIT-flat (base n2000 compiled_block_count +3, base2 n2000 compiled_block_count +3), no claim
- yjit find_by, logger at info: instructions −0.5% with A/A 0.99% (base 92,010 / 92,929, candidate 92,022), JIT-flat in 6 windows: inside the A/A, no claim
