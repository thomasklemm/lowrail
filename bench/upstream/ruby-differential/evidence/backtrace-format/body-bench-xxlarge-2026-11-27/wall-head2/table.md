Time per call, base and candidate Ruby, no JIT, 30 rounds of fresh processes on one core

| | base | head | Change |
| --- | ---: | ---: | ---: |
| `caller` | 30.44 µs | 24.50 µs | −19.1% |
| `Exception#backtrace` | 31.90 µs | 25.26 µs | −20.4% |
| `locations.each(&:to_s)` | 27.01 µs | 21.62 µs | −19.6% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/ruby-differential/evidence/backtrace-format/body-bench-xxlarge-2026-11-27/wall-head2.
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T13:11:57Z HEAD 274cfe719a) +PRISM [x86_64-linux]
- candidate: ruby 4.1.0dev (2026-11-27T17:45:37Z HEAD 5fc1871eec) +PRISM [x86_64-linux]
- wall caller: −19.1% [−20.1%, −18.4%] with A/A +0.0% [−0.8%, +1.0%] (1628 calls × 30 windows per process)
- wall Exception#backtrace: −20.4% [−21.5%, −19.0%] with A/A +0.1% [−0.9%, +1.2%] (1561 calls × 30 windows per process)
- wall locations.each(&:to_s): −19.6% [−20.6%, −18.5%] with A/A +0.2% [−0.6%, +0.6%] (1754 calls × 30 windows per process)
