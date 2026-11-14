---
id: QL1
repo: rails/rails
kind: perf
area: Active Record, request log line (ControllerRuntime)
reviewer: "fatkodima (added the query count to the line), jhawthorn (sped up pluralize in #59651)"
branch: thomasklemm/controller-runtime-query-literal
head: "ce6d06884094c58baec9b6cf66eb4cc2df0ad51f"
base: main
built_on: "50c54eed06"
depends_on: []
stacked_on:
alternative_of:
impact: "Every request of every app with Active Record at the default info log level runs \"query\".pluralize(count) for its Completed line when the count isn't 1 (43k interpreter instructions, 6 objects a call). Whole request, Callgrind interpreter: new app's JSON bare request -3.84% (A/A -0.03%), JSON show with 2 queries -1.03%, HTML bare page -1.77% (A/A -0.59%), HTML show -0.92%; 6 fewer objects. Vernier YJIT: the pluralize is about 2% of a new API app's bare JSON request. benchmark-ips on log_process_action 245.1k -> 792.6k i/s (3.2x, YJIT, best of 5, A/A -2.5%). Lifetime: Rails main and 8.x; runs on every Ruby."
rank: 14
risky: false
state: built
pr:
note: "DEF8 (docs/upstream/rails8-defaults.md). Unchanged for counts 0..2000 under default inflections; differs only for an app with its own English inflection for \"query\" (log text). Not yet run: the micro on Ruby master x ZJIT (no master build in the DEF8 orb). Suites: actionview test:integration:active_record 177 runs 0 failures; controller_runtime_test 5 runs."
passes: []
---

# Spell out "query" and "queries" in the request log line

The `Completed` line that every request logs in an app with Active Record ends in something like `ActiveRecord: 0.4ms (2 queries, 0 cached)`. The word comes from `"query".pluralize(queries_count)`, which runs the inflector's English rules on every request whose query count isn't 1.

The count is an Integer, so this writes out "query" for 1 and "queries" otherwise. The line only differs for an app that defines its own inflection for "query".

```ruby
require "action_controller"
require "active_record"
require "active_record/railties/controller_runtime"
require "benchmark/ips"

ActionController::Base.include ActiveRecord::Railties::ControllerRuntime
payload = { view_runtime: 1.2, db_runtime: 0.4, queries_count: 2, cached_queries_count: 0 }

Benchmark.ips do |x|
  x.report("log_process_action") { ActionController::Base.log_process_action(payload) }
end
```

```
ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +YJIT +PRISM [x86_64-linux]

before: log_process_action    245.107k (± 4.1%) i/s    (4.08 μs/i) -      1.229M in   5.014108s
after:  log_process_action    792.623k (± 5.4%) i/s    (1.26 μs/i) -      3.998M in   5.044020s
```

In a new app's full request without queries, that is 6 fewer objects and 2 to 4 percent fewer instructions without JIT.

---

<sub>Found while measuring the request path of a new Rails app ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/rails8-defaults.md)).</sub>
