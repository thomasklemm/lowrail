# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails test test/controllers -v`
* Ruby: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux]
* Rails: 8.1.4.1, test environment
* Counted in run 1: 181 requests, 2 jobs; 2 runs
* Not counted in run 1: 374 requests made by controller tests (`ActionController::TestCase`, rspec-rails controller specs), which call the controller directly, without the app's middleware and routing
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 181 | 7269.9 | 2 | 0 | 0 | 0 |
| run2 | 1 | 181 | 7293.4 | 2 | 0 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.02 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/controllers/concerns/auth_concern.rb:249` | `find_user_session` | 241.71 | 0.0 | 0.43 | `GEM/bullet/lib/bullet/registry/call_stack.rb:12` 28%, `RAILS/activerecord/lib/arel/alias_predication.rb:8` 9%, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:177` 7% | Web::OauthController#callback 49%, Web::OauthController#mcp_connect 29%, Web::OauthController#authorize 12% | `return UserSession.eager_load(:user).find_by(id: session[:user_session` |
| 2 | `app/services/auth/identity_resolver.rb:81` | `find_by_identity` | 153.95 | 0.0 | 0.46 | `GEM/bullet/lib/bullet/registry/call_stack.rb:12` 45%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 5%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 4% | Web::SessionsController#create 100% | `UserIdentity.find_by(identity_provider: provider, subject: assertion.s` |
| 3 | `app/models/user.rb:290` | `active_memberships_with_company` | 123.27 | 0.0 | 0.41 | `GEM/bullet/lib/bullet/registry/call_stack.rb:12` 46%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 5%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 5% | Web::OauthController#callback 54%, Web::OauthController#mcp_connect 32%, Web::OauthController#authorize 13% | `ActiveRecord::Associations::Preloader.new(records: list, associations:` |
| 4 | `app/services/auth/session_service.rb:20` | `record_proof` | 102.11 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:149` 4%, `GEM/bullet/lib/bullet/ext/string.rb:9` 3%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 3% | Web::SessionsController#create 100% | `proof.save!` |
| 5 | `app/services/teams/activity_authenticator.rb:58` | `get_json` | 93.44 | 0.0 | 0.24 | `GEM/addressable/lib/addressable/uri.rb:486` 3%, `GEM/addressable/lib/addressable/uri.rb:480` 3%, `GEM/addressable/lib/addressable/uri.rb:1544` 3% | Webhooks::TeamsController#activities 100% | `response = Faraday.get(url)` |
| 6 | `app/models/user_session.rb:27` | `start!` | 79.4 | 0.0 | 0.23 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:149` 5%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:144` 4%, `GEM/tzinfo/lib/tzinfo/timestamp.rb:208` 4% | Web::SessionsController#create 100% | `create!(user: user, impersonator: impersonator, last_seen_at: Time.cur` |
| 7 | `app/services/auth/identity_resolver.rb:158` | `link_identity` | 70.09 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 6%, `GEM/tzinfo/lib/tzinfo/timestamp.rb:208` 5%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 5% | Web::SessionsController#create 100% | `identity.save!` |
| 8 | `app/models/user.rb:277` | `active_memberships` | 65.65 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 6%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 4%, `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 4% | Web::OauthController#callback 52%, Web::OauthController#mcp_connect 32%, Web::OauthController#authorize 12% | `@active_memberships \|\|= company_memberships.active.to_a` |
| 9 | `app/controllers/web/sessions_controller.rb:209` | `landing_membership` | 63.13 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 7%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 7%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 5% | Web::SessionsController#create 100% | `memberships = user.company_memberships.active.to_a` |
| 10 | `app/forms/user_sign_in_form.rb:17` | `user` | 58.25 | 0.0 | 0.7 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 9%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 9%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 4% | Web::SessionsController#create 100% | `@user \|\|= User.active.not_deleted.find_by(email: email)` |
| 11 | `app/controllers/web/sessions_controller.rb:221` | `no_active_membership?` | 47.82 | 0.0 | 0.23 | `RAILS/activemodel/lib/active_model/type/value.rb:130` 4%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 4%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` 3% | Web::SessionsController#create 100% | `!user.super_admin? && user.company_memberships.active.none?` |
| 12 | `app/services/auth/policy_resolver.rb:65` | `satisfied?` | 47.05 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/type/value.rb:130` 14%, `RAILS/activerecord/lib/arel/visitors/postgresql.rb:136` 6%, `RAILS/activerecord/lib/active_record/relation/query_attribute.rb:61` 4% | Web::OauthController#callback 54%, Web::OauthController#mcp_connect 33%, Web::OauthController#authorize 14% | `.exists?` |
| 13 | `app/contexts/project_context.rb:9` | `initialize` | 46.97 | 0.0 | 0.0 | `GEM/bullet/lib/bullet/registry/call_stack.rb:12` 50%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 6%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 6% | Web::OauthController#mcp_connect 56%, Web::OauthController#callback 31%, Webhooks::SlackController#interactions 13% | `super(user, params, company: project&.company)` |
| 14 | `app/models/user_session.rb:26` | `start!` | 43.64 | 0.0 | 0.46 | `RAILS/activerecord/lib/arel/visitors/to_sql.rb:801` 10%, `RAILS/activerecord/lib/arel/nodes/bound_sql_literal.rb:20` 7%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:149` 3% | Web::SessionsController#create 100% | `where(user: user).where("revoked_at < :cut OR last_seen_at < :cut", cu` |
| 15 | `app/services/bitbucket/forge/installations.rb:51` | `create_for` | 40.12 | 0.0 | 0.04 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` 21%, `RAILS/activesupport/lib/active_support/code_generator.rb:30` 6%, `RAILS/activemodel/lib/active_model/attribute_methods.rb:333` 5% | Webhooks::BitbucketForgeController#heartbeat 96%, Webhooks::BitbucketForgeController#events 4%, Webhooks::BitbucketForgeController#lifecycle 0% | `BitbucketInstallation.create!(forge_installation_id: invocation.instal` |
| 16 | `app/models/identity_provider.rb:58` | `deployment!` | 39.94 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 5%, `RAILS/activemodel/lib/active_model/type/value.rb:130` 5%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 5% | Web::SessionsController#create 100% | `find_or_create_by!(kind: kind.to_s, scope: "deployment")` |
| 17 | `app/services/trigger_engine.rb:42` | `record_event` | 39.26 | 0.0 | 0.03 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` 21%, `RAILS/activemodel/lib/active_model/attribute_methods.rb:333` 5%, `RAILS/activesupport/lib/active_support/code_generator.rb:35` 5% | Webhooks::SlackController#interactions 81%, Webhooks::TrackersController#receive 19% | `TriggerEvent.create!(` |
| 18 | `app/services/auth/session_service.rb:16` | `record_proof` | 36.91 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/type/value.rb:130` 6%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` 4%, `RAILS/activerecord/lib/active_record/relation/query_attribute.rb:61` 4% | Web::SessionsController#create 100% | `proof = UserSessionProof.find_or_initialize_by(` |
| 19 | `app/controllers/web/oauth_controller.rb:327` | `resolve_owner` | 36.56 | 0.0 | 0.14 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 9%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 8%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 5% | Web::OauthController#callback 71%, Web::OauthController#authorize 29% | `current_user.company_memberships.active.find_by(company_id: owner_id)&` |
| 20 | `app/services/auth/identity_resolver.rb:153` | `link_identity` | 33.43 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/type/value.rb:130` 4%, `GEM/bullet/lib/bullet/ext/string.rb:9` 4%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` 3% | Web::SessionsController#create 100% | `identity = UserIdentity.find_or_initialize_by(identity_provider: provi` |
| 21 | `app/controllers/webhooks/trackers_controller.rb:20` | `receive` | 33.04 | 0.0 | 0.0 | `GEM/bullet/lib/bullet/registry/call_stack.rb:12` 56%, `GEM/bullet/lib/bullet/ext/string.rb:9` 3%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 3% | Webhooks::TrackersController#receive 100% | `provider = Trackers::Provider.for(subscription.integration)` |
| 22 | `app/controllers/web/oauth_controller.rb:191` | `mcp_connect` | 28.66 | 0.0 | 0.0 | `GEM/bullet/lib/bullet/registry/call_stack.rb:12` 54%, `GEM/bullet/lib/bullet/ext/string.rb:9` 3%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 3% | Web::OauthController#mcp_connect 100% | `owner = server && (server.credential_scope_per_user? ? current_user : ` |
| 23 | `app/models/project.rb:119` | `accessible_by?` | 28.04 | 0.0 | 0.19 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 6%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 6%, `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 4% | Web::OauthController#mcp_connect 53%, Web::OauthController#callback 30%, Webhooks::SlackController#interactions 11% | `membership = user.company_memberships.active.find_by(company_id: compa` |
| 24 | `app/controllers/web/oauth_controller.rb:329` | `resolve_owner` | 27.41 | 0.0 | 0.38 | `RAILS/activemodel/lib/active_model/type/value.rb:130` 14%, `RAILS/activerecord/lib/active_record/relation/query_attribute.rb:61` 13%, `RAILS/activerecord/lib/arel/visitors/postgresql.rb:136` 6% | Web::OauthController#callback 51%, Web::OauthController#mcp_connect 49% | `Project.for_user(current_user).find_by(id: owner_id)` |
| 25 | `app/models/project.rb:85` |  | 26.82 | 0.0 | 0.64 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:19` 6%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` 3% | Web::OauthController#mcp_connect 52%, Web::OauthController#callback 48%, Web::OauthController#mcp_connect_page 0% | `.or(where(id: user.collaborated_projects.select(:id)).where(company_id` |
| 26 | `app/services/bitbucket/forge/invocation_token.rb:52` | `fetch_keys` | 25.76 | 0.0 | 0.11 | `GEM/addressable/lib/addressable/uri.rb:486` 3%, `GEM/addressable/lib/addressable/uri.rb:480` 3%, `GEM/addressable/lib/addressable/uri.rb:136` 3% | Webhooks::BitbucketForgeController#heartbeat 70%, Webhooks::BitbucketForgeController#connect 12%, Webhooks::BitbucketForgeController#events 9% | `response = Faraday.new(request: { open_timeout: 3, timeout: 5 }).get(A` |
| 27 | `app/services/trigger_engine.rb:299` | `find_or_create_dispatch` | 23.9 | 0.0 | 0.02 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` 21%, `RAILS/activesupport/lib/active_support/code_generator.rb:30` 6%, `RAILS/activemodel/lib/active_model/attribute_methods.rb:333` 5% | Webhooks::SlackController#interactions 100% | `TriggerDispatch.create!(` |
| 28 | `app/controllers/webhooks/ingress_controller.rb:33` | `receive` | 22.93 | 0.0 | 0.02 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` 18%, `RAILS/activerecord/lib/active_record/connection_adapters/abstract_adapter.rb:1213` 9%, `RAILS/activesupport/lib/active_support/code_generator.rb:30` 5% | Webhooks::IngressController#receive 100% | `received = ReceivedWebhook.create!(` |
| 29 | `app/state_machines/concerns/state_event_concern.rb:19` | `aasm` | 22.48 | 0.0 | 2.5 | `GEM/aasm/lib/aasm/state_machine.rb:10` 11%, `GEM/aasm/lib/aasm/state_machine.rb:12` 11%, `GEM/aasm/lib/aasm/aasm.rb:32` 11% | Web::SessionsController#create 37%, Web::OauthController#callback 31%, Web::OauthController#mcp_connect 19% | `super` |
| 30 | `app/models/tracker_delivery.rb:13` | `record` | 22.3 | 0.0 | 0.15 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract_adapter.rb:1213` 28%, `GEM/json/lib/json/common.rb:364` 6%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:149` 3% | Webhooks::TrackersController#receive 92%, Webhooks::TrackersController#receive_linear_app 8%, Webhooks::TrackersController#receive_app 0% | `create!(tracker_subscription: subscription, dedup_key: dedup_key, noti` |

App middleware that hands the request on (the stack below it, not its own work): `lib/middleware/raw_upload_body.rb:30` 293.56, `config/initializers/content_security_policy.rb:56` 110.87 warm objects per request.

216.12 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | Webhooks::SlackController#interactions | 5 / 5 | 7944.3 / 7947.0 | 2.8 | 15208.2 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` 609.0, `GEM/bullet/lib/bullet/registry/call_stack.rb:12` 415.0, `RAILS/activesupport/lib/active_support/code_generator.rb:35` 148.8 | `app/services/trigger_engine.rb:42` 1436.8, `app/services/trigger_engine.rb:299` 1081.3, `app/services/chat/run_catalog.rb:38` 394.0 |
| 2 | Webhooks::BitbucketForgeController#connect | 2 / 2 | 7443.0 / 7446.0 | 3.0 | 5664.5 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` 840.0, `RAILS/activesupport/lib/active_support/code_generator.rb:30` 242.0, `RAILS/activesupport/lib/active_support/code_generator.rb:35` 203.0 | `app/models/bitbucket_pairing.rb:24` 3143.0, `app/services/bitbucket/forge/invocation_token.rb:52` 575.0, `app/models/bitbucket_pairing.rb:22` 435.0 |
| 3 | Web::OauthController#mcp_connect | 13 / 13 | 5783.6 / 5784.8 | 1.2 | 5824.5 | `GEM/bullet/lib/bullet/registry/call_stack.rb:12` 1041.6, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 175.3, `RAILS/activemodel/lib/active_model/attribute.rb:9` 113.8 | `app/controllers/concerns/auth_concern.rb:249` 1067.8, `app/models/user.rb:290` 601.0, `app/controllers/web/oauth_controller.rb:191` 432.3 |
| 4 | Web::OauthController#callback | 22 / 22 | 5338.2 / 5343.0 | 4.7 | 5353.5 | `GEM/bullet/lib/bullet/registry/call_stack.rb:12` 699.4, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 132.3, `RAILS/activemodel/lib/active_model/attribute.rb:9` 110.5 | `app/controllers/concerns/auth_concern.rb:249` 1019.9, `app/models/user.rb:290` 576.0, `lib/middleware/raw_upload_body.rb:30` 381.9 |
| 5 | Web::OauthController#authorize | 6 / 6 | 4398.2 / 4399.8 | 1.6 | 4604.8 | `GEM/bullet/lib/bullet/registry/call_stack.rb:12` 589.0, `RAILS/activemodel/lib/active_model/attribute.rb:9` 108.6, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 108.0 | `app/controllers/concerns/auth_concern.rb:249` 1064.2, `app/models/user.rb:290` 601.0, `app/controllers/web/oauth_controller.rb:327` 378.8 |
| 6 | Web::SessionsController#create | 43 / 43 | 4278.8 / 4279.1 | 0.4 | 4344.1 | `GEM/bullet/lib/bullet/registry/call_stack.rb:12` 300.1, `RAILS/activemodel/lib/active_model/attribute.rb:9` 98.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 92.0 | `app/services/auth/identity_resolver.rb:81` 663.5, `app/services/auth/session_service.rb:20` 440.0, `app/models/user_session.rb:27` 342.2 |
| 7 | Webhooks::SlackController#commands | 2 / 2 | 4033.0 / 4038.0 | 5.0 | 4410.0 | `GEM/bullet/lib/bullet/registry/call_stack.rb:12` 289.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 126.0, `RAILS/activemodel/lib/active_model/type/value.rb:130` 111.0 | `app/services/slack/run_action.rb:138` 833.0, `app/models/project.rb:119` 302.0, `app/services/chat/run_catalog.rb:43` 275.0 |
| 8 | Webhooks::BitbucketForgeController#heartbeat | 9 / 9 | 3601.9 / 3603.4 | 1.5 | 3436.9 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` 189.0, `GEM/json/lib/json/common.rb:364` 62.5, `RAILS/activesupport/lib/active_support/code_generator.rb:30` 50.3 | `app/services/bitbucket/forge/installations.rb:51` 873.9, `app/services/bitbucket/forge/invocation_token.rb:52` 410.0, `lib/middleware/raw_upload_body.rb:30` 309.0 |
| 9 | Webhooks::TeamsController#activities | 25 / 25 | 3256.9 / 3257.3 | 0.4 | 3211.4 | `GEM/lograge/lib/lograge/formatters/key_value.rb:19` 134.0, `GEM/json/lib/json/common.rb:364` 109.4, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 27.9 | `app/services/teams/activity_authenticator.rb:58` 704.7, `lib/middleware/raw_upload_body.rb:30` 446.0, `app/models/chat_conversation.rb:89` 156.2 |
| 10 | Webhooks::BitbucketForgeController#events | 2 / 2 | 3256.0 / 3255.0 | -1.0 | 3255.0 | `GEM/json/lib/json/common.rb:364` 74.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 52.0, `RAILS/activerecord/lib/arel/visitors/postgresql.rb:136` 37.0 | `app/services/bitbucket/forge/invocation_token.rb:52` 437.0, `lib/middleware/raw_upload_body.rb:30` 327.0, `app/services/bitbucket/forge/installations.rb:51` 270.0 |
| 11 | Webhooks::TrackersController#receive | 16 / 16 | 3225.6 / 3227.1 | 1.5 | 3482.0 | `GEM/bullet/lib/bullet/registry/call_stack.rb:12` 411.9, `GEM/json/lib/json/common.rb:364` 139.8, `RAILS/activerecord/lib/active_record/connection_adapters/abstract_adapter.rb:1213` 76.3 | `app/controllers/webhooks/trackers_controller.rb:20` 398.7, `lib/middleware/raw_upload_body.rb:30` 356.3, `app/services/trackers/event_pipeline.rb:50` 251.5 |
| 12 | Webhooks::TrackersController#receive_linear_app | 2 / 2 | 2451.0 / 2451.0 | 0.0 | 1717.5 | `GEM/bullet/lib/bullet/registry/call_stack.rb:12` 295.0, `GEM/json/lib/json/common.rb:364` 113.0, `GEM/lograge/lib/lograge/formatters/key_value.rb:19` 87.0 | `app/services/trackers/linear/webhooks.rb:52` 907.0, `lib/middleware/raw_upload_body.rb:30` 377.0, `app/models/tracker_delivery.rb:13` 340.0 |
| 13 | Webhooks::BitbucketForgeController#status | 2 / 2 | 2136.0 / 2137.0 | 1.0 | 3729.0 | `GEM/json/lib/json/common.rb:364` 70.0, `RAILS/activesupport/lib/active_support/inflector/methods.rb:80` 28.0, `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:348` 26.0 | `app/services/bitbucket/forge/invocation_token.rb:52` 371.0, `lib/middleware/raw_upload_body.rb:30` 311.0, `app/services/bitbucket/forge/invocation_token.rb:32` 142.0 |
| 14 | Web::SessionsController#destroy | 3 / 3 | 2057.0 / 2047.5 | -9.5 | 2069.3 | `GEM/bullet/lib/bullet/registry/call_stack.rb:12` 306.0, `RAILS/activerecord/lib/arel/alias_predication.rb:8` 96.0, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:177` 77.0 | `app/controllers/concerns/auth_concern.rb:249` 1050.5, `lib/middleware/raw_upload_body.rb:30` 280.0, `config/initializers/content_security_policy.rb:56` 129.0 |
| 15 | Webhooks::IngressController#receive | 6 / 6 | 1834.6 / 1835.4 | 0.8 | 1842.2 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` 151.2, `RAILS/activerecord/lib/active_record/connection_adapters/abstract_adapter.rb:1213` 74.8, `GEM/lograge/lib/lograge/formatters/key_value.rb:19` 43.0 | `app/controllers/webhooks/ingress_controller.rb:33` 830.0, `lib/middleware/raw_upload_body.rb:30` 315.8, `app/controllers/webhooks/ingress_controller.rb:11` 179.2 |
| 16 | FeatureGatedTest::GatedController#reaping | 2 / 2 | 1354.0 / 1354.0 | 0.0 | 1165.0 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:80` 36.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 36.0, `RAILS/activemodel/lib/active_model/attribute.rb:9` 30.0 | `lib/middleware/raw_upload_body.rb:30` 352.0, `app/controllers/concerns/feature_gated.rb:42` 179.0, `config/initializers/content_security_policy.rb:56` 122.0 |
| 17 | Webhooks::SlackController#events | 9 / 9 | 1264.0 / 1264.1 | 0.1 | 1225.2 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract_adapter.rb:1213` 46.8, `GEM/lograge/lib/lograge/formatters/key_value.rb:19` 42.5, `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:348` 26.0 | `lib/middleware/raw_upload_body.rb:30` 314.9, `app/controllers/webhooks/slack_controller.rb:35` 165.0, `app/controllers/webhooks/slack_controller.rb:107` 131.5 |
| 18 | FeatureGatedTest::GatedController#index | 5 / 5 | 1171.5 / 1171.8 | 0.3 | 1414.4 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:80` 36.0, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0, `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:348` 26.0 | `lib/middleware/raw_upload_body.rb:30` 333.5, `config/initializers/content_security_policy.rb:56` 119.5, `app/controllers/concerns/feature_gated.rb:42` 90.3 |
| 19 | Webhooks::TrackersController#receive_app | 2 / 2 | 755.0 / 755.0 | 0.0 | 1740.5 | `GEM/lograge/lib/lograge/formatters/key_value.rb:19` 75.0, `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:348` 26.0, `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:336` 24.0 | `lib/middleware/raw_upload_body.rb:30` 363.0, `config/initializers/content_security_policy.rb:56` 125.0, `app/controllers/webhooks/trackers_controller.rb:33` 13.0 |
| 20 | Webhooks::BitbucketForgeController#disconnect | 1 / 1 | – / – |  | 4753.0 |  |  |
| 21 | Web::OauthController#mcp_connect_page | 1 / 1 | – / – |  | 4490.0 |  |  |
| 22 | Webhooks::BitbucketForgeController#lifecycle | 1 / 1 | – / – |  | 3129.0 |  |  |
| 23 | Webhooks::BitbucketForgeController#uninstall | 1 / 1 | – / – |  | 3005.0 |  |  |
| 24 | Web::OauthController#client_metadata | 1 / 1 | – / – |  | 878.0 |  |  |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/bullet/lib/bullet/registry/call_stack.rb:12` | `add` | 311.7 / 311.71 | 0.01 | 314.99 | 60% | String, Array |  | `app/controllers/concerns/auth_concern.rb:249` 24%, `app/services/auth/identity_resolver.rb:81` 23% | `@registry[key] \|\|= Thread.current.backtrace` |
| 2 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` | `get_oid_type` | 73.64 / 73.64 | 0.0 | 74.58 | 90% | Array |  | `app/controllers/concerns/auth_concern.rb:249` 10%, `app/services/auth/identity_resolver.rb:81` 10% | `type_map.fetch(oid, fmod, sql_type) {` |
| 3 | `RAILS/activemodel/lib/active_model/attribute.rb:9` | `from_database` | 60.23 / 60.23 | 0.0 | 60.76 | 88% | Object |  | `app/models/user.rb:290` 11%, `app/services/auth/identity_resolver.rb:81` 9% | `FromDatabase.new(name, value_before_type_cast, type, nil, value)` |
| 4 | `RAILS/activemodel/lib/active_model/type/value.rb:130` | `hash` | 51.04 / 51.04 | 0.0 | 51.64 | 92% | Array |  | `app/services/auth/policy_resolver.rb:65` 14%, `app/controllers/web/oauth_controller.rb:329` 8% | `[self.class, precision, scale, limit].hash` |
| 5 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` | `cast_result` | 49.86 / 49.86 | 0.0 | 50.52 | 90% | String, Array |  | `app/services/auth/identity_resolver.rb:81` 9%, `app/controllers/concerns/auth_concern.rb:249` 7% | `ActiveRecord::Result.new(fields, result.values, types.freeze, affected` |
| 6 | `GEM/lograge/lib/lograge/formatters/key_value.rb:19` | `format` | 46.82 / 46.82 | 0.0 | 46.93 | 100% | String |  | `lib/middleware/raw_upload_body.rb:30` 100% | `"#{key}=#{parse_value(key, value)}"` |
| 7 | `GEM/bullet/lib/bullet/ext/string.rb:9` | `bullet_class_name` | 44.95 / 44.95 | 0.0 | 45.35 | 88% | String, Struct |  | `app/services/auth/identity_resolver.rb:81` 11%, `app/controllers/concerns/auth_concern.rb:138` 10% | `last_colon ? self[0...last_colon].dup : self.dup` |
| 8 | `GEM/json/lib/json/common.rb:364` | `parse` | 42.51 / 42.49 | -0.02 | 42.65 | 72% | String, Hash |  | `lib/middleware/raw_upload_body.rb:30` 16%, `app/controllers/webhooks/teams_controller.rb:123` 10% | `Parser.parse(source, opts)` |
| 9 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` | `build_handle` | 40.38 / 40.38 | 0.0 | 40.62 | 100% | Object | #59613 merged 2026-11-04, after this app's version, not released yet, #59235 merged 2026-10-21, after this app's version, not released yet | `app/services/auth/session_service.rb:20` 8%, `lib/middleware/raw_upload_body.rb:30` 7% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 10 | `GEM/sentry-rails/lib/sentry/rails/breadcrumb/active_support_logger.rb:22` | `add` | 39.25 / 39.25 | 0.0 | 39.49 | 100% | Object, Hash |  | `lib/middleware/raw_upload_body.rb:30` 10%, `app/services/auth/session_service.rb:20` 7% | `crumb = Sentry::Breadcrumb.new(` |
| 11 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:151` † | `now` | 39.12 / 39.12 | 0.0 | 39.36 | 99% | Data |  | `lib/middleware/raw_upload_body.rb:30` 10%, `app/services/auth/session_service.rb:20` 7% | `Time.now` |
| 12 | `RAILS/activerecord/lib/arel/table.rb:85` | `[]` | 36.24 / 36.24 | 0.0 | 36.51 | 93% | Struct |  | `app/controllers/concerns/auth_concern.rb:249` 24%, `app/models/user_session.rb:27` 5% | `Attribute.new(table, name)` |
| 13 | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:101` † | `helper_names` | 33.76 / 33.76 | 0.0 | 38.59 | 4% | String, Array |  | `lib/middleware/raw_upload_body.rb:30` 100% | `@path_helpers.map(&:to_s) + @url_helpers.map(&:to_s)` |
| 14 | `RAILS/activerecord/lib/active_record/relation/query_attribute.rb:61` | `hash` | 30.74 / 30.74 | 0.0 | 31.24 | 92% | Array |  | `app/controllers/web/oauth_controller.rb:329` 12%, `app/services/auth/identity_resolver.rb:81` 7% | `[self.class, name, value_for_database, type].hash` |
| 15 | `RAILS/activerecord/lib/arel/visitors/postgresql.rb:136` | `visit_Arel_Nodes_IsDistinctFrom` | 27.75 / 27.75 | 0.0 | 27.95 | 90% | String |  | `app/services/auth/policy_resolver.rb:65` 11%, `app/models/user_session.rb:27` 7% | `BIND_BLOCK = proc { \|i\| "$#{i}" }` |
| 16 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` | `expand_from_hash` | 26.97 / 26.97 | 0.0 | 27.35 | 90% | Array |  | `app/services/auth/session_service.rb:16` 6%, `app/models/user.rb:277` 5% | `attributes.flat_map do \|key, value\|` |
| 17 | `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:348` | `validate` | 25.86 / 25.86 | 0.0 | 26.0 | 100% | String |  | `config/initializers/content_security_policy.rb:56` 100% | `if source.include?(";") \|\| source != source.gsub(/[[:space:]]/, "")` |
| 18 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:78` | `camelize` | 25.23 / 25.23 | 0.0 | 25.36 | 100% | String, MatchData |  | `lib/middleware/raw_upload_body.rb:30` 95%, `app/services/trackers.rb:4` 2% | `string = string.sub(/^[a-z\d]*/) { \|match\| inflections.acronyms[match]` |
| 19 | `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:336` | `build_directives` | 23.87 / 23.87 | 0.0 | 24.0 | 100% | String |  | `config/initializers/content_security_policy.rb:56` 100% | `"#{directive} #{build_directive(directive, sources, context).join(' ')` |
| 20 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` | `as` | 23.82 / 23.82 | 0.0 | 24.3 | 25% | String, Hash |  | `app/controllers/concerns/auth_concern.rb:249` 96%, `app/services/trackers/jira/webhooks.rb:51` 2% | `Nodes::As.new self, Nodes::SqlLiteral.new(other, retryable: true)` |
| 21 | `RUBY/random/formatter.rb:174` † | `uuid` | 23.01 / 23.01 | 0.0 | 23.13 | 100% | String, Array |  | `no app frame` 91%, `app/controllers/webhooks/trackers_controller.rb:68` 2% | `ary.unpack("H8H4H4H4H12").join(?-)` |
| 22 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` | `+` | 22.48 / 22.48 | 0.0 | 22.77 | 90% | Array, Object |  | `app/controllers/concerns/auth_concern.rb:249` 4%, `app/models/user_session.rb:26` 4% | `WhereClause.new(predicates + other.predicates)` |
| 23 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:80` | `camelize` | 22.4 / 22.4 | 0.0 | 22.51 | 100% | String, MatchData |  | `lib/middleware/raw_upload_body.rb:30` 95%, `app/services/trackers.rb:4` 2% | `string.gsub!(/(?:_\|(\/))([a-z\d]*)/i) do` |
| 24 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` † | `method_name` | 21.44 / 21.44 | 0.0 | 34.94 | 3% | String |  | `app/services/trigger_engine.rb:42` 24%, `app/services/bitbucket/forge/installations.rb:51` 24% | `@method_name % attr_name` |
| 25 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:149` | `change` | 21.25 / 21.25 | 0.0 | 21.45 | 64% | Rational, Data |  | `app/services/auth/session_service.rb:20` 20%, `app/models/user_session.rb:27` 20% | `::Time.utc(new_year, new_month, new_day, new_hour, new_min, new_sec)` |
| 26 | `GEM/tzinfo/lib/tzinfo/timestamp.rb:208` | `for_time` | 21.11 / 21.11 | 0.0 | 21.18 | 80% | Rational, Bignum |  | `app/services/auth/identity_resolver.rb:158` 18%, `app/models/user_session.rb:52` 14% | `sub_second = time.subsec` |
| 27 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:166` | `convert_dot_notation_to_hash` | 20.78 / 20.78 | 0.0 | 21.11 | 90% | Array, Hash |  | `app/controllers/web/sessions_controller.rb:221` 5%, `app/forms/user_sign_in_form.rb:17` 5% | `attributes.each_with_object({}) do \|(key, value), converted\|` |
| 28 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:29` | `references` | 20.78 / 20.78 | 0.0 | 21.11 | 90% | Array |  | `app/forms/user_sign_in_form.rb:17` 5%, `app/models/user.rb:277` 5% | `attributes.each_with_object([]) do \|(key, value), result\|` |
| 29 | `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` | `keys` | 20.7 / 20.7 | 0.0 | 20.9 | 59% | Array, Hash |  | `app/services/auth/identity_resolver.rb:158` 19%, `app/models/user.rb:277` 14% | `keys = values.keys \| types.keys \| @attributes.keys` |
| 30 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` | `deep_dup` | 19.9 / 19.9 | 0.0 | 20.04 | 100% | String, Object |  | `no app frame` 80%, `app/forms/user_sign_in_form.rb:17` 2% | `duplicable? ? dup : self` |

## Dev/test-mode work

28.1 of 3555.8 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | route build | `RAILS/actionpack/lib/action_dispatch/journey/gtg/transition_table.rb:52` | 5.03 | 100% | `lib/middleware/raw_upload_body.rb:30` 100% | `next_states = []` |
| 2 | route build | `RAILS/actionpack/lib/action_dispatch/journey/gtg/simulator.rb:48` | 2.6 | 100% | `lib/middleware/raw_upload_body.rb:30` 100% | `token = string.byteslice(start_index, pos - start_index)` |
| 3 | debug logging | `GEM/lograge/lib/lograge/rails_ext/rack/logger.rb:21` | 1.99 | 100% | `no app frame` 100% | `[status, headers, ::Rack::BodyProxy.new(body) {}] # rubocop:disable Li` |
| 4 | debug logging | `GEM/sentry-rails/lib/sentry/rails/log_subscriber.rb:61` | 1.99 | 100% | `lib/middleware/raw_upload_body.rb:30` 100% | `Sentry.logger.public_send(level, message, **attributes, origin: origin` |
| 5 | asset lookup | `GEM/propshaft/lib/propshaft/server.rb:16` | 1.82 | 100% | `no app frame` 100% | `if (method == "GET" \|\| method == "HEAD") && path.start_with?(@assembly` |
| 6 | asset lookup | `GEM/propshaft/lib/propshaft/server.rb:13` | 0.99 | 100% | `no app frame` 100% | `path = env["PATH_INFO"]` |
| 7 | asset lookup | `GEM/propshaft/lib/propshaft/server.rb:14` | 0.99 | 100% | `no app frame` 100% | `method = env["REQUEST_METHOD"]` |
| 8 | asset lookup | `GEM/propshaft/lib/propshaft/server.rb:60` | 0.99 | 100% | `no app frame` 100% | `if @assembly.config.sweep_cache` |
| 9 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/dev_server_proxy.rb:39` | 0.99 | 100% | `no app frame` 100% | `.sub(HOST_WITH_PORT_REGEX, "/") # Hanami adds the host and port.` |
| 10 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/dev_server_proxy.rb:40` | 0.99 | 100% | `no app frame` 100% | `.sub(".ts.js", ".ts") # Hanami's javascript helper always adds the ext` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activerecord | 1174.0 | 1210.4 | `postgresql_adapter.rb:880` 73.6, `database_statements.rb:176` 49.9, `table.rb:85` 36.2 |
| rails: activesupport | 548.5 | 572.7 | `fanout.rb:288` 40.4, `fanout.rb:151` 39.1, `methods.rb:78` 25.2 |
| gem: bullet | 445.0 | 450.5 | `call_stack.rb:12` 311.7, `string.rb:9` 45.0, `base.rb:29` 10.6 |
| rails: actionpack | 275.9 | 488.8 | `route_set.rb:101` 33.8, `content_security_policy.rb:348` 25.9, `content_security_policy.rb:336` 23.9 |
| rails: activemodel | 246.9 | 280.2 | `attribute.rb:9` 60.2, `value.rb:130` 51.0, `attribute_methods.rb:492` 21.4 |
| test harness: webmock | 118.5 | 119.7 | `headers.rb:69` 22.2, `headers.rb:68` 17.9, `uri.rb:62` 10.4 |
| gem: addressable | 98.3 | 101.5 | `uri.rb:486` 5.9, `uri.rb:480` 5.1, `uri.rb:1544` 4.9 |
| gem: sentry-rails | 95.2 | 95.9 | `active_support_logger.rb:22` 39.2, `active_support_logger.rb:27` 19.6, `active_support_logger.rb:18` 19.6 |
| ruby default gem: uri | 72.3 | 73.7 | `common.rb:465` 11.5, `common.rb:456` 9.8, `common.rb:108` 5.9 |
| gem: sentry-ruby | 65.5 | 66.3 | `hub.rb:295` 19.6, `sample_rand.rb:53` 3.7, `key_value_collection.rb:100` 3.2 |
| gem: lograge | 63.9 | 64.1 | `key_value.rb:19` 46.8, `key_value.rb:27` 3.0, `logger.rb:21` 2.0 |
| app | 62.5 | 109.4 | `application.rb:58` 3.0, `state_event_concern.rb:23` 2.7, `state_event_concern.rb:19` 2.7 |
| gem: rack | 60.9 | 61.5 | `utils.rb:693` 17.3, `body_proxy.rb:12` 5.0, `request.rb:604` 4.8 |
| ruby stdlib | 47.6 | 49.2 | `formatter.rb:174` 23.0, `normalize.rb:138` 4.0, `ipaddr.rb:725` 2.3 |
| gem: tzinfo | 46.0 | 46.2 | `timestamp.rb:208` 21.1, `timestamp.rb:193` 10.7, `constant_offset_data_timezone_info.rb:52` 10.7 |
| gem: json | 44.5 | 44.6 | `common.rb:364` 42.5, `common.rb:1089` 2.0, `common.rb:199` 0.0 |
| gem: aasm | 37.1 | 37.6 | `state_machine_store.rb:29` 4.8, `active_record_persistence.rb:46` 4.5, `state_machine.rb:12` 2.7 |
| gem: omniauth | 29.8 | 30.1 | `paths.rb:67` 8.0, `strategy.rb:281` 4.0, `paths.rb:94` 4.0 |
| gem: concurrent-ruby | 24.2 | 24.5 | `safe_initialization.rb:30` 6.0, `non_concurrent_map_backend.rb:131` 4.8, `mutex_lockable_object.rb:33` 2.0 |
| gem: jwt | 24.0 | 24.8 | `decode_verifier.rb:33` 3.0, `encoded_token.rb:36` 1.7, `rsa.rb:156` 1.7 |
| gem: mocha | 21.6 | 22.5 | `parameters_matcher.rb:37` 3.6, `expectation_list.rb:55` 3.6, `invocation.rb:45` 1.8 |
| gem: enumerize | 18.2 | 22.2 | `attribute.rb:41` 4.1, `attribute_map.rb:13` 3.8, `base.rb:106` 2.5 |
| gem: faraday | 15.4 | 16.2 | `options.rb:97` 0.9, `request.rb:83` 0.8, `connection.rb:465` 0.7 |
| ruby default gem: net-http | 12.4 | 12.6 | `header.rb:205` 1.6, `header.rb:284` 1.3, `header.rb:227` 1.2 |
| gem: debug | 12.4 | 12.9 | `thread_client.rb:903` 3.5, `thread_client.rb:223` 1.8, `session.rb:140` 1.8 |
| gem: base64 | 11.0 | 11.1 | `base64.rb:283` 5.3, `base64.rb:310` 3.9, `base64.rb:377` 0.9 |
| gem: rack-cors | 9.4 | 9.5 | `cors.rb:123` 5.4, `resource.rb:40` 2.0, `result.rb:38` 1.0 |
| rails: actionview | 8.1 | 8.5 | `view_paths.rb:90` 1.0, `lookup_context.rb:47` 1.0, `lookup_context.rb:238` 1.0 |
| gem: inertia_rails | 5.2 | 5.6 | `middleware.rb:139` 1.0, `middleware.rb:117` 1.0, `middleware.rb:10` 1.0 |
| rails: railties | 5.0 | 5.0 | `logger.rb:24` 1.0, `logger.rb:65` 1.0, `logger.rb:29` 1.0 |
| ruby default gem: securerandom | 4.8 | 4.9 | `securerandom.rb:71` 4.8 |
| gem: propshaft | 4.8 | 4.8 | `server.rb:16` 1.8, `server.rb:60` 1.0, `server.rb:13` 1.0 |
| gem: bcrypt | 4.4 | 4.5 | `password.rb:102` 1.4, `engine.rb:70` 0.7, `password.rb:103` 0.7 |
| gem: ransack | 3.8 | 4.0 | `join_dependency.rb:11` 1.6, `join_dependency.rb:31` 0.6, `join_dependency.rb:47` 0.6 |
| rails: activejob | 3.6 | 3.8 | `enqueuing.rb:62` 0.7, `core.rb:129` 0.5, `instrumentation.rb:33` 0.2 |
| gem: vite_ruby | 3.0 | 3.4 | `dev_server_proxy.rb:39` 1.0, `dev_server_proxy.rb:41` 1.0, `dev_server_proxy.rb:40` 1.0 |
| gem: rack-session | 3.0 | 3.0 | `id.rb:275` 1.0, `id.rb:277` 1.0, `id.rb:368` 0.5 |
| gem: faraday-net_http | 2.3 | 2.4 | `net_http.rb:81` 0.7, `net_http.rb:80` 0.3, `net_http.rb:123` 0.3 |
| gem: zeitwerk | 2.1 | 4.3 | `cref.rb:47` 0.5, `constant_path_validator.rb:13` 0.4, `file_system.rb:203` 0.4 |
| ruby default gem: openssl | 2.1 | 2.1 | `cipher.rb:56` 0.7, `pkey.rb:354` 0.4, `hmac.rb:55` 0.3 |
| gem: request_store | 2.0 | 2.0 | `middleware.rb:21` 1.0, `middleware.rb:28` 1.0 |
| gem: config | 0.8 | 0.8 | `options.rb:125` 0.5, `options.rb:156` 0.2 |
| gem: solid_queue | 0.5 | 0.5 | `batch_id.rb:20` 0.2, `batch_id.rb:24` 0.2 |
| gem: hashie | 0.2 | 1.1 | `mash.rb:591` 0.1, `mash.rb:587` 0.1, `mash.rb:596` 0.0 |
| ruby default gem: erb | 0.0 | 0.1 | `util.rb:65` 0.0 |
| gem: pg | 0.0 | 0.0 | `result.rb:17` 0.0 |
| gem: rails-html-sanitizer | 0.0 | 0.0 | `sanitizer.rb:39` 0.0 |
| gem: json-jwt | 0.0 | 0.2 | `jwt.rb:108` 0.0, `jws.rb:194` 0.0, `jws.rb:182` 0.0 |
| gem: i18n | 0.0 | 0.0 | `utils.rb:8` 0.0, `base.rb:58` 0.0, `i18n.rb:396` 0.0 |
| lowrail-profile | 0.0 | 0.0 | `profile.rb:93` 0.0, `profile.rb:103` 0.0, `profile.rb:56` 0.0 |
| gem: bootsnap | 0.0 | 0.2 | `cache.rb:218` 0.0, `cache.rb:205` 0.0, `loaded_features_index.rb:118` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Jobs

| # | Job | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | Webhooks::ProcessEventJob#perform | 1 / 1 | – / – |  | 10009.0 |  |  |
| 2 | Teams::UnboundTenantHintJob#perform | 1 / 1 | – / – |  | 2473.0 |  |  |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/addressable/lib/addressable/uri.rb:486` | 31.5 / 31.5 | 100% | `app/services/teams/connector_client.rb:86` 58%, `app/services/teams/token_service.rb:65` 42% | `result = uri.gsub(/%[0-9a-f]{2}/i) do \|sequence\|` |
| 2 | `GEM/addressable/lib/addressable/uri.rb:480` | 26.0 / 26.0 | 100% | `app/services/teams/connector_client.rb:86` 53%, `app/services/teams/token_service.rb:65` 47% | `if ![String, ::Addressable::URI].include?(return_type)` |
| 3 | `GEM/addressable/lib/addressable/uri.rb:1544` | 24.5 / 24.5 | 100% | `app/services/teams/connector_client.rb:86` 53%, `app/services/teams/token_service.rb:65` 47% | `result = path.strip.split(SLASH, -1).map do \|segment\|` |
| 4 | `GEM/addressable/lib/addressable/uri.rb:419` | 22.0 / 22.0 | 100% | `app/services/teams/connector_client.rb:86` 54%, `app/services/teams/token_service.rb:65` 46% | `if ![String, Regexp].include?(character_class.class)` |
| 5 | `GEM/addressable/lib/addressable/uri.rb:428` | 22.0 / 22.0 | 100% | `app/services/teams/connector_client.rb:86` 54%, `app/services/teams/token_service.rb:65` 46% | `component = component.dup` |
| 6 | `GEM/addressable/lib/addressable/uri.rb:431` | 22.0 / 22.0 | 100% | `app/services/teams/connector_client.rb:86` 54%, `app/services/teams/token_service.rb:65` 46% | `component = component.gsub(character_class) do \|char\|` |
| 7 | `GEM/addressable/lib/addressable/uri.rb:563` | 22.0 / 22.0 | 100% | `app/services/teams/connector_client.rb:86` 54%, `app/services/teams/token_service.rb:65` 46% | `if ![String, Regexp].include?(character_class.class)` |
| 8 | `GEM/addressable/lib/addressable/uri.rb:584` | 22.0 / 22.0 | 100% | `app/services/teams/connector_client.rb:86` 54%, `app/services/teams/token_service.rb:65` 46% | `component = component.dup` |
| 9 | `RUBY/unicode_normalize/normalize.rb:138` | 22.0 / 22.0 | 100% | `app/services/teams/connector_client.rb:86` 54%, `app/services/teams/token_service.rb:65` 46% | `string.gsub REGEXP_C, NF_HASH_C` |
| 10 | `GEM/addressable/lib/addressable/uri.rb:136` | 17.5 / 17.5 | 100% | `app/services/teams/connector_client.rb:86` 57%, `app/services/teams/token_service.rb:65` 43% | `scan = uri.scan(URIREGEX)` |
