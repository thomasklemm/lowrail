# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails test -v`
* Ruby: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +YJIT +PRISM [x86_64-linux]
* Rails: 8.1.4.1, test environment
* Counted in run 1: 4230 requests, 42 jobs, 15 mail windows in 8 processes; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 8 | 4230 | 9377.3 | 42 | 15 | 0 | 0 |
| run2 | 8 | 4230 | 9383.0 | 42 | 15 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.01, max |Δ| 0.52 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/models/user.rb:385` | `role?` | 92.53 | 0.0 | 1.08 | `GEM/prosopite/lib/prosopite.rb:419` 47%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 3%, `RAILS/activerecord/lib/active_record/relation.rb:77` 2% | SiteController#index 32%, SessionsController#create 6%, Api::Changesets::UploadsController#create 5% | `roles.any? { \|r\| r.role == role }` |
| 2 | `app/models/user.rb:288` | `preferred_color_scheme` | 86.31 | 0.0 | 2.38 | `GEM/prosopite/lib/prosopite.rb:419` 29%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 4%, `RAILS/activerecord/lib/arel/visitors/postgresql.rb:136` 2% | SiteController#index 69%, ChangesetsController#index 3%, UserBlocksController#show 3% | `color_preferences = preferences.color_schemes.where.not(:v => "auto").` |
| 3 | `app/helpers/user_helper.rb:40` | `user_image_tag` | 82.52 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 47%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 3%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 2% | SiteController#index 57%, DiaryEntriesController#index 10%, Users::ListsController#show 10% | `elsif user.avatar.attached?` |
| 4 | `app/views/layouts/_search.html.erb:18` |  | 80.59 | 67.73 | 0.28 | `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:54` 6%, `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:13` 5%, `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:12` 5% | SiteController#index 72%, SearchesController#show 18%, ChangesetsController#index 4% | `<%= inline_svg_tag "magnifying_glass.svg" %>` |
| 5 | `app/views/layouts/_search.html.erb:22` |  | 75.24 | 67.68 | 0.85 | `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:54` 7%, `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:4` 3%, `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:5` 3% | SiteController#index 72%, SearchesController#show 18%, ChangesetsController#index 4% | `<%= inline_svg_tag "directions.svg", :class => "align-bottom" %>` |
| 6 | `app/controllers/application_controller.rb:48` | `authorize_web` | 73.16 | 0.0 | 0.71 | `GEM/prosopite/lib/prosopite.rb:419` 32%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 11%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 7% | SiteController#index 53%, SessionsController#create 10%, ChangesetsController#index 3% | `self.current_user = User.find_by(:id => session[:user], :status => %w[` |
| 7 | `app/controllers/api_controller.rb:100` | `setup_user_auth` | 63.73 | 0.0 | 0.13 | `GEM/prosopite/lib/prosopite.rb:419` 55%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 8%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 7% | Api::Changesets::UploadsController#create 14%, Api::ChangesetCommentsController#create 9%, Api::NodesController#update 8% | `self.current_user = User.find(doorkeeper_token.resource_owner_id) if d` |
| 8 | `app/views/application/_auth_button.html.erb:7` |  | 61.24 | 22.54 | 0.3 | `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:54` 4%, `GEM/nokogiri/lib/nokogiri/xml/document.rb:85` 4%, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1431` 4% | SessionsController#new 93%, UsersController#create 6%, UsersController#new 2% | `<%= inline_svg_tag "auth_providers/#{provider}.svg",` |
| 9 | `app/views/layouts/_header.html.erb:53` |  | 61.06 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 48%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 3%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 2% | SiteController#index 72%, ChangesetsController#index 4%, UserBlocksController#show 3% | `<% if current_user.new_messages.size > 0 %>` |
| 10 | `app/views/layouts/_header.html.erb:38` |  | 51.24 | 0.0 | 18.22 | `RAILS/actionview/lib/action_view/helpers/output_safety_helper.rb:36` 13%, `GEM/uri/lib/uri/rfc2396_parser.rb:320` 12%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:590` 10% | SiteController#index 40%, SearchesController#show 10%, SessionsController#new 9% | `<%= link_to label, path, :class => ["nav-link", "px-1", "py-2", "py-md` |
| 11 | `app/controllers/api_controller.rb:106` | `setup_user_auth` | 43.84 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 47%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 3%, `RAILS/activerecord/lib/arel/visitors/to_sql.rb:790` 3% | Api::Changesets::UploadsController#create 13%, Api::ChangesetCommentsController#create 8%, Api::NodesController#update 7% | `user_block = current_user.blocks.active.take` |
| 12 | `app/models/user.rb:173` | `lookup` | 42.77 | 0.0 | 0.12 | `GEM/prosopite/lib/prosopite.rb:419` 41%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 9%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 9% | SessionsController#create 100% | `user = find_by("email = ? OR display_name = ?", username, username)` |
| 13 | `app/models/old_node.rb:72` | `save_with_dependencies!` | 42.3 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 48%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 4%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 2% | Api::Changesets::UploadsController#create 71%, Api::NodesController#create 15%, Api::NodesController#update 13% | `save!` |
| 14 | `app/controllers/api_controller.rb:146` | `api_call_timeout` | 40.87 | 1.38 | 0.0 | `GEM/cancancan/lib/cancan/ability.rb:80` 6%, `RAILS/actionview/lib/action_view/template_path.rb:23` 4%, `GEM/cancancan/lib/cancan/ability.rb:77` 4% | Api::ChangesetsController#index 9%, Api::Messages::InboxesController#show 6%, Api::UserPreferencesController#index 4% | `Timeout.timeout(Settings.api_timeout, &)` |
| 15 | `app/controllers/concerns/pagination_methods.rb:27` | `get_page_items` | 39.74 | 0.0 | 0.08 | `GEM/prosopite/lib/prosopite.rb:419` 23%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 13%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 5% | ChangesetsController#index 26%, TracesController#index 25%, DiaryEntriesController#index 14% | `page_items = page_items.sort_by(&cursor_column).reverse` |
| 16 | `app/views/layouts/_meta.html.erb:6` |  | 38.17 | 4.91 | 21.47 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 25%, `RAILS/activesupport/lib/active_support/core_ext/hash/keys.rb:28` 6%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 6% | SiteController#index 38%, SearchesController#show 9%, SessionsController#new 9% | `<%= favicon_link_tag "apple-touch-icon-#{size}x#{size}.png", :rel => "` |
| 17 | `app/models/user.rb:392` | `blocked_on_view` | 36.68 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 48%, `RAILS/activerecord/lib/arel/visitors/to_sql.rb:790` 3%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 3% | SessionsController#create 96%, UsersController#auth_success 3%, UsersController#create 1% | `blocks.active.detect(&:needs_view?)` |
| 18 | `app/models/node.rb:249` | `save_with_history!` | 30.91 | 0.0 | 0.03 | `GEM/prosopite/lib/prosopite.rb:419` 44%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 6%, `RAILS/activesupport/lib/active_support/callbacks.rb:362` 3% | Api::Changesets::UploadsController#create 70%, Api::NodesController#create 15%, Api::NodesController#update 13% | `clone.save!` |
| 19 | `config/initializers/inline_svg.rb:14` | `transform` | 29.94 | 0.0 | 0.0 | `GEM/nokogiri/lib/nokogiri/xml/node.rb:1431` 10%, `GEM/nokogiri/lib/nokogiri/xml/document.rb:85` 10%, `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations/transformation.rb:23` 7% | SiteController#index 55%, SessionsController#new 19%, SearchesController#show 14% | `with_svg(doc) do \|svg\|` |
| 20 | `app/views/layouts/_header.html.erb:27` |  | 22.82 | 0.0 | 2.48 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 17%, `GEM/i18n/lib/i18n/interpolate/ruby.rb:33` 13%, `GEM/i18n/lib/i18n/backend/fallbacks.rb:60` 9% | SiteController#index 41%, SearchesController#show 10%, SessionsController#new 9% | `<%= link_to t(".edit_with", :editor => t("editor.#{editor}.description` |
| 21 | `app/views/layouts/_search.html.erb:43` |  | 21.42 | 0.0 | 0.85 | `RAILS/actionview/lib/action_view/helpers/form_options_helper.rb:797` 11%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 8%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 7% | SiteController#index 72%, SearchesController#show 18%, ChangesetsController#index 4% | `grouped_options_for_select({ t("site.search.providers.description") =>` |
| 22 | `app/models/node.rb:271` | `save_with_history!` | 18.67 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 34%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 6%, `RAILS/activesupport/lib/active_support/callbacks.rb:362` 3% | Api::Changesets::UploadsController#create 71%, Api::NodesController#create 15%, Api::NodesController#update 13% | `changeset.save!` |
| 23 | `lib/rich_text.rb:111` | `sanitize` | 17.2 | 0.0 | 0.0 | `GEM/sanitize/lib/sanitize.rb:203` 23%, `GEM/sanitize/lib/sanitize/transformers/clean_element.rb:84` 10%, `GEM/sanitize/lib/sanitize.rb:206` 10% | DiaryEntriesController#index 44%, Users::ListsController#show 16%, UserBlocksController#show 7% | `Sanitize.clean(text, Sanitize::Config::OSM).html_safe` |
| 24 | `app/models/node.rb:259` | `save_with_history!` | 17.13 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 55%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 3%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 1% | Api::NodesController#update 56%, Api::Changesets::UploadsController#create 37%, Api::NodesController#create 7% | `tag.save!` |
| 25 | `app/models/user.rb:62` |  | 16.51 | 0.0 | 1.28 | `RAILS/activerecord/lib/active_record/relation/query_methods.rb:2117` 10%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:166` 8%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` 8% | SiteController#index 62%, UserBlocksController#show 3%, ChangesetsController#index 3% | `has_many :new_messages, -> { where(:to_user_visible => true, :muted =>` |
| 26 | `app/models/old_node.rb:80` | `save_with_dependencies!` | 15.9 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 48%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 5%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 1% | Api::NodesController#update 58%, Api::Changesets::UploadsController#create 39%, Api::NodesController#create 3% | `tag.save!` |
| 27 | `app/models/old_relation.rb:73` | `save_with_dependencies!` | 15.43 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 51%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 2%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 2% | Api::Changesets::UploadsController#create 47%, Api::RelationsController#create 41%, Api::RelationsController#update 12% | `member.save!` |
| 28 | `app/views/layouts/_search.html.erb:32` |  | 15.22 | 0.0 | 4.23 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 33%, `RAILS/actionview/lib/action_view/helpers/form_tag_helper.rb:1065` 22%, `RAILS/actionview/lib/action_view/helpers/form_tag_helper.rb:502` 11% | SiteController#index 72%, SearchesController#show 18%, ChangesetsController#index 4% | `<%= radio_button_tag "modes", mode, false, { :class => "btn-check", :a` |
| 29 | `app/views/api/changesets/index.xml.builder:5` |  | 15.1 | 0.07 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 29%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 3%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 2% | Api::ChangesetsController#index 100% | `osm << (render(@changesets) \|\| "")` |
| 30 | `app/views/diary_entries/_diary_entry.html.erb:28` |  | 14.98 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 32%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 3%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 2% | DiaryEntriesController#index 100% | `<% if diary_entry.visible_comments.count > 0 %>` |

App middleware that hands the request on (the stack below it, not its own work): `config/initializers/policy_headers.rb:13` 252.05, `config/initializers/compressed_requests.rb:37` 114.81 warm objects per request.

456.4 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | UserMutesController#destroy | 2 / 2 | 275921.0 / 275940.0 | 19.0 | 140175.0 | `RAILS/actionview/lib/action_view/buffers.rb:44` 1465.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 672.0, `RAILS/actionview/lib/action_view/helpers/url_helper.rb:438` 657.0 | `config/initializers/policy_headers.rb:13` 504.0, `app/controllers/user_mutes_controller.rb:37` 417.0, `app/controllers/application_controller.rb:48` 389.0 |
| 2 | LayersPanesController#show | 2 / 2 | 262367.0 / – |  | 133038.0 |  |  |
| 3 | RelationMembersController#show | 4 / 4 | 280594.0 / 9417.0 | -271177.0 | 76118.8 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 384.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 358.0, `GEM/pg/lib/pg/connection.rb:350` 269.0 | `app/views/layouts/_search.html.erb:18` 572.0, `app/views/layouts/_search.html.erb:22` 534.0, `app/controllers/application_controller.rb:236` 294.0 |
| 4 | Issues::ReportersController#index | 12 / 12 | 143034.5 / 143029.0 | -5.5 | 96608.7 | `RAILS/actionview/lib/action_view/buffers.rb:44` 739.3, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 382.0, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:11` 334.5 | `config/initializers/policy_headers.rb:13` 458.5, `app/controllers/issues/reporters_controller.rb:14` 237.0, `app/controllers/application_controller.rb:48` 175.5 |
| 5 | IssuesController#show | 9 / 9 | 113876.7 / 113888.3 | 11.7 | 79900.2 | `RAILS/actionview/lib/action_view/buffers.rb:44` 507.3, `GEM/prosopite/lib/prosopite.rb:419` 344.7, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 303.0 | `app/controllers/issues_controller.rb:68` 599.3, `config/initializers/policy_headers.rb:13` 402.7, `app/controllers/issues_controller.rb:105` 218.0 |
| 6 | IssuesController#ignore | 8 / 8 | 110131.8 / 110136.7 | 4.8 | 84283.9 | `RAILS/actionview/lib/action_view/buffers.rb:44` 507.3, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 247.3, `GEM/prosopite/lib/prosopite.rb:419` 229.7 | `config/initializers/policy_headers.rb:13` 336.3, `app/controllers/issues_controller.rb:85` 267.2, `app/controllers/issues_controller.rb:105` 216.7 |
| 7 | IssuesController#reopen | 8 / 8 | 110044.5 / 109998.0 | -46.5 | 83726.9 | `RAILS/actionview/lib/action_view/buffers.rb:44` 507.3, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 247.3, `GEM/prosopite/lib/prosopite.rb:419` 229.7 | `config/initializers/policy_headers.rb:13` 336.3, `app/controllers/issues_controller.rb:105` 216.3, `app/controllers/issues_controller.rb:95` 189.5 |
| 8 | IssuesController#resolve | 9 / 9 | 94533.9 / 94573.4 | 39.6 | 75201.6 | `RAILS/actionview/lib/action_view/buffers.rb:44` 434.9, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 212.0, `GEM/prosopite/lib/prosopite.rb:419` 196.9 | `config/initializers/policy_headers.rb:13` 341.6, `app/controllers/issues_controller.rb:75` 198.6, `app/controllers/issues_controller.rb:105` 185.1 |
| 9 | OldRelationMembersController#show | 6 / 6 | 1140.0 / 145356.0 | 144216.0 | 51863.3 | `RAILS/actionview/lib/action_view/buffers.rb:44` 754.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 446.5, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:11` 340.5 | `config/initializers/policy_headers.rb:13` 419.5, `app/controllers/old_relation_members_controller.rb:7` 390.0, `app/views/layouts/_search.html.erb:18` 286.0 |
| 10 | DiaryEntriesController#index | 30 / 30 | 24152.6 / 22462.2 | -1690.4 | 23073.4 | `GEM/prosopite/lib/prosopite.rb:419` 1781.6, `GEM/cancancan/lib/cancan/ability.rb:145` 624.3, `GEM/cancancan/lib/cancan/ability/rules.rb:28` 450.5 | `app/views/diary_entries/_diary_entry.html.erb:28` 2639.5, `app/helpers/user_helper.rb:40` 1420.0, `lib/rich_text.rb:111` 1338.2 |
| 11 | ChangesetsController#show | 34 / 34 | 18506.7 / 18910.4 | 403.7 | 25389.7 | `GEM/prosopite/lib/prosopite.rb:419` 620.4, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 203.3, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 179.4 | `app/views/changesets/_elements.html.erb:6` 396.3, `app/views/changesets/_elements.html.erb:10` 354.1, `app/views/changesets/_elements.html.erb:9` 321.6 |
| 12 | SiteController#edit | 29 / 29 | 18676.4 / 18127.0 | -549.5 | 15184.4 | `GEM/prosopite/lib/prosopite.rb:419` 208.7, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 169.4, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 149.2 | `config/initializers/policy_headers.rb:13` 326.0, `app/models/user.rb:288` 319.9, `app/helpers/user_helper.rb:40` 188.3 |
| 13 | (no action name) | 146 / 146 | 17069.1 / 17073.2 | 4.1 | 18628.3 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 259.4, `GEM/nokogiri/lib/nokogiri/xml/document.rb:416` 257.7, `GEM/nokogiri/lib/nokogiri/html5/node.rb:66` 257.7 | `config/initializers/compressed_requests.rb:37` 295.1, `config/initializers/policy_headers.rb:13` 38.1, `config/initializers/content_security_policy.rb:42` 2.0 |
| 14 | DiaryCommentsController#create | 5 / 5 | 15270.7 / 17029.3 | 1758.7 | 16586.8 | `GEM/prosopite/lib/prosopite.rb:419` 1773.7, `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` 532.0, `GEM/mail/lib/mail/utilities.rb:215` 438.0 | `app/controllers/diary_comments_controller.rb:24` 2045.3, `app/mailers/user_mailer.rb:146` 939.7, `app/controllers/diary_comments_controller.rb:21` 621.3 |
| 15 | Api::Changesets::UploadsController#create | 80 / 80 | 15772.8 / 15782.3 | 9.4 | 15288.0 | `GEM/prosopite/lib/prosopite.rb:419` 6101.5, `GEM/prosopite/lib/prosopite.rb:250` 1158.1, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 303.5 | `app/models/old_node.rb:72` 1756.1, `config/initializers/policy_headers.rb:13` 1396.1, `app/models/node.rb:249` 1269.8 |
| 16 | Traces::LegacyVisibilitiesController#edit | 8 / 8 | 14180.0 / 14055.3 | -124.7 | 10558.4 | `GEM/prosopite/lib/prosopite.rb:419` 721.7, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 467.3, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 424.3 | `app/controllers/concerns/pagination_methods.rb:27` 949.0, `app/helpers/application_helper.rb:21` 590.3, `config/initializers/policy_headers.rb:13` 419.7 |
| 17 | Api::RelationsController#update | 14 / 14 | 13856.9 / 14185.4 | 328.6 | 14299.1 | `GEM/prosopite/lib/prosopite.rb:419` 5821.1, `GEM/prosopite/lib/prosopite.rb:250` 1205.1, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 213.9 | `config/initializers/policy_headers.rb:13` 1451.9, `app/models/relation.rb:309` 1257.0, `app/models/old_relation.rb:73` 1146.0 |
| 18 | DiaryEntriesController#create | 4 / 4 | 14084.0 / 13887.0 | -197.0 | 11805.8 | `GEM/prosopite/lib/prosopite.rb:419` 845.0, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 638.0, `GEM/i18n/lib/i18n/backend/fallbacks.rb:54` 358.0 | `app/views/diary_entries/_form.html.erb:5` 1486.0, `app/views/application/_richtext_field.html.erb:18` 1228.0, `lib/bootstrap_form/inputs/richtext_field.rb:19` 1165.0 |
| 19 | Api::TracesController#create | 6 / 6 | 15910.0 / 11133.0 | -4777.0 | 9094.8 | `GEM/prosopite/lib/prosopite.rb:419` 1162.0, `GEM/mail/lib/mail/utilities.rb:215` 261.0, `GEM/mail/lib/mail/encodings/8bit.rb:14` 195.0 | `app/controllers/api/traces_controller.rb:96` 1418.3, `app/mailers/user_mailer.rb:70` 649.0, `app/models/trace.rb:296` 607.5 |
| 20 | AccountsController#update | 7 / 7 | 13474.7 / 13461.0 | -13.7 | 11872.0 | `GEM/prosopite/lib/prosopite.rb:419` 2050.8, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 258.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 183.3 | `config/initializers/policy_headers.rb:13` 892.5, `app/controllers/concerns/user_methods.rb:45` 825.5, `config/initializers/mail_delivery_job.rb:9` 701.2 |
| 21 | DiaryEntriesController#new | 8 / 8 | 12178.0 / 13149.0 | 971.0 | 10190.5 | `GEM/prosopite/lib/prosopite.rb:419` 1166.0, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 354.0, `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` 336.0 | `app/controllers/diary_entries_controller.rb:83` 895.7, `app/views/diary_entries/_form.html.erb:5` 817.3, `config/initializers/policy_headers.rb:13` 622.3 |
| 22 | UsersController#show | 34 / 34 | 12706.9 / 12158.0 | -548.9 | 13046.0 | `GEM/prosopite/lib/prosopite.rb:419` 1693.8, `GEM/cancancan/lib/cancan/ability.rb:145` 335.8, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 226.0 | `app/helpers/user_helper.rb:40` 553.9, `config/initializers/policy_headers.rb:13` 424.9, `app/models/user.rb:385` 385.9 |
| 23 | TracesController#index | 27 / 27 | 11972.0 / 12506.8 | 534.9 | 11872.3 | `GEM/prosopite/lib/prosopite.rb:419` 586.0, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 375.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 339.6 | `app/controllers/concerns/pagination_methods.rb:27` 1728.8, `app/helpers/application_helper.rb:21` 632.9, `app/views/traces/_trace.html.erb:54` 402.2 |
| 24 | Users::ListsController#show | 19 / 19 | 11883.2 / 11881.2 | -2.0 | 13598.5 | `GEM/prosopite/lib/prosopite.rb:419` 1305.6, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 268.1, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 205.9 | `app/helpers/user_helper.rb:40` 2101.6, `lib/rich_text.rb:111` 706.9, `app/controllers/concerns/pagination_methods.rb:27` 532.0 |
| 25 | SiteController#index | 446 / 446 | 11773.2 / 11772.5 | -0.7 | 11919.8 | `GEM/prosopite/lib/prosopite.rb:419` 1044.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 363.2, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 342.9 | `app/models/user.rb:288` 571.3, `app/views/layouts/_search.html.erb:18` 557.6, `app/views/layouts/_search.html.erb:22` 520.6 |
| 26 | OldRelationsController#show | 6 / 6 | 17207.0 / 6201.0 | -11006.0 | 9311.8 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 230.0, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 220.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 125.5 | `app/views/layouts/_search.html.erb:18` 286.0, `config/initializers/policy_headers.rb:13` 283.0, `app/views/layouts/_search.html.erb:22` 267.0 |
| 27 | Oauth2ApplicationsController#new | 2 / 2 | 11369.0 / 11360.0 | -9.0 | 6281.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 365.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 311.0, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 310.0 | `app/views/oauth2_applications/_form.html.erb:8` 2405.0, `app/views/application/_settings_menu.html.erb:16` 484.0, `config/initializers/policy_headers.rb:13` 424.0 |
| 28 | ReportsController#new | 7 / 7 | 11170.7 / 11327.7 | 157.0 | 9004.1 | `GEM/prosopite/lib/prosopite.rb:419` 975.0, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 344.7, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 263.3 | `app/views/reports/new.html.erb:20` 1019.3, `app/controllers/reports_controller.rb:16` 735.3, `app/models/user.rb:288` 505.7 |
| 29 | UsersController#create | 45 / 45 | 11503.3 / 10976.9 | -526.4 | 11977.5 | `GEM/prosopite/lib/prosopite.rb:419` 1712.5, `GEM/mail/lib/mail/utilities.rb:215` 197.5, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 119.6 | `config/initializers/mail_delivery_job.rb:9` 812.7, `app/mailers/user_mailer.rb:25` 526.7, `app/controllers/users_controller.rb:224` 466.7 |
| 30 | UserBlocksController#show | 33 / 33 | 11251.8 / 11198.1 | -53.6 | 11266.2 | `GEM/prosopite/lib/prosopite.rb:419` 1527.4, `GEM/prosopite/lib/prosopite.rb:250` 315.0, `GEM/cancancan/lib/cancan/ability.rb:145` 259.4 | `app/controllers/user_blocks_controller.rb:113` 1207.9, `config/initializers/policy_headers.rb:13` 799.8, `app/models/user.rb:288` 456.6 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/prosopite/lib/prosopite.rb:419` | `subscribe` | 770.99 / 770.99 | 0.0 | 772.76 | 70% | Data, Array |  | `app/models/user.rb:385` 7%, `app/controllers/api_controller.rb:100` 6% | `query_caller = caller_locations` |
| 2 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` | `extract_non_symbol_default!` | 99.21 / 99.21 | 0.0 | 99.24 | 48% | Array, Hash | ruby-i18n/i18n#764 open upstream work | `app/views/layouts/_header.html.erb:27` 5%, `app/views/layouts/_search.html.erb:40` 4% | `defaults = [options[:default]].flatten` |
| 3 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` | `tag_option` | 96.35 / 96.35 | 0.0 | 96.97 | 40% | String |  | `app/views/layouts/_meta.html.erb:6` 12%, `app/views/layouts/_header.html.erb:38` 6% | `%(#{key}="#{value}")` |
| 4 | `GEM/cancancan/lib/cancan/ability.rb:145` | `can` | 82.43 / 82.4 | -0.03 | 82.48 | 92% | Array, Object |  | `app/abilities/ability.rb:28` 3%, `app/abilities/ability.rb:11` 3% | `add_rule(Rule.new(true, action, subject, *attributes_and_conditions, &` |
| 5 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` | `html_safe` | 75.14 / 75.19 | 0.05 | 75.25 | 52% | String |  | `no app frame` 18%, `app/views/layouts/_header.html.erb:38` 7% | `ActiveSupport::SafeBuffer.new(self)` |
| 6 | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:101` † | `helper_names` | 69.82 / 69.3 | -0.52 | 70.74 | 13% | String, Array |  | `config/initializers/policy_headers.rb:13` 99%, `app/controllers/users_controller.rb:111` 1% | `@path_helpers.map(&:to_s) + @url_helpers.map(&:to_s)` |
| 7 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` | `initialize` | 63.33 / 63.38 | 0.04 | 63.43 | 50% | String |  | `no app frame` 12%, `app/views/layouts/_header.html.erb:38` 9% | `super` |
| 8 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:54` | `translate` | 55.27 / 55.27 | -0.0 | 55.29 | 50% | Hash | ruby-i18n/i18n#765 open upstream work | `app/views/layouts/_header.html.erb:27` 4%, `app/helpers/application_helper.rb:12` 4% | `fallback_options = options.merge(:fallback_in_progress => true, fallba` |
| 9 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:60` | `translate` | 53.85 / 53.85 | -0.0 | 53.87 | 48% | String | ruby-i18n/i18n#763 open upstream work | `app/views/layouts/_header.html.erb:27` 5%, `app/helpers/application_helper.rb:12` 4% | `on_fallback(locale, fallback, key, options) if locale.to_s != fallback` |
| 10 | `GEM/cancancan/lib/cancan/rule.rb:137` | `wrap` | 52.34 / 52.32 | -0.02 | 52.37 | 92% | Array |  | `app/abilities/ability.rb:29` 4%, `app/abilities/ability.rb:11` 4% | `[object]` |
| 11 | `RAILS/activemodel/lib/active_model/attribute.rb:9` | `from_database` | 51.93 / 51.91 | -0.02 | 52.2 | 70% | Object |  | `app/controllers/application_controller.rb:48` 19%, `app/controllers/concerns/pagination_methods.rb:27` 12% | `FromDatabase.new(name, value_before_type_cast, type, nil, value)` |
| 12 | `GEM/cancancan/lib/cancan/ability/rules.rb:28` | `add_rule_to_index` | 50.0 / 49.99 | -0.01 | 50.04 | 92% | Array |  | `app/abilities/ability.rb:7` 14%, `app/abilities/ability.rb:8` 14% | `@rules_index[subject] \|\|= []` |
| 13 | `GEM/prosopite/lib/prosopite.rb:250` † | `create_notifications` | 46.29 / 46.09 | -0.2 | 47.2 | 4% | String, Array |  | `config/initializers/policy_headers.rb:13` 100% | `kaller = state[:prosopite_query_caller][location_key].map(&:to_s)` |
| 14 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` | `get_oid_type` | 44.52 / 44.53 | 0.01 | 44.76 | 70% | Array |  | `app/controllers/api_controller.rb:100` 14%, `app/controllers/application_controller.rb:48` 12% | `type_map.fetch(oid, fmod, sql_type) {` |
| 15 | `GEM/cancancan/lib/cancan/ability/rules.rb:24` | `add_rule_to_index` | 41.22 / 41.2 | -0.01 | 41.24 | 92% | Array |  | `app/abilities/ability.rb:11` 3%, `app/abilities/ability.rb:26` 3% | `subjects = rule.subjects.compact` |
| 16 | `GEM/cancancan/lib/cancan/rule.rb:31` † | `initialize` | 41.22 / 41.2 | -0.01 | 41.24 | 92% | Array |  | `app/abilities/ability.rb:21` 3%, `app/abilities/ability.rb:22` 3% | `@actions = wrap(action).map(&:to_sym)` |
| 17 | `GEM/cancancan/lib/cancan/rule.rb:121` | `parse_attributes_from_extra_args` | 41.22 / 41.2 | -0.01 | 41.24 | 92% | Array |  | `app/abilities/ability.rb:26` 3%, `app/abilities/ability.rb:24` 3% | `[attributes, extra_args]` |
| 18 | `GEM/cancancan/lib/cancan/rule.rb:133` | `wrap` | 41.22 / 41.2 | -0.01 | 41.24 | 92% | Array |  | `app/abilities/ability.rb:9` 3%, `app/abilities/ability.rb:8` 3% | `[]` |
| 19 | `GEM/cancancan/lib/cancan/rule.rb:34` | `initialize` | 40.07 / 40.05 | -0.01 | 40.09 | 92% | Hash |  | `app/abilities/ability.rb:24` 3%, `app/abilities/ability.rb:10` 3% | `@conditions = extra_args \|\| {}` |
| 20 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:237` | `tag_options` | 33.77 / 33.77 | 0.0 | 33.97 | 40% | String |  | `app/views/layouts/_meta.html.erb:6` 9%, `app/views/layouts/_header.html.erb:38` 8% | `output = +""` |
| 21 | `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:348` | `validate` | 31.24 / 31.24 | 0.0 | 31.3 | 99% | String |  | `no app frame` 100% | `if source.include?(";") \|\| source != source.gsub(/[[:space:]]/, "")` |
| 22 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | `merge` | 30.34 / 30.36 | 0.02 | 30.43 | 66% | Object, Array |  | `app/models/user.rb:288` 15%, `app/models/user.rb:385` 13% | `WhereClause.new(predicates \| other.predicates)` |
| 23 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:151` † | `now` | 29.2 / 29.2 | 0.0 | 29.24 | 89% | Data |  | `no app frame` 12%, `config/initializers/policy_headers.rb:13` 5% | `Time.now` |
| 24 | `GEM/i18n/lib/i18n/utils.rb:8` | `except` | 29.12 / 29.12 | 0.0 | 29.14 | 50% | Hash |  | `app/views/layouts/_header.html.erb:27` 4%, `app/helpers/application_helper.rb:12` 3% | `hash.except(*keys)` |
| 25 | `GEM/i18n/lib/i18n.rb:396` | `normalize_keys` | 28.6 / 28.59 | 0.0 | 29.06 | 50% | Array |  | `app/views/layouts/_header.html.erb:27` 4%, `app/helpers/application_helper.rb:12` 3% | `[` |
| 26 | `GEM/i18n/lib/i18n/backend/base.rb:58` | `translate` | 27.68 / 27.68 | 0.0 | 27.69 | 50% | Array |  | `app/views/layouts/_header.html.erb:27` 4%, `app/helpers/application_helper.rb:12` 4% | `values = Utils.except(options, *RESERVED_KEYS) unless options.empty?` |
| 27 | `GEM/rails-controller-testing/lib/rails/controller/testing/template_assertions.rb:39` | `setup_subscriptions` | 27.05 / 27.03 | -0.02 | 27.07 | 48% | String, Array |  | `no app frame` 25%, `app/views/layouts/_header.html.erb:9` 6% | `@_partials[virtual_path.split("/").last] += 1` |
| 28 | `RAILS/activerecord/lib/arel/visitors/postgresql.rb:136` | `visit_Arel_Nodes_IsDistinctFrom` | 26.93 / 26.94 | 0.01 | 26.99 | 75% | String |  | `app/controllers/application_controller.rb:48` 11%, `app/models/user.rb:288` 8% | `BIND_BLOCK = proc { \|i\| "$#{i}" }` |
| 29 | `GEM/i18n/lib/i18n/backend/base.rb:49` | `translate` | 26.42 / 26.42 | 0.0 | 26.43 | 50% | String |  | `app/views/layouts/_header.html.erb:27` 5%, `app/helpers/application_helper.rb:12` 4% | `entry = entry.dup if entry.is_a?(String)` |
| 30 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` | `call` | 26.15 / 26.15 | 0.0 | 26.16 | 100% | Data |  | `config/initializers/policy_headers.rb:13` 17%, `no app frame` 15% | `result_lambda = -> { user_callback.call target, value }` |

## Dev/test-mode work

1796.7 of 7293.2 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | error page | `RUBY/error_highlight/base.rb:94` | 829.51 | 1% | `no app frame` 100% | `Prism.parse_file(absolute_path).value.breadth_first_search { \|node\| no` |
| 2 | error page | `GEM/prism/lib/prism/parse_result.rb:162` | 297.39 | 1% | `no app frame` 100% | `source.lines` |
| 3 | asset lookup | `GEM/sprockets/lib/sprockets/path_utils.rb:236` | 63.52 | 19% | `app/views/layouts/_search.html.erb:22` 48%, `app/views/layouts/_search.html.erb:18` 48% | `next unless File.basename(entry).start_with?(basename)` |
| 4 | error page | `RAILS/actionpack/lib/action_dispatch/middleware/exception_wrapper.rb:332` | 51.6 | 1% | `no app frame` 100% | `lines = source_lines.drop(start).take(6)` |
| 5 | error page | `GEM/prism/lib/prism/node.rb:4628` | 36.19 | 1% | `no app frame` 100% | `compact = [] #: Array[Prism::node]` |
| 6 | error page | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:195` | 33.47 | 1% | `no app frame` 100% | `add_filter { \|line\| line.sub(gems_regexp, gems_result) }` |
| 7 | error page | `GEM/prism/lib/prism/node.rb:30908` | 24.71 | 1% | `no app frame` 100% | `[*body]` |
| 8 | asset lookup | `GEM/sprockets-rails/lib/sprockets/rails/helper.rb:81` | 19.22 | 33% | `app/views/layouts/_meta.html.erb:6` 31%, `app/views/layouts/_meta.html.erb:8` 3% | `File.join(assets_prefix \|\| "/", legacy_debug_path(asset_path, debug))` |
| 9 | error page | `GEM/prism/lib/prism/node.rb:1312` | 16.79 | 1% | `no app frame` 100% | `[*arguments]` |
| 10 | template compile | `GEM/erubi/lib/erubi.rb:134` | 16.46 | 11% | `config/initializers/policy_headers.rb:13` 31%, `no app frame` 20% | `input.scan(regexp) do \|indicator, code, tailch, rspace\|` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activerecord | 915.0 | 933.6 | `postgresql_adapter.rb:880` 44.5, `where_clause.rb:29` 30.3, `postgresql.rb:136` 26.9 |
| ruby stdlib | 867.0 | 1204.3 | `base.rb:94` 829.5, `formatter.rb:174` 7.2, `ipaddr.rb:725` 3.4 |
| gem: prosopite | 856.0 | 859.1 | `prosopite.rb:419` 771.0, `prosopite.rb:250` 46.2, `prosopite.rb:418` 11.3 |
| rails: actionview | 690.3 | 704.1 | `tag_helper.rb:318` 96.3, `tag_helper.rb:237` 33.8, `translation_helper.rb:91` 23.5 |
| rails: activesupport | 654.6 | 687.2 | `output_safety.rb:242` 75.2, `output_safety.rb:71` 63.4, `backtrace_cleaner.rb:195` 33.5 |
| rails: actionpack | 614.2 | 708.4 | `route_set.rb:101` 69.6, `exception_wrapper.rb:332` 51.6, `content_security_policy.rb:348` 31.2 |
| ruby default gem: prism | 498.8 | 717.7 | `parse_result.rb:162` 297.4, `node.rb:4628` 36.2, `node.rb:30908` 24.7 |
| gem: cancancan | 483.1 | 483.7 | `ability.rb:145` 82.4, `rule.rb:137` 52.3, `rules.rb:28` 50.0 |
| app | 398.0 | 430.4 | `migrate.rb:8` 37.6, `_meta.html.erb:6` 26.5, `_header.html.erb:38` 22.1 |
| gem: i18n | 369.7 | 379.1 | `fallbacks.rb:98` 99.2, `fallbacks.rb:54` 55.3, `fallbacks.rb:60` 53.9 |
| gem: inline_svg | 188.4 | 190.4 | `transformations.rb:54` 14.6, `transformations.rb:13` 8.5, `transformations.rb:9` 8.5 |
| gem: sprockets | 183.4 | 186.5 | `path_utils.rb:236` 63.5, `resolve.rb:218` 9.7, `resolve.rb:292` 7.3 |
| gem: nokogiri | 170.0 | 171.2 | `node.rb:1431` 17.7, `node.rb:66` 11.2, `document.rb:85` 9.8 |
| rails: activemodel | 142.5 | 151.0 | `attribute.rb:9` 51.9, `attribute_methods.rb:492` 12.4, `builder.rb:37` 10.2 |
| gem: omniauth | 93.2 | 93.7 | `paths.rb:67` 25.0, `strategy.rb:285` 11.9, `paths.rb:94` 11.9 |
| gem: rack | 66.9 | 68.9 | `request.rb:607` 12.9, `utils.rb:693` 11.7, `body_proxy.rb:12` 4.0 |
| gem: sprockets-rails | 44.7 | 50.2 | `helper.rb:81` 19.2, `route_wrapper.rb:5` 7.8, `helper.rb:186` 2.5 |
| ruby default gem: uri | 39.7 | 40.0 | `rfc2396_parser.rb:320` 11.2, `common.rb:465` 8.2, `rfc2396_parser.rb:291` 7.3 |
| gem: hashie | 38.9 | 39.7 | `mash.rb:641` 15.1, `mash.rb:596` 15.1, `mash.rb:329` 3.6 |
| gem: mail | 38.0 | 55.1 | `utilities.rb:215` 5.7, `8bit.rb:14` 3.2, `field_list.rb:71` 2.8 |
| gem: rails-controller-testing | 34.9 | 34.9 | `template_assertions.rb:39` 27.0, `template_assertions.rb:35` 6.7, `template_assertions.rb:27` 0.7 |
| gem: builder | 33.3 | 34.8 | `xchar.rb:155` 7.2, `xchar.rb:156` 3.8, `xchar.rb:154` 3.8 |
| gem: aasm | 29.4 | 29.9 | `state_machine_store.rb:29` 4.9, `state_machine.rb:10` 2.1, `aasm.rb:45` 2.1 |
| gem: erubi | 28.3 | 31.1 | `erubi.rb:134` 16.3, `erubi.rb:137` 3.5, `erubi.rb:139` 2.1 |
| gem: concurrent-ruby | 25.1 | 25.4 | `safe_initialization.rb:30` 6.0, `non_concurrent_map_backend.rb:131` 3.7, `mutex_lockable_object.rb:33` 2.0 |
| gem: sanitize | 23.1 | 23.3 | `sanitize.rb:203` 6.7, `clean_element.rb:84` 3.3, `sanitize.rb:206` 2.9 |
| gem: loofah | 17.9 | 17.9 | `concerns.rb:172` 6.5, `concerns.rb:43` 4.9, `scrubber.rb:132` 3.3 |
| gem: kramdown | 15.6 | 15.9 | `kramdown.rb:136` 1.5, `kramdown.rb:135` 1.3, `utils.rb:27` 0.8 |
| gem: rack-session | 14.8 | 14.9 | `id.rb:43` 6.5, `id.rb:31` 4.1, `id.rb:275` 1.0 |
| gem: tzinfo | 14.0 | 14.1 | `timestamp.rb:208` 4.4, `timestamp.rb:193` 3.0, `constant_offset_data_timezone_info.rb:52` 2.8 |
| gem: rails-html-sanitizer | 11.4 | 11.4 | `sanitizer.rb:33` 1.6, `sanitizer.rb:192` 1.6, `sanitizer.rb:56` 1.6 |
| gem: http_accept_language | 11.3 | 11.3 | `parser.rb:19` 3.5, `middleware.rb:8` 3.0, `middleware.rb:10` 2.0 |
| gem: addressable | 8.9 | 10.0 | `uri.rb:438` 1.0, `uri.rb:424` 0.8, `uri.rb:486` 0.6 |
| gem: bootstrap_form | 7.9 | 8.4 | `hints.rb:65` 0.8, `bootstrap.rb:102` 0.5, `hints.rb:52` 0.4 |
| gem: doorkeeper | 7.8 | 9.6 | `scopes.rb:14` 2.4, `token.rb:150` 1.4, `token.rb:154` 0.7 |
| gem: quad_tile | 6.7 | 7.7 | `quad_tile.rb:13` 5.3, `quad_tile.rb:17` 1.2, `quad_tile.rb:19` 0.1 |
| rails: railties | 6.0 | 6.1 | `engine.rb:748` 1.0, `logger.rb:37` 1.0, `logger.rb:65` 1.0 |
| gem: rack-cors | 5.9 | 5.9 | `cors.rb:123` 3.3, `result.rb:38` 1.0, `cors.rb:129` 1.0 |
| test harness: webmock | 4.3 | 4.9 | `headers.rb:69` 0.5, `headers.rb:68` 0.4, `uri.rb:62` 0.2 |
| gem: turbo-rails | 3.8 | 3.9 | `request_id_tracking.rb:10` 1.0, `frame_request.rb:36` 0.8, `drive_helper.rb:78` 0.7 |
| gem: argon2 | 3.0 | 3.1 | `hash_format.rb:46` 0.9, `hash_format.rb:17` 0.8, `hash_format.rb:21` 0.2 |
| gem: rack-uri_sanitizer | 3.0 | 3.0 | `uri_sanitizer.rb:10` 3.0 |
| gem: canonical-rails | 3.0 | 3.0 | `tag_helper.rb:4` 0.7, `tag_helper.rb:23` 0.5, `tag_helper.rb:21` 0.4 |
| rails: activestorage | 2.9 | 3.6 | `model.rb:128` 0.6, `one.rb:34` 0.5, `model.rb:284` 0.3 |
| ruby default gem: securerandom | 2.2 | 2.2 | `securerandom.rb:71` 2.2 |
| gem: rgeo | 1.9 | 3.4 | `entities.rb:184` 0.5, `entities.rb:187` 0.4, `entities.rb:193` 0.3 |
| gem: bootsnap | 1.9 | 2.5 | `kernel_require.rb:11` 1.0, `cache.rb:218` 0.3, `loaded_features_index.rb:118` 0.1 |
| gem: rexml | 1.6 | 2.3 | `source.rb:293` 0.1, `element.rb:2429` 0.1, `source.rb:269` 0.1 |
| gem: config | 1.3 | 1.4 | `options.rb:156` 1.3, `options.rb:125` 0.1, `options.rb:123` 0.0 |
| ruby default gem: timeout | 1.3 | 1.3 | `timeout.rb:152` 0.3, `timeout.rb:292` 0.3, `timeout.rb:293` 0.3 |
| gem: rails_param | 1.2 | 1.4 | `validator.rb:51` 0.4, `param_evaluator.rb:11` 0.2, `param.rb:3` 0.2 |
| gem: faraday | 1.1 | 1.3 | `nested_params_encoder.rb:108` 0.2, `nested_params_encoder.rb:94` 0.1, `utils.rb:39` 0.1 |
| gem: json | 1.0 | 1.1 | `common.rb:860` 0.8, `common.rb:297` 0.2, `common.rb:377` 0.0 |
| gem: validates_email_format_of | 0.9 | 1.0 | `validates_email_format_of.rb:193` 0.3, `validates_email_format_of.rb:256` 0.3, `validates_email_format_of.rb:146` 0.1 |
| gem: globalid | 0.9 | 1.1 | `gid.rb:159` 0.2, `gid.rb:95` 0.2, `gid.rb:166` 0.1 |
| rails: activejob | 0.8 | 1.0 | `arguments.rb:141` 0.1, `core.rb:129` 0.1, `arguments.rb:61` 0.1 |
| gem: libxml-ruby | 0.8 | 0.8 | `node.rb:75` 0.2, `node.rb:58` 0.1, `node.rb:61` 0.1 |
| gem: simpleidn | 0.7 | 0.8 | `simpleidn.rb:224` 0.3, `simpleidn.rb:235` 0.1, `simpleidn.rb:222` 0.1 |
| rails: actionmailer | 0.4 | 1.0 | `mail_helper.rb:69` 0.1, `mail_helper.rb:68` 0.0, `base.rb:1009` 0.0 |
| gem: jbuilder | 0.4 | 0.5 | `jbuilder.rb:354` 0.1, `collection_renderer.rb:21` 0.1, `jbuilder_template.rb:150` 0.0 |
| ruby default gem: net-http | 0.3 | 0.4 | `header.rb:203` 0.0, `header.rb:275` 0.0, `header.rb:225` 0.0 |
| gem: pg | 0.3 | 0.9 | `connection.rb:350` 0.3, `connection.rb:351` 0.1, `connection.rb:844` 0.0 |
| gem: bigdecimal | 0.3 | 0.3 | `util.rb:24` 0.2, `util.rb:51` 0.0 |
| gem: noticed | 0.2 | 0.6 | `deliver_by.rb:12` 0.1, `notification_methods.rb:11` 0.0, `deliverable.rb:70` 0.0 |
| gem: openstreetmap-deadlock_retry | 0.2 | 0.2 | `deadlock_retry.rb:21` 0.2, `deadlock_retry.rb:62` 0.0 |
| ruby default gem: erb | 0.2 | 0.2 | `util.rb:65` 0.2 |
| ruby default gem: prettyprint | 0.2 | 0.2 | `prettyprint.rb:404` 0.0, `prettyprint.rb:264` 0.0, `prettyprint.rb:459` 0.0 |
| gem: unicode-display_width | 0.1 | 0.1 | `display_width.rb:218` 0.0, `display_width.rb:60` 0.0, `display_width.rb:220` 0.0 |
| gem: htmlentities | 0.1 | 0.1 | `decoder.rb:10` 0.0, `decoder.rb:25` 0.0, `decoder.rb:35` 0.0 |
| gem: zeitwerk | 0.1 | 0.1 | `cref.rb:36` 0.0, `cref.rb:47` 0.0, `file_system.rb:203` 0.0 |
| ruby default gem: pp | 0.1 | 0.1 | `pp.rb:542` 0.0, `pp.rb:550` 0.0, `pp.rb:271` 0.0 |
| gem: faraday-net_http | 0.1 | 0.1 | `net_http.rb:95` 0.0, `net_http.rb:165` 0.0, `net_http.rb:94` 0.0 |
| gem: base64 | 0.0 | 0.1 | `base64.rb:283` 0.0, `base64.rb:310` 0.0, `base64.rb:377` 0.0 |
| gem: logger | 0.0 | 0.1 | `log_device.rb:33` 0.0, `log_device.rb:165` 0.0, `logger.rb:692` 0.0 |
| gem: active_record_union | 0.0 | 0.1 | `union.rb:49` 0.0, `union.rb:27` 0.0, `union.rb:55` 0.0 |
| gem: omniauth-rails_csrf_protection | 0.0 | 0.0 | `token_verifier.rb:59` 0.0, `token_verifier.rb:55` 0.0 |
| gem: marcel | 0.0 | 0.3 | `magic.rb:18` 0.0, `mime_type.rb:90` 0.0, `magic.rb:75` 0.0 |
| ruby default gem: open3 | 0.0 | 0.1 | `open3.rb:527` 0.0, `open3.rb:790` 0.0, `open3.rb:528` 0.0 |
| gem: activerecord-postgis | 0.0 | 0.1 | `spatial.rb:76` 0.0, `spatial.rb:64` 0.0, `spatial.rb:39` 0.0 |
| gem: cgi | 0.0 | 0.1 | `core.rb:575` 0.0, `core.rb:574` 0.0, `core.rb:579` 0.0 |
| ruby default gem: digest | 0.0 | 0.0 | `digest.rb:83` 0.0, `digest.rb:64` 0.0, `digest.rb:65` 0.0 |
| gem: ffi | 0.0 | 0.3 | `managedstruct.rb:80` 0.0, `autopointer.rb:88` 0.0, `autopointer.rb:79` 0.0 |
| gem: mini_mime | 0.0 | 0.2 | `mini_mime.rb:54` 0.0, `mini_mime.rb:56` 0.0, `mini_mime.rb:169` 0.0 |
| gem: ruby-vips | 0.0 | 0.3 | `object.rb:203` 0.0, `object.rb:201` 0.0, `object.rb:202` 0.0 |
| gem: doorkeeper-openid_connect | 0.0 | 0.3 | `controller.rb:78` 0.0, `openid_connect.rb:145` 0.0, `prompt.rb:73` 0.0 |
| gem: racc | 0.0 | 0.0 | `parser.rb:263` 0.0 |
| gem: jwt | 0.0 | 0.0 | `rsa.rb:122` 0.0, `thumbprint.rb:17` 0.0, `rsa.rb:94` 0.0 |
| gem: lowrail-profile | 0.0 | 0.0 | `profile.rb:95` 0.0, `profile.rb:55` 0.0, `profile.rb:65` 0.0 |
| gem: rgeo-activerecord | 0.0 | 0.0 | `spatial_factory_store.rb:47` 0.0, `spatial_factory_store.rb:12` 0.0 |
| gem: active_storage_validations | 0.0 | 0.1 | `form_builder.rb:23` 0.0, `form_builder.rb:27` 0.0, `form_builder.rb:40` 0.0 |
| gem: omniauth-microsoft_graph | 0.0 | 0.0 | `microsoft_graph.rb:73` 0.0 |
| gem: omniauth-facebook | 0.0 | 0.0 | `facebook.rb:84` 0.0, `facebook.rb:88` 0.0 |
| gem: omniauth-google-oauth2 | 0.0 | 0.0 | `google_oauth2.rb:219` 0.0, `google_oauth2.rb:373` 0.0, `google_oauth2.rb:104` 0.0 |
| gem: omniauth-github | 0.0 | 0.0 | `github.rb:78` 0.0 |
| gem: omniauth-apple | 0.0 | 0.0 | `apple.rb:63` 0.0 |
| gem: activerecord-import | 0.0 | 0.0 | `import.rb:671` 0.0, `import.rb:650` 0.0, `import.rb:1308` 0.0 |
| gem: image_processing | 0.0 | 0.0 | `processor.rb:41` 0.0, `pipeline.rb:14` 0.0, `vips.rb:183` 0.0 |
| gem: gd2-ffij | 0.0 | 0.3 | `image.rb:54` 0.0, `image.rb:0` 0.0, `image.rb:534` 0.0 |
| gem: ffi-libarchive | 0.0 | 0.1 | `archive.rb:326` 0.0, `reader.rb:60` 0.0, `archive.rb:335` 0.0 |
| gem: matrix | 0.0 | 0.1 | `matrix.rb:331` 0.0, `matrix.rb:162` 0.0, `matrix.rb:198` 0.0 |
| gem: auth-sanitizer | 0.0 | 0.0 | `thing_filter.rb:23` 0.0, `thing_filter.rb:22` 0.0, `filtered_attributes.rb:35` 0.0 |
| gem: sentry-rails | 0.0 | 0.0 | `active_job.rb:32` 0.0 |
| gem: snaky_hash | 0.0 | 0.0 | `snake.rb:110` 0.0, `snake.rb:113` 0.0, `snake.rb:109` 0.0 |
| gem: oauth2 | 0.0 | 0.0 | `auth_code.rb:22` 0.0, `client.rb:67` 0.0, `client.rb:57` 0.0 |
| gem: omniauth-oauth2 | 0.0 | 0.0 | `oauth2.rb:63` 0.0, `oauth2.rb:71` 0.0, `oauth2.rb:137` 0.0 |
| gem: actionpack-page_caching | 0.0 | 0.0 | `pages.rb:61` 0.0, `pages.rb:55` 0.0, `railtie.rb:8` 0.0 |
| gem: teaspoon | 0.0 | 0.1 | `engine.rb:65` 0.0 |
| gem: msgpack | 0.0 | 0.0 | `factory.rb:41` 0.0, `factory.rb:16` 0.0, `factory.rb:31` 0.0 |
| rails: actiontext | 0.0 | 0.3 | `rendering.rb:13` 0.0, `content.rb:0` 0.0, `rendering.rb:0` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Jobs

| # | Job | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | TraceImporterJob#perform | 7 / 7 | 29800.0 / 16114.0 | -13686.0 | 18335.0 | `GEM/prosopite/lib/prosopite.rb:419` 1378.0, `GEM/mail/lib/mail/utilities.rb:215` 1044.0, `GEM/mail/lib/mail/encodings/8bit.rb:14` 776.0 | `app/mailers/user_mailer.rb:95` 2459.0, `app/jobs/trace_importer_job.rb:35` 1726.0, `app/jobs/trace_importer_job.rb:34` 1319.0 |
| 2 | Noticed::EventJob#perform | 16 / 16 | 8329.9 / 8170.8 | -159.1 | 10828.1 | `GEM/mail/lib/mail/utilities.rb:215` 588.4, `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` 420.0, `GEM/prosopite/lib/prosopite.rb:419` 371.8 | `app/mailers/user_mailer.rb:114` 361.1, `app/mailers/user_mailer.rb:200` 351.1, `app/mailers/user_mailer.rb:70` 321.6 |
| 3 | TraceLinestringJob#perform | 16 / 16 | 336.1 / 336.3 | 0.2 | 571.7 | `GEM/prosopite/lib/prosopite.rb:419` 94.1, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 8.0, `GEM/prosopite/lib/prosopite.rb:418` 8.0 | `app/jobs/trace_linestring_job.rb:93` 152.3, `app/jobs/trace_linestring_job.rb:95` 109.1, `app/jobs/trace_linestring_job.rb:92` 25.0 |
| 4 | ActionMailer::MailDeliveryJob#perform | 2 / 2 | – / – |  | 6276.5 |  |  |
| 5 | TraceDestroyerJob#perform | 1 / 1 | – / – |  | 382.0 |  |  |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/prosopite/lib/prosopite.rb:419` | 366.05 / 372.81 | 95% | `no app frame` 51%, `app/jobs/trace_linestring_job.rb:95` 9% | `query_caller = caller_locations` |
| 2 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` | 292.0 / 232.0 | 38% | `no app frame` 76%, `app/jobs/trace_importer_job.rb:34` 9% | `@method_name % attr_name` |
| 3 | `GEM/mail/lib/mail/utilities.rb:215` | 218.29 / 211.5 | 36% | `no app frame` 55%, `app/mailers/user_mailer.rb:95` 11% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 4 | `GEM/mail/lib/mail/encodings/8bit.rb:14` | 172.57 / 124.95 | 33% | `no app frame` 95%, `config/initializers/mail_delivery_job.rb:9` 5% | `!str.lines.find { \|line\| line.bytesize > 998 }` |
| 5 | `GEM/mail/lib/mail/field_list.rb:71` † | 109.12 / 105.81 | 36% | `no app frame` 56%, `app/mailers/user_mailer.rb:95` 11% | `fields = select { \|f\| f.responsible_for? field_name }` |
| 6 | `GEM/mail/lib/mail/fields/parameter_hash.rb:22` | 99.0 / 97.6 | 36% | `no app frame` 48%, `app/mailers/user_mailer.rb:95` 15% | `if k =~ /^#{key_pattern}(\*\|$)/i` |
| 7 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:333` | 70.5 / 56.0 | 38% | `no app frame` 76%, `app/jobs/trace_importer_job.rb:34` 9% | `generate_method = "define_method_#{pattern.proxy_target}"` |
| 8 | `RAILS/activesupport/lib/active_support/code_generator.rb:35` | 70.5 / 56.0 | 38% | `no app frame` 76%, `app/jobs/trace_importer_job.rb:34` 9% | `owner.define_method(as, @cache.instance_method(canonical_name))` |
| 9 | `RAILS/activerecord/lib/active_record/attribute_methods.rb:176` | 70.5 / 56.0 | 38% | `no app frame` 70%, `app/jobs/trace_importer_job.rb:34` 12% | `! superclass.instance_method(method_name).owner.is_a?(GeneratedAttribu` |
| 10 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:338` | 64.26 / 51.05 | 38% | `no app frame` 76%, `app/jobs/trace_importer_job.rb:34` 9% | `define_proxy_call(` |

### Mails

| # | Mailer action | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | UserMailer#gpx_success | 3 / 3 | 3736.0 / 3738.0 | 2.0 | 4042.0 | `GEM/mail/lib/mail/utilities.rb:215` 398.0, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 237.0, `GEM/mail/lib/mail/field_list.rb:71` 197.0 | `app/mailers/user_mailer.rb:70` 2463.0, `app/mailers/user_mailer.rb:248` 255.0, `app/views/layouts/user_mailer.html.erb:15` 211.0 |
| 2 | UserMailer#message_notification | 4 / 4 | – / – |  | 8275.0 |  |  |
| 3 | UserMailer#changeset_comment_notification | 1 / 1 | – / – |  | 5988.0 |  |  |
| 4 | UserMailer#diary_comment_notification | 1 / 1 | – / – |  | 5971.0 |  |  |
| 5 | UserMailer#follow_notification | 1 / 1 | – / – |  | 5350.0 |  |  |
| 6 | UserMailer#note_comment_notification | 1 / 1 | – / – |  | 5475.0 |  |  |
| 7 | UserMailer#gpx_failure | 1 / 1 | – / – |  | 4603.0 |  |  |
| 8 | UserMailer#signup_confirm | 1 / 1 | – / – |  | 4006.0 |  |  |
| 9 | UserMailer#email_confirm | 1 / 1 | – / – |  | 3728.0 |  |  |
| 10 | UserMailer#lost_password | 1 / 1 | – / – |  | 3652.0 |  |  |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/mail/lib/mail/utilities.rb:215` | 220.73 / 208.53 | 100% | `app/mailers/user_mailer.rb:114` 24%, `app/mailers/user_mailer.rb:70` 15% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 2 | `GEM/mail/lib/mail/fields/parameter_hash.rb:22` | 115.8 / 114.07 | 100% | `app/mailers/user_mailer.rb:114` 22%, `app/mailers/user_mailer.rb:70` 17% | `if k =~ /^#{key_pattern}(\*\|$)/i` |
| 3 | `GEM/mail/lib/mail/field_list.rb:71` † | 108.73 / 103.13 | 100% | `app/mailers/user_mailer.rb:114` 24%, `app/mailers/user_mailer.rb:70` 15% | `fields = select { \|f\| f.responsible_for? field_name }` |
| 4 | `GEM/mail/lib/mail/parsers/content_type_parser.rb:734` | 83.87 / 82.13 | 100% | `app/mailers/user_mailer.rb:114` 20%, `app/mailers/user_mailer.rb:248` 16% | `_wide = data[p].ord` |
| 5 | `GEM/mail/lib/mail/fields/parameter_hash.rb:56` | 57.33 / 53.0 | 100% | `app/mailers/user_mailer.rb:114` 24%, `app/mailers/user_mailer.rb:70` 13% | `map.sort_by { \|a\| a.first.to_s }.map! do \|key_name, value\|` |
| 6 | `GEM/mail/lib/mail/utilities.rb:291` | 47.93 / 44.07 | 100% | `app/mailers/user_mailer.rb:248` 21%, `app/mailers/user_mailer.rb:114` 16% | `value !~ /\S/` |
| 7 | `GEM/mail/lib/mail/message.rb:2130` | 45.87 / 42.4 | 100% | `app/mailers/user_mailer.rb:114` 24%, `app/mailers/user_mailer.rb:70` 13% | `content_loc_name  = header[:content_location].location rescue nil` |
| 8 | `GEM/mail/lib/mail/utilities.rb:226` | 43.13 / 40.27 | 100% | `app/mailers/user_mailer.rb:114` 23%, `app/mailers/user_mailer.rb:70` 13% | `str.to_s.downcase.tr(Constants::HYPHEN, Constants::UNDERSCORE)` |
| 9 | `GEM/mail/lib/mail/parsers/address_lists_parser.rb:32009` | 39.67 / 39.67 | 100% | `app/mailers/user_mailer.rb:114` 27%, `app/mailers/user_mailer.rb:70` 20% | `_wide = data[p].ord` |
| 10 | `GEM/erubi/lib/erubi.rb:134` (template compile) | 45.93 / 31.4 | 73% | `app/mailers/user_mailer.rb:114` 17%, `app/mailers/user_mailer.rb:237` 11% | `input.scan(regexp) do \|indicator, code, tailch, rspace\|` |
