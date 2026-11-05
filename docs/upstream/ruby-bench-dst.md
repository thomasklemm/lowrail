# Why lobsters does 1.35% more work near a DST change

Follow-up to the ruby-bench determinism audit ([round 4](ruby-bench-improvements.md)): on ruby-bench main `ad63bf8`
with Ruby 4.0.9, lobsters allocates about 657.9K objects per iteration on dates such as 2026-11-05 and about 649.0K
on others. This record finds where that work comes from, who else pays it, and a fix. Status as of 2026-11-05.
Scripts and raw numbers: [`bench/upstream/ruby_bench_dst/`](../../bench/upstream/ruby_bench_dst/).

## Answer

The cost is in **Active Support**, not tzinfo or Ruby. `TimeWithZone` looks the same local time up in tzinfo twice
whenever the result of a calendar operation (`70.days.ago`, `beginning_of_day`, `change`, `+ 1.month`) lands in a
different period than its receiver, which is what crossing a DST change means. lobsters runs in US Central time and
uses 7- to 90-day lookbacks, so on dates where those lookbacks cross a change it does 1,476 extra tzinfo lookups per
pass, about 6 objects and 24K instructions each.

A small fix in Active Support removes the second lookup for `Time` results and gives identical results:
branch [`thomasklemm/twz-reuse-local-period`](https://github.com/thomasklemm/rails/tree/thomasklemm/twz-reuse-local-period)
at `6993c9b20b` on rails/rails main `1e235cee11` (the first head, `4779066d80`, was wrong for Julian-calendar
`DateTime`s; see [round 2](#round-2-sol-and-astra-julian-datetimes)). With it, lobsters on 2026-11-05 allocates the same as on a date
without crossings (648.9K), and a lookback across a DST change costs 29–39% fewer instructions in micro-benchmarks.
Nothing is opened upstream.

## Mechanism

Verified against the source (Rails main `1e235cee11`, 8-1-stable `6e09124217`, tzinfo 2.0.6) and with counters.

1. `Duration#ago`, `TimeWithZone#advance` with days/weeks/months/years, `+`/`-` with a variable Duration, and
   `beginning_of_day` and friends go through `TimeWithZone#method_missing`
   ([`time_with_zone.rb:619`](https://github.com/rails/rails/blob/1e235cee11/activesupport/lib/active_support/time_with_zone.rb#L619-L623)),
   which calls the method on the local `Time` and passes the result to `wrap_with_time_zone`
   ([`:661-670`](https://github.com/rails/rails/blob/1e235cee11/activesupport/lib/active_support/time_with_zone.rb#L661-L670)).
   `change` has the same code inline ([`:453-455`](https://github.com/rails/rails/blob/1e235cee11/activesupport/lib/active_support/time_with_zone.rb#L453-L455)).
2. `wrap_with_time_zone` asks tzinfo for **all** periods of the new local time (`time_zone.periods_for_local`, lookup 1)
   and passes the receiver's period on only if it is among them:
   `self.class.new(nil, time_zone, time, periods.include?(period) ? period : nil)`. This is Andrew White's
   b594492870 (2014, #12163): during the repeated hour, keep the receiver's offset instead of `period_for_local`'s
   default.
3. With nil, the constructor runs `get_period_and_ensure_valid_local_time`
   ([`:638-649`](https://github.com/rails/rails/blob/1e235cee11/activesupport/lib/active_support/time_with_zone.rb#L638-L649)),
   which converts the time with `Time.utc(...)` if needed and calls `TimeZone#period_for_local`
   ([`values/time_zone.rb:640`](https://github.com/rails/rails/blob/1e235cee11/activesupport/lib/active_support/values/time_zone.rb#L640-L642)),
   which calls `TZInfo::Timezone#period_for_local` → `DataTimezone#periods_for_local` → 
   `TransitionsDataTimezoneInfo#periods_for_local` (lookup 2, for the same wall clock) and picks one.

So the cache only "hits" when the receiver's period contains the new time. It misses when the result is in another
period: on the other side of a DST change, or after `change(zone:)` to another zone. In the miss case lookup 1 has
usually already found exactly one period, which is the one lookup 2 returns again.

**tzinfo's own cache is used and is not the problem.** The zone's transitions are read once (one
`ZoneinfoReader#read` on first use, none in the next 10,000 lookups) and the `Timezone`/info objects are shared. What
each lookup costs is the search itself and its fresh result objects: a `Timestamp` (`timestamp.rb:193`, plus two
`Rational`s at `:208` when the time has sub-seconds, as `Time.now` does), the result `Array`
(`transitions_data_timezone_info.rb:88`) and a new `TransitionsTimezonePeriod` (`:101`) built from the cached
transitions. tzinfo has no per-time result cache and needs none here; Ruby itself does nothing unusual (all the
extra objects are created in Ruby code in tzinfo).

### lobsters, counted

`dst_harness.rb` with `COUNT=1` counts calls over one pass after two warmups (ruby-bench `ad63bf8`, Rails 8.1.4.1,
tzinfo 2.0.6, clock moved with libfaketime, fixed heap):

| date | `TimeZone#periods_for_local` (lookup 1) | `TimeZone#period_for_local` (lookup 2) | tzinfo lookups | allocations / pass |
| --- | ---: | ---: | ---: | ---: |
| 2026-11-05, Rails 8.1.4.1 | 1,482 | 1,476 | 2,958 | 657,759 |
| 2026-11-05, with the fix | 1,482 | 0 | 1,482 | 648,866 |
| 2027-06-28, Rails 8.1.4.1 | 1,482 | 0 | 1,482 | 648,851 |

This confirms the audit's 1,476 refetches per pass (8,893 objects, about 6 per refetch). The callers are lobsters'
`N.days.ago` lookbacks (`User#is_new?` 70 days, `Story` 90, `Comment` 7/14) under
`config.time_zone = "Central Time (US & Canada)"`.

## Cost per lookup and per operation

Callgrind instructions per call, Ruby 4.0.9 interpreter, GC off, Ir(N=2000) − Ir(0) / 2000 (`ir.sh`, `dst_micro.rb`),
two processes each; the two repeats differ by at most 81 instructions. Central time, receiver 2026-11-05 12:00 CST
(crossing) or 2027-06-28 CDT (same period).

| operation | main `1e235cee11` | fix | 8-1-stable `6e09124217` | 8-1 + fix | objects main → fix |
| --- | ---: | ---: | ---: | ---: | --- |
| `70.days.ago`, same period | 66,638 | 66,617 | 69,456 | 69,712 | 18 → 18 |
| `70.days.ago`, crosses DST | 83,465 | 59,713 (−28%) | 85,385 | 63,137 (−26%) | 22 → 18 |
| `1.day.ago` from the day clocks went back | 85,736 | 60,848 (−29%) | 87,252 | 64,031 (−27%) | 22 → 18 |
| `beginning_of_day`, same period | 43,720 | 43,813 | 44,823 | 44,973 | 7 → 7 |
| `beginning_of_day` on the day clocks went back | 63,644 | 38,671 (−39%) | 63,314 | 40,028 (−37%) | 11 → 7 |
| `change(month: 8)` from November | 62,082 | 38,268 (−38%) | 62,315 | 40,012 (−36%) | 12 → 8 |
| `70.days.ago`, UTC zone | 45,446 | 36,567 (−20%) | 50,223 | – | 17 → 15 |
| `70.days.ago`, Tokyo (no DST) | 58,024 | 58,168 | 61,732 | 61,907 | 18 → 18 |

(8-1 + fix is the same two `time_with_zone.rb` lines without the `periods_for_local` shortcut, so it has no UTC
row; the UTC gain on main comes from that shortcut, which builds on main's fbaf5cd9d0 constant-period memo, not in
8-1-stable.)

tzinfo alone: `Timezone#period_for_local` 24,903, `#periods_for_local` 20,677, of which `Timestamp.for` 5,249 and
the transitions search 15,814; `period_for_utc` 19,512. A crossing wrap on main pays lookup 2 (about 17K) plus an
`include?` that compares two non-identical periods (about 11K, see below).

### lobsters

Callgrind instructions for two measured passes after three warmups (`lob.sh`, `CG=1`, Ruby 4.0.9 interpreter, fixed
heap), with the two changed methods redefined from the 8-1-stable worktrees after boot:

| clock | Rails 8.1.4.1 | with the fix | allocations / pass |
| --- | ---: | ---: | --- |
| 2026-11-05 (libfaketime) | 7,226,985,733 / 7,226,916,332 | 7,156,345,321 / 7,085,899,203 | 657,952 / 657,922 → 649,117 / 649,162 |
| real clock, 2026-11-05 | 7,156,830,505 / 7,225,641,692 | 7,085,654,769 / 7,087,008,096 | 657,901 / 657,938 → 648,943 / 649,075 |
| 2027-06-28 (libfaketime) | 7,173,600,285 | 7,173,216,812 | 649,174 → 649,145 |

Allocations are the clean signal: the fix brings a crossing date to a non-crossing one's count, and changes nothing
on 2027-06-28. The instruction counts are bimodal: each arm has runs about 70M (1%) apart, as large as the effect,
so the A/A fails and the lobsters instruction numbers are **not a speed claim**. Within the same mode the fix is
0.97–0.99% lower on 2026-11-05 (about 24K per removed lookup, matching the micro-benchmark), and the 2027 control
differs by 0.005%. The mode change is not explained here (one GC falls in each measured window).

## Who else pays it

Every app with a DST time zone (the Rails default is UTC, so only apps that set `config.time_zone` or `Time.zone`),
on every calendar operation whose result is in another period than its receiver:

* lookbacks and lookaheads: the share of days in a year on which `N.days.ago` from noon crosses a change is 0.5% for
  1 day, 3.8% for 7, 7.7% for 14, 17% for 1 month, 39% for 70 days, 50% for 90 days (Chicago, Berlin and Sydney all
  alike);
* `beginning_of_day`/`end_of_day`/`all_day` and friends on the two days a year clocks change;
* every `change(zone:)` into another zone.

Each case costs one tzinfo lookup more than the same operation without the crossing: about 17–25K instructions and
4 objects (6 with sub-second times). For lobsters that is 0.99% of a pass; for a typical app it is small unless it
builds many time windows per request. Rails 8-1-stable and main have the same code; 8-1-stable is a few percent more
expensive per operation overall.

## The fix

```diff
     def change(options)
-      self.class.new(nil, new_zone, new_time, periods.include?(period) ? period : nil)
+      self.class.new(nil, new_zone, new_time, periods.include?(period) ? period : single_period(periods, new_time))
 ...
+      # TZInfo reads a DateTime by its Julian day, which needn't match the civil fields the constructor looks up.
+      def single_period(periods, time)
+        periods.first if periods.one? && time.is_a?(::Time)
+      end
+
       def wrap_with_time_zone(time)
-          self.class.new(nil, time_zone, time, periods.include?(period) ? period : nil)
+          self.class.new(nil, time_zone, time, periods.include?(period) ? period : single_period(periods, time))
 ...
     def periods_for_local(time) # :nodoc:
-      tzinfo.periods_for_local(time)
+      @constant_period ? [@constant_period] : tzinfo.periods_for_local(time)
     end
```

When the receiver's period doesn't apply, the result is a `Time` and its local time has exactly one period, that
period is passed on; it is equal (not identical) to what the constructor would find, since for a `Time` both lookups
see the same wall-clock second (`Timestamp.for(t, :ignore)` uses `to_i + utc_offset`,
`transfer_time_values_to_utc_constructor` the civil fields of the same instant, and sub-seconds can't cross a
whole-second transition). A `DateTime` keeps the old path: tzinfo reads it by its Julian day, while the constructor
converts a non-UTC one by its civil fields, and the two differ for a Julian-calendar `DateTime`. Gaps (no period: the constructor's +1 hour retry) and overlaps (two
periods: `period_for_local`'s DST preference and `periods.last`) keep the old path. The `periods_for_local` shortcut
makes zones without transitions return their memoized period, as `period_for_utc` and `period_for_local` already
do on main, so results in UTC keep sharing one frozen period object instead of a new one per result.

**Exactness.**

* `dst_compare.rb`: every Active Support zone plus 18 edge zones (Dublin's negative DST, Casablanca, Lord_Howe's
  30-minute DST, Moscow 2014, Sao_Paulo, Apia's skipped day, Caracas, Troll, Etc/GMT+5, Kolkata, St_Johns,
  Kiritimati, Gaza, Godthab, Lisbon, Tehran, Chatham, Havana), every transition from 1900 to 2045, 57 offsets around
  each (both sides of each boundary, ±1 s, ±0.5–26 h) with a 1/3-second fraction, 30 operations (day/week/month/year
  arithmetic, `beginning_of_*`, `change(hour: 0..3, min:, sec:, usec:)`, `change(zone:)` into five zones,
  `change(offset:)`, chains, ranges). Each line records inspect, utc, local fields, offset, `dst?`, abbreviation,
  zone and the period's transitions, or the exception. Round 1 (head `4779066d80`): main vs fix identical SHA-256
  in all 8 shards, 30,589,164 results; 8-1-stable vs 8-1 + fix identical in all 8 shards, 29,126,088 results; with
  tzinfo-data 1.2026.6's Ruby data source instead of the system zoneinfo, identical in shards 0 and 3 (7,253,820
  results). **Those runs had no `DateTime` receivers**: `TimeWithZone.new(datetime, zone)` turns a `DateTime` into a
  `Time` (`transfer_time_values_to_utc_constructor`), so the "DateTime" receivers were `Time`s. Round 2's script and
  results are below.
* Active Support's time tests (`time_with_zone_test.rb`, `time_ext_test.rb`, `date_time_ext_test.rb`,
  `date_ext_test.rb`, `time_zone_test.rb`, `duration_test.rb`, `date_and_time_compatibility_test.rb`): 1,281 runs,
  0 failures; RuboCop clean. Two wrong variants fail existing tests (`test_change_at_dst_boundary`,
  `test_round_at_dst_boundary`): always taking `periods.first`, and dropping the reuse of the receiver's period.
  Round 2 adds a regression test for the Julian case.

**Reviews.** Skeptical subagent, three passes:

1. Should-fix: in constant-offset zones (UTC, Etc/GMT+5) tzinfo builds a new `OffsetTimezonePeriod` per
   `periods_for_local` call, so results stopped sharing the zone's frozen, Ractor-shareable period (10,001 live
   periods vs 61 after 10,000 results). Fixed with the `periods_for_local` shortcut.
2. Should-fix: the first shape checked `periods.one?` first, so same-period results in DST zones no longer reused
   the receiver's period object (one extra retained object per result, and not shareable from a shareable
   receiver). Fixed by checking reuse first. That shape was also about 10K instructions cheaper per same-period
   wrap, because it skipped `include?`; that saving belongs in tzinfo (below).
3. Approve, no must-fix or should-fix. Object identity now matches main in every probe (2,550 lines, masked
   addresses); `TimeZone.create` with custom tzinfo, YAML- and Marshal-loaded zones, Ractors match main. Nit kept:
   in constant zones `periods_for_local(nil)` (`:nodoc:`, never called so by Rails) returns the period instead of
   raising `ArgumentError`.

Sol (`codex exec -m gpt-6.1-sol`) and Astra (`-m gpt-6-astra`) ran in the coordinator's orb (this orb has no Codex
CLI); see round 2.

### Round 2: Sol and Astra, Julian DateTimes

On `4779066d80` both returned "changes" with the same must-fix, found independently: for a `DateTime` whose
calendar is Julian, `periods.first` is not the period the constructor picks. tzinfo's `Timestamp.for_datetime`
(`timestamp.rb:231`) counts from the Julian day, while the constructor converts a non-UTC `DateTime` with
`Time.utc(year, month, …)` from its civil fields, which are 13 days behind in 2026. Such a `DateTime` with a nonzero
offset only comes from `change(offset:)` or `change(zone:)`; with offset 0 the constructor keeps the `DateTime` and
both read the Julian day. Reproduced on Ruby 4.0.9:

```ruby
t = ActiveSupport::TimeWithZone.new(nil, ActiveSupport::TimeZone["America/New_York"], DateTime.new(2026, 10, 20, 12, 0, 0, 0, Date::JULIAN))
t.change(offset: Rational(1, 24))  # main: 12:00 CEST +02:00 (10:00 UTC); 4779066d80: 12:00 CET +01:00 (11:00 UTC)
t = ActiveSupport::TimeWithZone.new(nil, ActiveSupport::TimeZone["UTC"], DateTime.new(2026, 10, 25, 12, 0, 0, 0, Date::JULIAN))
t.change(offset: "-07:00")         # main: MDT -06:00 (18:00 UTC); 4779066d80: MST -07:00 (19:00 UTC)
```

Fix: pass the single period on only for a `Time` result (`single_period`); `DateTime` results keep main's nil path
exactly. Other findings: should-fix, disclose in the body that `TimeZone#periods_for_local` (`:nodoc:`) returns the
shared cached period for constant zones and skips tzinfo's argument check (`periods_for_local(nil)` raises on main,
returns an array on the head); nits, the commit message now says "equal to", and speed claims are scoped to
Callgrind instructions of the measured operations. Astra found no other difference over 252 ordinary cases.

Head after round 2: `6993c9b20b`.

* **Regression test** `test_change_offset_of_julian_datetime_across_dst_boundary` asserts main's offset, zone
  abbreviation, `dst?` and UTC for the first case; it fails on `4779066d80` (`Expected: 7200, Actual: 3600`) and
  passes on main and the new head. Time tests: 1,282 runs, 0 failures; RuboCop clean.
* **Differential with real `DateTime` receivers.** `dst_compare.rb` now builds them through the local path
  (`new(nil, zone, datetime)`, asserting `time.is_a?(DateTime)`), as ITALY-start (Gregorian after 1582) and Julian
  `DateTime`s at 33 of the offsets around each transition, adds `change(offset:)` into ten offsets whose zones have
  DST, and adds ITALY-start receivers from 1400 to 1582-10-15 (Julian before the reform) with jumps of 400–444 years
  into the transition era. On New York, Berlin and UTC it finds 15,231 differences between main and `4779066d80`,
  all Julian receivers with `change(offset:)`, and none between main and the new head (2,105,322 results). The ITALY
  receivers before 1582 never differ: the earliest tzdata transition is 1834 (Europe/Amsterdam), so all such dates lie in one period.
  Full run, main vs `6993c9b20b`: identical SHA-256 in all 8 shards, 77,169,642 results; the head skips 18.2M of
  main's 42.1M second lookups (the rest are `DateTime` results, gaps and overlaps).
* **Instructions** (same micro-benchmarks as above, main vs `6993c9b20b`): crossing a DST change, `70.days.ago` 83,469/83,550 → 60,140 (−28%), `1.day.ago` 85,821/85,740 →
  61,194/61,275 (−29%), `beginning_of_day` 63,620 → 39,126 (−38%), `change(month:)` 62,082/62,121 → 38,696/38,734
  (−38%); UTC `70.days.ago` 45,446 → 36,486/36,567 (−20%); in the same period, `70.days.ago` 66,554 →
  66,617/66,698, `beginning_of_day` 43,723/43,750 → 43,786, a fresh receiver's `beginning_of_day` 67,669/67,696 →
  67,732/67,759, Tokyo 58,024/58,105 → 58,168 (within about 100 instructions; repeats differ by up to 81). With
  the helper called on every wrap (`6b667cb848`) the same-period cases were 150–310 instructions above main, so the
  `include?` check stays inline.
* **lobsters** (8-1-stable with the new `time_with_zone.rb` methods redefined after boot, one pass after two
  warmups): 657,778 → 648,805 objects per pass on 2026-11-05 with 0 second lookups; 648,888 → 648,893 on
  2027-06-28.

## tzinfo: comparing equal periods is slow

`periods.include?(period)` compares two `TransitionsTimezonePeriod`s that are never the same object (tzinfo builds
a new one per lookup) but share the same `TimezoneTransition` objects from the cached transitions array.
`TimezoneTransition#==` then compares both offsets field by field, and `TimezoneOffset#==` compares
`base_utc_offset`, `std_offset` and `abbreviation`. That costs about 11K instructions per `include?` hit, about a
quarter of a same-period `beginning_of_day`.

A one-line identity shortcut in `TimezoneTransition#==` (`return true if equal?(tti)`, branch
[`thomasklemm/equal-identity-shortcut`](https://github.com/thomasklemm/tzinfo/tree/thomasklemm/equal-identity-shortcut)
at `2b2f4b45` on tzinfo master `1207d609`; transition, period, timezone and data-timezone tests pass, 254 runs) is
exact for these value objects (`==` of an object with itself is true for every field they hold) and helps every
same-period wrap in every DST zone, independent of the Rails fix. Not reviewed beyond this record:

| instructions per call, Rails main, Ruby 4.0.9 | tzinfo master | with the shortcut |
| --- | ---: | ---: |
| `[period].include?(equal_period)` | 11,446 | 3,440 (−70%) |
| `beginning_of_day`, same period | 43,709 | 35,677 (−18%) |
| `70.days.ago`, same period | 66,485 / 66,566 | 58,480 (−12%) |
| `70.days.ago`, crosses DST | 83,376 | 83,587 (no `include?` hit) |

Pushed to the fork only, nothing opened. Queued as [TZ1](../../bench/upstream/pr-queue/items/TZ1.md) (2026-11-05).

### TZ1: the shortcut, re-measured and placed

Re-measured on the branch itself (the table above had the shortcut prepended to both `TimezoneTransition` and
`TimezoneOffset`), with a second master checkout as A/A control (`ir-tzinfo-eq.txt`, Rails main `1e235cee11`, Ruby
4.0.9, America/Chicago, system zoneinfo; A/A ≤ 81 instructions per call):

| instructions per call | master | `TimezoneOffset#==` shortcut | `TimezoneTransition#==` shortcut (TZ1) | both |
| --- | ---: | ---: | ---: | ---: |
| `[period].include?(equal_period)` | 11,446 | 7,489 | 3,440 | 3,440 |
| `transition == transition` (same object) | 5,280 | 3,302 | 1,277 | 1,277 |
| `beginning_of_day`, same period | 43,701 | 39,744 | 35,695 | 35,695 |
| `change(hour: 3)`, same period | 42,439 | 38,483 | 34,434 | 34,434 |
| `70.days.ago`, same period | 66,626 | 62,588 | 58,621 | 58,621 |
| `70.days.ago`, crosses DST | 83,464 | 83,674 | 83,594 | 83,808 |
| `beginning_of_day` on the day clocks went back | 63,560 | 63,798 | 63,798 | 64,008 |
| `[period].include?(different_period)` | 4,333 | 4,543 | 4,543 | 4,753 |

With tzinfo-data 1.2026.6: `include?` 11,290 → 3,440, `beginning_of_day` 44,275 → 36,399, `70.days.ago` same
period 65,677 → 57,827.

* **Placement.** The transition is the smallest place that catches the whole saving: Active Support's periods are
  never the same object (a `TransitionsTimezonePeriod#==` shortcut never fires there), but their transitions always
  are, in both data sources (they come from the zone's cached transitions array, also beyond the last defined
  transition). An offset-level shortcut saves half as much and adds the same ~210 instructions to unequal
  comparisons; adding it on top of TZ1 gains nothing.
* **Callers.** tzinfo itself never compares transitions or periods; the only caller found is Active Support's
  `periods.include?(period)` in `TimeWithZone#change` and `#wrap_with_time_zone` (Rails main and 8-1-stable).
* **Exactness.** `tz_eq_compare.rb`: `==`, `eql?` and `hash` agree with master's expression, and the per-comparison
  digest is identical between master and TZ1, for every transition of every zone against itself, its neighbours,
  equal copies built with `TimezoneTransition.new` (one with a fresh offset) and other types, up to 2100 (zoneinfo: 597 zones, 651,122 comparisons;
  tzinfo-data: 598 zones, 314,438). The only input whose result changes is a transition built with a value that is
  not equal to itself (e.g. `Float::NAN` as `timestamp_value`), outside the documented types. `eql?` is an alias
  bound after the new body. tzinfo `rake test` on Ruby 4.0.9: 1,867/1,865/1,865 runs, 0 failures; the fork's full
  Tests matrix (39 jobs, MRI 2.3–4.0, JRuby 9.1–10.1, Linux and Windows) passes on `2b2f4b45`. Active Support's
  seven time test files: 1,281 runs, 0 failures with master and with TZ1.

## Recommendation

* **Queue the Active Support fix** as a rails/rails draft from head `6993c9b20b` once Sol and Astra approve it
  (rails/rails is at the 20-open cap; drafts may open overnight, only Thomas marks them ready). Body: two short
  paragraphs (what is wasted and why; what changes and that results are the same, including the
  `periods_for_local` note for constant zones) and one table in Callgrind instructions; no lobsters speed claim.
  Readability L1 (one small private helper). Body draft, written to DECISIONS' "Bodies for humans, short":
  [`pr-body.md`](../../bench/upstream/ruby_bench_dst/pr-body.md).
* **tzinfo**: TZ1 is prepared as a draft candidate (see above); it is independent of the Active Support fix.
* **ruby-bench**: the fixed-clock PR from round 4 still makes sense on its own: it removes date dependence that has
  other sources too (expired windows), and the DST part would otherwise only disappear once ruby-bench pins a Rails
  release with the fix.
* **Ruby**: nothing to do; the data points at Ruby code in Active Support and tzinfo.
