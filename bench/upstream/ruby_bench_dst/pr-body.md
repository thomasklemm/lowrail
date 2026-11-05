Title: Don't look the same local time up twice when a TimeWithZone crosses a DST change

When `70.days.ago`, `beginning_of_day`, `change` or other calendar methods return a time in a different period than the receiver, for example on the other side of a DST change, `TimeWithZone` asks TZInfo for the periods of the new local time, finds that the receiver's period isn't among them, and passes nil to the constructor. The constructor then looks the same local time up in TZInfo again. Apps in a zone with DST pay this on every lookback that crosses a change: a 70-day lookback crosses one on about 40% of days. Ruby's lobsters benchmark, set to US Central time, does 1,476 of these repeated lookups per pass, about 1.4% of its allocations.

This passes the period on when the new time is a `Time` with exactly one period, which is the period the constructor would find. Gaps, overlaps and `DateTime` values, which TZInfo reads by their Julian day, keep the existing path, so results are the same as before. Zones without transitions, such as UTC, now also return their shared period from `TimeZone#periods_for_local`, as `period_for_utc` and `period_for_local` already do.

| Callgrind instructions per call, Ruby 4.0.9 | before | after |
| --- | ---: | ---: |
| `70.days.ago` across a DST change | 83,469 | 60,140 |
| `beginning_of_day` on the day clocks go back | 63,620 | 39,126 |
| `70.days.ago` in UTC | 45,446 | 36,486 |
| `70.days.ago` without a DST change | 66,554 | 66,617 |

---
<sub>Found while checking ruby-bench's lobsters for date-dependent work with Lowrail ([notes](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ruby-bench-dst.md)).</sub>
