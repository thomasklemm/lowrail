Objects and Callgrind instructions per call, Ruby 4.1.0dev, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `hello` | 4 | 3 | 4,365 | 3,577 | −18.1% |
| `form key` | 7 | 2 | 12,754 | 5,039 | −60.5% |
| `form value` | 8 | 2 | 14,823 | 4,585 | −69.1% |
| `cookie` | 7 | 2 | 18,961 | 10,095 | −46.8% |

Objects and Callgrind instructions per call, Ruby 4.1.0dev, ZJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `hello` | 4 | 3 | 3,335 | 2,674 | −19.8% |
| `form key` | 7 | 2 | 11,903 | 4,247 | −64.3% |
| `form value` | 8 | 2 | 13,996 | 3,793 | −72.9% |
| `cookie` | 7 | 2 | 18,026 | 9,303 | −48.4% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/outside_leads/ur1/body/UR1-cecaed1-master.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/w/uri-base at 48cda77031
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/w/uri at cecaed123f
- interp hello: instructions −18.1% with A/A 0.00% (base 4,365 / 4,365, candidate 3,577)
- interp form key: instructions −60.5% with A/A 0.23% (base 12,739 / 12,768, candidate 5,039)
- interp form value: instructions −69.1% with A/A 0.55% (base 14,782 / 14,863, candidate 4,585)
- interp cookie: instructions −46.8% with A/A 0.26% (base 18,986 / 18,936, candidate 10,095)
- zjit hello: instructions −19.8% with A/A 0.00% (base 3,335 / 3,335, candidate 2,674), JIT-flat in 6 windows
- zjit form key: instructions −64.3% with A/A 0.02% (base 11,904 / 11,902, candidate 4,247), JIT-flat in 6 windows
- zjit form value: instructions −72.9% with A/A 0.62% (base 13,952 / 14,039, candidate 3,793), JIT-flat in 6 windows
- zjit cookie: instructions −48.4% with A/A 0.00% (base 18,026 / 18,026, candidate 9,303), JIT-flat in 6 windows
