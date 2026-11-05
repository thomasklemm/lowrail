Alternative to #571: also fixes the clock, but near the fixture's dates, so the 16 time-filtered requests render stories. Merge one of the two.

The fixture's stories are from 2023-07-18, so on main /active, /recent and /top?length=1d|1w|1y (16 of 114 requests per iteration) render empty lists. This fixes `Time.now` at 2023-07-19 01:00 UTC, about 15 hours after the stories, during boot and in the benchmark block. Across the four tested dates (2026-11-05, 2026-12-25, 2027-03-20, 2027-06-28), allocations per iteration varied by 0.005%, against 1.37% on main.

/top never listed a story on main: `DATETIME('now', '- 1 DAY')` is NULL, because SQLite rejects `- 1` and has no WEEK. The modifier is now `-1 DAY`, with weeks as 7 days, as in upstream lobsters. The deliberate departure from upstream is that the query binds `Time.current` instead of SQLite's `'now'`, so /top follows the fixed clock.

Per pass after one warmup pass, Ruby 4.0.9:

| | stories in lists | KB | objects |
| --- | ---: | ---: | ---: |
| main | 145 | 3,709 | 658,492 |
| #571 | 145 | 3,709 | 649,706 |
| this PR | 545 | 4,771 | 950,426 |

The 16 requests render 25 stories each. Since stories and comments are hours old, pages also take the branches for recent content: reply and flag links, delete instead of disown, comment scores under 36 hours shown as `~`, one user marked as new. This is a deliberate workload change of about +44% objects per iteration against main (+46% against #571).

Response bodies are byte-identical between runs on 2026-11-05 and 2027-01-20, apart from CSRF tokens. The harness keeps the real clock. `Date.today`, `DateTime.now` and `Time.new` without arguments stay live. Cache entries and the session no longer age. `TRACK_AR_TIME` uses the monotonic clock.

<details><summary>How this was measured</summary>

Per pass: [route_dump.rb](https://github.com/thomasklemm/lowrail/blob/b625b533ed/bench/upstream/ruby_bench_round4/route_dump.rb) records status, bytes, `<li id="story_` count and allocated objects of each request in the pass after one warmup pass; [route_table.rb](https://github.com/thomasklemm/lowrail/blob/b625b533ed/bench/upstream/ruby_bench_round4/route_table.rb) sums them. Date spread: `GC.stat(:total_allocated_objects)` around each iteration of the default harness, `WARMUP_ITRS=1 MIN_BENCH_ITRS=3`, mean of the 3 measured iterations, system clock set with libfaketime (`FAKETIME='@<date> 12:00:00' FAKETIME_DONT_FAKE_MONOTONIC=1`), [cg_harness.rb](https://github.com/thomasklemm/lowrail/blob/b625b533ed/bench/upstream/ruby_bench_round4/cg_harness.rb) with `CG_DUMP=0`. Responses: [raw_dump.rb](https://github.com/thomasklemm/lowrail/blob/b625b533ed/bench/upstream/ruby_bench_round4/raw_dump.rb) writes status, headers and body of all 114 requests in the pass after one warmup pass; [raw_cmp.rb](https://github.com/thomasklemm/lowrail/blob/b625b533ed/bench/upstream/ruby_bench_round4/raw_cmp.rb) blanks the `authenticity_token` values, the `csrf-token` meta tag and the random headers (session cookie, ETag, X-Request-Id, X-Runtime) and compares the rest byte for byte: 0 of 114 differ.
</details>
