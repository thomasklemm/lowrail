# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails test test/controllers -v`
* Ruby: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux]
* Rails: 8.2.0.alpha, test environment
* Counted in run 1: 23 requests; 2 runs
* Not counted in run 1: 30 requests made by controller tests (`ActionController::TestCase`, rspec-rails controller specs), which call the controller directly, without the app's middleware and routing
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 23 | 9075.5 | 0 | 0 | 0 | 0 |
| run2 | 1 | 23 | 9097.1 | 0 | 0 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.0 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/services/bitbucket/forge/installations.rb:51` | `create_for` | 250.7 | 0.0 | 0.35 | `RAILS/activesupport/lib/active_support/code_generator.rb:16` 9%, `RAILS/activemodel/lib/active_model/attribute_methods.rb:469` 9%, `RAILS/activesupport/lib/active_support/code_generator.rb:30` 7% | Webhooks::BitbucketForgeController#heartbeat 96%, Webhooks::BitbucketForgeController#events 4%, Webhooks::BitbucketForgeController#lifecycle 0% | `BitbucketInstallation.create!(forge_installation_id: invocation.instal` |
| 2 | `app/services/bitbucket/forge/invocation_token.rb:52` | `fetch_keys` | 202.74 | 0.0 | 0.87 | `GEM/addressable/lib/addressable/uri.rb:486` 3%, `GEM/addressable/lib/addressable/uri.rb:480` 3%, `GEM/addressable/lib/addressable/uri.rb:136` 3% | Webhooks::BitbucketForgeController#heartbeat 70%, Webhooks::BitbucketForgeController#connect 12%, Webhooks::BitbucketForgeController#events 9% | `response = Faraday.new(request: { open_timeout: 3, timeout: 5 }).get(A` |
| 3 | `app/models/bitbucket_pairing.rb:24` | `start!` | 93.17 | 0.0 | 0.04 | `RAILS/activesupport/lib/active_support/code_generator.rb:30` 11%, `RAILS/activemodel/lib/active_model/attribute_methods.rb:518` 9%, `RAILS/activesupport/lib/active_support/code_generator.rb:35` 9% | Webhooks::BitbucketForgeController#connect 100% | `pairing = create!(bitbucket_installation: installation, public_id: Sec` |
| 4 | `app/services/bitbucket/forge/installations.rb:50` | `create_for` | 75.22 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract_adapter.rb:1284` 6%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:379` 4%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:227` 3% | Webhooks::BitbucketForgeController#heartbeat 88%, Webhooks::BitbucketForgeController#events 12%, Webhooks::BitbucketForgeController#lifecycle 0% | `.find_each { \|previous\| uninstall!(previous) }` |
| 5 | `app/services/bitbucket/forge/installations.rb:18` | `record!` | 74.35 | 0.0 | 0.87 | `RAILS/activerecord/lib/active_record/connection_adapters/deduplicable.rb:15` 8%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:19` 6%, `RAILS/activerecord/lib/active_record/connection_adapters/sql_type_metadata.rb:30` 6% | Webhooks::BitbucketForgeController#heartbeat 87%, Webhooks::BitbucketForgeController#status 6%, Webhooks::BitbucketForgeController#connect 5% | `installation = BitbucketInstallation.find_by(forge_installation_id: in` |
| 6 | `app/services/bitbucket/forge/invocation_token.rb:32` | `verify!` | 62.13 | 0.0 | 1.74 | `GEM/json/lib/json/common.rb:364` 20%, `GEM/jwt/lib/jwt/claims/decode_verifier.rb:33` 8%, `GEM/jwt/lib/jwt/jwk/rsa.rb:156` 6% | Webhooks::BitbucketForgeController#heartbeat 70%, Webhooks::BitbucketForgeController#status 10%, Webhooks::BitbucketForgeController#connect 10% | `claims = JWT.decode(token, nil, true, algorithms: [ ALGORITHM ], jwks:` |
| 7 | `app/models/bitbucket_installation.rb:47` | `store_token!` | 57.35 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:256` 10%, `GEM/bullet/lib/bullet/ext/string.rb:9` 4%, `RAILS/activemodel/lib/active_model/type/value.rb:131` 3% | Webhooks::BitbucketForgeController#heartbeat 78%, Webhooks::BitbucketForgeController#events 11%, Webhooks::BitbucketForgeController#connect 11% | `reload` |
| 8 | `app/models/bitbucket_installation.rb:45` | `store_token!` | 44.78 | 0.0 | 0.39 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:173` 5%, `RAILS/activerecord/lib/arel/table.rb:105` 4%, `RAILS/activerecord/lib/arel/visitors/to_sql.rb:825` 4% | Webhooks::BitbucketForgeController#heartbeat 78%, Webhooks::BitbucketForgeController#connect 11%, Webhooks::BitbucketForgeController#events 11% | `.update_all(encrypted_access_token: encrypt_secret(token.to_s, column:` |
| 9 | `app/models/bitbucket_installation.rb:40` | `store_token!` | 40.52 | 0.0 | 0.39 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:173` 6%, `RAILS/activerecord/lib/arel/table.rb:105` 4%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:168` 4% | Webhooks::BitbucketForgeController#heartbeat 79%, Webhooks::BitbucketForgeController#events 11%, Webhooks::BitbucketForgeController#connect 11% | `self.class.where(id: id).update_all(last_invocation_at: now)` |
| 10 | `app/services/bitbucket/forge/installations.rb:26` | `record!` | 35.3 | 2.0 | 0.04 | `GEM/sentry-ruby/lib/sentry/baggage.rb:66` 14%, `RUBY/random/formatter.rb:174` 8%, `RAILS/activejob/lib/active_job/enqueuing.rb:67` 3% | Webhooks::BitbucketForgeController#heartbeat 79%, Webhooks::BitbucketForgeController#connect 10%, Webhooks::BitbucketForgeController#events 10% | `RefreshBitbucketInstallationJob.perform_later(installation.id) if inst` |
| 11 | `app/models/bitbucket_pairing.rb:22` | `start!` | 33.61 | 0.0 | 0.04 | `RAILS/activerecord/lib/active_record/connection_adapters/deduplicable.rb:15` 9%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:19` 7%, `RAILS/activerecord/lib/active_record/connection_adapters/sql_type_metadata.rb:30` 7% | Webhooks::BitbucketForgeController#connect 100% | `where(expires_at: ...Time.current).delete_all` |
| 12 | `app/services/bitbucket/app_config.rb:32` | `settings` | 28.17 | 0.0 | 2.35 | `GEM/mocha/lib/mocha/expectation_list.rb:55` 17%, `GEM/mocha/lib/mocha/parameters_matcher.rb:37` 17%, `GEM/mocha/lib/mocha/yield_parameters.rb:11` 8% | Webhooks::BitbucketForgeController#heartbeat 69%, Webhooks::BitbucketForgeController#connect 13%, Webhooks::BitbucketForgeController#status 9% | `def settings = Settings.bitbucket` |
| 13 | `app/services/bitbucket/forge/invocation_token.rb:47` | `signing_key` | 27.04 | 0.0 | 0.43 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:227` 10%, `GEM/sentry-rails/lib/sentry/rails/breadcrumb/active_support_logger.rb:22` 10%, `RAILS/activesupport/lib/active_support/cache.rb:681` 5% | Webhooks::BitbucketForgeController#heartbeat 72%, Webhooks::BitbucketForgeController#status 9%, Webhooks::BitbucketForgeController#connect 9% | `keys = Rails.cache.fetch(CACHE_KEY, expires_in: KEYS_TTL) { fetch_keys` |
| 14 | `app/services/bitbucket/forge/invocation_token.rb:24` | `verify!` | 19.83 | 0.0 | 0.0 | `GEM/json/lib/json/common.rb:364` 64%, `GEM/jwt/lib/jwt/encoded_token.rb:36` 9%, `GEM/jwt/lib/jwt.rb:46` 5% | Webhooks::BitbucketForgeController#heartbeat 71%, Webhooks::BitbucketForgeController#connect 10%, Webhooks::BitbucketForgeController#status 10% | `header = JWT.decode(token, nil, false).last` |
| 15 | `app/services/bitbucket/client.rb:62` | `request` | 18.22 | 0.0 | 0.0 | `GEM/addressable/lib/addressable/uri.rb:486` 6%, `GEM/faraday/lib/faraday/utils.rb:32` 6%, `GEM/addressable/lib/addressable/uri.rb:431` 5% | Webhooks::BitbucketForgeController#connect 100%, Webhooks::BitbucketForgeController#status 0% | `response = connection.run_request(method, path, body&.to_json, headers` |
| 16 | `app/services/bitbucket/forge/installations.rb:46` | `create_for` | 17.39 | 0.0 | 0.35 | `GEM/sentry-rails/lib/sentry/rails/breadcrumb/active_support_logger.rb:22` 8%, `RAILS/activerecord/lib/active_record/core.rb:714` 8%, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:563` 6% | Webhooks::BitbucketForgeController#heartbeat 88%, Webhooks::BitbucketForgeController#events 13%, Webhooks::BitbucketForgeController#lifecycle 0% | `BitbucketInstallation.transaction do` |
| 17 | `app/models/feature_flag.rb:22` | `load_snapshot` | 16.74 | 0.0 | 1.43 | `RAILS/activerecord/lib/active_record/relation/calculations.rb:633` 8%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:256` 6%, `RAILS/activerecord/lib/arel/table.rb:105` 4% | FeatureGatedTest::GatedController#index 79%, FeatureGatedTest::GatedController#reaping 21% | `flags = pluck(:id, :key, :enabled).to_h { \|id, key, enabled\| [ id, [ k` |
| 18 | `app/models/feature_flag.rb:23` | `load_snapshot` | 15.7 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/relation/calculations.rb:633` 8%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:379` 4%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:256` 4% | FeatureGatedTest::GatedController#index 79%, FeatureGatedTest::GatedController#reaping 21% | `FeatureFlagOverride.pluck(:feature_flag_id, :company_id, :enabled).eac` |
| 19 | `app/controllers/concerns/feature_gated.rb:42` | `required_feature_enabled?` | 13.87 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:256` 15%, `GEM/bullet/lib/bullet/ext/string.rb:9` 6%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:227` 4% | FeatureGatedTest::GatedController#index 67%, FeatureGatedTest::GatedController#reaping 33% | `Feature.enabled?(key, company: signed_in? ? current_company : nil)` |
| 20 | `app/services/feature_flags.rb:99` | `load_snapshot` | 12.61 | 0.0 | 0.22 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:227` 10%, `GEM/sentry-rails/lib/sentry/rails/breadcrumb/active_support_logger.rb:22` 10%, `RAILS/activesupport/lib/active_support/cache.rb:957` 5% | FeatureGatedTest::GatedController#index 80%, FeatureGatedTest::GatedController#reaping 20% | `def load_snapshot = Rails.cache.fetch(CACHE_KEY, expires_in: CACHE_TTL` |
| 21 | `app/controllers/webhooks/bitbucket_forge_controller.rb:95` | `acknowledge` | 8.35 | 0.0 | 1.04 | `RAILS/actionpack/lib/action_controller/metal/rendering.rb:231` 12%, `RAILS/actionpack/lib/action_controller/metal/rendering.rb:235` 8%, `GEM/json/lib/json/common.rb:1089` 4% | Webhooks::BitbucketForgeController#heartbeat 87%, Webhooks::BitbucketForgeController#events 12%, Webhooks::BitbucketForgeController#lifecycle 0% | `def acknowledge = render(json: { ok: true })` |
| 22 | `app/controllers/webhooks/bitbucket_forge_controller.rb:72` | `verify_invocation` | 7.57 | 0.0 | 0.17 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:87` 14%, `RAILS/activesupport/lib/active_support/inflector/methods.rb:89` 11%, `GEM/zeitwerk/lib/zeitwerk/cref.rb:47` 11% | Webhooks::BitbucketForgeController#heartbeat 100% | `@invocation = Bitbucket::Forge::InvocationToken.verify!(request.author` |
| 23 | `app/models/concerns/encryptable.rb:99` | `encrypt_secret` | 6.26 | 0.0 | 0.39 | `GEM/base64/lib/base64.rb:283` 37%, `RAILS/activesupport/lib/active_support/message_encryptor.rb:224` 6%, `RAILS/activesupport/lib/active_support/message_encryptor.rb:348` 6% | Webhooks::BitbucketForgeController#heartbeat 78%, Webhooks::BitbucketForgeController#events 11%, Webhooks::BitbucketForgeController#connect 11% | `encryptor.encrypt_and_sign(plaintext, purpose: (secret_purpose(column)` |
| 24 | `app/services/bitbucket/forge/installations.rb:48` | `create_for` | 5.91 | 0.0 | 0.7 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:146` 18%, `RAILS/activerecord/lib/arel/table.rb:105` 12%, `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:18` 12% | Webhooks::BitbucketForgeController#heartbeat 87%, Webhooks::BitbucketForgeController#events 12%, Webhooks::BitbucketForgeController#lifecycle 0% | `.where(forge_environment_id: invocation.environment_id, workspace_uuid` |
| 25 | `app/services/bitbucket/forge/installations.rb:49` | `create_for` | 5.57 | 0.0 | 1.04 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:146` 12%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:18` 12%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:129` 6% | Webhooks::BitbucketForgeController#heartbeat 87%, Webhooks::BitbucketForgeController#events 12%, Webhooks::BitbucketForgeController#lifecycle 0% | `.where.not(forge_installation_id: invocation.installation_id)` |
| 26 | `app/models/bitbucket_installation.rb:43` | `store_token!` | 5.48 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/querying.rb:24` 14%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:146` 14%, `RAILS/activerecord/lib/active_record/scoping/default.rb:170` 7% | Webhooks::BitbucketForgeController#heartbeat 78%, Webhooks::BitbucketForgeController#connect 11%, Webhooks::BitbucketForgeController#events 11% | `stored = self.class.where(id: id)` |
| 27 | `app/services/bitbucket/client.rb:181` | `connection` | 4.78 | 0.0 | 0.04 | `GEM/uri/lib/uri/common.rb:108` 9%, `GEM/uri/lib/uri/rfc3986_parser.rb:85` 6%, `GEM/uri/lib/uri/generic.rb:1518` 5% | Webhooks::BitbucketForgeController#connect 100%, Webhooks::BitbucketForgeController#status 0% | `@connection \|\|= Faraday.new(url: AppConfig::API_HOST) do \|f\|` |
| 28 | `app/controllers/webhooks/bitbucket_forge_controller.rb:28` | `events` | 4.57 | 0.22 | 0.09 | `GEM/sentry-ruby/lib/sentry/baggage.rb:66` 12%, `RUBY/random/formatter.rb:174` 7%, `RUBY/bundled_gems.rb:111` 5% | Webhooks::BitbucketForgeController#events 100% | `RefreshBitbucketRepositoryJob.perform_later(installation_id: @installa` |
| 29 | `app/models/bitbucket_installation.rb:29` |  | 4.52 | 0.0 | 1.04 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:146` 15%, `RAILS/activerecord/lib/arel/predications.rb:18` 8%, `RAILS/activerecord/lib/active_record/relation/query_methods.rb:2043` 8% | Webhooks::BitbucketForgeController#heartbeat 88%, Webhooks::BitbucketForgeController#events 12%, Webhooks::BitbucketForgeController#lifecycle 0% | `scope :live, -> { where.not(status: "uninstalled") }` |
| 30 | `app/services/bitbucket/forge/invocation_token.rb:55` | `fetch_keys` | 3.48 | 0.0 | 0.0 | `GEM/json/lib/json/common.rb:364` 100% | Webhooks::BitbucketForgeController#heartbeat 70%, Webhooks::BitbucketForgeController#status 10%, Webhooks::BitbucketForgeController#connect 10% | `JSON.parse(response.body).fetch("keys")` |

App middleware that hands the request on (the stack below it, not its own work): `lib/middleware/raw_upload_body.rb:30` 141.26, `config/initializers/content_security_policy.rb:56` 59.26 warm objects per request.

121.83 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | Webhooks::BitbucketForgeController#connect | 2 / 2 | 6439.0 / 6439.0 | 0.0 | 4976.5 | `RAILS/activesupport/lib/active_support/code_generator.rb:30` 240.0, `RAILS/activemodel/lib/active_model/attribute_methods.rb:518` 189.0, `RAILS/activesupport/lib/active_support/code_generator.rb:35` 184.0 | `app/models/bitbucket_pairing.rb:24` 2143.0, `app/models/bitbucket_pairing.rb:22` 773.0, `app/services/bitbucket/forge/invocation_token.rb:52` 575.0 |
| 2 | Webhooks::BitbucketForgeController#heartbeat | 9 / 9 | 3124.0 / 3123.6 | -0.4 | 8108.0 | `RAILS/activesupport/lib/active_support/code_generator.rb:16` 64.3, `GEM/json/lib/json/common.rb:364` 62.5, `RAILS/activemodel/lib/active_model/attribute_methods.rb:469` 61.8 | `app/services/bitbucket/forge/installations.rb:51` 688.9, `app/services/bitbucket/forge/invocation_token.rb:52` 410.0, `app/services/bitbucket/forge/installations.rb:50` 189.4 |
| 3 | Webhooks::BitbucketForgeController#events | 2 / 2 | 2856.0 / 2856.0 | 0.0 | 2839.5 | `GEM/json/lib/json/common.rb:364` 74.0, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:379` 38.0, `RAILS/activerecord/lib/arel/table.rb:105` 37.0 | `app/services/bitbucket/forge/invocation_token.rb:52` 437.0, `app/services/bitbucket/forge/installations.rb:51` 255.0, `app/services/bitbucket/forge/installations.rb:50` 215.0 |
| 4 | Webhooks::BitbucketForgeController#status | 2 / 2 | 1892.0 / 1892.0 | 0.0 | 3811.0 | `GEM/json/lib/json/common.rb:364` 70.0, `GEM/rack/lib/rack/utils.rb:693` 26.0, `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:334` 24.0 | `app/services/bitbucket/forge/invocation_token.rb:52` 371.0, `lib/middleware/raw_upload_body.rb:30` 192.0, `app/services/bitbucket/forge/invocation_token.rb:32` 142.0 |
| 5 | FeatureGatedTest::GatedController#reaping | 2 / 2 | 1051.0 / 1052.0 | 1.0 | 869.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:256` 27.0, `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:334` 24.0, `RUBY/random/formatter.rb:174` 21.0 | `lib/middleware/raw_upload_body.rb:30` 247.0, `app/controllers/concerns/feature_gated.rb:42` 105.0, `app/models/feature_flag.rb:22` 82.0 |
| 6 | FeatureGatedTest::GatedController#index | 5 / 5 | 919.8 / 920.0 | 0.3 | 986.6 | `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:334` 24.0, `RUBY/random/formatter.rb:174` 21.0, `GEM/lograge/lib/lograge/formatters/key_value.rb:19` 19.0 | `lib/middleware/raw_upload_body.rb:30` 228.5, `config/initializers/content_security_policy.rb:56` 76.5, `app/models/feature_flag.rb:22` 75.8 |
| 7 | Webhooks::BitbucketForgeController#lifecycle | 1 / 1 | – / – |  | 2689.0 |  |  |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/json/lib/json/common.rb:364` | `parse` | 45.52 / 45.52 | 0.0 | 45.74 | 70% | String, Hash |  | `app/services/bitbucket/forge/invocation_token.rb:24` 39%, `app/services/bitbucket/forge/invocation_token.rb:32` 39% | `Parser.parse(source, opts)` |
| 2 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:379` | `build_handle` | 25.7 / 25.7 | 0.0 | 25.96 | 100% | Object |  | `lib/middleware/raw_upload_body.rb:30` 17%, `app/services/bitbucket/forge/installations.rb:50` 13% | `instances << group_klass.new(grouped_listeners, name, id, payload)` |
| 3 | `GEM/sentry-rails/lib/sentry/rails/breadcrumb/active_support_logger.rb:22` | `add` | 25.13 / 25.13 | 0.0 | 25.39 | 100% | Hash, Object |  | `lib/middleware/raw_upload_body.rb:30` 18%, `app/services/bitbucket/forge/invocation_token.rb:47` 14% | `crumb = Sentry::Breadcrumb.new(` |
| 4 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:227` † | `now` | 25.13 / 25.13 | 0.0 | 25.39 | 100% | Data |  | `lib/middleware/raw_upload_body.rb:30` 18%, `app/services/bitbucket/forge/invocation_token.rb:47` 14% | `Time.now` |
| 5 | `RUBY/random/formatter.rb:174` † | `uuid` | 24.65 / 24.65 | 0.0 | 25.57 | 100% | String, Array |  | `no app frame` 82%, `app/services/bitbucket/forge/installations.rb:26` 15% | `ary.unpack("H8H4H4H4H12").join(?-)` |
| 6 | `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:334` | `build_directives` | 22.96 / 22.96 | 0.0 | 24.0 | 100% | String |  | `config/initializers/content_security_policy.rb:56` 100% | `"#{directive} #{build_directive(directive, sources, context).join(' ')` |
| 7 | `GEM/lograge/lib/lograge/formatters/key_value.rb:19` | `format` | 22.26 / 22.26 | 0.0 | 23.17 | 100% | String |  | `lib/middleware/raw_upload_body.rb:30` 100% | `"#{key}=#{parse_value(key, value)}"` |
| 8 | `GEM/rack/lib/rack/utils.rb:693` | `clean_path_info` | 20.13 / 20.13 | 0.0 | 21.09 | 100% | String, Array |  | `no app frame` 54%, `config/initializers/content_security_policy.rb:56` 46% | `parts = path_info.split PATH_SEPS` |
| 9 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:18` | `deep_dup` | 19.96 / 19.96 | 0.0 | 20.65 | 100% | String, Object |  | `no app frame` 77%, `app/models/bitbucket_installation.rb:45` 8% | `duplicable? ? dup : self` |
| 10 | `RAILS/activerecord/lib/arel/table.rb:105` | `[]` | 18.43 / 18.43 | 0.0 | 20.13 | 87% | Struct |  | `app/services/bitbucket/forge/installations.rb:51` 35%, `app/models/bitbucket_installation.rb:45` 14% | `Attribute.new(table, name)` |
| 11 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:256` | `cast_result` | 17.04 / 17.04 | 0.0 | 18.35 | 87% | String, Array |  | `app/models/bitbucket_installation.rb:47` 43%, `app/controllers/concerns/feature_gated.rb:42` 15% | `ActiveRecord::Result.new(fields, result.values, types.freeze, affected` |
| 12 | `RAILS/activesupport/lib/active_support/code_generator.rb:30` | `apply` | 16.65 / 16.65 | 0.0 | 35.7 | 13% | Array, String |  | `app/services/bitbucket/forge/installations.rb:51` 51%, `app/models/bitbucket_pairing.rb:24` 29% | `@cache.module_eval("# frozen_string_literal: true\n" + @sources.join("` |
| 13 | `GEM/addressable/lib/addressable/uri.rb:486` | `unencode` | 14.61 / 14.61 | 0.0 | 16.17 | 61% | String, MatchData |  | `app/services/bitbucket/forge/invocation_token.rb:52` 66%, `app/services/bitbucket/client.rb:62` 34% | `result = uri.gsub(/%[0-9a-f]{2}/i) do \|sequence\|` |
| 14 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:50` | `deep_dup` | 13.43 / 13.43 | 0.0 | 14.04 | 100% | Hash |  | `no app frame` 100%, `app/models/bitbucket_pairing.rb:9` 0% | `hash = dup` |
| 15 | `GEM/sentry-rails/lib/sentry/rails/breadcrumb/active_support_logger.rb:18` | `add` | 12.57 / 12.57 | 0.0 | 12.7 | 100% | Hash |  | `lib/middleware/raw_upload_body.rb:30` 18%, `app/services/bitbucket/forge/invocation_token.rb:47` 14% | `data = data.slice(*@allowed_keys[name])` |
| 16 | `GEM/sentry-rails/lib/sentry/rails/breadcrumb/active_support_logger.rb:27` | `add` | 12.57 / 12.57 | 0.0 | 12.7 | 100% | Hash |  | `lib/middleware/raw_upload_body.rb:30` 18%, `app/services/bitbucket/forge/invocation_token.rb:47` 14% | `Sentry.add_breadcrumb(crumb)` |
| 17 | `GEM/sentry-ruby/lib/sentry/hub.rb:295` | `add_breadcrumb` | 12.57 / 12.57 | 0.0 | 12.7 | 100% | Hash |  | `lib/middleware/raw_upload_body.rb:30` 18%, `app/services/bitbucket/forge/invocation_token.rb:47` 14% | `def add_breadcrumb(breadcrumb, hint: {})` |
| 18 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:377` | `build_handle` | 12.57 / 12.57 | 0.0 | 12.7 | 100% | Array |  | `lib/middleware/raw_upload_body.rb:30` 18%, `app/services/bitbucket/forge/invocation_token.rb:47` 14% | `instances = []` |
| 19 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:381` | `build_handle` | 12.57 / 12.57 | 0.0 | 12.7 | 100% | Object |  | `lib/middleware/raw_upload_body.rb:30` 18%, `app/services/bitbucket/forge/invocation_token.rb:47` 14% | `Handle.new(name, id, instances, payload)` |
| 20 | `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:357` | `build_directive` | 12.43 / 12.43 | 0.0 | 13.0 | 100% | Array |  | `config/initializers/content_security_policy.rb:56` 100% | `resolved_sources = sources.flat_map { \|source\| resolve_source(source, ` |
| 21 | `GEM/rack-cors/lib/rack/cors.rb:123` | `call` | 12.39 / 12.39 | 0.0 | 12.7 | 100% | Array, String |  | `no app frame` 100% | `headers['vary'] = ((vary ? [vary].flatten.map { \|v\| v.split(/,\s*/) }.` |
| 22 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract_adapter.rb:1284` | `build_retry_budget` | 12.35 / 12.35 | 0.0 | 13.91 | 87% | Object, Hash |  | `app/services/bitbucket/forge/installations.rb:50` 38%, `app/services/bitbucket/forge/installations.rb:18` 11% | `RetryBudget.new(` |
| 23 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:173` | `change` | 12.0 / 12.0 | 0.0 | 13.04 | 56% | Rational, Data |  | `app/services/bitbucket/forge/installations.rb:51` 40%, `app/models/bitbucket_installation.rb:45` 26% | `::Time.utc(new_year, new_month, new_day, new_hour, new_min, new_sec)` |
| 24 | `GEM/addressable/lib/addressable/uri.rb:431` | `encode_component` | 11.43 / 11.43 | 0.0 | 12.7 | 61% | String, MatchData |  | `app/services/bitbucket/forge/invocation_token.rb:52` 65%, `app/services/bitbucket/client.rb:62` 35% | `component = component.gsub(character_class) do \|char\|` |
| 25 | `GEM/addressable/lib/addressable/uri.rb:480` | `unencode` | 9.39 / 9.39 | 0.0 | 10.26 | 61% | Array |  | `app/services/bitbucket/forge/invocation_token.rb:52` 81%, `app/services/bitbucket/client.rb:62` 19% | `if ![String, ::Addressable::URI].include?(return_type)` |
| 26 | `GEM/addressable/lib/addressable/uri.rb:136` | `parse` | 8.96 / 8.96 | 0.0 | 9.96 | 61% | String, Array |  | `app/services/bitbucket/forge/invocation_token.rb:52` 78%, `app/services/bitbucket/client.rb:62` 22% | `scan = uri.scan(URIREGEX)` |
| 27 | `GEM/bullet/lib/bullet/registry/base.rb:9` | `initialize` | 8.61 / 8.61 | 0.0 | 9.0 | 100% | Hash |  | `config/initializers/content_security_policy.rb:56` 100% | `@registry = {}` |
| 28 | `RAILS/activesupport/lib/active_support/code_generator.rb:35` | `apply` | 8.48 / 8.48 | 0.0 | 23.83 | 13% | Data |  | `app/services/bitbucket/forge/installations.rb:51` 64%, `app/models/bitbucket_pairing.rb:24` 34% | `owner.define_method(as, @cache.instance_method(canonical_name))` |
| 29 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:331` | `index_with` | 8.3 / 8.3 | 0.0 | 11.0 | 52% | Array, Hash |  | `app/services/bitbucket/forge/installations.rb:51` 67%, `app/services/bitbucket/forge/installations.rb:18` 18% | `to_h { \|elem\| [elem, yield(elem)] } # rubocop:disable Rails/IndexWith` |
| 30 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:518` | `method_name` | 8.22 / 8.22 | 0.0 | 23.74 | 9% | String |  | `app/services/bitbucket/forge/installations.rb:51` 65%, `app/models/bitbucket_pairing.rb:24` 35% | `@method_name % attr_name` |

## Dev/test-mode work

49.8 of 1842.4 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | route build | `RAILS/actionpack/lib/action_dispatch/journey/gtg/builder.rb:31` | 5.87 | 26% | `lib/middleware/raw_upload_body.rb:30` 100% | `u = ps.flat_map { \|l\| @followpos[l] }.uniq` |
| 2 | route build | `RAILS/actionpack/lib/action_dispatch/journey/gtg/builder.rb:30` | 4.57 | 26% | `lib/middleware/raw_upload_body.rb:30` 100% | `s.group_by { \|state\| symbol(state) }.each do \|sym, ps\|` |
| 3 | route build | `RAILS/actionpack/lib/action_dispatch/journey/gtg/builder.rb:97` | 3.04 | 26% | `lib/middleware/raw_upload_body.rb:30` 100% | `nullable?(node) ? [] : [node]` |
| 4 | route build | `RAILS/actionpack/lib/action_dispatch/journey/gtg/builder.rb:126` † | 2.83 | 26% | `lib/middleware/raw_upload_body.rb:30` 100% | `table = Hash.new { \|h, k\| h[k] = [] }.compare_by_identity` |
| 5 | route build | `RAILS/actionpack/lib/action_dispatch/journey/gtg/builder.rb:116` | 2.61 | 26% | `lib/middleware/raw_upload_body.rb:30` 100% | `nullable?(node) ? [] : [node]` |
| 6 | route build | `RAILS/actionpack/lib/action_dispatch/journey/gtg/builder.rb:131` | 2.61 | 26% | `lib/middleware/raw_upload_body.rb:30` 100% | `table[i] += firstpos(n.right)` |
| 7 | debug logging | `GEM/lograge/lib/lograge/rails_ext/rack/logger.rb:21` | 1.91 | 100% | `no app frame` 100% | `[status, headers, ::Rack::BodyProxy.new(body) {}] # rubocop:disable Li` |
| 8 | debug logging | `GEM/sentry-rails/lib/sentry/rails/log_subscriber.rb:61` | 1.91 | 100% | `lib/middleware/raw_upload_body.rb:30` 100% | `Sentry.logger.public_send(level, message, **attributes, origin: origin` |
| 9 | debug logging | `RAILS/activesupport/lib/active_support/event_reporter.rb:398` | 1.91 | 100% | `lib/middleware/raw_upload_body.rb:30` 100% | `event = { name: name }` |
| 10 | asset lookup | `GEM/propshaft/lib/propshaft/server.rb:16` | 1.61 | 100% | `no app frame` 100% | `if (method == "GET" \|\| method == "HEAD") && path.start_with?(@assembly` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activerecord | 348.0 | 434.7 | `table.rb:105` 18.4, `database_statements.rb:256` 17.0, `abstract_adapter.rb:1284` 12.3 |
| rails: activesupport | 316.0 | 417.9 | `fanout.rb:379` 25.7, `fanout.rb:227` 25.1, `deep_dup.rb:18` 20.0 |
| test harness: webmock | 192.4 | 201.9 | `headers.rb:69` 35.4, `headers.rb:68` 28.5, `uri.rb:62` 16.4 |
| gem: addressable | 183.0 | 208.4 | `uri.rb:486` 14.6, `uri.rb:431` 11.4, `uri.rb:480` 9.4 |
| rails: actionpack | 150.8 | 2177.9 | `content_security_policy.rb:334` 23.0, `content_security_policy.rb:357` 12.4, `builder.rb:31` 5.9 |
| rails: activemodel | 81.7 | 180.5 | `attribute_methods.rb:518` 8.2, `attribute.rb:10` 8.0, `attribute_methods.rb:372` 7.2 |
| app | 75.9 | 132.8 | `ids.rb:12` 16.3, `ids.rb:16` 5.6, `app_config.rb:32` 3.4 |
| gem: sentry-rails | 67.7 | 69.2 | `active_support_logger.rb:22` 25.1, `active_support_logger.rb:27` 12.6, `active_support_logger.rb:18` 12.6 |
| gem: sentry-ruby | 63.4 | 66.4 | `hub.rb:295` 12.6, `baggage.rb:66` 7.9, `sample_rand.rb:53` 3.6 |
| ruby default gem: uri | 61.6 | 66.2 | `common.rb:108` 8.1, `rfc3986_parser.rb:85` 5.4, `common.rb:194` 4.3 |
| gem: jwt | 61.3 | 67.0 | `decode_verifier.rb:33` 6.8, `encoded_token.rb:36` 4.6, `rsa.rb:156` 4.5 |
| gem: faraday | 55.1 | 61.6 | `options.rb:97` 2.8, `rack_builder.rb:119` 2.5, `headers.rb:59` 2.3 |
| ruby stdlib | 49.9 | 58.1 | `formatter.rb:174` 24.7, `normalize.rb:138` 7.2, `bundled_gems.rb:111` 3.7 |
| gem: json | 46.6 | 46.9 | `common.rb:364` 45.5, `common.rb:1089` 1.1 |
| gem: rack | 45.3 | 48.3 | `utils.rb:693` 20.1, `body_proxy.rb:12` 4.8, `request.rb:604` 4.5 |
| gem: mocha | 40.7 | 42.1 | `expectation_list.rb:55` 6.8, `parameters_matcher.rb:37` 6.8, `mock.rb:328` 3.4 |
| gem: bullet | 40.0 | 47.5 | `base.rb:9` 8.6, `string.rb:9` 6.8, `object.rb:20` 5.2 |
| gem: lograge | 38.5 | 40.2 | `key_value.rb:19` 22.3, `key_value.rb:27` 2.9, `logger.rb:21` 1.9 |
| gem: omniauth | 28.7 | 31.0 | `paths.rb:67` 7.7, `paths.rb:94` 3.8, `strategy.rb:281` 3.8 |
| ruby default gem: net-http | 24.8 | 26.4 | `header.rb:205` 3.3, `header.rb:284` 2.5, `header.rb:227` 2.1 |
| gem: debug | 22.2 | 24.7 | `thread_client.rb:903` 6.3, `thread_client.rb:234` 3.2, `thread_client.rb:239` 3.2 |
| gem: rack-cors | 16.2 | 16.7 | `cors.rb:123` 12.4, `resource.rb:40` 1.9, `result.rb:38` 1.0 |
| gem: enumerize | 14.7 | 16.2 | `attribute.rb:41` 3.7, `attribute_map.rb:13` 3.0, `base.rb:58` 1.6 |
| gem: base64 | 14.0 | 15.0 | `base64.rb:310` 5.3, `base64.rb:377` 3.3, `base64.rb:283` 3.1 |
| rails: activejob | 12.6 | 13.9 | `enqueuing.rb:67` 1.9, `queue_adapter.rb:11` 1.2, `core.rb:133` 1.2 |
| gem: tzinfo | 10.0 | 10.9 | `timestamp.rb:208` 4.0, `constant_offset_data_timezone_info.rb:36` 2.0, `timestamp.rb:193` 2.0 |
| rails: actionview | 7.3 | 7.8 | `view_paths.rb:99` 0.9, `view_paths.rb:103` 0.9, `lookup_context.rb:46` 0.9 |
| gem: faraday-net_http | 5.6 | 6.0 | `net_http.rb:81` 1.4, `net_http.rb:38` 0.7, `net_http.rb:80` 0.7 |
| rails: railties | 4.8 | 5.2 | `logger.rb:29` 1.0, `engine.rb:852` 1.0, `logger.rb:65` 1.0 |
| gem: pg | 4.6 | 5.3 | `connection.rb:403` 4.6, `result.rb:17` 0.0 |
| ruby default gem: securerandom | 4.6 | 4.7 | `securerandom.rb:71` 4.6 |
| gem: inertia_rails | 3.8 | 5.2 | `middleware.rb:117` 1.0, `middleware.rb:139` 1.0, `middleware.rb:54` 1.0 |
| gem: propshaft | 3.5 | 3.8 | `server.rb:16` 1.6, `server.rb:13` 1.0, `server.rb:14` 1.0 |
| gem: vite_ruby | 2.9 | 3.0 | `dev_server_proxy.rb:41` 1.0, `dev_server_proxy.rb:40` 1.0, `dev_server_proxy.rb:39` 1.0 |
| gem: rack-session | 2.9 | 3.0 | `id.rb:368` 1.0, `id.rb:275` 1.0, `id.rb:277` 1.0 |
| ruby default gem: openssl | 2.2 | 2.4 | `pkey.rb:354` 1.1, `pkey.rb:394` 0.6, `cipher.rb:56` 0.5 |
| gem: request_store | 1.9 | 2.0 | `middleware.rb:28` 1.0, `middleware.rb:21` 1.0 |
| gem: solid_queue | 1.8 | 2.0 | `batch_id.rb:20` 1.2, `batch_id.rb:24` 0.6 |
| gem: aasm | 1.6 | 2.1 | `state_machine_store.rb:29` 0.3, `state_machine_store.rb:73` 0.1, `state_machine.rb:11` 0.1 |
| gem: config | 1.0 | 1.2 | `options.rb:125` 1.0, `options.rb:123` 0.0, `options.rb:124` 0.0 |
| gem: bootsnap | 0.4 | 1.8 | `cache.rb:218` 0.2, `loaded_features_index.rb:115` 0.1, `loaded_features_index.rb:118` 0.1 |
| gem: concurrent-ruby | 0.3 | 0.6 | `map.rb:237` 0.1, `non_concurrent_map_backend.rb:131` 0.1, `non_concurrent_map_backend.rb:120` 0.0 |
| ruby default gem: erb | 0.3 | 0.4 | `util.rb:65` 0.3 |
| gem: msgpack | 0.0 | 0.7 | `factory.rb:37` 0.0, `factory.rb:9` 0.0, `factory.rb:29` 0.0 |
| gem: hashie | 0.0 | 6.9 | `mash.rb:329` 0.0, `mash.rb:641` 0.0, `mash.rb:587` 0.0 |
| gem: zeitwerk | 0.0 | 3.9 | `file_system.rb:199` 0.0, `cref.rb:47` 0.0, `loader.rb:511` 0.0 |
| lowrail-profile | 0.0 | 0.0 | `profile.rb:56` 0.0 |
