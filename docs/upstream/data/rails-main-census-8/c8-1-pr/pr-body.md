`asset_path` (and through it `image_tag`, `stylesheet_link_tag`, `javascript_include_tag` and `asset_url`) checks every source against `URI_REGEXP` to leave URLs alone. For the usual relative source, such as `"application.css"`, the check fails, and this failing match is a large part of `asset_path`'s cost: the pattern is case-insensitive and repeats the `^` anchor in each of its three alternatives. The `match?` alone runs 9,580 instructions on `"application.css"` before this change and 5,943 after (interpreter, Ruby 4.0.9).

This PR moves the anchor in front of the alternation: `^(?:A|B|C)` instead of `^A|^B|^C`. The alternatives and their order stay the same, and the group does not capture, so the pattern matches the same strings at the same positions. On Ruby 4.0.9 I compared the old and new pattern for every string of up to 6 characters over an alphabet that includes a newline (8.1 million strings) and for over 300,000 random strings, including multi-line strings, Unicode case-folding characters, invalid UTF-8 and other encodings. I found no difference in `match?`, match offsets or exceptions. The three users of the constant (`asset_path`, `compute_asset_host` and Action Text's `RemoteImage.remote_url?`) only call `match?`.

| Per call | Objects | Time, interpreter | Time, YJIT | Instructions, interpreter | Instructions, YJIT |
| --- | ---: | ---: | ---: | ---: | ---: |
| `asset_path("application.css")`, main | 5 | 2,621 ns | 1,883 ns | 34,778 | 25,927 |
| this PR (change from main) | 5 | 2,296 ns (−12.4%) | 1,608 ns (−14.6%) | 31,134 (−10.5%) | 22,306 (−14.0%) |
| main, run again (change from the first run) | 5 | −1.1% | −0.9% | +0.04% | +0.01% |
| `stylesheet_link_tag("application")`, main | 24 | 7,932 ns | 4,760 ns | 88,765 | 56,968 |
| this PR (change from main) | 24 | 7,829 ns (−1.3%) | 4,655 ns (−2.2%) | 85,475 (−3.7%) | 53,798 (−5.6%) |
| main, run again (change from the first run) | 24 | +1.9% | −1.0% | +0.20% | +0.26% |
| `asset_path("https://cdn.example.com/x.js")`, main | 1 | 216 ns | 168 ns | 3,561 | 2,270 |
| this PR (change from main) | 1 | 224 ns (+3.8%) | 168 ns (−0.2%) | 3,525 (−1.0%) | 2,292 (+1.0%) |
| main, run again (change from the first run) | 1 | +1.0% | −4.7% | 0.00% | +0.22% |

For `asset_path` with a relative source, the time and instruction savings are larger than the difference between the two runs of main. For `stylesheet_link_tag`, the instructions drop by 3.7% and 5.6%, but the time differences (−1.3% and −2.2%) are about the size of the difference between the two runs of main (+1.9% and −1.0%), so I can't claim them as a time saving.

For an absolute URL, the regexp itself costs the same in both forms (2,163 instructions per `match?` on the interpreter, before and after). The ±1% instruction changes in the URL row come from outside the regexp. Under YJIT the gap shrinks as the call count grows (+130 per call at 3,000 calls, +20 at 20,000, +4 at 60,000), so it is one-time compile work that lands inside the measurement, not a per-call cost. The interpreted time was +3.8% against +1.0% between the two runs of main in this measurement, and +2.6% against −4.0% in a repeat, so I read it as noise.

Times are the best of 7 rounds. In each round, main, main again and this PR each run in their own process, in a rotating order. Each process is pinned to one CPU, warms up with 20,500 calls, then times 200,000 calls with GC enabled. Instructions per call are Callgrind's count for 20,000 calls minus its count for 0 calls, divided by 20,000, with GC disabled. Objects are allocations per call. Everything ran on Ruby 4.0.9 against Rails main d795dac950, on an x86-64 Linux cloud VM ([scripts](https://github.com/thomasklemm/lowrail/tree/main/bench/upstream/census8)).

I found this line in a CPU census made with Lowrail, my research project ([census](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/rails-main-census-8.md)). For it, I counted the instructions that Rails main executes per source line in 251 workloads from 20 open-source apps. 17 of the apps run this line in at least one workload. In the 8 apps I measured again with this change (interpreter, Callgrind), the line's instructions per request drop by 35–47%. The line is about 0.23% of all instructions, so a whole request runs about 0.1% fewer instructions, which is within noise.
