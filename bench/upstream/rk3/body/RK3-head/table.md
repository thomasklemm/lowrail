Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `parse_nested_query (5 fields)` | 100 | 51 | 184,701 | 121,136 | −34.4% |
| `parse_cookies_header (session cookie + 1)` | 34 | 17 | 71,426 | 36,470 | −48.9% |
| `set_cookie_header (session cookie)` | 29 | 15 | 104,075 | 28,580 | −72.5% |

Objects and Callgrind instructions per call, Ruby 4.0.9, YJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `parse_nested_query (5 fields)` | 100 | 51 | 151,429 | 87,144 | −42.5% |
| `parse_cookies_header (session cookie + 1)` | 34 | 17 | 67,445 | 32,392 | −52.0% |
| `set_cookie_header (session cookie)` | 29 | 15 | 100,380 | 25,281 | −74.8% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/rk3/body/RK3-head.
- JIT-flat: compiled_iseq_count, compiled_block_count, invalidation_count unchanged in every measured window (each Callgrind N and N = 0 run; each benchmark-ips report from `running` to its last timed interval)
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/up/rack-main at da90464e3f
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/up/rack at c0a8e93011
- interp parse_nested_query (5 fields): instructions −34.4% with A/A 0.18% (base 184,866 / 184,536, candidate 121,136)
- interp parse_cookies_header (session cookie + 1): instructions −48.9% with A/A 0.11% (base 71,386 / 71,466, candidate 36,470)
- interp set_cookie_header (session cookie): instructions −72.5% with A/A 0.24% (base 103,951 / 104,199, candidate 28,580)
- yjit parse_nested_query (5 fields): instructions −42.5% with A/A 0.11% (base 151,514 / 151,344, candidate 87,144), JIT-flat in 6 windows
- yjit parse_cookies_header (session cookie + 1): instructions −52.0% with A/A 0.02% (base 67,452 / 67,438, candidate 32,392), JIT-flat in 6 windows
- yjit set_cookie_header (session cookie): instructions −74.8% with A/A 0.09% (base 100,424 / 100,336, candidate 25,281), JIT-flat in 6 windows
