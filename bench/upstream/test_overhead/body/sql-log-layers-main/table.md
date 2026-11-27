Objects and Callgrind instructions per call, Ruby 4.0.10, no JIT

| | Objects, main | Objects, main-aa | Instructions, main | Instructions, main-aa | Change |
| --- | ---: | ---: | ---: | ---: | ---: |
| `full` | 97 | 97 | 394,621 | 394,595 | within noise |
| `full, app_subscribers` | 97 | 97 | 401,255 | 401,529 | +0.1% |
| `no_format` | 62 | 62 | 326,329 | 326,394 | +0.0% |
| `no_format, app_subscribers` | 62 | 62 | 332,992 | 332,876 | within noise |
| `no_emit` | 62 | 62 | 313,164 | 313,182 | within noise |
| `no_emit, app_subscribers` | 62 | 62 | 320,009 | 319,738 | −0.1% |
| `no_report` | 53 | 53 | 275,290 | 275,366 | within noise |
| `no_report, app_subscribers` | 53 | 53 | 275,295 | 275,261 | within noise |
| `no_event` | 50 | 50 | 259,401 | 259,283 | −0.0% |
| `no_event, app_subscribers` | 50 | 50 | 259,352 | 259,438 | within noise |
| `no_sub` | 46 | 46 | 243,882 | 243,909 | within noise |
| `no_sub, app_subscribers` | 46 | 46 | 243,925 | 243,829 | −0.0% |
| `info` | 40 | 40 | 221,894 | 221,859 | −0.0% |
| `info, app_subscribers` | 40 | 40 | 221,850 | 221,884 | within noise |

Record (not for the body): Callgrind and benchmark-ips cells take base = mean of two base runs, A/A = their spread. Raw output and commands in /home/user/workspace/repo/bench/upstream/test_overhead/body/sql-log-layers-main.
- base: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /tmp/pt2/rails-main at 2e299253f9
- candidate: ruby 4.0.10 (2026-11-19 revision a704b7cd95) +PRISM [x86_64-linux], /tmp/pt2/rails-mainb at 2e299253f9
- interp full: instructions −0.0% with A/A 0.01% (base 394,607 / 394,635, candidate 394,595): inside the A/A, no claim
- interp full, app_subscribers: instructions +0.1% with A/A 0.02% (base 401,289 / 401,221, candidate 401,529)
- interp no_format: instructions +0.0% with A/A 0.02% (base 326,299 / 326,359, candidate 326,394)
- interp no_format, app_subscribers: instructions −0.0% with A/A 0.08% (base 332,853 / 333,131, candidate 332,876): inside the A/A, no claim
- interp no_emit: instructions +0.0% with A/A 0.01% (base 313,145 / 313,183, candidate 313,182): inside the A/A, no claim
- interp no_emit, app_subscribers: instructions −0.1% with A/A 0.00% (base 320,004 / 320,014, candidate 319,738)
- interp no_report: instructions +0.0% with A/A 0.07% (base 275,193 / 275,387, candidate 275,366): inside the A/A, no claim
- interp no_report, app_subscribers: instructions −0.0% with A/A 0.07% (base 275,204 / 275,386, candidate 275,261): inside the A/A, no claim
- interp no_event: instructions −0.0% with A/A 0.01% (base 259,387 / 259,415, candidate 259,283)
- interp no_event, app_subscribers: instructions +0.0% with A/A 0.04% (base 259,296 / 259,409, candidate 259,438): inside the A/A, no claim
- interp no_sub: instructions +0.0% with A/A 0.04% (base 243,834 / 243,931, candidate 243,909): inside the A/A, no claim
- interp no_sub, app_subscribers: instructions −0.0% with A/A 0.00% (base 243,931 / 243,920, candidate 243,829)
- interp info: instructions −0.0% with A/A 0.00% (base 221,894 / 221,893, candidate 221,859)
- interp info, app_subscribers: instructions +0.0% with A/A 0.03% (base 221,812 / 221,887, candidate 221,884): inside the A/A, no claim
