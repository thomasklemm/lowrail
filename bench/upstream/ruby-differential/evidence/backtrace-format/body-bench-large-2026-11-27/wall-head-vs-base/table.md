Time per call, base and candidate Ruby, no JIT, 40 rounds of fresh processes on one core

| | base | candidate | Change |
| --- | ---: | ---: | ---: |
| `Location#to_s` | 31.58 µs | 25.90 µs | −18.1% |
| `caller` | 34.76 µs | 28.61 µs | −18.0% |
| `Exception#backtrace` | 34.57 µs | 28.38 µs | −18.3% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/ruby-differential/evidence/backtrace-format/body-bench-large-2026-11-27/wall-head-vs-base.
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T13:11:57Z HEAD 274cfe719a) +PRISM [x86_64-linux]
- candidate: ruby 4.1.0dev (2026-11-27T16:39:23Z HEAD e75b1f0109) +PRISM [x86_64-linux]
- wall Location#to_s: −18.1% [−19.0%, −17.2%] with A/A +0.4% [−0.3%, +1.6%] (1452 calls × 30 windows per process)
- wall caller: −18.0% [−18.7%, −17.5%] with A/A +0.1% [−0.8%, +1.1%] (1335 calls × 30 windows per process)
- wall Exception#backtrace: −18.3% [−18.8%, −17.3%] with A/A +0.4% [−0.5%, +1.5%] (1343 calls × 30 windows per process)
