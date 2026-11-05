---
id: TZ1
repo: tzinfo/tzinfo
fork: thomasklemm/tzinfo
kind: perf
area: TimezoneTransition equality
reviewer: philr
branch: thomasklemm/equal-identity-shortcut
head: "2b2f4b458dadd3e132790d7c5bf934cee1820af6"
base: master
built_on: "1207d609"
depends_on: []
stacked_on:
alternative_of:
impact: "comparing equal periods 11,446 -> 3,440 instructions; same-period beginning_of_day/change/70.days.ago in Active Support 12-19% fewer instructions"
rank:
risky: false
state: in-review
pr:
note: "our #171 is still open there without a response; tzinfo's last release is 2.0.6 (2023)"
passes:
  - {reviewer: skeptic, head: "2b2f4b458dadd3e132790d7c5bf934cee1820af6", date: 2026-11-05, verdict: changes, open: "code approved as is; body must-fix: tzinfo-data copies were identical objects, linked files unpushed; should-fix: scope of TimeWithZone callers, run spread, NaN/raising fields; all applied"}
  - {reviewer: skeptic, head: "2b2f4b458dadd3e132790d7c5bf934cee1820af6", date: 2026-11-05, verdict: nits, open: "body re-review: no must-fix; nits applied (Hash wording, zones with transitions); kept the ~210 per unequal comparison"}
---

# Return early from TimezoneTransition#== for the same object

`[period].include?(other)` takes about 11,400 instructions when `other` is an equal period returned by a second lookup, although the start and end transitions of both periods are the same objects. `period_for_local`, `periods_for_local` and `period_for_utc` return a new `TransitionsTimezonePeriod` on each call, built from the time zone's cached transitions, and `TimezoneTransition#==` then compares both offsets and the timestamp of each transition with themselves. Active Support makes this comparison in `TimeWithZone#change` and after the calculations it hands to `Time` through `method_missing`, such as `beginning_of_day` and `70.days.ago`, to keep the receiver's period when the result is in it (`periods.include?(period)` in `#change` and `#wrap_with_time_zone`).

This returns `true` from `TimezoneTransition#==` when the argument is the same object, as `Array#include?` and `Hash` lookups already do. The result only changes for a transition with a field that is not equal to itself (such as `Float::NAN`) or whose `==` raises; no data source builds such transitions. `eql?` is an alias of `==`, and `hash` is unchanged. Comparing two different transitions costs about 210 instructions more, for the extra `equal?` call.

Callgrind instructions per call on Ruby 4.0.9 without a JIT, with GC disabled while measuring: (instructions for 2,000 calls − instructions for none) / 2,000, collected only inside the measured loop. The zone is America/Chicago from the system zoneinfo files, and Active Support is from Rails main. Each cell is the larger of two runs; runs of the same checkout differ by up to 81 instructions, and so does master from a second checkout.

| | master | this PR |
|---|---:|---:|
| `[period].include?(equal_period)` | 11,446 | 3,440 |
| `TimeWithZone#beginning_of_day` | 43,701 | 35,695 |
| `TimeWithZone#change(hour: 3)` | 42,439 | 34,434 |
| `70.days.ago(time_with_zone)`, in the same period | 66,626 | 58,621 |
| `70.days.ago(time_with_zone)`, across a DST change | 83,464 | 83,594 |
| `TimeWithZone#beginning_of_day` on the day the clocks go back | 63,560 | 63,798 |
| `[period].include?(different_period)` | 4,333 | 4,543 |

With tzinfo-data 1.2026.6 instead of the zoneinfo files, `beginning_of_day` goes from 44,275 to 36,399 instructions.

`==`, `eql?` and `hash` give the same results before and after for every transition up to 2100 of every zone, compared with itself, its neighbours, equal copies built with `TimezoneTransition.new` and values of other types, both with the zoneinfo files (549 zones with transitions) and with tzinfo-data (316 zones with their own transitions). `rake test` passes on Ruby 4.0.9, and the [Tests workflow](https://github.com/thomasklemm/tzinfo/actions/runs/42114287387) passes on my fork. The benchmark (`dst_micro.rb`) and the comparison (`tz_eq_compare.rb`) are [here](https://github.com/thomasklemm/lowrail/tree/bfeb3d349cf0d7464fe0c2830028c13f6037b5cc/bench/upstream/ruby_bench_dst).

I found this while looking at why the lobsters benchmark in ruby-bench does more work near a DST change.
