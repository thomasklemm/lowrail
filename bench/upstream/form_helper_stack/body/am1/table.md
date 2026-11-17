Objects and Callgrind instructions per call, Ruby 4.0.7, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `errors[:title]` | 5 | 1 | 4,937 | 2,040 | −58.7% |
| `errors["title"]` | 6 | 2 | 5,544 | 2,526 | −54.4% |
| `text_field` | 28 | 24 | 120,009 | 116,668 | −2.8% |

Objects and Callgrind instructions per call, Ruby 4.0.7, YJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `errors[:title]` | 5 | 1 | 3,574 | 1,684 | −52.9% |
| `errors["title"]` | 6 | 2 | 4,228 | 1,938 | −54.2% |
| `text_field` | 29 | 25 | 66,360 | 64,091 | −3.4% |

benchmark-ips, Ruby 4.0.7, YJIT, best of 3 on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `errors[:title]` | 2.37M i/s | 10.11M i/s | +325.8% |
| `errors["title"]` | 1.89M i/s | 5.67M i/s | +200.1% |
| `text_field` | 104.6k i/s | 112.8k i/s | +7.9% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/form_helper_stack/body/am1.
- base: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux], /home/user/workspace/rails-am1-main at 4f00fbc946
- candidate: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux], /home/user/workspace/rails-am1 at 8cef505ecc
- interp errors[:title]: instructions −58.7% with A/A 0.00% (base 4,937 / 4,937, candidate 2,040)
- interp errors["title"]: instructions −54.4% with A/A 0.00% (base 5,545 / 5,544, candidate 2,526)
- interp text_field: instructions −2.8% with A/A 0.01% (base 120,012 / 120,005, candidate 116,668)
- yjit errors[:title]: instructions −52.9% with A/A 0.07% (base 3,575 / 3,573, candidate 1,684)
- yjit errors["title"]: instructions −54.2% with A/A 0.38% (base 4,220 / 4,236, candidate 1,938)
- yjit text_field: instructions −3.4% with A/A 0.63% (base 66,150 / 66,569, candidate 64,091)
- ips errors[:title]: +325.8% with A/A 0.51% (best base 2.38M / 2.37M, candidate 10.11M)
- ips errors["title"]: +200.1% with A/A 1.91% (best base 1.87M / 1.91M, candidate 5.67M)
- ips text_field: +7.9% with A/A 4.70% (best base 107.0k / 102.1k, candidate 112.8k)
