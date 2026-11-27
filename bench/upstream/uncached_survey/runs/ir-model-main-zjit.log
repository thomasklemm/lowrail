Objects and Callgrind instructions per call, Ruby 4.1.0dev, ZJIT

| | Objects, cached | Objects, uncached | Instructions, cached | Instructions, uncached | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `1 binds, no rows` | 77 | 74 | 199,300 | 190,360 | −4.5% |
| `20 binds, no rows` | 131 | 128 | 640,431 | 431,087 | −32.7% |
| `100 binds, no rows` | 291 | 288 | 2,251,127 | 1,215,230 | −46.0% |
| `20 binds, 20 rows` | 276 | 272 | 818,915 | 608,838 | −25.7% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/uncached_survey/runs/ir-model-main-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/sides-main/base at fatal: not (dirty)
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/sides-main/uncached at fatal: not (dirty)
- zjit 1 binds, no rows: instructions −4.5% with A/A 0.13% (base 199,173 / 199,426, candidate 190,360), JIT-flat in 6 windows
- zjit 20 binds, no rows: instructions −32.7% with A/A 0.01% (base 640,472 / 640,390, candidate 431,087), JIT-flat in 6 windows
- zjit 100 binds, no rows: instructions −46.0% with A/A 0.03% (base 2,250,746 / 2,251,509, candidate 1,215,230), JIT-flat in 6 windows
- zjit 20 binds, 20 rows: instructions −25.7% with A/A 0.01% (base 818,940 / 818,890, candidate 608,838), JIT-flat in 6 windows
