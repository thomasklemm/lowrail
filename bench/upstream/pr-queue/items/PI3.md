---
id: PI3
repo: rails/rails
kind: perf
area: "Active Support core_ext (Object#try)"
reviewer: "kamipo (author of 2709a9f16d, #58238)"
branch: thomasklemm/try-without-kwargs-hash
head: "fb8a27353222a2ea6ba9533ca8c5bfc9a33de564"
base: main
built_on: "7a78da5a55"
depends_on: []
stacked_on:
alternative_of:
impact: "Object#try without keywords: 2 -> 1 objects, 3,199 -> 2,794 interpreter Ir/call; blocked by public-API differences"
rank: 7
risky: false
state: held
pr:
note: "Coordinator agreed to hold under the two-round rule; keep fork branch, no further design investigation. Fresh main comparison: 2 -> 1 objects, 3,199 -> 2,794 Ir/call, A/A about 0.0001%. Anonymous forwarding loses the keyword snapshot during to_str/respond_to? and changes Hash-subclass empty? effects; the proposed body below is rejected, not ready to post. Evidence: docs/upstream/app-suites.md, Queue skeptic refresh."
passes:
  - {reviewer: sol, head: "1e3539559d", date: 2026-11-05, verdict: changes, open: identical behaviour with keywords and a block; applied in fb8a273532}
  - {reviewer: skeptic, head: "fb8a27353222a2ea6ba9533ca8c5bfc9a33de564", date: 2026-11-05, verdict: changes, open: "Reproduced on main+patch: method-name to_str mutates caller keywords, target sees before on main but after on head; Hash-subclass empty? raising gives RangeError on main but TypeError on head, clearing itself gives ArgumentError on main but TypeError on head. Held under two-round rule. Fixed-heap/A/A gain is real but not exact."}
---

# Don't allocate a keyword Hash in `Object#try` without keywords

2709a9f16d replaced `ruby2_keywords` in `Object#try` and `#try!` with a named `**kwargs` parameter. A named keyword splat builds a new Hash on every call, also when the caller passes no keywords, so each `try(:name)` on main allocates one object more than on Rails 8.1. `try` is common in gems as well as in apps; in a private Rails app with Inertia, inertia-rails' prop resolver calls it about 200 times per page, for flags like `try(:deferred?)`.

This forwards the keywords with an anonymous `**`, which avoids materializing the keyword Hash on Ruby 3.4 and later when no keywords are passed; there is no allocation improvement on Ruby 3.3. Only the block form still checks for keywords, through a private predicate, so behaviour is unchanged. The tests cover keyword forwarding through both methods, including an empty `**{}`, a positional Hash, keywords with a block, and keywords alone with a block, which still raises.

Callgrind instruction counts per `try(:deferred?)` call, Ruby 4.0.9 ([script](https://github.com/thomasklemm/lowrail/blob/main/bench/upstream/app_suites/try_micro.rb)):

| | main | this PR |
| --- | ---: | ---: |
| objects | 2 | 1 |
| instructions, interpreter | 3,362 | 2,835 |
| instructions, YJIT | 2,293 | 1,894 |

---
<sub>Found by running a private Rails app on main against 8-1-stable with [Lowrail](https://github.com/thomasklemm/lowrail), my research project: [app-suites](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md#private-rails-app-with-inertia-rails).</sub>
