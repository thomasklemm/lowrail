Time per call, Ruby 4.1.0dev, no JIT, 40 rounds of fresh processes on one core

| | base | candidate | Change |
| --- | ---: | ---: | ---: |
| `Location#to_s` | 30.69 µs | 30.56 µs | within noise |
| `caller` | 33.82 µs | 33.87 µs | within noise |
| `Exception#backtrace` | 33.69 µs | 33.17 µs | within noise |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/ruby-differential/evidence/backtrace-format/body-bench-large-2026-11-27/wall-aa-base-vs-basecopy.
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T13:11:57Z HEAD 274cfe719a) +PRISM [x86_64-linux]
- candidate: ruby 4.1.0dev (2026-11-27T13:11:57Z HEAD 274cfe719a) +PRISM [x86_64-linux]
- wall Location#to_s: −2.0% [−2.9%, −0.4%] with A/A −1.3% [−4.5%, −0.2%] (1409 calls × 30 windows per process): A/A interval excludes 0, no claim
- wall caller: −0.8% [−1.8%, +1.5%] with A/A −1.2% [−3.8%, −0.2%] (1285 calls × 30 windows per process): A/A interval excludes 0, no claim
- wall Exception#backtrace: −1.8% [−2.9%, +0.4%] with A/A −2.2% [−3.9%, −0.2%] (1296 calls × 30 windows per process): A/A interval excludes 0, no claim
