# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bundle exec rspec spec/requests spec/controllers --seed 1234 --format documentation`
* Ruby: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux]
* Rails: 8.1.4, test environment
* Counted in run 1: 2032 requests, 75 jobs; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 2032 | 8176.0 | 75 | 0 | 0 | 0 |
| run2 | 1 | 2032 | 8163.0 | 75 | 0 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.0 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/models/concerns/cacheable.rb:18` | `preload_cacheable_associations` | 147.6 | 13.64 | 0.06 | `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:28` 10%, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:77` 5%, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:129` 5% | Api::V1::StatusesController#show 16%, Api::V2::NotificationsController#index 12%, Api::V1::Timelines::TagController#show 9% | `ActiveRecord::Associations::Preloader.new(records: records, associatio` |
| 2 | `app/lib/access_token_extension.rb:23` | `update_last_used` | 133.62 | 53.21 | 0.8 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 7%, `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 5%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 2% | Api::V1::Admin::AccountActionsController#create 3%, Api::V1::StatusesController#create 2%, Api::V2::NotificationsController#index 1% | `update(last_used_at: clock.now.utc, last_used_ip: request.remote_ip)` |
| 3 | `app/models/ip_block.rb:49` | `blocked_ips_map` | 102.99 | 33.39 | 2.2 | `RAILS/activesupport/lib/active_support/cache.rb:1083` 7%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 6%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:217` 3% | HomeController#index 4%, ActivityPub::RepliesController#index 3%, AccountsController#show 3% | `Rails.cache.fetch(CACHE_KEY) { FastIpMap.new(severity_no_access.pluck(` |
| 4 | `lib/vite/tagger.rb:32` | `vite_preload_tag` | 99.83 | 0.0 | 7.13 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 36%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 36%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:288` 7% | HomeController#index 59%, StatusesController#show 12%, AccountsController#show 9% | `helper.tag.link(rel: 'modulepreload', href:, as: 'script', crossorigin` |
| 5 | `app/models/setting.rb:76` | `[]` | 79.8 | 25.21 | 0.0 | `RAILS/activesupport/lib/active_support/cache.rb:1083` 20%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 13%, `RAILS/activesupport/lib/active_support/cache.rb:1085` 7% | HomeController#index 39%, StatusesController#show 9%, AccountsController#show 7% | `Rails.cache.fetch(cache_key(key)) do` |
| 6 | `app/controllers/api/base_controller.rb:62` | `require_not_suspended!` | 77.27 | 14.04 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 28%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 10%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 4% | Api::V1::Admin::AccountActionsController#create 3%, Api::V1::StatusesController#create 2%, Api::V2::NotificationsController#index 1% | `render json: { error: 'Your login is currently disabled' }, status: 40` |
| 7 | `app/controllers/api/base_controller.rb:44` | `current_resource_owner` | 66.19 | 28.86 | 0.43 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 21%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 6%, `GEM/doorkeeper/lib/doorkeeper/oauth/token.rb:150` 5% | Api::V1::Admin::AccountActionsController#create 3%, Api::V1::StatusesController#create 2%, Api::V1::StatusesController#show 1% | `@current_user \|\|= User.find(doorkeeper_token.resource_owner_id) if doo` |
| 8 | `app/models/setting.rb:77` | `[]` | 61.9 | 45.12 | 2.45 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 10%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:133` 6%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 4% | HomeController#index 43%, StatusesController#show 10%, AccountsController#show 8% | `db_val = find_by(var: key)` |
| 9 | `app/controllers/concerns/localized.rb:11` | `set_locale` | 60.0 | 16.72 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 39%, `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:30` 13%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 12% | HomeController#index 12%, StatusesController#show 4%, AccountsController#show 3% | `I18n.with_locale(requested_locale \|\| I18n.default_locale, &block)` |
| 10 | `app/models/admin/base_action.rb:59` | `process_notification!` | 53.38 | 0.29 | 0.01 | `GEM/css_parser/lib/css_parser/rule_set.rb:116` 5%, `GEM/css_parser/lib/css_parser/parser.rb:407` 5%, `GEM/css_parser/lib/css_parser.rb:112` 5% | Api::V1::Admin::AccountActionsController#create 100% | `UserMailer.warning(target_account.user, warning).deliver_later!` |
| 11 | `config/initializers/rack_attack.rb:10` | `authenticated_token` | 46.51 | 14.54 | 0.5 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 9%, `GEM/doorkeeper/lib/doorkeeper/oauth/token.rb:150` 7%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 5% | Api::V1::Admin::AccountActionsController#create 3%, Api::V1::StatusesController#create 2%, Api::V1::StatusesController#show 1% | `@authenticated_token = Doorkeeper::OAuth::Token.authenticate(` |
| 12 | `app/models/user.rb:302` | `two_factor_enabled?` | 40.83 | 12.11 | 0.33 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `RAILS/activerecord/lib/active_record/relation/finder_methods.rb:445` 3%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 3% | HomeController#index 22%, Admin::ReportsController#show 4%, Auth::SessionsController#create 4% | `otp_required_for_login? \|\| webauthn_credentials.any?` |
| 13 | `app/helpers/application_helper.rb:119` | `material_symbol` | 36.37 | 0.0 | 0.31 | `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:54` 13%, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1431` 7%, `GEM/nokogiri/lib/nokogiri/xml/document.rb:85` 7% | Admin::ReportsController#show 31%, OAuth::AuthorizedApplicationsController#index 15%, Settings::ExportsController#show 10% | `inline_svg_tag(` |
| 14 | `lib/vite/tagger.rb:163` | `vite_javascript_tag` | 35.73 | 6.24 | 1.23 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 14%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 10%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 10% | HomeController#index 66%, StatusesController#show 13%, AccountsController#show 10% | `helper.stylesheet_link_tag(` |
| 15 | `lib/vite/tagger.rb:23` | `vite_preload_tag` | 35.65 | 0.0 | 7.13 | `RAILS/actionview/lib/action_view/helpers/asset_url_helper.rb:194` 20%, `RAILS/actionview/lib/action_view/helpers/asset_url_helper.rb:187` 20%, `RAILS/actionview/lib/action_view/helpers/asset_url_helper.rb:208` 20% | HomeController#index 59%, StatusesController#show 12%, AccountsController#show 9% | `asset_paths = sources.map { \|source\| helper.path_to_asset(source, **ur` |
| 16 | `lib/mastodon/middleware/public_file_server.rb:18` | `call` | 34.25 | 0.0 | 0.0 | `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 37%, `GEM/rack/lib/rack/utils.rb:693` 14%, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:146` 12% | HomeController#index 6%, ActivityPub::RepliesController#index 5%, AccountsController#show 4% | `file = @file_handler.attempt(env)` |
| 17 | `app/models/user_role.rb:126` | `everyone` | 34.12 | 22.2 | 0.6 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 11%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 7%, `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:235` 4% | Api::V1::Admin::AccountActionsController#create 6%, HomeController#index 5%, Api::V1::Admin::ReportsController#index 4% | `UserRole.find(EVERYONE_ROLE_ID)` |
| 18 | `app/helpers/routing_helper.rb:20` | `full_asset_url` | 32.61 | 0.0 | 0.9 | `GEM/uri/lib/uri/generic.rb:1007` 23%, `GEM/uri/lib/uri/rfc3986_parser.rb:135` 6%, `GEM/uri/lib/uri/common.rb:194` 6% | HomeController#index 16%, Api::V2::NotificationsController#index 7%, Api::V1::NotificationsController#index 6% | `URI.join(asset_host, source).to_s` |
| 19 | `app/controllers/api/base_controller.rb:92` | `authorize_if_got_token!` | 31.13 | 0.06 | 0.14 | `GEM/doorkeeper/lib/doorkeeper/oauth/error_response.rb:110` 26%, `GEM/doorkeeper/lib/doorkeeper/oauth/error_response.rb:111` 24%, `GEM/doorkeeper/lib/doorkeeper/oauth/error_response.rb:112` 22% | Api::V1::Admin::AccountActionsController#create 7%, Api::V1::Timelines::PublicController#show 3%, Api::V1::Timelines::TagController#show 3% | `doorkeeper_authorize!(*scopes) if doorkeeper_token` |
| 20 | `lib/vite/tagger.rb:35` | `vite_preload_tag` | 28.52 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/helpers/output_safety_helper.rb:36` 50%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 25%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 25% | HomeController#index 59%, StatusesController#show 12%, AccountsController#show 9% | `helper.safe_join(tags)` |
| 21 | `app/models/concerns/paginable.rb:28` | `to_a_paginated_by_id` | 28.46 | 3.44 | 0.05 | `RAILS/activerecord/lib/arel/table.rb:85` 12%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 7%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 4% | Api::V1::Admin::ReportsController#index 25%, Api::V1::NotificationsController#index 16%, Api::V1::Admin::AccountsController#index 15% | `paginate_by_max_id(limit, options[:max_id], options[:since_id]).to_a` |
| 22 | `app/models/concerns/account/finder_concern.rb:34` | `find_remote` | 27.27 | 4.59 | 0.0 | `RAILS/activerecord/lib/arel/table.rb:85` 29%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 26%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 6% | AccountsController#show 23%, HomeController#index 18%, StatusesController#show 17% | `.take` |
| 23 | `app/models/session_activation.rb:62` | `assign_access_token` | 26.84 | 8.77 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 3%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 3%, `RAILS/activerecord/lib/arel/visitors/postgresql.rb:136` 3% | HomeController#index 36%, Auth::SessionsController#create 9%, IntentsController#show 4% | `self.access_token = Doorkeeper::AccessToken.create!(access_token_attri` |
| 24 | `app/views/layouts/admin.html.haml:27` |  | 25.83 | 0.0 | 0.0 | `GEM/simple-navigation/lib/simple_navigation/item.rb:148` 13%, `GEM/simple-navigation/lib/simple_navigation/configuration.rb:26` 10%, `GEM/simple-navigation/lib/simple_navigation/item.rb:152` 10% | Admin::ReportsController#show 30%, OAuth::AuthorizedApplicationsController#index 16%, Admin::InstancesController#show 10% | `= render_navigation` |
| 25 | `app/models/session_activation.rb:41` | `activate` | 25.12 | 9.26 | 0.06 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 9%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 3%, `RAILS/activerecord/lib/arel/table.rb:85` 2% | HomeController#index 36%, Auth::SessionsController#create 9%, IntentsController#show 4% | `create!(**).tap { purge_old }` |
| 26 | `app/helpers/routing_helper.rb:39` | `asset_host` | 23.62 | 0.0 | 2.7 | `RAILS/actionpack/lib/action_dispatch/http/url.rb:238` 8%, `RAILS/actionpack/lib/action_dispatch/journey/formatter.rb:128` 7%, `RAILS/actionpack/lib/action_dispatch/http/url.rb:204` 4% | HomeController#index 14%, Api::V2::NotificationsController#index 7%, Api::V1::NotificationsController#index 7% | `Rails.configuration.action_controller.asset_host \|\| root_url` |
| 27 | `app/models/account.rb:182` |  | 22.92 | 4.95 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 20%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5% | ActivityPub::RepliesController#index 16%, StatusesController#show 15%, AccountsController#show 15% | `delegate :email,` |
| 28 | `app/controllers/application_controller.rb:130` | `current_session` | 20.64 | 3.02 | 0.17 | `GEM/json/lib/json/common.rb:364` 6%, `RAILS/actionpack/lib/action_dispatch/middleware/cookies.rb:628` 6%, `GEM/rack/lib/rack/utils.rb:331` 4% | HomeController#index 21%, Auth::SessionsController#create 4%, StatusesController#show 4% | `@current_session = SessionActivation.find_by(session_id: cookies.signe` |
| 29 | `app/lib/activitypub/serializer.rb:36` | `serializable_hash` | 20.61 | 0.05 | 0.0 | `GEM/active_model_serializers/lib/active_model/serializer.rb:341` 13%, `GEM/active_model_serializers/lib/active_model/serializer.rb:420` 8%, `GEM/jsonapi-renderer/lib/jsonapi/include_directive/parser.rb:41` 7% | ActivityPub::RepliesController#index 53%, StatusesController#show 9%, ActivityPub::OutboxesController#show 8% | `super` |
| 30 | `app/models/user.rb:154` | `role` | 19.48 | 5.11 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 7%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 5% | HomeController#index 19%, Api::V1::Admin::AccountActionsController#create 7%, Api::V1::Admin::AccountsController#index 3% | `super` |

App middleware that hands the request on (the stack below it, not its own work): `lib/mastodon/middleware/socket_cleanup.rb:11` 177.39, `lib/mastodon/middleware/public_file_server.rb:21` 63.7 warm objects per request.

562.68 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | Api::Fasp::DataSharing::V0::EventSubscriptionsController#create | 3 / 3 | 332066.0 / 332051.0 | -15.0 | 224187.7 | `RAILS/actionview/lib/action_view/buffers.rb:44` 1390.5, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 629.0, `RAILS/actionview/lib/action_view/helpers/url_helper.rb:438` 621.5 | `app/controllers/api/fasp/data_sharing/v0/event_subscriptions_controller.rb:5` 723.0, `lib/mastodon/middleware/socket_cleanup.rb:11` 321.5, `app/controllers/api/fasp/base_controller.rb:48` 178.0 |
| 2 | Admin::RolesController#create | 2 / 2 | 43029.0 / 42927.0 | -102.0 | 24508.5 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 627.0, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 592.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 592.0 | `app/views/admin/roles/_form.html.haml:51` 6895.0, `app/helpers/application_helper.rb:119` 3689.0, `app/views/layouts/admin.html.haml:27` 2843.0 |
| 3 | Admin::ReportsController#show | 4 / 4 | 41207.0 / 41222.7 | 15.7 | 55310.8 | `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:54` 1024.0, `GEM/simple-navigation/lib/simple_navigation/item.rb:148` 680.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 636.7 | `app/helpers/application_helper.rb:119` 7616.0, `app/views/layouts/admin.html.haml:27` 5335.0, `app/views/admin/reports/show.html.haml:63` 2669.3 |
| 4 | Admin::InstancesController#show | 2 / 2 | 29743.0 / 29742.0 | -1.0 | 44693.5 | `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:54` 928.0, `GEM/simple-navigation/lib/simple_navigation/item.rb:148` 692.0, `GEM/simple-navigation/lib/simple_navigation/item.rb:152` 516.0 | `app/helpers/application_helper.rb:119` 6902.0, `app/views/layouts/admin.html.haml:27` 5375.0, `app/models/user.rb:302` 1125.0 |
| 5 | Admin::IpBlocksController#index | 2 / 2 | 29195.0 / 29084.0 | -111.0 | 33803.0 | `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:54` 944.0, `GEM/simple-navigation/lib/simple_navigation/item.rb:148` 692.0, `GEM/simple-navigation/lib/simple_navigation/item.rb:152` 516.0 | `app/helpers/application_helper.rb:119` 7021.0, `app/views/layouts/admin.html.haml:27` 5366.0, `app/models/user.rb:302` 1125.0 |
| 6 | OAuth::AuthorizedApplicationsController#index | 4 / 4 | 20564.7 / 20510.0 | -54.7 | 16205.8 | `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:54` 506.7, `GEM/chewy/lib/chewy/strategy.rb:70` 496.0, `GEM/simple-navigation/lib/simple_navigation/item.rb:148` 364.0 | `app/helpers/application_helper.rb:119` 3768.3, `app/views/layouts/admin.html.haml:27` 2726.3, `app/models/user.rb:302` 694.7 |
| 7 | HomeController#index | 70 / 70 | 17229.2 / 17225.1 | -4.0 | 17079.1 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 767.4, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 650.3, `GEM/chewy/lib/chewy/strategy.rb:70` 500.0 | `lib/vite/tagger.rb:32` 1734.0, `app/models/setting.rb:76` 912.6, `app/models/setting.rb:77` 790.8 |
| 8 | Api::V1::Statuses::ReblogsController#create | 2 / 2 | 16478.0 / 16389.0 | -89.0 | 11021.5 | `GEM/chewy/lib/chewy/strategy.rb:70` 512.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 383.0, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 320.0 | `app/controllers/api/v1/statuses/reblogs_controller.rb:19` 1663.0, `app/services/reblog_service.rb:29` 552.0, `app/models/status.rb:397` 413.0 |
| 9 | Api::V1::Statuses::QuotesController#index | 4 / 4 | 16462.3 / 16378.7 | -83.7 | 13378.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 495.7, `GEM/chewy/lib/chewy/strategy.rb:70` 467.3, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 328.0 | `app/controllers/api/v1/statuses/quotes_controller.rb:14` 1935.7, `app/controllers/api/v1/statuses/quotes_controller.rb:34` 421.3, `app/models/status.rb:397` 370.0 |
| 10 | Api::V2::NotificationsController#index | 12 / 12 | 15658.5 / 15657.6 | -0.9 | 16476.8 | `GEM/chewy/lib/chewy/strategy.rb:70` 481.5, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 449.7, `RAILS/activerecord/lib/arel/table.rb:85` 352.2 | `app/models/concerns/cacheable.rb:18` 3384.9, `app/controllers/api/v2/notifications_controller.rb:36` 1451.8, `app/models/notification.rb:200` 612.2 |
| 11 | PrivacyController#show | 4 / 4 | 14902.7 / 14907.3 | 4.7 | 15693.5 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 797.3, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 675.3, `GEM/chewy/lib/chewy/strategy.rb:70` 502.7 | `lib/vite/tagger.rb:32` 1806.0, `app/models/setting.rb:76` 875.7, `lib/vite/tagger.rb:163` 724.0 |
| 12 | Auth::RegistrationsController#edit | 3 / 3 | 14546.5 / 14537.5 | -9.0 | 24024.7 | `GEM/chewy/lib/chewy/strategy.rb:70` 515.0, `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:54` 472.0, `GEM/simple-navigation/lib/simple_navigation/item.rb:148` 330.0 | `app/helpers/application_helper.rb:119` 3510.5, `app/views/layouts/admin.html.haml:27` 2470.5, `app/models/user.rb:302` 524.0 |
| 13 | Api::V1::Notifications::RequestsController#index | 2 / 2 | 14378.0 / 14377.0 | -1.0 | 9010.5 | `GEM/chewy/lib/chewy/strategy.rb:70` 504.0, `RAILS/activerecord/lib/arel/table.rb:85` 492.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 430.0 | `app/models/concerns/cacheable.rb:18` 3808.0, `app/models/concerns/paginable.rb:28` 1552.0, `app/controllers/api/v1/notifications/requests_controller.rb:21` 1197.0 |
| 14 | FiltersController#index | 3 / 3 | 14347.0 / 14346.0 | -1.0 | 10096.3 | `GEM/chewy/lib/chewy/strategy.rb:70` 515.0, `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:54` 464.0, `GEM/simple-navigation/lib/simple_navigation/item.rb:148` 345.0 | `app/helpers/application_helper.rb:119` 3451.0, `app/views/layouts/admin.html.haml:27` 2462.5, `app/models/user.rb:302` 569.0 |
| 15 | AboutController#show | 8 / 8 | 13556.6 / 13538.9 | -17.7 | 16416.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 711.4, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 603.1, `GEM/chewy/lib/chewy/strategy.rb:70` 472.3 | `lib/vite/tagger.rb:32` 1612.0, `app/models/setting.rb:76` 780.7, `lib/vite/tagger.rb:163` 620.6 |
| 16 | Api::V1::Statuses::ReblogsController#destroy | 3 / 3 | 13382.0 / 13392.5 | 10.5 | 16355.3 | `RAILS/activerecord/lib/arel/table.rb:85` 618.5, `RAILS/activerecord/lib/arel/alias_predication.rb:8` 549.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 547.0 | `app/services/remove_status_service.rb:73` 1302.5, `app/services/remove_status_service.rb:67` 1179.5, `app/services/remove_status_service.rb:53` 946.0 |
| 17 | ActivityPub::ContextsController#show | 4 / 4 | 13114.7 / 13115.0 | 0.3 | 11359.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 1283.7, `RAILS/activerecord/lib/arel/table.rb:85` 1269.0, `RAILS/activemodel/lib/active_model/attribute.rb:9` 572.7 | `app/lib/activitypub/tag_manager.rb:52` 6336.0, `app/models/status.rb:207` 1232.0, `app/lib/activitypub/tag_manager.rb:55` 792.0 |
| 18 | OAuth::AuthorizationsController#new | 4 / 4 | 12755.7 / 12707.0 | -48.7 | 10404.0 | `GEM/chewy/lib/chewy/strategy.rb:70` 472.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 174.7, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 145.0 | `app/controllers/oauth/authorizations_controller.rb:19` 653.7, `app/models/session_activation.rb:62` 436.0, `app/models/session_activation.rb:41` 408.0 |
| 19 | Api::V1::ReportsController#create | 8 / 8 | 12646.9 / 12577.9 | -69.0 | 14385.1 | `GEM/chewy/lib/chewy/strategy.rb:70` 475.1, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 474.3, `RAILS/activerecord/lib/arel/table.rb:85` 219.6 | `app/services/webhook_service.rb:22` 1172.9, `app/services/report_service.rb:33` 623.4, `app/services/report_service.rb:51` 580.3 |
| 20 | Api::V1::Admin::AccountsController#reject | 6 / 6 | 11776.4 / 11775.4 | -1.0 | 10408.5 | `GEM/chewy/lib/chewy/strategy.rb:70` 475.6, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 324.8, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 272.8 | `app/services/delete_account_service.rb:165` 2862.8, `app/services/delete_account_service.rb:274` 1312.2, `app/services/delete_account_service.rb:276` 934.6 |
| 21 | Api::V2::SuggestionsController#index | 2 / 2 | 11446.0 / 11447.0 | 1.0 | 12594.0 | `GEM/chewy/lib/chewy/strategy.rb:70` 408.0, `RAILS/activerecord/lib/arel/table.rb:85` 344.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 246.0 | `app/models/account_suggestions.rb:33` 736.0, `app/controllers/api/v2/suggestions_controller.rb:14` 544.0, `app/models/account.rb:476` 528.0 |
| 22 | Api::V1::Admin::ReportsController#index | 10 / 10 | 11442.0 / 11441.7 | -0.3 | 10652.2 | `GEM/chewy/lib/chewy/strategy.rb:70` 465.8, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:129` 400.4, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 213.3 | `app/controllers/api/v1/admin/reports_controller.rb:29` 2935.9, `app/models/concerns/paginable.rb:28` 1579.7, `app/helpers/routing_helper.rb:20` 448.0 |
| 23 | Api::V1::Accounts::StatusesController#index | 10 / 10 | 11314.3 / 11314.4 | 0.1 | 11549.2 | `GEM/chewy/lib/chewy/strategy.rb:70` 421.1, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 302.1, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:28` 281.7 | `app/models/concerns/cacheable.rb:18` 2813.6, `app/controllers/api/v1/accounts/statuses_controller.rb:12` 913.7, `app/lib/access_token_extension.rb:23` 333.0 |
| 24 | Api::V1::NotificationsController#index | 12 / 12 | 11285.2 / 11284.3 | -0.9 | 12610.0 | `GEM/chewy/lib/chewy/strategy.rb:70` 510.2, `RAILS/activerecord/lib/arel/table.rb:85` 303.2, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 262.7 | `app/models/concerns/cacheable.rb:18` 1950.9, `app/controllers/api/v1/notifications_controller.rb:19` 1198.6, `app/models/concerns/paginable.rb:28` 821.0 |
| 25 | Api::V1::StatusesController#create | 20 / 20 | 10827.1 / 10770.7 | -56.4 | 10604.7 | `GEM/chewy/lib/chewy/strategy.rb:70` 524.5, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 247.4, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 170.5 | `app/controllers/api/v1/statuses_controller.rb:50` 592.4, `app/controllers/api/v1/statuses_controller.rb:134` 455.2, `app/lib/access_token_extension.rb:23` 333.0 |
| 26 | Api::V1::Timelines::PublicController#show | 12 / 12 | 10793.7 / 10737.8 | -55.9 | 11552.6 | `GEM/chewy/lib/chewy/strategy.rb:70` 508.9, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 258.1, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:28` 243.5 | `app/models/concerns/cacheable.rb:18` 2547.8, `app/controllers/api/v1/timelines/public_controller.rb:12` 1042.3, `app/lib/access_token_extension.rb:23` 272.5 |
| 27 | Api::V1::StatusesController#update | 4 / 4 | 10701.3 / 10641.7 | -59.7 | 11520.3 | `GEM/chewy/lib/chewy/strategy.rb:70` 510.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 365.3, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 162.7 | `app/models/concerns/status/snapshot_concern.rb:34` 504.0, `app/controllers/api/v1/statuses_controller.rb:73` 445.3, `app/lib/access_token_extension.rb:23` 333.0 |
| 28 | Settings::ExportsController#show | 4 / 4 | 10671.7 / 10661.7 | -10.0 | 19544.0 | `GEM/chewy/lib/chewy/strategy.rb:70` 479.3, `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:54` 346.7, `GEM/simple-navigation/lib/simple_navigation/item.rb:148` 212.0 | `app/helpers/application_helper.rb:119` 2578.3, `app/views/layouts/admin.html.haml:27` 1619.3, `app/models/user.rb:302` 349.3 |
| 29 | Api::V1::Timelines::TagController#show | 11 / 11 | 10660.7 / 10660.6 | -0.1 | 11327.3 | `GEM/chewy/lib/chewy/strategy.rb:70` 498.2, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:28` 277.2, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 268.5 | `app/models/concerns/cacheable.rb:18` 2811.4, `app/controllers/api/v1/timelines/tag_controller.rb:12` 651.4, `app/models/account.rb:476` 285.6 |
| 30 | Api::V1::Admin::AccountActionsController#create | 28 / 28 | 10656.1 / 10612.4 | -43.7 | 10452.1 | `GEM/chewy/lib/chewy/strategy.rb:70` 479.0, `GEM/css_parser/lib/css_parser/rule_set.rb:116` 226.5, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 221.5 | `app/models/admin/base_action.rb:59` 4017.3, `app/lib/access_token_extension.rb:23` 333.0, `app/mailers/user_mailer.rb:170` 298.2 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/chewy/lib/chewy/strategy.rb:70` | `debug` | 467.17 / 467.17 | 0.0 | 467.39 | 100% | String, Data |  | `no app frame` 100% | `line = caller.detect { \|l\| l !~ %r{lib/chewy/strategy.rb:\|lib/chewy.rb` |
| 2 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` | `get_oid_type` | 152.81 / 152.81 | 0.0 | 153.09 | 100% | Array |  | `app/controllers/api/base_controller.rb:62` 18%, `app/controllers/api/base_controller.rb:44` 11% | `type_map.fetch(oid, fmod, sql_type) {` |
| 3 | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:101` † | `helper_names` | 152.39 / 152.39 | 0.0 | 152.98 | 14% | String, Array |  | `lib/mastodon/middleware/socket_cleanup.rb:11` 99%, `app/models/email_subscription.rb:47` 0% | `@path_helpers.map(&:to_s) + @url_helpers.map(&:to_s)` |
| 4 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | `#{method}` | 73.87 / 73.87 | 0.0 | 73.93 | 100% | Array, Hash |  | `app/models/setting.rb:76` 18%, `app/models/ip_block.rb:49` 11% | `dispatch(:#{method}, ...)` |
| 5 | `RAILS/activerecord/lib/arel/table.rb:85` | `[]` | 64.82 / 64.82 | 0.0 | 64.96 | 100% | Struct |  | `app/models/concerns/account/finder_concern.rb:34` 14%, `app/models/concerns/cacheable.rb:18` 6% | `Attribute.new(table, name)` |
| 6 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` | `cast_result` | 64.13 / 64.13 | 0.0 | 64.21 | 100% | String, Array |  | `app/controllers/api/base_controller.rb:62` 15%, `app/controllers/api/base_controller.rb:44` 8% | `ActiveRecord::Result.new(fields, result.values, types.freeze, affected` |
| 7 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` | `tag_option` | 54.11 / 54.11 | 0.0 | 54.23 | 17% | String |  | `lib/vite/tagger.rb:32` 74%, `lib/vite/tagger.rb:163` 9% | `%(#{key}="#{value}")` |
| 8 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` | `deep_dup` | 44.92 / 44.92 | 0.0 | 44.96 | 92% | String, Struct |  | `app/controllers/concerns/localized.rb:11` 67%, `lib/mastodon/middleware/socket_cleanup.rb:11` 9% | `duplicable? ? dup : self` |
| 9 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` | `xml_name_escape` | 43.44 / 43.44 | 0.0 | 43.53 | 17% | String |  | `lib/vite/tagger.rb:32` 93%, `app/helpers/application_helper.rb:157` 2% | `name = name.to_s` |
| 10 | `RAILS/activesupport/lib/active_support/cache.rb:1083` | `_instrument` | 42.57 / 42.57 | 0.0 | 42.6 | 100% | String |  | `app/models/setting.rb:76` 46%, `app/models/ip_block.rb:49` 21% | `debug_options = " (#{options.inspect})" unless options.blank?` |
| 11 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | `merge` | 37.58 / 37.58 | 0.0 | 37.61 | 81% | Object, Array |  | `app/models/user.rb:302` 12%, `app/controllers/api/base_controller.rb:62` 10% | `WhereClause.new(predicates \| other.predicates)` |
| 12 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:217` | `dispatch` | 36.93 / 36.93 | 0.0 | 36.96 | 100% | Array |  | `app/models/setting.rb:76` 18%, `app/models/ip_block.rb:49` 11% | `@broadcasts.map { \|logger\|` |
| 13 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` | `html_safe` | 34.41 / 34.41 | 0.0 | 34.42 | 32% | String |  | `lib/vite/tagger.rb:35` 23%, `lib/vite/tagger.rb:32` 23% | `ActiveSupport::SafeBuffer.new(self)` |
| 14 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` | `build_handle` | 33.42 / 33.42 | 0.0 | 33.47 | 100% | Object, Data | #59613 merged 2026-11-04, after this app's version, not released yet, #59235 merged 2026-10-21, after this app's version, not released yet | `app/lib/access_token_extension.rb:23` 12%, `app/models/setting.rb:77` 9% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 15 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` | `initialize` | 31.44 / 31.44 | 0.0 | 31.44 | 25% | String |  | `lib/vite/tagger.rb:32` 26%, `lib/vite/tagger.rb:35` 26% | `super` |
| 16 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:80` | `camelize` | 30.08 / 30.08 | 0.0 | 30.45 | 87% | String, MatchData |  | `lib/mastodon/middleware/socket_cleanup.rb:11` 94%, `app/controllers/concerns/authorization.rb:13` 1% | `string.gsub!(/(?:_\|(\/))([a-z\d]*)/i) do` |
| 17 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:235` | `compact_blank` | 29.82 / 29.82 | 0.0 | 29.85 | 100% | Hash |  | `app/lib/access_token_extension.rb:23` 14%, `app/models/setting.rb:77` 10% | `reject { \|_k, v\| v.blank? }` |
| 18 | `RAILS/activemodel/lib/active_model/attribute.rb:9` | `from_database` | 29.12 / 29.12 | 0.0 | 29.28 | 81% | Object |  | `app/lib/access_token_extension.rb:23` 38%, `app/models/status.rb:207` 16% | `FromDatabase.new(name, value_before_type_cast, type, nil, value)` |
| 19 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:287` | `build_handle` | 25.43 / 25.43 | 0.0 | 25.46 | 100% | Array | #59235 merged 2026-10-21, after this app's version, not released yet | `app/lib/access_token_extension.rb:23` 10%, `lib/mastodon/middleware/socket_cleanup.rb:11` 9% | `groups = groups_for(name).map do \|group_klass, grouped_listeners\|` |
| 20 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` | `create` | 24.9 / 24.9 | 0.0 | 24.97 | 100% | Object, Hash |  | `app/models/concerns/cacheable.rb:18` 10%, `app/models/user.rb:302` 8% | `relation_class_for(model).new(model, ...)` |
| 21 | `RAILS/activerecord/lib/active_record/relation.rb:77` | `initialize` | 24.27 / 24.27 | 0.0 | 24.33 | 100% | Hash |  | `app/models/concerns/cacheable.rb:18` 10%, `app/models/user.rb:302` 9% | `def initialize(model, table: nil, predicate_builder: nil, values: {})` |
| 22 | `GEM/doorkeeper/lib/doorkeeper/oauth/error_response.rb:110` | `sanitize_error_values` | 23.56 / 23.56 | 0.0 | 23.62 | 11% | String, Struct |  | `app/controllers/api/base_controller.rb:92` 35%, `app/controllers/api/v1/accounts_controller.rb:8` 3% | `if char.in?("\x20".encode("utf-8").."\x21".encode("utf-8")) \|\|` |
| 23 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` | `+` | 23.45 / 23.45 | 0.0 | 23.5 | 100% | Array, Object |  | `app/lib/access_token_extension.rb:23` 9%, `app/models/ip_block.rb:49` 8% | `WhereClause.new(predicates + other.predicates)` |
| 24 | `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` | `keys` | 23.21 / 23.21 | 0.0 | 23.29 | 62% | Array, Hash |  | `app/lib/access_token_extension.rb:23` 37%, `app/models/status.rb:207` 34% | `keys = values.keys \| types.keys \| @attributes.keys` |
| 25 | `GEM/active_model_serializers/lib/active_model/serializer/concerns/caching.rb:45` | `inherited` | 22.81 / 22.81 | 0.0 | 27.19 | 4% | String, Array |  | `app/lib/activitypub/serializer.rb:13` 29%, `app/serializers/rest/rule_serializer.rb:3` 1% | `caller_line = caller[1]` |
| 26 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` | `call` | 22.77 / 22.77 | 0.0 | 22.78 | 100% | Data |  | `app/controllers/concerns/localized.rb:11` 41%, `no app frame` 18% | `result_lambda = -> { user_callback.call target, value }` |
| 27 | `RAILS/actionview/lib/action_view/helpers/output_safety_helper.rb:36` | `safe_join` | 22.12 / 22.12 | 0.0 | 22.16 | 17% | Array, String |  | `lib/vite/tagger.rb:35` 73%, `app/helpers/application_helper.rb:117` 9% | `array.flatten.map! { \|i\| ERB::Util.unwrapped_html_escape(i) }.join(sep` |
| 28 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:78` | `camelize` | 22.06 / 22.06 | 0.0 | 22.43 | 87% | String, MatchData |  | `lib/mastodon/middleware/socket_cleanup.rb:11` 92%, `app/controllers/concerns/authorization.rb:13` 1% | `string = string.sub(/^[a-z\d]*/) { \|match\| inflections.acronyms[match]` |
| 29 | `GEM/doorkeeper/lib/doorkeeper/oauth/error_response.rb:111` | `sanitize_error_values` | 21.52 / 21.52 | 0.0 | 21.58 | 11% | String, Struct |  | `app/controllers/api/base_controller.rb:92` 35%, `app/controllers/api/v1/accounts_controller.rb:8` 3% | `char.in?("\x23".encode("utf-8").."\x5B".encode("utf-8")) \|\|` |
| 30 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` | `expand_from_hash` | 21.19 / 21.19 | 0.0 | 21.24 | 100% | Array |  | `app/models/ip_block.rb:49` 9%, `app/models/status.rb:128` 6% | `attributes.flat_map do \|key, value\|` |

## Dev/test-mode work

1320.7 of 6426.7 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | error page | `RUBY/error_highlight/base.rb:94` | 160.87 | 0% | `no app frame` 100% | `Prism.parse_file(absolute_path).value.breadth_first_search { \|node\| no` |
| 2 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` | 100.76 | 100% | `app/models/setting.rb:77` 10%, `app/lib/access_token_extension.rb:23` 10% | `binds = binds.inspect` |
| 3 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:177` | 89.27 | 100% | `app/lib/access_token_extension.rb:23` 14%, `app/models/setting.rb:77` 10% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 4 | error page | `GEM/prism/lib/prism/parse_result.rb:70` | 61.32 | 0% | `no app frame` 100% | `source.lines` |
| 5 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:175` | 59.64 | 100% | `app/lib/access_token_extension.rb:23` 14%, `app/models/setting.rb:77` 10% | `modes = MODES.values_at(*options.compact_blank.keys)` |
| 6 | debug logging | `GEM/logger/lib/logger/log_device.rb:33` | 49.91 | 100% | `app/models/setting.rb:76` 21%, `app/models/ip_block.rb:49` 10% | `handle_write_errors("writing") {@dev.write(message)}` |
| 7 | debug logging | `GEM/logger/lib/logger/log_device.rb:165` | 36.04 | 100% | `app/models/setting.rb:76` 18%, `app/models/ip_block.rb:49` 11% | `if @filename && (@shift_age > 0) && (@dev.stat.size > @shift_size)` |
| 8 | debug logging | `RAILS/activesupport/lib/active_support/logger.rb:42` | 36.04 | 100% | `app/models/setting.rb:76` 18%, `app/models/ip_block.rb:49` 11% | `"#{String === msg ? msg : msg.inspect}\n"` |
| 9 | debug logging | `GEM/logger/lib/logger.rb:692` † | 35.7 | 98% | `app/models/setting.rb:76` 18%, `app/models/ip_block.rb:49` 11% | `format_message(format_severity(severity), Time.now, progname, message)` |
| 10 | debug logging | `RAILS/actionpack/lib/action_controller/log_subscriber.rb:56` | 33.98 | 10% | `lib/mastodon/middleware/socket_cleanup.rb:11` 100% | `exception_backtrace = exception.backtrace&.first` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activerecord | 1888.1 | 1897.3 | `postgresql_adapter.rb:880` 152.8, `log_subscriber.rb:49` 100.8, `table.rb:85` 64.8 |
| rails: activesupport | 1341.9 | 1358.9 | `log_subscriber.rb:177` 89.3, `broadcast_logger.rb:129` 73.9, `log_subscriber.rb:175` 59.6 |
| rails: actionpack | 647.4 | 688.5 | `route_set.rb:101` 152.4, `log_subscriber.rb:56` 34.0, `logger.rb:12` 20.1 |
| gem: chewy | 493.2 | 493.4 | `strategy.rb:70` 467.2, `strategy.rb:71` 18.0, `railtie.rb:14` 3.0 |
| app | 395.5 | 414.4 | `tagger.rb:232` 48.8, `tagger.rb:24` 32.2, `initial_state_serializer.rb:93` 29.1 |
| rails: actionview | 257.9 | 262.3 | `tag_helper.rb:309` 54.1, `output_safety_helper.rb:36` 22.1, `tag_helper.rb:237` 12.9 |
| ruby stdlib | 193.5 | 377.0 | `base.rb:94` 160.9, `formatter.rb:174` 7.3, `delegate.rb:88` 2.3 |
| gem: active_model_serializers | 141.7 | 147.2 | `caching.rb:45` 22.8, `serializer.rb:341` 18.3, `serializer.rb:330` 7.7 |
| rails: activemodel | 136.7 | 139.7 | `attribute.rb:9` 29.1, `builder.rb:37` 23.2, `string.rb:39` 8.0 |
| gem: logger | 135.3 | 135.4 | `log_device.rb:33` 56.3, `log_device.rb:165` 36.0, `logger.rb:692` 35.7 |
| gem: temple | 125.1 | 134.4 | `static_analyzer.rb:14` 18.0, `dispatcher.rb:87` 15.5, `dispatcher.rb:7` 13.6 |
| gem: doorkeeper | 124.0 | 126.2 | `error_response.rb:110` 23.6, `error_response.rb:111` 21.5, `error_response.rb:112` 20.6 |
| ruby default gem: prism | 103.1 | 214.8 | `parse_result.rb:70` 61.3, `node.rb:2797` 6.7, `node.rb:18058` 4.8 |
| gem: haml | 82.0 | 87.7 | `ruby_expression.rb:25` 20.0, `parser.rb:117` 4.6, `parser.rb:865` 3.0 |
| gem: rack | 74.9 | 75.3 | `utils.rb:693` 16.1, `request.rb:607` 13.3, `body_proxy.rb:12` 4.0 |
| ruby default gem: uri | 67.5 | 67.8 | `generic.rb:1007` 9.8, `common.rb:465` 7.2, `rfc2396_parser.rb:320` 5.6 |
| gem: nokogiri | 62.0 | 63.0 | `node.rb:1431` 8.6, `document.rb:85` 8.3, `node.rb:1515` 4.5 |
| gem: inline_svg | 59.0 | 60.5 | `transformations.rb:54` 14.7, `asset_file.rb:8` 4.5, `class_attribute.rb:5` 3.7 |
| gem: i18n | 42.4 | 42.6 | `fallbacks.rb:98` 6.0, `fallbacks.rb:54` 5.7, `fallbacks.rb:60` 5.1 |
| gem: simple-navigation | 42.3 | 43.8 | `item.rb:148` 9.5, `configuration.rb:26` 8.1, `item.rb:152` 7.1 |
| gem: jsonapi-renderer | 32.1 | 32.3 | `parser.rb:41` 10.7, `include_directive.rb:18` 8.0, `include_directive.rb:44` 8.0 |
| ruby default gem: ipaddr | 30.9 | 31.0 | `ipaddr.rb:769` 14.2, `ipaddr.rb:716` 5.7, `ipaddr.rb:844` 4.0 |
| gem: tzinfo | 30.5 | 39.7 | `timestamp.rb:208` 14.7, `timestamp.rb:193` 7.8, `constant_offset_data_timezone_info.rb:52` 7.1 |
| gem: warden | 30.3 | 30.3 | `proxy.rb:334` 3.8, `proxy.rb:348` 3.7, `proxy.rb:31` 2.3 |
| gem: kt-paperclip | 29.5 | 30.0 | `interpolations.rb:38` 12.1, `attachment.rb:389` 1.6, `has_attached_file.rb:45` 1.4 |
| gem: css_parser | 25.5 | 31.9 | `rule_set.rb:116` 2.4, `parser.rb:407` 2.2, `css_parser.rb:112` 2.1 |
| gem: concurrent-ruby | 19.6 | 19.7 | `safe_initialization.rb:30` 6.0, `non_concurrent_map_backend.rb:131` 2.1, `mutex_lockable_object.rb:32` 2.0 |
| gem: ruby-vips | 17.7 | 20.8 | `image.rb:1256` 16.1, `object.rb:203` 0.2, `object.rb:202` 0.2 |
| gem: propshaft | 14.7 | 76.5 | `helper.rb:128` 4.1, `helper.rb:125` 2.0, `helper.rb:137` 2.0 |
| gem: addressable | 14.5 | 14.8 | `uri.rb:136` 2.6, `native.rb:43` 0.9, `uri.rb:486` 0.6 |
| gem: rack-attack | 13.3 | 13.3 | `cache.rb:73` 3.5, `attack.rb:93` 3.4, `cache.rb:80` 1.2 |
| gem: mail | 11.7 | 12.5 | `utilities.rb:215` 1.4, `parameter_hash.rb:22` 0.8, `field_list.rb:71` 0.7 |
| gem: json | 11.7 | 11.9 | `common.rb:364` 9.8, `common.rb:1089` 1.6, `common.rb:454` 0.2 |
| gem: rack-cors | 11.1 | 11.1 | `cors.rb:123` 7.7, `resource.rb:40` 1.3, `result.rb:38` 1.0 |
| gem: connection_pool | 10.5 | 10.6 | `connection_pool.rb:64` 2.9, `connection_pool.rb:67` 2.9, `timed_stack.rb:221` 2.1 |
| gem: devise | 10.5 | 10.7 | `helpers.rb:128` 3.6, `authenticatable.rb:173` 2.4, `authenticatable.rb:174` 1.8 |
| rails: railties | 9.0 | 9.0 | `logger.rb:57` 2.0, `logger.rb:37` 1.0, `logger.rb:21` 1.0 |
| gem: rdf | 8.6 | 10.3 | `nquads.rb:129` 0.5, `statement.rb:396` 0.4, `node.rb:170` 0.4 |
| gem: simple_form | 7.5 | 8.0 | `many.rb:61` 1.0, `many.rb:66` 1.0, `leaf.rb:13` 0.5 |
| gem: http_accept_language | 6.1 | 6.7 | `middleware.rb:8` 3.0, `middleware.rb:10` 2.0, `parser.rb:81` 0.7 |
| gem: premailer | 6.0 | 7.5 | `nokogiri.rb:228` 2.1, `nokogiri.rb:49` 1.3, `premailer.rb:462` 0.5 |
| gem: stoplight | 5.0 | 5.4 | `config.rb:41` 0.5, `light_builder.rb:77` 0.4, `compatibility_result.rb:14` 0.4 |
| gem: redis-client | 4.3 | 4.4 | `redis_client.rb:613` 1.2, `redis_client.rb:511` 1.2, `redis_client.rb:515` 1.1 |
| gem: redis | 4.1 | 4.2 | `client.rb:116` 1.0, `pipeline.rb:9` 1.0, `redis.rb:107` 1.0 |
| gem: rack-session | 3.0 | 3.0 | `id.rb:275` 1.0, `id.rb:277` 1.0, `id.rb:368` 0.8 |
| gem: sidekiq | 3.0 | 3.0 | `job.rb:396` 0.4, `job.rb:299` 0.3, `chain.rb:201` 0.3 |
| ruby default gem: securerandom | 2.8 | 2.8 | `securerandom.rb:71` 2.8 |
| gem: bootsnap | 2.8 | 3.1 | `iseq.rb:99` 1.8, `iseq.rb:156` 0.4, `kernel_require.rb:11` 0.3 |
| test harness: rspec-mocks | 2.5 | 2.6 | `recorder.rb:135` 0.3, `message_chains.rb:7` 0.2, `message_expectation.rb:629` 0.2 |
| gem: discard | 2.1 | 2.1 | `model.rb:17` 2.0, `model.rb:19` 0.1, `model.rb:21` 0.0 |
| gem: pundit | 2.1 | 2.1 | `context.rb:166` 0.3, `policy_finder.rb:108` 0.3, `context.rb:179` 0.3 |
| gem: base64 | 2.0 | 2.0 | `base64.rb:283` 1.0, `base64.rb:310` 0.8, `base64.rb:374` 0.1 |
| gem: http | 1.9 | 2.2 | `normalizer.rb:47` 0.3, `options.rb:168` 0.2, `headers.rb:104` 0.2 |
| gem: json-ld | 1.9 | 2.9 | `context.rb:1314` 0.1, `context.rb:155` 0.1, `flatten.rb:258` 0.1 |
| gem: zeitwerk | 1.8 | 2.6 | `cref.rb:47` 0.4, `file_system.rb:203` 0.3, `constant_path_validator.rb:13` 0.3 |
| gem: link_header | 1.7 | 1.7 | `link_header.rb:195` 1.2, `link_header.rb:31` 0.2, `link_header.rb:62` 0.2 |
| ruby default gem: openssl | 1.6 | 1.6 | `hmac.rb:57` 0.5, `hmac.rb:55` 0.5, `cipher.rb:56` 0.2 |
| gem: globalid | 1.6 | 1.6 | `gid.rb:95` 0.3, `gid.rb:159` 0.3, `gid.rb:166` 0.2 |
| gem: rdf-normalize | 1.4 | 1.7 | `writer.rb:48` 0.1, `rdfc10.rb:200` 0.1, `rdfc10.rb:210` 0.1 |
| gem: starry | 1.2 | 1.2 | `parser.rb:163` 0.2, `starry.rb:30` 0.1, `starry.rb:36` 0.1 |
| rails: activejob | 1.1 | 1.1 | `log_subscriber.rb:207` 0.3, `configured_job.rb:15` 0.1, `log_subscriber.rb:201` 0.1 |
| test harness: webmock | 1.0 | 1.2 | `headers.rb:69` 0.2, `headers.rb:68` 0.2, `headers.rb:16` 0.1 |
| gem: fastimage | 1.0 | 1.3 | `fiber_stream.rb:49` 0.2, `fiber_stream.rb:33` 0.1, `fiber_stream.rb:47` 0.1 |
| gem: ffi | 0.9 | 1.1 | `managedstruct.rb:80` 0.3, `autopointer.rb:88` 0.2, `struct_by_reference.rb:69` 0.2 |
| gem: sanitize | 0.8 | 0.9 | `sanitize.rb:204` 0.3, `sanitize.rb:207` 0.1, `clean_element.rb:71` 0.1 |
| gem: erubi | 0.8 | 0.9 | `erubi.rb:134` 0.5, `erubi.rb:137` 0.1, `erubi.rb:139` 0.1 |
| ruby default gem: forwardable | 0.8 | 0.8 | `forwardable.rb:231` 0.8 |
| gem: linzer | 0.7 | 0.8 | `signature.rb:236` 0.0, `common.rb:61` 0.0, `signature.rb:173` 0.0 |
| gem: hiredis-client | 0.7 | 0.7 | `hiredis_connection.rb:90` 0.7 |
| gem: uts58 | 0.7 | 0.7 | `extractor.rb:77` 0.5, `extractor.rb:71` 0.2, `extractor.rb:233` 0.0 |
| test harness: rspec-support | 0.6 | 0.7 | `method_signature_verifier.rb:135` 0.1, `fuzzy_matcher.rb:35` 0.1, `method_signature_verifier.rb:403` 0.0 |
| gem: terrapin | 0.6 | 1.6 | `process_runner.rb:30` 0.4, `command_line.rb:191` 0.1, `command_line.rb:180` 0.0 |
| gem: parslet | 0.5 | 0.9 | `context.rb:34` 0.0, `source.rb:22` 0.0, `base.rb:90` 0.0 |
| gem: loofah | 0.5 | 0.5 | `concerns.rb:172` 0.2, `concerns.rb:43` 0.1, `scrubber.rb:132` 0.1 |
| gem: browser | 0.5 | 0.6 | `platform.rb:50` 0.1, `base.rb:278` 0.1, `browser.rb:109` 0.1 |
| gem: mime-types | 0.3 | 2.0 | `types.rb:149` 0.2, `types.rb:154` 0.0, `types.rb:155` 0.0 |
| gem: marcel | 0.3 | 0.3 | `magic.rb:18` 0.1, `mime_type.rb:90` 0.0, `mime_type.rb:73` 0.0 |
| rails: actionmailer | 0.2 | 0.3 | `base.rb:636` 0.0, `message_delivery.rb:154` 0.0, `base.rb:1009` 0.0 |
| gem: hkdf | 0.2 | 0.3 | `hkdf.rb:52` 0.0, `hkdf.rb:75` 0.0, `hkdf.rb:64` 0.0 |
| gem: rails-html-sanitizer | 0.2 | 0.2 | `sanitizer.rb:192` 0.0, `sanitizer.rb:56` 0.0, `sanitizer.rb:33` 0.0 |
| gem: orm_adapter | 0.2 | 0.2 | `base.rb:100` 0.0, `base.rb:105` 0.0, `active_record.rb:54` 0.0 |
| gem: bcrypt | 0.2 | 0.2 | `password.rb:102` 0.1, `engine.rb:70` 0.0, `password.rb:103` 0.0 |
| gem: webpush | 0.2 | 0.2 | `encryption.rb:49` 0.0, `encryption.rb:15` 0.0, `encryption.rb:28` 0.0 |
| gem: ox | 0.2 | 0.2 | `element.rb:42` 0.1, `element.rb:41` 0.1, `hasattrs.rb:30` 0.0 |
| gem: csv | 0.2 | 0.2 | `writer.rb:154` 0.0, `writer.rb:156` 0.0, `writer.rb:51` 0.0 |
| gem: httplog | 0.1 | 0.2 | `http_log.rb:271` 0.0, `http_log.rb:272` 0.0, `http_log.rb:170` 0.0 |
| gem: responders | 0.1 | 0.2 | `respond_with.rb:248` 0.0, `respond_with.rb:208` 0.0, `respond_with.rb:214` 0.0 |
| gem: sidekiq-unique-jobs | 0.1 | 0.1 | `core_ext.rb:103` 0.1, `core_ext.rb:107` 0.0 |
| gem: kaminari-core | 0.1 | 0.1 | `tags.rb:140` 0.0, `page_scope_methods.rb:10` 0.0, `helper_methods.rb:122` 0.0 |
| gem: mario-redis-lock | 0.1 | 0.1 | `redis_lock.rb:111` 0.0, `redis_lock.rb:56` 0.0, `redis_lock.rb:38` 0.0 |
| gem: bigdecimal | 0.1 | 0.1 | `util.rb:24` 0.1, `util.rb:51` 0.0 |
| gem: case_transform | 0.1 | 0.1 | `case_transform.rb:47` 0.1, `case_transform.rb:8` 0.0, `version.rb:2` 0.0 |
| gem: opentelemetry-api | 0.1 | 0.1 | `context.rb:158` 0.0, `proxy_tracer.rb:34` 0.0, `context.rb:160` 0.0 |
| gem: public_suffix | 0.1 | 0.1 | `rule.rb:202` 0.0, `rule.rb:203` 0.0, `list.rb:202` 0.0 |
| gem: sidekiq-bulk | 0.1 | 0.1 | `bulk.rb:5` 0.0, `bulk.rb:9` 0.0, `bulk.rb:14` 0.0 |
| gem: premailer-rails | 0.1 | 0.1 | `hook.rb:45` 0.0, `css_helper.rb:27` 0.0, `css_helper.rb:13` 0.0 |
| gem: pg | 0.0 | 1.7 | `coder.rb:21` 0.0, `result.rb:17` 0.0, `date.rb:14` 0.0 |
| gem: http-cookie | 0.0 | 0.0 | `cookie_jar.rb:57` 0.0, `hash_store.rb:34` 0.0, `cookie_jar.rb:21` 0.0 |
| gem: scenic | 0.0 | 0.0 | `postgres.rb:274` 0.0, `postgres.rb:263` 0.0, `postgres.rb:280` 0.0 |
| gem: kaminari-activerecord | 0.0 | 0.0 | `active_record_model_extension.rb:31` 0.0, `active_record_relation_methods.rb:14` 0.0, `active_record_relation_methods.rb:30` 0.0 |
| ruby default gem: prettyprint | 0.0 | 0.0 | `prettyprint.rb:404` 0.0, `prettyprint.rb:264` 0.0, `prettyprint.rb:459` 0.0 |
| gem: blurhash | 0.0 | 0.0 | `blurhash.rb:10` 0.0, `blurhash.rb:11` 0.0 |
| gem: rainbow | 0.0 | 0.0 | `wrapper.rb:18` 0.0 |
| ruby default gem: pp | 0.0 | 0.0 | `pp.rb:542` 0.0, `pp.rb:271` 0.0, `pp.rb:268` 0.0 |
| gem: devise-two-factor | 0.0 | 0.0 | `two_factor_backupable.rb:20` 0.0, `two_factor_authenticatable.rb:14` 0.0, `two_factor_authenticatable.rb:67` 0.0 |
| lowrail-profile | 0.0 | 0.0 | `profile.rb:107` 0.0, `profile.rb:66` 0.0, `profile.rb:56` 0.0 |
| test harness: rspec-core | 0.0 | 0.0 | `memoized_helpers.rb:343` 0.0 |
| gem: bloom_fit | 0.0 | 0.0 | `bloom_fit.rb:59` 0.0, `bloom_fit.rb:235` 0.0 |
| gem: kaminari-actionview | 0.0 | 0.0 | `action_view_extension.rb:14` 0.0, `action_view_extension.rb:12` 0.0, `action_view_extension.rb:0` 0.0 |
| gem: rotp | 0.0 | 0.1 | `base32.rb:41` 0.0, `base32.rb:33` 0.0, `base32.rb:46` 0.0 |
| ruby default gem: bundler | 0.0 | 0.0 | `rubygems_integration.rb:192` 0.0 |
| gem: webauthn | 0.0 | 0.0 | `json_serializer.rb:29` 0.0, `json_serializer.rb:42` 0.0, `credential.rb:15` 0.0 |
| gem: msgpack | 0.0 | 0.0 | `factory.rb:31` 0.0, `factory.rb:16` 0.0, `factory.rb:14` 0.0 |
| gem: racc | 0.0 | 0.0 | `parser.rb:263` 0.0 |
| gem: tzinfo-data | 0.0 | 0.6 | `Brussels.rb:10` 0.0, `Kabul.rb:13` 0.0, `Buenos_Aires.rb:11` 0.0 |
| gem: json-ld-preloaded | 0.0 | 0.1 | `activitystreams.rb:56` 0.0, `activitystreams.rb:19` 0.0, `activitystreams.rb:78` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Jobs

| # | Job | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | ActionMailer::MailDeliveryJob#perform | 75 / 75 | 30435.0 / 30423.3 | -11.7 | 31085.5 | `GEM/css_parser/lib/css_parser/rule_set.rb:116` 1452.9, `GEM/css_parser/lib/css_parser/parser.rb:407` 1119.0, `GEM/css_parser/lib/css_parser.rb:112` 1063.0 | `app/services/notify_service.rb:302` 22619.2, `app/mailers/notification_mailer.rb:27` 856.1, `app/mailers/notification_mailer.rb:35` 718.4 |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/css_parser/lib/css_parser/rule_set.rb:116` | 1433.49 / 1433.49 | 100% | `app/services/notify_service.rb:302` 89%, `no app frame` 8% | `value = Value.new(value)` |
| 2 | `GEM/css_parser/lib/css_parser/parser.rb:407` | 1104.08 / 1104.08 | 100% | `app/services/notify_service.rb:302` 97%, `app/controllers/auth/sessions_controller.rb:167` 1% | `token = scanner.scan(RULESET_TOKENIZER_RX)` |
| 3 | `GEM/css_parser/lib/css_parser.rb:112` | 1048.83 / 1048.83 | 100% | `app/services/notify_service.rb:302` 97%, `app/controllers/auth/sessions_controller.rb:186` 1% | `c = selector.scan(NON_ID_ATTRIBUTES_AND_PSEUDO_CLASSES_RX_NC).length` |
| 4 | `GEM/premailer/lib/premailer/adapter/nokogiri.rb:228` | 1045.87 / 1045.87 | 100% | `app/services/notify_service.rb:302` 97%, `app/controllers/auth/sessions_controller.rb:167` 1% | `selector.scan(CLASS_IN_SELECTOR).any? { \|(name)\| !classes_in_doc.inclu` |
| 5 | `GEM/css_parser/lib/css_parser/rule_set.rb:671` | 945.84 / 945.84 | 100% | `app/services/notify_service.rb:302` 97%, `app/controllers/auth/sessions_controller.rb:167` 1% | `block.split(SEMICOLON) do \|decs\|` |
| 6 | `GEM/css_parser/lib/css_parser/rule_set.rb:683` | 881.65 / 881.65 | 100% | `app/services/notify_service.rb:302` 97%, `app/controllers/auth/sessions_controller.rb:186` 1% | `value = decs[colon + 1, decs.length]` |
| 7 | `GEM/css_parser/lib/css_parser/rule_set.rb:682` | 832.37 / 832.37 | 100% | `app/services/notify_service.rb:302` 97%, `app/controllers/auth/sessions_controller.rb:167` 1% | `property = decs[0, colon]` |
| 8 | `GEM/mail/lib/mail/utilities.rb:215` | 672.56 / 672.56 | 100% | `app/services/notify_service.rb:302` 73%, `app/mailers/notification_mailer.rb:27` 12% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 9 | `GEM/premailer/lib/premailer/adapter/nokogiri.rb:49` | 647.25 / 647.25 | 100% | `app/services/notify_service.rb:302` 97%, `app/controllers/auth/sessions_controller.rb:167` 1% | `selector.gsub!(/([\s]\|^)([\w]+)/) { \|_m\| $1.to_s + $2.to_s.downcase }` |
| 10 | `GEM/css_parser/lib/css_parser/rule_set.rb:702` | 579.17 / 579.17 | 100% | `app/services/notify_service.rb:302` 97%, `app/controllers/auth/sessions_controller.rb:186` 1% | `@selectors = selectors.split(',').map! do \|s\|` |
