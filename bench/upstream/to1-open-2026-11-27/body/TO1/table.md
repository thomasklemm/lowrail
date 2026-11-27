Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, main | Objects, to1 | Instructions, main | Instructions, to1 | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `text_field_tag` | 7 | 6 | 60,304 | 59,881 | −0.7% |
| `hidden_field_tag` | 9 | 8 | 80,263 | 79,768 | −0.6% |
| `submit_tag` | 13 | 12 | 67,500 | 67,116 | −0.6% |
| `tag.input` | 4 | 3 | 26,818 | 26,416 | −1.5% |
| `image_tag` | 8 | 7 | 61,471 | 61,014 | −0.7% |
| `f.text_field` | 17 | 16 | 110,253 | 110,911 | +0.6% |
| `f.check_box` | 20 | 18 | 152,881 | 151,956 | −0.6% |

Objects and Callgrind instructions per call, Ruby 4.0.10, YJIT

| | Objects, main | Objects, to1 | Instructions, main | Instructions, to1 | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `text_field_tag` | 7 | 6 | 34,983 | 34,381 | −1.7% |
| `hidden_field_tag` | 9 | 8 | 48,197 | 47,669 | −1.1% |
| `submit_tag` | 13 | 12 | 38,672 | 37,974 | −1.8% |
| `tag.input` | 4 | 3 | 15,062 | 14,451 | −4.1% |
| `image_tag` | 8 | 7 | 38,782 | 38,232 | −1.4% |
| `f.text_field` | 18 | 17 | 59,256 | 58,945 | within noise |
| `f.check_box` | 22 | 20 | 82,817 | 81,869 | −1.1% |

benchmark-ips, Ruby 4.0.10, YJIT, best of 3 on one core

| | main | TO1 | Change |
| --- | ---: | ---: | ---: |
| `text_field_tag` | 292.8k i/s | 310.9k i/s | +6.2% |
| `hidden_field_tag` | 207.7k i/s | 212.9k i/s | +2.5% |
| `submit_tag` | 227.3k i/s | 238.2k i/s | +4.8% |
| `tag.input` | 652.7k i/s | 690.2k i/s | +5.7% |
| `image_tag` | 258.8k i/s | 265.4k i/s | +2.6% |
| `f.text_field` | 167.5k i/s | 164.9k i/s | −1.5% |
| `f.check_box` | 114.2k i/s | 116.3k i/s | +1.9% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/to1-open-2026-11-27/body/TO1.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-main at 2e299253f9
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /home/user/w/rails-to1 at 18fd3c4a07
- interp text_field_tag: instructions −0.7% with A/A 0.07% (base 60,326 / 60,282, candidate 59,881)
- interp hidden_field_tag: instructions −0.6% with A/A 0.05% (base 80,245 / 80,281, candidate 79,768)
- interp submit_tag: instructions −0.6% with A/A 0.04% (base 67,486 / 67,513, candidate 67,116)
- interp tag.input: instructions −1.5% with A/A 0.06% (base 26,810 / 26,826, candidate 26,416)
- interp image_tag: instructions −0.7% with A/A 0.01% (base 61,475 / 61,467, candidate 61,014)
- interp f.text_field: instructions +0.6% with A/A 0.03% (base 110,271 / 110,234, candidate 110,911)
- interp f.check_box: instructions −0.6% with A/A 0.12% (base 152,972 / 152,790, candidate 151,956)
- yjit text_field_tag: instructions −1.7% with A/A 0.41% (base 34,911 / 35,056, candidate 34,381), JIT-flat in 6 windows
- yjit hidden_field_tag: instructions −1.1% with A/A 0.14% (base 48,231 / 48,163, candidate 47,669), JIT-flat in 6 windows
- yjit submit_tag: instructions −1.8% with A/A 0.09% (base 38,689 / 38,655, candidate 37,974), JIT-flat in 6 windows
- yjit tag.input: instructions −4.1% with A/A 0.44% (base 15,095 / 15,028, candidate 14,451), JIT-flat in 6 windows
- yjit image_tag: instructions −1.4% with A/A 0.60% (base 38,898 / 38,665, candidate 38,232), JIT-flat in 6 windows
- yjit f.text_field: instructions −0.5% with A/A 0.69% (base 59,462 / 59,051, candidate 58,945), JIT-flat in 6 windows: inside the A/A, no claim
- yjit f.check_box: instructions −1.1% with A/A 0.01% (base 82,813 / 82,821, candidate 81,869), JIT-flat in 6 windows
- ips text_field_tag: +6.2% with A/A 2.51% (best base 296.5k / 289.1k, candidate 310.9k), JIT-flat in 9 windows
- ips hidden_field_tag: +2.5% with A/A 0.38% (best base 208.1k / 207.3k, candidate 212.9k), JIT-flat in 9 windows
- ips submit_tag: +4.8% with A/A 0.28% (best base 227.6k / 227.0k, candidate 238.2k), JIT-flat in 9 windows
- ips tag.input: +5.7% with A/A 0.08% (best base 652.4k / 653.0k, candidate 690.2k), JIT-flat in 9 windows
- ips image_tag: +2.6% with A/A 1.77% (best base 261.0k / 256.5k, candidate 265.4k), JIT-flat in 9 windows
- ips f.text_field: −1.5% with A/A 0.23% (best base 167.3k / 167.7k, candidate 164.9k), JIT-flat in 9 windows
- ips f.check_box: +1.9% with A/A 1.66% (best base 115.1k / 113.2k, candidate 116.3k), JIT-flat in 9 windows
