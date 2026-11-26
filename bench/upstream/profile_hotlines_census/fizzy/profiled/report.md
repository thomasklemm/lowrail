# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails test test/controllers -v`
* Ruby: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +YJIT +PRISM [x86_64-linux]
* Rails: 8.1.4, test environment
* Counted in run 1: 96 requests; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 96 | 11762.8 | 0 | 0 | 0 | 0 |
| run2 | 1 | 96 | 11763.0 | 0 | 0 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.13 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/controllers/concerns/authentication.rb:56` | `start_new_session_for` | 153.62 | 46.49 | 0.43 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:149` 3%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 2%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:144` 2% | SessionsController#create 100%, FirstRunsController#create 0%, Sessions::TransfersController#update 0% | `user.sessions.create!(user_agent: request.user_agent, ip_address: requ` |
| 2 | `app/controllers/sessions_controller.rb:11` | `create` | 76.54 | 20.1 | 0.88 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` 5%, `GEM/bcrypt/lib/bcrypt/password.rb:93` 3%, `RAILS/activerecord/lib/active_record/secure_password.rb:42` 3% | SessionsController#create 100% | `if user = User.active.authenticate_by(params.permit(:email_address, :p` |
| 3 | `app/helpers/avatars_helper.rb:20` | `avatar_image_tag` | 45.02 | 8.69 | 0.75 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 3%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 2% | BubblesController#show 33%, BubblesController#index 33%, BoostsController#create 22% | `image_tag user_avatar_path(user), aria: { hidden: "true" }, size: 48, ` |
| 4 | `app/helpers/events_helper.rb:41` | `render_event_grid_cells` | 42.0 | 0.0 | 9.33 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:539` 33%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 10%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 10% | EventsController#index 100% | `tag.div class: class_names("event__grid-item"), style: "grid-area: #{r` |
| 5 | `app/controllers/concerns/authentication.rb:63` | `set_current_session` | 41.72 | 0.0 | 0.55 | `RAILS/activesupport/lib/active_support/core_ext/hash/keys.rb:35` 8%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:149` 8%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:144` 5% | SessionsController#create 78%, BubblesController#show 4%, EventsController#index 3% | `cookies.signed.permanent[:session_token] = { value: session.signed_id,` |
| 6 | `app/models/event_summary.rb:44` | `boosts_summary` | 39.22 | 9.38 | 0.13 | `RAILS/activerecord/lib/active_record/relation/calculations.rb:38` 3%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 3%, `RAILS/activerecord/lib/arel.rb:56` 3% | BoostsController#create 51%, BubblesController#show 49%, CommentsController#create 0% | `if tally = events.boosts.group(:creator).count.presence` |
| 7 | `app/models/filter/resources.rb:21` | `buckets` | 37.91 | 5.13 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 11%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 6%, `RAILS/activerecord/lib/active_record/relation.rb:1311` 4% | BubblesController#index 100%, FiltersController#destroy 0%, FiltersController#create 0% | `creator.buckets.where id: super.ids` |
| 8 | `app/views/layouts/application.html.erb:15` |  | 37.06 | 30.55 | 0.22 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 17%, `RAILS/actionview/lib/action_view/helpers/asset_url_helper.rb:246` 11%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 6% | SessionsController#new 29%, EventsController#index 29%, BubblesController#index 14% | `<%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>` |
| 9 | `app/models/bubble/eventable.rb:11` | `track_event` | 35.68 | 7.53 | 0.03 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:149` 6%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:144` 4%, `GEM/tzinfo/lib/tzinfo/timestamp.rb:208` 4% | Assignments::TogglesController#create 81%, BoostsController#create 19%, Bubbles::PublishesController#create 0% | `event = find_or_capture_event_summary.events.create! action: action, c` |
| 10 | `app/controllers/sessions_controller.rb:26` | `require_first_run_completion` | 35.27 | 15.56 | 0.0 | `RAILS/activerecord/lib/active_record/relation/finder_methods.rb:445` 5%, `GEM/sqlite3/lib/sqlite3/statement.rb:54` 4%, `RAILS/activerecord/lib/active_record/connection_adapters/sqlite3/database_statements.rb:123` 3% | SessionsController#create 95%, SessionsController#new 5%, SessionsController#destroy 0% | `redirect_to first_run_path if Account.none?` |
| 11 | `app/controllers/concerns/current_timezone.rb:15` | `timezone_from_cookie` | 35.05 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:298` 11%, `GEM/tzinfo/lib/tzinfo/transition_rule.rb:373` 11%, `GEM/tzinfo/lib/tzinfo/timestamp.rb:193` 11% | EventsController#index 100% | `timezone if timezone.present? && ActiveSupport::TimeZone[timezone]` |
| 12 | `app/controllers/concerns/authentication.rb:37` | `find_session_by_cookie` | 34.99 | 4.73 | 0.0 | `RAILS/actionpack/lib/action_dispatch/middleware/cookies.rb:628` 5%, `GEM/json/lib/json/common.rb:221` 4%, `RAILS/activerecord/lib/active_record/signed_id.rb:71` 3% | SessionsController#create 29%, EventsController#index 12%, BubblesController#show 11% | `Session.find_signed(cookies.signed[:session_token])` |
| 13 | `app/models/event/particulars.rb:9` | `assignees` | 31.4 | 4.0 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 7%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 3%, `RAILS/activerecord/lib/active_record/relation.rb:77` 3% | BubblesController#show 40%, BoostsController#create 40%, EventsController#index 21% | `@assignees \|\|= account.users.where id: assignee_ids` |
| 14 | `app/controllers/concerns/authentication.rb:47` | `after_authentication_url` | 27.33 | 0.0 | 0.43 | `RAILS/activesupport/lib/active_support/key_generator.rb:63` 8%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:55` 6%, `GEM/rack/lib/rack/request.rb:693` 6% | SessionsController#create 100% | `session.delete(:return_to_after_authenticating) \|\| root_url` |
| 15 | `app/views/layouts/application.html.erb:16` |  | 27.12 | 7.51 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 24%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 24%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 13% | SessionsController#new 29%, EventsController#index 29%, BucketsController#index 14% | `<%= javascript_importmap_tags %>` |
| 16 | `app/controllers/concerns/current_timezone.rb:10` | `set_current_timezone` | 25.09 | 9.4 | 0.0 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` 11%, `RAILS/actionpack/lib/action_controller/metal/rate_limiting.rb:75` 5%, `RAILS/actionview/lib/action_view/template_path.rb:23` 4% | SessionsController#create 28%, SessionsController#new 27%, EventsController#index 13% | `Time.use_zone(timezone_from_cookie, &)` |
| 17 | `app/models/event_summary.rb:15` | `main_summary` | 21.08 | 4.81 | 0.38 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `RAILS/activerecord/lib/arel.rb:56` 4%, `RAILS/activerecord/lib/active_record/relation/query_methods.rb:2185` 3% | BubblesController#show 50%, BoostsController#create 50%, CommentsController#create 0% | `events.non_boosts.map { \|event\| summarize(event) }.join(" ")` |
| 18 | `app/controllers/sessions_controller.rb:13` | `create` | 20.07 | 5.98 | 0.43 | `GEM/uri/lib/uri/rfc3986_parser.rb:85` 9%, `GEM/uri/lib/uri/rfc3986_parser.rb:102` 4%, `GEM/uri/lib/uri/generic.rb:335` 4% | SessionsController#create 100% | `redirect_to after_authentication_url` |
| 19 | `app/controllers/concerns/bucket_scoped.rb:10` | `set_bucket` | 19.49 | 3.06 | 0.07 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 4%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 2%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 2% | BubblesController#show 30%, Buckets::SubscriptionsController#update 14%, CommentsController#update 14% | `@bucket = Current.user.buckets.find(params[:bucket_id])` |
| 20 | `app/views/messages/_message.html.erb:1` |  | 18.02 | 5.83 | 0.1 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 2%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 2% | BubblesController#show 50%, BoostsController#create 50%, CommentsController#create 0% | `<%= render message.messageable %>` |
| 21 | `app/models/bucket/accessible.rb:18` | `revoke_from` | 16.87 | 0.83 | 0.02 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` 31%, `RAILS/activemodel/lib/active_model/attribute_methods.rb:333` 7%, `RAILS/activesupport/lib/active_support/code_generator.rb:35` 7% | BucketsController#update 100% | `destroy_by user: users unless proxy_association.owner.all_access?` |
| 22 | `app/models/current.rb:4` |  | 16.79 | 4.73 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 3% | EventsController#index 17%, BubblesController#show 17%, BubblesController#index 8% | `delegate :user, to: :session, allow_nil: true` |
| 23 | `app/views/comments/_body.html.erb:6` |  | 16.44 | 3.36 | 0.25 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 3%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` 3% | BoostsController#create 50%, BubblesController#show 50%, CommentsController#update 0% | `<%= link_to bucket_bubble_path(comment.bubble.bucket, comment.bubble, ` |
| 24 | `app/views/bubbles/_tags.html.erb:1` |  | 13.53 | 2.51 | 0.07 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 3%, `RAILS/activerecord/lib/active_record/reflection.rb:746` 3% | BubblesController#index 91%, BubblesController#show 9% | `<% bubble.tags.each do \|tag\| %>` |
| 25 | `lib/rails_ext/action_text_has_markdown.rb:9` | `#{name}` | 12.17 | 1.92 | 0.02 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 3%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 3% | BubblesController#show 50%, BoostsController#create 50%, Notifications::TraysController#show 0% | `markdown_#{name} \|\| build_markdown_#{name}` |
| 26 | `app/models/bubble/poppable.rb:24` | `update_auto_pop_at` | 11.68 | 2.1 | 0.03 | `RAILS/activesupport/lib/active_support/callbacks.rb:362` 6%, `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 5%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:149` 5% | Assignments::TogglesController#create 62%, BoostsController#create 38%, BubblesController#update 0% | `update!(auto_pop_at: last_activity + AUTO_POP_AFTER)` |
| 27 | `app/models/user/role.rb:8` |  | 11.42 | 0.0 | 1.69 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` 10%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:29` 10%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 10% | SessionsController#create 77%, EventsController#index 12%, BubblesController#index 6% | `scope :without_system, -> { where.not(role: :system) }` |
| 28 | `app/models/bubble/eventable.rb:18` | `find_or_capture_event_summary` | 11.32 | 2.68 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 3%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 3% | Assignments::TogglesController#create 64%, BoostsController#create 36%, Bubbles::PublishesController#create 0% | `messages.last&.event_summary \|\| capture(EventSummary.new).event_summar` |
| 29 | `app/models/user/role.rb:9` |  | 10.17 | 0.0 | 1.0 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` 10%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:29` 10%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:166` 10% | SessionsController#create 86%, BubblesController#index 7%, BucketsController#update 2% | `scope :active, -> { without_system.where(active: true) }` |
| 30 | `app/views/bubbles/_comments.html.erb:1` |  | 9.28 | 1.75 | 0.08 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 4%, `RAILS/activerecord/lib/active_record/relation.rb:77` 3% | BubblesController#index 75%, BubblesController#show 25% | `<% if bubble.messages.comments.any? %>` |

274.59 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | BubblesController#show | 3 / 3 | 197304.5 / 197305.5 | 1.0 | 140930.3 | `RAILS/actionview/lib/action_view/buffers.rb:44` 701.5, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 478.5, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 337.5 | `app/models/event_summary.rb:44` 922.5, `app/helpers/avatars_helper.rb:20` 719.5, `app/models/event/particulars.rb:9` 598.5 |
| 2 | BubblesController#index | 2 / 2 | 30127.0 / 30124.0 | -3.0 | 31891.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 1000.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 817.0, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 500.0 | `app/models/filter/resources.rb:21` 3639.0, `app/helpers/avatars_helper.rb:20` 1430.0, `app/views/bubbles/_tags.html.erb:1` 1186.0 |
| 3 | BoostsController#create | 2 / 2 | 21941.0 / 21937.0 | -4.0 | 32834.5 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 576.0, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 288.0, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 279.0 | `app/models/event_summary.rb:44` 1920.0, `app/models/event/particulars.rb:9` 1197.0, `app/models/event_summary.rb:15` 1012.0 |
| 4 | EventsController#index | 3 / 3 | 12497.0 / 12500.0 | 3.0 | 12706.7 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:539` 672.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 415.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 309.5 | `app/helpers/events_helper.rb:41` 2016.0, `app/controllers/concerns/current_timezone.rb:15` 1682.5, `app/views/layouts/application.html.erb:15` 508.0 |
| 5 | Assignments::TogglesController#create | 2 / 2 | 11879.0 / 11874.0 | -5.0 | 15382.5 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:149` 270.0, `GEM/tzinfo/lib/tzinfo/timestamp.rb:208` 184.0, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:144` 180.0 | `app/models/bubble/eventable.rb:11` 2775.0, `app/models/bubble/assignable.rb:23` 803.0, `app/models/bubble/assignable.rb:32` 775.0 |
| 6 | BucketsController#update | 2 / 2 | 5306.0 / 5305.0 | -1.0 | 4585.0 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` 504.0, `RAILS/activesupport/lib/active_support/code_generator.rb:35` 119.0, `RAILS/activemodel/lib/active_model/attribute_methods.rb:333` 119.0 | `app/models/bucket/accessible.rb:18` 1620.0, `app/controllers/buckets_controller.rb:24` 557.0, `app/models/bucket/accessible.rb:14` 310.0 |
| 7 | Taggings::TogglesController#create | 2 / 2 | 4817.0 / 4818.0 | 1.0 | 6207.5 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 80.0, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:149` 78.0, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 60.0 | `app/models/bubble/taggable.rb:27` 822.0, `app/models/bubble/taggable.rb:21` 790.0, `app/controllers/concerns/bucket_scoped.rb:10` 263.0 |
| 8 | BucketsController#index | 2 / 2 | 3707.0 / 3708.0 | 1.0 | 4876.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 222.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 112.0, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 110.0 | `app/views/layouts/application.html.erb:15` 508.0, `app/views/layouts/application.html.erb:16` 372.0, `app/controllers/concerns/authentication.rb:37` 193.0 |
| 9 | SessionsController#new | 3 / 3 | 3431.5 / 3432.0 | 0.5 | 2572.3 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 256.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 141.0, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 137.0 | `app/views/layouts/application.html.erb:15` 509.0, `app/views/layouts/application.html.erb:16` 372.0, `app/controllers/concerns/current_timezone.rb:10` 323.0 |
| 10 | CommentsController#update | 2 / 2 | 1979.0 / 1986.0 | 7.0 | 5353.5 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` 39.0, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 36.0, `GEM/uri/lib/uri/common.rb:422` 35.0 | `app/controllers/concerns/bucket_scoped.rb:10` 263.0, `app/controllers/comments_controller.rb:37` 200.0, `app/controllers/concerns/bubble_scoped.rb:10` 199.0 |
| 11 | Buckets::SubscriptionsController#update | 2 / 2 | 1808.0 / 1817.0 | 9.0 | 2164.5 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 28.0, `RAILS/activesupport/lib/active_support/inflector/methods.rb:78` 24.0, `GEM/uri/lib/uri/common.rb:422` 24.0 | `app/models/concerns/subscribable.rb:16` 368.0, `app/controllers/concerns/bucket_scoped.rb:10` 263.0, `app/controllers/concerns/authentication.rb:37` 193.0 |
| 12 | SessionsController#create | 43 / 43 | 1512.9 / 1513.8 | 0.9 | 2117.5 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 19.9, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:149` 17.6, `GEM/uri/lib/uri/common.rb:415` 17.5 | `app/controllers/concerns/authentication.rb:56` 351.1, `app/controllers/sessions_controller.rb:11` 175.0, `app/controllers/sessions_controller.rb:26` 77.0 |
| 13 | FirstRunsController#show | 2 / 2 | 650.0 / 650.0 | 0.0 | 2236.5 | `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0, `RAILS/activesupport/lib/active_support/inflector/methods.rb:78` 24.0, `RAILS/activesupport/lib/active_support/inflector/methods.rb:80` 20.0 | `app/controllers/first_runs_controller.rb:17` 137.0, `app/controllers/concerns/authentication.rb:37` 23.0, `app/controllers/concerns/current_timezone.rb:10` 19.0 |
| 14 | Notifications::MarkAllReadsController#create | 1 / 1 | – / – |  | 74696.0 |  |  |
| 15 | BucketsController#destroy | 1 / 1 | – / – |  | 34271.0 |  |  |
| 16 | CommentsController#create | 1 / 1 | – / – |  | 30812.0 |  |  |
| 17 | BubblesController#update | 1 / 1 | – / – |  | 17481.0 |  |  |
| 18 | FiltersController#create | 1 / 1 | – / – |  | 11546.0 |  |  |
| 19 | Notifications::TraysController#show | 1 / 1 | – / – |  | 8326.0 |  |  |
| 20 | BucketsController#edit | 1 / 1 | – / – |  | 7551.0 |  |  |
| 21 | Bubbles::PopsController#create | 1 / 1 | – / – |  | 6949.0 |  |  |
| 22 | ReadingsController#create | 1 / 1 | – / – |  | 6711.0 |  |  |
| 23 | Comments::ReactionsController#create | 1 / 1 | – / – |  | 6264.0 |  |  |
| 24 | Bubbles::PublishesController#create | 1 / 1 | – / – |  | 5711.0 |  |  |
| 25 | Sessions::TransfersController#show | 1 / 1 | – / – |  | 4653.0 |  |  |
| 26 | Comments::ReactionsController#destroy | 1 / 1 | – / – |  | 4375.0 |  |  |
| 27 | FiltersController#destroy | 1 / 1 | – / – |  | 4196.0 |  |  |
| 28 | BubblesController#edit | 1 / 1 | – / – |  | 4032.0 |  |  |
| 29 | UploadsController#create | 1 / 1 | – / – |  | 3938.0 |  |  |
| 30 | BucketsController#new | 1 / 1 | – / – |  | 3728.0 |  |  |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` | `method_name` | 112.88 / 112.88 | 0.0 | 119.0 | 9% | String |  | `app/controllers/buckets_controller.rb:31` 15%, `app/controllers/bubbles_controller.rb:29` 13% | `@method_name % attr_name` |
| 2 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | `merge` | 96.25 / 96.25 | 0.0 | 96.33 | 92% | Array, Object |  | `app/models/filter/resources.rb:21` 9%, `app/helpers/avatars_helper.rb:20` 6% | `WhereClause.new(predicates \| other.predicates)` |
| 3 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` | `tag_option` | 78.77 / 78.77 | 0.0 | 80.68 | 28% | String |  | `app/views/layouts/application.html.erb:16` 23%, `app/views/layouts/application.html.erb:15` 22% | `%(#{key}="#{value}")` |
| 4 | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:101` † | `helper_names` | 57.59 / 57.59 | 0.0 | 60.63 | 21% | String, Array |  | `no app frame` 100% | `@path_helpers.map(&:to_s) + @url_helpers.map(&:to_s)` |
| 5 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` | `html_safe` | 49.75 / 49.75 | 0.0 | 50.72 | 28% | String |  | `app/views/layouts/application.html.erb:16` 20%, `no app frame` 13% | `ActiveSupport::SafeBuffer.new(self)` |
| 6 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | `#{method}` | 49.02 / 49.02 | 0.0 | 49.23 | 100% | Hash, Array |  | `no app frame` 19%, `app/controllers/concerns/authentication.rb:56` 6% | `dispatch(:#{method}, ...)` |
| 7 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` | `extract_attributes` | 48.13 / 48.13 | 0.0 | 48.17 | 92% | Array |  | `app/models/filter/resources.rb:21` 9%, `app/helpers/avatars_helper.rb:20` 6% | `attrs = []` |
| 8 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` | `each` | 47.63 / 47.63 | 0.0 | 47.75 | 98% | String, Array |  | `app/controllers/sessions_controller.rb:11` 8%, `app/models/current.rb:4` 7% | `val = step` |
| 9 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` | `create` | 43.61 / 43.61 | 0.0 | 43.86 | 98% | Object, Hash |  | `app/models/filter/resources.rb:21` 5%, `app/controllers/concerns/authentication.rb:56` 5% | `relation_class_for(model).new(model, ...)` |
| 10 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` | `initialize` | 41.42 / 41.42 | 0.0 | 42.33 | 28% | String |  | `app/views/layouts/application.html.erb:16` 24%, `app/views/layouts/application.html.erb:15` 15% | `super` |
| 11 | `RAILS/activerecord/lib/active_record/relation.rb:77` | `initialize` | 41.23 / 41.23 | 0.0 | 41.3 | 98% | Hash |  | `app/models/filter/resources.rb:21` 6%, `app/controllers/concerns/authentication.rb:56` 6% | `def initialize(model, table: nil, predicate_builder: nil, values: {})` |
| 12 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` | `xml_name_escape` | 39.55 / 39.55 | 0.0 | 40.54 | 28% | String |  | `app/views/layouts/application.html.erb:16` 46%, `app/helpers/events_helper.rb:41` 15% | `name = name.to_s` |
| 13 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` | `build_handle` | 39.27 / 39.27 | 0.0 | 39.42 | 100% | Object, Data | #59613 merged 2026-11-04, after this app's version, not released yet, #59235 merged 2026-10-21, after this app's version, not released yet | `no app frame` 8%, `app/controllers/concerns/authentication.rb:56` 7% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 14 | `RAILS/activerecord/lib/arel/table.rb:85` | `[]` | 38.63 / 38.63 | 0.0 | 38.73 | 94% | Struct |  | `app/controllers/concerns/authentication.rb:56` 7%, `app/helpers/avatars_helper.rb:20` 5% | `Attribute.new(table, name)` |
| 15 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` | `expand_from_hash` | 37.95 / 37.95 | 0.0 | 38.03 | 94% | Array |  | `app/helpers/avatars_helper.rb:20` 7%, `app/models/event/particulars.rb:9` 5% | `attributes.flat_map do \|key, value\|` |
| 16 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` | `+` | 37.56 / 37.56 | 0.0 | 37.65 | 94% | Array, Object |  | `app/helpers/avatars_helper.rb:20` 10%, `app/models/filter/resources.rb:21` 4% | `WhereClause.new(predicates + other.predicates)` |
| 17 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:149` | `change` | 37.06 / 37.19 | 0.13 | 37.31 | 93% | Rational, Data |  | `app/models/bubble/eventable.rb:11` 18%, `app/controllers/concerns/authentication.rb:56` 15% | `::Time.utc(new_year, new_month, new_day, new_hour, new_min, new_sec)` |
| 18 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:29` | `references` | 33.07 / 33.07 | 0.0 | 33.16 | 94% | Array |  | `app/helpers/avatars_helper.rb:20` 8%, `app/models/event/particulars.rb:9` 4% | `attributes.each_with_object([]) do \|(key, value), result\|` |
| 19 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:166` | `convert_dot_notation_to_hash` | 33.07 / 33.07 | 0.0 | 33.16 | 94% | Array, Hash |  | `app/helpers/avatars_helper.rb:20` 8%, `app/models/event/particulars.rb:9` 4% | `attributes.each_with_object({}) do \|(key, value), converted\|` |
| 20 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:235` | `compact_blank` | 33.02 / 33.02 | 0.0 | 33.14 | 98% | Hash, Array |  | `app/controllers/concerns/authentication.rb:56` 8%, `no app frame` 5% | `reject { \|_k, v\| v.blank? }` |
| 21 | `GEM/sqlite3/lib/sqlite3/statement.rb:54` | `bind_params` | 32.53 / 32.53 | 0.0 | 32.63 | 98% | Array, Hash |  | `no app frame` 7%, `app/controllers/sessions_controller.rb:26` 4% | `bind_vars.flatten.each do \|var\|` |
| 22 | `RAILS/activesupport/lib/active_support/code_generator.rb:30` | `apply` | 32.13 / 32.13 | 0.0 | 34.74 | 9% | Array, String |  | `app/controllers/bubbles_controller.rb:29` 17%, `app/models/filter.rb:13` 13% | `@cache.module_eval("# frozen_string_literal: true\n" + @sources.join("` |
| 23 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:287` | `build_handle` | 30.99 / 30.99 | 0.0 | 31.1 | 100% | Array | #59235 merged 2026-10-21, after this app's version, not released yet | `no app frame` 11%, `app/controllers/concerns/authentication.rb:56` 6% | `groups = groups_for(name).map do \|group_klass, grouped_listeners\|` |
| 24 | `RAILS/activerecord/lib/active_record/relation.rb:1311` | `values` | 29.32 / 29.32 | 0.0 | 29.35 | 98% | Hash |  | `app/models/filter/resources.rb:21` 10%, `app/helpers/avatars_helper.rb:20` 6% | `@values.dup` |
| 25 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:237` | `tag_options` | 28.99 / 28.99 | 0.0 | 29.8 | 28% | String |  | `app/views/layouts/application.html.erb:16` 31%, `app/views/layouts/application.html.erb:15` 20% | `output = +""` |
| 26 | `RAILS/activemodel/lib/active_model/attribute.rb:9` | `from_database` | 27.51 / 27.51 | 0.0 | 27.57 | 90% | Object |  | `app/models/bubble/eventable.rb:11` 14%, `app/controllers/buckets_controller.rb:31` 12% | `FromDatabase.new(name, value_before_type_cast, type, nil, value)` |
| 27 | `RAILS/activesupport/lib/active_support/code_generator.rb:35` | `apply` | 26.93 / 26.93 | 0.0 | 28.41 | 10% | Data |  | `app/controllers/buckets_controller.rb:31` 15%, `app/controllers/bubbles_controller.rb:29` 13% | `owner.define_method(as, @cache.instance_method(canonical_name))` |
| 28 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:333` | `define_attribute_method_pattern` | 26.91 / 26.91 | 0.0 | 28.36 | 9% | String |  | `app/controllers/buckets_controller.rb:31` 15%, `app/controllers/bubbles_controller.rb:29` 13% | `generate_method = "define_method_#{pattern.proxy_target}"` |
| 29 | `GEM/tzinfo/lib/tzinfo/timestamp.rb:208` | `for_time` | 25.44 / 25.48 | 0.04 | 26.27 | 93% | Rational, Bignum |  | `app/models/bubble/eventable.rb:11` 17%, `app/controllers/concerns/authentication.rb:56` 14% | `sub_second = time.subsec` |
| 30 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:144` | `change` | 25.33 / 25.42 | 0.08 | 25.5 | 93% | Rational, Array |  | `app/models/bubble/eventable.rb:11` 18%, `app/controllers/concerns/authentication.rb:63` 15% | `new_sec += Rational(new_usec, 1000000)` |

## Dev/test-mode work

1052.3 of 5670.6 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` | 108.1 | 98% | `app/controllers/concerns/authentication.rb:56` 7%, `app/helpers/avatars_helper.rb:20` 5% | `binds = binds.inspect` |
| 2 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:177` | 98.19 | 98% | `app/controllers/concerns/authentication.rb:56` 8%, `no app frame` 5% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 3 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:175` | 65.6 | 98% | `app/controllers/concerns/authentication.rb:56` 8%, `no app frame` 5% | `modes = MODES.values_at(*options.compact_blank.keys)` |
| 4 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:170` | 65.01 | 98% | `app/controllers/concerns/authentication.rb:56` 8%, `no app frame` 5% | `clear = "\e[#{MODES[:clear]}m"` |
| 5 | asset lookup | `GEM/propshaft/lib/propshaft/asset.rb:40` † | 64.75 | 25% | `app/views/layouts/application.html.erb:15` 65%, `app/views/layouts/application.html.erb:16` 10% | `logical_path.sub(/\.(\w+(\.map)?)$/) { \|ext\| "-#{digest}#{ext}" }` |
| 6 | template compile | `RAILS/actionview/lib/action_view/template.rb:509` | 53.21 | 20% | `app/controllers/concerns/current_timezone.rb:10` 25%, `no app frame` 15% | `mod.module_eval(compiled_source, identifier, offset)` |
| 7 | template compile | `GEM/erubi/lib/erubi.rb:134` | 39.95 | 19% | `app/controllers/concerns/current_timezone.rb:10` 27%, `no app frame` 11% | `input.scan(regexp) do \|indicator, code, tailch, rspace\|` |
| 8 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:171` | 32.8 | 98% | `app/controllers/concerns/authentication.rb:56` 8%, `no app frame` 5% | `"#{mode}#{color}#{text}#{clear}"` |
| 9 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:26` | 32.73 | 98% | `app/controllers/concerns/authentication.rb:56` 8%, `no app frame` 5% | `"#{payload[:name]} (#{event.duration.round(1)}ms)"` |
| 10 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:90` | 32.73 | 98% | `app/controllers/concerns/authentication.rb:56` 8%, `no app frame` 5% | `case match[1].downcase` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activerecord | 2194.4 | 2255.0 | `log_subscriber.rb:49` 108.1, `where_clause.rb:29` 96.3, `where_clause.rb:111` 48.1 |
| rails: activesupport | 1272.6 | 1419.1 | `log_subscriber.rb:177` 98.2, `log_subscriber.rb:175` 65.6, `log_subscriber.rb:170` 65.0 |
| rails: actionview | 590.6 | 637.7 | `tag_helper.rb:309` 78.8, `template.rb:509` 53.2, `tag_helper.rb:237` 29.0 |
| rails: activemodel | 380.8 | 399.2 | `attribute_methods.rb:492` 112.9, `attribute.rb:9` 27.5, `attribute_methods.rb:333` 26.9 |
| rails: actionpack | 328.4 | 635.6 | `route_set.rb:101` 57.6, `logger.rb:12` 21.6, `request.rb:66` 8.9 |
| gem: sqlite3 | 142.6 | 143.5 | `statement.rb:125` 47.6, `statement.rb:54` 32.5, `statement.rb:186` 16.7 |
| gem: propshaft | 118.3 | 584.7 | `asset.rb:40` 64.8, `dynamic.rb:11` 32.4, `asset.rb:58` 8.1 |
| gem: logger | 84.1 | 84.4 | `log_device.rb:152` 24.3, `log_device.rb:38` 24.3, `logger.rb:673` 23.4 |
| app | 71.0 | 106.7 | `events_helper.rb:41` 9.3, `role.rb:8` 2.1, `avatars_helper.rb:20` 1.6 |
| gem: erubi | 69.5 | 71.0 | `erubi.rb:134` 39.9, `erubi.rb:137` 8.6, `erubi.rb:139` 5.1 |
| gem: rack | 67.1 | 76.3 | `request.rb:693` 9.8, `utils.rb:408` 6.1, `body_proxy.rb:12` 3.9 |
| gem: tzinfo | 66.4 | 92.3 | `timestamp.rb:208` 25.5, `timestamp.rb:193` 18.3, `constant_offset_data_timezone_info.rb:52` 14.6 |
| ruby default gem: uri | 64.0 | 65.7 | `common.rb:422` 15.6, `common.rb:415` 12.0, `common.rb:83` 5.8 |
| ruby stdlib | 61.6 | 2193.2 | `ipaddr.rb:725` 9.9, `formatter.rb:174` 8.1, `bundled_gems.rb:111` 4.4 |
| gem: debug | 40.0 | 51.3 | `thread_client.rb:901` 10.2, `thread_client.rb:234` 10.2, `thread_client.rb:224` 5.1 |
| gem: concurrent-ruby | 39.4 | 41.4 | `safe_initialization.rb:30` 7.5, `non_concurrent_map_backend.rb:131` 5.2, `mutex_lockable_object.rb:33` 4.5 |
| gem: globalid | 25.7 | 27.3 | `gid.rb:91` 5.8, `gid.rb:155` 5.8, `gid.rb:162` 2.3 |
| gem: importmap-rails | 20.4 | 231.7 | `importmap_tags_helper.rb:34` 17.0, `importmap_tags_helper.rb:20` 0.8, `importmap_tags_helper.rb:21` 0.4 |
| gem: turbo-rails | 17.7 | 20.9 | `stream_name.rb:26` 3.6, `frames_helper.rb:42` 3.4, `stream_name.rb:28` 1.6 |
| gem: json | 13.1 | 13.4 | `common.rb:221` 8.1, `common.rb:305` 3.8, `common.rb:824` 1.1 |
| gem: nokogiri | 9.8 | 11.3 | `node.rb:66` 1.8, `document.rb:415` 1.6, `node.rb:1378` 1.2 |
| rails: railties | 8.9 | 9.4 | `logger.rb:57` 2.0, `engine.rb:748` 1.0, `logger.rb:42` 1.0 |
| gem: base64 | 8.7 | 8.9 | `base64.rb:274` 6.3, `base64.rb:298` 2.0, `base64.rb:359` 0.5 |
| gem: bootsnap | 8.3 | 18.6 | `iseq.rb:53` 3.6, `kernel_require.rb:11` 1.1, `cache.rb:221` 0.9 |
| gem: bcrypt | 7.6 | 7.9 | `password.rb:93` 2.7, `password.rb:94` 1.3, `engine.rb:70` 1.3 |
| rails: activestorage | 5.9 | 9.5 | `model.rb:128` 1.1, `model.rb:284` 0.7, `model.rb:144` 0.6 |
| gem: i18n | 5.4 | 10.0 | `ruby.rb:33` 1.2, `utils.rb:8` 1.1, `i18n.rb:366` 0.9 |
| rails: activejob | 4.4 | 6.9 | `log_subscriber.rb:207` 0.7, `enqueuing.rb:62` 0.3, `log_subscriber.rb:23` 0.3 |
| gem: zeitwerk | 3.8 | 5.7 | `explicit_namespace.rb:61` 1.5, `inflector.rb:16` 1.0, `cref.rb:44` 0.3 |
| gem: rack-session | 2.9 | 3.0 | `id.rb:277` 1.0, `id.rb:275` 1.0, `id.rb:401` 0.6 |
| gem: loofah | 2.6 | 3.0 | `scrubber.rb:132` 1.0, `concerns.rb:172` 0.6, `concerns.rb:43` 0.6 |
| ruby default gem: securerandom | 1.9 | 1.9 | `securerandom.rb:71` 1.9 |
| gem: useragent | 1.7 | 12.3 | `version.rb:27` 0.5, `user_agent.rb:25` 0.2, `user_agent.rb:24` 0.1 |
| gem: rails-html-sanitizer | 1.0 | 1.3 | `sanitizer.rb:29` 0.2, `sanitizer.rb:52` 0.2, `sanitizer.rb:187` 0.2 |
| rails: actioncable | 0.5 | 1.7 | `broadcasting.rb:53` 0.1, `test.rb:24` 0.1, `subscriber_map.rb:9` 0.1 |
| gem: marcel | 0.2 | 0.5 | `magic.rb:18` 0.1, `mime_type.rb:81` 0.0, `mime_type.rb:90` 0.0 |
| gem: redcarpet | 0.2 | 0.2 | `render_strip.rb:40` 0.2 |
| lowrail-profile | 0.0 | 0.0 | `profile.rb:66` 0.0, `profile.rb:56` 0.0 |
| ruby default gem: prism | 0.0 | 1427.8 | `node.rb:16795` 0.0, `node.rb:18058` 0.0, `node.rb:2897` 0.0 |
| gem: nio4r | 0.0 | 0.6 | `nio4r_ext.so:0` 0.0, `nio.rb:21` 0.0, `nio.rb:0` 0.0 |
| ruby default gem: bundler | 0.0 | 0.0 | `rubygems_integration.rb:192` 0.0 |
| gem: msgpack | 0.0 | 0.4 | `factory.rb:29` 0.0, `factory.rb:9` 0.0, `bigint.rb:0` 0.0 |
| rails: actiontext | 0.0 | 0.9 | `content.rb:24` 0.0, `content.rb:27` 0.0, `engine.rb:72` 0.0 |
| gem: jbuilder | 0.0 | 0.6 | `jbuilder_dependency_tracker.rb:0` 0.0, `jbuilder.rb:71` 0.0, `jbuilder.rb:15` 0.0 |
