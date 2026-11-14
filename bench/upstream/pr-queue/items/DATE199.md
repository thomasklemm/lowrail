---
id: DATE199
repo: ruby/date
kind: fix
area: Date#<=>
reviewer:
branch: thomasklemm/cmp-nan
head: "8a34d5a595324d561665326e975ff8ab45f816c0"
base: master
built_on: "2c48b11dde0fd173e61a91c10ea27ec616c09474"
depends_on: []
stacked_on:
alternative_of:
impact:
rank:
risky: false
state: ready
pr: 199
note: "Opened before the queue tracked it; item added 2026-11-14 so status watches it. Reworked 2026-11-14 onto 2c48b11 as two commits (Date#<=> nil for NaN with -1/0/1 normalization kept; step/upto/downto use rb_cmpint), force-pushed with a lease on f1d893f834. No pass yet on 8a34d5a; an independent review follows. Record: docs/upstream/contributions.md."
passes:
  - {reviewer: skeptic, head: "58d4ef92967425aeb3a3d9170086115dacafb0d1", date: 2026-11-14, verdict: changes, open: "cmp_gen correct, -1/0/1/nil kept. Must fix: step/upto/downto pass Date#<=> to FIX2INT, so a NaN limit gives TypeError on 64-bit Linux and, by the Ruby 4.0 header, an endless downto where int and long are the same size; fixed as a second commit. Nits applied: drop the ajd local, DateTime case at noon UTC. Title nit kept to match the PR."}
  - {reviewer: sol, head: "f1e916ea731a3417d1fc2d8c9d06966c3b85c512", date: 2026-11-14, verdict: changes, open: "C code and commit split approved. Applied: step(limit, 1) assertions, yielding blocks flunk instead of {}, commit 2 message states only the verified TypeError, body says the comparisons in step/upto/downto raise. Not applied, by Thomas: asserting d < Float::NAN (Comparable, dropped on purpose)."}
---

# Return nil from Date#<=> for a NaN

Thank you for maintaining date.

`Date#<=>` raises `ArgumentError` when the other value is `Float::NAN` or `BigDecimal("NaN")`, and `Date#==` raises with it, while `1 <=> Float::NAN`, `Rational(1) <=> Float::NAN` and `Time.now <=> Float::NAN` return `nil`. `cmp_gen` passes the result of `ajd <=> other` to `rb_cmpint`, which turns the `nil` from `Rational#<=>` into that exception.

This returns `nil` when `ajd <=> other` does and still normalizes other values to -1, 0 or 1. `Date <=> NaN` is now `nil` and `Date == NaN` is `false`, while `Date < NaN` still raises `ArgumentError`, as `Comparable` does for `Time` and `Rational`. The second commit makes the comparisons in `step`, `upto` and `downto` raise `ArgumentError` for a limit that `Date#<=>` can't compare, instead of passing `nil` to `FIX2INT`. The suite passes on Ruby 4.0.9 and master.

---

<sub>Found while comparing Active Model's `changed?` on Rails 8.1 and main with random attribute values, where a NaN assigned to a date attribute raised ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/rails-82-differential.md#changed-and-nan-a-rubydate-bug), part of my research project Lowrail).</sub>
