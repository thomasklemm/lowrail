### Read the logger once in EventReporter::LogSubscriber#emit and #consumes?

[`emit` and `consumes?`](https://github.com/rails/rails/blob/bdb3d960121e7eb73a61c04099d1eef3c821e397/activesupport/lib/active_support/event_reporter/log_subscriber.rb#L56-L88) look up `logger` for the nil check and then again in `log_level_satisfied?`. Each lookup goes from `self.class.logger` to `@logger || default_logger`, such as `ActionController::Base.logger`. This passes the logger they already have to `log_level_satisfied?`. The framework's subscribers only define `default_logger`; none overrides these methods.

`consumes?` runs for each `emitting?` check that a structured event subscriber makes before it builds an event (81d95a3f74), so the lookup is on every request.

Callgrind instructions per call, Ruby 4.0.9 interpreter, in the railsbench app (main against itself within 0.1%):

| | main | this PR |
| --- | ---: | ---: |
| `LogSubscriber#consumes?` | 13,789 | 11,621 (−15.7%) |
| `EventReporter#emitting?` | 27,813 | 25,640 (−7.8%) |

Per railsbench iteration (4,000 `emitting?` calls) that is 8.3M fewer instructions.

---
<sub>Found by comparing Rails main with 8-1-stable on ruby-bench with Callgrind ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/perf-round-main.md), part of my research project Lowrail).</sub>
