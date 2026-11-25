# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bundle exec rspec spec/requests --format documentation`
* Ruby: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux]
* Rails: 8.1.4.1, test environment
* Counted in run 1: 4069 requests, 4 jobs; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 4069 | 31691.3 | 4 | 0 | 0 | 0 |
| run2 | 1 | 4069 | 31683.6 | 4 | 0 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 1.08 objects per request; 1 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/services/responsive_qr_svg.rb:29` | `call` | 7728.18 | 0.0 | 0.29 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_util.rb:93` 87%, `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_polynomial.rb:32` 6%, `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_polynomial.rb:15` 1% | Map::MaplibreController#index 13%, TripsController#index 8%, TripsController#show 7% | `qrcode = RQRCode::QRCode.new(@content)` |
| 2 | `app/services/responsive_qr_svg.rb:30` | `call` | 1436.99 | 0.0 | 0.14 | `GEM/rqrcode/lib/rqrcode/export/svg.rb:146` 22%, `GEM/rqrcode/lib/rqrcode/export/svg.rb:87` 17%, `GEM/rqrcode/lib/rqrcode/export/svg.rb:59` 17% | Map::MaplibreController#index 13%, TripsController#index 8%, TripsController#show 7% | `svg = qrcode.as_svg(` |
| 3 | `app/services/demo_data/tracks_seeder.rb:30` | `call` | 1388.27 | 11.6 | 0.12 | `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:187` 19%, `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:184` 19%, `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:193` 13% | Settings::OnboardingsController#demo_data 100% | `track = @user.tracks.create!(` |
| 4 | `app/serializers/track_serializer.rb:20` | `call` | 1173.11 | 0.0 | 0.0 | `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:187` 23%, `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:184` 23%, `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:197` 15% | Settings::OnboardingsController#demo_data 100%, Tracks::SegmentsController#update 0% | `original_path: @track.original_path.to_s` |
| 5 | `app/services/demo_data/destroyer.rb:15` | `call` | 592.24 | 0.01 | 0.0 | `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:184` 23%, `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:187` 23%, `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:193` 15% | Settings::OnboardingsController#destroy_demo_data 100% | `ActiveRecord::Base.transaction do` |
| 6 | `app/views/layouts/application.html.erb:20` |  | 321.7 | 267.4 | 0.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 33%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 17%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 17% | Users::RegistrationsController#new 8%, TripsController#index 8%, TripsController#show 6% | `<%= javascript_importmap_tags %>` |
| 7 | `app/services/demo_data/points_seeder.rb:45` | `call` | 169.43 | 0.03 | 0.0 | `RAILS/activerecord/lib/active_record/insert_all.rb:62` 9%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:149` 6%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/quoting.rb:129` 5% | Settings::OnboardingsController#demo_data 100% | `Point.insert_all(rows, returning: false)` |
| 8 | `app/controllers/api_controller.rb:158` | `current_api_user` | 109.26 | 15.95 | 0.92 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 18%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 17%, `GEM/yabeda-prometheus/lib/yabeda/prometheus/adapter.rb:93` 5% | Api::V1::Tiles::PointsController#show 10%, Api::V1::Imports::PendingController#create 7%, Api::V1::Tiles::TracksController#show 7% | `@current_api_user \|\|= User.find_by(api_key:)` |
| 9 | `app/services/users/safe_settings.rb:115` | `initialize` | 107.16 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 80%, `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:44` 11%, `RAILS/activesupport/lib/active_support/deep_mergeable.rb:30` 5% | Map::MaplibreController#index 12%, TripsController#show 7%, TripsController#index 5% | `@settings = DEFAULT_VALUES.deep_dup.deep_merge(settings)` |
| 10 | `app/services/users/privacy_zones.rb:13` | `call` | 75.91 | 10.93 | 0.59 | `GEM/yabeda-prometheus/lib/yabeda/prometheus/adapter.rb:93` 5%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 3%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 3% | Settings::OnboardingsController#demo_data 26%, Api::V1::Tiles::PointsController#show 14%, Api::V1::Tiles::TracksController#show 11% | `@user.tags.privacy_zones.includes(:places).flat_map do \|tag\|` |
| 11 | `app/models/concerns/user_family.rb:25` | `in_family?` | 61.21 | 10.95 | 0.0 | `GEM/yabeda-prometheus/lib/yabeda/prometheus/adapter.rb:93` 5%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 4%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 3% | Api::V1::Tiles::PointsController#show 9%, Api::V1::Tiles::TracksController#show 7%, Map::MaplibreController#index 6% | `family_membership.present?` |
| 12 | `config/initializers/date_time_preferences.rb:28` | `localize` | 59.6 | 0.0 | 0.0 | `GEM/i18n/lib/i18n/backend/base.rb:290` 24%, `GEM/i18n/lib/i18n/backend/flatten.rb:34` 18%, `GEM/i18n/lib/i18n/backend/base.rb:58` 9% | Map::ResidencyController#show 67%, InsightsController#index 14%, TripsController#show 4% | `return super if preferences.default? \|\| !format.is_a?(Symbol) \|\| !obje` |
| 13 | `lib/dawarich/aggregating_metrics.rb:34` | `call` | 57.42 | 0.0 | 0.0 | `GEM/prometheus-client/lib/prometheus/client/formats/text.rb:78` 31%, `GEM/prometheus-client/lib/prometheus/client/formats/text.rb:77` 19%, `GEM/prometheus-client/lib/prometheus/client/formats/text.rb:85` 15% | - 100% | `status, headers, body = @local_app.call(env)` |
| 14 | `app/services/demo_data/derivatives_seeder.rb:80` | `seed_visits` | 57.16 | 13.97 | 0.15 | `RAILS/activerecord/lib/arel/visitors/postgresql.rb:136` 6%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 5%, `RAILS/activerecord/lib/arel/table.rb:85` 4% | Settings::OnboardingsController#demo_data 100% | `visit = @user.visits.create!(` |
| 15 | `app/services/demo_data/destroyer.rb:18` | `call` | 56.86 | 10.23 | 0.0 | `GEM/yabeda-prometheus/lib/yabeda/prometheus/adapter.rb:93` 6%, `RAILS/activerecord/lib/arel/table.rb:85` 6%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 4% | Settings::OnboardingsController#destroy_demo_data 100% | `@user.tracks.demo.destroy_all` |
| 16 | `app/services/demo_data/destroyer.rb:16` | `call` | 56.65 | 10.4 | 0.0 | `RAILS/activerecord/lib/arel/table.rb:85` 7%, `GEM/yabeda-prometheus/lib/yabeda/prometheus/adapter.rb:93` 6%, `GEM/prometheus-client/lib/prometheus/client/label_set_validator.rb:52` 3% | Settings::OnboardingsController#destroy_demo_data 100% | `@user.visits.demo.destroy_all` |
| 17 | `app/services/demo_data/tracks_seeder.rb:46` | `call` | 53.9 | 11.72 | 0.12 | `RAILS/activerecord/lib/arel/visitors/postgresql.rb:136` 6%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 4%, `RAILS/activerecord/lib/arel/table.rb:85` 4% | Settings::OnboardingsController#demo_data 100% | `track.track_segments.create!(` |
| 18 | `app/services/users/date_time_preferences.rb:21` | `with` | 50.82 | 15.35 | 0.0 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` 9%, `RAILS/actionpack/lib/abstract_controller/rendering.rb:66` 4%, `RAILS/actionview/lib/action_view/base.rb:230` 4% | Map::MaplibreController#index 7%, TripsController#index 5%, InsightsController#index 4% | `Current.set(date_time_preferences: preferences, &)` |
| 19 | `app/controllers/application_controller.rb:217` | `switch_locale` | 46.9 | 3.42 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 6%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 5%, `GEM/uri/lib/uri/common.rb:465` 3% | Users::SessionsController#create 26%, Settings::BackgroundJobsController#update 4%, Trial::WelcomeController#show 4% | `locale = parameter_locale \|\| current_user&.preferred_locale \|\| support` |
| 20 | `app/controllers/application_controller.rb:324` | `sign_out_deleted_users` | 45.47 | 0.13 | 0.0 | `GEM/devise/lib/devise/strategies/authenticatable.rb:173` 7%, `RAILS/activesupport/lib/active_support/inflector/methods.rb:103` 7%, `RAILS/activesupport/lib/active_support/key_generator.rb:63` 5% | Api::V1::Tiles::PointsController#show 10%, Api::V1::Tiles::TracksController#show 7%, Api::V1::SettingsController#update 5% | `return unless current_user&.deleted?` |
| 21 | `app/controllers/api/v1/countries/borders_controller.rb:10` | `index` | 44.58 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/json/encoding.rb:252` 100%, `RAILS/actionpack/lib/action_controller/metal/rendering.rb:228` 0%, `RAILS/actionpack/lib/action_controller/metal/rendering.rb:232` 0% | Api::V1::Countries::BordersController#index 100% | `render json: countries` |
| 22 | `app/services/instance_settings/resolver.rb:112` | `load_stored` | 44.47 | 12.95 | 0.0 | `GEM/yabeda-prometheus/lib/yabeda/prometheus/adapter.rb:93` 12%, `GEM/prometheus-client/lib/prometheus/client/label_set_validator.rb:52` 7%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 3% | Map::MaplibreController#index 10%, TripsController#index 7%, InsightsController#index 5% | `connection.transaction(requires_new: true) { InstanceSetting.all.to_a ` |
| 23 | `app/controllers/api/v1/imports/pending_controller.rb:58` | `create` | 42.74 | 6.57 | 0.0 | `GEM/yabeda-prometheus/lib/yabeda/prometheus/adapter.rb:93` 4%, `GEM/prometheus-client/lib/prometheus/client/label_set_validator.rb:52` 2%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 2% | Api::V1::Imports::PendingController#create 100% | `pending.save!` |
| 24 | `app/services/demo_data/destroyer.rb:21` | `call` | 37.84 | 8.04 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 25%, `GEM/yabeda-prometheus/lib/yabeda/prometheus/adapter.rb:93` 6%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 6% | Settings::OnboardingsController#destroy_demo_data 100% | `demo_import.destroy` |
| 25 | `app/views/layouts/map.html.erb:17` |  | 34.31 | 28.52 | 0.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 33%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 17%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 17% | Map::MaplibreController#index 100% | `<%= javascript_importmap_tags %>` |
| 26 | `app/views/map/_onboarding_modal.html.erb:8` |  | 31.74 | 5.14 | 0.0 | `GEM/yabeda-prometheus/lib/yabeda/prometheus/adapter.rb:93` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 4%, `GEM/prometheus-client/lib/prometheus/client/label_set_validator.rb:52` 3% | Map::MaplibreController#index 9%, TripsController#index 9%, TripsController#show 6% | `data-onboarding-modal-imports-count-value="<%= current_user.imports.co` |
| 27 | `app/views/layouts/shared.html.erb:15` |  | 31.65 | 26.3 | 0.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 33%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 17%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 17% | Shared::LinksController#show 75%, Shared::AchievementsController#show 14%, Shared::LinksController#unlock 8% | `<%= javascript_importmap_tags %>` |
| 28 | `app/views/map/_onboarding_modal.html.erb:2` |  | 30.88 | 5.79 | 0.0 | `GEM/yabeda-prometheus/lib/yabeda/prometheus/adapter.rb:93` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 4%, `GEM/prometheus-client/lib/prometheus/client/label_set_validator.rb:52` 3% | Map::MaplibreController#index 12%, TripsController#show 6%, TripsController#index 6% | `<% has_home = current_user.homes.exists? %>` |
| 29 | `app/views/imports/_supported_formats.html.erb:17` |  | 29.49 | 0.0 | 14.72 | `GEM/i18n/lib/i18n/backend/flatten.rb:21` 14%, `GEM/i18n/lib/i18n/backend/flatten.rb:34` 14%, `RAILS/actionview/lib/action_view/helpers/translation_helper.rb:91` 14% | Map::MaplibreController#index 12%, TripsController#index 8%, TripsController#show 6% | `<li class="flex items-start gap-1.5"><%= icon 'circle-check', class: '` |
| 30 | `app/views/map/_onboarding_modal.html.erb:11` |  | 26.34 | 6.28 | 0.16 | `GEM/yabeda-prometheus/lib/yabeda/prometheus/adapter.rb:93` 7%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `GEM/prometheus-client/lib/prometheus/client/label_set_validator.rb:52` 4% | Map::MaplibreController#index 11%, TripsController#index 9%, TripsController#show 6% | `data-onboarding-modal-has-demo-data-value="<%= current_user.imports.ex` |

