# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bundle exec rspec --seed 1234 --format documentation`
* Ruby: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +YJIT +PRISM [x86_64-linux]
* Rails: 8.1.3.1, test environment
* Counted in run 1: 815 requests, 18 jobs, 17 mail windows; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 815 | 4458.9 | 18 | 17 | 0 | 0 |
| run2 | 1 | 815 | 4459.3 | 18 | 17 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.0 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/controllers/login_controller.rb:74` | `login` | 308.16 | 0.0 | 0.0 | `GEM/psych/lib/psych/tree_builder.rb:97` 6%, `GEM/activerecord-typedstore/lib/active_record/typed_store/typed_hash.rb:16` 5%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 5% | LoginController#login 100% | `user.save!` |
| 2 | `config/initializers/x_request_token.rb:33` | `make_request_id` | 213.48 | 0.0 | 2.64 | `GEM/typeid/lib/typeid/uuid.rb:83` 27%, `GEM/typeid/lib/typeid/uuid.rb:40` 14%, `GEM/typeid/lib/typeid/uuid.rb:42` 14% | LoginController#login 27%, HomeController#index 16%, LoginController#index 13% | `TypeID.new("request").to_s` |
| 3 | `app/models/stories_paginator.rb:24` | `with_pagination_info` | 138.22 | 0.0 | 0.0 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 11%, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 6%, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:129` 2% | HomeController#index 89%, HomeController#newest 4%, HomeController#for_domain 3% | `scope = scope.to_a` |
| 4 | `app/controllers/concerns/authenticatable.rb:16` | `authenticate_user` | 72.29 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/messages/rotator.rb:55` 9%, `RAILS/activesupport/lib/active_support/key_generator.rb:63` 6%, `GEM/json/lib/json/common.rb:364` 6% | HomeController#index 21%, LoginController#login 17%, StoriesController#show 16% | `if session[:u] &&` |
| 5 | `app/controllers/concerns/authenticatable.rb:17` | `authenticate_user` | 63.7 | 0.0 | 0.8 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 35%, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 18%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 8% | HomeController#index 31%, StoriesController#show 21%, StoriesController#new 4% | `(user = User.find_by(session_token: session[:u].to_s)) &&` |
| 6 | `app/models/concerns/token.rb:6` |  | 56.55 | 0.0 | 0.4 | `GEM/typeid/lib/typeid/uuid.rb:83` 23%, `GEM/typeid/lib/typeid/uuid.rb:40` 12%, `GEM/typeid/lib/typeid/uuid.rb:42` 12% | StoriesController#show 30%, StoriesController#create 15%, StoriesController#new 10% | `self.token \|\|= TypeID.new(self.class.to_s.parameterize) if new_record?` |
| 7 | `app/controllers/login_controller.rb:39` | `login` | 54.74 | 0.0 | 0.0 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 24%, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 12%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 6% | LoginController#login 100% | `User.where(email: params[:email]).first` |
| 8 | `app/controllers/stories_controller.rb:177` | `show` | 51.37 | 0.0 | 0.0 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 17%, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 8%, `RAILS/activerecord/lib/active_record/relation.rb:1519` 4% | StoriesController#show 100% | `@comments = Comment.story_threads(@story).for_presentation.load_async` |
| 9 | `app/views/layouts/application.html.erb:37` |  | 49.94 | 14.69 | 0.49 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 25%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 25%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 13% | HomeController#index 28%, LoginController#index 24%, StoriesController#show 14% | `<%= javascript_importmap_tags "user" %>` |
| 10 | `app/models/user.rb:628` | `inbox_count` | 46.51 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 3%, `RAILS/activerecord/lib/active_record/relation.rb:77` 3% | HomeController#index 45%, StoriesController#show 14%, StoriesController#new 6% | `@inbox_count \|\|= notifications.where(read_at: nil).count` |
| 11 | `app/views/moderations/_table.html.erb:8` |  | 42.46 | 0.0 | 0.0 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 17%, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:178` 14%, `GEM/sqlite3/lib/sqlite3/statement.rb:186` 11% | ModerationsController#index 100% | `<% moderations.each do \|mod\| %>` |
| 12 | `app/models/user.rb:507` | `is_new?` | 36.77 | 0.0 | 0.0 | `GEM/tzinfo/lib/tzinfo/timestamp.rb:208` 15%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:146` 15%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:141` 10% | StoriesController#show 32%, HomeController#index 30%, StoriesController#create 10% | `created_at > NEW_USER_DAYS.days.ago` |
| 13 | `app/controllers/stories_controller.rb:196` | `show` | 33.69 | 0.0 | 0.29 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 13%, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 6%, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:129` 3% | StoriesController#show 100% | `@merged_stories = [@story, @story.merged_stories.not_deleted(@user).mo` |
| 14 | `app/views/layouts/application.html.erb:36` |  | 32.37 | 1.47 | 2.85 | `GEM/activerecord-typedstore/lib/active_record/typed_store/typed_hash.rb:16` 18%, `GEM/psych/lib/psych/parser.rb:62` 15%, `GEM/psych/lib/psych/tree_builder.rb:97` 14% | HomeController#index 40%, LoginController#index 9%, StoriesController#new 7% | `<%= stylesheet_link_tag (@user&.prefers_color_scheme \|\| "system") + "-` |
| 15 | `config/initializers/reject_spoofed_ips.rb:13` | `call` | 27.5 | 0.0 | 0.88 | `RUBY/ipaddr.rb:725` 32%, `RUBY/ipaddr.rb:672` 13%, `RUBY/ipaddr.rb:456` 10% | LoginController#login 27%, HomeController#index 16%, LoginController#index 13% | `ActionDispatch::Request.new(env).remote_ip` |
| 16 | `app/controllers/home_controller.rb:41` | `index` | 26.78 | 0.0 | 0.28 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 12%, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6% | HomeController#index 100% | `paginate Story.hottest(@user, filtered_tags.map(&:id))` |
| 17 | `app/controllers/stories_controller.rb:513` | `track_story_reads` | 26.1 | 0.0 | 0.0 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 21%, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 10%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 4% | StoriesController#show 100% | `@story = Story.where(short_id: params[:id]).mod_single_preload?(@user)` |
| 18 | `app/models/user.rb:489` | `has_2fa?` | 25.88 | 0.0 | 0.0 | `GEM/activerecord-typedstore/lib/active_record/typed_store/typed_hash.rb:16` 30%, `GEM/psych/lib/psych/parser.rb:62` 25%, `GEM/psych/lib/psych/tree_builder.rb:97` 23% | LoginController#login 99%, LoginController#set_new_password 1%, SettingsController#twofa_auth 0% | `totp_secret.present?` |
| 19 | `app/models/story.rb:792` | `is_gone?` | 25.73 | 0.0 | 0.0 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 25%, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 13%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 6% | StoriesController#show 80%, CommentsController#upvote 3%, CommentsController#create 3% | `is_deleted? \|\| (user.is_banned? && score < 0 && is_moderated == false)` |
| 20 | `app/helpers/application_helper.rb:189` | `tag` | 23.8 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 39%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 11%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:237` 11% | StoriesController#show 29%, HomeController#index 24%, LoginController#index 11% | `super` |
| 21 | `app/helpers/application_helper.rb:118` | `link_to_different_page` | 23.62 | 0.0 | 3.37 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:539` 43%, `RAILS/actionview/lib/action_view/helpers/output_safety_helper.rb:36` 29%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 14% | HomeController#index 31%, LoginController#index 17%, StoriesController#show 15% | `options[:class] = class_names(options[:class])` |
| 22 | `app/models/read_ribbon.rb:45` | `bump` | 22.67 | 0.0 | 0.0 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 17%, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 9%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 4% | StoriesController#show 100% | `save!` |
| 23 | `app/models/search.rb:19` | `initialize` | 21.67 | 0.0 | 0.01 | `GEM/parslet/lib/parslet/atoms/context.rb:34` 13%, `GEM/parslet/lib/parslet/source.rb:75` 8%, `GEM/parslet/lib/parslet/atoms/context.rb:63` 6% | SearchController#index 100% | `SearchParser.new.parse(params[:q])` |
| 24 | `app/models/vote.rb:77` | `votes_by_user_for_stories_hash` | 21.42 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/relation/query_methods.rb:2089` 3%, `RAILS/activerecord/lib/active_record/relation/batches.rb:364` 3%, `GEM/sqlite3/lib/sqlite3/statement.rb:186` 3% | HomeController#index 93%, HomeController#for_domain 3%, HomeController#for_origin 2% | `comment_id: nil).find_each do \|v\|` |
| 25 | `app/helpers/application_helper.rb:124` | `link_to_different_page` | 20.95 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 17%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:232` 16%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:237` 16% | HomeController#index 30%, LoginController#index 19%, StoriesController#show 14% | `link_to text, path, options` |
| 26 | `app/controllers/home_controller.rb:64` | `index` | 19.06 | 3.71 | 0.41 | `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:159` 10%, `RAILS/actionpack/lib/abstract_controller/rendering.rb:66` 9%, `RAILS/actionview/lib/action_view/base.rb:230` 9% | HomeController#index 100% | `render action: "index"` |
| 27 | `app/views/stories/_singledetail.html.erb:43` |  | 18.56 | 0.0 | 0.0 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 8%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 4% | StoriesController#show 100%, CabinetController#index 0% | `<% ms.tags.each do \|tag\| %>` |
| 28 | `app/models/story.rb:628` | `can_have_images?` | 17.34 | 0.0 | 0.15 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 19%, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 10%, `RAILS/activerecord/lib/arel/table.rb:85` 3% | StoriesController#show 75%, StoriesController#create 14%, StoriesController#new 11% | `Hat.where(user_id: user.id, modlog_use: true).any? do \|hat\|` |
| 29 | `app/controllers/stories_controller.rb:514` | `track_story_reads` | 14.96 | 0.0 | 0.0 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 7%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` 4%, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 3% | StoriesController#show 100% | `@ribbon = ReadRibbon.where(user: @user, story: @story).first_or_initia` |
| 30 | `app/views/stories/show.html.erb:211` |  | 14.08 | 0.0 | 0.0 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 22%, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 11%, `RAILS/activerecord/lib/arel/visitors/to_sql.rb:790` 11% | StoriesController#show 100% | `<% if @story.public_similar_stories(@user).length > 0 %>` |

