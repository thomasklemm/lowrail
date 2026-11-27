Time per call, Ruby 4.0.10, YJIT, 30 rounds of fresh processes on one core

| | main | TO1 | Change |
| --- | ---: | ---: | ---: |
| `text_field_tag` | 3.21 µs | 3.12 µs | −2.5% |
| `hidden_field_tag` | 4.48 µs | 4.41 µs | −2.2% |
| `submit_tag` | 3.90 µs | 3.81 µs | −2.2% |
| `tag.input` | 1.40 µs | 1.32 µs | −5.7% |
| `image_tag` | 3.66 µs | 3.62 µs | −1.5% |
| `f.text_field` | 5.68 µs | 5.67 µs | within noise |
| `f.check_box` | 8.19 µs | 8.05 µs | −1.7% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/to1-open-2026-11-27/body/TO1-wall-yjit.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-main at 2e299253f9
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-to1 at 18fd3c4a07
- wall text_field_tag: −2.5% [−3.3%, −2.0%] with A/A +0.4% [−0.7%, +1.0%] (14643 calls × 30 windows per process), JIT-flat in 90 processes
- wall hidden_field_tag: −2.2% [−2.6%, −1.5%] with A/A +0.3% [−0.3%, +0.8%] (10438 calls × 30 windows per process), JIT-flat in 90 processes
- wall submit_tag: −2.2% [−2.7%, −1.6%] with A/A +0.4% [−0.2%, +1.1%] (11919 calls × 30 windows per process), JIT-flat in 90 processes
- wall tag.input: −5.7% [−6.3%, −4.8%] with A/A +0.2% [−0.2%, +1.1%] (33942 calls × 30 windows per process), JIT-flat in 90 processes
- wall image_tag: −1.5% [−2.0%, −0.7%] with A/A +0.5% [−0.4%, +1.0%] (12731 calls × 30 windows per process), JIT-flat in 90 processes
- wall f.text_field: −0.2% [−1.0%, +0.7%] with A/A +0.3% [−0.5%, +0.9%] (8598 calls × 30 windows per process), JIT-flat in 90 processes: interval includes 0, no claim
- wall f.check_box: −1.7% [−2.2%, −0.6%] with A/A +0.0% [−0.9%, +1.0%] (5584 calls × 30 windows per process), JIT-flat in 90 processes
