# Time.new: overflowing mday with a UTC offset or a timezone object

2026-11-17. Two findings from the review of rails/rails#59617 (Time#change with zone objects), checked on ruby/ruby
master c2c5ac6d1b and on 3.3.13, 3.4.12 and 4.0.9. **Both are real on master and on all three releases. They have
one root cause and one fix.** Neither is reported on bugs.ruby-lang.org. Fix branch:
[thomasklemm/ruby `thomasklemm/time-new-normalize-mday-3`](https://github.com/thomasklemm/ruby/tree/thomasklemm/time-new-normalize-mday-3)
(head `2e061793aa` on master 6478deb7d2, 2026-11-26; earlier heads stay on `-2` (`a0e8852a14`) and on
`thomasklemm/time-new-normalize-mday` (`d3e0a31795`)), queue item [TN1](../../bench/upstream/pr-queue/items/TN1.md),
state in-review. 2026-11-25: Thomas posted the repros and our commit as a comment on ruby/ruby#16469
(issuecomment-7162441987), no reply. 2026-11-26: Thomas approved opening one draft PR with both commits once
thermos-sol and Astra approve the head and the body (section below). No further comment on #16469 is planned.

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

Branch `thomasklemm/time-new-normalize-mday` on master c2c5ac6d1b, two commits (rebased unchanged on 2026-11-25 as
`a87590a698` and `a0e8852a14` on `-2`, see below):

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

### Rebase onto master e8167b0ddd (2026-11-25)

Branch `thomasklemm/time-new-normalize-mday-2`: `a87590a698` (Chris Hasiński's commit, his authorship kept, same
patch-id as #16469's head `f796c85300`) and `a0e8852a14` (ours), Thomas as committer, no trailers. `git range-diff`
shows both patches identical: time.c has no commits since c2c5ac6d1b, so the code and the claude-code pass carry
over. Master hasn't fixed it: #16469 is still open on `f796c85300` (last update 2026-05-08, jeremyevans's approval,
no comments), Bug #21301 and #22375 are open with nobu's duplicate mark of 2026-09-23 as the last change, Feature
#21307 is unchanged, no Redmine issue since 2026-11-18 is about Time (22560 to 22637, read one by one; the issue list
API answers 403), and no ruby/ruby PR updated since 2026-11-17 touches time.c. The release branches' time.c got only
bb382ae5df (`time_init_parse` precision) since 3.3.13, 3.4.12 and 4.0.9.

On master (`ruby 4.1.0dev (2026-11-25T11:44:00Z master e8167b0ddd) +PRISM [x86_64-linux]`) and 4.0.9 every line of the note below reproduces (`.amp/in/orb-backup/tn/repro.sh`); the head
gives the expected values. Tests on the head: `make test-all TESTS='ruby/test_time*'` 251 tests, 2461 assertions;
test_time.rb + test_time_tz.rb through `tool/runruby.rb` with TZInfo 2.0.6 and timezone 1.3.32 preloaded
(`-rtzinfo -rtimezone`; without the preload the runner drops the GemTimezone class) 357 tests, 3147 assertions,
0 failures under TZ=UTC, Europe/Berlin, Africa/Lagos, Asia/Tokyo, America/New_York and Australia/Sydney;
spec/ruby/core/time 652 examples, 0 failures. Master with the head's tests: 357 tests, 14 failures, exactly the new
tests. `git merge-tree` with TN2's `ec3f27cd36` is clean. Not run: btest, the full test-all, hosted CI.

### Rebase onto master 6478deb7d2 and added tests (2026-11-26)

TN2 merged today as 34af03e0d4 (nobu reworded its subject), so time.c moved under TN1. New branch
`thomasklemm/time-new-normalize-mday-3`, cherry-picked onto master 6478deb7d2: `a71fbcdb55` (Chris Hasiński's commit,
his authorship kept, `git patch-id --stable` 488d6a13 as #16469's head `f796c85300`) and `baf2e89c32` (ours,
patch-id cf6c1198 as `a0e8852a14`), Thomas as committer, no trailers, both signed with script/signing-key.
`git range-diff e8167b0ddd..a0e8852a14 6478deb7d2..baf2e89c32` gives `=` for both: the TN2 change and ours touch
different lines of `time_init_vtm()` and the cherry-picks merged without conflicts. Then ours was amended to
`9d4667a9a6` (time.c unchanged, range-diff `!` only in test lines and one commit-message sentence). Our commit also
applies to #16469's head unchanged (`git merge-tree` clean).

