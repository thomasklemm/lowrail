Objects and Callgrind instructions per call, Ruby 4.1.0dev, no JIT

| | Objects, main | Objects, to1 | Instructions, main | Instructions, to1 | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `text_field_tag` | 7 | 6 | 57,293 | 56,685 | −1.1% |
| `submit_tag` | 13 | 12 | 66,517 | 65,837 | −1.0% |
| `tag.input` | 4 | 3 | 25,437 | 25,152 | −1.1% |
| `f.text_field` | 17 | 16 | 101,290 | 101,526 | +0.2% |
| `f.check_box` | 20 | 18 | 140,208 | 138,992 | −0.9% |

Objects and Callgrind instructions per call, Ruby 4.1.0dev, ZJIT

| | Objects, main | Objects, to1 | Instructions, main | Instructions, to1 | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `text_field_tag` | 7 | 6 | 32,491 | 32,216 | −0.8% |
| `submit_tag` | 13 | 12 | 38,620 | 38,203 | −1.1% |
| `tag.input` | 4 | 3 | 14,614 | 14,222 | −2.7% |
| `f.text_field` | 18 | 17 | 52,178 | 52,506 | +0.6% |
| `f.check_box` | 22 | 20 | 74,409 | 73,615 | −1.1% |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/lead-sweep-2026-11-27/to1-zjit.
- JIT-flat: compiled_iseq_count, failed_iseq_count, compiled_side_exit_count, invalidation_time_ns unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval; every timed wall window)
- base: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/src/w-main at 2e299253f9
- candidate: ruby 4.1.0dev (2026-11-27T16:40:23Z master 0d399335b7) +PRISM [x86_64-linux], /home/user/src/w-to1 at c7ebf689ed
- interp text_field_tag: instructions −1.1% with A/A 0.12% (base 57,328 / 57,258, candidate 56,685)
- interp submit_tag: instructions −1.0% with A/A 0.05% (base 66,500 / 66,534, candidate 65,837)
- interp tag.input: instructions −1.1% with A/A 0.16% (base 25,458 / 25,416, candidate 25,152)
- interp f.text_field: instructions +0.2% with A/A 0.03% (base 101,307 / 101,273, candidate 101,526)
- interp f.check_box: instructions −0.9% with A/A 0.22% (base 140,360 / 140,055, candidate 138,992)
- zjit text_field_tag: instructions −0.8% with A/A 0.23% (base 32,529 / 32,452, candidate 32,216), JIT-flat in 6 windows
- zjit submit_tag: instructions −1.1% with A/A 0.31% (base 38,560 / 38,680, candidate 38,203), JIT-flat in 6 windows
- zjit tag.input: instructions −2.7% with A/A 0.11% (base 14,606 / 14,622, candidate 14,222), JIT-flat in 6 windows
- zjit f.text_field: instructions +0.6% with A/A 0.48% (base 52,304 / 52,051, candidate 52,506), JIT-flat in 6 windows
- zjit f.check_box: instructions −1.1% with A/A 0.19% (base 74,480 / 74,338, candidate 73,615), JIT-flat in 6 windows
