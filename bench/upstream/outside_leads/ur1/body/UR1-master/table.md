Objects and Callgrind instructions per call, Ruby 4.1.0dev, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `hello` | 4 | 2 | 4,365 | 4,053 | −7.1% |
| `form key` | 7 | 1 | 12,755 | 5,729 | −55.1% |
| `form value` | 8 | 1 | 14,779 | 5,281 | −64.3% |
| `cookie` | 7 | 1 | 18,936 | 10,408 | −45.0% |

Objects and Callgrind instructions per call, Ruby 4.1.0dev, ZJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `hello` | 4 | 2 | 3,336 | 2,835 | −15.0% |
| `form key` | 7 | 1 | 11,902 | 4,620 | −61.2% |
| `form value` | 8 | 1 | 13,955 | 4,172 | −70.1% |
| `cookie` | 7 | 1 | 18,022 | 9,298 | −48.4% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/outside_leads/ur1/body/UR1-master.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/w/uri-base at 48cda77031
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/w/uri at a3b201f05b
- interp hello: instructions −7.1% with A/A 0.00% (base 4,365 / 4,365, candidate 4,053)
- interp form key: instructions −55.1% with A/A 0.21% (base 12,741 / 12,768, candidate 5,729)
- interp form value: instructions −64.3% with A/A 0.04% (base 14,776 / 14,782, candidate 5,281)
- interp cookie: instructions −45.0% with A/A 0.00% (base 18,936 / 18,936, candidate 10,408)
- zjit hello: instructions −15.0% with A/A 0.00% (base 3,336 / 3,336, candidate 2,835), JIT-flat in 6 windows
- zjit form key: instructions −61.2% with A/A 0.00% (base 11,902 / 11,902, candidate 4,620), JIT-flat in 6 windows
- zjit form value: instructions −70.1% with A/A 0.04% (base 13,958 / 13,952, candidate 4,172), JIT-flat in 6 windows
- zjit cookie: instructions −48.4% with A/A 0.00% (base 18,022 / 18,022, candidate 9,298), JIT-flat in 6 windows
