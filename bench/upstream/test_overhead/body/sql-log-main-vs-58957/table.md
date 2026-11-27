Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, main | Objects, 58957 | Instructions, main | Instructions, 58957 | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `find_by, logger at debug` | 95 | 95 | 390,334 | 390,455 | within noise |
| `find_by, logger at info` | 38 | 38 | 220,388 | 220,211 | −0.1% |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, main | Objects, 58957 | Instructions, main | Instructions, 58957 | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `find_by, logger at debug` | 97 | 97 | 202,838 | 202,768 | not JIT-flat, no claim |
| `find_by, logger at info` | 38 | 38 | 91,951 | 91,962 | within noise |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/test_overhead/body/sql-log-main-vs-58957.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /tmp/pt2/rails-main at 2e299253f9
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /tmp/pt2/rails-58957 at 2bb5d3df1c
- interp find_by, logger at debug: instructions +0.0% with A/A 0.05% (base 390,229 / 390,439, candidate 390,455): inside the A/A, no claim
- interp find_by, logger at info: instructions −0.1% with A/A 0.04% (base 220,344 / 220,431, candidate 220,211)
- yjit find_by, logger at debug: instructions −0.0% with A/A 0.12% (base 202,721 / 202,956, candidate 202,768): not JIT-flat (base n2000 compiled_block_count +3, candidate n2000 compiled_block_count +3), no claim
- yjit find_by, logger at info: instructions +0.0% with A/A 0.02% (base 91,943 / 91,959, candidate 91,962), JIT-flat in 6 windows: inside the A/A, no claim
