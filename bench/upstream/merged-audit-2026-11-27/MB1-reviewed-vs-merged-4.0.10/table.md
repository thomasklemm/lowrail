Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, reviewed | Objects, merged | Instructions, reviewed | Instructions, merged | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `post.comments.where(approved: true)` | 27 | 27 | 153,450 | 153,943 | +0.3% |
| `where.merge(order)` | 10 | 10 | 59,436 | 59,584 | +0.2% |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, reviewed | Objects, merged | Instructions, reviewed | Instructions, merged | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `post.comments.where(approved: true)` | 28 | 28 | 66,032 | 66,132 | within noise |
| `where.merge(order)` | 10 | 10 | 27,990 | 28,006 | within noise |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/merged-audit-2026-11-27/MB1-reviewed-vs-merged-4.0.10.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/mb1-reviewed at fc6573f8cb
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/mb1-merged at 9ed75f692f
- interp post.comments.where(approved: true): instructions +0.3% with A/A 0.04% (base 153,478 / 153,422, candidate 153,943)
- interp where.merge(order): instructions +0.2% with A/A 0.13% (base 59,398 / 59,474, candidate 59,584)
- yjit post.comments.where(approved: true): instructions +0.2% with A/A 0.22% (base 65,960 / 66,104, candidate 66,132), JIT-flat in 6 windows: inside the A/A, no claim
- yjit where.merge(order): instructions +0.1% with A/A 0.27% (base 28,028 / 27,952, candidate 28,006), JIT-flat in 6 windows: inside the A/A, no claim
