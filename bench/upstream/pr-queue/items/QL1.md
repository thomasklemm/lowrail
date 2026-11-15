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
impact: "Every request of every app with Active Record at the default info log level runs \"query\".pluralize(count) for its Completed line when the count isn't 1 (43k interpreter instructions, 6 objects a call). Whole request, Callgrind interpreter: new app's JSON bare request -3.84% (A/A -0.03%), JSON show with 2 queries -1.03%, HTML bare page -1.77% (A/A -0.59%), HTML show -0.92%; 6 fewer objects. Vernier YJIT: the pluralize is about 2% of a new API app's bare JSON request. benchmark-ips on log_process_action 245.1k -> 792.6k i/s (3.2x, YJIT, best of 5, A/A -2.5%). Lifetime: Rails main, 8.x and 7.2; runs on every Ruby."
rank: 14
risky: false
state: in-review
pr:
note: "DEF8 (docs/upstream/rails8-defaults.md). Unchanged for counts 0..2000 under default inflections; differs only for an app whose English inflections pluralize \"query\" differently: an irregular or uncountable for it, or a generic rule such as /y$/ (log text). Optional, not done: a 2-query test case (the mutant zero? ? \"queries\" : \"query\" passes the suite). Not yet run: the micro on Ruby master x ZJIT (no master build in the DEF8 orb). Suites: actionview test:integration:active_record 177 runs 0 failures; controller_runtime_test 5 runs."
passes:
  - {reviewer: claude-code, head: "ce6d06884094c58baec9b6cf66eb4cc2df0ad51f", orb: T-01a1dc64-bf9b-767f-a931-99cff8cc12ab, date: 2026-11-15, verdict: changes, open: "Must-fix (body): the Completed line ends in '| GC: ...ms)', not the ActiveRecord part; 'ends in' -> 'includes'. Optional: add a 2-query case to controller_runtime_test.rb (zero? ? 'queries' : 'query' passes the suite); word the boundary as an English inflection that changes the plural of 'query' (/y$/ or clear(:plurals) too); 3.2x rests on one outlier run (3.0-3.1x here); lifetime includes 7.2. Evidence: author/committer Thomas, no trailers, diff --check clean, no comments; controller_runtime.rb on main identical to 50c54eed06; probe of log_process_action identical for -3..30, 99-101, 1,000, 2,000, 2**40, 2**70, nil, missing key, 0.0, 1.0, 1.5, 2.5, Rational, BigDecimal, Complex, '1', duck-typed counts, Symbol and Object (same TypeError) and a :de inflection; differs only for :en irregular, uncountable, plural /y$/ and clear(:plurals); the count is RuntimeRegistry's Integer; Callgrind micro pluralize(2) 43,100 Ir vs 805 literal; objects 10 -> 4 (counts 0, 2, 5), 5 -> 4 (count 1); actionview test:integration:active_record 177 runs and controller_runtime_test 5 runs green on both; ir.sh interp bare page -1.81% (A/A -0.18%, -6 objects), show -0.66%, index +0.03%; ips ql_ips.rb (core 1, YJIT, best of 5) 237.8k, A/A 233.8k (-1.7%), branch 710.0k, 3.0x (first set 3.1x); prior art none; fatkodima authored 6369e92fbb, #59651 merged 11-05. Not run: ZJIT, Vernier 2%."}
  - {reviewer: opus, head: "ce6d06884094c58baec9b6cf66eb4cc2df0ad51f", orb: T-01a1dc64-c914-71e3-b32d-db2e5e85f50f, date: 2026-11-15, verdict: changes, open: "Changes, body only; code exact. Must-fix 1: the Completed line ends in '| GC: ...ms)'; 'ends in' -> 'includes'. Must-fix 2: '2 to 4 percent' too high for the HTML page (1.43% here, record 1.77%); -> 'up to 4 percent fewer instructions without JIT'. Optional: a generic /y$/ rule also changes the word ('whose English inflections pluralize query differently'); lifetime names 7.2 (7-2, 8-0, 8-1-stable have the pluralize); == 0 ? 'queries' : 'query' survives the tests. Evidence: author/committer Thomas, no trailers, diff --check clean, no comments; probe identical for nil, 0..3, -1, -3, 21, 101, 2**64, 0.0, 1.0, 2.5, Rational 1/1 and 3/2, BigDecimal 1 and 2, Complex(1,0), '1', '2', :foo and true (TypeError either way), payloads without queries_count or db_runtime, and a :de inflection; 'query'.pluralize(n) equals the literal for -3..100,000; differs for English irregular, uncountable and /y$/ rules, and a duck-typed count no longer receives is_a?(Symbol) (counts are Integers); actionview AR integration 177 runs 344 assertions, controller_runtime_test 5 runs, 0 failures; swapped and always-queries mutants fail 2 tests each; Callgrind interp API JSON bare 1,287,056 -> 1,241,257 -3.56% (A/A -0.18%), 306 -> 300 objects; HTML bare 2,789,331 -> 2,749,455 -1.43%, 785 -> 779; ips body script (YJIT, core 1, best of 5) 292.4k -> 968.8k 3.3x (A/A +6.4%, 3.1x against it); prior art none. Not checked: Vernier 2%, ZJIT."}
---

# Spell out "query" and "queries" in the request log line

The `Completed` line that every request logs in an app with Active Record includes something like `ActiveRecord: 0.4ms (2 queries, 0 cached)`. The word comes from `"query".pluralize(queries_count)`, which runs the inflector's English rules on every request whose query count isn't 1.

The count is an Integer, so this writes out "query" for 1 and "queries" otherwise. The line only differs for an app whose English inflections pluralize "query" differently.

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

In a new app's full request without queries, that is 6 fewer objects and up to 4 percent fewer instructions without JIT.

---

<sub>Found while measuring the request path of a new Rails app ([record](https://github.com/thomasklemm/lowrail/blob/7b7f24bf8985eed81bcb20aca6157384cde2dab6/docs/upstream/rails8-defaults.md)).</sub>
