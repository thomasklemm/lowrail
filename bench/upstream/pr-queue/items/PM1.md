---
id: PM1
repo: rails/rails
kind: perf
area: Active Record, query intents
reviewer: matthewd (author of QueryIntent)
branch: thomasklemm/query-intent-async-state
head: "68c907bbeb"
base: main
built_on: "1e235cee11"
depends_on: []
stacked_on:
alternative_of:
impact: on Ruby master an intent in the measured query shapes fits a 256-byte slot instead of 512, 256 B less per query; on Ruby 4.0 the same shapes stay at 320 B
rank: 11
risky: true
state: draft
pr: 59673
note: "reviewed: skeptic, Sol and Astra approve on 68c907bbeb under the contract (public API and Rails' callers identical, claims scoped)"
passes:
  - {reviewer: skeptic, head: "9fabafcf8b", date: 2026-11-05, verdict: approve, open: ""}
  - {reviewer: sol, head: "9fabafcf8b", date: 2026-11-05, verdict: changes, open: "lock_wait in the struct changed dup/freeze; applied in 8e7de36dbc"}
  - {reviewer: skeptic, head: "8e7de36dbc", date: 2026-11-05, verdict: approve, open: ""}
  - {reviewer: skeptic, head: "4957872cea", date: 2026-11-05, verdict: nits, open: "ivar count wording (RangeError fallback corner reaches 31, main 32); applied in 5e26a026f1"}
  - {reviewer: skeptic, head: "5e26a026f1", date: 2026-11-05, verdict: approve, open: "async_schedule! link to L397, applied (body only)"}
  - {reviewer: sol, head: "5e26a026f1", date: 2026-11-05, verdict: changes, open: "every-intent claim false on the async RangeError/affected_rows path; objects claim; no lock_wait test; comment; method SHAs; applied in 68c907bbeb"}
  - {reviewer: astra, head: "5e26a026f1", date: 2026-11-05, verdict: changes, open: "fix first; applied in 68c907bbeb"}
  - {reviewer: skeptic, head: "68c907bbeb", date: 2026-11-05, verdict: approve, open: "test stable over 20 runs incl. under load; no Rails caller of session/session= or nil session"}
  - {reviewer: sol, head: "68c907bbeb", date: 2026-11-05, verdict: changes, open: "body only: disclose nil-session pending?/canceled?/ensure_result and execute_or_wait NullLock changes as unreachable; scope Ruby 4.0 claims; applied (body). Optional: split test, assert ran_async (skipped, keeps head)"}
  - {reviewer: astra, head: "68c907bbeb", date: 2026-11-05, verdict: changes, open: "body only, same as Sol; applied (body)"}
  - {reviewer: sol, head: "68c907bbeb", date: 2026-11-05, verdict: approve, open: "body confirm pass: disclosures accurate, Ruby 4.0 claims scoped"}
  - {reviewer: astra, head: "68c907bbeb", date: 2026-11-05, verdict: approve, open: "body confirm pass"}
---

# Keep QueryIntent's background session and mutex together

`QueryIntent#initialize` presets [`@session` and `@mutex`](https://github.com/rails/rails/blob/1e235cee11b0a7aecb189d8837534807626287aa/activerecord/lib/active_record/connection_adapters/query_intent.rb#L102-L103), which only an intent scheduled by [`async_schedule!`](https://github.com/rails/rails/blob/1e235cee11b0a7aecb189d8837534807626287aa/activerecord/lib/active_record/connection_adapters/query_intent.rb#L390-L397) uses. With them an intent has 30 instance variables after `initialize` and 31 once its result is cast. Ruby master no longer has a 320-byte heap ([ruby/ruby#16282](https://github.com/ruby/ruby/pull/16282)), so such an intent takes a 512-byte slot there.

This moves the two into an `AsyncState` struct that `async_schedule!` creates, so an intent has one instance variable fewer at every point and the query shapes below fit a 256-byte slot. A background intent that falls back to the foreground, hits a bind `RangeError` and is then read through `affected_rows` ends with 31 (main: 32). The unused `session` reader and writer (`:nodoc:`, unreleased) go away. Two internal changes are unreachable from Rails, whose only scheduler passes `asynchronous_queries_session` (a session, or it raises): an intent scheduled with a nil session now raises in `pending?`/`canceled?` instead of returning nil, and `ensure_result` checks the wrapper rather than the session; the private `execute_or_wait` on an unscheduled intent no longer falls back to `NullLock`. A new test checks that a copy or a frozen intent keeps its own `lock_wait`.

Heap slot bytes allocated per query, Ruby master (main against itself: identical):

| | main | this PR |
| --- | ---: | ---: |
| `Post.find(1)` | 4,088 | 3,832 |
| `Post.where(n: 1).to_a` | 5,592 | 5,336 |
| `update_all` | 5,120 | 4,864 |

Objects per query are unchanged in these foreground queries; scheduling a background query allocates one struct. On Ruby 4.0 an intent in these query shapes stays in a 320-byte slot either way.

<details><summary>Method</summary>

Rails main [`1e235cee11`](https://github.com/rails/rails/commit/1e235cee11b0a7aecb189d8837534807626287aa) against this branch at [`68c907bbeb`](https://github.com/thomasklemm/rails/commit/68c907bbeb6f03af43d15ddbcfe6137487c4ee36) and a second checkout of main. Lowrail [`a06703e89d`](https://github.com/thomasklemm/lowrail/tree/a06703e89dd41af36cf7a923103be3e7ec7be9a5/bench/upstream/perf_round).

Bytes: [`qi_bytes.rb`](https://github.com/thomasklemm/lowrail/blob/a06703e89dd41af36cf7a923103be3e7ec7be9a5/bench/upstream/perf_round/qi_bytes.rb) on Ruby master [`2a3b7678ff`](https://github.com/ruby/ruby/commit/2a3b7678ff31dbe70f2131314aa34879559367db): SQLite in memory, 500 warmup calls, then 2,000 calls with GC disabled; bytes = Σ over heaps of slot size × objects allocated, from `GC.stat_heap`.

```
RAILS_PATH=path/to/rails path/to/ruby-master/bin/ruby qi_bytes.rb 2000
```

Instructions: Ruby 4.0.9 ([`3e93b23afc`](https://github.com/ruby/ruby/commit/3e93b23afcec3433f6aecc34b5d832799d754238)) interpreter, Callgrind on the timed loop only, 2,000 `Post.find` calls after 2,000 warmups, GC disabled, fixed heap, inclusive Ir per call, three runs per tree. The difference is negligible: main 316,755 / 316,605 / 316,571, main again 316,809 / 316,771 / 316,579, this PR 316,420 / 316,596 / 316,575.

```
WARMUP=2000 RUBY=path/to/ruby-4.0.9/bin/ruby percall.sh cases/qi.rb find 2000 3 path/to/main path/to/main-2 path/to/branch
```

</details>

---
<sub>Found while checking which Rails objects lost the 320-byte slot on Ruby master ([record](https://github.com/thomasklemm/lowrail/blob/9874d3f115aa081699a9e6ec3611e40cc4b3658c/docs/upstream/perf-round-main.md#refresh-on-main-1e235cee11-2026-11-05-evening), part of my research project Lowrail).</sub>
