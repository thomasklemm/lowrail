# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bundle exec rspec spec/requests/list_controller_spec.rb spec/requests/topics_controller_spec.rb spec/requests/posts_controller_spec.rb spec/requests/categories_controller_spec.rb spec/requests/tags_controller_spec.rb spec/requests/search_controller_spec.rb --seed 1234 --format documentation`
* Ruby: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux]
* Rails: 8.1.4, test environment
* Counted in run 1: 3021 requests; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1
* Not attributed: 0.0 objects per request (0.0% of all) are on lines outside the app, Rails, Ruby and the bundle's gems, which no table below ranks; most in `discourse_plugin_outlet__ApplicationHelper`, `(eval at /home/user/workspace/repo/.corpus/hl-discourse/lib/middleware/anonymous_cache.rb:41)`

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 3021 | 9796.1 | 0 | 0 | 0 | 0 |
| run2 | 1 | 3021 | 9795.0 | 0 | 0 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.01 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `lib/http_language_parser.rb:10` | `parse` | 262.39 | 0.0 | 0.0 | `GEM/http_accept_language/lib/http_accept_language/parser.rb:81` 97%, `GEM/http_accept_language/lib/http_accept_language/parser.rb:19` 1%, `GEM/http_accept_language/lib/http_accept_language/parser.rb:31` 1% | SessionController#become 44%, TopicsController#show 13%, ListController#latest 5% | `matched = parser.language_region_compatible_from(available_locales)&.t` |
| 2 | `app/models/web_hook.rb:92` | `enqueue_object_hooks` | 155.19 | 0.0 | 0.0 | `RAILS/activerecord/lib/arel/visitors/to_sql.rb:790` 7%, `RAILS/activerecord/lib/active_record/reflection.rb:214` 3%, `RAILS/activerecord/lib/arel/nodes/select_statement.rb:11` 3% | SessionController#become 94%, CategoriesController#update 2%, PostsController#create 1% | `if active_web_hooks(event).exists?` |
| 3 | `lib/topic_query.rb:568` | `prioritize_pinned_topics` | 143.22 | 0.0 | 0.1 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 22%, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:177` 20%, `RAILS/activerecord/lib/arel/table.rb:85` 11% | ListController#filter 22%, ListController#latest 21%, ListController#category_default 15% | `(pinned_topics + unpinned_topics)[0...limit] if limit` |
| 4 | `app/models/user_auth_token.rb:36` | `user` | 134.6 | 0.13 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 20%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 5%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 4% | SessionController#become 52%, TopicsController#show 4%, PostsController#create 4% | `impersonated_user \|\| acting_user` |
| 5 | `app/models/user_auth_token.rb:112` | `generate!` | 95.39 | 0.0 | 0.36 | `GEM/erb/lib/erb/util.rb:65` 7%, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 6%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 5% | SessionController#become 100% | `UserAuthToken.create!(` |
| 6 | `lib/mini_sql_multisite_connection.rb:21` | `encode` | 92.45 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/sanitization.rb:222` 28%, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/quoting.rb:81` 17%, `RAILS/activerecord/lib/active_record/sanitization.rb:223` 13% | SessionController#become 19%, TopicsController#show 16%, PostsController#create 13% | `ActiveRecord::Base.public_send(:sanitize_sql_array, sql_array)` |
| 7 | `lib/stylesheet/manager.rb:264` | `load_themes` | 91.22 | 1.56 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 5%, `GEM/erb/lib/erb/util.rb:65` 3%, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 2% | TopicsController#show 50%, ListController#latest 17%, ListController#category_default 8% | `.each do \|theme\|` |
| 8 | `lib/topic_query.rb:591` | `create_list` | 90.82 | 0.25 | 0.0 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 21%, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:177` 19%, `RAILS/activerecord/lib/arel/table.rb:85` 11% | TopicsController#show 35%, ListController#latest 13%, ListController#top_feed 5% | `topics = topics.to_a` |
| 9 | `app/models/user_auth_token.rb:55` | `log` | 85.19 | 0.0 | 0.0 | `GEM/erb/lib/erb/util.rb:65` 8%, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 6%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 4% | SessionController#become 100% | `UserAuthTokenLog.create!(info)` |
| 10 | `lib/theme_resolver.rb:14` | `resolve_theme_id` | 85.18 | 0.13 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 36%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 4%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 3% | PostsController#create 9%, TopicsController#show 8%, TopicsController#update 5% | `user_option = current_user&.user_option` |
| 11 | `app/models/user.rb:1113` | `create_visit_record!` | 79.91 | 0.45 | 0.33 | `GEM/erb/lib/erb/util.rb:65` 7%, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 3% | TopicsController#show 9%, PostsController#create 8%, TopicsController#update 6% | `user_visits.create!(` |
| 12 | `lib/suggested_topics_builder.rb:26` | `add_results` | 78.86 | 0.0 | 0.0 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 18%, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:177` 17%, `RAILS/activerecord/lib/arel/table.rb:85` 9% | TopicsController#show 99%, TopicsController#posts 1%, NestedTopicsController#show 0% | `results = results.to_a` |
| 13 | `lib/freedom_patches/ams_include_without_root.rb:57` | `include!` | 77.65 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 7%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 3%, `GEM/active_model_serializers/lib/active_model/serializer/associations.rb:75` 2% | TopicsController#show 53%, ListController#latest 12%, ListController#category_default 9% | `node[association.key] = association.serialize` |
| 14 | `app/models/user.rb:1118` | `create_visit_record!` | 77.18 | 0.21 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 10%, `GEM/erb/lib/erb/util.rb:65` 5%, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 4% | TopicsController#show 9%, PostsController#create 8%, TopicsController#update 6% | `user_stat.update_column(:days_visited, user_stat.days_visited + 1)` |
| 15 | `lib/topic_query.rb:767` | `apply_ordering` | 74.34 | 0.0 | 0.0 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 26%, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:177` 24%, `RAILS/activerecord/lib/arel/table.rb:85` 14% | TopicsController#show 52%, ListController#filter 18%, ListController#category_default 13% | `return new_result if !new_result.nil? && new_result != result` |
| 16 | `app/models/user_auth_token.rb:156` | `lookup` | 71.93 | 0.13 | 0.0 | `RAILS/activerecord/lib/arel/visitors/to_sql.rb:801` 9%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 7%, `RAILS/activerecord/lib/arel/visitors/to_sql.rb:790` 6% | TopicsController#show 8%, PostsController#create 8%, TopicsController#update 5% | `user_token = user_token.first` |
| 17 | `lib/topic_view.rb:1093` | `find_topic` | 68.36 | 0.0 | 0.19 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 14%, `RAILS/activerecord/lib/arel/table.rb:85` 7%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 3% | TopicsController#show 78%, TopicsController#update 11%, TopicsController#posts 5% | `.find_by(id: topic_or_topic_id)` |
| 18 | `lib/topic_view.rb:177` | `initialize` | 60.9 | 0.0 | 0.07 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 10%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 4%, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:77` 2% | TopicsController#show 68%, TopicsController#update 13%, TopicsController#posts 6% | `@post_custom_fields = Post.custom_fields_for_ids(@posts.map(&:id), all` |
| 19 | `lib/i18n/backend/discourse_i18n.rb:25` | `load_translations` | 59.9 | 0.0 | 0.01 | `GEM/bootsnap/lib/bootsnap/compile_cache/yaml.rb:222` 96%, `GEM/i18n/lib/i18n/backend/base.rb:241` 1%, `GEM/i18n/lib/i18n/utils.rb:19` 1% | TopicsController#show 100%, PostsController#latest 0% | `self.class.sort_locale_files(filenames.flatten).each { \|filename\| load` |
| 20 | `app/models/concerns/roleable.rb:90` | `auto_approve_user` | 59.43 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/callbacks.rb:362` 25%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 13%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 6% | SessionController#become 100% | `save!` |
| 21 | `app/models/user.rb:1123` | `visit_record_for` | 57.69 | 0.13 | 0.66 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 3%, `GEM/erb/lib/erb/util.rb:65` 3% | TopicsController#show 9%, PostsController#create 7%, TopicsController#update 6% | `user_visits.find_by(visited_at: date)` |
| 22 | `app/models/concerns/roleable.rb:61` | `save_and_refresh_staff_groups!` | 57.49 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/callbacks.rb:362` 25%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 14%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 12% | SessionController#become 100% | `save!` |
| 23 | `lib/freedom_patches/translate_accelerator.rb:140` | `translate_no_override` | 56.4 | 0.0 | 4.8 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:90` 17%, `GEM/i18n/lib/i18n/backend/fallbacks.rb:46` 17%, `GEM/i18n/lib/i18n/backend/fallbacks.rb:52` 13% | TopicsController#show 51%, CategoriesController#destroy 21%, ListController#latest 7% | `return translate_no_cache(key, **options) if dup_options.present?` |
| 24 | `app/models/topic_list.rb:164` | `load_topics` | 55.92 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 8%, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:28` 4%, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:77` 4% | TopicsController#show 37%, ListController#latest 12%, ListController#filter 12% | `).call` |
| 25 | `app/services/word_watcher.rb:34` | `words_for_action` | 54.29 | 1.5 | 0.71 | `GEM/erb/lib/erb/util.rb:65` 6%, `RAILS/activerecord/lib/arel/table.rb:85` 5%, `RAILS/activerecord/lib/active_record/relation/calculations.rb:634` 5% | PostsController#create 43%, PostsController#update 14%, TopicsController#show 11% | `.pluck(:word, :replacement, :case_sensitive, :html)` |
| 26 | `app/models/group.rb:641` | `refresh_automatic_group!` | 52.62 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 33%, `RAILS/activesupport/lib/active_support/callbacks.rb:362` 24%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 19% | SessionController#become 100% | `group.save!` |
| 27 | `app/models/concerns/trashable.rb:7` |  | 52.33 | 0.0 | 6.16 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` 12%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 12%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:166` 12% | TopicsController#show 34%, PostsController#create 10%, TopicsController#move_posts 7% | `default_scope { where(deleted_at: nil) }` |
| 28 | `app/models/group.rb:805` | `lookup_group` | 51.7 | 0.0 | 0.97 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 37%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 7%, `GEM/erb/lib/erb/util.rb:65` 6% | SessionController#become 94%, CategoriesController#update 5%, CategoriesController#create 0% | `Group.find_by(id: id)` |
| 29 | `app/models/site.rb:132` | `all_categories_cache` | 50.1 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 6%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 4%, `RAILS/activerecord/lib/active_record/associations.rb:60` 2% | TopicsController#show 63%, ListController#latest 10%, ListController#category_default 10% | `query.to_a` |
| 30 | `lib/discourse_redis.rb:145` | `method_missing` | 47.67 | 0.0 | 0.38 | `GEM/redis-client/lib/redis_client/ruby_connection/resp3.rb:54` 29%, `GEM/redis-client/lib/redis_client/ruby_connection/resp3.rb:99` 24%, `GEM/redis-client/lib/redis_client/command_builder.rb:9` 10% | SessionController#become 21%, TopicsController#show 20%, PostsController#create 8% | `DiscourseRedis.ignore_readonly { @redis.public_send(m, *args, **kwargs` |

App middleware that hands the request on (the stack below it, not its own work): `lib/middleware/omniauth_bypass_middleware.rb:35` 142.76, `lib/middleware/request_tracker.rb:384` 78.92, `lib/middleware/default_headers.rb:13` 38.09, `lib/content_security_policy/middleware.rb:12` 14.37, `lib/middleware/enforce_hostname.rb:23` 10.43, `lib/middleware/overload_protections.rb:18` 2.85, `config/initializers/200-first_middlewares.rb:34` 0.0 warm objects per request.

3.92 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | CategoriesController#destroy | 3 / 3 | 93013.5 / 93017.5 | 4.0 | 62678.0 | `GEM/i18n/lib/i18n.rb:447` 5799.0, `GEM/i18n/lib/i18n/backend/fallbacks.rb:46` 2585.0, `GEM/i18n/lib/i18n/backend/fallbacks.rb:90` 2547.0 | `lib/freedom_patches/translate_accelerator.rb:140` 17682.0, `lib/i18n/backend/discourse_i18n.rb:80` 9212.0, `lib/freedom_patches/translate_accelerator.rb:193` 2614.0 |
| 2 | ListController#read | 2 / 2 | 32890.0 / 32894.0 | 4.0 | 21869.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 763.0, `GEM/erb/lib/erb/util.rb:65` 595.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 566.0 | `lib/freedom_patches/ams_include_without_root.rb:57` 1682.0, `lib/topic_query.rb:591` 1335.0, `app/models/site.rb:132` 1086.0 |
| 3 | ReviewablesController#perform | 2 / 2 | 24516.0 / 24509.0 | -7.0 | 15339.5 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 1058.0, `RAILS/activerecord/lib/arel/table.rb:85` 686.0, `GEM/erb/lib/erb/util.rb:65` 558.0 | `app/controllers/reviewables_controller.rb:365` 2534.0, `lib/post_creator.rb:635` 652.0, `lib/mini_sql_multisite_connection.rb:21` 529.0 |
| 4 | ListController#latest | 62 / 62 | 21991.3 / 21982.6 | -8.7 | 22037.2 | `RUBY/psych/parser.rb:62` 1048.6, `RUBY/psych/tree_builder.rb:97` 1040.5, `GEM/http_accept_language/lib/http_accept_language/parser.rb:81` 611.3 | `lib/js_locale_helper.rb:40` 1636.7, `lib/topic_query.rb:568` 1497.4, `lib/js_locale_helper.rb:23` 1076.6 |
| 5 | TopicsController#show | 273 / 273 | 19930.3 / 19925.1 | -5.2 | 19892.1 | `GEM/bootsnap/lib/bootsnap/compile_cache/yaml.rb:222` 639.8, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 603.7, `RAILS/activerecord/lib/arel/table.rb:85` 492.1 | `lib/suggested_topics_builder.rb:26` 869.2, `lib/i18n/backend/discourse_i18n.rb:25` 665.3, `lib/topic_view.rb:1093` 595.6 |
| 6 | TopicsController#merge_topic | 14 / 14 | 19597.1 / 19594.9 | -2.2 | 18344.5 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 1146.4, `RAILS/activerecord/lib/arel/table.rb:85` 707.4, `GEM/erb/lib/erb/util.rb:65` 497.5 | `lib/mini_sql_multisite_connection.rb:21` 929.5, `lib/guardian/topic_guardian.rb:260` 678.8, `app/models/concerns/has_custom_fields.rb:200` 439.1 |
| 7 | TopicsController#status | 27 / 27 | 19153.3 / 19152.1 | -1.2 | 18520.1 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 523.3, `RAILS/activerecord/lib/arel/table.rb:85` 332.4, `GEM/erb/lib/erb/util.rb:65` 256.2 | `lib/guardian/topic_guardian.rb:260` 313.4, `app/models/topic.rb:1736` 221.6, `lib/theme_resolver.rb:14` 208.8 |
| 8 | ListController#new | 4 / 4 | 19068.0 / 19078.3 | 10.3 | 17416.8 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 522.7, `RAILS/activerecord/lib/arel/table.rb:85` 397.0, `RAILS/activerecord/lib/arel/alias_predication.rb:8` 330.0 | `lib/topic_query.rb:591` 2034.0, `app/models/user.rb:1627` 692.0, `app/models/topic_list.rb:164` 659.7 |
| 9 | ListController#hot | 2 / 2 | 18767.0 / 18766.0 | -1.0 | 21300.5 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 660.0, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:177` 620.0, `RAILS/activerecord/lib/arel/table.rb:85` 489.0 | `lib/topic_query.rb:568` 2655.0, `lib/freedom_patches/ams_include_without_root.rb:57` 1662.0, `lib/stylesheet/manager.rb:264` 969.0 |
| 10 | PostsController#create | 106 / 106 | 16984.9 / 16983.1 | -1.8 | 17050.4 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 579.6, `RAILS/activerecord/lib/arel/table.rb:85` 404.8, `GEM/erb/lib/erb/util.rb:65` 341.5 | `app/services/word_watcher.rb:34` 676.8, `lib/mini_sql_multisite_connection.rb:21` 352.4, `lib/post_creator.rb:635` 281.0 |
| 11 | TopicsController#move_posts | 37 / 37 | 16156.9 / 16158.1 | 1.3 | 15780.1 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 970.2, `RAILS/activerecord/lib/arel/table.rb:85` 535.7, `GEM/erb/lib/erb/util.rb:65` 396.2 | `lib/mini_sql_multisite_connection.rb:21` 836.5, `lib/guardian/topic_guardian.rb:260` 479.6, `app/models/concerns/has_custom_fields.rb:200` 327.6 |
| 12 | TagsController#show | 30 / 30 | 16096.4 / 16093.4 | -3.0 | 15626.4 | `GEM/http_accept_language/lib/http_accept_language/parser.rb:81` 455.2, `RAILS/activerecord/lib/arel/alias_predication.rb:8` 444.8, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:177` 416.9 | `lib/topic_query.rb:568` 1715.6, `lib/http_language_parser.rb:10` 470.3, `lib/freedom_patches/ams_include_without_root.rb:57` 359.7 |
| 13 | ListController#category_latest | 16 / 16 | 15838.2 / 15831.5 | -6.7 | 14948.7 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 647.6, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:177` 599.3, `RAILS/activerecord/lib/arel/table.rb:85` 488.1 | `lib/topic_query.rb:568` 1561.1, `lib/stylesheet/manager.rb:264` 805.2, `lib/freedom_patches/ams_include_without_root.rb:57` 675.9 |
| 14 | ListController#top | 8 / 8 | 14955.6 / 14955.7 | 0.1 | 16843.3 | `GEM/http_accept_language/lib/http_accept_language/parser.rb:81` 424.3, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 352.6, `RAILS/activerecord/lib/arel/alias_predication.rb:8` 332.6 | `lib/topic_query.rb:591` 1406.4, `lib/freedom_patches/ams_include_without_root.rb:57` 952.0, `lib/stylesheet/manager.rb:264` 752.9 |
| 15 | ListController#filter | 36 / 36 | 14923.2 / 14919.4 | -3.8 | 15120.6 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 867.4, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:177` 814.9, `RAILS/activerecord/lib/arel/table.rb:85` 624.6 | `lib/topic_query.rb:568` 2716.9, `lib/topic_query.rb:767` 1134.2, `app/models/topic_list.rb:164` 569.2 |
| 16 | TopicsController#update_tags | 7 / 7 | 14640.5 / 14636.7 | -3.8 | 16100.3 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 742.3, `RAILS/activerecord/lib/arel/table.rb:85` 343.8, `GEM/erb/lib/erb/util.rb:65` 315.0 | `lib/discourse_tagging.rb:815` 495.0, `lib/topic_view.rb:1093` 483.5, `lib/topic_view.rb:177` 477.5 |
| 17 | TopicsController#make_banner | 2 / 2 | 13481.0 / 13506.0 | 25.0 | 8545.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 719.0, `GEM/erb/lib/erb/util.rb:65` 366.0, `RAILS/activerecord/lib/arel/table.rb:85` 364.0 | `app/models/topic.rb:1531` 438.0, `app/models/topic_user.rb:135` 355.0, `lib/post_creator.rb:615` 340.0 |
| 18 | CategoriesController#categories_and_hot | 2 / 2 | 13413.0 / 13537.0 | 124.0 | 11898.5 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 666.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 656.0, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:177` 620.0 | `lib/topic_query.rb:568` 3427.0, `app/models/user.rb:1627` 692.0, `app/models/topic_list.rb:164` 583.0 |
| 19 | ListController#category_default | 44 / 44 | 13384.2 / 13372.2 | -12.0 | 13318.0 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 598.3, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:177` 555.6, `RAILS/activerecord/lib/arel/table.rb:85` 421.2 | `lib/topic_query.rb:568` 1484.9, `lib/topic_query.rb:767` 673.0, `lib/stylesheet/manager.rb:264` 543.7 |
| 20 | TopicsController#update | 62 / 62 | 13179.0 / 13181.5 | 2.5 | 13001.9 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 761.4, `RAILS/activerecord/lib/arel/table.rb:85` 328.3, `GEM/erb/lib/erb/util.rb:65` 306.7 | `lib/topic_view.rb:177` 400.1, `lib/topic_view.rb:1093` 383.5, `lib/mini_sql_multisite_connection.rb:21` 300.6 |
| 21 | TopicsController#remove_banner | 2 / 2 | 12689.0 / 12707.0 | 18.0 | 8133.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 566.0, `RAILS/activerecord/lib/arel/table.rb:85` 350.0, `GEM/erb/lib/erb/util.rb:65` 342.0 | `app/models/topic.rb:1543` 438.0, `app/models/topic_user.rb:135` 355.0, `lib/post_creator.rb:615` 340.0 |
| 22 | PostsController#update | 42 / 42 | 12028.4 / 12029.3 | 0.9 | 11824.6 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 584.1, `GEM/erb/lib/erb/util.rb:65` 267.4, `RAILS/activerecord/lib/arel/table.rb:85` 235.5 | `app/services/word_watcher.rb:34` 566.0, `lib/mini_sql_multisite_connection.rb:21` 286.9, `lib/middleware/omniauth_bypass_middleware.rb:35` 244.1 |
| 23 | TagsController#show_new | 3 / 3 | 11832.0 / 11838.5 | 6.5 | 11999.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 372.5, `RAILS/activerecord/lib/arel/table.rb:85` 346.0, `RAILS/activerecord/lib/arel/alias_predication.rb:8` 330.0 | `lib/topic_query.rb:591` 2041.0, `app/models/user.rb:1627` 693.5, `app/models/topic_list.rb:164` 629.5 |
| 24 | CategoriesController#create | 14 / 14 | 11796.5 / 11795.2 | -1.3 | 11096.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 381.8, `RAILS/activerecord/lib/arel/table.rb:85` 281.8, `GEM/erb/lib/erb/util.rb:65` 215.5 | `lib/category_creator.rb:39` 480.0, `app/serializers/category_serializer.rb:79` 298.2, `app/models/user.rb:1113` 242.2 |
| 25 | CategoriesController#update | 46 / 46 | 11675.8 / 11679.6 | 3.8 | 11696.8 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 684.4, `RAILS/activerecord/lib/arel/table.rb:85` 401.4, `GEM/erb/lib/erb/util.rb:65` 255.3 | `lib/s3_helper.rb:464` 1140.9, `lib/category_updater.rb:61` 592.5, `app/models/category.rb:1467` 527.3 |
| 26 | PostsController#revert | 14 / 14 | 11436.7 / 11433.5 | -3.2 | 10763.9 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 585.9, `GEM/erb/lib/erb/util.rb:65` 264.5, `RAILS/activerecord/lib/arel/table.rb:85` 259.1 | `lib/mini_sql_multisite_connection.rb:21` 269.6, `lib/discourse_tagging.rb:123` 253.0, `app/models/user.rb:1113` 241.5 |
| 27 | PostsController#destroy_many | 11 / 11 | 10942.3 / 10940.8 | -1.5 | 11296.3 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 668.5, `GEM/erb/lib/erb/util.rb:65` 305.4, `RAILS/activerecord/lib/arel/table.rb:85` 289.4 | `app/models/post_action.rb:235` 499.2, `lib/post_destroyer.rb:94` 232.0, `app/models/user.rb:1113` 217.6 |
| 28 | TopicsController#convert_topic | 8 / 8 | 10736.4 / 10738.1 | 1.7 | 9650.6 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 584.4, `GEM/erb/lib/erb/util.rb:65` 273.4, `RAILS/activerecord/lib/arel/table.rb:85` 236.1 | `app/services/word_watcher.rb:34` 304.6, `lib/mini_sql_multisite_connection.rb:21` 267.0, `app/models/user.rb:1113` 242.6 |
| 29 | TagsController#show_latest | 15 / 15 | 10675.8 / 10675.9 | 0.1 | 34778.7 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 636.4, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:177` 597.9, `RAILS/activerecord/lib/arel/table.rb:85` 485.4 | `lib/topic_query.rb:568` 2409.9, `lib/discourse_tagging.rb:745` 426.4, `lib/topic_query.rb:767` 422.4 |
| 30 | CategoriesController#categories_and_latest | 14 / 14 | 10508.9 / 10519.2 | 10.2 | 10803.3 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 615.2, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:177` 572.3, `RAILS/activerecord/lib/arel/table.rb:85` 509.5 | `lib/topic_query.rb:568` 2643.2, `app/models/topic_list.rb:164` 679.5, `app/models/category_list.rb:227` 569.6 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` | `get_oid_type` | 326.99 / 326.99 | 0.0 | 327.09 | 97% | Array |  | `lib/theme_resolver.rb:14` 10%, `app/models/user_auth_token.rb:36` 9% | `type_map.fetch(oid, fmod, sql_type) {` |
| 2 | `GEM/http_accept_language/lib/http_accept_language/parser.rb:81` | `sanitize_available_locales` | 273.74 / 273.74 | 0.0 | 273.85 | 69% | String, Array |  | `lib/http_language_parser.rb:10` 100% | `available.to_s.split(/[_-]/).reject { \|part\| part.start_with?("x") }.j` |
| 3 | `RAILS/activerecord/lib/arel/table.rb:85` | `[]` | 190.63 / 190.63 | 0.0 | 190.65 | 97% | Struct |  | `lib/topic_query.rb:568` 9%, `lib/topic_query.rb:591` 6% | `Attribute.new(table, name)` |
| 4 | `GEM/erb/lib/erb/util.rb:65` | `url_encode` | 151.91 / 151.91 | 0.0 | 151.97 | 97% | String |  | `app/models/user_auth_token.rb:55` 4%, `app/models/user_auth_token.rb:112` 4% | `CGI.escapeURIComponent(s.to_s)` |
| 5 | `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` | `format` | 126.53 / 126.53 | 0.0 | 126.58 | 97% | String |  | `app/models/user_auth_token.rb:55` 4%, `app/models/user_auth_token.rb:112` 4% | `"#{key}='#{ERB::Util.url_encode(value)}'"` |
| 6 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` | `cast_result` | 111.74 / 111.73 | -0.01 | 111.76 | 97% | Array, String |  | `app/models/user_auth_token.rb:36` 6%, `lib/freedom_patches/ams_include_without_root.rb:57` 5% | `ActiveRecord::Result.new(fields, result.values, types.freeze, affected` |
| 7 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` | `as` | 97.56 / 97.56 | 0.0 | 97.79 | 23% | Object, Hash |  | `lib/topic_query.rb:568` 34%, `lib/topic_query.rb:591` 21% | `Nodes::As.new self, Nodes::SqlLiteral.new(other, retryable: true)` |
| 8 | `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:177` | `aliases` | 90.17 / 90.17 | 0.0 | 90.38 | 19% | String, Struct |  | `lib/topic_query.rb:568` 34%, `lib/topic_query.rb:591` 21% | `Aliases::Column.new column_name, "t#{i}_r#{j}"` |
| 9 | `RAILS/activemodel/lib/active_model/attribute.rb:9` | `from_database` | 83.11 / 83.11 | -0.0 | 83.16 | 89% | Object |  | `app/models/group.rb:641` 21%, `app/models/group.rb:608` 8% | `FromDatabase.new(name, value_before_type_cast, type, nil, value)` |
| 10 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` | `+` | 73.41 / 73.41 | 0.0 | 73.42 | 96% | Array, Object |  | `app/models/concerns/trashable.rb:7` 9%, `app/models/web_hook.rb:92` 4% | `WhereClause.new(predicates + other.predicates)` |
| 11 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/quoting.rb:81` | `quote` | 68.77 / 68.76 | -0.0 | 68.77 | 96% | String |  | `lib/mini_sql_multisite_connection.rb:21` 23%, `app/helpers/application_helper.rb:730` 3% | `when Numeric then value.to_s` |
| 12 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | `merge` | 64.44 / 64.44 | 0.0 | 64.46 | 93% | Object, Array |  | `app/models/user_auth_token.rb:36` 9%, `app/models/user.rb:1627` 5% | `WhereClause.new(predicates \| other.predicates)` |
| 13 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` | `call` | 63.31 / 63.31 | 0.0 | 63.31 | 100% | Data |  | `app/models/group.rb:641` 16%, `app/controllers/application_controller.rb:472` 15% | `result_lambda = -> { user_callback.call target, value }` |
| 14 | `RAILS/activesupport/lib/active_support/callbacks.rb:362` | `make_lambda` | 62.63 / 62.63 | 0.0 | 62.64 | 72% | Array, Hash |  | `app/models/concerns/roleable.rb:61` 23%, `app/models/concerns/roleable.rb:90` 23% | `target.send(@method_name, &block)` |
| 15 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` | `create` | 61.2 / 61.19 | -0.0 | 61.21 | 97% | Object, Hash |  | `app/models/web_hook.rb:92` 5%, `app/models/user_auth_token.rb:36` 4% | `relation_class_for(model).new(model, ...)` |
| 16 | `RAILS/activerecord/lib/active_record/relation.rb:98` | `initialize_copy` | 57.86 / 57.86 | 0.0 | 57.87 | 97% | Hash |  | `app/models/concerns/trashable.rb:7` 6%, `app/models/user.rb:1627` 2% | `@values = @values.dup` |
| 17 | `GEM/bootsnap/lib/bootsnap/compile_cache/yaml.rb:222` | `storage_to_output` | 57.61 / 57.61 | 0.0 | 63.78 | 0% | String, Hash |  | `lib/i18n/backend/discourse_i18n.rb:25` 100% | `result = unpacker.unpack` |
| 18 | `RAILS/activerecord/lib/active_record/relation.rb:77` | `initialize` | 56.2 / 56.19 | -0.0 | 56.21 | 97% | Hash |  | `app/models/user_auth_token.rb:36` 4%, `app/models/topic_list.rb:164` 4% | `def initialize(model, table: nil, predicate_builder: nil, values: {})` |
| 19 | `RAILS/activerecord/lib/active_record/relation/spawn_methods.rb:10` † | `spawn` | 55.77 / 55.77 | 0.0 | 55.79 | 97% | Object |  | `app/models/concerns/trashable.rb:7` 6%, `app/models/user.rb:1627` 2% | `already_in_scope?(model.scope_registry) ? model.all : clone` |
| 20 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` | `expand_from_hash` | 55.64 / 55.64 | 0.0 | 55.66 | 96% | Array |  | `app/models/concerns/trashable.rb:7` 11%, `app/models/web_hook.rb:76` 3% | `attributes.flat_map do \|key, value\|` |
| 21 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:29` | `references` | 51.81 / 51.81 | 0.0 | 51.82 | 96% | Array |  | `app/models/concerns/trashable.rb:7` 12%, `app/models/web_hook.rb:76` 3% | `attributes.each_with_object([]) do \|(key, value), result\|` |
| 22 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:166` | `convert_dot_notation_to_hash` | 51.81 / 51.81 | 0.0 | 51.82 | 96% | Array, Hash |  | `app/models/concerns/trashable.rb:7` 12%, `app/models/web_hook.rb:76` 3% | `attributes.each_with_object({}) do \|(key, value), converted\|` |
| 23 | `RAILS/activerecord/lib/arel/nodes/select_statement.rb:11` | `initialize` | 46.01 / 46.01 | 0.0 | 46.02 | 97% | Array, Object |  | `app/models/web_hook.rb:92` 9%, `app/services/word_watcher.rb:34` 3% | `@cores          = [SelectCore.new(relation)]` |
| 24 | `RAILS/activerecord/lib/arel.rb:56` | `sql` | 43.2 / 43.2 | 0.0 | 43.21 | 95% | Hash, String |  | `app/models/web_hook.rb:92` 10%, `app/models/user_auth_token.rb:156` 4% | `Arel::Nodes::SqlLiteral.new(sql_string, retryable: retryable)` |
| 25 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:287` | `build_handle` | 41.48 / 41.48 | -0.0 | 41.49 | 100% | Array | #59235 merged 2026-10-21, after this app's version, not released yet | `app/helpers/application_helper.rb:730` 4%, `app/models/user_auth_token.rb:36` 4% | `groups = groups_for(name).map do \|group_klass, grouped_listeners\|` |
| 26 | `RAILS/activerecord/lib/arel/visitors/to_sql.rb:757` | `visit_Arel_Nodes_SqlLiteral` | 41.45 / 41.45 | 0.0 | 41.45 | 83% | String |  | `lib/topic_query.rb:568` 27%, `lib/topic_query.rb:591` 17% | `collector << o.to_s` |
| 27 | `RAILS/activerecord/lib/arel/visitors/to_sql.rb:801` | `visit_Arel_Nodes_BoundSqlLiteral` | 38.89 / 38.89 | 0.0 | 38.89 | 49% | String, Array |  | `app/models/user_auth_token.rb:156` 18%, `lib/guardian/topic_guardian.rb:50` 8% | `o.sql_with_placeholders.scan(/:(?<!::)([a-zA-Z]\w*)\|([^:]+\|.)/) do` |
| 28 | `RAILS/activerecord/lib/arel/visitors/to_sql.rb:790` | `visit_Arel_Nodes_BoundSqlLiteral` | 37.48 / 37.48 | 0.0 | 37.5 | 90% | String, Array |  | `app/models/web_hook.rb:92` 30%, `app/models/user_auth_token.rb:156` 12% | `o.sql_with_placeholders.scan(/\?\|([^?]+)/) do` |
| 29 | `RAILS/activerecord/lib/active_record/relation/query_methods.rb:1681` | `build_where_clause` | 36.22 / 36.22 | 0.0 | 36.23 | 96% | Object |  | `app/models/concerns/trashable.rb:7` 9%, `app/models/web_hook.rb:92` 4% | `Relation::WhereClause.new(parts)` |
| 30 | `RAILS/activemodel/lib/active_model/type/string.rb:39` | `cast_value` | 34.94 / 34.93 | -0.0 | 34.94 | 94% | String |  | `lib/post_action_type_view.rb:26` 8%, `app/models/group.rb:641` 4% | `when ::String then ::String.new(value)` |

## Dev/test-mode work

61.6 of 7105.8 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | route build | `RAILS/actionpack/lib/action_dispatch/journey/gtg/transition_table.rb:85` | 12.08 | 100% | `lib/middleware/omniauth_bypass_middleware.rb:35` 99%, `lib/discourse.rb:727` 1% | `curr_slice = full_string.slice(slice_start, slice_length)` |
| 2 | error page | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:195` | 11.6 | 0% | `lib/middleware/default_headers.rb:13` 10%, `app/helpers/application_helper.rb:730` 8% | `add_filter { \|line\| line.sub(gems_regexp, gems_result) }` |
| 3 | route build | `RAILS/actionpack/lib/action_dispatch/journey/gtg/transition_table.rb:52` | 6.49 | 100% | `lib/middleware/omniauth_bypass_middleware.rb:35` 99%, `lib/discourse.rb:727` 1% | `next_states = []` |
| 4 | route build | `RAILS/actionpack/lib/action_dispatch/journey/gtg/simulator.rb:48` | 3.25 | 100% | `lib/middleware/omniauth_bypass_middleware.rb:35` 99%, `lib/discourse.rb:727` 1% | `token = string.byteslice(start_index, pos - start_index)` |
| 5 | error page | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:74` | 2.3 | 0% | `app/helpers/application_helper.rb:730` 9%, `lib/stylesheet/manager.rb:264` 8% | `frame = frame.to_s` |
| 6 | debug logging | `GEM/lograge/lib/lograge/rails_ext/rack/logger.rb:21` | 2.0 | 100% | `config/initializers/100-quiet_logger.rb:20` 100% | `[status, headers, ::Rack::BodyProxy.new(body) {}] # rubocop:disable Li` |
| 7 | debug logging | `GEM/logger/lib/logger/log_device.rb:33` | 1.99 | 100% | `lib/discourse_logstash_logger.rb:122` 100% | `handle_write_errors("writing") {@dev.write(message)}` |
| 8 | asset lookup | `GEM/propshaft/lib/propshaft/asset.rb:73` † | 1.72 | 9% | `lib/freedom_patches/propshaft_patches.rb:8` 94%, `lib/discourse.rb:590` 6% | `logical_path.sub(/\.(\w+(\.map)?)$/) { \|ext\| "-#{digest}#{ext}" }` |
| 9 | debug logging | `RAILS/actionview/lib/action_view/structured_event_subscriber.rb:61` † | 1.66 | 14% | `app/controllers/application_controller.rb:985` 36%, `app/controllers/topics_controller.rb:1597` 27% | `string = string.sub("#{rails_root}/", "")` |
| 10 | asset lookup | `GEM/propshaft/lib/propshaft/server.rb:16` | 1.27 | 100% | `lib/middleware/request_tracker.rb:384` 100% | `if (method == "GET" \|\| method == "HEAD") && path.start_with?(@assembly` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activerecord | 4431.6 | 4435.6 | `postgresql_adapter.rb:880` 327.0, `table.rb:85` 190.6, `query_logs_formatter.rb:21` 126.5 |
| app | 1250.4 | 1388.6 | `upcoming_changes.rb:153` 140.2, `js_locale_helper.rb:141` 108.5, `http_language_parser.rb:8` 82.1 |
| rails: activesupport | 646.3 | 654.6 | `callbacks.rb:179` 63.3, `callbacks.rb:362` 62.6, `fanout.rb:287` 41.5 |
| gem: http_accept_language | 283.3 | 283.5 | `parser.rb:81` 273.7, `parser.rb:19` 4.1, `parser.rb:31` 1.7 |
| rails: activemodel | 281.0 | 283.0 | `attribute.rb:9` 83.1, `string.rb:39` 34.9, `attribute.rb:13` 18.5 |
| rails: actionpack | 261.8 | 356.4 | `mime_type.rb:338` 16.0, `static.rb:145` 13.3, `transition_table.rb:85` 12.1 |
| ruby default gem: erb | 151.9 | 152.1 | `util.rb:65` 151.9, `erb.rb:872` 0.0, `compiler.rb:276` 0.0 |
| gem: rack | 141.3 | 142.0 | `request.rb:515` 30.6, `utils.rb:511` 24.1, `utils.rb:507` 11.5 |
| ruby stdlib | 137.6 | 170.8 | `ipaddr.rb:725` 23.0, `tree_builder.rb:97` 22.7, `parser.rb:62` 22.4 |
| gem: nokogiri | 78.1 | 105.4 | `searchable.rb:270` 4.9, `selector_cache.rb:33` 4.2, `searchable.rb:238` 4.2 |
| gem: redis-client | 74.6 | 74.6 | `resp3.rb:99` 22.0, `resp3.rb:54` 20.1, `resp3.rb:69` 7.2 |
| gem: i18n | 74.5 | 75.0 | `fallbacks.rb:90` 10.2, `fallbacks.rb:46` 10.1, `fallbacks.rb:52` 7.7 |
| rails: actionview | 68.4 | 69.5 | `base.rb:230` 9.6, `lookup_context.rb:44` 4.6, `lookup_context.rb:47` 4.6 |
| gem: message_bus | 62.2 | 62.3 | `message.rb:31` 20.0, `message_bus.rb:367` 8.6, `distributed_cache.rb:132` 6.0 |
| gem: bootsnap | 60.0 | 66.8 | `yaml.rb:222` 57.6, `iseq.rb:98` 0.7, `yaml.rb:305` 0.2 |
| ruby default gem: uri | 58.3 | 58.8 | `common.rb:465` 19.8, `common.rb:456` 10.9, `common.rb:108` 3.5 |
| gem: tzinfo | 56.0 | 56.1 | `timestamp.rb:208` 28.0, `timestamp.rb:193` 14.0, `constant_offset_data_timezone_info.rb:52` 14.0 |
| gem: active_model_serializers | 29.7 | 30.1 | `serializer.rb:304` 5.1, `associations.rb:75` 5.0, `serializer.rb:467):2` 3.4 |
| gem: goldiloader | 29.2 | 29.2 | `auto_include_context.rb:10` 12.3, `auto_include_context.rb:14` 11.1, `auto_include_context.rb:43` 4.3 |
| gem: concurrent-ruby | 24.1 | 24.2 | `safe_initialization.rb:30` 6.0, `non_concurrent_map_backend.rb:131` 5.7, `mutex_lockable_object.rb:32` 2.0 |
| gem: lograge | 20.2 | 20.2 | `logger.rb:21` 2.0, `method_and_path.rb:8` 2.0, `lograge.rb:74` 2.0 |
| gem: mini_sql | 13.7 | 13.7 | `connection.rb:217` 5.6, `connection.rb:64` 2.0, `builder.rb:112` 1.4 |
| gem: sidekiq | 13.2 | 13.5 | `sidekiq.rb:54` 6.2, `job.rb:381` 2.1, `job_util.rb:58` 0.7 |
| gem: rails_multisite | 12.3 | 12.3 | `connection_specification.rb:8` 6.2, `connection_management.rb:23` 6.2 |
| gem: json | 11.2 | 11.2 | `common.rb:967` 5.9, `common.rb:1130` 2.3, `common.rb:1124` 2.3 |
| gem: redis | 8.8 | 8.8 | `strings.rb:191` 3.9, `keys.rb:283` 1.1, `scripting.rb:110` 0.9 |
| gem: logstash-event | 8.1 | 8.2 | `event.rb:57` 3.0, `event.rb:55` 2.0, `fieldreference.rb:44):2` 1.0 |
| gem: mocha | 7.9 | 8.3 | `parameters_matcher.rb:37` 1.4, `expectation_list.rb:55` 1.3, `invocation.rb:45` 0.7 |
| gem: propshaft | 7.2 | 12.0 | `asset.rb:73` 1.7, `server.rb:16` 1.3, `server.rb:14` 1.0 |
| gem: ostruct | 5.2 | 5.2 | `ostruct.rb:238` 1.3, `ostruct.rb:237` 1.3, `ostruct.rb:248` 0.9 |
| gem: connection_pool | 4.9 | 4.9 | `connection_pool.rb:110` 1.4, `connection_pool.rb:113` 1.4, `timed_stack.rb:38` 0.7 |
| gem: base64 | 4.8 | 4.8 | `base64.rb:283` 2.8, `base64.rb:310` 1.7, `base64.rb:223` 0.3 |
| gem: multi_json | 4.5 | 4.5 | `oj.rb:67` 2.4, `legacy_constant.rb:34` 1.4, `multi_json.rb:214` 0.7 |
| gem: addressable | 4.0 | 4.5 | `uri.rb:431` 1.3, `uri.rb:428` 1.3, `uri.rb:486` 0.2 |
| ruby default gem: securerandom | 3.8 | 3.8 | `securerandom.rb:71` 3.8 |
| rails: railties | 3.5 | 3.9 | `logger.rb:29` 1.0, `logger.rb:21` 1.0, `engine.rb:748` 1.0 |
| gem: loofah | 3.5 | 3.5 | `concerns.rb:172` 1.2, `scrubber.rb:128` 1.0, `concerns.rb:43` 0.5 |
| ruby default gem: digest | 3.0 | 3.0 | `digest.rb:56` 3.0, `digest.rb:49` 0.0, `digest.rb:65` 0.0 |
| gem: logger | 3.0 | 3.0 | `log_device.rb:33` 2.0, `logger.rb:739` 1.0, `logger.rb:608` 0.0 |
| gem: logster | 2.1 | 2.1 | `message.rb:198` 0.4, `message.rb:190` 0.4, `message.rb:123` 0.4 |
| gem: sanitize | 1.8 | 2.0 | `sanitize.rb:204` 0.9, `sanitize.rb:207` 0.3, `config.rb:44` 0.1 |
| test harness: webmock | 1.5 | 1.9 | `headers.rb:69` 0.4, `headers.rb:68` 0.3, `headers.rb:16` 0.1 |
| gem: mail | 1.5 | 3.2 | `8bit.rb:14` 0.2, `utilities.rb:215` 0.1, `address_lists_parser.rb:32009` 0.1 |
| gem: erubi | 1.4 | 2.2 | `erubi.rb:134` 0.8, `erubi.rb:137` 0.2, `erubi.rb:139` 0.1 |
| gem: mustache | 1.2 | 2.3 | `parser.rb:271` 0.2, `template.rb:41` 0.2, `parser.rb:198` 0.1 |
| gem: aws-sdk-core | 0.8 | 7.9 | `handler_list_entry.rb:33` 0.1, `handler_list_entry.rb:73` 0.1, `configuration.rb:159` 0.0 |
| ruby default gem: openssl | 0.7 | 0.7 | `cipher.rb:56` 0.7, `hmac.rb:36` 0.0, `hmac.rb:38` 0.0 |
| gem: fastimage | 0.7 | 0.7 | `type_parser.rb:14` 0.1, `fastimage.rb:397` 0.1, `png.rb:4` 0.1 |
| gem: racc | 0.6 | 0.6 | `parser.rb:263` 0.6 |
| gem: zeitwerk | 0.4 | 0.4 | `cref.rb:47` 0.1, `constant_path_validator.rb:13` 0.1, `file_system.rb:203` 0.1 |
| gem: rails-html-sanitizer | 0.4 | 0.4 | `sanitizer.rb:157` 0.1, `scrubbers.rb:55` 0.1, `sanitizer.rb:33` 0.0 |
| ruby default gem: net-http | 0.3 | 0.4 | `http.rb:1062` 0.1, `header.rb:203` 0.1, `http.rb:1061` 0.1 |
| gem: mini_mime | 0.3 | 0.3 | `mini_mime.rb:54` 0.2, `mini_mime.rb:56` 0.1, `mini_mime.rb:125` 0.0 |
| gem: lru_redux | 0.2 | 0.2 | `cache.rb:63` 0.1, `cache.rb:34` 0.1, `cache.rb:62` 0.0 |
| gem: csv | 0.2 | 0.2 | `parser.rb:1003` 0.0, `parser.rb:62` 0.0, `parser.rb:988` 0.0 |
| gem: htmlentities | 0.1 | 0.1 | `decoder.rb:10` 0.0, `decoder.rb:25` 0.0, `decoder.rb:35` 0.0 |
| gem: aws-sigv4 | 0.1 | 0.2 | `signer.rb:611` 0.0, `signer.rb:633` 0.0, `signer.rb:140` 0.0 |
| gem: excon | 0.1 | 0.1 | `connection.rb:248` 0.0, `connection.rb:303` 0.0, `connection.rb:469` 0.0 |
| gem: crass | 0.1 | 0.1 | `scanner.rb:97` 0.0, `scanner.rb:41` 0.0, `tokenizer.rb:642` 0.0 |
| gem: aws-sdk-s3 | 0.0 | 9.5 | `endpoint_provider.rb:490` 0.0, `endpoint_provider.rb:877` 0.0, `endpoint_parameters.rb:169` 0.0 |
| gem: pg | 0.0 | 0.0 | `date.rb:14` 0.0, `result.rb:17` 0.0, `json.rb:13` 0.0 |
| gem: messageformat-wrapper | 0.0 | 0.1 | `messageformat.rb:25` 0.0, `messageformat.rb:34` 0.0, `messageformat.rb:38` 0.0 |
| gem: mini_racer | 0.0 | 0.0 | `mini_racer.rb:101` 0.0 |
| gem: certified | 0.0 | 0.0 | `certified.rb:7` 0.0 |
| rails: actionmailer | 0.0 | 0.0 | `base.rb:953` 0.0, `base.rb:996` 0.0, `delivery_methods.rb:66` 0.0 |
| gem: dry-initializer | 0.0 | 0.1 | `wrap_type.rb:29` 0.0, `root.rb:11` 0.0, `unwrap_type.rb:18` 0.0 |
| other | 0.0 | 0.0 | `discourse_plugin_outlet__ApplicationHelper:1` 0.0, `anonymous_cache.rb:41):2` 0.0 |
| gem: mini_suffix | 0.0 | 0.0 | `mini_suffix.rb:26` 0.0 |
| gem: test-prof | 0.0 | 0.0 | `let_it_be.rb:131` 0.0, `let_it_be.rb:121` 0.0, `active_record_refind.rb:15` 0.0 |
| lowrail-profile | 0.0 | 0.0 | `profile.rb:107` 0.0, `profile.rb:66` 0.0, `profile.rb:56` 0.0 |
| gem: request_store | 0.0 | 0.0 | `request_store.rb:7` 0.0 |
| gem: bigdecimal | 0.0 | 0.0 | `util.rb:51` 0.0, `util.rb:24` 0.0 |
| gem: aws-partitions | 0.0 | 0.1 | `metadata.rb:27` 0.0, `metadata.rb:26` 0.0 |
| gem: maxminddb | 0.0 | 0.0 | `reader.rb:10` 0.0, `maxminddb.rb:14` 0.0, `maxminddb.rb:17` 0.0 |
| gem: msgpack | 0.0 | 0.0 | `msgpack.rb:40` 0.0, `factory.rb:9` 0.0, `factory.rb:137` 0.0 |
| gem: discourse-emojis | 0.0 | 0.0 | `discourse_emojis.rb:27` 0.0, `discourse_emojis.rb:25` 0.0, `discourse_emojis.rb:16` 0.0 |
| gem: mini_scheduler | 0.0 | 0.0 | `web.rb:21` 0.0, `web.rb:5` 0.0, `web.rb:78` 0.0 |
| ruby default gem: bundler | 0.0 | 0.0 | `rubygems_integration.rb:192` 0.0 |
| gem: discourse-fonts | 0.0 | 0.0 | `discourse_fonts.rb:7` 0.0 |
| test harness: rspec-expectations | 0.0 | 0.0 | `expectation_target.rb:45` 0.0, `matchers.rb:559` 0.0 |
