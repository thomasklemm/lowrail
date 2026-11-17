# Time.new: overflowing mday with a UTC offset or a timezone object

2026-11-17. Two findings from the review of rails/rails#59617 (Time#change with zone objects), checked on ruby/ruby
master c2c5ac6d1b and on 3.3.13, 3.4.12 and 4.0.9. **Both are real on master and on all three releases. They have
one root cause and one fix.** Neither is reported on bugs.ruby-lang.org. Fix branch:
[thomasklemm/ruby `thomasklemm/time-new-normalize-mday`](https://github.com/thomasklemm/ruby/tree/thomasklemm/time-new-normalize-mday)
(head `d3e0a31795`), queue item [TN1](../../bench/upstream/pr-queue/items/TN1.md), state built. No PR or issue
was opened.

## Repros

```ruby
Time.new(2026, 2, 31, 23, 0, 0, -18000)   #=> 2026-01-30 23:00:00 -0500, expected 2026-03-03 23:00:00 -0500
Time.new(2026, 2, 31, 23, 0, 0, "-05:00") #=> same
Time.new(2026, 4, 31, 23, 0, 0, -18000)   #=> 2026-03-30 23:00:00 -0500, expected 2026-05-01 23:00:00 -0500
Time.new(2026, 2, 31, 23, 0, 0, 18000)    #=> 2026-03-03 23:00:00 +0500 (right)

tz = TZInfo::Timezone.get("Australia/Sydney")
t = Time.new(2026, 4, 31, 2, 0, 0, tz)
t.day      #=> 31
t.inspect  #=> "2026-04-31 02:00:00 +1000"
t.to_i     # right: same instant as 2026-05-01 02:00 +1000
t.strftime("%F") #=> "2026-05-01", and t.day is 1 from then on
```

A zone object that only implements `local_to_utc`/`utc_to_local` with a fixed offset shows the same, so it is not
TZInfo-specific.

Sweep (`.amp/in/orb-backup/sweep.rb`): years 2024 and 2026, every month, days 1–31, hours 0–24, 31 offsets
(−12h..+14h plus −9:30, +5:30, +5:45, +12:45). Each `Time.new` is compared with `Time.utc(...) - offset`, both the
instant and the fields:

| zone argument | 3.3.13 / 3.4.12 / 4.0.9 / master | with the fix |
|---|---|---|
| Integer offset | 1,000 of 576,600 differ (wrong instant) | 0 |
| `"+HH:MM"` string | 1,000 of 576,600 differ (the same cases) | 0 |
| zone object, fixed offset | 10,075 of 576,600 differ (fields only, instant right) | 0 |
| `"UTC"` | 325 of 18,600 differ (fields only; Bug #21301) | 0 |

Integer and string offsets behave identically: `utc_offset_arg` turns both into the same `vtm.utc_offset`. The wrong
instants all have day 31 in February, April, June, September or November, a negative offset, and a local time that
is on the next day in UTC. The review's 1,152 of 340,200 used a different grid; the cases are the same kind.
`Time.new` without a zone (local time) also changes, only for a day past the month's end, and now matches
`Time.local`, which normalizes in `time_arg()` (Bug #15340, 2c652768a8). On master the two disagree near DST changes
and for years with |year − 1900| > INT_MAX: in 144 to 715 of 82,320 nil-zone cases under each of 14 TZ settings; on
the head in 0 (claude-code pass). Examples on master: under `TZ=Pacific/Auckland`, `Time.new(2000, 9, 31, 3, 30)` is
04:30 +1300 (head and `Time.local`: 03:30); Pacific/Chatham 1987-02-29 02:59 gets +1345 instead of +1245;
Europe/Berlin 1916-04-31 12:00 becomes 13:00; `Time.new(3_000_000_000, 2, 31, 23)` is March 1 under Berlin instead
of March 2. The earlier "0 of 2,400" under `TZ=America/New_York` sampled no such case.

## What the documented behaviour is

`Time.new`'s RDoc (timev.rb) gives `mday` the range 1..31 with no per-month limit, and says the zone argument only
selects the timezone ("the new +Time+ object is in the specified timezone"). Time.utc and Time.local normalize month
and mday in `time_arg()` (April 31 → May 1, February 30 → March 2 or 1), and `Time.new` with `"+00:00"` rolls over
the same way (mame's examples in Bug #21301 and Feature #21307). So day 31 of a 30-day month is documented input and
should mean the same instant whatever the zone. For an offset that is `Time.utc(y, m, d, h, mi, s) - offset`; for a
zone object it is whatever its `local_to_utc` returns, with fields read as `utc_to_local` of it. Feature #21307
(a strict constructor) was accepted as an opt-in `strict: true` keyword, so rolling over stays the default, and
nothing there makes the results above intended: the negative-offset result is a month away from any reading of the input.

## Root cause (time.c, `time_init_vtm`)

`time_init_vtm()` validates the fields (mday 1..31), then branches on the zone. Only the `"UTC"` branch would
normalize month-mday, and only with ruby/ruby#16469, which is still open:

* **Offset (Integer or string):** `vtm_add_offset(&vtm, off, -1)` moves the fields to UTC. For a negative offset
  crossing midnight it calls `vtm_add_day(vtm, 1)`, which normalizes only `mday == days_in_month` and otherwise does
  `mday++`. Day 31 of a 30-day month (or of February) becomes 32, which the 5-bit `mday` bit-field in `struct vtm`
  stores as 0. `timegmw()` then reads day 0 of the month, i.e. the last day of the month before, so the instant is a
  month early. Positive offsets subtract a day (31 → 30), and `timegmw()` normalizes that correctly.
* **Zone object:** the instant comes from `timegmw()` (which normalizes) and `local_to_utc`, so it is right. But
  `time_set_vtm()` caches the unnormalized fields with `tm_got = 1`, so `#day`, `#mon`, `#inspect` and `#to_s`
  return April 31 until a method such as `strftime` recomputes the fields.
* **`"UTC"`:** the same field cache (Bug #21301).

## Fix

Branch `thomasklemm/time-new-normalize-mday` on master c2c5ac6d1b, two commits:

1. `5f4d01cd26`, Chris Hasiński's commit from the open ruby/ruby#16469 (Bug #21301, approved by jeremyevans
   2026-05-08, not merged), cherry-picked unchanged with authorship kept. It moves `time_arg()`'s month-mday
   normalization into `vtm_normalize_month_mday()` and calls it in the `"UTC"` branch.
2. `d3e0a31795`, ours: moves that call to right after `validate_vtm()`, so every branch (UTC, offset, zone object,
   local) starts from a normalized date. time.c +1/−1 net on top of (1), plus tests.

```diff
     validate_vtm(&vtm);
+    vtm_normalize_month_mday(&vtm);
 ...
         vtm.isdst = 0; /* No DST in UTC */
-        vtm_normalize_month_mday(&vtm);
         vtm_day_wraparound(&vtm);
```

Normalizing before the branch is safe: after it `mday` is at most the month's length, so `vtm_add_day` and
`vtm_day_wraparound` (hour 24) see valid dates. `timegmw`/`timelocalw` already gave the same instant for in-range
input. The local path changes only for days past the month's end, where it now agrees with `Time.local`.

Tests: `test_month_mday_normalization_with_negative_utc_offset` in test/ruby/test_time.rb (Integer and string
offsets, leap and common February, April 31, April 31 24:00, and the string form `"2026-02-31 23:00:00 -05:00"`),
and `subtest_month_mday_normalization` in test/ruby/test_time_tz.rb, which runs for the file's dummy `TZ` class,
TZInfo and the Timezone gem in four zones each (February 31 12:00 → March 3; April 31 24:00 → May 2).

Results on the fixed build:

* Without the fix (master binary), the new tests fail: 10 tests, 10 failures (8 zone-object subtests with TZInfo and
  the dummy TZ, the UTC test from (1), and the offset test).
* With the fix, `test_time.rb` + `test_time_tz.rb` with TZInfo on the load path: 303 tests, 2800 assertions,
  0 failures. `make test-all TESTS='ruby/test_time*'`: 250 tests, 2457 assertions, 0 failures (TZInfo not
  installed there, so the gem subtests skip). `make btest`: PASS all 2148. `make test-spec
  SPECOPTS=../spec/ruby/core/time`: 652 examples, 7876 expectations, 0 failures.
* Sweep: 0 differences for every zone kind (table above).

Not run: the full test-all, hosted CI, and a Thermos pass. Nothing measured for speed; the change adds one switch per
`Time.new` with fields.

## Prior reports

* [Bug #21301](https://bugs.ruby-lang.org/issues/21301) (mame, open): the same field cache with `"UTC"`. The
  candidate fixes are ruby/ruby#13246 (closed by its author unmerged) and ruby/ruby#16469 (khasinski, open,
  approved). Both normalize only in the `"UTC"` branch, so neither fixes the offset or zone-object cases.
  [Bug #22375](https://bugs.ruby-lang.org/issues/22375) (`Time.new("2026-02-30T00:00:00Z")`) is open; nobu
  marked it a duplicate of #21301 on 2026-09-23.
* [Bug #18274](https://bugs.ruby-lang.org/issues/18274) (closed, 1d666ed50f): a different `vtm_add_day` bug (leap
  day with a positive offset).
* [Feature #21307](https://bugs.ruby-lang.org/issues/21307) (Assigned): a strict constructor, accepted at the dev
  meeting as a `strict: true` keyword, not implemented yet; related, not a report.
* Redmine subject searches for `Time.new` and `utc_offset`, and ruby/ruby PR searches for mday and
  normalization, found nothing on the negative-offset instant or on zone objects.

So the offset bug is unreported, and so is the zone-object variant. It is the same mechanism as #21301, so it fits
there as a note rather than as a new issue.

## How to send it (needs Thomas's OK)

DECISIONS, Pull requests: no new ruby/ruby PRs for now. Never stack on an open PR, and where someone already has a
branch, build on it with their commits kept. Ordered by what fits these rules best:

1. **Note on Bug #21301 with the repro (draft below)**, pointing at the one-line follow-up. If #16469 merges first,
   the fix becomes a one-line rebase of commit 2 onto master, and the PR then names #16469.
2. **One PR with both commits**, Chris's first, crediting #16469 in the body. It replaces #16469, so it should
   happen only if khasinski or a committer is fine with that.

The draft below is for (1), or as a new issue if Thomas prefers a separate ticket. It is written in the plain style of
ruby-core reports.

### Draft for bugs.ruby-lang.org

> **Time.new misplaces day 31 of a shorter month with a negative UTC offset, and keeps it with a timezone object**
>
> `Time.new` accepts day 31 for months with fewer days and normally rolls it over, like `Time.utc`:
>
> ```ruby
> Time.new(2026, 2, 31, 23, 0, 0, "+05:00") #=> 2026-03-03 23:00:00 +0500
> Time.utc(2026, 2, 31, 23, 0, 0)          #=> 2026-03-03 23:00:00 UTC
> ```
>
> With a negative UTC offset, when the time is on the next day in UTC, the result is a month early:
>
> ```ruby
> Time.new(2026, 2, 31, 23, 0, 0, "-05:00") #=> 2026-01-30 23:00:00 -0500, expected 2026-03-03 23:00:00 -0500
> Time.new(2026, 4, 31, 23, 0, 0, -18000)   #=> 2026-03-30 23:00:00 -0500, expected 2026-05-01 23:00:00 -0500
> ```
>
> With a timezone object the time is correct, but the fields are not normalized, as with "UTC" in this issue:
>
> ```ruby
> require "tzinfo"
> t = Time.new(2026, 4, 31, 2, 0, 0, TZInfo::Timezone.get("Australia/Sydney"))
> t       #=> 2026-04-31 02:00:00 +1000
> t.day   #=> 31
> t.strftime("%F") #=> "2026-05-01"
> t.day   #=> 1
> ```
>
> Without a zone, `Time.new` disagrees with `Time.local` near DST changes, because only `Time.local` normalizes
> first (Bug #15340):
>
> ```ruby
> ENV["TZ"] = "Pacific/Auckland"
> Time.new(2000, 9, 31, 3, 30)   #=> 2000-10-01 04:30:00 +1300
> Time.local(2000, 9, 31, 3, 30) #=> 2000-10-01 03:30:00 +1300
> ```
>
> The first two happen on 3.3, 3.4, 4.0 and master. In `time_init_vtm()`, `vtm_add_offset()` calls `vtm_add_day()`, which
> turns day 31 into 32, stored as 0 in the 5-bit `mday`. The timezone object path caches the fields as given, and the local path converts before normalizing.
>
> Calling `vtm_normalize_month_mday()` from github.com/ruby/ruby/pull/16469 right after `validate_vtm()`, instead
> of only in the UTC branch, fixes all three cases:
> https://github.com/thomasklemm/ruby/commit/d3e0a31795
