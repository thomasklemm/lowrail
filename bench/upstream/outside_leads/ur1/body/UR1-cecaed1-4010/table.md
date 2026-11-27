Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `hello` | 4 | 3 | 4,486 | 3,553 | −20.8% |
| `form key` | 7 | 2 | 13,101 | 4,973 | −62.0% |
| `form value` | 8 | 2 | 15,320 | 4,548 | −70.3% |
| `cookie` | 7 | 2 | 18,059 | 9,283 | −48.6% |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `hello` | 4 | 3 | 3,506 | 2,678 | −23.6% |
| `form key` | 7 | 2 | 12,310 | 4,052 | −67.1% |
| `form value` | 8 | 2 | 14,493 | 3,627 | −75.0% |
| `cookie` | 7 | 2 | 17,276 | 8,362 | −51.6% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/outside_leads/ur1/body/UR1-cecaed1-4010.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/uri-base at 48cda77031
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/uri at cecaed123f
- interp hello: instructions −20.8% with A/A 0.00% (base 4,486 / 4,486, candidate 3,553)
- interp form key: instructions −62.0% with A/A 0.02% (base 13,102 / 13,100, candidate 4,973)
- interp form value: instructions −70.3% with A/A 0.33% (base 15,294 / 15,345, candidate 4,548)
- interp cookie: instructions −48.6% with A/A 0.00% (base 18,059 / 18,059, candidate 9,283)
- yjit hello: instructions −23.6% with A/A 0.00% (base 3,506 / 3,506, candidate 2,678), JIT-flat in 6 windows
- yjit form key: instructions −67.1% with A/A 0.07% (base 12,315 / 12,306, candidate 4,052), JIT-flat in 6 windows
- yjit form value: instructions −75.0% with A/A 0.04% (base 14,495 / 14,490, candidate 3,627), JIT-flat in 6 windows
- yjit cookie: instructions −51.6% with A/A 0.01% (base 17,276 / 17,275, candidate 8,362), JIT-flat in 6 windows
