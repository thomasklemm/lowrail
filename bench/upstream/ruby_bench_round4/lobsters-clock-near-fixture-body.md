Alternative to #571: also fixes the clock, but near the fixture's dates, so the 16 time-filtered requests render stories. Merge one of the two.

The fixture's stories are from 2023-07-18, so on main /active, /recent and /top?length=1d|1w|1y (16 of 114 requests per iteration) render empty lists. This fixes `Time.now` at 2023-07-19 01:00 UTC, about 15 hours after the stories, during boot and in the benchmark block. As in #571, allocations per iteration then stop changing with the date (0.01% across four dates, against 1.37% on main).

/top never listed a story on main: `DATETIME('now', '- 1 DAY')` is NULL, because SQLite rejects `- 1` and has no WEEK. The modifier is now `-1 DAY`, with weeks as 7 days, the arithmetic upstream lobsters' IntervalHelper uses. The deliberate departure from upstream is that the query binds `Time.current` instead of SQLite's `'now'`, so /top follows the fixed clock.

Per pass after one warmup pass, Ruby 4.0.9:

| | stories in lists | KB | objects |
| --- | ---: | ---: | ---: |
| main | 145 | 3,709 | 658,492 |
| #571 | 145 | 3,709 | 649,706 |
| this PR | 545 | 4,771 | 950,426 |

The 16 requests render 25 stories each. Since stories and comments are hours old, pages also take the branches for recent content: reply and flag links, delete instead of disown, comment scores under 36 hours shown as `~`, one user marked as new. This is a deliberate workload change of about +44% objects per iteration against main (+46% against #571).

Response bodies are byte-identical between runs on 2026-11-05 and 2027-01-20, apart from CSRF tokens. The same live clocks and non-aging caches as in #571 apply.

<details><summary>How this was measured</summary>

Per pass: [route_dump.rb](https://github.com/thomasklemm/lowrail/blob/b625b533ed/bench/upstream/ruby_bench_round4/route_dump.rb) records status, bytes, `<li id="story_` count and allocated objects of each request in the pass after one warmup pass; [route_table.rb](https://github.com/thomasklemm/lowrail/blob/b625b533ed/bench/upstream/ruby_bench_round4/route_table.rb) sums them. Date spread and responses: as in #571's details.
</details>
