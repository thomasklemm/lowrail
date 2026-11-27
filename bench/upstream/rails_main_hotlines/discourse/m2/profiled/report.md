# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bundle exec rspec spec/requests/list_controller_spec.rb spec/requests/topics_controller_spec.rb spec/requests/posts_controller_spec.rb spec/requests/categories_controller_spec.rb spec/requests/tags_controller_spec.rb spec/requests/search_controller_spec.rb --seed 1234 --format documentation`
* Ruby: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux]
* Rails: 8.2.0.alpha, test environment
* Counted in run 1: 3021 requests; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1
* Not attributed: 0.0 objects per request (0.0% of all) are on lines outside the app, Rails, Ruby and the bundle's gems, which no table below ranks; most in `discourse_plugin_outlet__ApplicationHelper`, `(eval at /home/user/workspace/repo/.corpus/hl-discourse/lib/middleware/anonymous_cache.rb:41)`

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 3021 | 8314.2 | 0 | 0 | 0 | 0 |
| run2 | 1 | 3021 | 8314.4 | 0 | 0 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.36 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `lib/http_language_parser.rb:10` | `parse` | 262.39 | 0.0 | 0.0 | `GEM/http_accept_language/lib/http_accept_language/parser.rb:81` 97%, `GEM/http_accept_language/lib/http_accept_language/parser.rb:19` 1%, `GEM/http_accept_language/lib/http_accept_language/parser.rb:31` 1% | SessionController#become 44%, TopicsController#show 13%, ListController#latest 5% | `matched = parser.language_region_compatible_from(available_locales)&.t` |
| 2 | `lib/topic_query.rb:568` | `prioritize_pinned_topics` | 146.07 | 0.0 | 0.1 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 21%, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:190` 20%, `RAILS/activerecord/lib/arel/table.rb:105` 11% | ListController#filter 22%, ListController#latest 21%, ListController#category_default 15% | `(pinned_topics + unpinned_topics)[0...limit] if limit` |
| 3 | `app/models/web_hook.rb:92` | `enqueue_object_hooks` | 124.84 | 0.0 | 0.0 | `RAILS/activerecord/lib/arel/visitors/to_sql.rb:825` 4%, `RAILS/activerecord/lib/arel/table.rb:105` 3%, `RAILS/activerecord/lib/arel/nodes/select_statement.rb:11` 3% | SessionController#become 94%, CategoriesController#update 2%, PostsController#create 1% | `if active_web_hooks(event).exists?` |
| 4 | `app/models/user_auth_token.rb:112` | `generate!` | 117.11 | 0.0 | 0.36 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:173` 5%, `GEM/erb/lib/erb/util.rb:65` 5%, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 5% | SessionController#become 100% | `UserAuthToken.create!(` |
| 5 | `lib/mini_sql_multisite_connection.rb:21` | `encode` | 94.23 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/sanitization.rb:269` 27%, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/quoting.rb:106` 16%, `RAILS/activerecord/lib/active_record/sanitization.rb:270` 13% | SessionController#become 19%, TopicsController#show 16%, PostsController#create 13% | `ActiveRecord::Base.public_send(:sanitize_sql_array, sql_array)` |
| 6 | `app/models/user_auth_token.rb:55` | `log` | 93.72 | 0.0 | 0.0 | `GEM/erb/lib/erb/util.rb:65` 7%, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 6%, `RAILS/activemodel/lib/active_model/attribute_set.rb:607` 3% | SessionController#become 100% | `UserAuthTokenLog.create!(info)` |
| 7 | `lib/suggested_topics_builder.rb:26` | `add_results` | 86.62 | 0.0 | 0.0 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 16%, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:190` 15%, `RAILS/activerecord/lib/arel/table.rb:105` 9% | TopicsController#show 99%, TopicsController#posts 1%, NestedTopicsController#show 0% | `results = results.to_a` |
| 8 | `lib/topic_query.rb:591` | `create_list` | 86.39 | 0.0 | 0.0 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 22%, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:190` 20%, `RAILS/activerecord/lib/arel/table.rb:105` 12% | TopicsController#show 34%, ListController#latest 12%, ListController#top_feed 6% | `topics = topics.to_a` |
| 9 | `app/models/user_auth_token.rb:36` | `user` | 80.41 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:22` 9%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:256` 8%, `GEM/erb/lib/erb/util.rb:65` 5% | SessionController#become 52%, TopicsController#show 4%, PostsController#create 4% | `impersonated_user \|\| acting_user` |
| 10 | `app/models/user.rb:1113` | `create_visit_record!` | 76.65 | 0.0 | 0.33 | `GEM/erb/lib/erb/util.rb:65` 8%, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 6%, `RAILS/activemodel/lib/active_model/attribute.rb:10` 3% | TopicsController#show 9%, PostsController#create 8%, TopicsController#update 6% | `user_visits.create!(` |
| 11 | `lib/stylesheet/manager.rb:264` | `load_themes` | 76.2 | 0.0 | 0.0 | `GEM/erb/lib/erb/util.rb:65` 3%, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 3%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:32` 3% | TopicsController#show 49%, ListController#latest 17%, ListController#category_default 9% | `.each do \|theme\|` |
| 12 | `lib/topic_query.rb:767` | `apply_ordering` | 72.12 | 0.0 | 0.0 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 27%, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:190` 25%, `RAILS/activerecord/lib/arel/table.rb:105` 14% | TopicsController#show 52%, ListController#filter 18%, ListController#category_default 13% | `return new_result if !new_result.nil? && new_result != result` |
| 13 | `lib/freedom_patches/ams_include_without_root.rb:57` | `include!` | 64.95 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:256` 9%, `GEM/active_model_serializers/lib/active_model/serializer/associations.rb:75` 3%, `RAILS/activerecord/lib/active_record/associations.rb:62` 3% | TopicsController#show 53%, ListController#latest 12%, ListController#category_default 9% | `node[association.key] = association.serialize` |
| 14 | `lib/i18n/backend/discourse_i18n.rb:25` | `load_translations` | 60.26 | 0.0 | 0.01 | `GEM/bootsnap/lib/bootsnap/compile_cache/yaml.rb:222` 96%, `GEM/i18n/lib/i18n/backend/base.rb:241` 1%, `GEM/i18n/lib/i18n/utils.rb:19` 1% | TopicsController#show 100%, PostsController#latest 0% | `self.class.sort_locale_files(filenames.flatten).each { \|filename\| load` |
| 15 | `lib/freedom_patches/translate_accelerator.rb:140` | `translate_no_override` | 56.38 | 0.0 | 4.8 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:90` 17%, `GEM/i18n/lib/i18n/backend/fallbacks.rb:46` 17%, `GEM/i18n/lib/i18n/backend/fallbacks.rb:52` 13% | TopicsController#show 51%, CategoriesController#destroy 21%, ListController#latest 7% | `return translate_no_cache(key, **options) if dup_options.present?` |
| 16 | `app/models/user.rb:1118` | `create_visit_record!` | 56.36 | 0.0 | 0.0 | `GEM/erb/lib/erb/util.rb:65` 7%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:22` 6%, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 6% | TopicsController#show 9%, PostsController#create 8%, TopicsController#update 6% | `user_stat.update_column(:days_visited, user_stat.days_visited + 1)` |
| 17 | `lib/topic_view.rb:1093` | `find_topic` | 52.64 | 0.0 | 0.19 | `RAILS/activerecord/lib/arel/table.rb:105` 9%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:256` 4%, `GEM/erb/lib/erb/util.rb:65` 3% | TopicsController#show 78%, TopicsController#update 11%, TopicsController#posts 5% | `.find_by(id: topic_or_topic_id)` |
| 18 | `app/models/concerns/roleable.rb:90` | `auto_approve_user` | 51.19 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/callbacks.rb:399` 28%, `RAILS/activemodel/lib/active_model/attribute.rb:10` 7%, `GEM/erb/lib/erb/util.rb:65` 4% | SessionController#become 100% | `save!` |
| 19 | `app/services/word_watcher.rb:34` | `words_for_action` | 51.07 | 0.0 | 0.71 | `RAILS/activerecord/lib/active_record/relation/calculations.rb:633` 11%, `GEM/erb/lib/erb/util.rb:65` 7%, `RAILS/activerecord/lib/arel/table.rb:105` 6% | PostsController#create 43%, PostsController#update 14%, TopicsController#show 11% | `.pluck(:word, :replacement, :case_sensitive, :html)` |
| 20 | `lib/topic_view.rb:177` | `initialize` | 50.46 | 0.0 | 0.07 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:256` 5%, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:77` 3%, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:28` 3% | TopicsController#show 68%, TopicsController#update 13%, TopicsController#posts 6% | `@post_custom_fields = Post.custom_fields_for_ids(@posts.map(&:id), all` |
| 21 | `app/models/user_auth_token.rb:156` | `lookup` | 49.49 | 0.0 | 0.0 | `RAILS/activerecord/lib/arel/visitors/to_sql.rb:836` 7%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:256` 7%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/quoting.rb:129` 4% | TopicsController#show 8%, PostsController#create 8%, TopicsController#update 5% | `user_token = user_token.first` |
| 22 | `app/models/topic_list.rb:164` | `load_topics` | 47.98 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:28` 5%, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:77` 5%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:146` 4% | TopicsController#show 37%, ListController#latest 12%, ListController#filter 12% | `).call` |
| 23 | `lib/discourse_redis.rb:145` | `method_missing` | 47.62 | 0.0 | 0.38 | `GEM/redis-client/lib/redis_client/ruby_connection/resp3.rb:54` 29%, `GEM/redis-client/lib/redis_client/ruby_connection/resp3.rb:99` 24%, `GEM/redis-client/lib/redis_client/command_builder.rb:9` 10% | SessionController#become 21%, TopicsController#show 20%, PostsController#create 8% | `DiscourseRedis.ignore_readonly { @redis.public_send(m, *args, **kwargs` |
| 24 | `app/models/concerns/roleable.rb:61` | `save_and_refresh_staff_groups!` | 46.0 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/callbacks.rb:399` 32%, `RAILS/activemodel/lib/active_model/attribute.rb:10` 15%, `GEM/erb/lib/erb/util.rb:65` 2% | SessionController#become 100% | `save!` |
| 25 | `app/models/site.rb:132` | `all_categories_cache` | 44.15 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:256` 5%, `RAILS/activerecord/lib/active_record/associations.rb:62` 3%, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:77` 2% | TopicsController#show 63%, ListController#latest 10%, ListController#category_default 10% | `query.to_a` |
| 26 | `lib/theme_resolver.rb:14` | `resolve_theme_id` | 42.54 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:22` 9%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:256` 6%, `GEM/erb/lib/erb/util.rb:65` 5% | PostsController#create 9%, TopicsController#show 8%, TopicsController#update 5% | `user_option = current_user&.user_option` |
| 27 | `app/models/user.rb:1123` | `visit_record_for` | 41.2 | 0.0 | 0.66 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:22` 8%, `GEM/erb/lib/erb/util.rb:65` 5%, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 4% | TopicsController#show 9%, PostsController#create 7%, TopicsController#update 6% | `user_visits.find_by(visited_at: date)` |
| 28 | `app/models/group.rb:641` | `refresh_automatic_group!` | 39.79 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:10` 44%, `RAILS/activesupport/lib/active_support/callbacks.rb:399` 32%, `RAILS/activemodel/lib/active_model/type/string.rb:40` 4% | SessionController#become 100% | `group.save!` |
| 29 | `app/models/user_auth_token.rb:195` | `lookup` | 39.11 | 0.0 | 0.33 | `RAILS/activerecord/lib/arel/table.rb:105` 5%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:173` 5%, `GEM/erb/lib/erb/util.rb:65` 5% | TopicsController#show 9%, PostsController#create 8%, TopicsController#update 6% | `UserAuthToken.where(id: user_token.id, auth_token: token).update_all(` |
| 30 | `lib/discourse_tagging.rb:745` | `visible_tags` | 37.42 | 0.0 | 0.0 | `RAILS/activerecord/lib/arel/table.rb:105` 5%, `RAILS/activerecord/lib/arel/nodes/select_statement.rb:11` 4%, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:242` 4% | TopicsController#show 26%, TagsController#search 10%, ListController#latest 8% | `Tag.where(` |

App middleware that hands the request on (the stack below it, not its own work): `lib/middleware/omniauth_bypass_middleware.rb:35` 129.5, `lib/middleware/default_headers.rb:13` 36.07, `lib/middleware/request_tracker.rb:384` 31.26, `lib/content_security_policy/middleware.rb:12` 14.58, `lib/middleware/enforce_hostname.rb:23` 9.48, `lib/middleware/overload_protections.rb:18` 1.9, `config/initializers/200-first_middlewares.rb:34` 0.0 warm objects per request.

3.11 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | CategoriesController#destroy | 3 / 3 | 88908.0 / 88823.0 | -85.0 | 59959.7 | `GEM/i18n/lib/i18n.rb:447` 5799.0, `GEM/i18n/lib/i18n/backend/fallbacks.rb:46` 2581.0, `GEM/i18n/lib/i18n/backend/fallbacks.rb:90` 2543.0 | `lib/freedom_patches/translate_accelerator.rb:140` 17654.0, `lib/i18n/backend/discourse_i18n.rb:80` 9208.0, `app/models/concerns/has_destroyed_web_hook.rb:16` 1557.5 |
| 2 | ListController#read | 2 / 2 | 28048.0 / 28050.0 | 2.0 | 18911.5 | `GEM/erb/lib/erb/util.rb:65` 595.0, `RAILS/activerecord/lib/arel/table.rb:105` 567.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:256` 566.0 | `lib/freedom_patches/ams_include_without_root.rb:57` 1403.0, `lib/topic_query.rb:591` 1237.0, `app/models/site.rb:132` 960.0 |
| 3 | ReviewablesController#perform | 2 / 2 | 21478.0 / 21488.0 | 10.0 | 12890.0 | `RAILS/activerecord/lib/arel/table.rb:105` 687.0, `GEM/erb/lib/erb/util.rb:65` 558.0, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 465.0 | `app/controllers/reviewables_controller.rb:365` 2510.0, `lib/mini_sql_multisite_connection.rb:21` 534.0, `lib/post_creator.rb:635` 516.0 |
| 4 | ListController#latest | 62 / 62 | 20305.8 / 20309.3 | 3.5 | 20343.6 | `GEM/psych/lib/psych/parser.rb:62` 1048.6, `GEM/psych/lib/psych/tree_builder.rb:97` 1040.5, `GEM/http_accept_language/lib/http_accept_language/parser.rb:81` 611.3 | `lib/js_locale_helper.rb:40` 1636.7, `lib/topic_query.rb:568` 1548.2, `lib/js_locale_helper.rb:23` 1076.6 |
| 5 | TopicsController#status | 27 / 27 | 17658.5 / 17660.5 | 2.0 | 17092.5 | `RAILS/activerecord/lib/arel/table.rb:105` 333.0, `GEM/erb/lib/erb/util.rb:65` 256.2, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 213.5 | `lib/post_creator.rb:615` 260.8, `lib/guardian/topic_guardian.rb:260` 207.5, `app/models/user.rb:1113` 178.8 |
| 6 | TopicsController#show | 273 / 273 | 17524.1 / 17524.7 | 0.6 | 17490.3 | `GEM/bootsnap/lib/bootsnap/compile_cache/yaml.rb:222` 643.8, `RAILS/activerecord/lib/arel/table.rb:105` 494.3, `GEM/http_accept_language/lib/http_accept_language/parser.rb:81` 355.5 | `lib/suggested_topics_builder.rb:26` 954.9, `lib/i18n/backend/discourse_i18n.rb:25` 669.2, `lib/topic_view.rb:1093` 458.3 |
| 7 | ListController#hot | 2 / 2 | 16699.0 / 16704.0 | 5.0 | 18724.5 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 660.0, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:190` 620.0, `RAILS/activerecord/lib/arel/table.rb:105` 491.0 | `lib/topic_query.rb:568` 2459.0, `lib/freedom_patches/ams_include_without_root.rb:57` 1391.0, `lib/stylesheet/manager.rb:264` 792.0 |
| 8 | ListController#new | 4 / 4 | 16512.0 / 16515.7 | 3.7 | 15084.5 | `RAILS/activerecord/lib/arel/table.rb:105` 397.7, `RAILS/activerecord/lib/arel/alias_predication.rb:8` 330.0, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:190` 310.0 | `lib/topic_query.rb:591` 2202.3, `app/models/topic_list.rb:164` 563.7, `app/models/user.rb:1627` 515.0 |
| 9 | TopicsController#merge_topic | 14 / 14 | 16469.2 / 16469.6 | 0.4 | 15458.4 | `RAILS/activerecord/lib/arel/table.rb:105` 710.2, `GEM/erb/lib/erb/util.rb:65` 499.4, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 416.2 | `lib/mini_sql_multisite_connection.rb:21` 943.8, `lib/post_creator.rb:615` 477.2, `lib/guardian/topic_guardian.rb:260` 447.5 |
| 10 | TagsController#show | 30 / 30 | 14915.1 / 14919.4 | 4.3 | 14483.1 | `GEM/http_accept_language/lib/http_accept_language/parser.rb:81` 455.2, `RAILS/activerecord/lib/arel/alias_predication.rb:8` 444.8, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:190` 416.9 | `lib/topic_query.rb:568` 1755.0, `lib/http_language_parser.rb:10` 470.3, `lib/freedom_patches/ams_include_without_root.rb:57` 301.4 |
| 11 | PostsController#create | 106 / 106 | 14222.5 / 14222.0 | -0.5 | 14282.8 | `RAILS/activerecord/lib/arel/table.rb:105` 406.3, `GEM/erb/lib/erb/util.rb:65` 341.4, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 284.5 | `app/services/word_watcher.rb:34` 637.0, `lib/mini_sql_multisite_connection.rb:21` 364.0, `lib/post_creator.rb:615` 260.3 |
| 12 | ListController#category_latest | 16 / 16 | 14167.9 / 14166.6 | -1.3 | 13374.1 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 647.6, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:190` 599.3, `RAILS/activerecord/lib/arel/table.rb:105` 488.9 | `lib/topic_query.rb:568` 1619.3, `lib/stylesheet/manager.rb:264` 699.9, `lib/topic_query.rb:767` 652.3 |
| 13 | TopicsController#move_posts | 37 / 37 | 13643.6 / 13643.4 | -0.2 | 13339.5 | `RAILS/activerecord/lib/arel/table.rb:105` 538.7, `GEM/erb/lib/erb/util.rb:65` 397.2, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 331.0 | `lib/mini_sql_multisite_connection.rb:21` 850.1, `lib/guardian/topic_guardian.rb:260` 316.9, `lib/post_creator.rb:615` 300.0 |
| 14 | ListController#filter | 36 / 36 | 13288.6 / 13297.5 | 8.9 | 13474.3 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 867.4, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:190` 814.9, `RAILS/activerecord/lib/arel/table.rb:105` 624.6 | `lib/topic_query.rb:568` 2779.5, `lib/topic_query.rb:767` 1133.3, `app/models/topic_list.rb:164` 484.2 |
| 15 | ListController#top | 8 / 8 | 13019.0 / 13018.0 | -1.0 | 14726.5 | `GEM/http_accept_language/lib/http_accept_language/parser.rb:81` 424.3, `RAILS/activerecord/lib/arel/alias_predication.rb:8` 332.6, `RAILS/activerecord/lib/arel/table.rb:105` 318.6 | `lib/topic_query.rb:591` 1279.1, `lib/freedom_patches/ams_include_without_root.rb:57` 797.1, `lib/stylesheet/manager.rb:264` 626.4 |
| 16 | TopicsController#update_tags | 7 / 7 | 12012.5 / 12015.8 | 3.3 | 13233.7 | `RAILS/activerecord/lib/arel/table.rb:105` 346.8, `GEM/erb/lib/erb/util.rb:65` 315.0, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 262.5 | `lib/discourse_tagging.rb:815` 420.0, `lib/topic_view.rb:177` 395.0, `lib/topic_view.rb:1093` 371.5 |
| 17 | CategoriesController#categories_and_hot | 2 / 2 | 11817.0 / 11815.0 | -2.0 | 10658.5 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 666.0, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:190` 620.0, `RAILS/activerecord/lib/arel/table.rb:105` 602.0 | `lib/topic_query.rb:568` 3431.0, `app/models/user.rb:1627` 515.0, `app/models/topic_list.rb:164` 507.0 |
| 18 | ListController#category_default | 44 / 44 | 11381.7 / 11384.5 | 2.8 | 11352.1 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 598.3, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:190` 555.6, `RAILS/activerecord/lib/arel/table.rb:105` 421.8 | `lib/topic_query.rb:568` 1492.7, `lib/topic_query.rb:767` 661.8, `lib/stylesheet/manager.rb:264` 470.6 |
| 19 | TopicsController#make_banner | 2 / 2 | 11376.0 / 11374.0 | -2.0 | 7301.5 | `GEM/erb/lib/erb/util.rb:65` 366.0, `RAILS/activerecord/lib/arel/table.rb:105` 365.0, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 305.0 | `lib/post_creator.rb:615` 452.0, `app/models/topic.rb:1531` 380.0, `app/models/topic_user.rb:135` 301.0 |
| 20 | TopicsController#remove_banner | 2 / 2 | 10892.0 / 10884.0 | -8.0 | 7056.0 | `RAILS/activerecord/lib/arel/table.rb:105` 351.0, `GEM/erb/lib/erb/util.rb:65` 342.0, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 285.0 | `lib/post_creator.rb:615` 452.0, `app/models/topic.rb:1543` 380.0, `app/models/topic_user.rb:135` 301.0 |
| 21 | TopicsController#update | 62 / 62 | 10685.6 / 10687.3 | 1.7 | 10551.7 | `RAILS/activerecord/lib/arel/table.rb:105` 330.9, `GEM/erb/lib/erb/util.rb:65` 306.7, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 255.6 | `lib/topic_view.rb:177` 331.1, `lib/mini_sql_multisite_connection.rb:21` 306.6, `lib/topic_view.rb:1093` 296.1 |
| 22 | CategoriesController#create | 14 / 14 | 10419.9 / 10423.4 | 3.5 | 9836.0 | `RAILS/activerecord/lib/arel/table.rb:105` 282.5, `GEM/erb/lib/erb/util.rb:65` 215.1, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 179.2 | `lib/category_creator.rb:39` 492.7, `app/serializers/category_serializer.rb:79` 283.8, `app/models/category.rb:635` 239.1 |
| 23 | PostsController#update | 42 / 42 | 10314.6 / 10313.9 | -0.7 | 10139.0 | `GEM/erb/lib/erb/util.rb:65` 267.4, `RAILS/activerecord/lib/arel/table.rb:105` 236.2, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 222.8 | `app/services/word_watcher.rb:34` 533.5, `lib/mini_sql_multisite_connection.rb:21` 297.5, `lib/middleware/omniauth_bypass_middleware.rb:35` 222.2 |
| 24 | TagsController#show_new | 3 / 3 | 10231.0 / 10226.5 | -4.5 | 10376.3 | `RAILS/activerecord/lib/arel/table.rb:105` 346.0, `RAILS/activerecord/lib/arel/alias_predication.rb:8` 330.0, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:190` 310.0 | `lib/topic_query.rb:591` 2194.5, `app/models/topic_list.rb:164` 540.0, `app/models/user.rb:1627` 515.0 |
| 25 | PostsController#revert | 14 / 14 | 9751.3 / 9749.0 | -2.3 | 9217.0 | `GEM/erb/lib/erb/util.rb:65` 264.5, `RAILS/activerecord/lib/arel/table.rb:105` 261.5, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 220.4 | `lib/mini_sql_multisite_connection.rb:21` 280.2, `lib/discourse_tagging.rb:123` 255.0, `app/models/user.rb:1113` 232.3 |
| 26 | CategoriesController#update | 46 / 46 | 9746.0 / 9746.9 | 0.9 | 9733.5 | `RAILS/activerecord/lib/arel/table.rb:105` 402.0, `GEM/erb/lib/erb/util.rb:65` 255.5, `GEM/aws-sdk-s3/lib/aws-sdk-s3/client_api.rb:0` 227.4 | `lib/s3_helper.rb:464` 1141.0, `app/serializers/category_serializer.rb:79` 470.4, `lib/category_updater.rb:61` 448.8 |
| 27 | CategoriesController#categories_and_latest | 14 / 14 | 9562.2 / 9554.2 | -8.1 | 9790.0 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 615.2, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:190` 572.3, `RAILS/activerecord/lib/arel/table.rb:105` 509.5 | `lib/topic_query.rb:568` 2729.0, `app/models/topic_list.rb:164` 576.5, `app/models/category_list.rb:227` 482.7 |
| 28 | TagsController#show_latest | 15 / 15 | 9516.9 / 9515.5 | -1.4 | 33011.0 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 636.4, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:190` 597.9, `RAILS/activerecord/lib/arel/table.rb:105` 485.6 | `lib/topic_query.rb:568` 2374.0, `lib/topic_query.rb:767` 413.1, `lib/discourse_tagging.rb:745` 357.9 |
| 29 | PostsController#destroy_many | 11 / 11 | 9226.6 / 9230.8 | 4.2 | 9487.0 | `GEM/erb/lib/erb/util.rb:65` 306.0, `RAILS/activerecord/lib/arel/table.rb:105` 291.4, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 255.0 | `app/models/post_action.rb:235` 540.0, `lib/mini_sql_multisite_connection.rb:21` 209.8, `app/models/user.rb:1113` 208.8 |
| 30 | TopicsController#convert_topic | 8 / 8 | 9117.1 / 9121.1 | 4.0 | 8265.0 | `GEM/erb/lib/erb/util.rb:65` 273.4, `RAILS/activerecord/lib/arel/table.rb:105` 237.0, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 227.9 | `app/services/word_watcher.rb:34` 286.0, `lib/mini_sql_multisite_connection.rb:21` 272.6, `app/models/user.rb:1113` 232.6 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/http_accept_language/lib/http_accept_language/parser.rb:81` | `sanitize_available_locales` | 273.74 / 273.74 | 0.0 | 273.85 | 69% | String, Array |  | `lib/http_language_parser.rb:10` 100% | `available.to_s.split(/[_-]/).reject { \|part\| part.start_with?("x") }.j` |
| 2 | `RAILS/activerecord/lib/arel/table.rb:105` | `[]` | 191.44 / 191.44 | -0.0 | 191.46 | 97% | Struct |  | `lib/topic_query.rb:568` 9%, `lib/topic_query.rb:591` 6% | `Attribute.new(table, name)` |
| 3 | `GEM/erb/lib/erb/util.rb:65` | `url_encode` | 151.96 / 151.96 | -0.0 | 152.02 | 97% | String |  | `app/models/user_auth_token.rb:55` 4%, `app/models/user_auth_token.rb:112` 4% | `CGI.escapeURIComponent(s.to_s)` |
| 4 | `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` | `format` | 126.57 / 126.57 | -0.0 | 126.62 | 97% | String |  | `app/models/user_auth_token.rb:55` 4%, `app/models/user_auth_token.rb:112` 4% | `"#{key}='#{ERB::Util.url_encode(value)}'"` |
| 5 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:256` | `cast_result` | 111.87 / 111.85 | -0.02 | 111.89 | 97% | Array, String |  | `app/models/user_auth_token.rb:36` 6%, `lib/freedom_patches/ams_include_without_root.rb:57` 5% | `ActiveRecord::Result.new(fields, result.values, types.freeze, affected` |
| 6 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` | `as` | 97.56 / 97.56 | 0.0 | 97.79 | 23% | String, Object |  | `lib/topic_query.rb:568` 34%, `lib/topic_query.rb:591` 21% | `Nodes::As.new self, Nodes::SqlLiteral.new(other, retryable: true)` |
| 7 | `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:190` | `aliases` | 90.17 / 90.17 | 0.0 | 90.38 | 19% | String, Struct |  | `lib/topic_query.rb:568` 34%, `lib/topic_query.rb:591` 21% | `Aliases::Column.new column_name, "t#{i}_r#{j}"` |
| 8 | `RAILS/activemodel/lib/active_model/attribute.rb:10` | `from_database` | 77.07 / 77.07 | -0.0 | 77.1 | 80% | Object |  | `app/models/group.rb:641` 23%, `app/models/concerns/roleable.rb:61` 9% | `FromDatabase.new(name, value_before_type_cast, type, nil, value)` |
| 9 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/quoting.rb:106` | `quote` | 68.77 / 68.77 | -0.0 | 68.78 | 96% | String |  | `lib/mini_sql_multisite_connection.rb:21` 23%, `app/helpers/application_helper.rb:730` 3% | `when Numeric then value.to_s` |
| 10 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:22` | `-` | 63.31 / 63.31 | 0.0 | 63.32 | 91% | Array, Object |  | `app/models/user_auth_token.rb:36` 12%, `lib/theme_resolver.rb:14` 6% | `WhereClause.new(predicates - other.predicates)` |
| 11 | `RAILS/activesupport/lib/active_support/callbacks.rb:399` | `make_lambda` | 62.63 / 62.63 | 0.0 | 62.64 | 72% | Array, Hash |  | `app/models/concerns/roleable.rb:90` 23%, `app/models/concerns/roleable.rb:61` 23% | `target.send(@method_name, &block)` |
| 12 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:146` | `create` | 59.57 / 59.57 | -0.0 | 59.58 | 97% | Object, Hash |  | `app/models/web_hook.rb:92` 5%, `app/models/user_auth_token.rb:36` 4% | `relation_class_for(model).new(model, ...)` |
| 13 | `RAILS/activerecord/lib/active_record/relation.rb:102` | `initialize_copy` | 58.23 / 58.23 | -0.0 | 58.24 | 97% | Hash |  | `app/models/concerns/trashable.rb:7` 5%, `app/models/user.rb:1627` 2% | `@values = @values.dup` |
| 14 | `GEM/bootsnap/lib/bootsnap/compile_cache/yaml.rb:222` | `storage_to_output` | 57.61 / 57.97 | 0.36 | 63.96 | 0% | String, Hash |  | `lib/i18n/backend/discourse_i18n.rb:25` 100% | `result = unpacker.unpack` |
| 15 | `RAILS/activerecord/lib/active_record/relation/spawn_methods.rb:10` † | `spawn` | 56.14 / 56.14 | -0.0 | 56.15 | 97% | Object |  | `app/models/concerns/trashable.rb:7` 6%, `app/models/user.rb:1627` 2% | `already_in_scope?(model.scope_registry) ? model.all : clone` |
| 16 | `RAILS/activerecord/lib/active_record/relation.rb:81` | `initialize` | 53.33 / 53.32 | -0.0 | 53.34 | 97% | Hash |  | `app/models/user_auth_token.rb:36` 4%, `app/models/topic_list.rb:164` 4% | `def initialize(model, table: nil, predicate_builder: nil, values: {})` |
| 17 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:146` | `expand_from_hash` | 53.13 / 53.13 | -0.0 | 53.15 | 96% | Array |  | `app/models/concerns/trashable.rb:7` 12%, `app/models/web_hook.rb:76` 3% | `attributes.flat_map do \|key, value\|` |
| 18 | `RAILS/activerecord/lib/arel/nodes/select_statement.rb:11` | `initialize` | 46.01 / 46.01 | -0.0 | 46.02 | 97% | Object, Array |  | `app/models/web_hook.rb:92` 9%, `app/services/word_watcher.rb:34` 3% | `@cores          = [SelectCore.new(relation)]` |
| 19 | `RAILS/activerecord/lib/arel/visitors/to_sql.rb:792` | `visit_Arel_Nodes_SqlLiteral` | 42.69 / 42.69 | 0.0 | 42.69 | 92% | String |  | `lib/topic_query.rb:568` 26%, `lib/topic_query.rb:591` 16% | `collector << o.to_s` |
| 20 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract_adapter.rb:1284` | `build_retry_budget` | 38.52 / 38.52 | -0.0 | 38.54 | 97% | Object |  | `lib/mini_sql_multisite_connection.rb:109` 7%, `app/models/user_auth_token.rb:55` 6% | `RetryBudget.new(` |
| 21 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:32` | `merge` | 36.42 / 36.42 | 0.0 | 36.43 | 93% | Array, Object |  | `app/models/user_auth_token.rb:36` 8%, `lib/stylesheet/manager.rb:264` 6% | `WhereClause.new(predicates \| other.predicates)` |
| 22 | `RAILS/activerecord/lib/active_record/relation/query_methods.rb:2043` | `build_where_clause` | 36.22 / 36.22 | -0.0 | 36.23 | 96% | Object |  | `app/models/concerns/trashable.rb:7` 9%, `app/models/web_hook.rb:92` 4% | `Relation::WhereClause.new(parts)` |
| 23 | `RAILS/activemodel/lib/active_model/type/string.rb:40` | `cast_value` | 34.79 / 34.79 | -0.01 | 34.79 | 94% | String |  | `lib/post_action_type_view.rb:26` 8%, `app/models/group.rb:641` 4% | `when ::String then ::String.new(value)` |
| 24 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:331` | `index_with` | 33.0 / 32.96 | -0.04 | 33.03 | 81% | Array, Hash |  | `app/models/user_auth_token.rb:112` 15%, `lib/topic_query.rb:568` 14% | `to_h { \|elem\| [elem, yield(elem)] } # rubocop:disable Rails/IndexWith` |
| 25 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:379` | `build_handle` | 32.15 / 32.15 | -0.0 | 32.16 | 100% | Object, Data |  | `lib/middleware/omniauth_bypass_middleware.rb:35` 7%, `app/models/user_auth_token.rb:55` 3% | `instances << group_klass.new(grouped_listeners, name, id, payload)` |
| 26 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:377` | `build_handle` | 31.96 / 31.95 | -0.0 | 31.97 | 100% | Array |  | `lib/middleware/omniauth_bypass_middleware.rb:35` 7%, `app/models/user_auth_token.rb:55` 3% | `instances = []` |
| 27 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:381` | `build_handle` | 31.96 / 31.95 | -0.0 | 31.97 | 100% | Object |  | `lib/middleware/omniauth_bypass_middleware.rb:35` 7%, `app/models/user_auth_token.rb:55` 3% | `Handle.new(name, id, instances, payload)` |
| 28 | `RAILS/activerecord/lib/arel/predications.rb:18` | `eq` | 31.51 / 31.51 | 0.0 | 31.51 | 96% | Object |  | `app/models/concerns/trashable.rb:7` 10%, `app/models/web_hook.rb:92` 4% | `Nodes::Equality.new self, quoted_node(other)` |
| 29 | `GEM/rack/lib/rack/request.rb:515` | `path` | 30.56 / 30.56 | -0.0 | 30.57 | 100% | String |  | `config/environments/test.rb:61` 83%, `lib/middleware/request_tracker.rb:201` 3% | `script_name + path_info` |
| 30 | `RAILS/activerecord/lib/active_record/scoping/default.rb:170` | `build_default_scope` | 28.41 / 28.41 | -0.0 | 28.42 | 97% | Data |  | `app/models/web_hook.rb:92` 5%, `lib/discourse_tagging.rb:743` 3% | `if !Base.is_a?(method(:default_scope).owner)` |

## Dev/test-mode work

99.1 of 6004.1 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | debug logging | `RAILS/actionpack/lib/action_controller/structured_event_subscriber.rb:59` | 52.56 | 16% | `lib/middleware/omniauth_bypass_middleware.rb:35` 99%, `app/controllers/topics_controller.rb:1025` 1% | `exception_backtrace = exception.backtrace&.first` |
| 2 | route build | `RAILS/actionpack/lib/action_dispatch/journey/gtg/transition_table.rb:80` | 12.05 | 99% | `lib/middleware/omniauth_bypass_middleware.rb:35` 99%, `lib/discourse.rb:727` 1% | `curr_slice = full_string.slice(slice_start, slice_length)` |
| 3 | route build | `RAILS/actionpack/lib/action_dispatch/journey/gtg/transition_table.rb:47` | 6.46 | 99% | `lib/middleware/omniauth_bypass_middleware.rb:35` 99%, `lib/discourse.rb:727` 1% | `next_states = []` |
| 4 | route build | `RAILS/actionpack/lib/action_dispatch/journey/gtg/simulator.rb:38` | 3.23 | 99% | `lib/middleware/omniauth_bypass_middleware.rb:35` 99%, `lib/discourse.rb:727` 1% | `token = string.byteslice(start_index, pos - start_index)` |
| 5 | debug logging | `GEM/lograge/lib/lograge/rails_ext/rack/logger.rb:21` | 2.0 | 100% | `config/initializers/100-quiet_logger.rb:20` 100% | `[status, headers, ::Rack::BodyProxy.new(body) {}] # rubocop:disable Li` |
| 6 | debug logging | `GEM/logger/lib/logger/log_device.rb:33` | 1.99 | 100% | `lib/discourse_logstash_logger.rb:122` 100% | `handle_write_errors("writing") {@dev.write(message)}` |
| 7 | debug logging | `RAILS/activesupport/lib/active_support/event_reporter.rb:398` | 1.99 | 100% | `lib/middleware/omniauth_bypass_middleware.rb:35` 100% | `event = { name: name }` |
| 8 | asset lookup | `GEM/propshaft/lib/propshaft/asset.rb:73` † | 1.72 | 9% | `lib/freedom_patches/propshaft_patches.rb:8` 94%, `lib/discourse.rb:590` 6% | `logical_path.sub(/\.(\w+(\.map)?)$/) { \|ext\| "-#{digest}#{ext}" }` |
| 9 | asset lookup | `GEM/propshaft/lib/propshaft/server.rb:16` | 1.27 | 100% | `lib/middleware/request_tracker.rb:384` 100% | `if (method == "GET" \|\| method == "HEAD") && path.start_with?(@assembly` |
| 10 | error page | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:204` | 1.04 | 0% | `lib/middleware/default_headers.rb:13` 100% | `add_filter(&Ractors.shareable_proc  { \|line\| line.sub(gems_regexp, gem` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activerecord | 3497.7 | 3501.3 | `table.rb:105` 191.4, `query_logs_formatter.rb:21` 126.6, `database_statements.rb:256` 111.9 |
| app | 1227.7 | 1365.9 | `upcoming_changes.rb:153` 140.2, `js_locale_helper.rb:141` 108.5, `http_language_parser.rb:8` 82.1 |
| rails: activesupport | 553.5 | 557.1 | `callbacks.rb:399` 62.6, `enumerable.rb:331` 33.0, `fanout.rb:379` 32.2 |
| gem: http_accept_language | 283.3 | 283.5 | `parser.rb:81` 273.7, `parser.rb:19` 4.1, `parser.rb:31` 1.7 |
| rails: activemodel | 282.9 | 284.1 | `attribute.rb:10` 77.1, `string.rb:40` 34.8, `attribute_set.rb:607` 19.6 |
| rails: actionpack | 248.0 | 362.0 | `structured_event_subscriber.rb:59` 52.6, `mime_type.rb:436` 16.0, `transition_table.rb:80` 12.0 |
| ruby default gem: erb | 152.0 | 152.1 | `util.rb:65` 152.0, `compiler.rb:97` 0.0, `compiler.rb:400` 0.0 |
| gem: rack | 139.5 | 140.1 | `request.rb:515` 30.6, `utils.rb:511` 25.4, `utils.rb:507` 10.9 |
| gem: nokogiri | 78.2 | 105.5 | `searchable.rb:270` 4.9, `xpath_visitor.rb:99` 4.2, `searchable.rb:238` 4.2 |
| gem: redis-client | 74.6 | 74.6 | `resp3.rb:99` 22.0, `resp3.rb:54` 20.1, `resp3.rb:69` 7.2 |
| gem: i18n | 74.5 | 75.0 | `fallbacks.rb:90` 10.2, `fallbacks.rb:46` 10.1, `fallbacks.rb:52` 7.7 |
| ruby default gem: psych | 67.4 | 100.1 | `tree_builder.rb:97` 22.7, `parser.rb:62` 22.4, `node.rb:33` 4.2 |
| gem: message_bus | 62.2 | 62.3 | `message.rb:31` 20.0, `message_bus.rb:367` 8.6, `distributed_cache.rb:132` 6.0 |
| gem: bootsnap | 60.3 | 67.0 | `yaml.rb:222` 57.8, `iseq.rb:98` 0.7, `yaml.rb:299` 0.2 |
| ruby default gem: uri | 58.7 | 59.2 | `common.rb:465` 20.2, `common.rb:456` 10.9, `common.rb:108` 3.5 |
| ruby stdlib | 56.8 | 57.3 | `ipaddr.rb:725` 17.8, `ipaddr.rb:672` 7.1, `formatter.rb:174` 7.0 |
| rails: actionview | 54.2 | 55.4 | `base.rb:317` 9.6, `lookup_context.rb:46` 4.6, `lookup_context.rb:49` 4.6 |
| gem: active_model_serializers | 29.7 | 30.1 | `serializer.rb:304` 5.1, `associations.rb:75` 5.0, `serializer.rb:467):2` 3.4 |
| gem: goldiloader | 29.2 | 29.2 | `auto_include_context.rb:10` 12.3, `auto_include_context.rb:14` 11.1, `auto_include_context.rb:43` 4.3 |
| gem: pg | 25.6 | 25.6 | `connection.rb:403` 25.6, `date.rb:14` 0.0, `result.rb:17` 0.0 |
| gem: tzinfo | 20.2 | 20.2 | `timestamp.rb:208` 8.1, `constant_offset_data_timezone_info.rb:52` 4.0, `timestamp.rb:193` 4.0 |
| gem: lograge | 20.2 | 20.2 | `logger.rb:21` 2.0, `method_and_path.rb:8` 2.0, `lograge.rb:74` 2.0 |
| gem: mini_sql | 13.7 | 13.7 | `connection.rb:217` 5.6, `connection.rb:64` 2.0, `builder.rb:112` 1.4 |
| gem: sidekiq | 13.2 | 13.5 | `sidekiq.rb:54` 6.2, `job.rb:381` 2.1, `job_util.rb:50` 0.7 |
| gem: rails_multisite | 12.3 | 12.3 | `connection_management.rb:23` 6.2, `connection_specification.rb:8` 6.2 |
| gem: json | 11.2 | 11.2 | `common.rb:967` 5.9, `common.rb:1130` 2.3, `common.rb:1124` 2.3 |
| gem: redis | 8.8 | 8.8 | `strings.rb:191` 3.9, `keys.rb:283` 1.1, `scripting.rb:110` 0.9 |
| gem: logstash-event | 8.1 | 8.2 | `event.rb:57` 3.0, `event.rb:55` 2.0, `event.rb:49` 1.0 |
| gem: mocha | 7.8 | 8.2 | `parameters_matcher.rb:37` 1.4, `expectation_list.rb:55` 1.2, `invocation.rb:45` 0.7 |
| gem: propshaft | 6.2 | 10.7 | `asset.rb:73` 1.7, `server.rb:16` 1.3, `server.rb:13` 1.0 |
| gem: ostruct | 5.2 | 5.2 | `ostruct.rb:238` 1.3, `ostruct.rb:237` 1.3, `ostruct.rb:248` 0.9 |
| gem: connection_pool | 4.9 | 4.9 | `connection_pool.rb:110` 1.4, `connection_pool.rb:113` 1.4, `timed_stack.rb:38` 0.7 |
| gem: base64 | 4.8 | 4.8 | `base64.rb:283` 2.8, `base64.rb:310` 1.7, `base64.rb:223` 0.3 |
| gem: multi_json | 4.5 | 4.5 | `oj.rb:67` 2.4, `legacy_constant.rb:34` 1.4, `multi_json.rb:214` 0.7 |
| gem: addressable | 4.0 | 4.5 | `uri.rb:431` 1.4, `uri.rb:428` 1.3, `uri.rb:486` 0.2 |
| ruby default gem: securerandom | 3.8 | 3.8 | `securerandom.rb:71` 3.8 |
| rails: railties | 3.5 | 4.0 | `logger.rb:29` 1.0, `logger.rb:21` 1.0, `engine.rb:852` 1.0 |
| gem: loofah | 3.5 | 3.5 | `concerns.rb:172` 1.2, `scrubber.rb:128` 1.0, `concerns.rb:43` 0.5 |
| ruby default gem: digest | 3.0 | 3.0 | `digest.rb:56` 3.0, `digest.rb:64` 0.0, `digest.rb:49` 0.0 |
| gem: logger | 3.0 | 3.0 | `log_device.rb:33` 2.0, `logger.rb:739` 1.0, `logger.rb:608` 0.0 |
| gem: logster | 2.1 | 2.1 | `message.rb:198` 0.4, `message.rb:190` 0.4, `message.rb:191` 0.4 |
| gem: sanitize | 1.8 | 2.0 | `sanitize.rb:204` 0.9, `sanitize.rb:207` 0.3, `config.rb:44` 0.1 |
| gem: mail | 1.5 | 3.2 | `8bit.rb:14` 0.2, `utilities.rb:215` 0.1, `address_lists_parser.rb:32009` 0.1 |
| test harness: webmock | 1.5 | 1.9 | `headers.rb:69` 0.4, `headers.rb:68` 0.3, `headers.rb:16` 0.1 |
| gem: erubi | 1.4 | 2.2 | `erubi.rb:134` 0.8, `erubi.rb:137` 0.2, `erubi.rb:139` 0.1 |
| gem: concurrent-ruby | 1.2 | 1.3 | `non_concurrent_map_backend.rb:26` 0.9, `locals.rb:66` 0.1, `mri_map_backend.rb:14` 0.1 |
| gem: mustache | 1.2 | 2.3 | `parser.rb:271` 0.2, `template.rb:41` 0.2, `parser.rb:198` 0.1 |
| gem: aws-sdk-core | 0.8 | 8.0 | `handler_list_entry.rb:33` 0.1, `handler_list_entry.rb:73` 0.1, `configuration.rb:159` 0.0 |
| ruby default gem: openssl | 0.7 | 0.7 | `cipher.rb:56` 0.7, `hmac.rb:36` 0.0, `hmac.rb:38` 0.0 |
| gem: fastimage | 0.7 | 0.7 | `type_parser.rb:16` 0.1, `type_parser.rb:14` 0.1, `png.rb:4` 0.1 |
| gem: racc | 0.6 | 0.6 | `parser.rb:263` 0.6 |
| gem: zeitwerk | 0.4 | 0.4 | `cref.rb:47` 0.1, `constant_path_validator.rb:13` 0.1, `file_system.rb:203` 0.1 |
| ruby default gem: net-http | 0.3 | 0.4 | `http.rb:1062` 0.1, `header.rb:203` 0.1, `http.rb:1061` 0.0 |
| gem: rails-html-sanitizer | 0.3 | 0.3 | `scrubbers.rb:59` 0.0, `scrubbers.rb:55` 0.0, `scrubbers.rb:63` 0.0 |
| gem: mini_mime | 0.3 | 0.3 | `mini_mime.rb:54` 0.2, `mini_mime.rb:56` 0.1, `mini_mime.rb:125` 0.0 |
| gem: lru_redux | 0.2 | 0.2 | `cache.rb:63` 0.1, `cache.rb:34` 0.1, `cache.rb:62` 0.0 |
| gem: csv | 0.2 | 0.2 | `parser.rb:1003` 0.0, `parser.rb:62` 0.0, `parser.rb:988` 0.0 |
| gem: htmlentities | 0.1 | 0.1 | `decoder.rb:10` 0.0, `decoder.rb:25` 0.0, `decoder.rb:35` 0.0 |
| gem: aws-sigv4 | 0.1 | 0.2 | `signer.rb:611` 0.0, `signer.rb:633` 0.0, `signer.rb:140` 0.0 |
| gem: excon | 0.1 | 0.1 | `connection.rb:248` 0.0, `connection.rb:303` 0.0, `connection.rb:469` 0.0 |
| gem: crass | 0.1 | 0.1 | `scanner.rb:97` 0.0, `tokenizer.rb:642` 0.0, `tokenizer.rb:301` 0.0 |
| gem: aws-sdk-s3 | 0.0 | 9.5 | `endpoint_provider.rb:490` 0.0, `endpoint_provider.rb:877` 0.0, `endpoint_parameters.rb:169` 0.0 |
| gem: messageformat-wrapper | 0.0 | 0.1 | `messageformat.rb:25` 0.0, `messageformat.rb:38` 0.0, `messageformat.rb:34` 0.0 |
| gem: mini_racer | 0.0 | 0.0 | `mini_racer.rb:101` 0.0 |
| gem: certified | 0.0 | 0.0 | `certified.rb:7` 0.0 |
| rails: actionmailer | 0.0 | 0.0 | `base.rb:642` 0.0, `base.rb:963` 0.0, `delivery_methods.rb:69` 0.0 |
| gem: dry-initializer | 0.0 | 0.1 | `wrap_type.rb:29` 0.0, `root.rb:11` 0.0, `config.rb:52` 0.0 |
| other | 0.0 | 0.0 | `discourse_plugin_outlet__ApplicationHelper:1` 0.0, `anonymous_cache.rb:41):2` 0.0 |
| gem: mini_suffix | 0.0 | 0.0 | `mini_suffix.rb:26` 0.0 |
| ruby default gem: bundler | 0.0 | 0.0 | `rubygems_integration.rb:192` 0.0 |
| gem: test-prof | 0.0 | 0.0 | `let_it_be.rb:131` 0.0, `active_record_refind.rb:15` 0.0, `let_it_be.rb:65` 0.0 |
| lowrail-profile | 0.0 | 0.0 | `profile.rb:115` 0.0, `profile.rb:66` 0.0, `profile.rb:56` 0.0 |
| gem: discourse-fonts | 0.0 | 0.0 | `discourse_fonts.rb:7` 0.0 |
| gem: mini_scheduler | 0.0 | 0.0 | `web.rb:0` 0.0, `web.rb:4` 0.0, `web.rb:21` 0.0 |
| gem: bigdecimal | 0.0 | 0.0 | `util.rb:51` 0.0, `util.rb:24` 0.0 |
| gem: msgpack | 0.0 | 0.0 | `factory.rb:14` 0.0, `factory.rb:125` 0.0, `factory.rb:16` 0.0 |
| gem: aws-partitions | 0.0 | 0.1 | `metadata.rb:27` 0.0, `metadata.rb:26` 0.0 |
| gem: maxminddb | 0.0 | 0.0 | `reader.rb:10` 0.0, `maxminddb.rb:17` 0.0, `reader.rb:9` 0.0 |
| gem: request_store | 0.0 | 0.0 | `request_store.rb:7` 0.0 |
| test harness: rspec-expectations | 0.0 | 0.0 | `expectation_target.rb:45` 0.0, `matchers.rb:559` 0.0 |
| gem: discourse-emojis | 0.0 | 0.0 | `discourse_emojis.rb:8` 0.0, `discourse_emojis.rb:21` 0.0, `discourse_emojis.rb:28` 0.0 |
