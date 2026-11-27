Time per call, base and candidate Ruby, no JIT, 30 rounds of fresh processes on one core

| | base | head | Change |
| --- | ---: | ---: | ---: |
| `caller` | 31.08 µs | 25.94 µs | −16.4% |
| `Exception#backtrace` | 32.54 µs | 26.79 µs | −16.8% |
| `locations.each(&:to_s)` | 27.60 µs | 22.81 µs | −17.4% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/ruby-differential/evidence/backtrace-format/body-bench-xxlarge-2026-11-27/wall-head.
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T13:11:57Z HEAD 274cfe719a) +PRISM [x86_64-linux]
- candidate: ruby 4.1.0dev (2026-11-27T16:39:23Z HEAD e75b1f0109) +PRISM [x86_64-linux]
- wall caller: −16.4% [−17.7%, −15.7%] with A/A −0.0% [−1.0%, +0.8%] (1572 calls × 30 windows per process)
- wall Exception#backtrace: −16.8% [−19.1%, −16.1%] with A/A −0.2% [−0.7%, +0.4%] (1602 calls × 30 windows per process)
- wall locations.each(&:to_s): −17.4% [−18.5%, −16.8%] with A/A −0.1% [−0.8%, +0.2%] (1855 calls × 30 windows per process)