Master hasn't fixed it, checked 2026-11-26: #16469 is open on `f796c85300`, updated 2026-11-25 only by Thomas's
comment, jeremyevans's approval of 2026-05-08 the only review; of the 125 ruby/ruby PRs updated since 2026-11-25, only
#16469 and TN2's #20172 touch time.c, test_time*, timev.rb or spec/ruby/core/time; Bug #21301 and #22375 Open with
nobu's duplicate mark of 2026-09-23 as the last journal, Feature #21307 Assigned and unchanged since 2025-05-09;
Redmine issues 22630 to 22641 (through today; the list API answers 403) have none about Time.

**Tests looked for (Thomas, 2026-11-26).** Each candidate was run on master and the head
(`.amp/in/orb-backup/tn/candidates.rb`, expected values from `Time.utc(...) - offset`, TZ=UTC):

* Leap years: Feb 29 and 30 with -05:00 at 23:00 are right on master in 2024, 2026, 2000 and 1900
  (`vtm_add_day` makes 30/31 and `timegmw` normalizes them); only day 31 goes wrong. Added Feb 31 23:00 -05:00 in
  2000 and 1900 to `test_month_mday_normalization_with_negative_utc_offset` (2024 and 2026 were there): master gives
  2000-01-31 and 1900-01-31 04:00 UTC, the head March 3 and March 4. A fix with a wrong leap rule (y % 4 or a missing
  y % 400) fails one of the two.
* Positive offset back across the month boundary (Apr 31 02:00 +05:00 → Apr 30 21:00 UTC): right on master and the
  head, and every placement of the call gives it, so not added.
* Hour 24 on an overflowing day: already in the tests (Apr 31 24:00 -05:00; Apr 31 24:00 in the zone-object
  subtest, which fails on master). Not added again.
* `in:` next to the positional zone: timev.rb passes either one as the same `zone` to `time_init_args`; master
  fails both the same way. A near-duplicate, not added.
* No zone near DST: added `test_pacific_auckland` to test_time_tz.rb in its `assert_time_constructor` style,
  `Time.local` and `Time.new` with 2000-09-31 03:30 → "2000-10-01 03:30:00 +1300". Master gives 04:30 for `:new`.
