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
state: ready
pr: 175
note: "our #171 is still open there without a response; tzinfo's last release is 2.0.6 (2023)"
passes:
  - {reviewer: skeptic, head: "2b2f4b458dadd3e132790d7c5bf934cee1820af6", date: 2026-11-05, verdict: changes, open: "code approved as is; body must-fix: tzinfo-data copies were identical objects, linked files unpushed; should-fix: scope of TimeWithZone callers, run spread, NaN/raising fields; all applied"}
  - {reviewer: skeptic, head: "2b2f4b458dadd3e132790d7c5bf934cee1820af6", date: 2026-11-05, verdict: nits, open: "body re-review: no must-fix; nits applied (Hash wording, zones with transitions); kept the ~210 per unequal comparison"}
  - {reviewer: sol, head: "2b2f4b458dadd3e132790d7c5bf934cee1820af6", date: 2026-11-05, verdict: nits, open: "code approved; body nits applied: custom overrides in the boundary, +210 scoped to the measured case, zones with transitions, same-period label, Rails pin, differential described precisely, body shortened"}
---

# Return early from TimezoneTransition#== for the same object

In zones with transitions, `period_for_local`, `periods_for_local` and `period_for_utc` return a new `TransitionsTimezonePeriod` on each call, but its start and end transitions are the zone's cached `TimezoneTransition` objects. Comparing two such periods for the same time therefore compares each transition with itself, offsets and timestamp field by field, which makes `[period].include?(equal_period)` cost about 11,400 instructions. Active Support does this in `TimeWithZone#change` and after the calculations it hands to `Time` through `method_missing`, such as `beginning_of_day` and `70.days.ago`, to keep the receiver's period (`periods.include?(period)`).

This returns `true` from `TimezoneTransition#==` when the argument is the same object, as `Array#include?` and `Hash` lookups already do. `eql?` is an alias of `==`, and `hash` is unchanged. Results only change for transitions no data source builds: a field that isn't equal to itself (such as `Float::NAN`) or whose `==` raises, or a subclass that overrides `equal?`, `kind_of?` or the field readers.

Callgrind instructions per call, Ruby 4.0.9 without a JIT, Active Support from Rails main (1e235cee11), America/Chicago from the system zoneinfo files. Master from a second checkout differs by at most 81 instructions per call.

| | master | this PR |
|---|---:|---:|
| `[period].include?(equal_period)` | 11,446 | 3,440 |
| `TimeWithZone#beginning_of_day`, same period | 43,701 | 35,695 |
| `70.days.ago(time_with_zone)`, same period | 66,626 | 58,621 |
| `[period].include?(different_period)` | 4,333 | 4,543 |

The measured comparison of two different periods costs 210 instructions more. `rake test` passes on Ruby 4.0.9, and the [Tests workflow](https://github.com/thomasklemm/tzinfo/actions/runs/42114287387) passes on my fork. A comparison of `==` and `eql?` before and after, with a check that equal transitions have equal hashes, over every transition up to 2100 of every zone (zoneinfo files and tzinfo-data) against itself, its neighbours, equal copies and non-nil values of other types gives identical results. The benchmark, the comparison, more cases and the method are [here](https://github.com/thomasklemm/lowrail/tree/bfeb3d349cf0d7464fe0c2830028c13f6037b5cc/bench/upstream/ruby_bench_dst).

I found this while looking at why the lobsters benchmark in ruby-bench does more work near a DST change.
