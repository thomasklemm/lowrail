Time per call, Ruby 4.0.10, ZJIT, 20 rounds of fresh processes on one core

| | master | branch | Change |
| --- | ---: | ---: | ---: |
| `quiet.new(repository)` | 141.15 µs | 65.46 µs | not JIT-flat, no claim |
| `quiet.new(auth hash)` | 47.59 µs | 24.39 µs | not JIT-flat, no claim |
| `quiet merge` | 147.64 µs | 69.38 µs | not JIT-flat, no claim |
| `quiet []=` | 0.93 µs | 0.28 µs | not JIT-flat, no claim |
| `Mash.new(repository)` | 160.03 µs | 156.48 µs | not JIT-flat, no claim |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/hashie_perf/round2/wall/HM4-10a9303-4.0.10-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/hashie-base2 at 277e88e6cc
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/hashie-quiet at 10a9303397
- wall quiet.new(repository): −53.4% [−53.8%, −52.5%] with A/A +0.3% [−0.6%, +2.1%] (347 calls × 30 windows per process): not JIT-flat (r1 base compiled_side_exit_count missing, r1 candidate compiled_side_exit_count missing, r1 base2 compiled_side_exit_count missing, …), no claim
- wall quiet.new(auth hash): −48.7% [−49.1%, −48.3%] with A/A −0.6% [−0.9%, +0.1%] (1050 calls × 30 windows per process): not JIT-flat (r1 base compiled_side_exit_count missing, r1 candidate compiled_side_exit_count missing, r1 base2 compiled_side_exit_count missing, …), no claim
- wall quiet merge: −52.6% [−53.0%, −51.9%] with A/A −0.4% [−1.2%, +1.8%] (345 calls × 30 windows per process): not JIT-flat (r1 base compiled_side_exit_count missing, r1 candidate compiled_side_exit_count missing, r1 base2 compiled_side_exit_count missing, …), no claim
- wall quiet []=: −69.4% [−69.5%, −69.2%] with A/A −0.9% [−1.7%, +0.4%] (52678 calls × 30 windows per process): not JIT-flat (r1 base compiled_side_exit_count missing, r1 candidate compiled_side_exit_count missing, r1 base2 compiled_side_exit_count missing, …), no claim
- wall Mash.new(repository): −2.6% [−3.7%, +0.1%] with A/A −0.2% [−0.7%, +2.3%] (309 calls × 30 windows per process): not JIT-flat (r1 base compiled_side_exit_count missing, r1 candidate compiled_side_exit_count missing, r1 base2 compiled_side_exit_count missing, …), no claim
