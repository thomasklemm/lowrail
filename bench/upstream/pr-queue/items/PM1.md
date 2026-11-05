---
id: PM1
repo: rails/rails
kind: perf
area: Active Record, query intents
reviewer: matthewd (author of QueryIntent)
branch: thomasklemm/query-intent-async-state
head: "5e26a026f1"
base: main
built_on: "1e235cee11"
depends_on: []
stacked_on:
alternative_of:
impact: on Ruby master every query intent fits a 256-byte slot instead of 512, 256 B less per query; no change on Ruby 4.0
rank: 11
risky: true
state: in-review
pr:
note: rebased from 8e7de36dbc (bdb3d96012) onto 1e235cee11; struct comment reworded; numbers refreshed on 1e235cee11; waits for Sol and Astra on 5e26a026f1
passes:
  - {reviewer: skeptic, head: "9fabafcf8b", date: 2026-11-05, verdict: approve, open: ""}
  - {reviewer: sol, head: "9fabafcf8b", date: 2026-11-05, verdict: changes, open: "lock_wait in the struct changed dup/freeze; applied in 8e7de36dbc"}
  - {reviewer: skeptic, head: "8e7de36dbc", date: 2026-11-05, verdict: approve, open: ""}
  - {reviewer: skeptic, head: "4957872cea", date: 2026-11-05, verdict: nits, open: "ivar count wording (RangeError fallback corner reaches 31, main 32); applied in 5e26a026f1"}
  - {reviewer: skeptic, head: "5e26a026f1", date: 2026-11-05, verdict: approve, open: "async_schedule! link to L397, applied (body only)"}
---

# Keep QueryIntent's background session and mutex together

`QueryIntent#initialize` presets [`@session` and `@mutex`](https://github.com/rails/rails/blob/1e235cee11b0a7aecb189d8837534807626287aa/activerecord/lib/active_record/connection_adapters/query_intent.rb#L102-L103), which only an intent scheduled by [`async_schedule!`](https://github.com/rails/rails/blob/1e235cee11b0a7aecb189d8837534807626287aa/activerecord/lib/active_record/connection_adapters/query_intent.rb#L390-L397) uses. With them an intent has 30 instance variables after `initialize` and 31 once its result is cast. Ruby master no longer has a 320-byte heap (ruby/ruby#16282), so each intent takes a 512-byte slot there.

This moves the two into an `AsyncState` struct that `async_schedule!` creates. Every intent, background ones included, now has one instance variable fewer at every point (29 after `initialize`, 30 once cast) and fits a 256-byte slot. The foreground reads of these fields were already nil-safe. The unused `session` reader and writer (`:nodoc:`, unreleased) go away.

Heap slot bytes allocated per query, Ruby master (main against itself: identical):

| | main | this PR |
| --- | ---: | ---: |
| `Post.find(1)` | 4,088 | 3,832 |
| `Post.where(n: 1).to_a` | 5,592 | 5,336 |
| `update_all` | 5,120 | 4,864 |

Objects per query are unchanged. On Ruby 4.0 an intent stays in a 320-byte slot either way.

<details><summary>Method</summary>

[`qi_bytes.rb`](https://github.com/thomasklemm/lowrail/blob/a06703e89dd41af36cf7a923103be3e7ec7be9a5/bench/upstream/perf_round/qi_bytes.rb) at Lowrail a06703e89d: SQLite in memory, 500 warmup calls, then 2,000 calls with GC disabled; bytes = Σ over heaps of slot size × objects allocated, from `GC.stat_heap`. Ruby master 2a3b7678ff, main 1e235cee11 against this branch and a second checkout of main.

```
RAILS_PATH=path/to/rails ruby qi_bytes.rb 2000
```

Instructions do not move: Callgrind, Ruby 4.0.9 interpreter, 2,000 `Post.find` calls after 2,000 warmups, Ir per call, inclusive, two runs each: main 316,608 / 316,759, main again 316,581 / 316,786, this PR 316,412 / 316,384.

</details>

---
<sub>Found while checking which Rails objects lost the 320-byte slot on Ruby master ([record](https://github.com/thomasklemm/lowrail/blob/9874d3f115aa081699a9e6ec3611e40cc4b3658c/docs/upstream/perf-round-main.md#refresh-on-main-1e235cee11-2026-11-05-evening), part of my research project Lowrail).</sub>
