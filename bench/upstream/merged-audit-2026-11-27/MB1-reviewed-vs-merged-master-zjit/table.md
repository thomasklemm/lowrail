Objects and Callgrind instructions per call, Ruby 4.1.0dev, ZJIT

| | Objects, reviewed | Objects, merged | Instructions, reviewed | Instructions, merged | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `post.comments.where(approved: true)` | 27 | 27 | 64,461 | 64,429 | within noise |
| `where.merge(order)` | 10 | 10 | 28,062 | 28,040 | −0.1% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/merged-audit-2026-11-27/MB1-reviewed-vs-merged-master-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.1.0dev (2026-11-27T09:42:55Z HEAD f3e180b5eb) +PRISM [x86_64-linux], /home/user/w/mb1-reviewed at fc6573f8cb
- candidate: ruby 4.1.0dev (2026-11-27T09:42:55Z HEAD f3e180b5eb) +PRISM [x86_64-linux], /home/user/w/mb1-merged at 9ed75f692f
- zjit post.comments.where(approved: true): instructions −0.1% with A/A 0.32% (base 64,357 / 64,565, candidate 64,429), JIT-flat in 6 windows: inside the A/A, no claim
- zjit where.merge(order): instructions −0.1% with A/A 0.01% (base 28,061 / 28,064, candidate 28,040), JIT-flat in 6 windows
