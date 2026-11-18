Objects and Callgrind instructions per call, Ruby 4.0.7, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `text_field` | 28 | 22 | 120,408 | 116,392 | −3.3% |
| `checkbox` | 32 | 26 | 164,185 | 160,568 | −2.2% |
| `text_field, persisted` | 28 | 22 | 120,000 | 116,535 | −2.9% |
| `checkbox, persisted` | 32 | 26 | 164,180 | 160,569 | −2.2% |

Objects and Callgrind instructions per call, Ruby 4.0.7, YJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `text_field` | 29 | 23 | 65,842 | 62,264 | −5.4% |
| `checkbox` | 34 | 28 | 88,782 | 85,556 | −3.6% |
| `text_field, persisted` | 29 | 23 | 65,756 | 62,846 | −4.4% |
| `checkbox, persisted` | 34 | 28 | 88,903 | 85,335 | −4.0% |

benchmark-ips, Ruby 4.0.7, YJIT, best of 3 on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `text_field` | 106.1k i/s | 115.0k i/s | +8.5% |
| `checkbox` | 73.1k i/s | 77.0k i/s | +5.4% |
| `text_field, persisted` | 105.5k i/s | 110.9k i/s | +5.1% |
| `checkbox, persisted` | 73.1k i/s | 75.7k i/s | +3.6% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/form_helper_stack/body/fb1/gated.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux], /home/user/workspace/rails-fb1-main at a5203b3d4d
- candidate: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux], /home/user/workspace/rails-fb1 at a2a13fc793
- interp text_field: instructions −3.3% with A/A 0.13% (base 120,486 / 120,329, candidate 116,392)
- interp checkbox: instructions −2.2% with A/A 0.03% (base 164,157 / 164,213, candidate 160,568)
- interp text_field, persisted: instructions −2.9% with A/A 0.17% (base 119,897 / 120,104, candidate 116,535)
- interp checkbox, persisted: instructions −2.2% with A/A 0.12% (base 164,084 / 164,276, candidate 160,569)
- yjit text_field: instructions −5.4% with A/A 0.59% (base 65,646 / 66,038, candidate 62,264), JIT-flat in 6 windows
- yjit checkbox: instructions −3.6% with A/A 0.06% (base 88,808 / 88,756, candidate 85,556), JIT-flat in 6 windows
- yjit text_field, persisted: instructions −4.4% with A/A 0.15% (base 65,806 / 65,705, candidate 62,846), JIT-flat in 6 windows
- yjit checkbox, persisted: instructions −4.0% with A/A 0.29% (base 88,776 / 89,030, candidate 85,335), JIT-flat in 6 windows
- ips text_field: +8.5% with A/A 0.94% (best base 105.6k / 106.6k, candidate 115.0k), JIT-flat in 9 windows
- ips checkbox: +5.4% with A/A 0.95% (best base 73.4k / 72.7k, candidate 77.0k), JIT-flat in 9 windows
- ips text_field, persisted: +5.1% with A/A 4.05% (best base 103.4k / 107.7k, candidate 110.9k), JIT-flat in 9 windows
- ips checkbox, persisted: +3.6% with A/A 1.83% (best base 72.4k / 73.7k, candidate 75.7k), JIT-flat in 9 windows
