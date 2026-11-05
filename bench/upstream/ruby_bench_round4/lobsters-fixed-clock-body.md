This fixes `Time.now` in lobsters at 2026-07-01 12:00 UTC, during boot and in the benchmark block, so its allocations per iteration stop changing with the date it runs. #572 is an alternative with the clock near the fixture's dates; merge one of the two.

lobsters runs in US Central time. On main, when a lookback such as `70.days.ago` crosses a DST change, ActiveSupport looks up the zone period again: 1,476 extra lookups per pass on 2026-11-05, none in July. On Dec 25 and Jun 28 the logo changes too. With the clock fixed, the lookups come out the same on every run.

Objects per iteration on Ruby 4.0.9, with the system clock set to each date:

| | 2026-11-05 | 2026-12-25 | 2027-03-20 | 2027-06-28 | spread |
| --- | ---: | ---: | ---: | ---: | ---: |
| main | 657,758 | 657,025 | 657,811 | 648,912 | 1.37% |
| this PR | 648,831 | 648,883 | 648,864 | 648,871 | 0.01% |

Response bodies are byte-identical between runs on 2026-11-05 and 2027-01-20, apart from CSRF tokens. The harness keeps the real clock. `Date.today`, `DateTime.now`, `Time.new` without arguments and SQLite's `'now'` stay live. Cache entries and the session no longer age. `TRACK_AR_TIME` uses the monotonic clock.

For lobsters' history this is a one-time step of about −1.35% objects against runs whose lookbacks cross a DST change (roughly November to January and mid-March to mid-June).

<details><summary>How this was measured</summary>

Objects: `GC.stat(:total_allocated_objects)` around each iteration of the default harness, `WARMUP_ITRS=1 MIN_BENCH_ITRS=3`, mean of the 3 measured iterations, system clock set with libfaketime (`FAKETIME='@<date> 12:00:00' FAKETIME_DONT_FAKE_MONOTONIC=1`), [cg_harness.rb](https://github.com/thomasklemm/lowrail/blob/b625b533ed/bench/upstream/ruby_bench_round4/cg_harness.rb) with `CG_DUMP=0`. Responses: [raw_dump.rb](https://github.com/thomasklemm/lowrail/blob/b625b533ed/bench/upstream/ruby_bench_round4/raw_dump.rb) writes status, headers and body of all 114 requests in the pass after one warmup pass; [raw_cmp.rb](https://github.com/thomasklemm/lowrail/blob/b625b533ed/bench/upstream/ruby_bench_round4/raw_cmp.rb) blanks the `authenticity_token` values, the `csrf-token` meta tag and the random headers (session cookie, ETag, X-Request-Id, X-Runtime) and compares the rest byte for byte: 0 of 114 differ. Lookups: [dst_probe.rb](https://github.com/thomasklemm/lowrail/blob/b625b533ed/bench/upstream/ruby_bench_round4/dst_probe.rb).
</details>
