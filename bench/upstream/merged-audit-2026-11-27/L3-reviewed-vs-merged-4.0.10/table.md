Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, reviewed | Objects, merged | Instructions, reviewed | Instructions, merged | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Marshal.dump` | 14 | 14 | 269,104 | 267,982 | −0.4% |
| `attributes_for_database` | 2 | 2 | 111,019 | 110,194 | −0.7% |
| `attributes_before_type_cast` | 2 | 2 | 74,210 | 73,557 | −0.9% |
| `MessagePack dump` | 17 | 17 | 139,372 | 139,002 | −0.3% |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, reviewed | Objects, merged | Instructions, reviewed | Instructions, merged | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `Marshal.dump` | 14 | 14 | 216,093 | 216,217 | +0.1% |
| `attributes_for_database` | 2 | 2 | 61,900 | 61,617 | within noise |
| `attributes_before_type_cast` | 2 | 2 | 51,184 | 51,236 | within noise |
| `MessagePack dump` | 17 | 17 | 84,902 | 84,787 | −0.1% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/merged-audit-2026-11-27/L3-reviewed-vs-merged-4.0.10.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/l3-reviewed at b113448052
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/l3-merged at 9c28399099
- interp Marshal.dump: instructions −0.4% with A/A 0.18% (base 269,349 / 268,859, candidate 267,982)
- interp attributes_for_database: instructions −0.7% with A/A 0.09% (base 110,969 / 111,069, candidate 110,194)
- interp attributes_before_type_cast: instructions −0.9% with A/A 0.21% (base 74,288 / 74,131, candidate 73,557)
- interp MessagePack dump: instructions −0.3% with A/A 0.23% (base 139,536 / 139,208, candidate 139,002)
- yjit Marshal.dump: instructions +0.1% with A/A 0.04% (base 216,141 / 216,044, candidate 216,217), JIT-flat in 6 windows
- yjit attributes_for_database: instructions −0.5% with A/A 0.58% (base 61,722 / 62,079, candidate 61,617), JIT-flat in 6 windows: inside the A/A, no claim
- yjit attributes_before_type_cast: instructions +0.1% with A/A 0.35% (base 51,273 / 51,094, candidate 51,236), JIT-flat in 6 windows: inside the A/A, no claim
- yjit MessagePack dump: instructions −0.1% with A/A 0.11% (base 84,950 / 84,855, candidate 84,787), JIT-flat in 6 windows
