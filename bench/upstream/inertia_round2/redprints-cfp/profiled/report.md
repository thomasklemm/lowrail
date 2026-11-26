# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bundle exec rspec --format documentation --seed 1234`
* Ruby: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux]
* Rails: 8.1.3, test environment
* Counted in run 1: 34 requests, 10 mail windows; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 34 | 2491.1 | 0 | 10 | 0 | 0 |
| run2 | 1 | 34 | 2491.1 | 0 | 10 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.35 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/controllers/evaluations_controller.rb:10` | `index` | 37.18 | 1.53 | 0.24 | `GEM/json/lib/json/common.rb:355` 7%, `RAILS/activemodel/lib/active_model/attribute_methods.rb:273` 4%, `GEM/sqlite3/lib/sqlite3/statement.rb:186` 3% | EvaluationsController#index 100% | `render inertia: {evaluations: serialize(evaluations)}` |
| 2 | `app/controllers/concerns/authenticated.rb:30` | `current_user` | 33.56 | 0.0 | 0.0 | `GEM/json/lib/json/common.rb:355` 12%, `GEM/uri/lib/uri/common.rb:465` 9%, `GEM/rack/lib/rack/utils.rb:331` 7% | ReviewsController#update 25%, ProposalsController#update 15%, ProposalsController#create 15% | `if (auth_token = cookies.signed[:session_token])` |
| 3 | `app/forms/proposal_form.rb:55` | `submit!` | 33.53 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 8%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:146` 5%, `RAILS/activerecord/lib/arel/table.rb:85` 5% | ProposalsController#create 59%, ProposalsController#update 41% | `proposal.save!` |
| 4 | `app/controllers/concerns/authenticated.rb:31` | `current_user` | 31.18 | 0.0 | 1.18 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` 15%, `GEM/sqlite3/lib/sqlite3/statement.rb:54` 6%, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/database_statements.rb:49` 4% | ReviewsController#update 25%, ProposalsController#create 15%, ProposalsController#update 15% | `User.find_by(auth_token:)` |
| 5 | `app/controllers/reviews_controller.rb:30` | `set_review` | 27.06 | 0.0 | 0.15 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 4%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 3%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 3% | ReviewsController#update 100% | `@review = current_user.reviews.find(params[:id])` |
| 6 | `app/forms/proposal_form.rb:56` | `submit!` | 26.38 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 6%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:146` 5%, `RAILS/activemodel/lib/active_model/type/string.rb:39` 5% | ProposalsController#create 59%, ProposalsController#update 41% | `speaker_profile.save!` |
| 7 | `app/controllers/proposals/confirmations_controller.rb:18` | `set_proposal` | 25.65 | 0.0 | 0.24 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 4%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:29` 3%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` 3% | Proposals::ConfirmationsController#destroy 50%, Proposals::ConfirmationsController#create 50% | `@proposal = current_user.proposals.accepted.find_by!(external_id: para` |
| 8 | `app/controllers/proposals_controller.rb:12` | `index` | 23.65 | 0.76 | 0.12 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:273` 7%, `GEM/json/lib/json/common.rb:355` 7%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 5% | ProposalsController#index 100% | `render inertia: {proposals: serialize(current_user.proposals.active)}` |
| 9 | `app/forms/proposal_form.rb:110` | `attributes_from_context` | 20.91 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 7%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 5%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 3% | ProposalsController#update 56%, ProposalsController#create 44%, ProposalsController#new 0% | `profile = user&.speaker_profile` |
| 10 | `app/controllers/reviews_controller.rb:34` | `check_deadline` | 19.59 | 0.0 | 0.0 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 3% | ReviewsController#update 100% | `return unless @review.evaluation.deadline&.past?` |
| 11 | `app/forms/application_form.rb:69` | `initialize_from_params` | 16.68 | 0.06 | 0.59 | `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:1329` 16%, `RAILS/activemodel/lib/active_model/attribute.rb:101` 14%, `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:405` 9% | ReviewsController#update 31%, ProposalsController#create 29%, ProposalsController#update 28% | `initialize(params.permit(permitted_attributes))` |
| 12 | `app/controllers/proposals_controller.rb:64` | `set_proposal` | 16.59 | 0.0 | 0.18 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` 7%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 4%, `RAILS/activerecord/lib/active_record/relation.rb:77` 3% | ProposalsController#update 100%, ProposalsController#edit 0%, ProposalsController#destroy 0% | `@proposal = current_user.proposals.find_by!(external_id: params[:id])` |
| 13 | `app/forms/proposal_form.rb:70` | `assign_attributes` | 13.88 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:101` 7%, `RAILS/activerecord/lib/active_record/associations/association.rb:221` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5% | ProposalsController#create 100%, ProposalsController#new 0% | `@proposal = user.proposals.new(build_proposal_attributes)` |
| 14 | `app/forms/review_form.rb:15` | `submit!` | 12.18 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 9%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 7%, `GEM/tzinfo/lib/tzinfo/timestamp.rb:208` 4% | ReviewsController#update 100% | `review.save!` |
| 15 | `app/forms/application_form.rb:90` | `with_transaction` | 11.85 | 0.0 | 0.24 | `RAILS/activerecord/lib/active_record/attribute_methods/primary_key.rb:19` 16%, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:348` 8%, `RAILS/actionview/lib/action_view/lookup_context.rb:47` 8% | ProposalsController#create 40%, ProposalsController#update 26%, ReviewsController#update 22% | `def with_transaction(&) = ApplicationRecord.transaction(&)` |
| 16 | `app/views/layouts/application.html.erb:3` |  | 11.47 | 51.44 | 0.26 | `GEM/json/lib/json/common.rb:355` 27%, `RUBY/ipaddr.rb:725` 8%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 5% | EvaluationsController#index 67%, ProposalsController#index 33%, ProposalsController#show 0% | `<%= vite_typescript_tag "inertia" %>` |
| 17 | `app/views/layouts/core.html.erb:17` |  | 9.97 | 51.09 | 0.35 | `GEM/json/lib/json/common.rb:355` 31%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 6%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 6% | EvaluationsController#index 67%, ProposalsController#index 33%, Evaluations::ResultsController#index 0% | `<%= vite_javascript_tag 'application', media: 'all' %>` |
| 18 | `app/controllers/proposals_controller.rb:52` | `update` | 8.56 | 0.06 | 0.09 | `GEM/i18n/lib/i18n.rb:476` 9%, `GEM/i18n/lib/i18n/backend/base.rb:157` 8%, `GEM/i18n/lib/i18n.rb:396` 5% | ProposalsController#update 100% | `redirect_to edit_proposal_path(@proposal), inertia: {errors: form.erro` |
| 19 | `app/forms/application_form.rb:77` | `assign_attributes` | 8.53 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:13` 20%, `RAILS/activemodel/lib/active_model/attribute_assignment.rb:68` 20%, `RAILS/activemodel/lib/active_model/attribute_methods.rb:312` 20% | ProposalsController#update 46%, ProposalsController#create 25%, ReviewsController#update 23% | `super(attrs.reverse_merge(attributes_from_context))` |
| 20 | `app/controllers/evaluations_controller.rb:5` | `index` | 8.41 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 8%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 4%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 4% | EvaluationsController#index 100% | `evaluations = current_user.evaluations.active` |
| 21 | `app/controllers/reviews_controller.rb:7` | `index` | 8.26 | 0.0 | 0.03 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 4%, `RAILS/activerecord/lib/active_record/relation/query_methods.rb:1821` 4%, `RAILS/activerecord/lib/active_record/relation.rb:77` 2% | ReviewsController#index 100% | `evaluation = current_user.evaluations.find(params[:evaluation_id])` |
| 22 | `app/forms/proposal_form.rb:73` | `assign_attributes` | 6.97 | 0.0 | 0.09 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 10%, `RAILS/activemodel/lib/active_model/attribute.rb:101` 10%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 5% | ProposalsController#create 100%, ProposalsController#new 0%, ProposalsController#edit 0% | `@speaker_profile = user.speaker_profile \|\| user.build_speaker_profile` |
| 23 | `app/controllers/reviews_controller.rb:36` | `check_deadline` | 6.47 | 0.12 | 0.12 | `RAILS/activesupport/lib/active_support/key_generator.rb:63` 5%, `GEM/uri/lib/uri/common.rb:108` 4%, `GEM/uri/lib/uri/rfc3986_parser.rb:85` 4% | ReviewsController#update 100% | `redirect_to review_path(@review), alert: "The evaluation deadline has ` |
| 24 | `app/forms/evaluation/submit_form.rb:57` | `notify_speakers` | 5.91 | 0.0 | 0.21 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 5%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 3% | Evaluations::ResultsController#create 100% | `ProposalDelivery.with(proposal:, speaker: proposal.speaker_profile).pu` |
| 25 | `app/forms/application_form.rb:60` | `save` | 5.82 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:312` 38%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 23%, `RAILS/activemodel/lib/active_model/validations/length.rb:49` 15% | ProposalsController#update 49%, ProposalsController#create 38%, ReviewsController#update 8% | `return false unless valid?` |
| 26 | `app/forms/evaluation/submit_form.rb:26` | `submit!` | 5.5 | 0.0 | 0.03 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 16%, `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 10%, `GEM/tzinfo/lib/tzinfo/timestamp.rb:208` 4% | Evaluations::ResultsController#create 100% | `proposal.update!(status: it[:status])` |
| 27 | `app/controllers/evaluations_controller.rb:7` | `index` | 5.47 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/relation/query_methods.rb:1821` 5%, `RAILS/activerecord/lib/active_record/relation/query_methods.rb:1794` 3%, `RAILS/activerecord/lib/arel/collectors/sql_string.rb:22` 3% | EvaluationsController#index 100% | `if evaluations.size == 1` |
| 28 | `app/controllers/proposals_controller.rb:25` | `create` | 5.29 | 0.18 | 0.09 | `GEM/uri/lib/uri/rfc3986_parser.rb:85` 7%, `GEM/uri/lib/uri/common.rb:108` 7%, `RAILS/actionpack/lib/action_dispatch/http/url.rb:325` 5% | ProposalsController#create 100% | `redirect_to proposals_path` |
| 29 | `app/forms/evaluation/submit_form.rb:18` | `submit!` | 5.21 | 0.0 | 0.09 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 17%, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 8%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 7% | Evaluations::ResultsController#create 100% | `locked_proposals = Proposal.lock.where(external_id: proposals.map { it` |
| 30 | `app/forms/proposal_form.rb:74` | `assign_attributes` | 4.76 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/attribute_assignment.rb:10` 22%, `RAILS/activemodel/lib/active_model/attribute.rb:13` 22%, `RAILS/activemodel/lib/active_model/attribute_assignment.rb:68` 22% | ProposalsController#update 56%, ProposalsController#create 44%, ProposalsController#new 0% | `@speaker_profile.assign_attributes(build_speaker_attributes)` |

306.56 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | ProposalsController#index | 2 / 2 | 3040.0 / 3040.0 | 0.0 | 3040.0 | `GEM/json/lib/json/common.rb:355` 132.0, `RAILS/activemodel/lib/active_model/attribute_methods.rb:273` 63.0, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 45.0 | `app/controllers/proposals_controller.rb:12` 804.0, `app/views/layouts/application.html.erb:3` 130.0, `app/views/layouts/core.html.erb:17` 113.0 |
| 2 | EvaluationsController#index | 3 / 3 | 2991.5 / 2990.0 | -1.5 | 2324.3 | `GEM/json/lib/json/common.rb:355` 124.0, `RAILS/activemodel/lib/active_model/attribute_methods.rb:273` 39.0, `GEM/hashie/lib/hashie/mash.rb:374` 27.0 | `app/controllers/evaluations_controller.rb:10` 632.0, `app/controllers/evaluations_controller.rb:5` 143.0, `app/views/layouts/application.html.erb:3` 130.0 |
| 3 | ProposalsController#create | 4 / 4 | 1648.0 / 1648.0 | 0.0 | 1742.0 | `GEM/uri/lib/uri/common.rb:465` 48.0, `RAILS/activemodel/lib/active_model/attribute.rb:101` 31.0, `RAILS/activemodel/lib/active_model/attribute_methods.rb:312` 29.0 | `app/forms/proposal_form.rb:55` 224.0, `app/forms/proposal_form.rb:56` 177.7, `app/forms/proposal_form.rb:70` 157.3 |
| 4 | ProposalsController#update | 4 / 4 | 1598.3 / 1598.3 | 0.0 | 1628.3 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:312` 41.0, `RAILS/activemodel/lib/active_model/attribute.rb:9` 38.3, `RAILS/activemodel/lib/active_model/type/string.rb:39` 35.7 | `app/controllers/proposals_controller.rb:64` 188.0, `app/forms/proposal_form.rb:55` 156.0, `app/forms/proposal_form.rb:110` 132.0 |
| 5 | Evaluations::ResultsController#create | 2 / 2 | 1587.0 / 1590.0 | 3.0 | 1552.5 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` 39.0, `RAILS/activemodel/lib/active_model/attribute.rb:9` 31.0, `GEM/sqlite3/lib/sqlite3/statement.rb:186` 30.0 | `app/forms/evaluation/submit_form.rb:57` 201.0, `app/forms/evaluation/submit_form.rb:26` 187.0, `app/forms/evaluation/submit_form.rb:18` 177.0 |
| 6 | ReviewsController#index | 2 / 2 | 1467.0 / 1467.0 | 0.0 | 4655.0 | `RAILS/actionpack/lib/action_controller/metal/rescue.rb:39` 328.0, `RAILS/actionview/lib/action_view/template/resolver.rb:127` 84.0, `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/collection/map/non_concurrent_map_backend.rb:131` 35.0 | `app/controllers/reviews_controller.rb:7` 281.0, `app/controllers/concerns/authenticated.rb:30` 57.0, `app/controllers/concerns/authenticated.rb:31` 53.0 |
| 7 | Proposals::ConfirmationsController#create | 3 / 3 | 1436.0 / 1441.0 | 5.0 | 1354.0 | `RAILS/actionpack/lib/action_controller/metal/rescue.rb:39` 330.0, `RAILS/actionview/lib/action_view/template/resolver.rb:127` 90.0, `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/collection/map/non_concurrent_map_backend.rb:131` 53.0 | `app/controllers/proposals/confirmations_controller.rb:18` 218.0, `app/controllers/concerns/authenticated.rb:30` 57.5, `app/controllers/concerns/authenticated.rb:31` 53.0 |
| 8 | Proposals::ConfirmationsController#destroy | 3 / 3 | 1432.0 / 1432.0 | 0.0 | 1328.0 | `RAILS/actionpack/lib/action_controller/metal/rescue.rb:39` 330.0, `RAILS/actionview/lib/action_view/template/resolver.rb:127` 90.0, `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/collection/map/non_concurrent_map_backend.rb:131` 53.0 | `app/controllers/proposals/confirmations_controller.rb:18` 218.0, `app/controllers/concerns/authenticated.rb:30` 57.0, `app/controllers/concerns/authenticated.rb:31` 53.0 |
| 9 | ReviewsController#update | 6 / 6 | 1205.0 / 1203.8 | -1.2 | 1397.0 | `GEM/hashie/lib/hashie/mash.rb:374` 27.0, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 24.0, `GEM/uri/lib/uri/common.rb:465` 19.2 | `app/controllers/reviews_controller.rb:30` 184.0, `app/controllers/reviews_controller.rb:34` 133.2, `app/forms/review_form.rb:15` 82.8 |
| 10 | Evaluations::ResultsController#index | 1 / 1 | – / – |  | 4806.0 |  |  |
| 11 | ProposalsController#new | 1 / 1 | – / – |  | 3642.0 |  |  |
| 12 | ProposalsController#edit | 1 / 1 | – / – |  | 3181.0 |  |  |
| 13 | ProposalsController#show | 1 / 1 | – / – |  | 2991.0 |  |  |
| 14 | ProposalsController#destroy | 1 / 1 | – / – |  | 1078.0 |  |  |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `RAILS/actionpack/lib/action_controller/metal/rescue.rb:39` | `process_action` | 48.12 / 48.12 | 0.0 | 57.76 | 18% | String, Array |  | `no app frame` 100% | `rescue_with_handler(exception) \|\| raise` |
| 2 | `GEM/json/lib/json/common.rb:355` | `parse` | 36.15 / 35.79 | -0.35 | 40.41 | 100% | String, Hash |  | `app/views/layouts/application.html.erb:3` 23%, `app/views/layouts/core.html.erb:17` 23% | `Parser.parse(source, opts)` |
| 3 | `GEM/hashie/lib/hashie/mash.rb:374` | `convert_key` | 26.21 / 26.21 | 0.0 | 27.0 | 100% | String |  | `no app frame` 100% | `key.respond_to?(:to_sym) ? key.to_s : key` |
| 4 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` | `each` | 24.0 / 24.0 | 0.0 | 25.24 | 100% | String, Array |  | `app/controllers/concerns/authenticated.rb:31` 32%, `app/controllers/proposals_controller.rb:64` 11% | `val = step` |
| 5 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:273` | `define_attribute_methods` | 20.18 / 20.18 | 0.0 | 22.41 | 85% | Array |  | `app/controllers/proposals_controller.rb:12` 15%, `app/controllers/evaluations/results_controller.rb:8` 12% | `ActiveSupport::CodeGenerator.batch(generated_attribute_methods, __FILE` |
| 6 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | `merge` | 17.65 / 17.65 | 0.0 | 19.18 | 100% | Object, Array |  | `app/forms/proposal_form.rb:110` 13%, `app/controllers/proposals_controller.rb:64` 9% | `WhereClause.new(predicates \| other.predicates)` |
| 7 | `GEM/uri/lib/uri/common.rb:465` | `_decode_uri_component` | 17.59 / 17.59 | 0.0 | 17.74 | 100% | String, MatchData |  | `no app frame` 72%, `app/controllers/concerns/authenticated.rb:30` 28% | `str.b.gsub(regexp, TBLDECWWWCOMP_).force_encoding(enc)` |
| 8 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` | `call` | 15.88 / 15.88 | 0.0 | 16.21 | 100% | Data |  | `no app frame` 77%, `app/forms/application_form.rb:60` 11% | `result_lambda = -> { user_callback.call target, value }` |
| 9 | `RAILS/activemodel/lib/active_model/attribute.rb:9` | `from_database` | 14.44 / 14.44 | 0.0 | 14.59 | 85% | Object |  | `app/forms/proposal_form.rb:55` 25%, `app/forms/proposal_form.rb:56` 16% | `FromDatabase.new(name, value_before_type_cast, type, nil, value)` |
| 10 | `GEM/tzinfo/lib/tzinfo/timestamp.rb:208` | `for_time` | 13.35 / 13.35 | 0.0 | 14.0 | 74% | Rational |  | `app/models/cfp.rb:17` 34%, `app/models/cfp.rb:15` 24% | `sub_second = time.subsec` |
| 11 | `RAILS/actionview/lib/action_view/template/resolver.rb:127` | `built_templates` | 13.24 / 13.24 | 0.0 | 15.71 | 18% | Array, Hash |  | `no app frame` 100% | `@unbound_templates.values.flatten.flat_map(&:built_templates)` |
| 12 | `GEM/hashie/lib/hashie/mash.rb:369` | `method_suffix` | 11.65 / 11.65 | 0.0 | 12.0 | 100% | String |  | `no app frame` 100% | `method_name = method_name.to_s` |
| 13 | `GEM/hashie/lib/hashie/mash.rb:410` | `log_collision?` | 11.65 / 11.65 | 0.0 | 12.0 | 100% | Array |  | `no app frame` 100% | `return unless respond_to?(method_key)` |
| 14 | `RAILS/activemodel/lib/active_model/type/string.rb:39` | `cast_value` | 10.62 / 10.62 | 0.0 | 11.09 | 82% | String |  | `app/forms/proposal_form.rb:56` 17%, `app/controllers/proposals_controller.rb:12` 14% | `when ::String then ::String.new(value)` |
| 15 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:312` | `define_attribute_method` | 10.53 / 10.53 | 0.0 | 10.79 | 44% | Array |  | `app/forms/application_form.rb:60` 29%, `app/forms/application_form.rb:77` 25% | `ActiveSupport::CodeGenerator.batch(_owner, __FILE__, __LINE__) do \|own` |
| 16 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` | `get_metadata` | 10.35 / 10.35 | 0.0 | 12.0 | 50% | Data, String |  | `app/controllers/proposals_controller.rb:12` 15%, `app/controllers/evaluations/results_controller.rb:8` 12% | `val&.downcase` |
| 17 | `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/collection/map/non_concurrent_map_backend.rb:131` | `dupped_backend` | 10.29 / 10.29 | 0.0 | 10.32 | 100% | Hash |  | `no app frame` 93%, `app/forms/proposal_form.rb:56` 2% | `@backend.dup` |
| 18 | `GEM/sqlite3/lib/sqlite3/statement.rb:54` | `bind_params` | 10.15 / 10.15 | 0.0 | 10.59 | 100% | Array, Hash |  | `app/controllers/concerns/authenticated.rb:31` 28%, `app/forms/proposal_form.rb:110` 8% | `bind_vars.flatten.each do \|var\|` |
| 19 | `RAILS/actionpack/lib/action_dispatch/http/request.rb:66` | `initialize` | 9.88 / 9.88 | 0.0 | 10.18 | 100% | Object |  | `no app frame` 100% | `@rack_request = Rack::Request.new(env)` |
| 20 | `RAILS/activerecord/lib/arel/table.rb:85` | `[]` | 9.32 / 9.32 | 0.0 | 9.94 | 100% | Struct |  | `app/forms/proposal_form.rb:55` 22%, `app/forms/proposal_form.rb:56` 14% | `Attribute.new(table, name)` |
| 21 | `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:75` | `initialize` | 9.03 / 9.03 | 0.0 | 9.65 | 100% | Array |  | `app/forms/application_form.rb:77` 15%, `app/forms/application_form.rb:69` 12% | `update(constructor)` |
| 22 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` | `extract_attributes` | 8.82 / 8.82 | 0.0 | 9.59 | 100% | Array |  | `app/forms/proposal_form.rb:110` 13%, `app/controllers/reviews_controller.rb:34` 9% | `attrs = []` |
| 23 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:287` | `build_handle` | 8.62 / 8.62 | 0.0 | 9.03 | 100% | Array | #59235 merged 2026-10-21, after this app's version, not released yet | `app/controllers/concerns/authenticated.rb:31` 22%, `no app frame` 11% | `groups = groups_for(name).map do \|group_klass, grouped_listeners\|` |
| 24 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` | `create` | 8.56 / 8.56 | 0.0 | 9.5 | 100% | Object, Data |  | `app/controllers/proposals_controller.rb:64` 11%, `app/forms/proposal_form.rb:110` 10% | `relation_class_for(model).new(model, ...)` |
| 25 | `RAILS/activerecord/lib/active_record/relation.rb:77` | `initialize` | 8.41 / 8.41 | 0.0 | 9.15 | 100% | Hash |  | `app/controllers/proposals_controller.rb:64` 11%, `app/forms/proposal_form.rb:110` 11% | `def initialize(model, table: nil, predicate_builder: nil, values: {})` |
| 26 | `RAILS/activemodel/lib/active_model/attribute.rb:13` | `from_user` | 8.41 / 8.41 | 0.0 | 8.62 | 50% | Object |  | `app/forms/application_form.rb:77` 31%, `app/forms/proposal_form.rb:74` 20% | `FromUser.new(name, value_before_type_cast, type, original_attribute)` |
| 27 | `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` | `file_readable?` | 7.94 / 7.94 | 0.0 | 8.74 | 32% | String, Array |  | `no app frame` 100% | `file_path = File.join(@root, path.b)` |
| 28 | `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/map.rb:245` | `values` | 7.5 / 7.5 | 0.0 | 8.47 | 18% | Array |  | `no app frame` 100% | `arr = []` |
| 29 | `RUBY/random/formatter.rb:174` † | `uuid` | 7.0 / 7.0 | 0.0 | 7.21 | 100% | String, Array |  | `no app frame` 97%, `app/forms/proposal_form.rb:81` 3% | `ary.unpack("H8H4H4H4H12").join(?-)` |
| 30 | `RAILS/activemodel/lib/active_model/attribute_assignment.rb:68` | `_assign_attribute` | 6.85 / 6.85 | 0.0 | 7.0 | 50% | String |  | `app/forms/application_form.rb:77` 39%, `app/forms/proposal_form.rb:74` 25% | `setter = :"#{k}="` |

## Dev/test-mode work

330.5 of 1761.8 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/config.rb:38` † | 131.76 | 27% | `app/views/layouts/application.html.erb:3` 50%, `app/views/layouts/core.html.erb:17` 50% | `root.join(public_dir, public_output_dir)` |
| 2 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/config.rb:27` † | 34.82 | 27% | `app/views/layouts/application.html.erb:3` 50%, `app/views/layouts/core.html.erb:17` 50% | `build_output_dir.join(".vite/manifest-assets.json"),` |
| 3 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/config.rb:24` † | 34.82 | 27% | `app/views/layouts/core.html.erb:17` 50%, `app/views/layouts/application.html.erb:3` 50% | `build_output_dir.join(".vite/manifest.json"),` |
| 4 | error page | `RAILS/actionpack/lib/action_dispatch/middleware/exception_wrapper.rb:269` | 22.91 | 18% | `no app frame` 100% | `(@exception.backtrace_locations \|\| []).map do \|loc\|` |
| 5 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/builder.rb:49` † | 16.47 | 27% | `app/views/layouts/core.html.erb:17` 50%, `app/views/layouts/application.html.erb:3` 50% | `config.build_cache_dir.join("last#{"-ssr" if ssr}-build-#{config.mode}` |
| 6 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/manifest.rb:156` | 7.53 | 27% | `app/views/layouts/application.html.erb:3` 50%, `app/views/layouts/core.html.erb:17` 50% | `File.join(vite_asset_origin \|\| "/", config.public_output_dir, path)` |
| 7 | asset lookup | `GEM/vite_ruby/lib/vite_ruby.rb:88` † | 6.12 | 27% | `app/views/layouts/application.html.erb:3` 46%, `app/views/layouts/core.html.erb:17` 46% | `return @running if defined?(@running) && Time.now - @running_checked_a` |
| 8 | debug logging | `RAILS/actionpack/lib/abstract_controller/logger.rb:12` | 5.18 | 100% | `no app frame` 78%, `app/controllers/proposals_controller.rb:25` 4% | `singleton_class.delegate :logger, :logger=, to: :config` |
| 9 | debug logging | `RAILS/actionview/lib/action_view/structured_event_subscriber.rb:61` † | 4.47 | 27% | `app/views/layouts/application.html.erb:11` 32%, `app/controllers/evaluations_controller.rb:10` 15% | `string = string.sub("#{rails_root}/", "")` |
| 10 | route build | `RAILS/actionpack/lib/action_dispatch/journey/gtg/transition_table.rb:52` | 4.0 | 100% | `no app frame` 100% | `next_states = []` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activerecord | 396.7 | 446.7 | `where_clause.rb:29` 17.6, `table.rb:85` 9.3, `where_clause.rb:111` 8.8 |
| gem: vite_ruby | 262.0 | 307.6 | `config.rb:38` 131.8, `config.rb:27` 34.8, `config.rb:24` 34.8 |
| rails: actionpack | 243.7 | 271.4 | `rescue.rb:39` 48.1, `exception_wrapper.rb:269` 22.9, `request.rb:66` 9.9 |
| rails: activesupport | 217.6 | 242.7 | `callbacks.rb:179` 15.9, `hash_with_indifferent_access.rb:75` 9.0, `fanout.rb:287` 8.6 |
| rails: activemodel | 107.4 | 115.8 | `attribute_methods.rb:273` 20.2, `attribute.rb:9` 14.4, `string.rb:39` 10.6 |
| rails: actionview | 97.9 | 141.1 | `resolver.rb:127` 13.2, `structured_event_subscriber.rb:61` 4.5, `tag_helper.rb:309` 3.8 |
| gem: sqlite3 | 61.4 | 66.0 | `statement.rb:125` 24.0, `statement.rb:186` 10.4, `statement.rb:54` 10.1 |
| gem: rack | 58.5 | 76.8 | `query_parser.rb:245` 5.3, `request.rb:693` 4.7, `utils.rb:331` 3.9 |
| gem: hashie | 57.3 | 59.0 | `mash.rb:374` 26.2, `mash.rb:369` 11.6, `mash.rb:410` 11.6 |
| gem: json | 37.0 | 41.5 | `common.rb:355` 36.0, `common.rb:1080` 1.1 |
| ruby default gem: uri | 35.8 | 38.1 | `common.rb:465` 17.6, `common.rb:456` 3.1, `common.rb:108` 2.1 |
| gem: concurrent-ruby | 34.4 | 36.2 | `non_concurrent_map_backend.rb:131` 10.3, `map.rb:245` 7.5, `safe_initialization.rb:30` 5.8 |
| gem: inertia_rails | 30.1 | 34.0 | `renderer.rb:138` 4.2, `dotted_keys.rb:15` 1.6, `middleware.rb:10` 1.0 |
| gem: tzinfo | 27.6 | 28.9 | `timestamp.rb:208` 13.4, `timestamp.rb:193` 6.7, `constant_offset_data_timezone_info.rb:52` 6.7 |
| app | 18.8 | 24.4 | `authenticated.rb:31` 1.9, `application_controller.rb:30` 1.0, `core.html.erb:17` 0.9 |
| gem: omniauth | 18.4 | 19.0 | `strategy.rb:139` 6.8, `strategy.rb:470` 1.9, `strategy.rb:169` 1.9 |
| ruby stdlib | 18.3 | 46.1 | `formatter.rb:174` 7.0, `ipaddr.rb:725` 2.4, `monitor.rb:237` 1.9 |
| gem: frozen_record | 13.2 | 14.1 | `scope.rb:262` 4.2, `scope.rb:187` 3.6, `scope.rb:163` 1.2 |
| gem: propshaft | 10.0 | 10.9 | `helper.rb:128` 1.9, `server.rb:16` 1.6, `server.rb:13` 1.0 |
| gem: vite_rails | 9.4 | 10.6 | `tag_helpers.rb:106` 1.9, `tag_helpers.rb:47` 0.9, `tag_helpers.rb:48` 0.9 |
| rails: railties | 3.7 | 3.9 | `logger.rb:37` 1.0, `logger.rb:21` 1.0, `engine.rb:748` 1.0 |
| gem: alba | 3.2 | 4.1 | `resource.rb:113` 1.7, `resource.rb:167` 1.1, `association.rb:64` 0.2 |
| gem: base64 | 2.6 | 2.8 | `base64.rb:310` 1.9, `base64.rb:283` 0.7 |
| gem: store_model | 2.5 | 3.2 | `parent_assignment.rb:12` 2.4, `base.rb:28` 0.1 |
| gem: rack-session | 2.4 | 2.5 | `id.rb:275` 0.8, `id.rb:277` 0.8, `id.rb:368` 0.6 |
| rails: activestorage | 2.1 | 2.4 | `set_current.rb:12` 1.0, `model.rb:144` 0.4, `model.rb:282` 0.3 |
| gem: bootsnap | 1.8 | 8.1 | `iseq.rb:98` 0.5, `iseq.rb:14` 0.4, `iseq.rb:201` 0.2 |
| gem: turbo-rails | 1.4 | 1.5 | `request_id_tracking.rb:10` 1.0, `frame_request.rb:36` 0.5 |
| ruby default gem: securerandom | 1.3 | 1.4 | `securerandom.rb:71` 1.3 |
| gem: after_commit_everywhere | 1.2 | 1.3 | `after_commit_everywhere.rb:126` 0.9, `after_commit_everywhere.rb:51` 0.3 |
| gem: nanoid | 1.0 | 1.3 | `nanoid.rb:22` 0.7, `nanoid.rb:21` 0.2, `nanoid.rb:59` 0.1 |
| gem: require-hooks | 0.8 | 3.3 | `api.rb:56` 0.2, `bootsnap.rb:69` 0.2, `api.rb:147` 0.2 |
| gem: debug | 0.7 | 3.6 | `thread_client.rb:903` 0.2, `thread_client.rb:234` 0.1, `thread_client.rb:223` 0.1 |
| gem: active_delivery | 0.2 | 1.0 | `base.rb:15` 0.1, `base.rb:242` 0.1, `testing.rb:22` 0.1 |
| gem: freezolite | 0.1 | 0.5 | `freezolite.rb:27` 0.1 |
| rails: actionmailer | 0.0 | 0.2 | `parameterized.rb:113` 0.0, `parameterized.rb:132` 0.0, `parameterized.rb:119` 0.0 |
| gem: i18n | 0.0 | 11.0 | `fallbacks.rb:58` 0.0, `base.rb:45` 0.0, `base.rb:155` 0.0 |
| gem: erubi | 0.0 | 4.6 | `erubi.rb:199` 0.0, `erubi.rb:134` 0.0, `erubi.rb:110` 0.0 |
| gem: msgpack | 0.0 | 0.9 | `bigint.rb:0` 0.0, `bigint.rb:4` 0.0, `factory.rb:27` 0.0 |
| lowrail-profile | 0.0 | 0.1 | `profile.rb:66` 0.0, `profile.rb:56` 0.0 |
| ruby default gem: bundler | 0.0 | 0.1 | `rubygems_integration.rb:192` 0.0 |
| gem: globalid | 0.0 | 1.1 | `gid.rb:159` 0.0, `gid.rb:108` 0.0, `gid.rb:166` 0.0 |
| rails: activejob | 0.0 | 0.8 | `test_adapter.rb:49` 0.0, `configured_job.rb:15` 0.0, `arguments.rb:35` 0.0 |
| gem: meta-tags | 0.0 | 0.0 | `controller_helper.rb:24` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Mails

| # | Mailer action | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | ProposalMailer.deliver_mail | 5 / 5 | 1175.8 / 1175.5 | -0.3 | 1237.0 | `GEM/mail/lib/mail/encodings/8bit.rb:14` 182.0, `GEM/mail/lib/mail/utilities.rb:215` 78.0, `GEM/mail/lib/mail/utilities.rb:388` 55.0 |  |
| 2 | ProposalMailer#proposal_submitted | 2 / 2 | 652.0 / 652.0 | 0.0 | 802.5 | `GEM/mail/lib/mail/parsers/address_lists_parser.rb:32009` 66.0, `GEM/mail/lib/mail/utilities.rb:215` 37.0, `GEM/mail/lib/mail/parser_tools.rb:7` 32.0 | `app/mailers/proposal_mailer.rb:7` 531.0, `app/views/mailers/proposal_mailer/proposal_submitted.html.erb:15` 39.0, `app/views/mailers/proposal_mailer/proposal_submitted.html.erb:1` 6.0 |
| 3 | ProposalMailer#proposal_accepted | 1 / 1 | – / – |  | 1722.0 |  |  |
| 4 | ProposalMailer#proposal_waitlisted | 1 / 1 | – / – |  | 969.0 |  |  |
| 5 | ProposalMailer#proposal_rejected | 1 / 1 | – / – |  | 964.0 |  |  |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/mail/lib/mail/utilities.rb:215` | 53.8 / 53.8 | 100% | `no app frame` 68%, `app/mailers/proposal_mailer.rb:7` 13% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 2 | `GEM/mail/lib/mail/utilities.rb:291` | 36.8 / 36.8 | 100% | `no app frame` 64%, `app/mailers/proposal_mailer.rb:7` 14% | `value !~ /\S/` |
| 3 | `GEM/mail/lib/mail/encodings/8bit.rb:14` | 36.4 / 36.4 | 20% | `no app frame` 100% | `!str.lines.find { \|line\| line.bytesize > 998 }` |
| 4 | `GEM/mail/lib/mail/parsers/address_lists_parser.rb:32009` | 26.3 / 26.3 | 50% | `app/mailers/proposal_mailer.rb:7` 40%, `app/mailers/proposal_mailer.rb:23` 20% | `_wide = data[p].ord` |
| 5 | `GEM/mail/lib/mail/field_list.rb:71` | 24.5 / 24.5 | 100% | `no app frame` 71%, `app/mailers/proposal_mailer.rb:7` 12% | `fields = select { \|f\| f.responsible_for? field_name }` |
| 6 | `GEM/mail/lib/mail/utilities.rb:388` | 22.0 / 22.0 | 50% | `no app frame` 100% | `charset_encoder.encode(str.dup, from_encoding).encode(to_encoding, :un` |
| 7 | `GEM/mail/lib/mail/parser_tools.rb:7` | 18.9 / 18.9 | 100% | `app/mailers/proposal_mailer.rb:7` 29%, `no app frame` 28% | `data.slice(from_bytes..to_bytes).force_encoding(Encoding::UTF_8)` |
| 8 | `GEM/mail/lib/mail/parsers/message_ids_parser.rb:4870` | 18.0 / 18.0 | 50% | `no app frame` 100% | `_wide = data[p].ord` |
| 9 | `RAILS/actionview/lib/action_view/template.rb:508` (template compile) | 16.7 / 16.7 | 40% | `app/mailers/proposal_mailer.rb:15` 51%, `app/mailers/proposal_mailer.rb:31` 18% | `mod.module_eval(compiled_source, identifier, offset)` |
| 10 | `GEM/mail/lib/mail/elements/address.rb:110` | 14.4 / 14.4 | 50% | `no app frame` 100% | `Encodings.decode_encode("#{@data.obs_domain_list}#{get_local.strip}", ` |
