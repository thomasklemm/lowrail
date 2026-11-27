Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `hello` | 4 | 2 | 4,486 | 4,083 | −9.0% |
| `form key` | 7 | 1 | 13,114 | 5,693 | −56.6% |
| `form value` | 8 | 1 | 15,322 | 5,265 | −65.6% |
| `cookie` | 7 | 1 | 18,056 | 10,154 | −43.8% |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `hello` | 4 | 2 | 3,506 | 2,785 | −20.6% |
| `form key` | 7 | 1 | 12,307 | 4,349 | −64.7% |
| `form value` | 8 | 1 | 14,518 | 3,921 | −73.0% |
| `cookie` | 7 | 1 | 17,272 | 8,810 | −49.0% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/outside_leads/ur1/body/UR1-4010.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/uri-base at 48cda77031
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/uri at a3b201f05b
- interp hello: instructions −9.0% with A/A 0.00% (base 4,486 / 4,486, candidate 4,083)
- interp form key: instructions −56.6% with A/A 0.18% (base 13,126 / 13,103, candidate 5,693)
- interp form value: instructions −65.6% with A/A 0.37% (base 15,351 / 15,294, candidate 5,265)
- interp cookie: instructions −43.8% with A/A 0.02% (base 18,054 / 18,058, candidate 10,154)
- yjit hello: instructions −20.6% with A/A 0.00% (base 3,506 / 3,506, candidate 2,785), JIT-flat in 6 windows
- yjit form key: instructions −64.7% with A/A 0.02% (base 12,306 / 12,309, candidate 4,349), JIT-flat in 6 windows
- yjit form value: instructions −73.0% with A/A 0.44% (base 14,486 / 14,550, candidate 3,921), JIT-flat in 6 windows
- yjit cookie: instructions −49.0% with A/A 0.01% (base 17,271 / 17,272, candidate 8,810), JIT-flat in 6 windows
