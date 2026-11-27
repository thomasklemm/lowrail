Time per call, base and candidate Ruby, ZJIT, 30 rounds of fresh processes on one core

| | Before | After | Change |
| --- | ---: | ---: | ---: |
| `caller` | 27.62 µs | 20.94 µs | −18.4% |
| `Exception#backtrace` | 28.47 µs | 22.11 µs | −17.8% |
| `locations.each(&:to_s)` | 24.12 µs | 18.40 µs | −18.6% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/ruby-differential/evidence/backtrace-format/jit-wall-2026-11-27/zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T13:11:57Z HEAD 274cfe719a) +PRISM [x86_64-linux]
- candidate: ruby 4.1.0dev (2026-11-27T17:45:37Z thomasklemm/backtrace-format-length 5fc1871eec) +PRISM [x86_64-linux]
- wall caller: −18.4% [−19.5%, −17.7%] with A/A −0.8% [−8.0%, +0.3%] (1454 calls × 30 windows per process), JIT-flat in 90 processes
- wall Exception#backtrace: −17.8% [−19.6%, −17.4%] with A/A −1.1% [−8.7%, +0.4%] (1409 calls × 30 windows per process), JIT-flat in 90 processes
- wall locations.each(&:to_s): −18.6% [−19.8%, −18.1%] with A/A −0.6% [−6.6%, +0.3%] (1609 calls × 30 windows per process), JIT-flat in 90 processes
