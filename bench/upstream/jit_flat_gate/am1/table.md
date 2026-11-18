Objects and Callgrind instructions per call, Ruby 4.0.7, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `errors[:title]` | 5 | 1 | 4,937 | 2,040 | −58.7% |
| `errors["title"]` | 6 | 2 | 5,544 | 2,526 | −54.4% |
| `text_field` | 28 | 24 | 119,950 | 116,867 | −2.6% |

Objects and Callgrind instructions per call, Ruby 4.0.7, YJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `errors[:title]` | 5 | 1 | 3,101 | 1,231 | −60.3% |
| `errors["title"]` | 6 | 2 | 3,745 | 1,464 | −60.9% |
| `text_field` | 29 | 25 | 66,273 | 63,971 | −3.5% |

benchmark-ips, Ruby 4.0.7, YJIT, best of 3 on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `errors[:title]` | 2.61M i/s | 10.28M i/s | +293.3% |
| `errors["title"]` | 2.09M i/s | 5.96M i/s | +184.8% |
| `text_field` | 110.3k i/s | 110.7k i/s | within noise |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/jit_flat_gate/am1.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux], /home/user/workspace/rails-am1-main at 4f00fbc946
- candidate: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux], /home/user/workspace/rails-am1 at 8cef505ecc
- interp errors[:title]: instructions −58.7% with A/A 0.00% (base 4,937 / 4,937, candidate 2,040)
- interp errors["title"]: instructions −54.4% with A/A 0.00% (base 5,544 / 5,544, candidate 2,526)
- interp text_field: instructions −2.6% with A/A 0.24% (base 119,807 / 120,092, candidate 116,867)
- yjit errors[:title]: instructions −60.3% with A/A 0.00% (base 3,101 / 3,101, candidate 1,231), JIT-flat in 6 windows
- yjit errors["title"]: instructions −60.9% with A/A 0.00% (base 3,745 / 3,745, candidate 1,464), JIT-flat in 6 windows
- yjit text_field: instructions −3.5% with A/A 0.37% (base 66,396 / 66,150, candidate 63,971), JIT-flat in 6 windows
- ips errors[:title]: +293.3% with A/A 4.09% (best base 2.67M / 2.56M, candidate 10.28M), JIT-flat in 9 windows
- ips errors["title"]: +184.8% with A/A 1.29% (best base 2.08M / 2.11M, candidate 5.96M), JIT-flat in 9 windows
- ips text_field: +0.4% with A/A 2.19% (best base 111.5k / 109.1k, candidate 110.7k), JIT-flat in 9 windows: inside the A/A, no claim
