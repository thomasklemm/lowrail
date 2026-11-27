Objects and Callgrind instructions per call, Ruby 4.1.0dev, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `hello` | 4 | 3 | 4,365 | 4,081 | −6.5% |
| `form key` | 7 | 2 | 12,743 | 5,542 | −56.5% |
| `form value` | 8 | 2 | 14,862 | 5,087 | −65.8% |
| `cookie` | 7 | 2 | 19,049 | 10,632 | −44.2% |
| `uri hello` | 4 | 3 | 4,366 | 4,081 | −6.5% |
| `uri user` | 6 | 2 | 9,768 | 4,966 | −49.2% |

Objects and Callgrind instructions per call, Ruby 4.1.0dev, ZJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `hello` | 4 | 3 | 3,342 | 2,745 | −17.9% |
| `form key` | 7 | 2 | 11,914 | 4,321 | −63.7% |
| `form value` | 8 | 2 | 13,958 | 3,867 | −72.3% |
| `cookie` | 7 | 2 | 18,093 | 9,411 | −48.0% |
| `uri hello` | 4 | 3 | 3,342 | 2,745 | −17.9% |
| `uri user` | 6 | 2 | 8,913 | 3,745 | −58.0% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/outside_leads/ur1/body/UR1-d09ffb7-master.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/uri-base at 48cda77031
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/uri-d09ffb7 at d09ffb7376
- interp hello: instructions −6.5% with A/A 0.01% (base 4,365 / 4,366, candidate 4,081)
- interp form key: instructions −56.5% with A/A 0.03% (base 12,741 / 12,745, candidate 5,542)
- interp form value: instructions −65.8% with A/A 1.09% (base 14,781 / 14,943, candidate 5,087)
- interp cookie: instructions −44.2% with A/A 0.28% (base 19,076 / 19,022, candidate 10,632)
- interp uri hello: instructions −6.5% with A/A 0.00% (base 4,366 / 4,366, candidate 4,081)
- interp uri user: instructions −49.2% with A/A 0.00% (base 9,768 / 9,768, candidate 4,966)
- zjit hello: instructions −17.9% with A/A 0.00% (base 3,342 / 3,342, candidate 2,745), JIT-flat in 6 windows
- zjit form key: instructions −63.7% with A/A 0.23% (base 11,928 / 11,901, candidate 4,321), JIT-flat in 6 windows
- zjit form value: instructions −72.3% with A/A 0.00% (base 13,958 / 13,958, candidate 3,867), JIT-flat in 6 windows
- zjit cookie: instructions −48.0% with A/A 0.00% (base 18,093 / 18,093, candidate 9,411), JIT-flat in 6 windows
- zjit uri hello: instructions −17.9% with A/A 0.00% (base 3,342 / 3,342, candidate 2,745), JIT-flat in 6 windows
- zjit uri user: instructions −58.0% with A/A 0.02% (base 8,912 / 8,914, candidate 3,745), JIT-flat in 6 windows
