# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bundle exec rspec --seed 1234 --format documentation --exclude-pattern spec/system/**/*_spec.rb`
* Ruby: ruby 3.4.3 (2025-04-14 revision d0b7e5b6a0) +PRISM [x86_64-linux]
* Rails: 8.1.3, test environment
* Counted in run 1: 34 requests, 10 mail windows; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 34 | 2539.7 | 0 | 10 | 0 | 0 |
| run2 | 1 | 34 | 2541.1 | 0 | 10 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.0 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/views/layouts/application.html.erb:3` |  | 45.44 | 13.85 | 0.26 | `RUBY/pathname.rb:51` 23%, `RUBY/pathname.rb:55` 18%, `RUBY/pathname.rb:358` 10% | EvaluationsController#index 67%, ProposalsController#index 33%, ProposalsController#edit 0% | `<%= vite_typescript_tag "inertia" %>` |
| 2 | `app/views/layouts/core.html.erb:17` |  | 43.94 | 13.5 | 0.35 | `RUBY/pathname.rb:51` 24%, `RUBY/pathname.rb:55` 19%, `RUBY/pathname.rb:358` 10% | EvaluationsController#index 67%, ProposalsController#index 33%, ProposalsController#new 0% | `<%= vite_javascript_tag 'application', media: 'all' %>` |
| 3 | `app/controllers/evaluations_controller.rb:10` | `index` | 38.68 | 1.59 | 0.24 | `GEM/json/lib/json/common.rb:355` 7%, `RAILS/activemodel/lib/active_model/attribute_methods.rb:273` 4%, `GEM/sqlite3/lib/sqlite3/statement.rb:186` 3% | EvaluationsController#index 100% | `render inertia: {evaluations: serialize(evaluations)}` |
| 4 | `app/forms/proposal_form.rb:55` | `submit!` | 36.62 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 7%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:146` 5%, `RAILS/activerecord/lib/arel/table.rb:85` 4% | ProposalsController#create 59%, ProposalsController#update 41% | `proposal.save!` |
| 5 | `app/controllers/concerns/authenticated.rb:30` | `current_user` | 35.29 | 0.0 | 0.0 | `GEM/json/lib/json/common.rb:355` 12%, `GEM/uri/lib/uri/common.rb:465` 12%, `GEM/rack/lib/rack/utils.rb:331` 7% | ReviewsController#update 25%, ProposalsController#create 15%, ProposalsController#update 15% | `if (auth_token = cookies.signed[:session_token])` |
| 6 | `app/controllers/concerns/authenticated.rb:31` | `current_user` | 31.76 | 0.0 | 1.18 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` 15%, `GEM/sqlite3/lib/sqlite3/statement.rb:54` 6%, `RAILS/activerecord/lib/active_record/connection_adapters/sqlite3/database_statements.rb:123` 6% | ReviewsController#update 25%, ProposalsController#create 15%, ProposalsController#update 15% | `User.find_by(auth_token:)` |
| 7 | `app/forms/proposal_form.rb:56` | `submit!` | 28.74 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 6%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:146` 5%, `RAILS/activemodel/lib/active_model/type/string.rb:39` 4% | ProposalsController#create 59%, ProposalsController#update 41% | `speaker_profile.save!` |
| 8 | `app/controllers/reviews_controller.rb:30` | `set_review` | 28.68 | 0.0 | 0.15 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 5%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 4%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 3% | ReviewsController#update 100% | `@review = current_user.reviews.find(params[:id])` |
| 9 | `app/controllers/proposals/confirmations_controller.rb:18` | `set_proposal` | 27.06 | 0.0 | 0.24 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 4%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 3%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 3% | Proposals::ConfirmationsController#create 50%, Proposals::ConfirmationsController#destroy 50% | `@proposal = current_user.proposals.accepted.find_by!(external_id: para` |
| 10 | `app/controllers/proposals_controller.rb:12` | `index` | 25.74 | 0.79 | 0.12 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:273` 7%, `GEM/json/lib/json/common.rb:355` 6%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 4% | ProposalsController#index 100% | `render inertia: {proposals: serialize(current_user.proposals.active)}` |
| 11 | `app/forms/proposal_form.rb:110` | `attributes_from_context` | 21.97 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 5%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 4% | ProposalsController#update 55%, ProposalsController#create 45%, ProposalsController#new 0% | `profile = user&.speaker_profile` |
| 12 | `app/controllers/reviews_controller.rb:34` | `check_deadline` | 20.74 | 0.0 | 0.0 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 4% | ReviewsController#update 100% | `return unless @review.evaluation.deadline&.past?` |
| 13 | `app/controllers/proposals_controller.rb:64` | `set_proposal` | 17.56 | 0.0 | 0.18 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` 7%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 5%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 4% | ProposalsController#update 100%, ProposalsController#show 0%, ProposalsController#destroy 0% | `@proposal = current_user.proposals.find_by!(external_id: params[:id])` |
| 14 | `app/forms/application_form.rb:69` | `initialize_from_params` | 16.74 | 0.06 | 0.59 | `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:1329` 16%, `RAILS/activemodel/lib/active_model/attribute.rb:101` 14%, `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:405` 9% | ReviewsController#update 31%, ProposalsController#create 29%, ProposalsController#update 27% | `initialize(params.permit(permitted_attributes))` |
| 15 | `app/forms/proposal_form.rb:70` | `assign_attributes` | 14.94 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:101` 6%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 6%, `RAILS/activerecord/lib/active_record/associations/association.rb:221` 5% | ProposalsController#create 100%, ProposalsController#new 0% | `@proposal = user.proposals.new(build_proposal_attributes)` |
| 16 | `app/forms/review_form.rb:15` | `submit!` | 13.18 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 8%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 7%, `GEM/tzinfo/lib/tzinfo/timestamp.rb:208` 4% | ReviewsController#update 100% | `review.save!` |
| 17 | `app/forms/application_form.rb:90` | `with_transaction` | 12.79 | 0.0 | 0.24 | `RAILS/activerecord/lib/active_record/attribute_methods/primary_key.rb:19` 15%, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:348` 7%, `RAILS/actionview/lib/action_view/lookup_context.rb:47` 7% | ProposalsController#create 40%, ProposalsController#update 26%, ReviewsController#update 23% | `def with_transaction(&) = ApplicationRecord.transaction(&)` |
| 18 | `app/controllers/evaluations_controller.rb:5` | `index` | 9.06 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 8%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 8%, `RAILS/activerecord/lib/active_record/relation.rb:77` 4% | EvaluationsController#index 100% | `evaluations = current_user.evaluations.active` |
| 19 | `app/controllers/proposals_controller.rb:52` | `update` | 8.71 | 0.06 | 0.09 | `GEM/i18n/lib/i18n.rb:476` 8%, `GEM/i18n/lib/i18n/backend/base.rb:157` 8%, `GEM/i18n/lib/i18n.rb:396` 5% | ProposalsController#update 100% | `redirect_to edit_proposal_path(@proposal), inertia: {errors: form.erro` |
| 20 | `app/controllers/reviews_controller.rb:7` | `index` | 8.65 | 0.0 | 0.03 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 4%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 4%, `RAILS/activerecord/lib/active_record/relation/query_methods.rb:1821` 3% | ReviewsController#index 100% | `evaluation = current_user.evaluations.find(params[:evaluation_id])` |
| 21 | `app/forms/application_form.rb:77` | `assign_attributes` | 8.53 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:13` 20%, `RAILS/activemodel/lib/active_model/attribute_assignment.rb:68` 20%, `RAILS/activemodel/lib/active_model/attribute_methods.rb:312` 20% | ProposalsController#update 46%, ProposalsController#create 25%, ReviewsController#update 23% | `super(attrs.reverse_merge(attributes_from_context))` |
| 22 | `app/forms/proposal_form.rb:73` | `assign_attributes` | 7.41 | 0.0 | 0.09 | `RAILS/activemodel/lib/active_model/attribute.rb:101` 10%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 10%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 5% | ProposalsController#create 100%, ProposalsController#edit 0%, ProposalsController#new 0% | `@speaker_profile = user.speaker_profile \|\| user.build_speaker_profile` |
| 23 | `app/controllers/reviews_controller.rb:36` | `check_deadline` | 6.82 | 0.12 | 0.12 | `RAILS/activesupport/lib/active_support/messages/rotator.rb:55` 5%, `RAILS/activesupport/lib/active_support/key_generator.rb:63` 4%, `GEM/uri/lib/uri/rfc3986_parser.rb:85` 3% | ReviewsController#update 100% | `redirect_to review_path(@review), alert: "The evaluation deadline has ` |
| 24 | `app/forms/evaluation/submit_form.rb:57` | `notify_speakers` | 6.18 | 0.0 | 0.21 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 5%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 4% | Evaluations::ResultsController#create 100% | `ProposalDelivery.with(proposal:, speaker: proposal.speaker_profile).pu` |
| 25 | `app/forms/evaluation/submit_form.rb:26` | `submit!` | 5.97 | 0.0 | 0.03 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 14%, `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 9%, `GEM/tzinfo/lib/tzinfo/timestamp.rb:208` 4% | Evaluations::ResultsController#create 100% | `proposal.update!(status: it[:status])` |
| 26 | `app/forms/application_form.rb:60` | `save` | 5.85 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:312` 38%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 23%, `RAILS/activemodel/lib/active_model/validations/length.rb:49` 15% | ProposalsController#update 50%, ProposalsController#create 38%, ReviewsController#update 8% | `return false unless valid?` |
| 27 | `app/controllers/evaluations_controller.rb:7` | `index` | 5.59 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/relation/query_methods.rb:1821` 5%, `GEM/sqlite3/lib/sqlite3/statement.rb:54` 3%, `RAILS/activerecord/lib/active_record/relation/query_methods.rb:1794` 3% | EvaluationsController#index 100% | `if evaluations.size == 1` |
| 28 | `app/forms/evaluation/submit_form.rb:18` | `submit!` | 5.35 | 0.0 | 0.09 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 16%, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 8%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 7% | Evaluations::ResultsController#create 100% | `locked_proposals = Proposal.lock.where(external_id: proposals.map { it` |
| 29 | `app/controllers/proposals_controller.rb:25` | `create` | 5.29 | 0.18 | 0.09 | `GEM/uri/lib/uri/common.rb:108` 7%, `GEM/uri/lib/uri/rfc3986_parser.rb:85` 7%, `RAILS/actionpack/lib/action_dispatch/http/url.rb:325` 5% | ProposalsController#create 100% | `redirect_to proposals_path` |
| 30 | `app/forms/proposal_form.rb:74` | `assign_attributes` | 4.76 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:273` 22%, `RAILS/activemodel/lib/active_model/attribute_assignment.rb:68` 22%, `RAILS/activemodel/lib/active_model/attribute.rb:13` 22% | ProposalsController#update 56%, ProposalsController#create 44%, ProposalsController#edit 0% | `@speaker_profile.assign_attributes(build_speaker_attributes)` |

314.82 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | ProposalsController#index | 2 / 2 | 3041.0 / 3041.0 | 0.0 | 3041.0 | `RUBY/pathname.rb:51` 240.0, `RUBY/pathname.rb:55` 188.0, `GEM/json/lib/json/common.rb:355` 132.0 | `app/controllers/proposals_controller.rb:12` 875.0, `app/views/layouts/application.html.erb:3` 515.0, `app/views/layouts/core.html.erb:17` 498.0 |
| 2 | EvaluationsController#index | 3 / 3 | 2958.5 / 2958.5 | 0.0 | 2308.3 | `RUBY/pathname.rb:51` 240.0, `RUBY/pathname.rb:55` 188.0, `GEM/json/lib/json/common.rb:355` 125.5 | `app/controllers/evaluations_controller.rb:10` 657.5, `app/views/layouts/application.html.erb:3` 515.0, `app/views/layouts/core.html.erb:17` 498.0 |
| 3 | ProposalsController#create | 4 / 4 | 1752.3 / 1752.3 | 0.0 | 1868.0 | `GEM/uri/lib/uri/common.rb:465` 85.3, `RAILS/activemodel/lib/active_model/attribute.rb:101` 31.0, `RAILS/activemodel/lib/active_model/attribute_methods.rb:312` 29.0 | `app/forms/proposal_form.rb:55` 244.7, `app/forms/proposal_form.rb:56` 193.7, `app/forms/proposal_form.rb:70` 169.3 |
| 4 | Evaluations::ResultsController#create | 2 / 2 | 1658.0 / 1679.0 | 21.0 | 1601.5 | `GEM/uri/lib/uri/common.rb:456` 54.0, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 39.0, `RAILS/activemodel/lib/active_model/attribute.rb:9` 31.0 | `app/forms/evaluation/submit_form.rb:57` 210.0, `app/forms/evaluation/submit_form.rb:26` 203.0, `app/forms/evaluation/submit_form.rb:18` 182.0 |
| 5 | ProposalsController#update | 4 / 4 | 1663.3 / 1664.3 | 1.0 | 1694.8 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:312` 41.0, `RAILS/activemodel/lib/active_model/attribute.rb:9` 38.3, `GEM/uri/lib/uri/common.rb:465` 38.3 | `app/controllers/proposals_controller.rb:64` 199.0, `app/forms/proposal_form.rb:55` 170.3, `app/forms/proposal_form.rb:110` 138.0 |
| 6 | ReviewsController#index | 2 / 2 | 1471.0 / 1471.0 | 0.0 | 4706.5 | `RAILS/actionpack/lib/action_controller/metal/rescue.rb:39` 322.0, `RAILS/actionview/lib/action_view/template/resolver.rb:127` 84.0, `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/collection/map/non_concurrent_map_backend.rb:131` 35.0 | `app/controllers/reviews_controller.rb:7` 294.0, `app/controllers/concerns/authenticated.rb:30` 60.0, `app/controllers/concerns/authenticated.rb:31` 54.0 |
| 7 | Proposals::ConfirmationsController#create | 3 / 3 | 1443.0 / 1443.0 | 0.0 | 1379.0 | `RAILS/actionpack/lib/action_controller/metal/rescue.rb:39` 324.0, `RAILS/actionview/lib/action_view/template/resolver.rb:127` 90.0, `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/collection/map/non_concurrent_map_backend.rb:131` 53.0 | `app/controllers/proposals/confirmations_controller.rb:18` 230.0, `app/controllers/concerns/authenticated.rb:30` 60.0, `app/controllers/concerns/authenticated.rb:31` 54.0 |
| 8 | Proposals::ConfirmationsController#destroy | 3 / 3 | 1439.0 / 1439.0 | 0.0 | 1353.7 | `RAILS/actionpack/lib/action_controller/metal/rescue.rb:39` 324.0, `RAILS/actionview/lib/action_view/template/resolver.rb:127` 90.0, `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/collection/map/non_concurrent_map_backend.rb:131` 53.0 | `app/controllers/proposals/confirmations_controller.rb:18` 230.0, `app/controllers/concerns/authenticated.rb:30` 60.0, `app/controllers/concerns/authenticated.rb:31` 54.0 |
| 9 | ReviewsController#update | 6 / 6 | 1256.8 / 1260.4 | 3.6 | 1453.7 | `GEM/uri/lib/uri/common.rb:456` 31.8, `GEM/hashie/lib/hashie/mash.rb:374` 27.0, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 24.0 | `app/controllers/reviews_controller.rb:30` 195.0, `app/controllers/reviews_controller.rb:34` 141.0, `app/forms/review_form.rb:15` 89.6 |
| 10 | Evaluations::ResultsController#index | 1 / 1 | – / – |  | 4882.0 |  |  |
| 11 | ProposalsController#new | 1 / 1 | – / – |  | 3672.0 |  |  |
| 12 | ProposalsController#edit | 1 / 1 | – / – |  | 3217.0 |  |  |
| 13 | ProposalsController#show | 1 / 1 | – / – |  | 3005.0 |  |  |
| 14 | ProposalsController#destroy | 1 / 1 | – / – |  | 1108.0 |  |  |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `RUBY/pathname.rb:51` | `chop_basename` | 56.47 / 56.47 | 0.0 | 63.53 | 27% | String |  | `app/views/layouts/core.html.erb:17` 50%, `app/views/layouts/application.html.erb:3` 50% | `base = File.basename(path)` |
| 2 | `RAILS/actionpack/lib/action_controller/metal/rescue.rb:39` | `process_action` | 47.24 / 47.24 | 0.0 | 56.71 | 18% | String, Array |  | `no app frame` 100% | `rescue_with_handler(exception) \|\| raise` |
| 3 | `RUBY/pathname.rb:55` | `chop_basename` | 44.24 / 44.24 | 0.0 | 49.76 | 27% | String, Array |  | `app/views/layouts/core.html.erb:17` 50%, `app/views/layouts/application.html.erb:3` 50% | `return path[0, path.rindex(base)], base` |
| 4 | `GEM/json/lib/json/common.rb:355` | `parse` | 36.24 / 36.24 | 0.0 | 40.76 | 100% | String, Hash |  | `app/views/layouts/application.html.erb:3` 23%, `app/views/layouts/core.html.erb:17` 23% | `Parser.parse(source, opts)` |
| 5 | `GEM/uri/lib/uri/common.rb:465` | `_decode_uri_component` | 26.76 / 26.76 | 0.0 | 26.97 | 100% | String, MatchData |  | `no app frame` 74%, `app/controllers/concerns/authenticated.rb:30` 26% | `str.b.gsub(regexp, TBLDECWWWCOMP_).force_encoding(enc)` |
| 6 | `GEM/hashie/lib/hashie/mash.rb:374` | `convert_key` | 26.21 / 26.21 | 0.0 | 27.0 | 100% | String |  | `no app frame` 100% | `key.respond_to?(:to_sym) ? key.to_s : key` |
| 7 | `RUBY/pathname.rb:358` | `+` | 24.47 / 24.47 | 0.0 | 27.53 | 27% | String, Object |  | `app/views/layouts/application.html.erb:3` 50%, `app/views/layouts/core.html.erb:17` 50% | `Pathname.new(plus(@path, other.to_s))` |
| 8 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` | `each` | 24.0 / 24.0 | 0.0 | 25.24 | 100% | String, Array |  | `app/controllers/concerns/authenticated.rb:31` 32%, `app/controllers/proposals_controller.rb:64` 11% | `val = step` |
| 9 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:273` | `define_attribute_methods` | 20.18 / 20.18 | 0.0 | 22.41 | 85% | Array |  | `app/controllers/proposals_controller.rb:12` 15%, `app/controllers/evaluations/results_controller.rb:8` 12% | `ActiveSupport::CodeGenerator.batch(generated_attribute_methods, __FILE` |
| 10 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | `merge` | 17.65 / 17.65 | 0.0 | 19.18 | 100% | Array, Object |  | `app/forms/proposal_form.rb:110` 13%, `app/controllers/reviews_controller.rb:34` 9% | `WhereClause.new(predicates \| other.predicates)` |
| 11 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` | `create` | 16.88 / 16.88 | 0.0 | 18.38 | 100% | Object, Array |  | `app/controllers/proposals_controller.rb:64` 11%, `app/forms/proposal_form.rb:110` 11% | `relation_class_for(model).new(model, ...)` |
| 12 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` | `call` | 15.88 / 15.88 | 0.0 | 16.21 | 100% | Data |  | `no app frame` 77%, `app/forms/application_form.rb:60` 11% | `result_lambda = -> { user_callback.call target, value }` |
| 13 | `RAILS/activemodel/lib/active_model/attribute.rb:9` | `from_database` | 14.44 / 14.44 | 0.0 | 14.59 | 85% | Object |  | `app/forms/proposal_form.rb:55` 25%, `app/forms/proposal_form.rb:56` 16% | `FromDatabase.new(name, value_before_type_cast, type, nil, value)` |
| 14 | `GEM/tzinfo/lib/tzinfo/timestamp.rb:208` | `for_time` | 13.35 / 13.35 | 0.0 | 14.0 | 74% | Rational |  | `app/models/cfp.rb:17` 34%, `app/models/cfp.rb:15` 24% | `sub_second = time.subsec` |
| 15 | `RAILS/actionview/lib/action_view/template/resolver.rb:127` | `built_templates` | 13.24 / 13.24 | 0.0 | 15.71 | 18% | Array, Hash |  | `no app frame` 100% | `@unbound_templates.values.flatten.flat_map(&:built_templates)` |
| 16 | `RUBY/pathname.rb:396` | `plus` | 12.24 / 12.24 | 0.0 | 13.76 | 27% | String, Struct |  | `app/views/layouts/core.html.erb:17` 50%, `app/views/layouts/application.html.erb:3` 50% | `suffix2 = path2[index_list2.first..-1]` |
| 17 | `RUBY/pathname.rb:397` | `plus` | 12.24 / 12.24 | 0.0 | 13.76 | 27% | Array, String |  | `app/views/layouts/application.html.erb:3` 50%, `app/views/layouts/core.html.erb:17` 50% | `r1 ? File.join(prefix1, suffix2) : prefix1 + suffix2` |
| 18 | `GEM/hashie/lib/hashie/mash.rb:369` | `method_suffix` | 11.65 / 11.65 | 0.0 | 12.0 | 100% | String |  | `no app frame` 100% | `method_name = method_name.to_s` |
| 19 | `GEM/hashie/lib/hashie/mash.rb:410` | `log_collision?` | 11.65 / 11.65 | 0.0 | 12.0 | 100% | Array |  | `no app frame` 100% | `return unless respond_to?(method_key)` |
| 20 | `RAILS/activemodel/lib/active_model/type/string.rb:39` | `cast_value` | 10.62 / 10.62 | 0.0 | 11.09 | 82% | String |  | `app/forms/proposal_form.rb:56` 17%, `app/controllers/proposals_controller.rb:12` 14% | `when ::String then ::String.new(value)` |
| 21 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:312` | `define_attribute_method` | 10.53 / 10.53 | 0.0 | 10.79 | 44% | Array |  | `app/forms/application_form.rb:60` 29%, `app/forms/application_form.rb:77` 25% | `ActiveSupport::CodeGenerator.batch(_owner, __FILE__, __LINE__) do \|own` |
| 22 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` | `get_metadata` | 10.35 / 10.35 | 0.0 | 12.0 | 50% | Data, String |  | `app/controllers/proposals_controller.rb:12` 15%, `app/controllers/evaluations/results_controller.rb:8` 12% | `val&.downcase` |
| 23 | `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/collection/map/non_concurrent_map_backend.rb:131` | `dupped_backend` | 10.29 / 10.29 | 0.0 | 10.32 | 100% | Hash |  | `no app frame` 93%, `app/forms/proposal_form.rb:55` 2% | `@backend.dup` |
| 24 | `GEM/sqlite3/lib/sqlite3/statement.rb:54` | `bind_params` | 10.15 / 10.15 | 0.0 | 10.59 | 100% | Array, Hash |  | `app/controllers/concerns/authenticated.rb:31` 28%, `app/forms/proposal_form.rb:110` 8% | `bind_vars.flatten.each do \|var\|` |
| 25 | `RAILS/actionpack/lib/action_dispatch/http/request.rb:66` | `initialize` | 9.88 / 9.88 | 0.0 | 10.18 | 100% | Object |  | `no app frame` 100% | `@rack_request = Rack::Request.new(env)` |
| 26 | `RAILS/activerecord/lib/arel/table.rb:85` | `[]` | 9.32 / 9.32 | 0.0 | 9.94 | 100% | Struct |  | `app/forms/proposal_form.rb:55` 22%, `app/forms/proposal_form.rb:56` 14% | `Attribute.new(table, name)` |
| 27 | `RAILS/activerecord/lib/active_record/connection_adapters/sqlite3/database_statements.rb:123` | `perform_query` | 9.18 / 9.18 | 0.0 | 9.62 | 100% | Object, Hash | #59605 merged 2026-11-04, after this app's version, not released yet | `app/controllers/concerns/authenticated.rb:31` 31%, `app/forms/proposal_form.rb:110` 9% | `ActiveRecord::Result.new(stmt.columns, rows, stmt.types.map { \|t\| type` |
| 28 | `RUBY/pathname.rb:419` | `join` | 8.94 / 8.94 | 0.0 | 10.06 | 27% | String, Object |  | `app/views/layouts/application.html.erb:3` 50%, `app/views/layouts/core.html.erb:17` 50% | `result = Pathname.new(result) unless Pathname === result` |
| 29 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` | `extract_attributes` | 8.82 / 8.82 | 0.0 | 9.59 | 100% | Array |  | `app/forms/proposal_form.rb:110` 13%, `app/controllers/reviews_controller.rb:34` 9% | `attrs = []` |
| 30 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:287` | `build_handle` | 8.62 / 8.62 | 0.0 | 9.03 | 100% | Array | #59235 merged 2026-10-21, after this app's version, not released yet | `app/controllers/concerns/authenticated.rb:31` 22%, `no app frame` 11% | `groups = groups_for(name).map do \|group_klass, grouped_listeners\|` |

## Dev/test-mode work

128.5 of 1803.0 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | error page | `RAILS/actionpack/lib/action_dispatch/middleware/exception_wrapper.rb:269` | 22.47 | 18% | `no app frame` 100% | `(@exception.backtrace_locations \|\| []).map do \|loc\|` |
| 2 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/manifest.rb:156` | 11.29 | 27% | `app/views/layouts/application.html.erb:3` 50%, `app/views/layouts/core.html.erb:17` 50% | `File.join(vite_asset_origin \|\| "/", config.public_output_dir, path)` |
| 3 | asset lookup | `GEM/vite_ruby/lib/vite_ruby.rb:88` † | 6.12 | 27% | `app/views/layouts/application.html.erb:3` 46%, `app/views/layouts/core.html.erb:17` 46% | `return @running if defined?(@running) && Time.now - @running_checked_a` |
| 4 | debug logging | `RAILS/actionpack/lib/abstract_controller/logger.rb:12` | 5.18 | 100% | `no app frame` 78%, `app/controllers/proposals_controller.rb:25` 4% | `singleton_class.delegate :logger, :logger=, to: :config` |
| 5 | debug logging | `RAILS/actionview/lib/action_view/structured_event_subscriber.rb:61` | 4.47 | 27% | `app/views/layouts/application.html.erb:11` 32%, `app/controllers/proposals_controller.rb:12` 15% | `string = string.sub("#{rails_root}/", "")` |
| 6 | route build | `RAILS/actionpack/lib/action_dispatch/journey/gtg/transition_table.rb:52` | 4.0 | 100% | `no app frame` 100% | `next_states = []` |
| 7 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/manifest.rb:167` | 3.76 | 27% | `app/views/layouts/application.html.erb:3` 50%, `app/views/layouts/core.html.erb:17` 50% | `config.origin if dev_server_running? && config.skip_proxy` |
| 8 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/manifest.rb:149` | 3.29 | 27% | `app/views/layouts/application.html.erb:3` 50%, `app/views/layouts/core.html.erb:17` 50% | `.map { \|path\| JSON.parse(path.read) }` |
| 9 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/build.rb:24` | 2.82 | 27% | `app/views/layouts/application.html.erb:3` 50%, `app/views/layouts/core.html.erb:17` 50% | `JSON.parse(pathname.read.to_s).transform_keys(&:to_sym).slice(*members` |
| 10 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/config.rb:33` | 2.82 | 27% | `app/views/layouts/core.html.erb:17` 50%, `app/views/layouts/application.html.erb:3` 50% | `known_manifest_paths.select(&:exist?)` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activerecord | 422.9 | 474.6 | `where_clause.rb:29` 17.6, `delegation.rb:139` 16.9, `table.rb:85` 9.3 |
| rails: actionpack | 245.9 | 273.0 | `rescue.rb:39` 47.2, `exception_wrapper.rb:269` 22.5, `request.rb:66` 9.9 |
| rails: activesupport | 219.8 | 244.8 | `callbacks.rb:179` 15.9, `fanout.rb:287` 8.6, `hash_with_indifferent_access.rb:75` 8.3 |
| ruby stdlib | 202.0 | 257.0 | `pathname.rb:51` 56.5, `pathname.rb:55` 44.2, `pathname.rb:358` 24.5 |
| rails: activemodel | 113.5 | 122.2 | `attribute_methods.rb:273` 20.2, `attribute.rb:9` 14.4, `string.rb:39` 10.6 |
| rails: actionview | 99.4 | 142.4 | `resolver.rb:127` 13.2, `structured_event_subscriber.rb:61` 4.5, `tag_helper.rb:309` 3.8 |
| gem: vite_ruby | 62.9 | 83.8 | `manifest.rb:156` 11.3, `vite_ruby.rb:88` 6.1, `manifest.rb:167` 3.8 |
| gem: sqlite3 | 61.4 | 66.0 | `statement.rb:125` 24.0, `statement.rb:186` 10.4, `statement.rb:54` 10.1 |
| gem: rack | 59.5 | 77.7 | `query_parser.rb:245` 5.3, `request.rb:693` 4.7, `query_parser.rb:229` 4.5 |
| gem: hashie | 57.3 | 59.0 | `mash.rb:374` 26.2, `mash.rb:410` 11.6, `mash.rb:369` 11.6 |
| ruby default gem: uri | 49.6 | 53.0 | `common.rb:465` 26.8, `common.rb:456` 7.8, `common.rb:108` 2.1 |
| gem: inertia_rails | 38.6 | 42.6 | `renderer.rb:106` 4.2, `configuration.rb:112` 2.8, `props_resolver.rb:81` 2.7 |
| gem: json | 37.3 | 41.9 | `common.rb:355` 36.2, `common.rb:1080` 1.1 |
| gem: concurrent-ruby | 34.4 | 36.2 | `non_concurrent_map_backend.rb:131` 10.3, `map.rb:245` 7.5, `safe_initialization.rb:30` 5.8 |
| gem: tzinfo | 27.6 | 28.9 | `timestamp.rb:208` 13.4, `constant_offset_data_timezone_info.rb:52` 6.7, `timestamp.rb:193` 6.7 |
| app | 19.6 | 25.1 | `authenticated.rb:31` 1.9, `application_controller.rb:30` 1.8, `core.html.erb:17` 0.9 |
| gem: omniauth | 15.5 | 16.0 | `strategy.rb:139` 6.8, `strategy.rb:470` 1.9, `strategy.rb:169` 1.9 |
| gem: frozen_record | 13.2 | 14.1 | `scope.rb:262` 4.2, `scope.rb:187` 3.6, `scope.rb:299` 1.2 |
| gem: vite_rails | 9.4 | 10.6 | `tag_helpers.rb:106` 1.9, `tag_helpers.rb:52` 0.9, `tag_helpers.rb:47` 0.9 |
| gem: propshaft | 7.1 | 7.8 | `helper.rb:128` 1.9, `server.rb:16` 1.6, `server.rb:60` 1.0 |
| rails: railties | 3.7 | 3.9 | `logger.rb:37` 1.0, `logger.rb:21` 1.0, `engine.rb:748` 1.0 |
| gem: alba | 3.5 | 4.5 | `resource.rb:113` 1.7, `resource.rb:167` 1.1, `association.rb:128` 0.5 |
| gem: base64 | 2.6 | 2.8 | `base64.rb:310` 1.9, `base64.rb:283` 0.7 |
| gem: store_model | 2.5 | 3.2 | `parent_assignment.rb:12` 2.4, `base.rb:28` 0.1 |
| gem: rack-session | 2.4 | 2.5 | `id.rb:275` 0.8, `id.rb:277` 0.8, `id.rb:368` 0.6 |
| rails: activestorage | 2.1 | 2.4 | `set_current.rb:12` 1.0, `model.rb:144` 0.4, `model.rb:282` 0.3 |
| gem: bootsnap | 1.8 | 8.1 | `iseq.rb:98` 0.5, `iseq.rb:14` 0.4, `iseq.rb:201` 0.2 |
| gem: after_commit_everywhere | 1.5 | 1.6 | `after_commit_everywhere.rb:126` 1.2, `after_commit_everywhere.rb:51` 0.3 |
| gem: turbo-rails | 1.4 | 1.5 | `request_id_tracking.rb:10` 1.0, `frame_request.rb:36` 0.5 |
| ruby default gem: securerandom | 1.3 | 1.4 | `securerandom.rb:71` 1.3 |
| gem: nanoid | 1.0 | 1.3 | `nanoid.rb:22` 0.7, `nanoid.rb:21` 0.2, `nanoid.rb:59` 0.1 |
| gem: require-hooks | 0.8 | 3.3 | `bootsnap.rb:69` 0.2, `api.rb:147` 0.2, `api.rb:56` 0.2 |
| gem: debug | 0.7 | 3.6 | `thread_client.rb:903` 0.2, `thread_client.rb:223` 0.1, `thread_client.rb:224` 0.1 |
| gem: active_delivery | 0.3 | 1.3 | `base.rb:242` 0.2, `base.rb:15` 0.1, `testing.rb:22` 0.1 |
| gem: freezolite | 0.1 | 0.5 | `freezolite.rb:27` 0.1 |
| ruby default gem: bundler | 0.0 | 0.1 | `rubygems_integration.rb:192` 0.0 |
| rails: actionmailer | 0.0 | 0.3 | `message_delivery.rb:136` 0.0, `parameterized.rb:149` 0.0, `parameterized.rb:113` 0.0 |
| lowrail-profile | 0.0 | 0.0 | `profile.rb:65` 0.0 |
| gem: msgpack | 0.0 | 0.9 | `factory.rb:37` 0.0, `bigint.rb:0` 0.0, `bigint.rb:10` 0.0 |
| gem: globalid | 0.0 | 1.1 | `gid.rb:159` 0.0, `gid.rb:166` 0.0, `gid.rb:167` 0.0 |
| rails: activejob | 0.0 | 0.9 | `configured_job.rb:15` 0.0, `queue_name.rb:49` 0.0, `arguments.rb:35` 0.0 |
| gem: erubi | 0.0 | 4.6 | `erubi.rb:199` 0.0, `erubi.rb:134` 0.0, `erubi.rb:137` 0.0 |
| gem: i18n | 0.0 | 10.8 | `tag.rb:7` 0.0, `fallbacks.rb:18` 0.0, `i18n.rb:476` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Mails

| # | Mailer action | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | ProposalMailer.deliver_mail | 5 / 5 | 1406.0 / 1406.0 | 0.0 | 1483.0 | `GEM/mail/lib/mail/utilities.rb:248` 211.0, `GEM/mail/lib/mail/encodings/8bit.rb:14` 182.0, `GEM/mail/lib/mail/utilities.rb:215` 78.0 |  |
| 2 | ProposalMailer#proposal_submitted | 2 / 2 | 659.0 / 659.0 | 0.0 | 812.5 | `GEM/mail/lib/mail/parsers/address_lists_parser.rb:32009` 66.0, `GEM/mail/lib/mail/utilities.rb:215` 37.0, `GEM/mail/lib/mail/parser_tools.rb:7` 32.0 | `app/mailers/proposal_mailer.rb:7` 532.0, `app/views/mailers/proposal_mailer/proposal_submitted.html.erb:15` 40.0, `app/views/mailers/proposal_mailer/proposal_submitted.html.erb:16` 7.0 |
| 3 | ProposalMailer#proposal_accepted | 1 / 1 | – / – |  | 1716.0 |  |  |
| 4 | ProposalMailer#proposal_waitlisted | 1 / 1 | – / – |  | 979.0 |  |  |
| 5 | ProposalMailer#proposal_rejected | 1 / 1 | – / – |  | 974.0 |  |  |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/mail/lib/mail/utilities.rb:248` | 84.4 / 84.4 | 50% | `no app frame` 100% | `string.gsub(TO_CRLF_REGEX, Constants::CRLF)` |
| 2 | `GEM/mail/lib/mail/utilities.rb:215` | 53.8 / 53.8 | 100% | `no app frame` 68%, `app/mailers/proposal_mailer.rb:7` 13% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 3 | `GEM/mail/lib/mail/utilities.rb:291` | 36.8 / 36.8 | 100% | `no app frame` 64%, `app/mailers/proposal_mailer.rb:7` 14% | `value !~ /\S/` |
| 4 | `GEM/mail/lib/mail/encodings/8bit.rb:14` | 36.4 / 36.4 | 20% | `no app frame` 100% | `!str.lines.find { \|line\| line.bytesize > 998 }` |
| 5 | `GEM/mail/lib/mail/parsers/address_lists_parser.rb:32009` | 26.3 / 26.3 | 50% | `app/mailers/proposal_mailer.rb:7` 40%, `app/mailers/proposal_mailer.rb:31` 20% | `_wide = data[p].ord` |
| 6 | `GEM/mail/lib/mail/field_list.rb:71` | 24.5 / 24.5 | 100% | `no app frame` 71%, `app/mailers/proposal_mailer.rb:7` 12% | `fields = select { \|f\| f.responsible_for? field_name }` |
| 7 | `GEM/mail/lib/mail/utilities.rb:388` | 22.0 / 22.0 | 50% | `no app frame` 100% | `charset_encoder.encode(str.dup, from_encoding).encode(to_encoding, :un` |
| 8 | `GEM/mail/lib/mail/parser_tools.rb:7` | 18.9 / 18.9 | 100% | `app/mailers/proposal_mailer.rb:7` 29%, `no app frame` 28% | `data.slice(from_bytes..to_bytes).force_encoding(Encoding::UTF_8)` |
| 9 | `GEM/mail/lib/mail/parsers/message_ids_parser.rb:4870` | 18.0 / 18.0 | 50% | `no app frame` 100% | `_wide = data[p].ord` |
| 10 | `RAILS/actionview/lib/action_view/template.rb:508` (template compile) | 16.8 / 16.8 | 40% | `app/mailers/proposal_mailer.rb:15` 51%, `app/mailers/proposal_mailer.rb:31` 18% | `mod.module_eval(compiled_source, identifier, offset)` |
