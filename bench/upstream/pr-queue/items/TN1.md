---
id: TN1
repo: ruby/ruby
kind: fix
area: time.c, Time.new with a UTC offset or timezone object
reviewer: "jeremyevans (approved #16469), nobu (time.c)"
branch: thomasklemm/time-new-normalize-mday
head: "d3e0a31795"
base: master
built_on: "c2c5ac6d1b"
depends_on: []
stacked_on:
alternative_of:
impact: "Time.new(2026, 2, 31, 23, 0, 0, \"-05:00\") is a month early (2026-01-30), and with a timezone object #day/#inspect read April 31; one call moved so every zone path normalizes month-mday"
rank: 5
risky: false
state: built
pr:
note: "Both findings from the rails/rails#59617 review; one root cause, one fix (docs/upstream/ruby-time-new.md). Commit 1 is khasinski's 5f4d01cd26 from the open ruby/ruby#16469 (Bug #21301), cherry-picked with authorship kept; commit 2 moves its vtm_normalize_month_mday() call to right after validate_vtm(). Built and tested in orb T-01a1ebb7-3c99-7036-8f87-f511fbc24e61: the new tests fail on master (10/10) and pass on the fix; test_time*.rb 250 tests and 303 with TZInfo, btest 2148, spec/ruby/core/time 652 examples, all green; the sweep shows 0 of 576,600 differ per zone kind (1,000 offset, 10,075 zone-object fields on master). Unreported: the offset case and the zone-object case are not on Redmine. Not to open now (ruby/ruby moratorium); Thomas decides between a note on Bug #21301 with the draft in the doc, and a PR with both commits only if it doesn't step on #16469. No passes yet."
passes: []
---

# Normalize month-mday in Time.new before every zone path

On Ruby master, `Time.new` misplaces day 31 of a shorter month when a negative UTC offset moves it to the next day in UTC, and with a timezone object it keeps the unnormalized day:

```ruby
Time.new(2026, 2, 31, 23, 0, 0, "-05:00") #=> 2026-01-30 23:00:00 -0500, expected 2026-03-03 23:00:00 -0500
Time.new(2026, 4, 31, 2, 0, 0, TZInfo::Timezone.get("Australia/Sydney")).day #=> 31, expected 1
```

This builds on #16469 ([Bug #21301](https://bugs.ruby-lang.org/issues/21301)), whose commit is kept as the first one. Its `vtm_normalize_month_mday()` runs only in the `"UTC"` branch of `time_init_vtm()`. The second commit calls it right after `validate_vtm()` instead, so the offset, timezone object and local paths start from a valid date too. With an offset, `vtm_add_day()` turned day 31 into 32, which the 5-bit `mday` stores as 0. With a timezone object, the fields were cached as given.
