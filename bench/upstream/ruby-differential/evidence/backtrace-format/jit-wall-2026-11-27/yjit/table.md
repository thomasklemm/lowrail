Time per call, base and candidate Ruby, YJIT, 30 rounds of fresh processes on one core

| | Before | After | Change |
| --- | ---: | ---: | ---: |
| `caller` | 25.75 µs | 19.32 µs | −19.3% |
| `Exception#backtrace` | 26.55 µs | 20.33 µs | −18.5% |
| `locations.each(&:to_s)` | 23.84 µs | 18.30 µs | −18.5% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/rdiff/jitwall/yjit.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T13:11:57Z HEAD 274cfe719a) +PRISM [x86_64-linux]
- candidate: ruby 4.1.0dev (2026-11-27T17:45:37Z thomasklemm/backtrace-format-length 5fc1871eec) +PRISM [x86_64-linux]
- wall caller: −19.3% [−19.8%, −18.9%] with A/A +0.4% [−0.4%, +3.6%] (1583 calls × 30 windows per process), JIT-flat in 90 processes
- wall Exception#backtrace: −18.5% [−19.4%, −17.9%] with A/A +0.4% [−0.4%, +3.3%] (1307 calls × 30 windows per process), JIT-flat in 90 processes
- wall locations.each(&:to_s): −18.5% [−19.0%, −18.0%] with A/A +0.5% [−0.5%, +1.8%] (1177 calls × 30 windows per process), JIT-flat in 90 processes
