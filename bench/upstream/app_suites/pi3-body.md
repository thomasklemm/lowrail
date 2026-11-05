### Don't allocate a keyword Hash in `Object#try` without keywords

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
