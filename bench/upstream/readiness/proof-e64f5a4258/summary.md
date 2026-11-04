# Rails readiness: e64f5a4258 against 6e09124217

Base `6e09124217` (8.1.4.1), candidate `e64f5a4258` (8.2.0.alpha), ruby 4.0.9, seeds 4242 and 1717 (run 1 and run 2 on both trees). Generated 2026-11-04T20:15:02Z.

| Suite | Ref | Base runs | Candidate runs | Flags | Lock difference besides Rails |
| --- | --- | --- | --- | --- | --- |
| lograge | `v0.15.1` (`106e8333d6`) | 134 / 3F, 134 / 32F | 134 / 7F, 134 / 34F | 2 confirmed, 2 signature-changed, 30 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| scenic | `v1.9.0` (`bef5f4959b`) | 111 / 2F, 111 / 2F | 111 / 19F, 111 / 19F | 17 confirmed, 2 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| lobsters (shims: 1) | `b6ea255a` (`b6ea255ad7`) | 927 / 0F, 927 / 1F | did not load, did not load | 1 suite-did-not-load | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| lobsters-rspec-rails-main (bumps: rspec-rails https://github.com/rspec/rspec-rails 9fb6f4f0a3; shims: 1) | `b6ea255a` (`b6ea255ad7`) | 927 / 0F, 927 / 1F | 927 / 3F, 927 / 4F | 3 confirmed, 1 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |

Runs read as tests / failed tests. Classes: `confirmed` fails 2/2 on the candidate and passes 2/2 on base; `flaky-candidate` and `order-dependent` fail under one seed only (then run alone 5 times per tree); `base-failing` fails on base too; `signature-changed` fails on both with different errors.

## confirmed (22)

| Signature | Count | Suites | Example |
| --- | --- | --- | --- |
| `ActionController::UrlGenerationError: No route matches {action: "show", controller: "stories", id: ""}, missing required keys: [:id]` | 3 | lobsters-rspec-rails-main | ./spec/requests/stories_spec.rb[1:1:2:1] |
| `ArgumentError: wrong number of arguments (given 2, expected 3)` | 14 | scenic | ./spec/integration/revert_spec.rb[1:1] |
| `NoMethodError: undefined method 'attach_to' for class ActionController::LogSubscriber` | 1 | lograge | ./spec/lograge_spec.rb[1:1:3:1] |
| `RSpec::Core::MultipleExceptionError: expected 'Lograge.notification_listeners_for('render_template.action_view')' to have changed to [], but did not change` | 1 | lograge | ./spec/lograge_spec.rb[1:1:2] |
| `RSpec::Expectations::ExpectationNotMetError: expected ActiveRecord::IrreversibleMigration, got #<ArgumentError: wrong number of arguments (given 2, expected 3)> with backtrace:` | 3 | scenic | ./spec/scenic/command_recorder_spec.rb[1:2:3] |

## suite-did-not-load (1)

| Signature | Count | Suites | Example |
| --- | --- | --- | --- |
| `FrozenError: can't modify frozen Hash: {}` | 1 | lobsters | (suite); cand runs 1,2 did not load, 20 load errors |

## signature-changed (2)

| Signature | Count | Suites | Example |
| --- | --- | --- | --- |
| `FrozenError: can't modify frozen Hash: {"ActionController::RoutingError" => :not_found, "AbstractController::ActionNotFound" => :not_found, "ActionController::MethodNotAllowed" => :method_not_allowed,` | 2 | lograge | ./spec/log_subscribers/action_cable_spec.rb[1:2:3:1]; base: RSpec::Expectations::ExpectationNotMetError: expected "" to match /status=404 / |

## base-failing (33)

| Signature | Count | Suites | Example |
| --- | --- | --- | --- |
| `ActiveRecord::RecordInvalid: Validation failed: Domain has already been taken` | 1 | lobsters-rspec-rails-main | ./spec/features/submit_story_spec.rb[1:10] |
| `ActiveRecord::StatementInvalid: PG::DuplicateTable: ERROR: relation "search in a haystack" already exists` | 1 | scenic | ./spec/scenic/schema_dumper_spec.rb[1:8:1] |
| `RSpec::Core::MultipleExceptionError: expected 'Lograge.notification_listeners_for('process_action.action_controller')' to have changed to [], but did not change` | 1 | lograge | ./spec/lograge_spec.rb[1:1:1] |
| `RSpec::Core::MultipleExceptionError: expected collection contained: [#<ActiveSupport::Notifications::Fanout::Subscribers::Timed:0xX @pattern="process_acti...>:0xX @events=[]>, @silenceable=false, @can` | 1 | lograge | ./spec/lograge_spec.rb[1:1:4:1] |
| `RSpec::Expectations::ExpectationNotMetError: expected "" to include "action=pong"` | 1 | lograge | ./spec/log_subscribers/action_cable_spec.rb[1:5:1] |
| `RSpec::Expectations::ExpectationNotMetError: expected "" to include "controller=ActionCableChannel action=pong"` | 5 | lograge | ./spec/log_subscribers/action_cable_spec.rb[1:2:1] |
| `RSpec::Expectations::ExpectationNotMetError: expected "" to match /^My test: {.*"data"\s*:\s*"value"/` | 2 | lograge | ./spec/log_subscribers/action_cable_spec.rb[1:1:1] |
| `RSpec::Expectations::ExpectationNotMetError: expected "" to match /duration=[.0-9]{2,4}/` | 1 | lograge | ./spec/log_subscribers/action_cable_spec.rb[1:2:2] |
| `RSpec::Expectations::ExpectationNotMetError: expected "" to match /status=200 /` | 1 | lograge | ./spec/log_subscribers/action_cable_spec.rb[1:2:4] |
| `RSpec::Expectations::ExpectationNotMetError: expected "My test: {\"method\":\"GET\",\"status\":200}" to match /^My test: {.*"data"\s*:\s*"value"/` | 2 | lograge | ./spec/log_subscribers/action_controller_spec.rb[1:1:1] |
| `RSpec::Expectations::ExpectationNotMetError: expected "method=GET status=200" to match / data=value/` | 1 | lograge | ./spec/log_subscribers/action_controller_spec.rb[1:6:1] |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to include "/home"` | 1 | lograge | ./spec/log_subscribers/action_controller_spec.rb[1:4:1] |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to include "controller=HomeController action=index"` | 1 | lograge | ./spec/log_subscribers/action_controller_spec.rb[1:4:5] |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to include "unpermitted_params=[\"florb\", \"blarf\"]"` | 1 | lograge | ./spec/log_subscribers/action_controller_spec.rb[1:4:13:1] |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to match / data=value/` | 2 | lograge | ./spec/log_subscribers/action_controller_spec.rb[1:5:1] |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to match /^method=GET /` | 1 | lograge | ./spec/log_subscribers/action_controller_spec.rb[1:4:3] |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to match /allocations=231/` | 1 | lograge | ./spec/log_subscribers/action_controller_spec.rb[1:4:15:1] |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to match /db=0.02/` | 1 | lograge | ./spec/log_subscribers/action_controller_spec.rb[1:4:8] |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to match /duration=[.0-9]{4,4} /` | 1 | lograge | ./spec/log_subscribers/action_controller_spec.rb[1:4:6] |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to match /location=http:\/\/www.example.com/` | 1 | lograge | ./spec/log_subscribers/action_controller_spec.rb[1:4:11:1] |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to match /view=0.01 /` | 1 | lograge | ./spec/log_subscribers/action_controller_spec.rb[1:4:7] |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=pong" to match / data=value/` | 1 | lograge | ./spec/log_subscribers/action_cable_spec.rb[1:4:1] |
| `RSpec::Expectations::ExpectationNotMetError: expected '"".present?' to be truthy, got false` | 3 | lograge | ./spec/log_subscribers/action_cable_spec.rb[1:1:3] |
| `RSpec::Expectations::ExpectationNotMetError: expected: ["scenic.bananas", "scenic.apples"]` | 1 | scenic | ./spec/scenic/schema_dumper_spec.rb[1:4:2] |
