Objects and Callgrind instructions per call, Ruby 4.0.9, no JIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `parse_nested_query (5 fields)` | 100 | 51 | 182,980 | 119,032 | −34.9% |
| `parse_cookies_header (session cookie + 1)` | 34 | 17 | 71,071 | 36,151 | −49.1% |
| `set_cookie_header (session cookie)` | 29 | 15 | 103,902 | 28,841 | −72.2% |

Objects and Callgrind instructions per call, Ruby 4.0.9, YJIT

| | Objects, main | Objects, branch | Instructions, main | Instructions, branch | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `parse_nested_query (5 fields)` | 100 | 51 | 153,509 | 86,397 | −43.7% |
| `parse_cookies_header (session cookie + 1)` | 34 | 17 | 67,846 | 32,307 | −52.4% |
| `set_cookie_header (session cookie)` | 29 | 15 | 100,837 | 25,883 | −74.3% |

benchmark-ips, Ruby 4.0.9, YJIT, best of 3 on one core

| | main | branch | Change |
| --- | ---: | ---: | ---: |
| `parse_nested_query (5 fields)` | 42.8k i/s | 81.7k i/s | +90.8% |
| `parse_cookies_header (session cookie + 1)` | 86.9k i/s | 199.0k i/s | +129.0% |
| `set_cookie_header (session cookie)` | 76.2k i/s | 242.8k i/s | +218.5% |

Record (not for the body): base = mean of two base runs; A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/rk3/body/RK3.
- base: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/up/rack-main at da90464e3f
- candidate: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux], /home/user/up/rack at 02087583dc
- interp parse_nested_query (5 fields): instructions −34.9% with A/A 0.03% (base 182,957 / 183,004, candidate 119,032)
- interp parse_cookies_header (session cookie + 1): instructions −49.1% with A/A 0.23% (base 70,989 / 71,153, candidate 36,151)
- interp set_cookie_header (session cookie): instructions −72.2% with A/A 0.02% (base 103,910 / 103,893, candidate 28,841)
- yjit parse_nested_query (5 fields): instructions −43.7% with A/A 0.07% (base 153,453 / 153,565, candidate 86,397)
- yjit parse_cookies_header (session cookie + 1): instructions −52.4% with A/A 0.61% (base 68,052 / 67,640, candidate 32,307)
- yjit set_cookie_header (session cookie): instructions −74.3% with A/A 0.00% (base 100,838 / 100,836, candidate 25,883)
- ips parse_nested_query (5 fields): +90.8% with A/A 3.41% (best base 42.1k / 43.6k, candidate 81.7k)
- ips parse_cookies_header (session cookie + 1): +129.0% with A/A 2.41% (best base 85.9k / 88.0k, candidate 199.0k)
- ips set_cookie_header (session cookie): +218.5% with A/A 5.35% (best base 74.2k / 78.3k, candidate 242.8k)
