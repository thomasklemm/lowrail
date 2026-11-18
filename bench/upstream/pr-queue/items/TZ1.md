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
note: "2026-11-18 (rules review): body cleaned per Leave out, thermos-sol body-only approve (a26f9b16), PATCHed live. 2026-11-18 (rules review, docs/upstream/rules-review-2026-11-18-ecosystem.md): body without SHA, rake/CI and differential lines, unposted; code unchanged. our #171 is still open there without a response; tzinfo's last release is 2.0.6 (2023)"
passes:
  - {reviewer: skeptic, head: "2b2f4b458dadd3e132790d7c5bf934cee1820af6", date: 2026-11-05, verdict: changes, open: "code approved as is; body must-fix: tzinfo-data copies were identical objects, linked files unpushed; should-fix: scope of TimeWithZone callers, run spread, NaN/raising fields; all applied"}
  - {reviewer: skeptic, head: "2b2f4b458dadd3e132790d7c5bf934cee1820af6", date: 2026-11-05, verdict: nits, open: "body re-review: no must-fix; nits applied (Hash wording, zones with transitions); kept the ~210 per unequal comparison"}
  - {reviewer: sol, head: "2b2f4b458dadd3e132790d7c5bf934cee1820af6", date: 2026-11-05, verdict: nits, open: "code approved; body nits applied: custom overrides in the boundary, +210 scoped to the measured case, zones with transitions, same-period label, Rails pin, differential described precisely, body shortened"}
  - {reviewer: claude-code, head: "2b2f4b458dadd3e132790d7c5bf934cee1820af6", orb: T-01a1ded6-4813-7653-94e8-9b8375d70deb, date: 2026-11-15, verdict: approve, open: "Footer cleanup (DECISIONS 4eb18bee, Fixed parts): reviewed the old and new body word diff. Only the <sub> footer and Lowrail links are removed and, where useful, one how-found clause is added; numbers, tables, scripts and wording unchanged; no internal labels or private names. No clause added (the body already says where the problem shows up, or the clause was already there); link cut."}
  - {reviewer: thermos-sol, orb: "T-01a1ee72-6d4f-7377-b2ff-f1240d8bebeb", head: "2b2f4b458dadd3e132790d7c5bf934cee1820af6", date: 2026-11-18, verdict: approve, open: "body only; live/generated bodies, source, record and upstream template checked; both rubrics self-performed, no delegation. Cached-transition identity and pathological-field boundary agree with source; usage and instruction record support table without tested-version or command prose. No body correction needed; not a new code approval."}
---

# Return early from TimezoneTransition#== for the same object

In zones with transitions, `period_for_local`, `periods_for_local` and `period_for_utc` return a new `TransitionsTimezonePeriod` on each call, but its start and end transitions are the zone's cached `TimezoneTransition` objects. Comparing two such periods for the same time therefore compares each transition with itself, offsets and timestamp field by field, which makes `[period].include?(equal_period)` cost about 11,400 instructions. Active Support does this in `TimeWithZone#change` and after the calculations it hands to `Time` through `method_missing`, such as `beginning_of_day` and `70.days.ago`, to keep the receiver's period (`periods.include?(period)`).

This returns `true` from `TimezoneTransition#==` when the argument is the same object, as `Array#include?` and `Hash` lookups already do. `eql?` is an alias of `==`, and `hash` is unchanged. Results only change for transitions no data source builds: a field that isn't equal to itself (such as `Float::NAN`) or whose `==` raises, or a subclass that overrides `equal?`, `kind_of?` or the field readers.

Callgrind instructions per call, Ruby 4.0, no JIT, America/Chicago:

| | master | this PR |
|---|---:|---:|
| `[period].include?(equal_period)` | 11,446 | 3,440 |
| `TimeWithZone#beginning_of_day`, same period | 43,701 | 35,695 |
| `70.days.ago(time_with_zone)`, same period | 66,626 | 58,621 |
| `[period].include?(different_period)` | 4,333 | 4,543 |

Comparing two different periods costs 210 instructions more. I found this while looking at why the lobsters benchmark in ruby-bench does more work near a DST change.
