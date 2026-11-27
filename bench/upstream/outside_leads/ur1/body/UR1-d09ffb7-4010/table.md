Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `hello` | 4 | 3 | 4,486 | 4,054 | −9.6% |
| `form key` | 7 | 2 | 13,100 | 5,474 | −58.2% |
| `form value` | 8 | 2 | 15,290 | 5,049 | −67.0% |
| `cookie` | 7 | 2 | 18,056 | 9,784 | −45.8% |
| `uri hello` | 4 | 3 | 4,486 | 4,054 | −9.6% |
| `uri user` | 6 | 2 | 10,074 | 4,914 | −51.2% |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `hello` | 4 | 3 | 3,506 | 2,770 | −21.0% |
| `form key` | 7 | 2 | 12,328 | 4,144 | −66.4% |
| `form value` | 8 | 2 | 14,511 | 3,719 | −74.4% |
| `cookie` | 7 | 2 | 17,265 | 8,454 | −51.0% |
| `uri hello` | 4 | 3 | 3,506 | 2,770 | −21.0% |
| `uri user` | 6 | 2 | 9,252 | 3,584 | −61.3% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/outside_leads/ur1/body/UR1-d09ffb7-4010.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/uri-base at 48cda77031
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/uri-d09ffb7 at d09ffb7376
- interp hello: instructions −9.6% with A/A 0.00% (base 4,486 / 4,486, candidate 4,054)
- interp form key: instructions −58.2% with A/A 0.02% (base 13,101 / 13,099, candidate 5,474)
- interp form value: instructions −67.0% with A/A 0.04% (base 15,293 / 15,287, candidate 5,049)
- interp cookie: instructions −45.8% with A/A 0.00% (base 18,056 / 18,056, candidate 9,784)
- interp uri hello: instructions −9.6% with A/A 0.00% (base 4,486 / 4,486, candidate 4,054)
- interp uri user: instructions −51.2% with A/A 0.00% (base 10,074 / 10,074, candidate 4,914)
- yjit hello: instructions −21.0% with A/A 0.00% (base 3,506 / 3,506, candidate 2,770), JIT-flat in 6 windows
- yjit form key: instructions −66.4% with A/A 0.31% (base 12,309 / 12,347, candidate 4,144), JIT-flat in 6 windows
- yjit form value: instructions −74.4% with A/A 0.36% (base 14,536 / 14,485, candidate 3,719), JIT-flat in 6 windows
- yjit cookie: instructions −51.0% with A/A 0.01% (base 17,266 / 17,265, candidate 8,454), JIT-flat in 6 windows
- yjit uri hello: instructions −21.0% with A/A 0.00% (base 3,506 / 3,506, candidate 2,770), JIT-flat in 6 windows
- yjit uri user: instructions −61.3% with A/A 0.02% (base 9,251 / 9,253, candidate 3,584), JIT-flat in 6 windows
