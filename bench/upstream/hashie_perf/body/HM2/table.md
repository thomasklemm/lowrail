Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, master | Objects, branch | Instructions, master | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `read keys with suffixes` | 16 | 13 | 34,993 | 35,048 | within noise |
| `write a new key as a method` | 6 | 5 | 19,670 | 19,702 | +0.2% |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, master | Objects, branch | Instructions, master | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `read keys with suffixes` | 16 | 13 | 20,130 | 19,314 | −4.1% |
| `write a new key as a method` | 6 | 5 | 10,775 | 10,530 | −2.3% |

Objects and Callgrind instructions per call, Ruby 4.0.10, ZJIT

| | Objects, master | Objects, branch | Instructions, master | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `read keys with suffixes` | 16 | 13 | 35,857 | 35,871 | not JIT-flat, no claim |
| `write a new key as a method` | 6 | 5 | 18,368 | 18,199 | not JIT-flat, no claim |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/body/HM2.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count; compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/workspace/repo/.amp/in/orb-backup/hashie-perf/hashie-base at 9e313f308f
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/workspace/repo/.amp/in/orb-backup/hashie-perf/hashie-c1 at d1f403e077
- interp read keys with suffixes: instructions +0.2% with A/A 0.29% (base 34,943 / 35,043, candidate 35,048): inside the A/A, no claim
- interp write a new key as a method: instructions +0.2% with A/A 0.01% (base 19,671 / 19,669, candidate 19,702)
- yjit read keys with suffixes: instructions −4.1% with A/A 0.18% (base 20,149 / 20,112, candidate 19,314), JIT-flat in 6 windows
- yjit write a new key as a method: instructions −2.3% with A/A 0.02% (base 10,774 / 10,776, candidate 10,530), JIT-flat in 6 windows
- zjit read keys with suffixes: instructions +0.0% with A/A 0.23% (base 35,900 / 35,815, candidate 35,871): not JIT-flat (base n0 compiled_side_exit_count missing, base n2000 compiled_side_exit_count missing, candidate n0 compiled_side_exit_count missing, …), no claim
- zjit write a new key as a method: instructions −0.9% with A/A 0.00% (base 18,368 / 18,368, candidate 18,199): not JIT-flat (base n0 compiled_side_exit_count missing, base n2000 compiled_side_exit_count missing, candidate n0 compiled_side_exit_count missing, …), no claim
