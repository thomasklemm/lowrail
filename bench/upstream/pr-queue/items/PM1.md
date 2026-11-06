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
state: closed
pr: 59673
note: "held: #59673 closed 2026-11-05 (Thomas) for low impact: no change on Ruby 4.0, 256 B per query only on Ruby master, no per-request evidence. Revisit after Ruby 4.1 is released and measure GC per request; branch kept"
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

This moves the two into a struct that `async_schedule!` creates, so an intent has one instance variable fewer and fits a 256-byte slot in these queries. Objects per query are unchanged in foreground queries; scheduling a background query allocates the struct.

Heap slot bytes allocated per query, Ruby master:

| | main | this PR |
| --- | ---: | ---: |
| `Post.find(1)` | 4,088 | 3,832 |
| `Post.where(n: 1).to_a` | 5,592 | 5,336 |
| `update_all` | 5,120 | 4,864 |

---
<sub>Found while checking which Rails objects lost the 320-byte slot on Ruby master ([record](https://github.com/thomasklemm/lowrail/blob/9874d3f115aa081699a9e6ec3611e40cc4b3658c/docs/upstream/perf-round-main.md#refresh-on-main-1e235cee11-2026-11-05-evening), part of my research project Lowrail).</sub>
