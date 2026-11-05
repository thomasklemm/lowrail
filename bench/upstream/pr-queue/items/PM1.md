---
id: PM1
repo: rails/rails
kind: perf
area: Active Record QueryIntent
reviewer: matthewd (query-intent architecture)
branch: thomasklemm/query-intent-async-state
head: "8e7de36dbc"
base: main
built_on: "bdb3d96012"
depends_on: []
stacked_on:
alternative_of:
impact: "every QueryIntent 512 -> 256 B on Ruby master; ruby-bench slot bytes -0.8% to -1.0% per iteration"
rank: 11
risky: true
state: in-review
pr:
note: "risky: background session and mutex (thread state), so Astra is required"
passes:
  - {reviewer: sol, head: "9fabafcf8b", date: 2026-11-05, verdict: changes, open: lock_wait dup/freeze semantics; applied}
  - {reviewer: skeptic, head: "8e7de36dbc", date: 2026-11-05, verdict: approve, open: "third pass on the final version: ship"}
---

# Keep QueryIntent's background session and mutex together

`QueryIntent#initialize` presets [`@session` and `@mutex`](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activerecord/lib/active_record/connection_adapters/query_intent.rb#L102-L103), which only an intent scheduled by [`async_schedule!`](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activerecord/lib/active_record/connection_adapters/query_intent.rb#L390-L396) uses. With them every intent has 30 instance variables after `initialize` and 31 once its result is cast. Ruby master no longer has a 320-byte heap (ruby/ruby#16282), so each intent takes a 512-byte slot there.

This moves the two into an `AsyncState` struct that `async_schedule!` creates. Every intent, background ones included, now has 29 or 30 instance variables and fits a 256-byte slot. The foreground reads of these fields were already nil-safe. The unused `session` reader and writer (`:nodoc:`, unreleased) go away.

Heap slot bytes allocated per ruby-bench iteration (Σ slot size × objects allocated, from `GC.stat_heap`; 3 warmups, 10 iterations, fixed heap), Ruby master a041273a4c, main against itself within 0.005%:

| | main | this PR |
| --- | ---: | ---: |
| railsbench | 59,087,612 | 58,575,608 (−0.87%) |
| shipit | 52,044,134 | 51,542,168 (−0.96%) |
| lobsters | 33,485,554 | 33,214,610 (−0.81%) |

Object counts are approximately unchanged; a scheduled async intent allocates one struct more. On Ruby 4.0 an intent stays in a 320-byte slot either way.

---
<sub>Found while checking which Rails objects lost the 320-byte slot on Ruby master ([record](https://github.com/thomasklemm/lowrail/blob/d08c2967ba89b663180133ebbe97e873f3746c8a/docs/upstream/perf-round-main.md), part of my research project Lowrail).</sub>
