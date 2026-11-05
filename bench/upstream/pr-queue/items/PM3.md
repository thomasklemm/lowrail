---
id: PM3
repo: rails/rails
kind: perf
area: Active Support EventReporter
reviewer: unknown
branch: thomasklemm/log-subscriber-logger-once
head: "cec8010a8b"
base: main
built_on: "bdb3d96012"
depends_on: []
stacked_on:
alternative_of:
impact: "EventReporter::LogSubscriber consumes? -15.7%, emitting? -7.8% Ir per call; railsbench -8.3M Ir per iteration"
rank: 13
risky: false
state: held
pr:
note: "fix first (Sol 20:09): the logger snapshot is untested, the body needs a reproducible benchmark method, and 'on every request' overstates it; P2 is on it"
passes:
  - {reviewer: sol, head: "cec8010a8b", date: 2026-11-05, verdict: changes, open: "first review: disclosure, arity, numbers, links; applied in the body"}
  - {reviewer: sol, head: "cec8010a8b", date: 2026-11-05, verdict: changes, open: "20:09: untested snapshot, benchmark method"}
---

# Read the logger once in EventReporter::LogSubscriber#emit and #consumes?

[`emit` and `consumes?`](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activesupport/lib/active_support/event_reporter/log_subscriber.rb#L56-L88) look up `logger` for the nil check and then again in `log_level_satisfied?`. Each lookup goes from `self.class.logger` to `@logger || default_logger`, such as `ActionController::Base.logger`. This passes the logger they already have to `log_level_satisfied?`, so the level check now uses the logger from the nil check, even if a `logger` override would return a different one on the second call. The framework's subscribers customize logger selection through `default_logger` and don't override these methods or call the private helper, whose arity changes.

`consumes?` runs for each `emitting?` check that a structured event subscriber makes before it builds an event ([81d95a3f74](https://github.com/rails/rails/commit/81d95a3f744ee504ecb9835293bda0a808cc56cf)), so the lookup is on every request.

Callgrind instructions per call, Ruby 4.0.9 interpreter, in the railsbench app (main against itself within 0.1%):

| | main | this PR |
| --- | ---: | ---: |
| `LogSubscriber#consumes?` | 13,789 | 11,621 (−15.7%) |
| `EventReporter#emitting?` | 27,813 | 25,640 (−7.8%) |

A separate sampled railsbench window, with 4,000 `emitting?` calls per iteration, measured 8.3M fewer instructions per iteration (A/A 0.29M).

---
<sub>Found by comparing Rails main with 8-1-stable on ruby-bench with Callgrind ([record](https://github.com/thomasklemm/lowrail/blob/d08c2967ba89b663180133ebbe97e873f3746c8a/docs/upstream/perf-round-main.md), part of my research project Lowrail).</sub>