1187.83 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | Settings::OnboardingsController#demo_data | 6 / 6 | 2506388.6 / 2506401.8 | 13.2 | 2610739.3 | `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:184` 439084.8, `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:187` 439084.8, `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:197` 292723.2 | `app/services/demo_data/tracks_seeder.rb:30` 1129774.4, `app/serializers/track_serializer.rb:20` 954560.0, `app/services/demo_data/points_seeder.rb:45` 137884.6 |
| 2 | Settings::OnboardingsController#destroy_demo_data | 3 / 3 | 1625807.0 / 1626729.5 | 922.5 | 1085304.0 | `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:187` 274452.0, `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:184` 274452.0, `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:197` 182968.0 | `app/services/demo_data/destroyer.rb:15` 1204904.5, `app/services/demo_data/destroyer.rb:18` 115679.5, `app/services/demo_data/destroyer.rb:16` 115252.0 |
| 3 | Tracks::SegmentsController#index | 2 / 2 | 581551.0 / 581551.0 | 0.0 | 292794.0 | `RAILS/actionview/lib/action_view/buffers.rb:44` 2304.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 1047.0, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:11` 1032.0 | `app/controllers/tracks/segments_controller.rb:91` 291.0, `app/services/users/safe_settings.rb:115` 70.0, `app/models/notification.rb:27` 37.0 |
| 4 | RouteVideosController#destroy | 2 / 2 | 563463.0 / 563454.0 | -9.0 | 283244.0 | `RAILS/actionview/lib/action_view/buffers.rb:44` 2393.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 1089.0, `RAILS/actionview/lib/action_view/helpers/url_helper.rb:438` 1074.0 | `app/controllers/route_videos_controller.rb:45` 269.0, `app/services/users/safe_settings.rb:115` 70.0, `app/models/notification.rb:27` 37.0 |
| 5 | Achievements::CollectiblesController#show | 2 / 2 | 511774.0 / 511767.0 | -7.0 | 267931.0 | `RAILS/actionview/lib/action_view/buffers.rb:44` 2194.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 999.0, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:11` 984.0 | `app/controllers/application_controller.rb:217` 432.0, `app/models/achievements/collection_state.rb:26` 315.0, `app/controllers/achievements/collectibles_controller.rb:29` 288.0 |
| 6 | Api::V1::Countries::BordersController#index | 4 / 4 | 437942.7 / 437942.7 | 0.0 | 329118.8 | `RAILS/activesupport/lib/active_support/json/encoding.rb:252` 60448.7, `GEM/posthog-rails/lib/posthog/rails/tracing_headers.rb:77` 340.0, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 54.0 | `app/controllers/api/v1/countries/borders_controller.rb:10` 60464.0, `app/controllers/api_controller.rb:158` 288.7, `app/controllers/application_controller.rb:324` 107.0 |
| 7 | Trips::NotesController#destroy | 3 / 3 | 313855.0 / 313852.0 | -3.0 | 210258.0 | `RAILS/actionview/lib/action_view/buffers.rb:44` 1238.5, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 562.5, `RAILS/actionview/lib/action_view/helpers/url_helper.rb:438` 555.0 | `app/controllers/trips/notes_controller.rb:88` 290.5, `app/controllers/trips/notes_controller.rb:92` 144.0, `app/controllers/trips/notes_controller.rb:58` 131.0 |
| 8 | PlacesController#confirm | 3 / 3 | 297447.5 / 297448.0 | 0.5 | 199442.7 | `RAILS/actionview/lib/action_view/buffers.rb:44` 1152.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 523.5, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:11` 516.0 | `app/controllers/places_controller.rb:143` 369.0, `app/controllers/places_controller.rb:192` 292.0, `app/services/users/safe_settings.rb:115` 70.0 |
| 9 | Shared::CollectiblesController#image | 3 / 3 | 267135.5 / 267120.0 | -15.5 | 354709.3 | `RAILS/actionview/lib/action_view/buffers.rb:44` 1086.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 509.0, `RAILS/actionview/lib/action_view/helpers/url_helper.rb:438` 485.0 | `app/services/users/privacy_zones.rb:13` 685.5, `app/services/achievements/og_image.rb:61` 395.0, `app/controllers/shared/collectibles_controller.rb:31` 313.0 |
| 10 | Shared::CollectiblesController#show | 7 / 7 | 184752.2 / 184738.5 | -13.7 | 160605.4 | `RAILS/actionview/lib/action_view/buffers.rb:44` 725.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 561.5, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 457.5 | `app/services/users/privacy_zones.rb:13` 816.0, `app/views/layouts/shared.html.erb:15` 604.7, `app/views/layouts/achievement_embed.html.erb:11` 604.3 |
| 11 | PlacesController#merge | 8 / 8 | 180573.1 / 180555.9 | -17.3 | 229304.1 | `RAILS/actionview/lib/action_view/buffers.rb:44` 689.1, `GEM/posthog-rails/lib/posthog/rails/tracing_headers.rb:77` 380.6, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 359.3 | `app/services/places/merge.rb:51` 876.9, `app/services/users/privacy_zones.rb:13` 587.3, `app/controllers/places_controller.rb:155` 452.4 |
| 12 | TagsController#update | 5 / 5 | 167997.3 / 168204.3 | 207.0 | 151335.2 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_util.rb:93` 11616.0, `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_polynomial.rb:32` 812.0, `RAILS/actionview/lib/action_view/buffers.rb:44` 577.8 | `app/services/responsive_qr_svg.rb:29` 13410.3, `app/services/responsive_qr_svg.rb:30` 2510.5, `app/controllers/tags_controller.rb:50` 498.0 |
| 13 | Users::RegistrationsController#edit | 11 / 11 | 121130.3 / 121218.4 | 88.1 | 123731.9 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_util.rb:93` 74416.0, `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_polynomial.rb:32` 5196.8, `GEM/rqrcode/lib/rqrcode/export/svg.rb:146` 3489.6 | `app/services/responsive_qr_svg.rb:29` 85898.0, `app/services/responsive_qr_svg.rb:30` 16003.2, `app/views/layouts/application.html.erb:20` 1813.0 |
| 14 | Places::HomesController#create | 6 / 6 | 114847.6 / 114848.0 | 0.4 | 96364.3 | `RAILS/actionview/lib/action_view/buffers.rb:44` 452.6, `GEM/posthog-rails/lib/posthog/rails/tracing_headers.rb:77` 378.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 209.8 | `app/controllers/places/homes_controller.rb:11` 320.0, `app/controllers/places/homes_controller.rb:32` 291.4, `app/controllers/places/homes_controller.rb:10` 102.8 |
| 15 | AchievementsController#show | 31 / 31 | 104423.6 / 104358.8 | -64.8 | 119038.3 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_util.rb:93` 30964.7, `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_polynomial.rb:32` 2165.3, `GEM/rqrcode/lib/rqrcode/export/svg.rb:146` 1451.1 | `app/services/responsive_qr_svg.rb:29` 35747.9, `app/services/responsive_qr_svg.rb:30` 6632.1, `app/views/layouts/application.html.erb:20` 1571.3 |
| 16 | Map::MaplibreController#index | 82 / 82 | 103577.0 / 103552.6 | -24.5 | 104202.1 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_util.rb:93` 42487.6, `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_polynomial.rb:32` 2967.3, `GEM/rqrcode/lib/rqrcode/export/svg.rb:146` 1973.6 | `app/services/responsive_qr_svg.rb:29` 49043.0, `app/services/responsive_qr_svg.rb:30` 9114.6, `app/views/layouts/map.html.erb:17` 1723.5 |
| 17 | NotificationsController#open | 7 / 7 | 103380.0 / 103367.0 | -13.0 | 89382.9 | `RAILS/actionview/lib/action_view/buffers.rb:44` 391.3, `GEM/posthog-rails/lib/posthog/rails/tracing_headers.rb:77` 336.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 185.3 | `app/controllers/notifications_controller.rb:71` 216.0, `app/controllers/notifications_controller.rb:67` 198.8, `app/models/notification.rb:97` 183.0 |
| 18 | TripsController#show | 41 / 41 | 102677.3 / 102643.2 | -34.2 | 102876.3 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_util.rb:93` 45329.8, `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_polynomial.rb:32` 3166.8, `GEM/rqrcode/lib/rqrcode/export/svg.rb:146` 2115.3 | `app/services/responsive_qr_svg.rb:29` 52325.3, `app/services/responsive_qr_svg.rb:30` 9742.5, `app/views/layouts/application.html.erb:20` 1813.0 |
| 19 | AreasController#update | 8 / 8 | 95236.1 / 95241.1 | 5.0 | 87792.6 | `GEM/posthog-rails/lib/posthog/rails/tracing_headers.rb:77` 348.0, `RAILS/actionview/lib/action_view/buffers.rb:44` 341.6, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 264.0 | `app/services/places/areas_backfill.rb:33` 507.1, `app/services/places/areas_backfill.rb:129` 342.9, `app/services/places/legacy_area_adapter.rb:37` 283.1 |
| 20 | AchievementsController#index | 10 / 10 | 94275.3 / 94482.0 | 206.7 | 85363.6 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_util.rb:93` 46451.1, `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_polynomial.rb:32` 3248.0, `GEM/rqrcode/lib/rqrcode/export/svg.rb:146` 2157.4 | `app/services/responsive_qr_svg.rb:29` 53626.1, `app/services/responsive_qr_svg.rb:30` 10158.0, `app/views/layouts/application.html.erb:20` 1813.0 |
| 21 | Achievements::CollectiblesController#index | 2 / 2 | 90845.0 / 90171.0 | -674.0 | 92913.5 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_util.rb:93` 46310.0, `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_polynomial.rb:32` 3248.0, `GEM/rqrcode/lib/rqrcode/export/svg.rb:146` 2214.0 | `app/services/responsive_qr_svg.rb:29` 53487.0, `app/services/responsive_qr_svg.rb:30` 9841.0, `app/views/layouts/application.html.erb:20` 1813.0 |
| 22 | PlacesController#show | 43 / 43 | 89474.4 / 89464.0 | -10.4 | 89479.4 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_util.rb:93` 30979.6, `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_polynomial.rb:32` 2165.3, `GEM/rqrcode/lib/rqrcode/export/svg.rb:146` 1437.4 | `app/services/responsive_qr_svg.rb:29` 35763.0, `app/services/responsive_qr_svg.rb:30` 6606.8, `app/views/layouts/application.html.erb:20` 1683.5 |
| 23 | Settings::UsersController#destroy | 9 / 9 | 85319.4 / 85305.3 | -14.1 | 76284.1 | `GEM/posthog-rails/lib/posthog/rails/tracing_headers.rb:77` 354.0, `RAILS/actionview/lib/action_view/buffers.rb:44` 323.4, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 146.6 | `app/controllers/settings/users_controller.rb:57` 259.1, `app/controllers/settings/users_controller.rb:137` 258.0, `app/models/concerns/user_family.rb:35` 179.4 |
| 24 | TagsController#edit | 23 / 23 | 85307.1 / 85313.2 | 6.1 | 85170.5 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_util.rb:93` 12677.9, `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_polynomial.rb:32` 885.8, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 736.1 | `app/services/responsive_qr_svg.rb:29` 14634.7, `app/services/responsive_qr_svg.rb:30` 2720.0, `app/views/layouts/application.html.erb:20` 1565.8 |
| 25 | Settings::DataProcessingController#show | 4 / 4 | 84668.0 / 84723.3 | 55.3 | 85727.8 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_util.rb:93` 46496.3, `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_polynomial.rb:32` 3248.0, `GEM/rqrcode/lib/rqrcode/export/svg.rb:146` 2234.0 | `app/services/responsive_qr_svg.rb:29` 53671.3, `app/services/responsive_qr_svg.rb:30` 10148.0, `app/views/layouts/application.html.erb:20` 1813.0 |
| 26 | Settings::UsersController#show | 5 / 5 | 84087.5 / 84200.3 | 112.8 | 84365.0 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_util.rb:93` 46570.5, `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_polynomial.rb:32` 3248.0, `GEM/rqrcode/lib/rqrcode/export/svg.rb:146` 2199.8 | `app/services/responsive_qr_svg.rb:29` 53746.0, `app/services/responsive_qr_svg.rb:30` 10077.0, `app/views/layouts/application.html.erb:20` 1813.0 |
| 27 | ShareLinks::TimelinesController#new | 4 / 4 | 83744.3 / 83542.0 | -202.3 | 83581.5 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_util.rb:93` 46473.3, `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_polynomial.rb:32` 3248.0, `GEM/rqrcode/lib/rqrcode/export/svg.rb:146` 2137.0 | `app/services/responsive_qr_svg.rb:29` 53650.3, `app/services/responsive_qr_svg.rb:30` 9901.0, `app/views/layouts/application.html.erb:20` 1813.0 |
| 28 | Settings::TwoFactorController#verify | 2 / 2 | 83569.0 / 83687.0 | 118.0 | 117332.5 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_util.rb:93` 46470.0, `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_polynomial.rb:32` 3248.0, `GEM/rqrcode/lib/rqrcode/export/svg.rb:146` 2160.0 | `app/services/responsive_qr_svg.rb:29` 53647.0, `app/services/responsive_qr_svg.rb:30` 9982.0, `app/views/layouts/application.html.erb:20` 1813.0 |
| 29 | ShareLinks::LivesController#new | 2 / 2 | 83501.0 / 83600.0 | 99.0 | 83516.5 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_util.rb:93` 46472.0, `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_polynomial.rb:32` 3248.0, `GEM/rqrcode/lib/rqrcode/export/svg.rb:146` 2151.0 | `app/services/responsive_qr_svg.rb:29` 53649.0, `app/services/responsive_qr_svg.rb:30` 10047.0, `app/views/layouts/application.html.erb:20` 1813.0 |
| 30 | NotificationsController#show | 10 / 10 | 83456.1 / 83357.2 | -98.9 | 83355.7 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_util.rb:93` 46488.8, `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_polynomial.rb:32` 3248.0, `GEM/rqrcode/lib/rqrcode/export/svg.rb:146` 2171.4 | `app/services/responsive_qr_svg.rb:29` 53665.1, `app/services/responsive_qr_svg.rb:30` 10094.6, `app/views/layouts/application.html.erb:20` 1813.0 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_util.rb:93` | `rszf` | 7337.5 / 7336.41 | -1.08 | 7348.38 | 16% | Bignum |  | `app/services/responsive_qr_svg.rb:29` 100% | `(num >> count) & ((1 << (ARCH_BITS - count)) - 1)` |
| 2 | `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:184` | `to_wkt` | 810.21 / 810.21 | 0.0 | 810.21 | 3% | String, Array |  | `app/serializers/track_serializer.rb:20` 42%, `app/services/demo_data/tracks_seeder.rb:30` 42% | `content = wkt_content(standard_brackets).map { \|obj\| ",#{obj}" }.join` |
| 3 | `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:187` | `to_wkt` | 810.21 / 810.21 | 0.0 | 810.21 | 3% | String |  | `app/serializers/track_serializer.rb:20` 42%, `app/services/demo_data/tracks_seeder.rb:30` 42% | `",AUTHORITY#{open}#{@authority.inspect},#{@authority_code.inspect}#{cl` |
| 4 | `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:193` | `to_wkt` | 540.14 / 540.14 | 0.0 | 540.14 | 3% | String, Array |  | `app/serializers/track_serializer.rb:20` 42%, `app/services/demo_data/tracks_seeder.rb:30` 42% | `@extensions.map { \|k, v\| ",EXTENSION#{open}#{k.inspect},#{v.inspect}#{` |
| 5 | `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:197` | `to_wkt` | 540.14 / 540.14 | 0.0 | 540.14 | 3% | String |  | `app/serializers/track_serializer.rb:20` 42%, `app/services/demo_data/tracks_seeder.rb:30` 42% | `"#{wkt_typename}#{open}#{@name.inspect}#{content}#{extensions}#{author` |
| 6 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_polynomial.rb:32` | `multiply` | 512.49 / 512.49 | 0.0 | 513.29 | 16% | Struct |  | `app/services/responsive_qr_svg.rb:29` 100% | `(0...e.get_length).each do \|j\|` |
| 7 | `GEM/posthog-rails/lib/posthog/rails/tracing_headers.rb:77` | `normalize_header_name` | 349.88 / 349.88 | 0.0 | 349.98 | 100% | String |  | `no app frame` 100% | `header_name.to_s.upcase.tr('-', '_')` |
| 8 | `GEM/rqrcode/lib/rqrcode/export/svg.rb:146` | `build` | 342.11 / 341.6 | -0.51 | 342.38 | 16% | String |  | `app/services/responsive_qr_svg.rb:30` 100% | `path_str << DIR_PATH_COMMANDS[current_dir] << current_count.to_s if cu` |
| 9 | `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:240` | `brackets` | 270.07 / 270.07 | 0.0 | 270.07 | 3% | Array |  | `app/serializers/track_serializer.rb:20` 42%, `app/services/demo_data/tracks_seeder.rb:30` 42% | `standard ? %w[( )] : %w([ ])` |
| 10 | `GEM/rgeo/lib/rgeo/coord_sys/cs/entities.rb:976` | `wkt_content` | 270.07 / 270.07 | 0.0 | 270.07 | 3% | Array |  | `app/serializers/track_serializer.rb:20` 42%, `app/services/demo_data/tracks_seeder.rb:30` 42% | `[@dimension]` |
| 11 | `GEM/rqrcode/lib/rqrcode/export/svg.rb:87` | `build` | 263.03 / 263.27 | 0.24 | 263.57 | 16% | Array |  | `app/services/responsive_qr_svg.rb:30` 100% | `(edge_matrix[y][x] \|\|= []) << [x, y, DIR_UP]` |
| 12 | `GEM/rqrcode/lib/rqrcode/export/svg.rb:59` | `build` | 261.98 / 261.45 | -0.53 | 262.12 | 16% | Array |  | `app/services/responsive_qr_svg.rb:30` 100% | `(edge_matrix[y][x] \|\|= []) << [x, y, DIR_LEFT]` |
| 13 | `GEM/rqrcode/lib/rqrcode/export/svg.rb:81` | `build` | 234.14 / 234.54 | 0.4 | 234.71 | 16% | Array |  | `app/services/responsive_qr_svg.rb:30` 100% | `(edge_matrix[y][x] \|\|= []) << [x, y, DIR_DOWN]` |
| 14 | `GEM/rqrcode/lib/rqrcode/export/svg.rb:65` | `build` | 232.09 / 231.65 | -0.44 | 232.23 | 16% | Array |  | `app/services/responsive_qr_svg.rb:30` 100% | `(edge_matrix[y][x] \|\|= []) << [x, y, DIR_RIGHT]` |
| 15 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` | `tag_option` | 207.28 / 207.28 | 0.0 | 207.44 | 32% | String |  | `app/views/layouts/application.html.erb:20` 56%, `app/views/layouts/map.html.erb:17` 6% | `%(#{key}="#{value}")` |
| 16 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` | `html_safe` | 129.83 / 129.83 | 0.0 | 129.92 | 33% | String |  | `app/views/layouts/application.html.erb:20` 45%, `no app frame` 11% | `ActiveSupport::SafeBuffer.new(self)` |
| 17 | `GEM/yabeda-prometheus/lib/yabeda/prometheus/adapter.rb:93` † | `build_name` | 113.67 / 113.67 | 0.0 | 113.69 | 94% | String, Array |  | `no app frame` 12%, `app/services/instance_settings/resolver.rb:112` 5% | `[metric.group, metric.name, metric.unit].compact.join('_').to_sym` |
| 18 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` | `initialize` | 106.53 / 106.53 | 0.0 | 106.62 | 33% | String |  | `app/views/layouts/application.html.erb:20` 55%, `app/views/layouts/map.html.erb:17` 5% | `super` |
| 19 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` | `deep_dup` | 96.39 / 96.39 | 0.0 | 96.39 | 86% | String, Object |  | `app/services/users/safe_settings.rb:115` 97%, `app/services/users/plan_settings_gate.rb:53` 2% | `duplicable? ? dup : self` |
| 20 | `GEM/rqrcode/lib/rqrcode/export/svg.rb:125` | `build` | 94.51 / 94.55 | 0.04 | 94.68 | 16% | Hash, String |  | `app/services/responsive_qr_svg.rb:30` 100% | `path_str = String.new(capacity: 64)` |
| 21 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_polynomial.rb:13` | `initialize` | 92.47 / 92.46 | -0.01 | 92.61 | 16% | Array |  | `app/services/responsive_qr_svg.rb:29` 100% | `@num = Array.new(num.size - offset + shift)` |
| 22 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_polynomial.rb:15` | `initialize` | 92.47 / 92.46 | -0.01 | 92.61 | 16% | Struct |  | `app/services/responsive_qr_svg.rb:29` 100% | `(0...num.size - offset).each do \|i\|` |
| 23 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_code.rb:256` † | `make_impl` | 91.37 / 91.37 | 0.0 | 91.52 | 16% | Array |  | `app/services/responsive_qr_svg.rb:29` 100% | `@modules = @common_patterns.map(&:clone)` |
| 24 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:237` | `tag_options` | 91.06 / 91.06 | 0.0 | 91.14 | 32% | String |  | `app/views/layouts/application.html.erb:20` 63%, `app/views/layouts/map.html.erb:17` 6% | `output = +""` |
| 25 | `GEM/rgeo/lib/rgeo/wkrep/wkt_parser.rb:412` | `next_token` | 79.69 / 79.69 | 0.0 | 79.69 | 4% | String, MatchData |  | `app/services/demo_data/tracks_seeder.rb:30` 94%, `app/services/demo_data/points_seeder.rb:45` 6% | `when /^[-+]?(\d+(\.\d*)?\|\.\d+)(e[-+]?\d+)?$/` |
| 26 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` | `cast_result` | 75.04 / 75.04 | 0.0 | 75.1 | 90% | String, Array | #59278 merged 2026-10-22, after this app's version, not released yet | `app/controllers/api_controller.rb:158` 28%, `app/controllers/application_controller.rb:217` 4% | `ar_result = if result.fields.empty?` |
| 27 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_util.rb:129` | `get_error_correct_polynomial` | 70.72 / 70.72 | 0.0 | 70.83 | 16% | Array, Object |  | `app/services/responsive_qr_svg.rb:29` 100% | `a = a.multiply(QRPolynomial.new([1, QRMath.gexp(i)], 0))` |
| 28 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:297` | `self_closing_tag_string` | 69.24 / 69.24 | 0.0 | 69.32 | 23% | String |  | `app/views/layouts/application.html.erb:20` 83%, `app/views/layouts/map.html.erb:17` 8% | `"<#{name}#{tag_options(options, escape)}#{tag_suffix}".html_safe` |
| 29 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` | `get_oid_type` | 69.11 / 69.11 | 0.0 | 69.16 | 90% | Array |  | `app/controllers/api_controller.rb:158` 29%, `app/controllers/application_controller.rb:217` 4% | `type_map.fetch(oid, fmod, sql_type) {` |
| 30 | `RAILS/activemodel/lib/active_model/attribute.rb:9` | `from_database` | 66.88 / 67.05 | 0.18 | 67.01 | 88% | Object |  | `no app frame` 27%, `app/services/demo_data/destroyer.rb:21` 14% | `FromDatabase.new(name, value_before_type_cast, type, nil, value)` |

## Dev/test-mode work

8598.0 of 28568.6 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | error page | `RUBY/error_highlight/base.rb:94` | 3549.84 | 1% | `no app frame` 100% | `Prism.parse_file(absolute_path).value.breadth_first_search { \|node\| no` |
| 2 | error page | `GEM/prism/lib/prism/parse_result.rb:70` | 1425.58 | 1% | `no app frame` 100% | `source.lines` |
| 3 | asset lookup | `GEM/sprockets/lib/sprockets/path_utils.rb:234` | 184.83 | 24% | `app/helpers/achievements_helper.rb:11` 18%, `app/views/layouts/application.html.erb:12` 12% | `next unless File.basename(entry).start_with?(basename)` |
| 4 | error page | `RAILS/actionpack/lib/action_dispatch/middleware/exception_wrapper.rb:332` | 154.63 | 1% | `no app frame` 100% | `lines = source_lines.drop(start).take(6)` |
| 5 | error page | `GEM/prism/lib/prism/node.rb:2797` | 153.72 | 1% | `no app frame` 100%, `app/views/insights/_year_cards.html.erb:11` 0% | `compact = [] #: Array[Prism::node]` |
| 6 | asset lookup | `GEM/importmap-rails/app/helpers/importmap/importmap_tags_helper.rb:30` | 137.25 | 23% | `app/views/layouts/application.html.erb:20` 83%, `app/views/layouts/map.html.erb:17` 8% | `_generate_preload_tags(packages) { \|path, package\| [path, { integrity:` |
| 7 | asset lookup | `GEM/importmap-rails/app/helpers/importmap/importmap_tags_helper.rb:44` | 137.25 | 23% | `app/views/layouts/application.html.erb:20` 83%, `app/views/layouts/map.html.erb:17` 8% | `tag.link rel: "modulepreload", href: path, nonce: content_security_pol` |
| 8 | error page | `GEM/prism/lib/prism/node.rb:18058` | 105.54 | 1% | `no app frame` 100%, `app/views/insights/_year_cards.html.erb:11` 0% | `[*body]` |
| 9 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` | 98.66 | 94% | `app/services/demo_data/derivatives_seeder.rb:80` 9%, `no app frame` 9% | `binds = binds.inspect` |
| 10 | error page | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:195` | 97.05 | 1% | `no app frame` 100% | `add_filter { \|line\| line.sub(gems_regexp, gems_result) }` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| gem: rqrcode_core | 8469.1 | 8482.3 | `qr_util.rb:93` 7337.0, `qr_polynomial.rb:32` 512.5, `qr_polynomial.rb:15` 92.5 |
| gem: rgeo | 3764.5 | 3769.4 | `entities.rb:187` 810.2, `entities.rb:184` 810.2, `entities.rb:193` 540.1 |
| ruby stdlib | 3624.3 | 3710.4 | `base.rb:94` 3549.8, `ipaddr.rb:725` 10.7, `formatter.rb:174` 8.5 |
| ruby default gem: prism | 2314.2 | 2371.3 | `parse_result.rb:70` 1425.6, `node.rb:2797` 153.7, `node.rb:18058` 105.5 |
| rails: activesupport | 1781.0 | 1790.1 | `output_safety.rb:242` 129.8, `output_safety.rb:71` 106.5, `backtrace_cleaner.rb:195` 97.0 |
| rails: activerecord | 1611.1 | 1613.4 | `log_subscriber.rb:49` 98.7, `database_statements.rb:165` 75.0, `postgresql_adapter.rb:880` 69.1 |
| gem: rqrcode | 1575.6 | 1578.0 | `svg.rb:146` 341.9, `svg.rb:87` 263.2, `svg.rb:59` 261.7 |
| gem: sprockets | 1236.4 | 1427.9 | `path_utils.rb:234` 184.8, `resolve.rb:218` 88.9, `resolve.rb:292` 66.7 |
| rails: actionview | 911.4 | 916.1 | `tag_helper.rb:318` 207.3, `tag_helper.rb:237` 91.1, `tag_helper.rb:297` 69.2 |
| rails: actionpack | 796.9 | 829.3 | `exception_wrapper.rb:332` 154.6, `static.rb:145` 28.4, `visitors.rb:40` 27.8 |
| app | 679.8 | 858.2 | `borders_controller.rb:7` 138.5, `tracks_seeder.rb:70` 45.2, `rails_icons_cache.rb:22` 22.3 |
| gem: posthog-rails | 377.1 | 377.2 | `tracing_headers.rb:77` 349.9, `tracing_headers.rb:53` 9.0, `tracing_headers.rb:54` 6.0 |
| gem: importmap-rails | 347.0 | 380.1 | `importmap_tags_helper.rb:30` 137.2, `importmap_tags_helper.rb:44` 137.2, `importmap_tags_helper.rb:42` 69.1 |
| gem: i18n | 312.1 | 312.9 | `flatten.rb:34` 58.2, `flatten.rb:21` 51.0, `utils.rb:8` 49.9 |
| test harness: rspec-mocks | 180.6 | 180.7 | `message_expectation.rb:629` 17.3, `argument_list_matcher.rb:97` 17.1, `message_expectation.rb:809` 17.1 |
| rails: activemodel | 173.7 | 174.8 | `attribute.rb:9` 67.0, `attribute.rb:13` 13.0, `string.rb:39` 11.9 |
| gem: prometheus-client | 144.8 | 202.1 | `label_set_validator.rb:52` 62.0, `metric.rb:113` 20.7, `metric.rb:109` 20.7 |
| gem: yabeda | 134.5 | 134.5 | `group.rb:14` 20.7, `metric.rb:62` 20.7, `metric.rb:64` 20.7 |
| gem: yabeda-prometheus | 113.7 | 113.7 | `adapter.rb:93` 113.7, `exporter.rb:58` 0.0, `exporter.rb:18` 0.0 |
| ruby default gem: uri | 106.6 | 117.9 | `rfc2396_parser.rb:291` 60.1, `rfc2396_parser.rb:320` 11.5, `common.rb:465` 9.5 |
| gem: tzinfo | 106.3 | 125.9 | `timestamp.rb:208` 39.8, `timestamp.rb:193` 27.3, `constant_offset_data_timezone_info.rb:52` 14.1 |
| gem: rack | 90.0 | 90.1 | `utils.rb:693` 19.5, `request.rb:607` 11.7, `request.rb:696` 8.4 |
| gem: logger | 82.5 | 82.6 | `log_device.rb:33` 24.0, `log_device.rb:165` 20.8, `logger.rb:692` 20.5 |
| gem: concurrent-ruby | 68.0 | 70.0 | `atom.rb:183` 20.6, `copy_on_notify_observer_set.rb:64` 10.3, `copy_on_notify_observer_set.rb:95` 10.3 |
| gem: warden | 45.2 | 45.3 | `proxy.rb:334` 6.8, `proxy.rb:348` 5.9, `proxy.rb:349` 3.0 |
| gem: rgeo-geojson | 45.1 | 45.1 | `entities.rb:16` 45.0, `coder.rb:120` 0.0, `interface.rb:16` 0.0 |
| test harness: rspec-support | 44.3 | 44.4 | `fuzzy_matcher.rb:35` 4.6, `method_signature_verifier.rb:135` 4.5, `method_signature_verifier.rb:19` 4.3 |
| gem: sprockets-rails | 34.6 | 36.6 | `helper.rb:81` 10.4, `helper.rb:357` 10.4, `helper.rb:356` 5.2 |
| gem: nokogiri | 34.2 | 34.4 | `document.rb:416` 3.4, `node.rb:66` 3.2, `node.rb:1431` 2.4 |
| gem: yabeda-activerecord | 30.8 | 30.8 | `active_record.rb:72` 10.3, `active_record.rb:65` 10.3, `active_record.rb:58` 10.3 |
| gem: devise | 26.6 | 26.8 | `helpers.rb:128` 4.8, `authenticatable.rb:173` 4.6, `authenticatable.rb:174` 3.4 |
| gem: erubi | 22.8 | 23.7 | `erubi.rb:134` 13.0, `erubi.rb:137` 3.0, `erubi.rb:139` 1.8 |
| gem: flipper | 19.1 | 19.1 | `memoizable.rb:97` 3.0, `wrapper.rb:32` 3.0, `memoizable.rb:93` 2.0 |
| gem: json_schemer | 14.2 | 21.7 | `output.rb:16` 5.3, `schema.rb:135` 1.8, `schema.rb:143` 1.8 |
| gem: icons | 13.3 | 13.5 | `file_path.rb:52` 11.5, `configurable.rb:43` 0.4, `icon.rb:33` 0.3 |
| gem: activerecord-postgis-adapter | 13.2 | 13.2 | `spatial.rb:113` 6.4, `spatial.rb:120` 2.7, `spatial.rb:83` 2.7 |
| gem: fakeredis | 12.2 | 12.2 | `memory.rb:914` 2.4, `command_executor.rb:4` 2.0, `command_executor.rb:5` 1.2 |
| gem: globalid | 9.1 | 9.1 | `gid.rb:95` 2.4, `gid.rb:159` 1.9, `gid.rb:166` 1.0 |
| rails: railties | 9.0 | 9.0 | `logger.rb:57` 2.0, `engine.rb:748` 1.0, `logger.rb:21` 1.0 |
| gem: turbo-rails | 7.2 | 7.3 | `request_id_tracking.rb:10` 1.0, `stream_name.rb:26` 0.8, `frames_helper.rb:45` 0.8 |
| gem: connection_pool | 7.1 | 7.1 | `connection_pool.rb:64` 2.0, `connection_pool.rb:67` 2.0, `connection_pool.rb:65` 1.0 |
| gem: posthog-ruby | 6.4 | 6.5 | `context.rb:61` 1.0, `context.rb:78` 1.0, `context.rb:54` 1.0 |
| gem: loofah | 5.7 | 5.7 | `concerns.rb:172` 2.0, `concerns.rb:43` 1.4, `scrubber.rb:132` 1.1 |
| gem: rotp | 4.5 | 4.6 | `base32.rb:18` 1.1, `base32.rb:23` 0.8, `base32.rb:19` 0.7 |
| gem: mcp | 4.5 | 6.0 | `schema.rb:122` 2.9, `streamable_http_transport.rb:1476` 0.1, `json_rpc_handler.rb:58` 0.1 |
| rails: actioncable | 4.5 | 4.5 | `broadcasting.rb:53` 2.5, `broadcasting.rb:25` 0.5, `broadcasting.rb:32` 0.4 |
| gem: base64 | 3.8 | 3.8 | `base64.rb:283` 3.0, `base64.rb:310` 0.7, `base64.rb:374` 0.0 |
| gem: debug | 3.8 | 4.0 | `thread_client.rb:903` 1.1, `thread_client.rb:234` 0.5, `session.rb:140` 0.5 |
| gem: jwt | 3.7 | 3.7 | `json.rb:10` 0.4, `json.rb:14` 0.2, `decode_verifier.rb:33` 0.2 |
| rails: activestorage | 3.5 | 3.6 | `model.rb:133` 0.4, `filename.rb:61` 0.3, `model.rb:144` 0.2 |
| rails: activejob | 3.4 | 3.4 | `log_subscriber.rb:207` 0.5, `log_subscriber.rb:201` 0.2, `queue_adapter.rb:11` 0.2 |
| gem: rails-html-sanitizer | 3.4 | 3.4 | `sanitizer.rb:165` 0.5, `sanitizer.rb:33` 0.5, `scrubbers.rb:59` 0.5 |
| gem: rgeo-activerecord | 3.3 | 3.3 | `spatial_factory_store.rb:47` 1.8, `spatial_factory_store.rb:39` 1.5, `common_adapter_elements.rb:10` 0.0 |
| gem: addressable | 3.2 | 3.4 | `uri.rb:438` 0.2, `uri.rb:486` 0.2, `uri.rb:424` 0.2 |
| gem: rack-session | 3.0 | 3.0 | `id.rb:275` 1.0, `id.rb:277` 1.0, `id.rb:401` 0.5 |
| gem: rack-cors | 2.5 | 2.5 | `cors.rb:129` 1.0, `result.rb:38` 1.0, `cors.rb:123` 0.3 |
| ruby default gem: securerandom | 2.5 | 2.5 | `securerandom.rb:71` 2.5 |
| gem: redis | 2.3 | 2.4 | `client.rb:161` 0.9, `strings.rb:84` 0.4, `strings.rb:191` 0.4 |
| gem: bootsnap | 2.1 | 14.4 | `kernel_require.rb:11` 1.9, `cache.rb:218` 0.1, `cache.rb:205` 0.0 |
| test harness: webmock | 2.1 | 2.2 | `headers.rb:69` 0.3, `headers.rb:68` 0.3, `headers.rb:16` 0.1 |
| gem: request_store | 2.0 | 2.0 | `middleware.rb:21` 1.0, `middleware.rb:28` 1.0 |
| gem: bcrypt | 2.0 | 2.0 | `password.rb:102` 0.6, `password.rb:103` 0.3, `engine.rb:70` 0.3 |
| gem: rack-attack | 1.8 | 1.9 | `cache.rb:73` 0.5, `attack.rb:93` 0.4, `cache.rb:80` 0.2 |
| gem: kaminari-core | 1.8 | 1.8 | `page_scope_methods.rb:10` 0.2, `tags.rb:69` 0.2, `tags.rb:33` 0.1 |
| gem: zeitwerk | 1.1 | 1.1 | `cref.rb:47` 0.2, `constant_path_validator.rb:13` 0.2, `file_system.rb:203` 0.2 |
| gem: bigdecimal | 1.1 | 1.1 | `util.rb:51` 0.9, `util.rb:24` 0.1, `util.rb:73` 0.0 |
| gem: redis-client | 1.0 | 1.1 | `resp3.rb:99` 0.3, `resp3.rb:54` 0.2, `resp3.rb:69` 0.1 |
| rails: actiontext | 1.0 | 1.1 | `fragment.rb:38` 0.1, `html_conversion.rb:23` 0.1, `attachment_gallery.rb:44` 0.1 |
| ruby default gem: erb | 0.9 | 1.1 | `compiler.rb:307` 0.2, `compiler.rb:243` 0.1, `compiler.rb:242` 0.1 |
| gem: geocoder | 0.7 | 0.9 | `calculations.rb:301` 0.2, `base.rb:352` 0.1, `calculations.rb:405` 0.1 |
| gem: mail | 0.7 | 1.4 | `utilities.rb:215` 0.1, `address_lists_parser.rb:32009` 0.0, `utilities.rb:291` 0.0 |
| gem: pg | 0.6 | 0.6 | `date.rb:14` 0.4, `date.rb:13` 0.2, `result.rb:17` 0.0 |
| gem: pundit | 0.5 | 0.5 | `authorization.rb:38` 0.1, `authorization.rb:36` 0.1, `authorization.rb:137` 0.1 |
| gem: marcel | 0.5 | 0.5 | `magic.rb:18` 0.1, `mime_type.rb:90` 0.1, `mime_type.rb:81` 0.1 |
| ruby default gem: prettyprint | 0.4 | 0.4 | `prettyprint.rb:403` 0.1, `prettyprint.rb:263` 0.1, `prettyprint.rb:458` 0.1 |
| gem: with_advisory_lock | 0.4 | 0.4 | `postgresql_advisory.rb:172` 0.1, `core_advisory.rb:26` 0.0, `core_advisory.rb:97` 0.0 |
| gem: responders | 0.3 | 0.4 | `respond_with.rb:248` 0.1, `respond_with.rb:214` 0.0, `responder.rb:166` 0.0 |
| ruby default gem: net-http | 0.3 | 0.3 | `header.rb:205` 0.0, `http.rb:1161` 0.0, `header.rb:468` 0.0 |
| gem: hashie | 0.2 | 0.3 | `mash.rb:374` 0.2, `mash.rb:369` 0.0 |
| gem: rubyzip | 0.2 | 0.3 | `extra_field.rb:16` 0.0, `generic.rb:24` 0.0, `central_directory.rb:260` 0.0 |
| ruby default gem: pp | 0.2 | 0.2 | `pp.rb:542` 0.1, `pp.rb:271` 0.0, `pp.rb:550` 0.0 |
| gem: orm_adapter | 0.1 | 0.1 | `active_record.rb:17` 0.1, `base.rb:100` 0.0, `base.rb:105` 0.0 |
| gem: kaminari-activerecord | 0.1 | 0.1 | `active_record_model_extension.rb:17` 0.1, `active_record_relation_methods.rb:29` 0.0, `active_record_relation_methods.rb:31` 0.0 |
| gem: chartkick | 0.1 | 0.1 | `helper.rb:91` 0.0, `helper.rb:103` 0.0, `helper.rb:12` 0.0 |
| gem: sidekiq | 0.1 | 0.1 | `redis_client_adapter.rb:35` 0.1, `job.rb:120` 0.0, `job.rb:74` 0.0 |
| gem: rails_icons | 0.1 | 0.1 | `icon_helper.rb:21` 0.1, `routes.rb:7` 0.0, `routes.rb:4` 0.0 |
| gem: devise-two-factor | 0.1 | 0.1 | `two_factor_authenticatable.rb:47` 0.0, `two_factor_authenticatable.rb:36` 0.0, `two_factor_authenticatable.rb:54` 0.0 |
| gem: h3 | 0.0 | 0.1 | `indexing.rb:76` 0.0, `indexing.rb:77` 0.0, `indexing.rb:74` 0.0 |
| rails: actionmailer | 0.0 | 0.0 | `base.rb:636` 0.0, `parameterized.rb:149` 0.0, `message_delivery.rb:104` 0.0 |
| ruby default gem: timeout | 0.0 | 0.0 | `timeout.rb:292` 0.0, `timeout.rb:152` 0.0, `timeout.rb:293` 0.0 |
| gem: tzf2 | 0.0 | 0.0 | `tzf2.rb:38` 0.0, `tzf2.rb:34` 0.0 |
| gem: hana | 0.0 | 0.1 | `hana.rb:47` 0.0, `hana.rb:51` 0.0, `hana.rb:3` 0.0 |
| other | 0.0 | 0.0 | `(erb):1` 0.0, `(erb):58` 0.0, `(erb):54` 0.0 |
| gem: racc | 0.0 | 0.0 | `parser.rb:263` 0.0 |
| gem: flipper-ui | 0.0 | 0.0 | `ui.rb:49` 0.0, `middleware.rb:17` 0.0, `ui.rb:44` 0.0 |
| gem: lowrail-profile | 0.0 | 0.0 | `profile.rb:95` 0.0, `profile.rb:83` 0.0, `profile.rb:55` 0.0 |
| gem: sentry-rails | 0.0 | 0.0 | `active_job.rb:32` 0.0 |
| gem: rack-protection | 0.0 | 0.0 | `base.rb:37` 0.0, `base.rb:24` 0.0, `base.rb:35` 0.0 |
| gem: ffi | 0.0 | 0.1 | `function.rb:84` 0.0, `dynamic_library.rb:101` 0.0, `library.rb:233` 0.0 |
| gem: simpleidn | 0.0 | 0.8 | `uts46mapping.rb:1322` 0.0, `uts46mapping.rb:2279` 0.0, `uts46mapping.rb:1876` 0.0 |
| gem: regexp_parser | 0.0 | 0.1 | `scanner.rb:153` 0.0, `scanner.rb:942` 0.0, `scanner.rb:1011` 0.0 |
| gem: kaminari-actionview | 0.0 | 0.0 | `action_view_extension.rb:0` 0.0, `action_view_extension.rb:12` 0.0, `action_view_extension.rb:10` 0.0 |
| rails: actionmailbox | 0.0 | 0.0 | `routes.rb:4` 0.0, `routes.rb:21` 0.0, `routes.rb:10` 0.0 |
| gem: msgpack | 0.0 | 0.0 | `factory.rb:16` 0.0, `factory.rb:29` 0.0, `factory.rb:37` 0.0 |
| gem: json | 0.0 | 0.0 | `state.rb:65` 0.0, `state.rb:33` 0.0, `state.rb:43` 0.0 |
| test harness: rspec-expectations | 0.0 | 0.0 | `expectation_target.rb:45` 0.0, `matchers.rb:559` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Jobs

| # | Job | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | Users::Digests::Yearly::CalculatingJob#perform | 1 / 1 | – / – |  | 33531.0 |  |  |
| 2 | EnhancedImport::DestroyJob#perform | 1 / 1 | – / – |  | 8895.0 |  |  |
| 3 | Import::ProcessJob#perform | 1 / 1 | – / – |  | 7505.0 |  |  |
| 4 | ActionMailer::MailDeliveryJob#perform | 1 / 1 | – / – |  | 3401.0 |  |  |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/yabeda-prometheus/lib/yabeda/prometheus/adapter.rb:93` † | 467.5 / 467.5 | 100% | `app/services/stats/calculate_month.rb:131` 14%, `app/services/enhanced_import/destroy.rb:50` 11% | `[metric.group, metric.name, metric.unit].compact.join('_').to_sym` |
| 2 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` | 370.75 / 370.75 | 100% | `app/services/stats/calculate_month.rb:10` 35%, `app/services/stats/calculate_month.rb:131` 12% | `ar_result = if result.fields.empty?` |
| 3 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` | 342.0 / 342.0 | 100% | `app/services/stats/calculate_month.rb:10` 37%, `app/services/stats/calculate_month.rb:131` 12% | `type_map.fetch(oid, fmod, sql_type) {` |
| 4 | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` (debug logging) | 341.0 / 341.0 | 100% | `app/services/stats/calculate_month.rb:135` 13%, `app/services/stats/calculate_month.rb:17` 13% | `binds = binds.inspect` |
| 5 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` | 309.5 / 309.5 | 100% | `app/services/users/safe_settings.rb:115` 99%, `app/services/notifications.rb:43` 0% | `duplicable? ? dup : self` |
| 6 | `GEM/prometheus-client/lib/prometheus/client/label_set_validator.rb:52` | 255.0 / 255.0 | 100% | `app/services/stats/calculate_month.rb:131` 14%, `app/services/enhanced_import/destroy.rb:50` 11% | `labelset.keys.sort == expected_labels` |
| 7 | `RAILS/activesupport/lib/active_support/log_subscriber.rb:177` (debug logging) | 253.5 / 253.5 | 100% | `app/services/stats/calculate_month.rb:131` 14%, `app/services/enhanced_import/destroy.rb:50` 11% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 8 | `RAILS/activesupport/lib/active_support/log_subscriber.rb:175` (debug logging) | 169.0 / 169.0 | 100% | `app/services/stats/calculate_month.rb:131` 14%, `app/services/enhanced_import/destroy.rb:50` 11% | `modes = MODES.values_at(*options.compact_blank.keys)` |
| 9 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` | 149.5 / 149.5 | 100% | `app/services/stats/calculate_month.rb:10` 26%, `app/services/enhanced_import/destroy.rb:50` 6% | `ActiveRecord::Result.new(fields, result.values, types.freeze, affected` |
| 10 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` | 130.75 / 130.75 | 100% | `app/services/stats/calculate_month.rb:131` 13%, `app/services/enhanced_import/destroy.rb:50` 11% | `group_klass.new(grouped_listeners, name, id, payload)` |
