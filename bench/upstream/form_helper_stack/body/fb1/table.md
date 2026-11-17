Objects and Callgrind instructions per call, Ruby 4.0.7, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `text_field` | 28 | 22 | 120,058 | 116,668 | −2.8% |
| `checkbox` | 32 | 26 | 164,148 | 160,622 | −2.1% |
| `text_field, persisted` | 28 | 22 | 120,120 | 116,711 | −2.8% |
| `checkbox, persisted` | 32 | 26 | 164,136 | 160,606 | −2.2% |

Objects and Callgrind instructions per call, Ruby 4.0.7, YJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `text_field` | 29 | 23 | 66,235 | 63,216 | −4.6% |
| `checkbox` | 34 | 28 | 89,222 | 85,851 | −3.8% |
| `text_field, persisted` | 29 | 23 | 66,399 | 63,542 | −4.3% |
| `checkbox, persisted` | 34 | 28 | 89,231 | 85,996 | −3.6% |

benchmark-ips, Ruby 4.0.7, YJIT, best of 3 on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `text_field` | 107.5k i/s | 113.9k i/s | +6.0% |
| `checkbox` | 75.2k i/s | 79.4k i/s | +5.6% |
| `text_field, persisted` | 106.6k i/s | 115.3k i/s | +8.1% |
| `checkbox, persisted` | 76.5k i/s | 80.4k i/s | +5.2% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/form_helper_stack/body/fb1.
- base: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux], /home/user/workspace/rails-fb1-main at a5203b3d4d
- candidate: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux], /home/user/workspace/rails-fb1 at a2a13fc793
- interp text_field: instructions −2.8% with A/A 0.04% (base 120,080 / 120,037, candidate 116,668)
- interp checkbox: instructions −2.1% with A/A 0.10% (base 164,065 / 164,232, candidate 160,622)
- interp text_field, persisted: instructions −2.8% with A/A 0.09% (base 120,068 / 120,171, candidate 116,711)
- interp checkbox, persisted: instructions −2.2% with A/A 0.02% (base 164,120 / 164,152, candidate 160,606)
- yjit text_field: instructions −4.6% with A/A 0.35% (base 66,118 / 66,352, candidate 63,216)
- yjit checkbox: instructions −3.8% with A/A 0.04% (base 89,239 / 89,206, candidate 85,851)
- yjit text_field, persisted: instructions −4.3% with A/A 0.01% (base 66,395 / 66,403, candidate 63,542)
- yjit checkbox, persisted: instructions −3.6% with A/A 0.06% (base 89,260 / 89,202, candidate 85,996)
- ips text_field: +6.0% with A/A 4.93% (best base 110.1k / 104.8k, candidate 113.9k)
- ips checkbox: +5.6% with A/A 0.93% (best base 75.6k / 74.9k, candidate 79.4k)
- ips text_field, persisted: +8.1% with A/A 1.70% (best base 107.5k / 105.7k, candidate 115.3k)
- ips checkbox, persisted: +5.2% with A/A 2.17% (best base 75.6k / 77.3k, candidate 80.4k)
