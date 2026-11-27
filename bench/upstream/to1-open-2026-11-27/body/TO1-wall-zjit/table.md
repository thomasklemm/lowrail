Time per call, Ruby 4.1.0dev, ZJIT, 30 rounds of fresh processes on one core

| | main | TO1 | Change |
| --- | ---: | ---: | ---: |
| `text_field_tag` | 2.94 µs | 2.87 µs | −2.4% |
| `hidden_field_tag` | 4.44 µs | 4.37 µs | −0.6% |
| `submit_tag` | 3.77 µs | 3.69 µs | −1.5% |
| `tag.input` | 1.39 µs | 1.34 µs | −4.1% |
| `image_tag` | 3.38 µs | 3.30 µs | −2.1% |
| `f.text_field` | 5.69 µs | 5.63 µs | within noise |
| `f.check_box` | 8.22 µs | 8.12 µs | −1.5% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/to1-open-2026-11-27/body/TO1-wall-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/rails-main at 2e299253f9
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z HEAD 0d399335b7) +PRISM [x86_64-linux], /home/user/w/rails-to1 at 18fd3c4a07
- wall text_field_tag: −2.4% [−2.7%, −2.1%] with A/A +0.2% [−0.4%, +0.5%] (15946 calls × 30 windows per process), JIT-flat in 90 processes
- wall hidden_field_tag: −0.6% [−1.7%, −0.2%] with A/A +0.0% [−0.3%, +0.5%] (11151 calls × 30 windows per process), JIT-flat in 90 processes
- wall submit_tag: −1.5% [−2.1%, −1.1%] with A/A −0.2% [−1.0%, +0.4%] (12515 calls × 30 windows per process), JIT-flat in 90 processes
- wall tag.input: −4.1% [−4.3%, −3.5%] with A/A −0.2% [−1.1%, +0.6%] (33801 calls × 30 windows per process), JIT-flat in 90 processes
- wall image_tag: −2.1% [−2.8%, −1.6%] with A/A −0.1% [−1.1%, +0.6%] (14029 calls × 30 windows per process), JIT-flat in 90 processes
- wall f.text_field: +0.4% [−0.4%, +0.9%] with A/A +0.5% [−0.2%, +0.9%] (8404 calls × 30 windows per process), JIT-flat in 90 processes: interval includes 0, no claim
- wall f.check_box: −1.5% [−1.9%, −0.8%] with A/A −0.0% [−0.8%, +0.5%] (5717 calls × 30 windows per process), JIT-flat in 90 processes
