Title: Don't look the same local time up twice when a TimeWithZone crosses a DST change

When `70.days.ago`, `beginning_of_day`, `change` or another calendar method returns a time in a different period than the receiver, for example on the other side of a DST change, `TimeWithZone` asks TZInfo for the periods of the new local time and sees that the receiver's period isn't among them. It then passes nil to the constructor, which looks the same local time up in TZInfo again. Apps in a zone with DST pay this on every lookback that crosses a change, and a 70-day lookback crosses one on about 40% of days. In Ruby's lobsters benchmark, set to US Central time, a `/threads` page does 131 of these repeated lookups.

With this change, when the new time is a UTC `Time` with exactly one period, that period is passed on: the constructor would look up the same object in the same zone. Other values (`DateTime`s, times with an offset, zones without transitions) and gaps and overlaps keep the existing path, so callers get the same results.

| Ruby 4.0.9, Callgrind instructions | before | after |
| --- | ---: | ---: |
| lobsters `/threads` request, on 2026-11-05 | 106.6M | 103.5M (−2.9%) |
| `70.days.ago` across a DST change | 83,549 | 60,583 |
| `beginning_of_day` on the day clocks go back | 63,647 | 39,622 |
| `70.days.ago` without a DST change | 66,635 | 66,635 |

---
<sub>Found while checking ruby-bench's lobsters for date-dependent work with Lowrail ([notes](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ruby-bench-dst.md)).</sub>
