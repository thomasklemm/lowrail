benchmark-ips, Ruby 4.0.10, YJIT, best of 3 on one core

| | main | TO1 | Change |
| --- | ---: | ---: | ---: |
| `text_field_tag` | 286.9k i/s | 301.9k i/s | +5.3% |
| `submit_tag` | 229.1k i/s | 232.4k i/s | not JIT-flat, no claim |
| `tag.input` | 650.1k i/s | 693.6k i/s | +6.7% |
| `f.text_field` | 177.6k i/s | 180.2k i/s | within noise |
| `f.check_box` | 117.2k i/s | 120.6k i/s | +2.9% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/lead-sweep-2026-11-27/to1/ips_4010.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-main at 2e299253f9
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-to1 at 2eadffb2b3
- ips text_field_tag: +5.3% with A/A 1.09% (best base 285.3k / 288.4k, candidate 301.9k), JIT-flat in 9 windows
- ips submit_tag: +1.5% with A/A 0.55% (best base 228.4k / 229.7k, candidate 232.4k): not JIT-flat (r1 base compiled_block_count +11, r1 candidate compiled_block_count +31, r1 base2 compiled_block_count +11, …), no claim
- ips tag.input: +6.7% with A/A 1.47% (best base 645.3k / 654.9k, candidate 693.6k), JIT-flat in 9 windows
- ips f.text_field: +1.4% with A/A 4.37% (best base 181.5k / 173.8k, candidate 180.2k), JIT-flat in 9 windows: inside the A/A, no claim
- ips f.check_box: +2.9% with A/A 2.13% (best base 118.4k / 115.9k, candidate 120.6k), JIT-flat in 9 windows
