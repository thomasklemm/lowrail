---
id: PM3
repo: rails/rails
kind: perf
area: Active Support, event reporter
reviewer: gmcgibbon (EventReporter::LogSubscriber, aebcb61520), amatsuda (consumes?, 81d95a3f74)
branch: thomasklemm/log-subscriber-logger-once
head: "defa5dc860"
base: main
built_on: "1e235cee11"
depends_on: []
stacked_on:
alternative_of:
impact: LogSubscriber#consumes? −17% and EventReporter#emitting? −13% instructions per call; Action Controller asks emitting? twice per action
rank: 13
risky: false
state: in-review
pr:
note: rebased from cec8010a8b (bdb3d96012) onto 1e235cee11; tests for a logger that changes between calls added (Sol 20:09); numbers refreshed; waits for Sol on defa5dc860
passes:
  - {reviewer: sol, head: "cec8010a8b", date: 2026-11-05, verdict: changes, open: "first review: disclosure, arity, numbers, links; applied in the body"}
  - {reviewer: skeptic, head: "cec8010a8b", date: 2026-11-05, verdict: approve, open: ""}
  - {reviewer: sol, head: "cec8010a8b", date: 2026-11-05, verdict: changes, open: "20:09: snapshot untested, perf method not reproducible, 'on every request' overstated"}
  - {reviewer: skeptic, head: "b6bbf99a51", date: 2026-11-05, verdict: nits, open: "add an info-then-nil case, list both commands; applied in defa5dc860"}
  - {reviewer: skeptic, head: "defa5dc860", date: 2026-11-05, verdict: approve, open: ""}
---

# Read the logger once in EventReporter::LogSubscriber#emit and #consumes?

[`emit` and `consumes?`](https://github.com/rails/rails/blob/1e235cee11b0a7aecb189d8837534807626287aa/activesupport/lib/active_support/event_reporter/log_subscriber.rb#L56-L88) look up `logger` for the nil check and then again in `log_level_satisfied?`. Each lookup goes from `self.class.logger` to `@logger || default_logger`, such as `ActionController::Base.logger`. This passes the logger they already have to `log_level_satisfied?`, so the level check uses the logger from the nil check, even if a `logger` override would return another one on a second call; the new tests cover that, including lookups that return nil. The framework's subscribers choose their logger through `default_logger` and don't override these methods or call the private helper, whose arity changes.

`EventReporter#emitting?` asks `consumes?` before an event is built ([81d95a3f74](https://github.com/rails/rails/commit/81d95a3f744ee504ecb9835293bda0a808cc56cf)); Action Controller's structured event subscriber asks it [twice per action](https://github.com/rails/rails/blob/1e235cee11b0a7aecb189d8837534807626287aa/actionpack/lib/action_controller/structured_event_subscriber.rb#L10-L30).

Callgrind instructions per call, Ruby 4.0.9 interpreter (main against itself within 0.12%):

| | main | this PR |
| --- | ---: | ---: |
| `ActionController::LogSubscriber#consumes?` | 12,805 | 10,591 (−17.3%) |
| `EventReporter#emitting?` | 16,878 | 14,662 (−13.1%) |

<details><summary>Method</summary>

Lowrail a06703e89d, [`percall.sh`](https://github.com/thomasklemm/lowrail/blob/a06703e89dd41af36cf7a923103be3e7ec7be9a5/bench/upstream/perf_round/percall.sh) with [`cases/er_none.rb`](https://github.com/thomasklemm/lowrail/blob/a06703e89dd41af36cf7a923103be3e7ec7be9a5/bench/upstream/perf_round/cases/er_none.rb): Action Controller loaded, `ActionController::Base.logger` an info-level `ActiveSupport::Logger`, `action_controller.request_started`. Callgrind counts only the timed loop: 2,000 calls after 2,000 warmups, GC disabled, fixed heap; Ir per call is inclusive (the method, everything it calls and the loop's block call, the same on both sides). Three runs each of main 1e235cee11, a second main checkout and this branch; the table shows the first; all runs of main agree within 19 Ir.

```
percall.sh cases/er_none.rb consumes 2000 3 path/to/main path/to/main-2 path/to/branch
percall.sh cases/er_none.rb emitting 2000 3 path/to/main path/to/main-2 path/to/branch
```

</details>

---
<sub>Found by comparing Rails main with 8-1-stable on ruby-bench with Callgrind ([record](https://github.com/thomasklemm/lowrail/blob/9874d3f115aa081699a9e6ec3611e40cc4b3658c/docs/upstream/perf-round-main.md#refresh-on-main-1e235cee11-2026-11-05-evening), part of my research project Lowrail).</sub>
