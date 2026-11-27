Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, master | Objects, branch | Instructions, master | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `read keys with suffixes` | 16 | 13 | 34,950 | 35,142 | +0.6% |
| `write a new key as a method` | 6 | 5 | 19,669 | 19,706 | +0.2% |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, master | Objects, branch | Instructions, master | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `read keys with suffixes` | 16 | 13 | 20,032 | 19,283 | −3.7% |
| `write a new key as a method` | 6 | 5 | 10,775 | 10,531 | −2.3% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/body/HM2-eae505a.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/workspace/repo/.amp/in/orb-backup/hashie-perf/hashie-base at 9e313f308f
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/workspace/repo/.amp/in/orb-backup/hashie-perf/hashie-c1 at eae505a846
- interp read keys with suffixes: instructions +0.6% with A/A 0.13% (base 34,928 / 34,972, candidate 35,142)
- interp write a new key as a method: instructions +0.2% with A/A 0.00% (base 19,669 / 19,669, candidate 19,706)
- yjit read keys with suffixes: instructions −3.7% with A/A 0.19% (base 20,051 / 20,013, candidate 19,283), JIT-flat in 6 windows
- yjit write a new key as a method: instructions −2.3% with A/A 0.02% (base 10,776 / 10,774, candidate 10,531), JIT-flat in 6 windows
