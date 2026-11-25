# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bundle exec rspec spec/requests --format documentation`
* Ruby: ruby 3.3.14 (2026-11-19 revision f4c37f481b) +YJIT [x86_64-linux]
* Rails: 8.0.5, test environment
* Counted in run 1: 6765 requests, 18 mail windows; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 6765 | 16980.6 | 0 | 18 | 0 | 0 |
| run2 | 1 | 6765 | 16990.1 | 0 | 18 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.0 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `config/initializers/warden_hooks.rb:13` |  | 231.68 | 42.55 | 0.02 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 16%, `RAILS/activesupport/lib/active_support/callbacks.rb:361` 15%, `RUBY/ipaddr.rb:659` 2% | - 11%, Stories::FeedsController#show 2%, NotificationsController#index 2% | `user.save(validate: false)` |
| 2 | `config/initializers/timeout.rb:232` | `execute` | 218.03 | 54.61 | 0.01 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 29%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:864` 29%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:191` 5% | StoriesController#index 3%, CommentsController#create 2%, CommentsController#index 2% | `super` |
| 3 | `app/policies/authorizer.rb:229` | `has_any_role?` | 177.74 | 23.79 | 0.01 | `RAILS/activerecord/lib/arel/visitors/to_sql.rb:802` 7%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 4%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:140` 3% | ArticlesController#update 9%, Api::V1::ArticlesController#update 6%, Api::V1::PagesController#update 4% | `return user.__send__(:has_any_role?, *args) unless roles_loaded?` |
| 4 | `app/models/settings/base.rb:198` | `all_settings` | 157.0 | 51.09 | 0.01 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:235` 4%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 4%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 4% | StoriesController#index 6%, - 4%, StoriesController#show 3% | `records.each do \|record\|` |
| 5 | `app/policies/authorizer.rb:225` | `has_role?` | 105.95 | 16.83 | 0.0 | `RAILS/activerecord/lib/arel/visitors/to_sql.rb:802` 7%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:140` 3% | ArticlesController#update 14%, Admin::UsersController#show 10%, Api::V1::ArticlesController#update 9% | `user.__send__(:has_role?, *args)` |
| 6 | `app/models/settings/base.rb:194` | `all_settings` | 98.69 | 0.0 | 0.01 | `RAILS/activesupport/lib/active_support/cache.rb:668` 12%, `RAILS/activesupport/lib/active_support/cache.rb:1028` 8%, `RAILS/activesupport/lib/active_support/cache.rb:1027` 8% | StoriesController#index 6%, - 4%, StoriesController#show 3% | `RequestStore[cache_key_with_subforem] \|\|= Rails.cache.fetch(cache_key_` |
| 7 | `lib/memory_first_cache.rb:25` | `fetch` | 93.1 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/cache/memory_store.rb:47` 32%, `RAILS/activesupport/lib/active_support/cache.rb:1027` 12%, `RAILS/activesupport/lib/active_support/cache.rb:505` 10% | StoriesController#index 6%, StoriesController#show 4%, Stories::FeedsController#show 3% | `mem = memory_store.read(memory_key)` |
| 8 | `app/models/user.rb:337` | `cached_recent_user_ids` | 92.13 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute_mutation_tracker.rb:29` 30%, `RAILS/activerecord/lib/active_record/attribute_methods/time_zone_conversion.rb:14` 11%, `RAILS/activemodel/lib/active_model/attribute_mutation_tracker.rb:36` 10% | - 7%, Stories::FeedsController#show 2%, NotificationsController#index 2% | `saved_changes.key?(:email) \|\| saved_changes.key?(:registered) \|\| saved` |
| 9 | `app/controllers/api/v1/api_controller.rb:174` | `authenticate_with_api_key` | 91.7 | 11.2 | 0.04 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 17%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:864` 16%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:191` 5% | Api::V1::PagesController#create 6%, Api::V1::ArticlesController#update 6%, Api::V1::PagesController#update 6% | `api_secret = ApiSecret.includes(:user).find_by(secret: api_key)` |
| 10 | `app/services/articles/updater.rb:47` | `save_article` | 56.99 | 1.55 | 0.0 | `GEM/psych/lib/psych/tree_builder.rb:97` 7%, `RAILS/activemodel/lib/active_model/attribute.rb:13` 6%, `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 6% | Api::V1::ArticlesController#update 40%, ArticlesController#update 35%, Api::V0::ArticlesController#update 20% | `return with_deadlock_retry { article.update(article_params) } if co_au` |
| 11 | `app/models/settings/base.rb:217` | `settings_records_for` | 51.93 | 0.0 | 0.05 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:29` 7%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:68` 7%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:164` 7% | StoriesController#index 6%, - 4%, StoriesController#show 3% | `return unscoped.select(:var, :value).where(subforem_id: nil) unless su` |
| 12 | `config/initializers/0_application_config.rb:23` | `[]` | 50.45 | 29.42 | 7.44 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 30%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:208` 20%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:212` 20% | StoriesController#index 13%, StoriesController#show 9%, NotificationsController#index 3% | `Rails.logger.debug { "Unset ENV variable: #{key}." }` |
| 13 | `app/views/admin/articles/_article_item.html.erb:224` |  | 49.15 | 0.0 | 0.05 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` 11%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 11%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` 11% | Admin::ArticlesController#index 98%, Admin::ArticlesController#show 1%, Admin::ArticlesController#unpin 1% | `<%= f.datetime_select :published_at, { required: true, include_blank: ` |
| 14 | `app/services/feature_flag.rb:16` | `flipper_id` | 48.63 | 0.0 | 0.03 | `GEM/flipper/lib/flipper/feature.rb:115` 12%, `GEM/flipper/lib/flipper/adapters/wrapper.rb:32` 8%, `RUBY/forwardable.rb:240` 8% | StoriesController#index 14%, StoriesController#show 10%, - 4% | `delegate :add, :disable, :enable, :enabled?, :exist?, :remove, to: Fli` |
| 15 | `app/controllers/application_controller.rb:217` | `handle_argument_error` | 48.19 | 15.02 | 0.0 | `RAILS/actionview/lib/action_view/template_path.rb:23` 6%, `RAILS/actionview/lib/action_view/template/resolver.rb:181` 6%, `RAILS/actionview/lib/action_view/template/resolver.rb:141` 6% | Api::V0::ArticlesController#index 5%, Api::V1::ArticlesController#index 5%, CommentsController#index 4% | `yield` |
| 16 | `app/views/admin/shared/_nested_sidebar.html.erb:26` |  | 42.59 | 0.0 | 0.01 | `RAILS/actionview/lib/action_view/buffers.rb:48` 12%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 12%, `RAILS/actionpack/lib/action_dispatch/journey/formatter.rb:123` 8% | Admin::UsersController#show 15%, Admin::PermissionsController#index 4%, Admin::ArticlesController#index 4% | `href="<%= admin_path %>/<%= group_name %>/<%= item.controller %>"` |
| 17 | `app/decorators/application_decorator.rb:15` | `decorate_collection` | 40.32 | 5.71 | 0.18 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 12%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:864` 12%, `RAILS/activerecord/lib/arel/table.rb:85` 6% | Api::V1::ArticlesController#index 19%, Api::V0::ArticlesController#index 18%, Api::V0::ArticlesController#search 13% | `objects.map(&:decorate)` |
| 18 | `app/controllers/stories_controller.rb:98` | `show` | 32.71 | 3.03 | 0.04 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 13%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:864` 13%, `RAILS/activerecord/lib/arel/table.rb:85` 6% | StoriesController#show 100% | `.find_by(path: path)&.decorate)` |
| 19 | `app/models/user.rb:874` | `subscribe_to_mailchimp_newsletter` | 32.07 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute_mutation_tracker.rb:29` 29%, `RAILS/activerecord/lib/active_record/attribute_methods/time_zone_conversion.rb:14` 12%, `RAILS/activemodel/lib/active_model/attribute_mutation_tracker.rb:36` 10% | - 7%, Stories::FeedsController#show 2%, NotificationsController#index 2% | `return unless saved_changes.key?(:email)` |
| 20 | `app/models/user.rb:873` | `subscribe_to_mailchimp_newsletter` | 32.07 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute_mutation_tracker.rb:29` 29%, `RAILS/activerecord/lib/active_record/attribute_methods/time_zone_conversion.rb:14` 12%, `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:399` 10% | - 7%, Stories::FeedsController#show 2%, NotificationsController#index 2% | `return if saved_changes.key?(:unconfirmed_email) && saved_changes.key?` |
| 21 | `app/views/admin/shared/_nested_sidebar.html.erb:31` |  | 31.25 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:146` 42%, `RAILS/activesupport/lib/active_support/inflector/methods.rb:193` 20%, `RAILS/activesupport/lib/active_support/inflector/methods.rb:152` 16% | Admin::UsersController#show 15%, Admin::ArticlesController#index 4%, Admin::PermissionsController#index 4% | `<%= item.name.to_s.titleize %>` |
| 22 | `app/models/billboard.rb:254` | `select_billboard_by_weighted_strategy` | 29.73 | 5.03 | 0.01 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 23%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:864` 22%, `RAILS/activerecord/lib/arel/visitors/to_sql.rb:802` 6% | StoriesController#index 36%, StoriesController#show 7%, SidebarsController#show 6% | `billboards_for_display.limit(rand(1..15)).sample` |
| 23 | `app/views/articles/_reaction_category_resources.html.erb:3` |  | 29.07 | 1.49 | 0.06 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:316` 23%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:311` 15%, `RAILS/activesupport/lib/active_support/inflector/methods.rb:227` 8% | StoriesController#index 19%, StoriesController#show 10%, NotificationsController#index 6% | `<%= image_tag "#{category.icon}.svg", size: "18x18", data: { name: cat` |
| 24 | `app/views/layouts/_user_config.html.erb:2` |  | 23.9 | 42.2 | 0.18 | `RAILS/activesupport/lib/active_support/core_ext/string/filters.rb:22` 84%, `GEM/uri/lib/uri/rfc2396_parser.rb:291` 4%, `RUBY/set.rb:244` 3% | NotificationsController#index 15%, UsersController#edit 11%, StoriesController#index 7% | `<%= Rails.application.assets["themes/dark.css"].to_s.squish.html_safe ` |
| 25 | `lib/memory_first_cache.rb:45` | `fetch` | 23.52 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/cache.rb:668` 26%, `RAILS/activesupport/lib/active_support/cache/memory_store.rb:34` 17%, `RAILS/activesupport/lib/active_support/cache.rb:884` 9% | StoriesController#index 8%, StoriesController#show 3%, Stories::FeedsController#show 2% | `memory_store.write(memory_key, computed, expires_in: memory_expires_in` |
| 26 | `app/controllers/api/v0/api_controller.rb:134` | `authenticate_with_api_key` | 21.2 | 2.56 | 0.11 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 17%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:864` 17%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:191` 5% | Api::V0::ArticlesController#create 15%, Api::V0::ArticlesController#update 12%, Api::V0::ArticlesController#me 6% | `api_secret = ApiSecret.includes(:user).find_by(secret: api_key)` |
| 27 | `app/models/user.rb:1157` | `add_role` | 20.56 | 4.33 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 3%, `RAILS/activerecord/lib/arel/visitors/postgresql.rb:81` 2%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:140` 2% | Api::V1::UserRolesController#update 17%, RegistrationsController#create 16%, Admin::PermissionsController#grant 15% | `result = super` |
| 28 | `app/services/articles/creator.rb:109` | `save_article` | 20.14 | 5.77 | 0.01 | `RAILS/activerecord/lib/arel/visitors/postgresql.rb:81` 11%, `RAILS/activesupport/lib/active_support/callbacks.rb:178` 6%, `RAILS/activerecord/lib/arel/table.rb:85` 6% | Api::V0::ArticlesController#create 34%, Api::V1::ArticlesController#create 34%, ArticlesController#create 32% | `return with_deadlock_retry { @article.save }` |
| 29 | `app/controllers/stories_controller.rb:186` | `handle_user_or_organization_or_podcast_or_page_index` | 20.05 | 2.12 | 0.13 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 13%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:864` 13%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:191` 2% | StoriesController#index 100% | `if (@user = User.includes(:profile, :setting, :roles).find_by(username` |
| 30 | `app/views/layouts/_footer.html.erb:3` |  | 19.7 | 4.82 | 0.04 | `RAILS/activerecord/lib/active_record/relation.rb:98` 3%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:235` 2%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 2% | StoriesController#index 18%, StoriesController#show 10%, NotificationsController#index 6% | `default_nav_ids: NavigationLink.from_subforem.default_section.ordered.` |

App middleware that hands the request on (the stack below it, not its own work): `app/lib/middlewares/set_time_zone.rb:10` 910.06, `app/lib/middlewares/restore_original_host.rb:27` 888.66 warm objects per request.

39.2 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | Admin::SettingsController#show | 4 / 4 | 142984.0 / 143040.7 | 56.7 | 148909.3 | `GEM/i18n/lib/i18n.rb:397` 12598.7, `GEM/i18n/lib/i18n/backend/fallbacks.rb:54` 12374.7, `GEM/i18n/lib/i18n/backend/fallbacks.rb:60` 12262.7 | `app/views/admin/settings/forms/_rate_limit.html.erb:24` 3958.3, `app/helpers/application_helper.rb:518` 2768.3, `app/helpers/admin/settings_helper.rb:26` 1894.0 |
| 2 | Admin::ArticlesController#index | 14 / 14 | 61187.1 / 61188.2 | 1.1 | 58046.4 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:311` 3172.2, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` 2954.9, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` 2938.9 | `app/views/admin/articles/_article_item.html.erb:224` 25089.4, `app/controllers/admin/articles_controller.rb:51` 1657.4, `app/lib/middlewares/set_time_zone.rb:10` 1064.7 |
| 3 | Admin::BulkAssignRoleController#assign_role | 10 / 10 | 38688.9 / 38685.0 | -3.9 | 39716.8 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 888.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:864` 842.4, `GEM/mail/lib/mail/utilities.rb:215` 541.7 | `app/policies/authorizer.rb:225` 5158.6, `app/mailers/notify_mailer.rb:367` 2364.0, `app/services/tag_moderators/add_trusted_role.rb:8` 2258.7 |
| 4 | CommentsController#update | 5 / 5 | 32036.8 / 32093.3 | 56.5 | 30617.8 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 736.8, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:864` 715.8, `RAILS/activemodel/lib/active_model/attribute.rb:9` 587.3 | `app/lib/middlewares/restore_original_host.rb:27` 1439.0, `app/queries/comments/tree.rb:70` 1279.0, `app/controllers/comments_controller.rb:152` 1252.3 |
| 5 | ArticlesController#update | 44 / 44 | 31513.7 / 31515.3 | 1.6 | 31684.4 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 632.8, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:864` 604.6, `GEM/psych/lib/psych/tree_builder.rb:97` 488.2 | `app/services/articles/updater.rb:47` 3178.2, `app/policies/authorizer.rb:229` 2432.3, `app/policies/authorizer.rb:225` 2328.8 |
| 6 | Admin::UsersController#show | 48 / 48 | 30801.3 / 30805.4 | 4.2 | 30971.8 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 473.1, `RAILS/activesupport/lib/active_support/inflector/methods.rb:146` 363.2, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 328.2 | `app/policies/authorizer.rb:225` 1528.3, `app/lib/middlewares/restore_original_host.rb:27` 1501.2, `app/lib/middlewares/set_time_zone.rb:10` 1066.3 |
| 7 | TagAdjustmentsController#create | 9 / 9 | 30621.8 / 30677.4 | 55.6 | 31402.8 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 805.8, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:864` 774.9, `RAILS/activemodel/lib/active_model/attribute.rb:9` 544.9 | `config/initializers/timeout.rb:232` 1768.9, `app/services/tag_adjustment_creation_service.rb:27` 1619.3, `app/lib/middlewares/restore_original_host.rb:27` 1497.4 |
| 8 | OrganizationSettingsController#edit | 10 / 10 | 29879.1 / 29941.6 | 62.4 | 28829.2 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 482.2, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 348.6, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:864` 333.9 | `app/lib/middlewares/restore_original_host.rb:27` 1280.6, `app/lib/middlewares/set_time_zone.rb:10` 1056.8, `app/policies/authorizer.rb:229` 577.2 |
| 9 | Admin::UsersController#index | 10 / 10 | 29725.0 / 29724.9 | -0.1 | 31226.4 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 472.9, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:311` 428.9, `RAILS/activesupport/lib/active_support/inflector/methods.rb:146` 354.0 | `app/views/admin/users/index/_filters_modal.html.erb:33` 1200.0, `app/lib/middlewares/set_time_zone.rb:10` 1079.9, `app/lib/middlewares/restore_original_host.rb:27` 986.6 |
| 10 | CommentsController#create | 25 / 25 | 29199.3 / 29211.0 | 11.8 | 29292.6 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 737.1, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:864` 701.8, `RAILS/activemodel/lib/active_model/attribute.rb:9` 543.7 | `app/policies/authorizer.rb:225` 2454.4, `app/lib/middlewares/restore_original_host.rb:27` 1612.8, `app/policies/authorizer.rb:229` 1492.3 |
| 11 | DashboardsController#feed_imports | 12 / 12 | 28321.0 / 28364.0 | 43.0 | 26740.5 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 396.5, `RAILS/activesupport/lib/active_support/core_ext/string/filters.rb:22` 333.0, `GEM/hashie/lib/hashie/mash.rb:374` 242.0 | `app/lib/middlewares/set_time_zone.rb:10` 1008.3, `app/lib/middlewares/restore_original_host.rb:27` 912.5, `config/initializers/warden_hooks.rb:13` 588.3 |
| 12 | Admin::ArticlesController#unfavorite | 2 / 2 | 28018.0 / 28007.0 | -11.0 | 25376.5 | `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/collection/map/non_concurrent_map_backend.rb:131` 5422.0, `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/map.rb:245` 5416.0, `RAILS/activemodel/lib/active_model/attribute.rb:9` 368.0 | `app/lib/middlewares/restore_original_host.rb:27` 13565.0, `app/lib/middlewares/set_time_zone.rb:10` 1237.0, `config/initializers/warden_hooks.rb:13` 1146.0 |
| 13 | ModerationsController#actions_panel | 8 / 8 | 28005.3 / 28013.3 | 8.0 | 30127.1 | `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/collection/map/non_concurrent_map_backend.rb:131` 2430.6, `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/map.rb:245` 2428.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 293.1 | `app/lib/middlewares/restore_original_host.rb:27` 6058.0, `app/lib/middlewares/set_time_zone.rb:10` 1090.0, `app/policies/authorizer.rb:225` 574.0 |
| 14 | Api::V0::InstancesController#show | 4 / 4 | 27698.0 / 27698.0 | 0.0 | 28451.8 | `GEM/hashie/lib/hashie/mash.rb:374` 242.0, `GEM/hashie/lib/hashie/mash.rb:410` 158.0, `GEM/hashie/lib/hashie/mash.rb:369` 158.0 | `app/lib/middlewares/set_time_zone.rb:10` 1080.7, `app/lib/middlewares/restore_original_host.rb:27` 292.3, `app/models/settings/base.rb:198` 191.3 |
| 15 | Api::V1::InstancesController#show | 6 / 6 | 27655.0 / 27655.2 | 0.2 | 25169.0 | `GEM/hashie/lib/hashie/mash.rb:374` 242.0, `GEM/hashie/lib/hashie/mash.rb:410` 158.0, `GEM/hashie/lib/hashie/mash.rb:369` 158.0 | `app/lib/middlewares/set_time_zone.rb:10` 1031.0, `app/lib/middlewares/restore_original_host.rb:27` 291.2, `app/models/settings/base.rb:198` 213.2 |
| 16 | ArticlesController#admin_unpublish | 3 / 3 | 27287.5 / 27314.0 | 26.5 | 27272.0 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 589.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 503.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:864` 481.5 | `app/services/articles/updater.rb:47` 3051.0, `app/lib/middlewares/restore_original_host.rb:27` 1428.5, `app/lib/middlewares/set_time_zone.rb:10` 1053.5 |
| 17 | Admin::FeedbackMessagesController#index | 8 / 8 | 27133.3 / 27134.1 | 0.9 | 27381.3 | `RAILS/actionview/lib/action_view/buffers.rb:48` 465.6, `RAILS/activesupport/lib/active_support/inflector/methods.rb:146` 383.1, `GEM/i18n/lib/i18n/interpolate/ruby.rb:33` 380.1 | `app/lib/middlewares/restore_original_host.rb:27` 1521.9, `app/lib/middlewares/set_time_zone.rb:10` 1065.7, `app/views/admin/shared/_nested_sidebar.html.erb:26` 954.0 |
| 18 | StoriesController#show | 138 / 138 | 26685.0 / 26716.5 | 31.5 | 26849.2 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 401.9, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:864` 384.4, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 257.6 | `app/controllers/stories_controller.rb:98` 1615.2, `app/lib/middlewares/set_time_zone.rb:10` 1033.8, `app/lib/middlewares/restore_original_host.rb:27` 824.1 |
| 19 | Admin::RequestRedirectsController#create | 2 / 2 | 26626.0 / 26632.0 | 6.0 | 19524.0 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 420.0, `GEM/i18n/lib/i18n.rb:397` 378.0, `RAILS/activesupport/lib/active_support/core_ext/string/filters.rb:22` 333.0 | `app/lib/middlewares/restore_original_host.rb:27` 1495.0, `app/views/admin/request_redirects/_form.html.erb:6` 1407.0, `app/lib/middlewares/set_time_zone.rb:10` 1112.0 |
| 20 | Admin::EventsController#show | 5 / 5 | 26559.8 / 26539.8 | -20.0 | 26687.0 | `RAILS/activesupport/lib/active_support/core_ext/string/filters.rb:22` 396.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 360.5, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:864` 339.0 | `app/lib/middlewares/restore_original_host.rb:27` 1314.8, `app/lib/middlewares/set_time_zone.rb:10` 1038.8, `app/views/admin/events/show.html.erb:19` 608.0 |
| 21 | Admin::Tags::ModeratorsController#create | 4 / 4 | 26405.3 / 26391.7 | -13.7 | 23668.0 | `GEM/mail/lib/mail/utilities.rb:215` 500.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 403.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:864` 380.7 | `app/models/user.rb:1157` 1874.0, `app/lib/middlewares/restore_original_host.rb:27` 1468.0, `app/lib/middlewares/set_time_zone.rb:10` 1108.0 |
| 22 | Admin::EventsController#index | 8 / 8 | 26197.3 / 26197.0 | -0.3 | 26013.4 | `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/collection/map/non_concurrent_map_backend.rb:131` 760.7, `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/map.rb:245` 757.7, `RAILS/activesupport/lib/active_support/core_ext/string/filters.rb:22` 285.4 | `app/lib/middlewares/restore_original_host.rb:27` 2948.4, `app/lib/middlewares/set_time_zone.rb:10` 1068.7, `config/initializers/warden_hooks.rb:13` 579.6 |
| 23 | Admin::BillboardCampaignsController#index | 6 / 6 | 26096.2 / 26093.6 | -2.6 | 25641.8 | `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/collection/map/non_concurrent_map_backend.rb:131` 670.6, `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/map.rb:245` 667.2, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 622.0 | `app/lib/middlewares/restore_original_host.rb:27` 2732.6, `app/lib/middlewares/set_time_zone.rb:10` 1108.4, `app/views/admin/shared/_nested_sidebar.html.erb:26` 763.2 |
| 24 | Admin::EventsController#new | 3 / 3 | 25932.0 / 25930.5 | -1.5 | 25653.7 | `RAILS/activesupport/lib/active_support/core_ext/string/filters.rb:22` 333.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:311` 279.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 263.5 | `app/lib/middlewares/restore_original_host.rb:27` 1535.0, `app/lib/middlewares/set_time_zone.rb:10` 1062.0, `config/initializers/warden_hooks.rb:13` 574.0 |
| 25 | Admin::ArticlesController#show | 3 / 3 | 25821.0 / 25820.0 | -1.0 | 26717.3 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 408.5, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:864` 395.0, `RAILS/activesupport/lib/active_support/inflector/methods.rb:146` 354.0 | `app/controllers/admin/articles_controller.rb:58` 2230.0, `app/views/admin/articles/_article_item.html.erb:224` 2070.0, `app/lib/middlewares/restore_original_host.rb:27` 1113.5 |
| 26 | Admin::CreatorSettingsController#new | 8 / 8 | 25572.1 / 25571.3 | -0.9 | 26387.3 | `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/collection/map/non_concurrent_map_backend.rb:131` 618.1, `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/map.rb:245` 614.9, `RAILS/activesupport/lib/active_support/core_ext/string/filters.rb:22` 285.4 | `app/lib/middlewares/restore_original_host.rb:27` 2639.1, `app/lib/middlewares/set_time_zone.rb:10` 1085.3, `config/initializers/warden_hooks.rb:13` 831.1 |
| 27 | ArticlesController#new | 15 / 15 | 25297.3 / 25344.2 | 46.9 | 26095.4 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 315.8, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:864` 302.6, `RAILS/activesupport/lib/active_support/core_ext/string/filters.rb:22` 285.4 | `app/lib/middlewares/restore_original_host.rb:27` 1452.9, `app/lib/middlewares/set_time_zone.rb:10` 1001.8, `app/policies/authorizer.rb:229` 639.1 |
| 28 | UsersController#edit | 49 / 49 | 25266.5 / 25270.3 | 3.8 | 25411.2 | `RAILS/activesupport/lib/active_support/core_ext/string/filters.rb:22` 312.2, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 291.0, `GEM/hashie/lib/hashie/mash.rb:374` 252.7 | `app/lib/middlewares/restore_original_host.rb:27` 1350.4, `app/lib/middlewares/set_time_zone.rb:10` 1016.3, `config/initializers/warden_hooks.rb:13` 564.6 |
| 29 | DashboardsController#show | 26 / 26 | 25220.9 / 25264.9 | 44.0 | 25620.3 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 285.1, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 266.8, `RAILS/activesupport/lib/active_support/core_ext/string/filters.rb:22` 266.4 | `app/lib/middlewares/restore_original_host.rb:27` 1696.4, `app/lib/middlewares/set_time_zone.rb:10` 1014.1, `config/initializers/warden_hooks.rb:13` 655.6 |
| 30 | DashboardsController#followers | 2 / 2 | 25102.0 / 25215.0 | 113.0 | 17057.0 | `RAILS/activesupport/lib/active_support/core_ext/string/filters.rb:22` 370.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` 329.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:864` 316.0 | `app/lib/middlewares/restore_original_host.rb:27` 1501.0, `app/lib/middlewares/set_time_zone.rb:10` 1011.0, `app/controllers/dashboards_controller.rb:108` 731.0 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/hashie/lib/hashie/mash.rb:374` | `convert_key` | 230.96 / 230.96 | 0.0 | 230.99 | 95% | String, Array |  | `app/lib/middlewares/set_time_zone.rb:10` 100%, `app/models/identity.rb:44` 0% | `key.respond_to?(:to_sym) ? key.to_s : key` |
| 2 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:179` | `cast_result` | 202.14 / 202.14 | 0.0 | 202.14 | 99% | String, Array |  | `config/initializers/timeout.rb:232` 37%, `app/lib/middlewares/restore_original_host.rb:27` 16% | `if result.fields.empty?` |
| 3 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:864` | `get_oid_type` | 192.69 / 192.69 | 0.0 | 192.69 | 99% | Array |  | `config/initializers/timeout.rb:232` 37%, `app/lib/middlewares/restore_original_host.rb:27` 17% | `type_map.fetch(oid, fmod, sql_type) {` |
| 4 | `GEM/hashie/lib/hashie/mash.rb:369` | `method_suffix` | 150.74 / 150.74 | 0.0 | 150.76 | 95% | String |  | `app/lib/middlewares/set_time_zone.rb:10` 100%, `app/models/identity.rb:44` 0% | `method_name = method_name.to_s` |
| 5 | `GEM/hashie/lib/hashie/mash.rb:410` | `log_collision?` | 150.73 / 150.73 | 0.0 | 150.75 | 95% | Array |  | `app/lib/middlewares/set_time_zone.rb:10` 100%, `app/models/identity.rb:44` 0% | `return unless respond_to?(method_key)` |
| 6 | `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/collection/map/non_concurrent_map_backend.rb:131` | `dupped_backend` | 130.95 / 130.95 | 0.0 | 130.95 | 100% | Hash, Array |  | `app/lib/middlewares/restore_original_host.rb:27` 99%, `config/initializers/warden_hooks.rb:13` 0% | `@backend.dup` |
| 7 | `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/map.rb:245` | `values` | 128.25 / 128.25 | 0.0 | 128.27 | 5% | Array |  | `app/lib/middlewares/restore_original_host.rb:27` 100% | `arr = []` |
| 8 | `RAILS/activemodel/lib/active_model/attribute.rb:9` | `from_database` | 107.61 / 107.61 | 0.0 | 107.64 | 72% | Object |  | `config/initializers/warden_hooks.rb:13` 40%, `app/lib/middlewares/restore_original_host.rb:27` 30% | `FromDatabase.new(name, value_before_type_cast, type, nil, value)` |
| 9 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | `#{method}` | 85.8 / 85.8 | 0.0 | 85.8 | 100% | Array, Hash |  | `config/initializers/0_application_config.rb:23` 19%, `app/lib/middlewares/set_time_zone.rb:10` 10% | `dispatch(:#{method}, ...)` |
| 10 | `RAILS/activesupport/lib/active_support/callbacks.rb:361` | `make_lambda` | 82.36 / 82.36 | 0.0 | 82.39 | 54% | Array, Hash |  | `config/initializers/warden_hooks.rb:13` 49%, `app/lib/middlewares/restore_original_host.rb:27` 37% | `target.send(@method_name, &block)` |
| 11 | `RAILS/activemodel/lib/active_model/attribute_mutation_tracker.rb:29` | `changes` | 63.79 / 63.79 | 0.0 | 63.81 | 50% | Hash, Array |  | `app/models/user.rb:337` 51%, `app/models/user.rb:873` 18% | `result.merge!(attr_name => change)` |
| 12 | `GEM/timecop/lib/timecop/time_extensions.rb:14` † | `now_with_mock_time` | 60.96 / 60.96 | 0.0 | 60.96 | 95% | Data |  | `lib/memory_first_cache.rb:25` 14%, `app/lib/middlewares/restore_original_host.rb:27` 10% | `mock_time \|\| now_without_mock_time` |
| 13 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:235` | `initialize` | 53.16 / 53.16 | 0.0 | 53.17 | 100% | Object |  | `app/models/settings/base.rb:198` 12%, `config/initializers/timeout.rb:232` 10% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 14 | `RAILS/actionpack/lib/abstract_controller/base.rb:100` | `action_methods` | 52.32 / 52.32 | 0.0 | 52.34 | 4% | String, Array |  | `app/lib/middlewares/set_time_zone.rb:10` 98%, `app/lib/middlewares/restore_original_host.rb:27` 0% | `methods.map!(&:to_s)` |
| 15 | `RUBY/set.rb:501` | `each` | 49.86 / 49.86 | 0.0 | 50.06 | 4% | String |  | `app/lib/middlewares/set_time_zone.rb:10` 98%, `app/controllers/organizations_controller.rb:192` 0% | `@hash.each_key(&block)` |
| 16 | `RAILS/activerecord/lib/arel/visitors/postgresql.rb:81` | `visit_Arel_Nodes_IsDistinctFrom` | 46.91 / 46.91 | 0.0 | 46.91 | 96% | String, Array |  | `config/initializers/warden_hooks.rb:13` 12%, `app/lib/middlewares/restore_original_host.rb:27` 9% | `BIND_BLOCK = proc { \|i\| "$#{i}" }` |
| 17 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:191` | `cast_result` | 46.85 / 46.85 | 0.0 | 46.85 | 99% | String, Array |  | `config/initializers/timeout.rb:232` 26%, `app/controllers/api/v1/api_controller.rb:174` 10% | `ar_result = ActiveRecord::Result.new(fields, result.values, types.free` |
| 18 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` | `extract_non_symbol_default!` | 46.37 / 46.37 | 0.0 | 46.38 | 28% | Array, Hash | ruby-i18n/i18n#764 open upstream work | `app/views/layouts/_footer.html.erb:21` 3%, `app/views/layouts/_logo.html.erb:1` 2% | `defaults = [options[:default]].flatten` |
| 19 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:140` | `create` | 45.03 / 45.03 | 0.0 | 45.04 | 99% | Array, Object |  | `app/policies/authorizer.rb:229` 13%, `app/models/settings/base.rb:217` 10% | `relation_class_for(model).new(model, ...)` |
| 20 | `RAILS/activerecord/lib/arel/table.rb:85` | `[]` | 44.17 / 44.17 | -0.0 | 44.17 | 99% | Struct, Array |  | `app/models/settings/base.rb:198` 10%, `config/initializers/warden_hooks.rb:13` 7% | `Attribute.new(table, name)` |
| 21 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:205` | `groups_for` | 41.46 / 41.46 | 0.0 | 41.46 | 99% | Array |  | `app/models/settings/base.rb:198` 10%, `app/lib/middlewares/set_time_zone.rb:10` 9% | `groups[group_class] = (groups[group_class] \|\| []) + active_subscriptio` |
| 22 | `GEM/hashie/lib/hashie/mash.rb:101` | `initialize` | 39.1 / 39.1 | 0.0 | 39.11 | 95% | Array |  | `app/lib/middlewares/set_time_zone.rb:10` 100%, `app/services/authentication/providers/provider.rb:41` 0% | `deep_update(source_hash) if source_hash` |
| 23 | `RAILS/actionview/lib/action_view/buffers.rb:48` | `<<` | 39.09 / 39.09 | 0.0 | 39.1 | 25% | String |  | `app/views/admin/shared/_nested_sidebar.html.erb:26` 17%, `app/views/admin/shared/_nested_sidebar.html.erb:31` 6% | `CGI.escapeHTML(value)` |
| 24 | `GEM/hashie/lib/hashie/mash.rb:196` | `dup` | 39.08 / 39.08 | 0.0 | 39.09 | 95% | Hash |  | `app/lib/middlewares/set_time_zone.rb:10` 100%, `app/services/authentication/providers/provider.rb:41` 0% | `self.class.new(self, default, &default_proc)` |
| 25 | `RAILS/activerecord/lib/arel/visitors/to_sql.rb:802` | `visit_Arel_Nodes_BoundSqlLiteral` | 37.76 / 37.76 | 0.0 | 37.77 | 60% | String, MatchData |  | `app/policies/authorizer.rb:229` 33%, `app/policies/authorizer.rb:225` 20% | `o.sql_with_placeholders.scan(/\?\|([^?]+)/) do` |
| 26 | `GEM/i18n/lib/i18n.rb:397` | `normalize_keys` | 34.91 / 34.91 | 0.0 | 34.92 | 51% | Array |  | `app/views/layouts/_footer.html.erb:21` 2%, `app/views/layouts/_logo.html.erb:1` 1% | `*normalize_key(locale, separator),` |
| 27 | `RAILS/activesupport/lib/active_support/cache/memory_store.rb:47` | `load` | 34.12 / 34.12 | 0.0 | 34.12 | 97% | Hash, Object |  | `lib/memory_first_cache.rb:25` 99%, `app/models/settings/base.rb:194` 1% | `Cache::Entry.new(load_value(entry.value), expires_at: entry.expires_at` |
| 28 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:54` | `translate` | 33.8 / 33.8 | 0.0 | 33.8 | 51% | Hash | ruby-i18n/i18n#765 open upstream work | `app/views/layouts/_footer.html.erb:21` 2%, `app/views/layouts/_logo.html.erb:1` 1% | `fallback_options = options.merge(:fallback_in_progress => true, fallba` |
| 29 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:311` | `tag_option` | 33.49 / 33.49 | 0.0 | 33.5 | 24% | String |  | `app/views/admin/articles/_article_item.html.erb:224` 16%, `app/views/articles/_reaction_category_resources.html.erb:3` 15% | `%(#{key}="#{value}")` |
| 30 | `RAILS/activerecord/lib/active_record/attribute_methods/time_zone_conversion.rb:14` | `deserialize` | 33.22 / 33.22 | 0.0 | 33.23 | 72% | Array |  | `app/models/user.rb:337` 38%, `app/models/user.rb:873` 13% | `convert_time_to_time_zone(super)` |

## Dev/test-mode work

6939.8 of 14264.8 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | reload check | `RAILS/activesupport/lib/active_support/file_update_checker.rb:132` | 3676.0 | 100% | `app/lib/middlewares/restore_original_host.rb:27` 100%, `app/models/user.rb:1240` 0% | `mtime = File.mtime(path)` |
| 2 | reload check | `RAILS/activesupport/lib/active_support/file_update_checker.rb:106` † | 1892.0 | 100% | `app/lib/middlewares/restore_original_host.rb:27` 100%, `app/models/user.rb:1240` 0% | `all.concat(Dir[@glob]) if @glob` |
| 3 | reload check | `RAILS/activesupport/lib/active_support/file_update_checker.rb:105` | 373.0 | 100% | `app/lib/middlewares/restore_original_host.rb:27` 100%, `app/models/user.rb:1240` 0% | `all = @files.select { \|f\| File.exist?(f) }` |
| 4 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` | 87.39 | 98% | `config/initializers/timeout.rb:232` 13%, `config/initializers/warden_hooks.rb:13` 11% | `binds = binds.inspect` |
| 5 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:183` | 83.26 | 99% | `app/models/settings/base.rb:198` 15%, `config/initializers/timeout.rb:232` 13% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 6 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:181` | 55.78 | 99% | `app/models/settings/base.rb:198` 15%, `config/initializers/timeout.rb:232` 13% | `modes = MODES.values_at(*options.compact_blank.keys)` |
| 7 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:176` | 55.77 | 99% | `app/models/settings/base.rb:198` 15%, `config/initializers/timeout.rb:232` 13% | `clear = "\e[#{MODES[:clear]}m"` |
| 8 | debug logging | `GEM/logger/lib/logger/log_device.rb:33` | 54.54 | 100% | `config/initializers/0_application_config.rb:23` 19%, `app/lib/middlewares/set_time_zone.rb:10` 10% | `handle_write_errors("writing") {@dev.write(message)}` |
| 9 | debug logging | `GEM/logger/lib/logger/log_device.rb:165` | 28.58 | 100% | `config/initializers/0_application_config.rb:23` 19%, `app/lib/middlewares/set_time_zone.rb:10` 10% | `if @filename && (@shift_age > 0) && (@dev.stat.size > @shift_size)` |
| 10 | debug logging | `RAILS/activesupport/lib/active_support/logger.rb:42` | 28.58 | 100% | `config/initializers/0_application_config.rb:23` 19%, `app/lib/middlewares/set_time_zone.rb:10` 10% | `"#{String === msg ? msg : msg.inspect}\n"` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activesupport | 7714.5 | 7717.6 | `file_update_checker.rb:132` 3676.0, `file_update_checker.rb:106` 1892.0, `file_update_checker.rb:105` 373.0 |
| rails: activerecord | 2446.6 | 2448.1 | `database_statements.rb:179` 202.1, `postgresql_adapter.rb:864` 192.7, `log_subscriber.rb:49` 87.4 |
| app | 1029.7 | 1048.8 | `subforem.rb:130` 145.2, `subforem.rb:129` 145.2, `subforem.rb:131` 145.2 |
| gem: hashie | 641.2 | 641.3 | `mash.rb:374` 231.0, `mash.rb:369` 150.7, `mash.rb:410` 150.7 |
| rails: actionpack | 573.9 | 590.0 | `base.rb:100` 52.3, `visitors.rb:40` 18.4, `exception_wrapper.rb:263` 15.6 |
| rails: actionview | 481.0 | 482.3 | `buffers.rb:48` 39.1, `tag_helper.rb:311` 33.5, `template.rb:508` 20.8 |
| rails: activemodel | 387.2 | 389.3 | `attribute.rb:9` 107.6, `attribute_mutation_tracker.rb:29` 63.8, `string.rb:35` 30.1 |
| test harness: rspec-mocks | 307.7 | 307.8 | `recorder.rb:135` 56.5, `argument_list_matcher.rb:97` 24.0, `argument_list_matcher.rb:96` 18.0 |
| gem: concurrent-ruby | 276.7 | 276.7 | `non_concurrent_map_backend.rb:131` 131.0, `map.rb:245` 128.3, `safe_initialization.rb:30` 6.0 |
| gem: i18n | 264.7 | 264.8 | `fallbacks.rb:98` 46.4, `i18n.rb:397` 34.9, `fallbacks.rb:54` 33.8 |
| ruby stdlib | 188.9 | 189.2 | `set.rb:501` 49.9, `ipaddr.rb:659` 22.8, `formatter.rb:174` 14.4 |
| gem: rack | 168.5 | 168.8 | `request.rb:515` 28.1, `utils.rb:511` 20.7, `utils.rb:642` 14.9 |
| gem: sprockets | 110.8 | 114.0 | `path_utils.rb:164` 10.5, `path_utils.rb:234` 8.4, `path_utils.rb:58` 5.6 |
| ruby default gem: logger | 104.0 | 104.0 | `log_device.rb:33` 49.7, `log_device.rb:165` 28.6, `logger.rb:685` 25.6 |
| test harness: rspec-support | 90.1 | 90.1 | `fuzzy_matcher.rb:32` 22.0, `method_signature_verifier.rb:110` 15.8, `method_signature_verifier.rb:285` 6.2 |
| ruby default gem: psych | 83.7 | 83.9 | `tree_builder.rb:97` 13.1, `parser.rb:62` 9.0, `yaml_tree.rb:72` 7.5 |
| gem: flipper | 67.8 | 67.9 | `wrapper.rb:32` 8.4, `feature.rb:115` 6.4, `memoizable.rb:97` 3.8 |
| gem: timecop | 65.6 | 65.7 | `time_extensions.rb:14` 61.0, `time_stack_item.rb:78` 2.6, `time_extensions.rb:145` 1.2 |
| gem: warden | 60.5 | 60.5 | `proxy.rb:334` 8.9, `proxy.rb:348` 8.5, `proxy.rb:349` 4.3 |
| gem: device_detector | 56.9 | 76.4 | `device_detector.rb:306` 19.1, `memory_cache.rb:33` 15.9, `parser.rb:110` 4.8 |
| gem: omniauth | 55.7 | 55.7 | `strategy.rb:470` 13.5, `strategy.rb:169` 13.3, `strategy.rb:449` 7.7 |
| gem: carrierwave | 45.4 | 45.6 | `sanitized_file.rb:90` 7.2, `url.rb:24` 3.0, `mounter.rb:151` 2.7 |
| gem: devise | 36.9 | 37.0 | `helpers.rb:128` 8.2, `orm.rb:41` 7.7, `rememberable.rb:56` 5.7 |
| gem: mail | 36.9 | 38.1 | `utilities.rb:215` 4.5, `parameter_hash.rb:22` 2.6, `field_list.rb:71` 2.2 |
| gem: sprockets-rails | 34.8 | 34.8 | `helper.rb:81` 20.2, `helper.rb:158` 2.2, `helper.rb:219` 2.1 |
| gem: nokogiri | 34.2 | 34.3 | `node.rb:1429` 3.3, `node.rb:66` 2.0, `document.rb:416` 1.8 |
| gem: honeybadger | 33.4 | 33.5 | `notice.rb:69` 5.5, `notice.rb:211` 5.4, `request_hash.rb:65` 3.9 |
| gem: tzinfo | 32.1 | 32.1 | `timestamp.rb:208` 14.7, `timestamp.rb:193` 7.8, `transitions_data_timezone_info.rb:66` 6.3 |
| ruby default gem: uri | 30.8 | 30.9 | `common.rb:465` 13.1, `rfc2396_parser.rb:291` 2.9, `rfc2396_parser.rb:320` 2.9 |
| gem: rolify | 22.7 | 22.7 | `role_adapter.rb:102` 2.2, `rolify.rb:39` 1.9, `role_adapter.rb:100` 1.7 |
| gem: rails-controller-testing | 21.4 | 21.4 | `template_assertions.rb:39` 14.5, `template_assertions.rb:35` 6.1, `template_assertions.rb:27` 0.5 |
| gem: acts-as-taggable-on | 19.3 | 19.4 | `acts-as-taggable-on.rb:29` 3.6, `default_parser.rb:74` 1.6, `default_parser.rb:59` 1.6 |
| gem: inline_svg | 18.1 | 18.2 | `id_generator.rb:14` 6.6, `id_generator.rb:13` 4.0, `transformations.rb:54` 1.6 |
| gem: erubi | 18.0 | 18.3 | `erubi.rb:134` 10.3, `erubi.rb:137` 2.4, `erubi.rb:139` 1.5 |
| gem: fakeredis | 14.2 | 14.2 | `expiring_hash.rb:53` 3.4, `command_executor.rb:4` 2.7, `command_executor.rb:5` 1.4 |
| rails: railties | 12.2 | 12.2 | `logger.rb:57` 3.2, `finisher.rb:194` 2.0, `engine.rb:749` 1.0 |
| gem: ahoy_matey | 11.7 | 11.7 | `tracker.rb:10` 4.2, `controller.rb:13` 2.8, `warden.rb:3` 1.4 |
| gem: addressable | 7.8 | 7.9 | `uri.rb:136` 0.7, `uri.rb:486` 0.3, `uri.rb:2497` 0.3 |
| gem: redis-store | 7.3 | 7.3 | `serialization.rb:57` 2.0, `namespace.rb:58` 1.7, `serialization.rb:40` 0.8 |
| gem: sidekiq | 7.3 | 7.3 | `worker.rb:289` 0.9, `chain.rb:175` 0.6, `job_util.rb:11` 0.6 |
| gem: cloudinary | 6.4 | 6.4 | `helper.rb:375` 6.4 |
| ruby default gem: securerandom | 5.0 | 5.0 | `securerandom.rb:71` 5.0 |
| gem: stripe | 4.9 | 5.1 | `stripe_object.rb:351` 1.1, `stripe_object.rb:546` 0.8, `stripe_object.rb:348` 0.7 |
| gem: debug | 4.1 | 4.2 | `thread_client.rb:901` 0.9, `thread_client.rb:223` 0.9, `thread_client.rb:234` 0.9 |
| gem: rack-cors | 3.8 | 3.8 | `cors.rb:123` 1.5, `result.rb:38` 1.0, `cors.rb:129` 1.0 |
| gem: redis | 3.6 | 3.6 | `keys.rb:192` 1.7, `client.rb:161` 1.4, `strings.rb:108` 0.4 |
| test harness: webmock | 3.2 | 3.3 | `headers.rb:69` 0.5, `headers.rb:68` 0.4, `uri.rb:62` 0.2 |
| gem: redis-rack | 3.1 | 3.1 | `redis.rb:37` 0.9, `redis.rb:42` 0.5, `redis.rb:58` 0.4 |
| gem: request_store | 2.7 | 2.7 | `middleware.rb:21` 1.0, `middleware.rb:28` 1.0, `request_store.rb:15` 0.8 |
| gem: counter_culture | 2.7 | 2.8 | `extensions.rb:8` 0.3, `counter.rb:265` 0.3, `counter.rb:248` 0.3 |
| gem: loofah | 2.5 | 2.5 | `scrubber.rb:132` 0.7, `concerns.rb:172` 0.7, `concerns.rb:43` 0.5 |
| gem: pundit | 2.2 | 2.2 | `policy_finder.rb:85` 0.7, `authorization.rb:140` 0.4, `pundit.rb:81` 0.2 |
| ruby default gem: base64 | 2.2 | 2.2 | `base64.rb:283` 2.0, `base64.rb:310` 0.1, `base64.rb:374` 0.1 |
| gem: neighbor | 2.2 | 2.4 | `vector.rb:19` 1.7, `vector.rb:10` 0.3, `model.rb:21` 0.1 |
| gem: liquid | 2.1 | 2.1 | `parse_context.rb:27` 0.2, `tokenizer.rb:31` 0.1, `context.rb:29` 0.1 |
| gem: ransack | 1.9 | 2.0 | `join_dependency.rb:5` 0.8, `join_dependency.rb:25` 0.1, `join_dependency.rb:41` 0.1 |
| gem: orm_adapter | 1.8 | 1.8 | `base.rb:100` 0.4, `active_record.rb:44` 0.4, `base.rb:105` 0.4 |
| gem: redis-actionpack | 1.6 | 1.6 | `redis_store.rb:22` 0.8, `redis_store.rb:43` 0.4, `redis_store.rb:29` 0.4 |
| gem: kaminari-core | 1.4 | 1.4 | `page_scope_methods.rb:10` 0.5, `page_scope_methods.rb:8` 0.2, `helper_methods.rb:120` 0.1 |
| gem: jbuilder | 1.3 | 1.3 | `jbuilder.rb:304` 0.6, `jbuilder_template.rb:58` 0.2, `jbuilder_template.rb:150` 0.2 |
| gem: bootsnap | 1.2 | 9.6 | `iseq.rb:53` 0.4, `kernel_require.rb:30` 0.4, `yaml.rb:210` 0.2 |
| gem: rails-html-sanitizer | 1.1 | 1.1 | `sanitizer.rb:191` 0.2, `sanitizer.rb:33` 0.2, `sanitizer.rb:56` 0.2 |
| gem: sterile | 1.1 | 1.1 | `utilities.rb:37` 0.3, `tags.rb:36` 0.2, `tags.rb:33` 0.2 |
| ruby default gem: openssl | 1.1 | 1.1 | `hmac.rb:57` 0.5, `hmac.rb:55` 0.5, `hmac.rb:38` 0.1 |
| gem: fastimage | 1.0 | 1.0 | `fastimage.rb:397` 0.1, `fiber_stream.rb:19` 0.1, `fastimage.rb:252` 0.1 |
| gem: i18n-js | 1.0 | 1.0 | `js.rb:185` 0.2, `js.rb:223` 0.2, `js.rb:186` 0.2 |
| gem: amazing_print | 0.8 | 0.8 | `class.rb:19` 0.4, `class.rb:21` 0.2, `awesome_method_array.rb:19` 0.1 |
| test harness: vcr | 0.8 | 0.8 | `request_handler.rb:80` 0.1, `structs.rb:148` 0.1, `structs.rb:305` 0.1 |
| gem: ancestry | 0.7 | 0.7 | `materialized_path.rb:122` 0.2, `materialized_path.rb:120` 0.1, `class_methods.rb:48` 0.1 |
| rails: actionmailer | 0.6 | 0.7 | `rescuable.rb:23` 0.1, `base.rb:998` 0.1, `base.rb:1049` 0.0 |
| gem: validate_url | 0.5 | 0.5 | `validate_url.rb:57` 0.4, `validate_url.rb:22` 0.1, `validate_url.rb:59` 0.0 |
| gem: zeitwerk | 0.5 | 0.5 | `cref.rb:47` 0.1, `file_system.rb:203` 0.1, `constant_path_validator.rb:13` 0.1 |
| gem: builder | 0.4 | 0.6 | `xchar.rb:155` 0.1, `xchar.rb:156` 0.1, `xchar.rb:154` 0.1 |
| gem: ahoy_email | 0.4 | 0.4 | `processor.rb:115` 0.1, `processor.rb:28` 0.1, `processor.rb:11` 0.0 |
| gem: rack-attack | 0.3 | 0.4 | `cache.rb:73` 0.2, `cache.rb:80` 0.1, `attack.rb:93` 0.0 |
| gem: kaminari-activerecord | 0.3 | 0.3 | `active_record_model_extension.rb:17` 0.3, `active_record_relation_methods.rb:99` 0.0, `active_record_relation_methods.rb:29` 0.0 |
| ruby default gem: net-http | 0.3 | 0.3 | `header.rb:205` 0.0, `header.rb:284` 0.0, `header.rb:227` 0.0 |
| gem: email_validator | 0.3 | 0.3 | `email_validator.rb:65` 0.1, `email_validator.rb:77` 0.1, `email_validator.rb:73` 0.0 |
| gem: bcrypt | 0.3 | 0.3 | `password.rb:93` 0.1, `engine.rb:90` 0.1, `engine.rb:70` 0.0 |
| rails: activejob | 0.3 | 0.3 | `log_subscriber.rb:148` 0.1, `arguments.rb:92` 0.0, `arguments.rb:142` 0.0 |
| gem: sidekiq-unique-jobs | 0.3 | 0.3 | `core_ext.rb:101` 0.3 |
| gem: httparty | 0.3 | 0.3 | `hash_conversions.rb:31` 0.0, `httparty.rb:645` 0.0, `request.rb:328` 0.0 |
| ruby default gem: bigdecimal | 0.3 | 0.3 | `util.rb:51` 0.2, `util.rb:24` 0.1, `util.rb:184` 0.0 |
| gem: stripe-ruby-mock | 0.3 | 0.3 | `instance.rb:217` 0.1, `instance.rb:20` 0.0, `instance.rb:116` 0.0 |
| gem: front_matter_parser | 0.3 | 0.3 | `parser.rb:71` 0.1, `parser.rb:67` 0.1, `multi_line_comment.rb:19` 0.0 |
| gem: connection_pool | 0.2 | 0.2 | `connection_pool.rb:110` 0.1, `connection_pool.rb:113` 0.1, `connection_pool.rb:106` 0.0 |
| gem: pg_search | 0.2 | 0.2 | `model.rb:42` 0.0, `tsearch.rb:185` 0.0, `scope_options.rb:125` 0.0 |
| gem: jwt | 0.2 | 0.2 | `decode_verifier.rb:33` 0.0, `encoded_token.rb:29` 0.0, `jwa.rb:48` 0.0 |
| gem: jsonapi-serializer | 0.2 | 0.2 | `helpers.rb:17` 0.0, `serialization_core.rb:48` 0.0, `object_serializer.rb:214` 0.0 |
| gem: sassc | 0.2 | 0.2 | `functions_handler.rb:23` 0.1, `script.rb:12` 0.0, `script.rb:11` 0.0 |
| ruby default gem: erb | 0.2 | 0.2 | `util.rb:65` 0.2 |
| gem: faraday | 0.2 | 0.2 | `request.rb:83` 0.0, `headers.rb:59` 0.0, `options.rb:97` 0.0 |
| gem: field_test | 0.2 | 0.2 | `experiment.rb:14` 0.0, `experiment.rb:194` 0.0, `participant.rb:35` 0.0 |
| gem: globalid | 0.2 | 0.2 | `gid.rb:95` 0.0, `gid.rb:159` 0.0, `gid.rb:166` 0.0 |
| gem: active_record_union | 0.1 | 0.2 | `union.rb:27` 0.0, `union.rb:35` 0.0, `union.rb:60` 0.0 |
| gem: marcel | 0.1 | 0.1 | `mime_type.rb:81` 0.0, `mime_type.rb:90` 0.0, `magic.rb:18` 0.0 |
| gem: sorbet-runtime | 0.1 | 0.1 | `_methods.rb:433` 0.1, `compatibility_patches.rb:41` 0.0 |
| gem: responders | 0.1 | 0.1 | `respond_with.rb:248` 0.0, `respond_with.rb:214` 0.0, `responder.rb:167` 0.0 |
| gem: cld3 | 0.1 | 0.1 | `cld3.rb:64` 0.1, `cld3.rb:53` 0.0 |
| ruby default gem: timeout | 0.1 | 0.1 | `timeout.rb:292` 0.0, `timeout.rb:152` 0.0, `timeout.rb:293` 0.0 |
| ruby default gem: csv | 0.1 | 0.1 | `writer.rb:154` 0.0, `csv.rb:1523` 0.0, `writer.rb:185` 0.0 |
| gem: devise_invitable | 0.1 | 0.1 | `models.rb:292` 0.0, `parameter_sanitizer.rb:34` 0.0, `models.rb:328` 0.0 |
| gem: gibbon | 0.1 | 0.1 | `request.rb:9` 0.0, `request.rb:11` 0.0, `request.rb:15` 0.0 |
| gem: sax-machine | 0.0 | 0.1 | `sax_abstract_handler.rb:163` 0.0, `sax_abstract_handler.rb:147` 0.0, `sax_abstract_handler.rb:44` 0.0 |
| gem: pg | 0.0 | 0.0 | `date.rb:14` 0.0, `result.rb:17` 0.0, `date.rb:13` 0.0 |
| gem: carrierwave-bombshelter | 0.0 | 0.0 | `bombshelter.rb:41` 0.0, `bombshelter.rb:31` 0.0, `bombshelter.rb:59` 0.0 |
| gem: racc | 0.0 | 0.0 | `parser.rb:263` 0.0 |
| gem: lowrail-profile | 0.0 | 0.0 | `profile.rb:95` 0.0, `profile.rb:104` 0.0, `profile.rb:72` 0.0 |
| gem: safely_block | 0.0 | 0.0 | `core.rb:48` 0.0 |
| gem: faraday-net_http | 0.0 | 0.0 | `net_http.rb:81` 0.0, `net_http.rb:181` 0.0, `net_http.rb:137` 0.0 |
| gem: s3_direct_upload | 0.0 | 0.0 | `form_helper.rb:68` 0.0, `form_helper.rb:75` 0.0, `form_helper.rb:77` 0.0 |
| gem: omniauth-rails_csrf_protection | 0.0 | 0.0 | `token_verifier.rb:59` 0.0, `token_verifier.rb:55` 0.0 |
| gem: recaptcha | 0.0 | 0.0 | `helpers.rb:172` 0.0, `helpers.rb:144` 0.0, `helpers.rb:62` 0.0 |
| gem: reverse_markdown | 0.0 | 0.0 | `base.rb:5` 0.0, `cleaner.rb:21` 0.0, `cleaner.rb:17` 0.0 |
| gem: sidekiq-throttled | 0.0 | 0.0 | `strategy_collection.rb:22` 0.0, `strategy.rb:51` 0.0, `registry.rb:23` 0.0 |
| test harness: rspec-expectations | 0.0 | 0.0 | `has.rb:87` 0.0, `matchers.rb:964` 0.0, `matchers.rb:963` 0.0 |
| gem: omniauth-oauth2 | 0.0 | 0.0 | `oauth2.rb:159` 0.0 |
| gem: countries | 0.0 | 0.0 | `data.rb:115` 0.0, `locales_methods.rb:17` 0.0, `locales_methods.rb:12` 0.0 |
| gem: feedjira | 0.0 | 0.0 | `itunes_rss.rb:66` 0.0, `rss.rb:26` 0.0, `rss_feed_burner.rb:20` 0.0 |
| gem: flipper-active_support_cache_store | 0.0 | 0.0 | `active_support_cache_store.rb:81` 0.0 |
| gem: omniauth-github | 0.0 | 0.0 | `github.rb:78` 0.0 |
| gem: sassc-rails | 0.0 | 0.2 | `compressor.rb:24` 0.0, `compressor.rb:26` 0.0, `template.rb:47` 0.0 |
| gem: omniauth-apple | 0.0 | 0.0 | `apple.rb:67` 0.0 |
| gem: multi_json | 0.0 | 0.0 | `multi_json.rb:298` 0.0, `deprecated.rb:34` 0.0, `multi_json.rb:214` 0.0 |
| gem: algoliasearch-rails | 0.0 | 0.0 | `algoliasearch-rails.rb:278` 0.0, `algoliasearch-rails.rb:814` 0.0, `algoliasearch-rails.rb:104` 0.0 |
| test harness: rspec-core | 0.0 | 0.0 | `example_group.rb:767` 0.0 |
| gem: ffi | 0.0 | 0.0 | `enum.rb:121` 0.0 |
| gem: oauth | 0.0 | 0.0 | `unauthorized.rb:11` 0.0 |
| ruby default gem: ostruct | 0.0 | 0.0 | `ostruct.rb:279` 0.0 |
| ruby default gem: bundler | 0.0 | 0.0 | `rubygems_integration.rb:257` 0.0 |
| gem: pg_query | 0.0 | 0.0 | `parse.rb:3` 0.0, `parse.rb:342` 0.0, `parse.rb:109` 0.0 |
| gem: factory_bot | 0.0 | 0.0 | `definition.rb:123` 0.0, `callbacks_observer.rb:18` 0.0, `attribute_assigner.rb:100` 0.0 |
| gem: test-prof | 0.0 | 0.0 | `factory_bot_patch.rb:22` 0.0, `factory_bot.rb:23` 0.0 |
| gem: msgpack | 0.0 | 0.0 | `factory.rb:27` 0.0, `bigint.rb:0` 0.0, `bigint.rb:10` 0.0 |
| gem: google-protobuf | 0.0 | 0.0 | `repeated_field.rb:60` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Mails

| # | Mailer action | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | NotifyMailer#trusted_role_email | 4 / 4 | 5040.3 / 5039.0 | -1.3 | 5042.0 | `GEM/mail/lib/mail/utilities.rb:215` 213.0, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 155.3, `GEM/mail/lib/mail/parsers/content_type_parser.rb:734` 110.0 | `app/mailers/notify_mailer.rb:367` 1645.3, `app/models/settings/base.rb:198` 316.0, `config/initializers/timeout.rb:232` 288.0 |
| 2 | NotifyMailer#tag_moderator_confirmation_email | 4 / 4 | 4177.3 / 4176.3 | -1.0 | 4176.5 | `GEM/mail/lib/mail/utilities.rb:215` 213.0, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 154.0, `GEM/mail/lib/mail/parsers/content_type_parser.rb:734` 110.0 | `app/mailers/notify_mailer.rb:332` 1633.0, `config/initializers/ahoy_email.rb:37` 248.0, `app/views/layouts/mailer.html.erb:10` 204.0 |
| 3 | NotifyMailer.deliver_mail | 9 / 9 | 1914.1 / 1914.0 | -0.1 | 1869.9 | `GEM/mail/lib/mail/utilities.rb:215` 221.5, `GEM/mail/lib/mail/utilities.rb:248` 131.0, `GEM/mail/lib/mail/field_list.rb:71` 110.3 | `app/services/tag_moderators/add.rb:27` 770.4, `app/services/exporter/service.rb:58` 565.0, `app/services/tag_moderators/add_trusted_role.rb:8` 563.5 |
| 4 | NotifyMailer#export_email | 1 / 1 | – / – |  | 5284.0 |  |  |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/mail/lib/mail/utilities.rb:215` | 210.94 / 210.94 | 100% | `app/mailers/notify_mailer.rb:367` 17%, `app/mailers/notify_mailer.rb:332` 17% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 2 | `GEM/mail/lib/mail/fields/parameter_hash.rb:22` | 118.61 / 118.61 | 100% | `app/mailers/notify_mailer.rb:367` 22%, `app/mailers/notify_mailer.rb:332` 21% | `if k =~ /^#{key_pattern}(\*\|$)/i` |
| 3 | `GEM/mail/lib/mail/field_list.rb:71` | 104.56 / 104.56 | 100% | `app/services/exporter/service.rb:58` 17%, `app/mailers/notify_mailer.rb:367` 17% | `fields = select { \|f\| f.responsible_for? field_name }` |
| 4 | `GEM/mail/lib/mail/field.rb:263` | 84.67 / 84.67 | 100% | `app/services/tag_moderators/add.rb:27` 19%, `app/services/tag_moderators/add_trusted_role.rb:8` 19% | `field.send(name, *args, &block)` |
| 5 | `GEM/mail/lib/mail/utilities.rb:248` | 59.5 / 59.5 | 100% | `app/services/tag_moderators/add.rb:27` 55%, `app/services/tag_moderators/add_trusted_role.rb:8` 37% | `string.gsub(TO_CRLF_REGEX, Constants::CRLF)` |
| 6 | `GEM/mail/lib/mail/utilities.rb:226` | 56.44 / 56.44 | 100% | `app/services/tag_moderators/add.rb:27` 19%, `app/services/tag_moderators/add_trusted_role.rb:8` 19% | `str.to_s.downcase.tr(Constants::HYPHEN, Constants::UNDERSCORE)` |
| 7 | `GEM/mail/lib/mail/parsers/content_type_parser.rb:734` | 53.33 / 53.28 | 50% | `app/mailers/notify_mailer.rb:332` 41%, `app/mailers/notify_mailer.rb:367` 41% | `_wide = data[p].ord` |
| 8 | `GEM/mail/lib/mail/utilities.rb:291` | 45.06 / 45.06 | 100% | `app/services/tag_moderators/add.rb:27` 22%, `app/services/tag_moderators/add_trusted_role.rb:8` 22% | `value !~ /\S/` |
| 9 | `GEM/mail/lib/mail/parser_tools.rb:7` | 34.44 / 34.44 | 100% | `app/mailers/notify_mailer.rb:332` 28%, `app/mailers/notify_mailer.rb:367` 28% | `data.slice(from_bytes..to_bytes).force_encoding(Encoding::UTF_8)` |
| 10 | `GEM/mail/lib/mail/parsers/content_transfer_encoding_parser.rb:380` | 32.11 / 32.11 | 56% | `app/services/tag_moderators/add.rb:27` 42%, `app/services/tag_moderators/add_trusted_role.rb:8` 42% | `_wide = data[p].ord` |
