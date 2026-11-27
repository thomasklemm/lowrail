Time per call, Ruby 4.1.0dev, ZJIT, 30 rounds of fresh processes on one core

| | main | TO1 | Change |
| --- | ---: | ---: | ---: |
| `text_field_tag` | 2.75 µs | 2.74 µs | −0.9% |
| `submit_tag` | 3.59 µs | 3.60 µs | within noise |
| `tag.input` | 1.30 µs | 1.25 µs | −5.4% |
| `f.text_field` | 5.00 µs | 5.11 µs | within noise |
| `f.check_box` | 7.32 µs | 7.24 µs | within noise |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/lead-sweep-2026-11-27/to1/zjit_wall_master.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/w/rails-main at 2e299253f9
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/w/rails-to1 at 2eadffb2b3
- wall text_field_tag: −0.9% [−1.6%, −0.5%] with A/A −0.1% [−1.1%, +1.5%] (17014 calls × 30 windows per process), JIT-flat in 90 processes
- wall submit_tag: −1.5% [−3.2%, +0.6%] with A/A +0.6% [−0.6%, +2.0%] (13160 calls × 30 windows per process), JIT-flat in 90 processes: interval includes 0, no claim
- wall tag.input: −5.4% [−6.5%, −4.4%] with A/A +0.4% [−0.5%, +3.1%] (36641 calls × 30 windows per process), JIT-flat in 90 processes
- wall f.text_field: +1.5% [−0.2%, +2.4%] with A/A +0.3% [−2.2%, +1.8%] (9699 calls × 30 windows per process), JIT-flat in 90 processes: interval includes 0, no claim
- wall f.check_box: −1.5% [−2.1%, +0.1%] with A/A +1.2% [−0.2%, +2.4%] (6467 calls × 30 windows per process), JIT-flat in 90 processes: interval includes 0, no claim
