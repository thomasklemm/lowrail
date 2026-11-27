Time per call, Ruby 4.0.10, YJIT, 30 rounds of fresh processes on one core

| | main | TO1 | Change |
| --- | ---: | ---: | ---: |
| `text_field_tag` | 2.99 µs | 2.92 µs | −3.1% |
| `submit_tag` | 3.64 µs | 3.58 µs | −2.1% |
| `tag.input` | 1.30 µs | 1.24 µs | −6.0% |
| `f.text_field` | 4.82 µs | 4.78 µs | within noise |
| `f.check_box` | 7.18 µs | 7.03 µs | within noise |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/lead-sweep-2026-11-27/to1/yjit_wall_4010.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- Wall: thread CPU time with GC off per window, the 10th-percentile window per process; change = median of every round's candidate / base and candidate / base2, A/A = median of base2 / base, 95% bootstrap intervals resampling rounds
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-main at 2e299253f9
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-to1 at 2eadffb2b3
- wall text_field_tag: −3.1% [−4.3%, −1.4%] with A/A −0.0% [−1.5%, +1.9%] (16018 calls × 30 windows per process), JIT-flat in 90 processes
- wall submit_tag: −2.1% [−3.9%, −0.7%] with A/A +0.5% [−0.2%, +1.8%] (13609 calls × 30 windows per process), JIT-flat in 90 processes
- wall tag.input: −6.0% [−7.7%, −4.5%] with A/A −0.1% [−2.4%, +1.6%] (36897 calls × 30 windows per process), JIT-flat in 90 processes
- wall f.text_field: −0.2% [−1.6%, +1.9%] with A/A −1.0% [−3.6%, +3.9%] (10182 calls × 30 windows per process), JIT-flat in 90 processes: interval includes 0, no claim
- wall f.check_box: −1.5% [−5.4%, +1.1%] with A/A −0.5% [−3.2%, +2.5%] (6869 calls × 30 windows per process), JIT-flat in 90 processes: interval includes 0, no claim
