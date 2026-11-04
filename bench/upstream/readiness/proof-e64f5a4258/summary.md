# Rails readiness: e64f5a4258 against 6e09124217

Base `6e09124217` (8.1.4.1), candidate `e64f5a4258` (8.2.0.alpha), ruby 4.0.9, seeds 4242 and 1717 (run 1 and run 2 on both trees). Generated 2026-11-04T20:50:14Z.

| Suite | Ref | Base runs | Candidate runs | Flags | Lock difference besides Rails |
| --- | --- | --- | --- | --- | --- |
| lograge | `v0.15.1` (`106e8333d6`) | 134 / 3F, 134 / 32F | 134 / 7F, 134 / 34F | 2 confirmed, 2 signature-changed, 30 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| scenic | `v1.9.0` (`bef5f4959b`) | 111 / 2F, 111 / 2F | 111 / 19F, 111 / 19F | 17 confirmed, 2 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, psych: - -> 5.5.0, ractor-dispatch: - -> 0.3.0, stringio: - -> 3.2.0 |
| lobsters (shims: 1) | `b6ea255a` (`b6ea255ad7`) | 927 / 0F, 927 / 1F | did not load, did not load | 1 suite-did-not-load | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |
| lobsters-rspec-rails-main (bumps: rspec-rails https://github.com/rspec/rspec-rails 9fb6f4f0a3; shims: 1) | `b6ea255a` (`b6ea255ad7`) | 927 / 0F, 927 / 1F | 927 / 3F, 927 / 4F | 3 confirmed, 1 base-failing | herb: - -> 0.11.1, marcel: 1.2.1 -> 2.1.0, ractor-dispatch: - -> 0.3.0 |

Runs read as tests / failed tests. Classes: `confirmed` fails 2/2 on the candidate and passes 2/2 on base; `flaky-candidate` and `order-dependent` fail under one seed only (then run alone 5 times per tree); `base-failing` fails on base too; `signature-changed` fails on both with different errors. Flags are matched against the known findings in `bench/upstream/readiness/known.yml`.

## New (0)

None: every candidate flag matches a known finding.

## Known (25)

| Finding | Status | Classes | Count | Suites | Record |
| --- | --- | --- | --- | --- | --- |
| L2 | merged | 3 confirmed | 3 | lobsters-rspec-rails-main | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| R2-2 | gem-side | 17 confirmed | 17 | scenic | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| R2-3 | gem-side | 2 confirmed | 2 | lograge | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |
| L1 | gem-side | 1 suite-did-not-load | 1 | lobsters | [app-suites.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/app-suites.md) |
| R2-4 | record-only | 2 signature-changed | 2 | lograge | [ecosystem-round-2.md](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/ecosystem-round-2.md) |

## Fails on base too (33)

| Signature | Count | Suites | Match |
| --- | --- | --- | --- |
| `ActiveRecord::RecordInvalid: Validation failed: Domain has already been taken` | 1 | lobsters-rspec-rails-main | known:noise-lobsters-submit-story |
| `ActiveRecord::StatementInvalid: PG::DuplicateTable: ERROR: relation "search in a haystack" already exists` | 1 | scenic | known:noise-scenic-schema-dumper |
| `RSpec::Core::MultipleExceptionError: expected 'Lograge.notification_listeners_for('process_action.action_controller')' to have changed to [], but did not change` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Core::MultipleExceptionError: expected collection contained: [#<ActiveSupport::Notifications::Fanout::Subscribers::Timed:0xX @pattern="process_acti...>:0xX @events=[]>, @silenceable=false, @can` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "" to include "action=pong"` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "" to include "controller=ActionCableChannel action=pong"` | 5 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "" to match /^My test: {.*"data"\s*:\s*"value"/` | 2 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "" to match /duration=[.0-9]{2,4}/` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "" to match /status=200 /` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "My test: {\"method\":\"GET\",\"status\":200}" to match /^My test: {.*"data"\s*:\s*"value"/` | 2 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "method=GET status=200" to match / data=value/` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to include "/home"` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to include "controller=HomeController action=index"` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to include "unpermitted_params=[\"florb\", \"blarf\"]"` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to match / data=value/` | 2 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to match /^method=GET /` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to match /allocations=231/` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to match /db=0.02/` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to match /duration=[.0-9]{4,4} /` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to match /location=http:\/\/www.example.com/` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=index" to match /view=0.01 /` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected "status=200 action=pong" to match / data=value/` | 1 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected '"".present?' to be truthy, got false` | 3 | lograge | known:noise-lograge-order |
| `RSpec::Expectations::ExpectationNotMetError: expected: ["scenic.bananas", "scenic.apples"]` | 1 | scenic | known:noise-scenic-schema-dumper |