App middleware that hands the request on (the stack below it, not its own work): `config/initializers/reject_spoofed_ips.rb:14` 315.36 warm objects per request.

138.72 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | StoriesController#create | 14 / 14 | 9053.2 / 9061.2 | 8.1 | 8997.3 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 335.4, `GEM/typeid/lib/typeid/uuid.rb:83` 205.0, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 167.7 | `app/controllers/stories_controller.rb:34` 639.2, `app/models/concerns/token.rb:6` 544.5, `app/models/mod_mail.rb:41` 490.6 |
| 2 | CommentsController#create | 4 / 4 | 7549.0 / 7539.0 | -10.0 | 7974.3 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 288.0, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 144.0, `GEM/typeid/lib/typeid/uuid.rb:83` 130.0 | `app/controllers/comments_controller.rb:54` 634.7, `app/models/keystore.rb:38` 344.7, `config/initializers/reject_spoofed_ips.rb:14` 339.0 |
| 3 | ModerationsController#index | 10 / 10 | 7448.3 / 7448.3 | 0.0 | 7435.2 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 651.0, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:178` 551.0, `GEM/sqlite3/lib/sqlite3/statement.rb:186` 490.0 | `app/views/moderations/_table.html.erb:8` 3844.8, `app/controllers/moderations_controller.rb:52` 734.6, `config/initializers/reject_spoofed_ips.rb:14` 405.0 |
| 4 | Mod::StoriesController#update | 2 / 2 | 7077.0 / 7082.0 | 5.0 | 8185.0 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 420.0, `GEM/typeid/lib/typeid/uuid.rb:83` 260.0, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 210.0 | `app/models/concerns/token.rb:6` 753.0, `app/controllers/mod/stories_controller.rb:25` 585.0, `app/models/moderation.rb:125` 534.0 |
| 5 | HomeController#newest | 3 / 3 | 6858.0 / 6851.0 | -7.0 | 7292.7 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 245.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 142.5, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 122.5 | `app/models/stories_paginator.rb:24` 2016.5, `app/controllers/home_controller.rb:376` 448.0, `config/initializers/reject_spoofed_ips.rb:14` 311.5 |
| 6 | HomeController#saved | 2 / 2 | 6416.0 / 6409.0 | -7.0 | 6523.0 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 304.0, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 152.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 102.0 | `app/models/stories_paginator.rb:24` 2161.0, `config/initializers/reject_spoofed_ips.rb:14` 349.0, `config/initializers/x_request_token.rb:33` 243.0 |
| 7 | StoriesController#show | 94 / 94 | 6214.7 / 6214.8 | 0.2 | 6217.3 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 438.1, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 219.0, `GEM/typeid/lib/typeid/uuid.rb:83` 99.9 | `app/controllers/stories_controller.rb:177` 450.2, `config/initializers/reject_spoofed_ips.rb:14` 334.2, `app/controllers/stories_controller.rb:196` 295.3 |
| 8 | UsersController#show | 19 / 19 | 6057.5 / 6059.9 | 2.4 | 6134.5 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 205.0, `GEM/typeid/lib/typeid/uuid.rb:83` 104.7, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 102.5 | `app/views/mod/activities/_table.html.erb:4` 406.1, `app/models/keystore.rb:22` 381.8, `app/views/users/show.html.erb:219` 325.1 |
| 9 | CommentsController#index | 5 / 5 | 6035.0 / 6035.5 | 0.5 | 5516.4 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 284.5, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 142.3, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 115.8 | `app/models/comment_vote_hydrator.rb:14` 1125.8, `app/models/comment_vote_hydrator.rb:4` 370.5, `config/initializers/reject_spoofed_ips.rb:14` 329.5 |
| 10 | UsersController#ban | 2 / 2 | 5951.0 / 6018.0 | 67.0 | 6543.0 | `GEM/typeid/lib/typeid/uuid.rb:83` 260.0, `GEM/sqlite3/lib/sqlite3/statement.rb:186` 162.0, `GEM/typeid/lib/typeid/uuid.rb:40` 136.0 | `app/models/user.rb:432` 1358.0, `app/models/concerns/token.rb:6` 738.0, `app/models/mod_activity.rb:45` 367.0 |
| 11 | CommentsController#edit | 3 / 3 | 5922.5 / 5922.0 | -0.5 | 5726.7 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 308.0, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 154.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 104.5 | `config/initializers/reject_spoofed_ips.rb:14` 347.5, `config/initializers/x_request_token.rb:33` 243.0, `app/views/comments/_threads.html.erb:102` 222.0 |
| 12 | StoriesController#new | 15 / 15 | 5845.4 / 5848.6 | 3.1 | 5860.1 | `RUBY/unicode_normalize/tables.rb:0` 682.2, `GEM/sqlite3/lib/sqlite3/statement.rb:186` 209.4, `GEM/typeid/lib/typeid/uuid.rb:83` 143.9 | `extras/sponge.rb:235` 755.8, `config/initializers/reject_spoofed_ips.rb:14` 491.1, `app/models/concerns/token.rb:6` 314.3 |
| 13 | SettingsController#deactivate | 4 / 4 | 5735.3 / 5772.3 | 37.0 | 6059.8 | `GEM/typeid/lib/typeid/uuid.rb:83` 195.0, `GEM/sqlite3/lib/sqlite3/statement.rb:186` 110.7, `GEM/typeid/lib/typeid/uuid.rb:40` 102.0 | `app/models/user.rb:432` 894.0, `app/models/concerns/token.rb:6` 492.0, `config/initializers/reject_spoofed_ips.rb:14` 358.7 |
| 14 | ModMailsController#show | 4 / 4 | 5192.0 / 5191.0 | -1.0 | 4388.5 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 192.0, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 96.0, `GEM/commonmarker/lib/commonmarker/config.rb:87` 92.0 | `app/views/mod_mails/_mail.html.erb:7` 560.0, `config/initializers/reject_spoofed_ips.rb:14` 555.7, `app/views/mod_mails/_mail.html.erb:34` 306.7 |
| 15 | SearchController#index | 11 / 11 | 5155.3 / 5159.3 | 4.0 | 6080.5 | `GEM/parslet/lib/parslet/atoms/context.rb:34` 231.9, `GEM/parslet/lib/parslet/source.rb:75` 143.9, `GEM/parslet/lib/parslet/atoms/str.rb:13` 116.7 | `app/models/search.rb:19` 1766.2, `config/initializers/reject_spoofed_ips.rb:14` 437.4, `app/views/search/index.html.erb:144` 336.1 |
| 16 | Mod::OriginsBanController#create_and_ban | 2 / 2 | 5150.0 / 5155.0 | 5.0 | 5084.5 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 374.0, `GEM/typeid/lib/typeid/uuid.rb:83` 260.0, `GEM/sqlite3/lib/sqlite3/statement.rb:186` 178.0 | `app/models/concerns/token.rb:6` 738.0, `app/controllers/mod/origins_ban_controller.rb:9` 511.0, `app/controllers/mod/origins_ban_controller.rb:8` 422.0 |
| 17 | CommentsController#delete | 4 / 4 | 4670.7 / 4671.0 | 0.3 | 4934.5 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 308.7, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 154.3, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 70.3 | `app/models/comment.rb:299` 421.3, `config/initializers/reject_spoofed_ips.rb:14` 346.7, `config/initializers/x_request_token.rb:33` 243.0 |
| 18 | StoriesController#destroy | 2 / 2 | 4613.0 / 4619.0 | 6.0 | 4628.0 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 282.0, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 141.0, `GEM/typeid/lib/typeid/uuid.rb:83` 65.0 | `app/controllers/stories_controller.rb:69` 575.0, `config/initializers/reject_spoofed_ips.rb:14` 368.0, `app/controllers/stories_controller.rb:464` 322.0 |
| 19 | CommentsController#disown | 4 / 4 | 4578.7 / 4574.7 | -4.0 | 4597.3 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 349.3, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 174.7, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 85.0 | `app/models/keystore.rb:27` 408.0, `config/initializers/reject_spoofed_ips.rb:14` 352.0, `app/controllers/comments_controller.rb:433` 282.7 |
| 20 | Mod::DomainsBanController#create_and_ban | 2 / 2 | 4535.0 / 4536.0 | 1.0 | 4404.5 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 355.0, `GEM/typeid/lib/typeid/uuid.rb:83` 195.0, `GEM/sqlite3/lib/sqlite3/statement.rb:186` 134.0 | `app/models/domain.rb:125` 626.0, `app/models/concerns/token.rb:6` 494.0, `config/initializers/reject_spoofed_ips.rb:14` 422.0 |
| 21 | Mod::MailsController#create | 2 / 2 | 4500.0 / 4441.0 | -59.0 | 4878.5 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 220.0, `GEM/typeid/lib/typeid/uuid.rb:83` 130.0, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 110.0 | `app/controllers/mod/mails_controller.rb:23` 1517.0, `app/controllers/mod/mails_controller.rb:51` 481.0, `config/initializers/reject_spoofed_ips.rb:14` 398.0 |
| 22 | HomeController#index | 114 / 114 | 4333.0 / 4333.7 | 0.7 | 4364.4 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 188.8, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 94.4, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 65.9 | `app/models/stories_paginator.rb:24` 891.3, `config/initializers/reject_spoofed_ips.rb:14` 325.6, `config/initializers/x_request_token.rb:33` 243.0 |
| 23 | CommentsController#upvote | 4 / 4 | 4192.3 / 4186.7 | -5.7 | 4405.3 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 415.3, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 207.7, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 83.7 | `config/initializers/reject_spoofed_ips.rb:14` 353.3, `app/models/vote.rb:157` 268.7, `config/initializers/x_request_token.rb:33` 243.0 |
| 24 | CommentsController#user_threads | 6 / 6 | 4183.6 / 4185.8 | 2.2 | 4157.5 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 229.6, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 114.8, `GEM/typeid/lib/typeid/uuid.rb:83` 65.0 | `app/controllers/comments_controller.rb:405` 1150.0, `config/initializers/reject_spoofed_ips.rb:14` 450.2, `config/initializers/x_request_token.rb:33` 243.0 |
| 25 | HomeController#single_tag | 3 / 3 | 4121.0 / 4134.0 | 13.0 | 5203.3 | `RAILS/actionpack/lib/action_controller/metal/rescue.rb:39` 157.5, `GEM/sqlite3/lib/sqlite3/statement.rb:186` 132.0, `RAILS/activemodel/lib/active_model/attribute.rb:9` 80.5 | `app/models/stories_paginator.rb:24` 1008.0, `app/controllers/home_controller.rb:376` 471.5, `config/initializers/reject_spoofed_ips.rb:14` 458.0 |
| 26 | InvitationsController#create | 2 / 2 | 4073.0 / 4113.0 | 40.0 | 3663.5 | `GEM/typeid/lib/typeid/uuid.rb:83` 130.0, `GEM/mail/lib/mail/utilities.rb:215` 120.0, `GEM/sqlite3/lib/sqlite3/statement.rb:186` 114.0 | `app/models/invitation.rb:33` 1028.0, `app/mailers/invitation_mailer.rb:7` 624.0, `app/controllers/invitations_controller.rb:56` 445.0 |
| 27 | HomeController#for_origin | 3 / 3 | 3999.0 / 3991.5 | -7.5 | 4273.7 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 182.0, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 91.0, `GEM/typeid/lib/typeid/uuid.rb:83` 65.0 | `app/models/stories_paginator.rb:24` 333.0, `config/initializers/reject_spoofed_ips.rb:14` 333.0, `config/initializers/x_request_token.rb:33` 243.0 |
| 28 | HatsController#index | 7 / 7 | 3980.3 / 3982.0 | 1.7 | 4108.4 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 234.0, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:178` 194.0, `GEM/sqlite3/lib/sqlite3/statement.rb:186` 124.7 | `app/controllers/hats_controller.rb:15` 1320.5, `config/initializers/reject_spoofed_ips.rb:14` 451.2, `config/initializers/x_request_token.rb:33` 243.0 |
| 29 | LoginController#reset_password | 7 / 7 | 3859.0 / 3875.5 | 16.5 | 3614.7 | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:101` 66.5, `GEM/typeid/lib/typeid/uuid.rb:83` 65.0, `GEM/mail/lib/mail/utilities.rb:215` 60.0 | `app/models/user.rb:483` 984.7, `app/models/user.rb:485` 538.5, `config/initializers/reject_spoofed_ips.rb:14` 337.7 |
| 30 | HomeController#for_domain | 7 / 7 | 3684.7 / 3686.5 | 1.8 | 3808.6 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 133.3, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 66.7, `GEM/typeid/lib/typeid/uuid.rb:83` 65.0 | `app/models/stories_paginator.rb:24` 510.2, `config/initializers/reject_spoofed_ips.rb:14` 387.5, `config/initializers/x_request_token.rb:33` 243.0 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` | `get_metadata` | 155.96 / 155.96 | 0.0 | 156.26 | 84% | String, Data |  | `app/controllers/concerns/authenticatable.rb:17` 18%, `app/models/stories_paginator.rb:24` 11% | `val&.downcase` |
| 2 | `GEM/typeid/lib/typeid/uuid.rb:83` † | `string` | 85.98 / 85.98 | 0.0 | 86.06 | 100% | String, Array |  | `config/initializers/x_request_token.rb:33` 76%, `app/models/concerns/token.rb:6` 24% | `.with_index { \|byte, index\| ([4, 6, 8, 10].include?(index) ? "-%02x" :` |
| 3 | `GEM/sqlite3/lib/sqlite3/statement.rb:185` | `get_metadata` | 77.98 / 77.98 | 0.0 | 78.13 | 84% | String |  | `app/controllers/concerns/authenticatable.rb:17` 18%, `app/models/stories_paginator.rb:24` 11% | `val = column_decltype(column)` |
| 4 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` | `tag_option` | 45.36 / 45.36 | 0.0 | 45.47 | 55% | String |  | `app/views/layouts/application.html.erb:37` 31%, `app/helpers/application_helper.rb:189` 23% | `%(#{key}="#{value}")` |
| 5 | `GEM/typeid/lib/typeid/uuid.rb:40` | `from_string` | 44.97 / 44.97 | 0.0 | 45.01 | 100% | String, Array |  | `config/initializers/x_request_token.rb:33` 76%, `app/models/concerns/token.rb:6` 24% | `.chars` |
| 6 | `GEM/typeid/lib/typeid/uuid.rb:42` † | `from_string` | 44.97 / 44.97 | 0.0 | 45.01 | 100% | Array, String |  | `config/initializers/x_request_token.rb:33` 76%, `app/models/concerns/token.rb:6` 24% | `.map { \|pair\| pair.join.to_i(16) }` |
| 7 | `GEM/typeid/lib/typeid.rb:90` | `initialize` | 41.0 / 41.0 | 0.0 | 41.04 | 100% | String, Array |  | `config/initializers/x_request_token.rb:33` 76%, `app/models/concerns/token.rb:6` 24% | `raise Error, "suffix must start with a 0-7 digit to avoid overflows" u` |
| 8 | `GEM/activerecord-typedstore/lib/active_record/typed_store/typed_hash.rb:16` † | `defaults_hash` | 40.01 / 40.01 | 0.0 | 40.13 | 61% | Array, Hash |  | `app/controllers/login_controller.rb:74` 38%, `app/models/user.rb:489` 20% | `Hash[fields.values.select(&:has_default?).map { \|c\| [c.name, c.default` |
| 9 | `RAILS/actionpack/lib/action_dispatch/http/permissions_policy.rb:159` | `build_directives` | 37.58 / 37.58 | 0.0 | 37.63 | 99% | String |  | `config/initializers/reject_spoofed_ips.rb:14` 100% | `"#{directive} #{build_directive(sources, context).join(' ')}"` |
| 10 | `GEM/psych/lib/psych/tree_builder.rb:97` | `scalar` | 37.33 / 37.33 | 0.0 | 37.45 | 61% | Object |  | `app/controllers/login_controller.rb:74` 47%, `app/models/user.rb:489` 16% | `s = Nodes::Scalar.new(value,anchor,tag,plain,quoted,style)` |
| 11 | `GEM/typeid/lib/typeid.rb:89` | `initialize` | 37.04 / 37.04 | 0.0 | 37.07 | 100% | String, Array |  | `config/initializers/x_request_token.rb:33` 76%, `app/models/concerns/token.rb:6` 24% | `raise Error, "suffix must only contain the letters in '#{TypeID::UUID:` |
| 12 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` | `each` | 36.61 / 36.61 | 0.0 | 36.67 | 84% | String, Array |  | `app/controllers/concerns/authenticatable.rb:17` 17%, `app/models/stories_paginator.rb:24` 9% | `val = step` |
| 13 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` | `call` | 33.45 / 33.45 | 0.0 | 33.47 | 100% | Data |  | `app/controllers/login_controller.rb:74` 45%, `config/initializers/reject_spoofed_ips.rb:14` 24% | `result_lambda = -> { user_callback.call target, value }` |
| 14 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` | `html_safe` | 33.07 / 33.07 | 0.0 | 33.13 | 56% | String |  | `app/views/layouts/application.html.erb:37` 21%, `app/helpers/application_helper.rb:118` 11% | `ActiveSupport::SafeBuffer.new(self)` |
| 15 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` | `initialize` | 27.5 / 27.5 | -0.0 | 27.56 | 56% | String |  | `app/views/layouts/application.html.erb:37` 24%, `app/helpers/application_helper.rb:124` 14% | `super` |
| 16 | `RAILS/activerecord/lib/arel/table.rb:85` | `[]` | 26.25 / 26.25 | 0.0 | 26.27 | 83% | Struct |  | `app/controllers/login_controller.rb:74` 12%, `app/views/moderations/_table.html.erb:8` 12% | `Attribute.new(table, name)` |
| 17 | `GEM/psych/lib/psych/parser.rb:62` | `parse` | 25.63 / 25.63 | 0.0 | 25.7 | 61% | String, Array |  | `app/models/user.rb:489` 25%, `app/controllers/login_controller.rb:74` 25% | `_native_parse @handler, yaml, path` |
| 18 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` | `+` | 25.48 / 25.48 | 0.0 | 25.49 | 83% | Object, Array |  | `app/controllers/login_controller.rb:74` 21%, `app/models/user.rb:628` 5% | `WhereClause.new(predicates + other.predicates)` |
| 19 | `RAILS/activemodel/lib/active_model/attribute.rb:9` | `from_database` | 23.51 / 23.51 | 0.0 | 23.51 | 83% | Object |  | `app/controllers/login_controller.rb:74` 51%, `app/models/concerns/token.rb:6` 12% | `FromDatabase.new(name, value_before_type_cast, type, nil, value)` |
| 20 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` | `expand_from_hash` | 21.66 / 21.66 | 0.0 | 21.67 | 82% | Array |  | `app/controllers/login_controller.rb:74` 13%, `app/models/user.rb:628` 6% | `attributes.flat_map do \|key, value\|` |
| 21 | `RAILS/activerecord/lib/active_record/relation.rb:98` | `initialize_copy` | 20.63 / 20.63 | 0.0 | 20.65 | 83% | Hash |  | `app/controllers/login_controller.rb:74` 13%, `app/controllers/login_controller.rb:39` 3% | `@values = @values.dup` |
| 22 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | `merge` | 20.58 / 20.58 | 0.0 | 20.6 | 51% | Array, Object |  | `app/models/user.rb:628` 13%, `app/controllers/home_controller.rb:41` 7% | `WhereClause.new(predicates \| other.predicates)` |
| 23 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` | `create` | 20.58 / 20.58 | 0.0 | 20.6 | 83% | Object, Hash |  | `app/models/stories_paginator.rb:24` 12%, `app/models/user.rb:628` 7% | `relation_class_for(model).new(model, ...)` |
| 24 | `RAILS/activerecord/lib/arel.rb:56` | `sql` | 20.4 / 20.4 | 0.0 | 20.43 | 83% | Hash, String |  | `app/controllers/login_controller.rb:74` 13%, `app/models/stories_paginator.rb:24` 7% | `Arel::Nodes::SqlLiteral.new(sql_string, retryable: retryable)` |
| 25 | `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` | `evaluate` | 19.99 / 19.99 | 0.0 | 20.03 | 71% | Array |  | `extras/routes.rb:29` 6%, `app/views/layouts/application.html.erb:91` 5% | `parts = @parts.dup` |
| 26 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:237` | `tag_options` | 19.88 / 19.88 | 0.0 | 19.92 | 55% | String |  | `app/views/layouts/application.html.erb:37` 24%, `app/helpers/application_helper.rb:124` 19% | `output = +""` |
| 27 | `RAILS/activerecord/lib/active_record/relation.rb:77` | `initialize` | 19.47 / 19.47 | 0.0 | 19.49 | 83% | Hash |  | `app/models/stories_paginator.rb:24` 12%, `app/models/user.rb:628` 8% | `def initialize(model, table: nil, predicate_builder: nil, values: {})` |
| 28 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:29` | `references` | 19.04 / 19.04 | 0.0 | 19.06 | 82% | Array |  | `app/controllers/login_controller.rb:74` 14%, `app/models/user.rb:628` 6% | `attributes.each_with_object([]) do \|(key, value), result\|` |
| 29 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:166` | `convert_dot_notation_to_hash` | 19.04 / 19.04 | 0.0 | 19.06 | 82% | Array, Hash |  | `app/controllers/login_controller.rb:74` 14%, `app/models/user.rb:628` 6% | `attributes.each_with_object({}) do \|(key, value), converted\|` |
| 30 | `RAILS/actionpack/lib/action_dispatch/http/permissions_policy.rb:169` † | `build_directive` | 18.79 / 18.79 | 0.0 | 18.81 | 99% | Array |  | `config/initializers/reject_spoofed_ips.rb:14` 100% | `sources.map { \|source\| resolve_source(source, context) }` |

## Dev/test-mode work

94.2 of 3662.4 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | template compile | `GEM/erubi/lib/erubi.rb:134` | 10.52 | 6% | `config/initializers/reject_spoofed_ips.rb:14` 30%, `app/controllers/users_controller.rb:37` 6% | `input.scan(regexp) do \|indicator, code, tailch, rspace\|` |
| 2 | template compile | `RAILS/actionview/lib/action_view/template.rb:508` | 8.78 | 7% | `config/initializers/reject_spoofed_ips.rb:14` 34%, `app/controllers/users_controller.rb:37` 5% | `mod.module_eval(compiled_source, identifier, offset)` |
| 3 | debug logging | `RAILS/actionpack/lib/abstract_controller/logger.rb:12` | 8.67 | 98% | `config/initializers/reject_spoofed_ips.rb:14` 91%, `app/controllers/login_controller.rb:97` 5% | `singleton_class.delegate :logger, :logger=, to: :config` |
| 4 | debug logging | `RAILS/actionview/lib/action_view/structured_event_subscriber.rb:61` † | 8.22 | 56% | `config/initializers/reject_spoofed_ips.rb:14` 43%, `app/controllers/home_controller.rb:64` 25% | `string = string.sub("#{rails_root}/", "")` |
| 5 | asset lookup | `GEM/importmap-rails/app/helpers/importmap/importmap_tags_helper.rb:34` | 7.58 | 54% | `app/views/layouts/application.html.erb:37` 100% | `tag.link rel: "modulepreload", href: path, nonce: request&.content_sec` |
| 6 | asset lookup | `GEM/propshaft/lib/propshaft/resolver/static.rb:11` | 3.73 | 54% | `app/views/layouts/application.html.erb:35` 29%, `app/views/layouts/application.html.erb:36` 29% | `File.join prefix, asset_path` |
| 7 | route build | `RAILS/actionpack/lib/action_dispatch/journey/gtg/transition_table.rb:52` | 3.05 | 100% | `config/initializers/reject_spoofed_ips.rb:14` 100% | `next_states = []` |
| 8 | asset lookup | `GEM/propshaft/lib/propshaft/helper.rb:16` | 2.39 | 54% | `app/views/layouts/application.html.erb:41` 27%, `app/views/layouts/application.html.erb:40` 27% | `super` |
| 9 | template compile | `GEM/erubi/lib/erubi.rb:137` | 2.36 | 6% | `config/initializers/reject_spoofed_ips.rb:14` 30%, `app/controllers/users_controller.rb:37` 6% | `text = input[pos, len]` |
| 10 | asset lookup | `GEM/importmap-rails/app/helpers/importmap/importmap_tags_helper.rb:20` † | 2.16 | 54% | `app/views/layouts/application.html.erb:37` 100% | `imports = Array(module_names).collect { \|m\| %(import "#{m}") }.join("\` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activerecord | 1170.1 | 1176.2 | `table.rb:85` 26.3, `where_clause.rb:15` 25.5, `predicate_builder.rb:87` 21.7 |
| rails: activesupport | 478.4 | 483.0 | `callbacks.rb:179` 33.5, `output_safety.rb:242` 33.1, `output_safety.rb:71` 27.5 |
| rails: actionpack | 417.1 | 419.6 | `permissions_policy.rb:159` 37.6, `visitors.rb:40` 20.0, `permissions_policy.rb:169` 18.8 |
| rails: actionview | 317.7 | 322.7 | `tag_helper.rb:309` 45.4, `tag_helper.rb:237` 19.9, `output_safety_helper.rb:36` 12.5 |
| gem: sqlite3 | 309.4 | 310.0 | `statement.rb:186` 156.0, `statement.rb:185` 78.0, `statement.rb:125` 36.6 |
| gem: typeid | 308.2 | 308.5 | `uuid.rb:83` 86.0, `uuid.rb:40` 45.0, `uuid.rb:42` 45.0 |
| app | 168.6 | 176.6 | `application_helper.rb:116` 7.6, `application_helper.rb:115` 7.6, `application_helper.rb:117` 7.5 |
| ruby default gem: psych | 128.4 | 128.8 | `tree_builder.rb:97` 37.3, `parser.rb:62` 25.6, `emitter.rb:32` 12.5 |
| rails: activemodel | 86.9 | 89.2 | `attribute.rb:9` 23.5, `string.rb:39` 11.3, `builder.rb:37` 5.3 |
| gem: rack | 78.6 | 79.6 | `request.rb:693` 12.1, `utils.rb:408` 6.5, `request.rb:604` 6.1 |
| ruby default gem: uri | 47.2 | 47.3 | `common.rb:465` 17.9, `common.rb:456` 15.4, `common.rb:448` 1.6 |
| gem: activerecord-typedstore | 42.1 | 42.3 | `typed_hash.rb:16` 40.0, `behavior.rb:90` 1.2, `type.rb:18` 0.9 |
| ruby stdlib | 39.9 | 53.1 | `ipaddr.rb:725` 10.4, `ipaddr.rb:672` 4.2, `ipaddr.rb:456` 3.0 |
| gem: tzinfo | 35.7 | 35.7 | `timestamp.rb:208` 16.1, `timestamp.rb:193` 8.1, `transitions_data_timezone_info.rb:66` 4.7 |
| gem: rack-mini-profiler | 33.1 | 33.2 | `railtie.rb:159` 16.7, `mini_profiler.rb:415` 8.0, `client_settings.rb:27` 2.7 |
| gem: parslet | 26.4 | 29.0 | `context.rb:34` 2.8, `source.rb:75` 1.8, `str.rb:13` 1.4 |
| gem: concurrent-ruby | 20.9 | 21.1 | `safe_initialization.rb:30` 6.0, `non_concurrent_map_backend.rb:131` 2.8, `mutex_lockable_object.rb:32` 2.0 |
| gem: erubi | 19.0 | 23.0 | `erubi.rb:134` 10.5, `erubi.rb:137` 2.4, `erubi.rb:139` 1.3 |
| gem: importmap-rails | 16.2 | 16.3 | `importmap_tags_helper.rb:34` 7.6, `importmap_tags_helper.rb:20` 2.2, `importmap_tags_helper.rb:15` 1.1 |
| gem: uuid7 | 11.9 | 11.9 | `uuid7.rb:21` 9.3, `generator.rb:27` 1.3, `generator.rb:45` 1.3 |
| gem: bcrypt | 10.2 | 10.2 | `password.rb:102` 2.8, `password.rb:103` 1.4, `engine.rb:70` 1.4 |
| gem: json | 7.8 | 7.9 | `common.rb:364` 5.2, `common.rb:1089` 2.6, `common.rb:536` 0.0 |
| gem: i18n | 6.2 | 7.0 | `i18n.rb:396` 0.9, `utils.rb:8` 0.7, `base.rb:157` 0.7 |
| gem: propshaft | 6.1 | 6.2 | `static.rb:11` 3.7, `helper.rb:16` 2.4, `static.rb:23` 0.0 |
| rails: railties | 6.0 | 6.0 | `engine.rb:748` 1.0, `logger.rb:37` 1.0, `logger.rb:24` 1.0 |
| gem: mail | 5.3 | 6.7 | `utilities.rb:215` 0.4, `utilities.rb:291` 0.3, `address_lists_parser.rb:32009` 0.3 |
| gem: base64 | 5.0 | 5.0 | `base64.rb:283` 3.0, `base64.rb:310` 2.0 |
| gem: rack-attack | 4.0 | 4.0 | `attack.rb:40` 2.0, `attack.rb:107` 1.0, `attack.rb:43` 1.0 |
| gem: rack-session | 3.6 | 3.6 | `id.rb:277` 1.0, `id.rb:275` 1.0, `id.rb:401` 0.8 |
| gem: nokogiri | 3.3 | 3.7 | `node.rb:1429` 0.4, `searchable.rb:270` 0.3, `node.rb:1252` 0.3 |
| gem: commonmarker | 2.9 | 3.2 | `config.rb:87` 2.3, `node.rb:27` 0.2, `commonmarker.rb:26` 0.1 |
| gem: debug | 2.9 | 3.2 | `thread_client.rb:234` 0.7, `thread_client.rb:903` 0.7, `thread_client.rb:223` 0.4 |
| ruby default gem: securerandom | 2.6 | 2.6 | `securerandom.rb:71` 2.6 |
| gem: turbo-rails | 2.1 | 2.1 | `frame_request.rb:36` 1.1, `request_id_tracking.rb:10` 1.0 |
| gem: request_store | 2.0 | 2.0 | `middleware.rb:28` 1.0, `middleware.rb:21` 1.0, `request_store.rb:15` 0.0 |
| ruby default gem: erb | 1.7 | 1.7 | `util.rb:65` 1.7 |
| gem: builder | 1.4 | 1.9 | `xchar.rb:155` 0.3, `xchar.rb:156` 0.2, `xchar.rb:154` 0.2 |
| test harness: rspec-mocks | 1.3 | 1.6 | `recorder.rb:135` 0.2, `message_chains.rb:7` 0.2, `message_expectation.rb:629` 0.1 |
| rails: activejob | 1.0 | 1.0 | `queue_name.rb:50` 0.1, `core.rb:129` 0.1, `configured_job.rb:15` 0.1 |
| test harness: webmock | 0.8 | 1.1 | `headers.rb:69` 0.2, `headers.rb:68` 0.1, `headers.rb:16` 0.1 |
| gem: addressable | 0.4 | 0.7 | `uri.rb:1417` 0.0, `uri.rb:136` 0.0, `uri.rb:1858` 0.0 |
| test harness: vcr | 0.4 | 0.7 | `errors.rb:269` 0.0, `errors.rb:190` 0.0, `errors.rb:186` 0.0 |
| gem: globalid | 0.4 | 0.4 | `gid.rb:95` 0.1, `gid.rb:159` 0.1, `gid.rb:166` 0.0 |
| test harness: rspec-support | 0.2 | 0.3 | `fuzzy_matcher.rb:32` 0.0, `caller_filter.rb:67` 0.0, `method_signature_verifier.rb:135` 0.0 |
| rails: actionmailer | 0.1 | 0.1 | `delivery_methods.rb:66` 0.0, `base.rb:999` 0.0, `base.rb:943` 0.0 |
| gem: bigdecimal | 0.1 | 0.1 | `util.rb:24` 0.1, `util.rb:51` 0.0 |
| ruby default gem: bundler | 0.0 | 0.1 | `shared_helpers.rb:22` 0.0, `rubygems_integration.rb:201` 0.0, `rubygems_integration.rb:206` 0.0 |
| ruby default gem: timeout | 0.0 | 0.1 | `timeout.rb:292` 0.0, `timeout.rb:152` 0.0, `timeout.rb:293` 0.0 |
| gem: actionpack-page_caching | 0.0 | 0.0 | `pages.rb:186` 0.0, `pages.rb:97` 0.0, `pages.rb:312` 0.0 |
| gem: lowrail-profile | 0.0 | 0.0 | `profile.rb:95` 0.0, `profile.rb:55` 0.0, `profile.rb:65` 0.0 |
| gem: rqrcode | 0.0 | 9.9 | `svg.rb:189` 0.0, `svg.rb:221` 0.0, `svg.rb:99` 0.0 |
| gem: rotp | 0.0 | 0.2 | `totp.rb:57` 0.0, `uri.rb:42` 0.0, `totp.rb:11` 0.0 |
| gem: zeitwerk | 0.0 | 0.2 | `helpers.rb:26` 0.0, `cref.rb:47` 0.0, `helpers.rb:44` 0.0 |
| gem: logger | 0.0 | 0.0 | `log_device.rb:33` 0.0, `logger.rb:692` 0.0, `log_device.rb:165` 0.0 |
| gem: rqrcode_core | 0.0 | 67.6 | `qr_util.rb:116` 0.0, `qr_code.rb:303` 0.0, `qr_code.rb:469` 0.0 |
| gem: faker | 0.0 | 1.1 | `faker.rb:134` 0.0, `faker.rb:239` 0.0, `faker.rb:109` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Jobs

| # | Job | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | CachePageJob#perform | 7 / 7 | 5380.2 / 5380.7 | 0.5 | 4861.3 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 286.3, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 143.2, `GEM/typeid/lib/typeid/uuid.rb:83` 108.3 | `app/jobs/cache_page_job.rb:10` 336.3, `app/models/stories_paginator.rb:24` 309.3, `config/initializers/reject_spoofed_ips.rb:14` 268.5 |
| 2 | NotifyCommentJob#perform | 6 / 6 | 3135.2 / 3135.2 | 0.0 | 4643.8 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` 144.8, `GEM/mail/lib/mail/utilities.rb:215` 73.2, `GEM/sqlite3/lib/sqlite3/statement.rb:185` 72.4 | `app/jobs/notify_comment_job.rb:16` 551.6, `app/jobs/notify_comment_job.rb:32` 391.6, `app/models/concerns/token.rb:6` 250.6 |
| 3 | RefillStoryPageCacheJob#perform | 1 / 1 | – / – |  | 6564.0 |  |  |
| 4 | PrefillPageCacheJob#perform | 1 / 1 | – / – |  | 4285.0 |  |  |
| 5 | NotifyMessageJob#perform | 1 / 1 | – / – |  | 3653.0 |  |  |
| 6 | ActionMailer::MailDeliveryJob#perform | 1 / 1 | – / – |  | 2613.0 |  |  |
| 7 | NotifyModMailMessageJob#perform | 1 / 1 | – / – |  | 1609.0 |  |  |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` | 173.11 / 173.11 | 100% | `app/models/stories_paginator.rb:24` 17%, `app/controllers/stories_controller.rb:145` 10% | `val&.downcase` |
| 2 | `GEM/sqlite3/lib/sqlite3/statement.rb:185` | 86.56 / 86.56 | 100% | `app/models/stories_paginator.rb:24` 17%, `app/controllers/stories_controller.rb:145` 10% | `val = column_decltype(column)` |
| 3 | `GEM/typeid/lib/typeid/uuid.rb:83` † | 65.0 / 65.0 | 83% | `app/models/concerns/token.rb:6` 65%, `config/initializers/x_request_token.rb:33` 35% | `.with_index { \|byte, index\| ([4, 6, 8, 10].include?(index) ? "-%02x" :` |
| 4 | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:101` † | 44.33 / 44.33 | 17% | `app/jobs/notify_mod_mail_message_job.rb:18` 33%, `app/jobs/notify_message_job.rb:15` 33% | `@path_helpers.map(&:to_s) + @url_helpers.map(&:to_s)` |
| 5 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` | 40.56 / 40.56 | 100% | `app/jobs/refill_story_page_cache_job.rb:7` 25%, `app/models/stories_paginator.rb:24` 15% | `val = step` |
| 6 | `GEM/typeid/lib/typeid/uuid.rb:40` | 34.0 / 34.0 | 83% | `app/models/concerns/token.rb:6` 65%, `config/initializers/x_request_token.rb:33` 35% | `.chars` |
| 7 | `GEM/typeid/lib/typeid/uuid.rb:42` † | 34.0 / 34.0 | 83% | `app/models/concerns/token.rb:6` 65%, `config/initializers/x_request_token.rb:33` 35% | `.map { \|pair\| pair.join.to_i(16) }` |
| 8 | `GEM/mail/lib/mail/utilities.rb:215` | 33.72 / 33.72 | 33% | `app/jobs/notify_comment_job.rb:74` 22%, `app/jobs/notify_comment_job.rb:32` 22% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 9 | `GEM/typeid/lib/typeid.rb:90` | 31.0 / 31.0 | 83% | `app/models/concerns/token.rb:6` 65%, `config/initializers/x_request_token.rb:33` 35% | `raise Error, "suffix must start with a 0-7 digit to avoid overflows" u` |
| 10 | `GEM/erubi/lib/erubi.rb:134` (template compile) | 29.06 / 29.06 | 33% | `app/controllers/stories_controller.rb:167` 81%, `app/views/home/index.html.erb:2` 5% | `input.scan(regexp) do \|indicator, code, tailch, rspace\|` |

### Mails

| # | Mailer action | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | EmailReplyMailer#reply | 8 / 8 | 1067.4 / 1068.1 | 0.7 | 1087.5 | `GEM/mail/lib/mail/parsers/message_ids_parser.rb:4870` 132.7, `GEM/mail/lib/mail/parsers/address_lists_parser.rb:32009` 48.0, `GEM/mail/lib/mail/utilities.rb:215` 41.0 | `app/mailers/email_reply_mailer.rb:18` 515.4, `app/mailers/email_reply_mailer.rb:41` 204.6, `app/mailers/email_reply_mailer.rb:42` 130.6 |
| 2 | PasswordResetMailer.deliver_mail | 3 / 3 | 869.0 / 868.5 | -0.5 | 868.7 | `GEM/mail/lib/mail/utilities.rb:215` 78.0, `GEM/mail/lib/mail/parsers/message_ids_parser.rb:4870` 43.5, `GEM/mail/lib/mail/utilities.rb:388` 40.0 | `app/models/user.rb:485` 866.5 |
| 3 | PasswordResetMailer#password_reset_link | 3 / 3 | 613.0 / 613.0 | 0.0 | 613.0 | `GEM/mail/lib/mail/parsers/address_lists_parser.rb:32009` 47.0, `GEM/mail/lib/mail/utilities.rb:215` 38.0, `GEM/mail/lib/mail/parser_tools.rb:7` 27.0 | `app/mailers/password_reset_mailer.rb:8` 513.0, `app/views/password_reset_mailer/password_reset_link.text.erb:7` 39.0, `app/models/user.rb:485` 12.0 |
| 4 | InvitationRequestMailer.deliver_mail | 1 / 1 | – / – |  | 986.0 |  |  |
| 5 | InvitationRequestMailer#invitation_request | 1 / 1 | – / – |  | 874.0 |  |  |
| 6 | BanNotificationMailer#notify | 1 / 1 | – / – |  | 676.0 |  |  |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/mail/lib/mail/parsers/message_ids_parser.rb:4870` | 70.94 / 70.88 | 71% | `app/mailers/email_reply_mailer.rb:41` 86%, `app/models/user.rb:485` 10% | `_wide = data[p].ord` |
| 2 | `GEM/mail/lib/mail/utilities.rb:215` | 46.65 / 46.65 | 100% | `app/mailers/email_reply_mailer.rb:18` 35%, `app/models/user.rb:485` 28% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 3 | `GEM/mail/lib/mail/parsers/address_lists_parser.rb:32009` | 35.82 / 35.82 | 77% | `app/mailers/email_reply_mailer.rb:18` 59%, `app/mailers/password_reset_mailer.rb:8` 21% | `_wide = data[p].ord` |
| 4 | `GEM/mail/lib/mail/utilities.rb:291` | 32.24 / 32.24 | 100% | `app/mailers/email_reply_mailer.rb:18` 34%, `app/models/user.rb:485` 21% | `value !~ /\S/` |
| 5 | `GEM/mail/lib/mail/parser_tools.rb:7` | 27.12 / 27.12 | 100% | `app/mailers/email_reply_mailer.rb:18` 44%, `app/mailers/email_reply_mailer.rb:41` 17% | `data.slice(from_bytes..to_bytes).force_encoding(Encoding::UTF_8)` |
| 6 | `GEM/mail/lib/mail/field_list.rb:71` † | 20.0 / 20.0 | 100% | `app/mailers/email_reply_mailer.rb:18` 34%, `app/models/user.rb:485` 31% | `fields = select { \|f\| f.responsible_for? field_name }` |
| 7 | `GEM/mail/lib/mail/parsers/content_type_parser.rb:734` | 14.12 / 14.12 | 77% | `app/mailers/email_reply_mailer.rb:18` 62%, `app/mailers/password_reset_mailer.rb:8` 23% | `_wide = data[p].ord` |
| 8 | `GEM/mail/lib/mail/field.rb:176` | 13.29 / 13.29 | 100% | `app/mailers/email_reply_mailer.rb:18` 40%, `app/mailers/email_reply_mailer.rb:41` 20% | `class_name = FIELDS_MAP[name.to_s.downcase]` |
| 9 | `GEM/sqlite3/lib/sqlite3/statement.rb:186` | 10.82 / 10.82 | 29% | `app/mailers/email_reply_mailer.rb:42` 100% | `val&.downcase` |
| 10 | `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:159` † | 10.06 / 10.06 | 77% | `app/mailers/email_reply_mailer.rb:18` 60%, `app/mailers/password_reset_mailer.rb:8` 24% | `identifier.split('/').last(2).join('/')` |