* String form: already pinned (`"2026-02-31 23:00:00 -05:00"` and commit 1's `"2025-04-31T00:00:00Z"`); it
  normalizes like the argument form, and day 32 still raises ArgumentError on both.
* spec/ruby/core/time/new_spec.rb has no overflowing-day example. Not added: spec/ruby is synced from ruby/spec,
  a fix there needs a `ruby_bug "#21301", ""..."4.1"` guard whose bound depends on backports nobody has decided,
  the Sydney case would need a duck zone (ruby/spec loads no gems), and test/ruby already fails on master for every
  case. Thomas can ask for it in review.

**time_init_vtm checked for cheap improvements:** one, not applied. The call runs once per `Time.new`;
`validate_vtm()` must run before it (the switch relies on mon 1..12 and mday 1..31); `time_arg()`'s own call serves
`Time.utc`/`Time.local`, which don't reach `time_init_vtm()`. TN2's `tvtm` copy in the zone block (wrap a copy for
the timezone object) is no longer needed once the date is normalized: both reviewers built the variant that wraps
`vtm` directly and found it behaviour-identical (Astra: 1,037,452 sweep cases; thermos-sol: 1,968,720 oracle
checks). It stays, because removing it would make our commit depend on TN2 and no longer apply unchanged to #16469.

**Results on `9d4667a9a6`** (`ruby 4.1.0dev (2026-11-26T13:46:56Z HEAD 9d4667a9a6)`; master `6478deb7d2`):

* Repros (`.amp/in/orb-backup/tn/repro.sh`, each case in a forked child): master gives 2026-01-30 (-05:00 and
  -18000, and the string form), 2026-03-30, `"2026-04-31 00:00:00 UTC"`, Sydney `["2026-04-31 02:00:00 +1000", 31,
  "2026-05-01", 1]`, Auckland 04:30 against `Time.local` 03:30. The head gives 2026-03-03, 2026-05-01, May 1,
  `["2026-05-01 02:00:00 +1000", 1, "2026-05-01", 1]` and 03:30. 4.0.9 matches master.
* TN2's cases on the same script: master and the head both give UTC for `to_str` UTC/Z/the string form/a
  find_timezone returning "UTC", "utc_offset out of range" for +25:00, 09:00 UTC for Plus3, and 2026-05-02 for
  +00:00 at April 31 24:00 (4.0.9: SIGSEGV, +2500, 17:00, March 31). One line differs: `to_str` "UTC" at
  2000-04-31 24:00 is `2000-04-01 00:00:00 UTC` on master (TN1's field cache) and `2000-05-02 00:00:00 UTC` on the head.
* Sweep (`.amp/in/orb-backup/tn/sweep.rb`, rewritten from the record's description because the old orbs are
  archived; it reproduces the record's numbers exactly on 4.0.9 and master): Integer 1,000, String 1,000, zone object
  10,075 of 576,600 and "UTC" 325 of 18,600 differ on master; 0 of each on the head.
* test_time.rb + test_time_tz.rb through `tool/runruby.rb` with TZInfo 2.0.6 and timezone 1.3.32 preloaded
  (`tn/tz6.sh`): 360 tests, 3176 assertions, 0 failures under UTC, Europe/Berlin, Africa/Lagos, Asia/Tokyo,
  America/New_York and Australia/Sydney. Master with the head's test files: 360 tests, 15 failures under each,
  exactly the new tests (`test_utc_month_mday_normalization`, `test_month_mday_normalization_with_negative_utc_offset`,
  `test_pacific_auckland`, and `test_month_mday_normalization` for DummyTZ, GemTZInfo and GemTimezone in four zones).
* `make test-all TESTS='ruby/test_time*'` 254 tests, 2490 assertions, 0 failures; `make btest` PASS all 2148;
  `make test-spec SPECOPTS=spec/ruby/core/time` 652 examples, 7876 expectations, 0 failures.

Not run: the full test-all, hosted CI (the fork has no workflows).

### Review fixes, head 2e061793aa (2026-11-26)

Both passes on `9d4667a9a6` asked for changes; neither found a runtime defect (verdicts in TN1.md). Applied in our
commit only, Chris's stays byte-identical, time.c code unchanged:

* Astra: `test_utc_month_mday_normalization` (commit 1's test) compared mostly instants, which already agree on
  master. It now checks the cached `[year, mon, mday, hour]` of each case before any method recomputes them, plus the
  instant. On master it fails at April 31 (reads April 31); a build that skips the June case passed all 360 tests
  before and fails it now. Its seven comment headings and the helper comment above `vtm_normalize_month_mday()` went
  (DECISIONS, code comments); the leap-year comment moved from `time_arg()` stays.
* thermos-sol: the body now says "With day 31 and a negative offset" (Feb 29 and 30 are right on master); added
  `test_local_month_mday_normalization`: `Time.new(3_000_000_000, 2, 31, 23)` equals `Time.local(3_000_000_000, 3, 2,
  23)`. Master gives Feb 29 under UTC and New York and March 1 under Tokyo, Berlin, Auckland and Sydney; the head
  March 2 under all.

On `2e061793aa` (binary built from `07c61fd3f2`, same time.c): gem tests 361 tests, 3183 assertions, 0 failures under
the six TZs; master with these tests 16 failures under each, exactly the new tests; `make test-all
TESTS='ruby/test_time*'` 255 tests, 2497 assertions; the sweep 0 of every kind; the repros identical to the section
above; spec/ruby/core/time 652 examples and btest 2148 passing. Our commit still applies to #16469's head unchanged.

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

### Note for Bug #21301 (ready to paste, 2026-11-25)

A comment on [Bug #21301](https://bugs.ruby-lang.org/issues/21301), so no subject or `ruby -v` field; the version
line is in the text.

> ```ruby
> Time.new(2026, 2, 31, 23, 0, 0, "-05:00") #=> 2026-01-30 23:00:00 -0500, expected 2026-03-03 23:00:00 -0500
> Time.new(2026, 4, 31, 23, 0, 0, -18000)   #=> 2026-03-30 23:00:00 -0500, expected 2026-05-01 23:00:00 -0500
> Time.new(2026, 2, 31, 23, 0, 0, "+05:00") #=> 2026-03-03 23:00:00 +0500
> ```
>
> The same overflowing day also goes wrong with a UTC offset, not only with "UTC". With a negative offset, when the time is on the next day in UTC, the result is a month early. Positive offsets are right.
>
> With a timezone object the time is right, but the fields are kept as given, as with "UTC" here:
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
> Without a zone, `Time.new` disagrees with `Time.local` near DST changes, because only `Time.local` normalizes first (Bug #15340):
>
> ```ruby
> ENV["TZ"] = "Pacific/Auckland"
> Time.new(2000, 9, 31, 3, 30)   #=> 2000-10-01 04:30:00 +1300
> Time.local(2000, 9, 31, 3, 30) #=> 2000-10-01 03:30:00 +1300
> ```
>
> All three happen on `ruby 4.1.0dev (2026-11-25T11:44:00Z master e8167b0ddd) +PRISM [x86_64-linux]`, and the first two also on 3.3, 3.4 and 4.0. In `time_init_vtm()`, `vtm_add_offset()` calls `vtm_add_day()`, which turns day 31 into 32, stored as 0 in the 5-bit `mday`. The timezone object path caches the fields as given, and the local path converts before normalizing.
>
> Calling `vtm_normalize_month_mday()` from https://github.com/ruby/ruby/pull/16469 right after `validate_vtm()`, instead of only in the UTC branch, fixes all three: https://github.com/thomasklemm/ruby/commit/a0e8852a14

## Time.new with a zone object whose `to_str` is "UTC": segfault (TN2)

2026-11-18. A side finding of the claude-code pass on TN1. **Real on 3.3.13, 3.4.12, 4.0.9 and master 3a19e2efcf;
unreported.** Fix branch:
[thomasklemm/ruby `thomasklemm/time-new-to-str-utc-4`](https://github.com/thomasklemm/ruby/tree/thomasklemm/time-new-to-str-utc-4)
(head `ec3f27cd36`, one commit on master e8167b0ddd, rebased unchanged on 2026-11-25 from `d6d39dbf17` on
3a19e2efcf, which stays on `-3`; standalone, not stacked on TN1), queue item
[TN2](../../bench/upstream/pr-queue/items/TN2.md), state built. The earlier heads stay on their branches:
`a0670a0a30` (`thomasklemm/time-new-to-str-utc`; thermos-opus: code approved, changes in the test, this record and
the draft) and `8d626f3a52` (`-2`; thermos-opus confirm: one time.c must-fix, the hour-24 overflow below). Both are
applied here. Thomas approved reporting it on 2026-11-25 (ticket text below; he posts it). Nothing posted.

```ruby
o = Object.new
def o.to_str = "UTC"
Time.new(2026, 1, 1, 0, 0, 0, o)  # [BUG] Segmentation fault at 0x0000000000000034
```

### Root cause

`time_init_vtm()` treats any zone argument that is not nil, an Integer or a String as a timezone object
(`maybe_tzobj_p`). When `zone_timelocal()` fails (no `local_to_utc`), it falls back to
`vtm.utc_offset = utc_offset_arg(zone)`, which converts with `to_str`. That fallback handles only `nil` (try
`Time.find_timezone`). Three other results go wrong, and a fourth problem shows once the first is fixed:

* **`UTC_ZONE`** (`Qundef`, returned for `"UTC"`, `"Z"` and `-00:00`-style strings), since 4f9ab3a01a (2.7.0), which
  added `UTC_ZONE` and converted it only in the String branch. The `utc == UTC_ZONE` check below doesn't see it,
  because only `vtm.utc_offset` holds it and `utc` is still nil, so the offset path runs
  `vtm_add_offset(&vtm, Qundef, -1)`. gdb on master: `time_init_vtm` (time.c:2609) → `vtm_add_offset` (2105,
  `lt(off, 0)`) → `cmp` (98) → `rb_funcallv(recv=0x24, <=>)` → `flo_cmp(x=36)` reads the Qundef as a Float. The
  reviewer's hypothesis was right.
* **A name that `Time.find_timezone` resolves**, since 337b4b6344 (2.6.0). `zone_timelocal()` sets up the time, but
  the block doesn't return, so the code falls through to `timelocalw()` and recomputes the instant from the wall
  time in the system's local zone, keeping the zone's offset. No crash, a wrong instant. `find_timezone` receives
  the object itself, not the converted String, so this needs a `find_timezone` that converts (`String(n)`); one that
  compares `n == "Plus3"` returns nil and `Time.new` raises ArgumentError on every version. With a fixed +03:00 zone
  found that way, `Time.new(2026, 1, 1, 12, 0, 0, o)` is 12:00 UTC (15:00 +0300) under `TZ=UTC` and 17:00 UTC
  (20:00 +0300) under `TZ=America/New_York`; the String name gives 09:00 UTC (`tn2/tzclaim.rb`; same on 3.3.13 and
  master).
* **Fixed offsets out of range.** The String branch's offset is range-checked by `validate_vtm()`, which has already
  run when the fallback assigns. So `to_str` `"+24:00"`, `"+25:00"` and `"-24:00"` give `+2400`, `+2500` and `-2400`
  where the String raises "utc_offset out of range" (3.3.13 through master; found by the thermos-opus pass).
* **Hour 24 on a day past the end of the month.** Before trying the timezone object, the zone block runs
  `vtm_day_wraparound(&vtm)` on the fields it hands to `zone_timelocal()`. When the fallback then takes the offset or
  UTC path, it gets those wrapped fields: April 31 24:00 has become April 32 00:00, stored as day 0, so the instant
  is March 31. The String path gets the unwrapped fields and gives May 2. On master this already shows for `to_str`
  `"+00:00"` (10 of 288 overflow pairs differ); on `8d626f3a52`, which made `"UTC"`/`"Z"`/`"-00:00"` take that path,
  it showed for those too (10 of 288 each; found by the thermos-opus confirm).

The other callers of `utc_offset_arg()` (`rb_time_num_new` for `Time.at(in:)`/`Time.now(in:)`, `time_zonelocal`
for `#localtime`, `time_getlocaltime`) check `off == UTC_ZONE` and call `validate_utc_offset()`, and they don't crash.

### Affected arguments (`.amp/in/orb-backup/tn2/probe.rb`, each case in a child process, TZ=America/New_York)

| argument | 3.3.13 / 3.4.12 / 4.0.9 / master | fixed |
|---|---|---|
| `to_str` → `"UTC"`, `"utc"`, `"Z"`, `"-00:00"`, `"-0000"`, `"-00"`, `"-00:00:00"`, `"-000000"`, positional | segfault | UTC, `utc?` true, same as the String |
| the same with `in:`, with hour 24, and `Time.new("2026-01-01 00:00:00", in: o)` | segfault | UTC |
| `to_str` → `"UTC"` plus `utc_to_local` but no `local_to_utc` | segfault | UTC |
| `to_str` → a name a converting `find_timezone` resolves | wrong instant (system local wall time) | same as the String name |
| `to_str` → `"+24:00"`, `"+25:00"`, `"-24:00"` | `+2400`, `+2500`, `-2400` | ArgumentError, as the String |
| `to_str` → `"+00:00"`, day past the month end at 24:00 | a month early (March 31 for April 31) | same as the String |
| `Time.find_timezone` returning the String `"UTC"` for a String name | segfault | UTC |
| `to_str` → `"+00:00"`, `"+09:00"`, `"-05:00"`, `"+23:59"`, `"-23:59:59"`, `"A"` | right (fixed offset) | unchanged |
| `to_str` → `"EST"`, `"Europe/Berlin"` with the default `find_timezone` | ArgumentError | unchanged |
| `Time.new(in: o)`, `Time.now(in: o)`, `Time.at(0, in: o)`, `t.localtime(o)`, `t.getlocal(o)` (`"UTC"`, `"Z"`) | UTC, no crash | unchanged |
| String subclass `"UTC"`/`"Z"`, a plain `"UTC"`, `Rational(3600)`, `Object.new` | right / TypeError | unchanged |

String subclasses are `T_STRING`, so `maybe_tzobj_p` rejects them and they take the first `utc_offset_arg()` branch,
which converts `UTC_ZONE`. The probe's output is identical on the three releases and master, and identical on the
two heads except the three out-of-range rows, which only the new head rejects.

### Fix

`d6d39dbf17`, time.c +7/−3: the zone block wraps a copy of the fields for the timezone object, and the fallback assigns to `utc` instead of `vtm.utc_offset`, returns after a successful
`find_timezone`/`zone_timelocal`, then converts with the String branch's own line and checks the offset with
`validate_utc_offset()`, the check `validate_vtm()` applies to the String branch. Setting `utc` makes the
`utc == UTC_ZONE` branch below run, as for a String `"UTC"`.

```diff
         time_set_timew(time, tobj, timegmw(&vtm));
-        vtm_day_wraparound(&vtm);
-        time_set_vtm(time, tobj, vtm);
+        struct vtm tvtm = vtm;
+        vtm_day_wraparound(&tvtm);
+        time_set_vtm(time, tobj, tvtm);
 ...
-        else if (NIL_P(vtm.utc_offset = utc_offset_arg(zone))) {
+        else if (NIL_P(utc = utc_offset_arg(zone))) {
             if (NIL_P(zone = find_timezone(time, zone)) || !zone_timelocal(zone, time))
                 invalid_utc_offset(arg);
+            return time;
         }
+        vtm.utc_offset = utc == UTC_ZONE ? INT2FIX(0) : utc;
+        validate_utc_offset(vtm.utc_offset);
     }
```

Tests:

* `test_new_with_zone_to_str` in test/ruby/test_time.rb: `"UTC"`, `"Z"`, `"-00:00"` positional, with `in:` at 24:00,
  and the string form with `in:` (`to_a` equal to the String's), April 31 24:00 equal to `Time.utc(2000, 5, 2)`
  (segfaults on master, fails on `8d626f3a52`), and `"+24:00"` raising "utc_offset out of range".
* `test_new_with_zone_name_to_str` in test/ruby/test_time_tz.rb (the reviewer's version): DummyTZ `Africa/Ndjamena`
  (+01:00) and `Asia/Tokyo` (+09:00) by name through `to_str`, instant `time_class.utc(2018, 1, 1, 12) - utc_offset`
  and offset. With only Ndjamena it passed on master under TZ=Europe/Berlin and Africa/Lagos (system offset equal to
  the zone's); Tokyo makes it fail there too.

On master (`tn2/newtests.sh`), under TZ=UTC, Europe/Berlin, Africa/Lagos, Asia/Tokyo and America/New_York, the first
segfaults the test process and the second fails in all five: Ndjamena 12:00 reads 13:00 +0100 (12:00 UTC) under UTC
and 18:00 +0100 (17:00 UTC) under New York, expected 11:00 UTC. On the head both pass under all five. On the head:

* `make btest`: PASS all 2148.
* `make test-all TESTS='ruby/test_time*'`: 246 tests, 2431 assertions, 0 failures (gem subtests skip there).
* test_time.rb + test_time_tz.rb through `tool/runruby.rb` with TZInfo 2.0.6 and timezone 1.3.32 on the load path
  (DummyTZ 52, GemTZInfo 49, GemTimezone 49 tests): 344 tests, 0 failures under TZ=UTC, Europe/Berlin, Africa/Lagos,
  Asia/Tokyo, America/New_York and Australia/Sydney.
* `make test-spec SPECOPTS=../ruby/spec/ruby/core/time`: 652 examples, 7876 expectations, 0 failures.
* The probe: as in the table, identical to `8d626f3a52`; `git merge-tree` with TN1's head d3e0a31795 is clean.
* Overflow pairs (`tn2/pairs.rb`: `to_str` against the String for 2000 and 2026, every month, days 28–31, hours 0,
  23 and 24, names UTC, Z, -00:00, +00:00, +09:00, -05:00, +05:30): 0 of 2,016 differ on the head alone and on the
  head merged with TN1. Master: crashes for the first three, 10 of 288 for +00:00; `8d626f3a52`: 10 of 288 for each
  of the first four.

Not run: the full test-all, hosted CI. (thermos-opus confirmed `d6d39dbf17` with nits only.)

### Rebase onto master e8167b0ddd (2026-11-25)

`ec3f27cd36` on `thomasklemm/time-new-to-str-utc-4`, Thomas as author and committer, no trailers. `git range-diff`
shows the patch identical to `d6d39dbf17`: time.c has no commits since 3a19e2efcf, and only test_time.rb's context
moved (a76ddf54a4 added a test). Master hasn't fixed it: no Redmine issue since 2026-11-18 is about Time, no ruby/ruby
PR updated since 2026-11-17 touches time.c, and the release branches' only time.c backport since 3.3.13, 3.4.12 and
4.0.9 is bb382ae5df (`time_init_parse` precision).

On master (`ruby 4.1.0dev (2026-11-25T11:44:00Z master e8167b0ddd) +PRISM [x86_64-linux]`) every example in the ticket below reproduces (`.amp/in/orb-backup/tn/repro.sh`, TZ=America/New_York):
the segfaults (positional `UTC`, `Z`, `-00:00`, `in:`, the string form, `find_timezone` returning `"UTC"`), `+2500`,
17:00 UTC for Plus3, and March 31 for `+00:00` at April 31 24:00. The head gives UTC, ArgumentError, 09:00 and May 2.
Tests on the head: `make test-all TESTS='ruby/test_time*'` 247 tests, 2438 assertions; test_time.rb + test_time_tz.rb
through `tool/runruby.rb` with TZInfo 2.0.6 and timezone 1.3.32 preloaded 345 tests, 3076 assertions, 0 failures
under TZ=UTC, Europe/Berlin, Africa/Lagos, Asia/Tokyo, America/New_York and Australia/Sydney (one more than before:
master's new test); spec/ruby/core/time 652 examples, 0 failures. Master with the head's tests:
`test_new_with_zone_to_str` segfaults, `test_new_with_zone_name_to_str` fails (13:00 +0100 under UTC, 18:00 +0100
under New York). Not run: btest, the full test-all, hosted CI.

### Prior reports

Redmine full-text searches (`to_str Time.new`, `Time.new segmentation`, `Time.new SEGV`, `UTC_ZONE`,
`utc_offset_arg`, `Time zone to_str`, `zone_timelocal`, `local_to_utc`, `Time.new timezone object`) and ruby/ruby
PR/issue searches (`Time.new to_str`, `UTC_ZONE`, `utc_offset_arg`, `time_init_vtm`, `Time.new zone`) found nothing.
The closest are [Bug #20327](https://bugs.ruby-lang.org/issues/20327) (Rational seconds with a zone object, closed)
and [Bug #20951](https://bugs.ruby-lang.org/issues/20951) (`utc_to_local` results, closed), neither on this
fallback. New.

### Ticket for bugs.ruby-lang.org (ready to paste, 2026-11-25)

Tracker Bug. Subject: **Time.new segfaults with a zone object that converts to "UTC"**.
ruby -v: `ruby 4.1.0dev (2026-11-25T11:44:00Z master e8167b0ddd) +PRISM [x86_64-linux]`. Description:

> ```ruby
> o = Object.new
> def o.to_str = "UTC"
> Time.new(2026, 1, 1, 0, 0, 0, o)  # [BUG] Segmentation fault at 0x0000000000000034
> ```
>
> The same happens for `"Z"` and `"-00:00"`, with `in:`, and with `Time.new("2026-01-01 00:00:00", in: o)`, on 3.3, 3.4, 4.0 and master. `Time.at(0, in: o)` and `Time#getlocal(o)` return UTC.
>
> A zone argument that isn't a String or an Integer is tried as a timezone object first. Without `local_to_utc`, `time_init_vtm()` falls back to `utc_offset_arg()`, and its `UTC_ZONE` result is used as an offset in `vtm_add_offset()`.
>
> A `Time.find_timezone` that returns the String `"UTC"` crashes the same way, without a `to_str` object:
>
> ```ruby
> def Time.find_timezone(n) = (n == "Mine" ? "UTC" : nil)
> Time.new(2026, 1, 1, 0, 0, 0, "Mine")  # [BUG] Segmentation fault
> ```
>
> The same fallback has two more problems. It doesn't range-check offsets: with `to_str` returning `"+25:00"` the result is `+2500`, where the String raises "utc_offset out of range". And when `Time.find_timezone` resolves the name, the time is computed from the system's local zone instead of that zone. `find_timezone` receives the object itself, so this needs one that converts it:
>
> ```ruby
> ENV["TZ"] = "America/New_York"
> class Plus3 # fixed +03:00
>   def local_to_utc(t) = Time.utc(t.year, t.mon, t.mday, t.hour, t.min, t.sec) - 10800
>   def utc_to_local(t) = Time.utc(t.year, t.mon, t.mday, t.hour, t.min, t.sec) + 10800
> end
> def Time.find_timezone(n) = (String(n) == "Plus3" ? Plus3.new : nil)
> o = Object.new
> def o.to_str = "Plus3"
> Time.new(2026, 1, 1, 12, 0, 0, "Plus3").getutc #=> 2026-01-01 09:00:00 UTC
> Time.new(2026, 1, 1, 12, 0, 0, o).getutc       #=> 2026-01-01 17:00:00 UTC
> ```
>
> Fix: https://github.com/thomasklemm/ruby/commit/ec3f27cd36
