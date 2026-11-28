Objects and Callgrind instructions per call, Ruby 4.1.0dev, ZJIT

| | Objects, main | Objects, uncached | Instructions, main | Instructions, uncached | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `worker poll, idle` | 290 | 288 | 617,396 | 620,581 | +0.5% |
| `dispatcher poll, idle` | – | – | 627,122 | 646,509 | +3.1% |
| `dispatcher poll, 10 due jobs` | – | – | 16,382,559 | 15,644,388 | not JIT-flat, no claim |
| `dispatcher poll, 100 due jobs` | – | – | 119,682,123 | 112,655,298 | not JIT-flat, no claim |
| `worker claim, 3 jobs` | – | – | 7,004,022 | 6,954,950 | −0.7% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/uncached_survey/runs/ir-sq-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/main/solid_queue at b9c646a848
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/cand/solid_queue at b9c646a848 (dirty)
- zjit worker poll, idle: instructions +0.5% with A/A 0.02% (base 617,468 / 617,324, candidate 620,581), JIT-flat in 6 windows
- zjit dispatcher poll, idle: objects differ between the two base runs (294, 293.9)
- zjit dispatcher poll, idle: instructions +3.1% with A/A 0.00% (base 627,117 / 627,127, candidate 646,509), JIT-flat in 6 windows
- zjit dispatcher poll, 10 due jobs: objects differ between the two base runs (5392.6, 5392.6)
- zjit dispatcher poll, 10 due jobs: instructions −4.5% with A/A 0.17% (base 16,396,617 / 16,368,502, candidate 15,644,388): not JIT-flat (base n200 compiled_iseq_count +2, base n200 compiled_side_exit_count +24, candidate n200 compiled_iseq_count +2, …), no claim
- zjit dispatcher poll, 100 due jobs: objects differ between the two base runs (33653.7, 33644.5)
- zjit dispatcher poll, 100 due jobs: instructions −5.9% with A/A 0.04% (base 119,704,361 / 119,659,885, candidate 112,655,298): not JIT-flat (base n200 compiled_iseq_count +2, base n200 compiled_side_exit_count +8, candidate n200 compiled_iseq_count +2, …), no claim
- zjit worker claim, 3 jobs: objects differ between the two base runs (2,612, 2,612)
- zjit worker claim, 3 jobs: instructions −0.7% with A/A 0.00% (base 7,004,044 / 7,004,001, candidate 6,954,950), JIT-flat in 6 windows
