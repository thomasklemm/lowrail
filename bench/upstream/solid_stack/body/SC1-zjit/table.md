Objects and Callgrind instructions per call, Ruby 4.1.0dev, ZJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `listener poll, idle` | 230 | 227 | 939,464 | 716,730 | −23.7% |
| `listener poll, one message` | – | – | 1,596,073 | 1,373,826 | −13.9% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/solid_stack/body/SC1-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/w/main/solid_cable at 40dd29ffdc
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/w/cand/solid_cable at ef534cc941
- zjit listener poll, idle: instructions −23.7% with A/A 0.04% (base 939,632 / 939,296, candidate 716,730), JIT-flat in 6 windows
- zjit listener poll, one message: objects differ between the two base runs (430.9, 431)
- zjit listener poll, one message: instructions −13.9% with A/A 0.02% (base 1,595,906 / 1,596,239, candidate 1,373,826), JIT-flat in 6 windows
