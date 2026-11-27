Objects and Callgrind instructions per call, Ruby 4.1.0dev, ZJIT

| | Objects, reviewed | Objects, merged | Instructions, reviewed | Instructions, merged | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Marshal.dump` | 14 | 14 | 215,729 | 215,524 | −0.1% |
| `attributes_for_database` | 2 | 2 | 57,712 | 57,750 | within noise |
| `attributes_before_type_cast` | 2 | 2 | 49,819 | 49,655 | within noise |
| `MessagePack dump` | 17 | 17 | 79,583 | 79,397 | −0.2% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/merged-audit-2026-11-27/L3-reviewed-vs-merged-master-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.1.0dev (2026-11-27T09:42:55Z HEAD f3e180b5eb) +PRISM [x86_64-linux], /home/user/w/l3-reviewed at b113448052
- candidate: ruby 4.1.0dev (2026-11-27T09:42:55Z HEAD f3e180b5eb) +PRISM [x86_64-linux], /home/user/w/l3-merged at 9c28399099
- zjit Marshal.dump: instructions −0.1% with A/A 0.04% (base 215,775 / 215,682, candidate 215,524), JIT-flat in 6 windows
- zjit attributes_for_database: instructions +0.1% with A/A 0.21% (base 57,771 / 57,652, candidate 57,750), JIT-flat in 6 windows: inside the A/A, no claim
- zjit attributes_before_type_cast: instructions −0.3% with A/A 0.36% (base 49,729 / 49,910, candidate 49,655), JIT-flat in 6 windows: inside the A/A, no claim
- zjit MessagePack dump: instructions −0.2% with A/A 0.01% (base 79,579 / 79,588, candidate 79,397), JIT-flat in 6 windows
