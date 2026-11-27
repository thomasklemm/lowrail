Objects and Callgrind instructions per call, Ruby 4.1.0dev, ZJIT

| | Objects, cached | Objects, uncached | Instructions, cached | Instructions, uncached | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `1 binds, no rows` | 95 | 92 | 199,141 | 185,584 | −6.8% |
| `20 binds, no rows` | 130 | 127 | 613,287 | 402,629 | −34.3% |
| `100 binds, no rows` | 210 | 207 | 2,135,239 | 1,102,476 | −48.4% |
| `20 binds, 20 rows` | 340 | 336 | 797,215 | 588,922 | −26.1% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/uncached_survey/runs/ir-model-81-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/sides/base at fatal: not (dirty)
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/sides/uncached at fatal: not (dirty)
- zjit 1 binds, no rows: instructions −6.8% with A/A 0.21% (base 199,346 / 198,935, candidate 185,584), JIT-flat in 6 windows
- zjit 20 binds, no rows: instructions −34.3% with A/A 0.01% (base 613,312 / 613,262, candidate 402,629), JIT-flat in 6 windows
- zjit 100 binds, no rows: instructions −48.4% with A/A 0.17% (base 2,137,064 / 2,133,415, candidate 1,102,476), JIT-flat in 6 windows
- zjit 20 binds, 20 rows: instructions −26.1% with A/A 0.03% (base 797,096 / 797,334, candidate 588,922), JIT-flat in 6 windows
