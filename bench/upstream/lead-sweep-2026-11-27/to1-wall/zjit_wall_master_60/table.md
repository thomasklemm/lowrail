Time per call, Ruby 4.1.0dev, ZJIT, 60 rounds of fresh processes on one core

| | main | TO1 | Change |
| --- | ---: | ---: | ---: |
| `text_field_tag` | 2.80 µs | 2.77 µs | −2.3% |
| `submit_tag` | 3.68 µs | 3.66 µs | −1.2% |
| `tag.input` | 1.33 µs | 1.27 µs | within noise |
| `f.text_field` | 5.13 µs | 5.15 µs | within noise |
| `f.check_box` | 7.49 µs | 7.40 µs | −2.2% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/lead-sweep-2026-11-27/to1/zjit_wall_master_60.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/w/rails-main at 2e299253f9
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/w/rails-to1 at 2eadffb2b3
- wall text_field_tag: −2.3% [−2.8%, −2.0%] with A/A −0.3% [−1.2%, +0.1%] (17431 calls × 30 windows per process), JIT-flat in 180 processes
- wall submit_tag: −1.2% [−1.7%, −0.2%] with A/A −0.4% [−0.9%, +0.6%] (12962 calls × 30 windows per process), JIT-flat in 180 processes
- wall tag.input: −5.3% [−5.7%, −4.9%] with A/A −0.5% [−0.9%, −0.2%] (36517 calls × 30 windows per process), JIT-flat in 180 processes: A/A interval excludes 0, no claim
- wall f.text_field: −0.2% [−0.7%, +0.6%] with A/A −0.3% [−0.9%, +0.6%] (9944 calls × 30 windows per process), JIT-flat in 180 processes: interval includes 0, no claim
- wall f.check_box: −2.2% [−2.6%, −1.7%] with A/A −0.4% [−1.1%, +0.4%] (6159 calls × 30 windows per process), JIT-flat in 180 processes
