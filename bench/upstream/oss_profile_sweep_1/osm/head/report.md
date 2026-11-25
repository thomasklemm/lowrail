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
| run1 | 8 | 4230 | 9383.0 | 42 | 15 | 0 | 0 |
| run2 | 8 | 4230 | 9379.6 | 42 | 15 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.01, max |Δ| 0.13 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/models/user.rb:385` | `role?` | 91.68 | 0.0 | 1.07 | `GEM/prosopite/lib/prosopite.rb:419` 47%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 3%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 2% | SiteController#index 32%, SessionsController#create 6%, Api::Changesets::UploadsController#create 5% | `roles.any? { \|r\| r.role == role }` |
| 2 | `app/models/user.rb:288` | `preferred_color_scheme` | 85.89 | 0.0 | 2.37 | `GEM/prosopite/lib/prosopite.rb:419` 29%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 4%, `RAILS/activerecord/lib/arel/visitors/postgresql.rb:136` 2% | SiteController#index 69%, UserBlocksController#show 3%, ChangesetsController#index 3% | `color_preferences = preferences.color_schemes.where.not(:v => "auto").` |
| 3 | `app/helpers/user_helper.rb:40` | `user_image_tag` | 84.44 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 47%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 3%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 2% | SiteController#index 55%, DiaryEntriesController#index 12%, Users::ListsController#show 9% | `elsif user.avatar.attached?` |
| 4 | `app/views/layouts/_search.html.erb:18` |  | 80.59 | 67.77 | 0.28 | `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:54` 6%, `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:11` 5%, `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:14` 5% | SiteController#index 72%, SearchesController#show 18%, ChangesetsController#index 4% | `<%= inline_svg_tag "magnifying_glass.svg" %>` |
| 5 | `app/views/layouts/_search.html.erb:22` |  | 75.24 | 67.7 | 0.85 | `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:54` 7%, `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:6` 3%, `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:12` 3% | SiteController#index 72%, SearchesController#show 18%, ChangesetsController#index 4% | `<%= inline_svg_tag "directions.svg", :class => "align-bottom" %>` |
| 6 | `app/controllers/application_controller.rb:48` | `authorize_web` | 72.63 | 0.0 | 0.71 | `GEM/prosopite/lib/prosopite.rb:419` 32%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 11%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 7% | SiteController#index 54%, SessionsController#create 10%, UserBlocksController#show 3% | `self.current_user = User.find_by(:id => session[:user], :status => %w[` |
| 7 | `app/controllers/api_controller.rb:100` | `setup_user_auth` | 62.7 | 0.0 | 0.13 | `GEM/prosopite/lib/prosopite.rb:419` 55%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 7%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 7% | Api::Changesets::UploadsController#create 14%, Api::ChangesetCommentsController#create 10%, Api::NodesController#update 8% | `self.current_user = User.find(doorkeeper_token.resource_owner_id) if d` |
| 8 | `app/views/application/_auth_button.html.erb:7` |  | 61.42 | 23.49 | 0.3 | `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:54` 4%, `GEM/nokogiri/lib/nokogiri/xml/document.rb:85` 4%, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1431` 4% | SessionsController#new 93%, UsersController#create 6%, UsersController#new 2% | `<%= inline_svg_tag "auth_providers/#{provider}.svg",` |
| 9 | `app/views/layouts/_header.html.erb:53` |  | 60.87 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 48%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 3%, `RAILS/activerecord/lib/arel/visitors/postgresql.rb:136` 2% | SiteController#index 73%, ChangesetsController#index 3%, UserBlocksController#show 3% | `<% if current_user.new_messages.size > 0 %>` |
| 10 | `app/views/layouts/_header.html.erb:38` |  | 51.12 | 0.0 | 18.19 | `RAILS/actionview/lib/action_view/helpers/output_safety_helper.rb:36` 13%, `GEM/uri/lib/uri/rfc2396_parser.rb:320` 12%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:590` 10% | SiteController#index 40%, SearchesController#show 10%, SessionsController#new 9% | `<%= link_to label, path, :class => ["nav-link", "px-1", "py-2", "py-md` |
| 11 | `app/controllers/api_controller.rb:106` | `setup_user_auth` | 43.25 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 48%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 3%, `RAILS/activerecord/lib/arel/visitors/to_sql.rb:790` 3% | Api::Changesets::UploadsController#create 13%, Api::ChangesetCommentsController#create 9%, Api::NodesController#update 7% | `user_block = current_user.blocks.active.take` |
| 12 | `app/models/user.rb:173` | `lookup` | 42.77 | 0.0 | 0.12 | `GEM/prosopite/lib/prosopite.rb:419` 41%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 9%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 9% | SessionsController#create 100% | `user = find_by("email = ? OR display_name = ?", username, username)` |
| 13 | `app/models/old_node.rb:72` | `save_with_dependencies!` | 41.89 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 48%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 4%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 2% | Api::Changesets::UploadsController#create 72%, Api::NodesController#create 15%, Api::NodesController#update 13% | `save!` |
| 14 | `app/controllers/api_controller.rb:146` | `api_call_timeout` | 41.4 | 1.42 | 0.0 | `GEM/cancancan/lib/cancan/ability.rb:80` 6%, `RAILS/actionview/lib/action_view/template_path.rb:23` 5%, `GEM/cancancan/lib/cancan/ability.rb:77` 4% | Api::ChangesetsController#index 9%, Api::Messages::InboxesController#show 5%, Api::UserPreferencesController#index 4% | `Timeout.timeout(Settings.api_timeout, &)` |
| 15 | `app/controllers/concerns/pagination_methods.rb:27` | `get_page_items` | 40.64 | 0.0 | 0.08 | `GEM/prosopite/lib/prosopite.rb:419` 22%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 14%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 6% | ChangesetsController#index 26%, TracesController#index 22%, DiaryEntriesController#index 15% | `page_items = page_items.sort_by(&cursor_column).reverse` |
| 16 | `app/views/layouts/_meta.html.erb:6` |  | 38.17 | 4.91 | 21.47 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 25%, `RAILS/actionview/lib/action_view/helpers/asset_url_helper.rb:208` 6%, `RAILS/actionview/lib/action_view/helpers/asset_tag_helper.rb:324` 6% | SiteController#index 38%, SearchesController#show 9%, SessionsController#new 9% | `<%= favicon_link_tag "apple-touch-icon-#{size}x#{size}.png", :rel => "` |
| 17 | `app/models/user.rb:392` | `blocked_on_view` | 37.25 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 48%, `RAILS/activerecord/lib/arel/visitors/to_sql.rb:790` 3%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 3% | SessionsController#create 94%, UsersController#auth_success 4%, UsersController#create 1% | `blocks.active.detect(&:needs_view?)` |
| 18 | `app/models/node.rb:249` | `save_with_history!` | 30.67 | 0.0 | 0.03 | `GEM/prosopite/lib/prosopite.rb:419` 44%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 6%, `RAILS/activesupport/lib/active_support/callbacks.rb:362` 3% | Api::Changesets::UploadsController#create 71%, Api::NodesController#create 15%, Api::NodesController#update 14% | `clone.save!` |
| 19 | `config/initializers/inline_svg.rb:14` | `transform` | 29.95 | 0.0 | 0.0 | `GEM/nokogiri/lib/nokogiri/xml/node.rb:1431` 10%, `GEM/nokogiri/lib/nokogiri/xml/document.rb:85` 10%, `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations/transformation.rb:23` 7% | SiteController#index 55%, SessionsController#new 19%, SearchesController#show 14% | `with_svg(doc) do \|svg\|` |
| 20 | `app/views/layouts/_header.html.erb:27` |  | 22.78 | 0.0 | 2.48 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 17%, `GEM/i18n/lib/i18n/interpolate/ruby.rb:33` 13%, `GEM/i18n/lib/i18n/backend/fallbacks.rb:60` 9% | SiteController#index 41%, SearchesController#show 10%, SessionsController#new 9% | `<%= link_to t(".edit_with", :editor => t("editor.#{editor}.description` |
| 21 | `app/views/layouts/_search.html.erb:43` |  | 21.42 | 0.0 | 0.85 | `RAILS/actionview/lib/action_view/helpers/form_options_helper.rb:797` 11%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 8%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 7% | SiteController#index 72%, SearchesController#show 18%, ChangesetsController#index 4% | `grouped_options_for_select({ t("site.search.providers.description") =>` |
| 22 | `app/models/node.rb:271` | `save_with_history!` | 18.51 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 34%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 6%, `RAILS/activesupport/lib/active_support/callbacks.rb:362` 3% | Api::Changesets::UploadsController#create 72%, Api::NodesController#create 15%, Api::NodesController#update 13% | `changeset.save!` |
| 23 | `lib/rich_text.rb:111` | `sanitize` | 18.32 | 0.0 | 0.0 | `GEM/sanitize/lib/sanitize.rb:203` 24%, `GEM/sanitize/lib/sanitize/transformers/clean_element.rb:84` 10%, `GEM/sanitize/lib/sanitize.rb:206` 10% | DiaryEntriesController#index 46%, Users::ListsController#show 15%, UserBlocksController#show 7% | `Sanitize.clean(text, Sanitize::Config::OSM).html_safe` |
| 24 | `app/views/diary_entries/_diary_entry.html.erb:28` |  | 17.2 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 33%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 3%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 2% | DiaryEntriesController#index 100% | `<% if diary_entry.visible_comments.count > 0 %>` |
| 25 | `app/models/user.rb:62` |  | 16.55 | 0.0 | 1.28 | `RAILS/activerecord/lib/active_record/relation/query_methods.rb:2117` 10%, `RAILS/activerecord/lib/arel/table.rb:85` 8%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:29` 8% | SiteController#index 62%, UserBlocksController#show 3%, ChangesetsController#index 3% | `has_many :new_messages, -> { where(:to_user_visible => true, :muted =>` |
| 26 | `app/models/node.rb:259` | `save_with_history!` | 15.54 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 55%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 3%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 1% | Api::NodesController#update 62%, Api::Changesets::UploadsController#create 34%, Api::NodesController#create 4% | `tag.save!` |
| 27 | `app/models/old_relation.rb:73` | `save_with_dependencies!` | 15.54 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 52%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 2%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 2% | Api::Changesets::UploadsController#create 41%, Api::RelationsController#create 40%, Api::RelationsController#update 19% | `member.save!` |
| 28 | `app/views/layouts/_search.html.erb:32` |  | 15.22 | 0.0 | 4.23 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 33%, `RAILS/actionview/lib/action_view/helpers/form_tag_helper.rb:1065` 22%, `RAILS/actionview/lib/action_view/helpers/form_tag_helper.rb:502` 11% | SiteController#index 72%, SearchesController#show 18%, ChangesetsController#index 4% | `<%= radio_button_tag "modes", mode, false, { :class => "btn-check", :a` |
| 29 | `app/views/api/changesets/index.xml.builder:5` |  | 15.11 | 0.07 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 29%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 2%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 2% | Api::ChangesetsController#index 100% | `osm << (render(@changesets) \|\| "")` |
| 30 | `app/helpers/issues_helper.rb:48` | `open_issues_count` | 14.92 | 0.0 | 0.05 | `GEM/prosopite/lib/prosopite.rb:419` 52%, `RAILS/activerecord/lib/arel.rb:56` 2%, `RAILS/activerecord/lib/arel/visitors/postgresql.rb:136` 2% | SiteController#index 79%, UserBlocksController#update 4%, UsersController#show 3% | `count = Issue.visible_to(current_user).open.limit(Settings.max_issues_` |

App middleware that hands the request on (the stack below it, not its own work): `config/initializers/policy_headers.rb:13` 253.29, `config/initializers/compressed_requests.rb:37` 114.52 warm objects per request.

479.69 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | RelationMembersController#show | 4 / 4 | 280582.0 / 280574.0 | -8.0 | 76163.5 | `RAILS/actionview/lib/action_view/buffers.rb:44` 1508.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 690.0, `RAILS/actionview/lib/action_view/helpers/url_helper.rb:438` 675.0 | `app/controllers/relation_members_controller.rb:6` 737.0, `config/initializers/policy_headers.rb:13` 509.0, `config/initializers/compressed_requests.rb:37` 108.0 |
| 2 | UserMutesController#destroy | 2 / 2 | 275940.0 / 275907.0 | -33.0 | 140159.0 | `RAILS/actionview/lib/action_view/buffers.rb:44` 1465.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 672.0, `RAILS/actionview/lib/action_view/helpers/url_helper.rb:438` 657.0 | `config/initializers/policy_headers.rb:13` 503.0, `app/controllers/user_mutes_controller.rb:37` 417.0, `app/controllers/application_controller.rb:48` 390.0 |
| 3 | LayersPanesController#show | 2 / 2 | 262367.0 / 262280.0 | -87.0 | 132561.5 | `RAILS/actionview/lib/action_view/buffers.rb:44` 1439.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 660.0, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:11` 645.0 | `config/initializers/policy_headers.rb:13` 446.0, `lib/map_layers.rb:6` 130.0, `config/initializers/compressed_requests.rb:37` 108.0 |
| 4 | Accounts::AuthDeletionsController#create | 4 / 4 | 261826.0 / 261888.0 | 62.0 | 68175.0 | `RAILS/actionview/lib/action_view/buffers.rb:44` 1439.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 660.0, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:11` 645.0 | `config/initializers/policy_headers.rb:13` 475.0, `config/initializers/compressed_requests.rb:37` 96.0, `app/abilities/ability.rb:7` 16.0 |
| 5 | IssuesController#show | 9 / 9 | 113870.0 / 113891.8 | 21.8 | 79371.0 | `RAILS/actionview/lib/action_view/buffers.rb:44` 507.3, `GEM/prosopite/lib/prosopite.rb:419` 344.7, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 303.0 | `app/controllers/issues_controller.rb:68` 572.3, `config/initializers/policy_headers.rb:13` 402.2, `app/controllers/issues_controller.rb:105` 217.7 |
| 6 | IssuesController#ignore | 8 / 8 | 110173.0 / 110133.8 | -39.2 | 84281.9 | `RAILS/actionview/lib/action_view/buffers.rb:44` 507.3, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 247.3, `GEM/prosopite/lib/prosopite.rb:419` 229.7 | `config/initializers/policy_headers.rb:13` 336.3, `app/controllers/issues_controller.rb:85` 267.3, `app/controllers/issues_controller.rb:105` 217.3 |
| 7 | IssuesController#reopen | 8 / 8 | 110046.8 / 109998.5 | -48.3 | 83724.3 | `RAILS/actionview/lib/action_view/buffers.rb:44` 507.3, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 247.3, `GEM/prosopite/lib/prosopite.rb:419` 229.7 | `config/initializers/policy_headers.rb:13` 336.3, `app/controllers/issues_controller.rb:105` 216.3, `app/controllers/issues_controller.rb:95` 189.5 |
| 8 | Issues::ReportersController#index | 12 / 12 | 71969.0 / 141426.5 | 69457.5 | 96627.8 | `RAILS/actionview/lib/action_view/buffers.rb:44` 739.3, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 350.8, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:11` 332.3 | `config/initializers/policy_headers.rb:13` 462.3, `app/controllers/issues/reporters_controller.rb:14` 156.0, `app/controllers/application_controller.rb:48` 131.5 |
| 9 | IssuesController#resolve | 9 / 9 | 94500.3 / 94541.6 | 41.3 | 75176.3 | `RAILS/actionview/lib/action_view/buffers.rb:44` 434.9, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 212.0, `GEM/prosopite/lib/prosopite.rb:419` 196.9 | `config/initializers/policy_headers.rb:13` 341.6, `app/controllers/issues_controller.rb:75` 198.6, `app/controllers/issues_controller.rb:105` 185.1 |
| 10 | OldRelationMembersController#show | 6 / 6 | 9541.0 / 97302.3 | 87761.3 | 51748.8 | `RAILS/actionview/lib/action_view/buffers.rb:44` 502.7, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 297.7, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:11` 227.0 | `config/initializers/policy_headers.rb:13` 385.7, `app/controllers/old_relation_members_controller.rb:7` 260.0, `app/views/layouts/_search.html.erb:18` 190.7 |
| 11 | NotesController#index | 19 / 19 | 26106.1 / 28029.3 | 1923.2 | 22205.7 | `GEM/prosopite/lib/prosopite.rb:419` 335.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 212.6, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 199.9 | `app/controllers/notes_controller.rb:33` 788.4, `app/helpers/application_helper.rb:21` 363.0, `lib/rich_text.rb:45` 344.1 |
| 12 | DiaryEntriesController#index | 30 / 30 | 23957.9 / 24678.4 | 720.5 | 23052.2 | `GEM/prosopite/lib/prosopite.rb:419` 2144.8, `GEM/cancancan/lib/cancan/ability.rb:145` 687.3, `GEM/cancancan/lib/cancan/ability/rules.rb:28` 497.0 | `app/views/diary_entries/_diary_entry.html.erb:28` 3031.0, `app/helpers/user_helper.rb:40` 1781.6, `lib/rich_text.rb:111` 1500.9 |
| 13 | ChangesetsController#show | 34 / 34 | 18442.1 / 18882.9 | 440.9 | 25324.9 | `GEM/prosopite/lib/prosopite.rb:419` 620.4, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 203.3, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 179.4 | `app/views/changesets/_elements.html.erb:6` 396.1, `app/views/changesets/_elements.html.erb:10` 356.2, `app/views/changesets/_elements.html.erb:9` 321.6 |
| 14 | (no action name) | 146 / 146 | 18405.1 / 18421.8 | 16.7 | 18630.7 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 279.4, `GEM/nokogiri/lib/nokogiri/html5/node.rb:66` 277.6, `GEM/nokogiri/lib/nokogiri/xml/document.rb:416` 277.6 | `config/initializers/compressed_requests.rb:37` 290.7, `config/initializers/policy_headers.rb:13` 38.5, `config/initializers/content_security_policy.rb:42` 2.0 |
| 15 | SiteController#edit | 29 / 29 | 18120.8 / 18637.8 | 517.0 | 15198.3 | `GEM/prosopite/lib/prosopite.rb:419` 196.4, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 168.0, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 148.6 | `config/initializers/policy_headers.rb:13` 322.6, `app/models/user.rb:288` 317.1, `app/helpers/user_helper.rb:40` 187.9 |
| 16 | DiaryCommentsController#create | 5 / 5 | 17197.3 / 17052.7 | -144.7 | 16648.8 | `GEM/prosopite/lib/prosopite.rb:419` 1773.7, `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` 532.0, `GEM/mail/lib/mail/utilities.rb:215` 438.0 | `app/controllers/diary_comments_controller.rb:24` 2046.0, `app/mailers/user_mailer.rb:146` 968.0, `app/controllers/diary_comments_controller.rb:21` 621.3 |
| 17 | Api::Changesets::UploadsController#create | 80 / 80 | 15693.9 / 15640.2 | -53.6 | 15224.8 | `GEM/prosopite/lib/prosopite.rb:419` 6072.4, `GEM/prosopite/lib/prosopite.rb:250` 1152.0, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 302.1 | `app/models/old_node.rb:72` 1771.8, `config/initializers/policy_headers.rb:13` 1389.8, `app/models/node.rb:249` 1286.2 |
| 18 | Api::TracesController#create | 6 / 6 | 14518.0 / 15947.3 | 1429.3 | 9647.2 | `GEM/prosopite/lib/prosopite.rb:419` 1549.3, `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` 532.0, `GEM/mail/lib/mail/utilities.rb:215` 348.0 | `app/jobs/trace_importer_job.rb:13` 1925.3, `app/controllers/api/traces_controller.rb:96` 1888.3, `app/mailers/user_mailer.rb:70` 836.0 |
| 19 | Api::RelationsController#update | 14 / 14 | 13866.9 / 16385.1 | 2518.3 | 14187.2 | `GEM/prosopite/lib/prosopite.rb:419` 6883.6, `GEM/prosopite/lib/prosopite.rb:250` 1352.3, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 243.3 | `app/models/old_relation.rb:73` 1767.4, `app/models/relation.rb:341` 1708.1, `config/initializers/policy_headers.rb:13` 1614.4 |
| 20 | FollowsController#create | 4 / 4 | 16231.5 / 12709.0 | -3522.5 | 10837.0 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` 798.0, `GEM/prosopite/lib/prosopite.rb:419` 685.5, `GEM/mail/lib/mail/utilities.rb:215` 653.5 | `app/controllers/follows_controller.rb:31` 2874.0, `app/mailers/user_mailer.rb:162` 1445.5, `app/models/user.rb:349` 623.5 |
| 21 | OldRelationsController#show | 6 / 6 | 13552.0 / 15201.5 | 1649.5 | 9569.7 | `GEM/prosopite/lib/prosopite.rb:419` 1985.0, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 432.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 382.5 | `app/controllers/old_relations_controller.rb:19` 1830.5, `app/views/layouts/_search.html.erb:18` 572.0, `app/views/layouts/_search.html.erb:22` 534.0 |
| 22 | DiaryEntriesController#create | 4 / 4 | 13889.0 / 13904.0 | 15.0 | 11661.8 | `GEM/prosopite/lib/prosopite.rb:419` 845.0, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 638.0, `GEM/i18n/lib/i18n/backend/fallbacks.rb:54` 358.0 | `app/views/diary_entries/_form.html.erb:5` 1489.0, `app/views/application/_richtext_field.html.erb:18` 1230.0, `lib/bootstrap_form/inputs/richtext_field.rb:19` 1152.0 |
| 23 | AccountsController#update | 7 / 7 | 13475.8 / 13461.7 | -14.2 | 11872.6 | `GEM/prosopite/lib/prosopite.rb:419` 2050.8, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 258.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 183.3 | `config/initializers/policy_headers.rb:13` 893.5, `app/controllers/concerns/user_methods.rb:45` 826.5, `config/initializers/mail_delivery_job.rb:9` 700.8 |
| 24 | DiaryEntriesController#new | 8 / 8 | 13077.0 / 13263.0 | 186.0 | 10095.3 | `GEM/prosopite/lib/prosopite.rb:419` 1170.0, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 354.0, `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` 336.0 | `app/controllers/diary_entries_controller.rb:83` 898.3, `app/views/diary_entries/_form.html.erb:5` 775.0, `config/initializers/policy_headers.rb:13` 699.3 |
| 25 | UsersController#show | 34 / 34 | 12224.2 / 12675.3 | 451.1 | 13091.4 | `GEM/prosopite/lib/prosopite.rb:419` 1767.1, `GEM/cancancan/lib/cancan/ability.rb:145` 345.1, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 229.3 | `app/helpers/user_helper.rb:40` 574.6, `config/initializers/policy_headers.rb:13` 431.4, `app/models/user.rb:385` 400.2 |
| 26 | TracesController#create | 5 / 5 | 12198.0 / 12185.5 | -12.5 | 11930.2 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` 882.0, `GEM/prosopite/lib/prosopite.rb:419` 830.5, `RAILS/activesupport/lib/active_support/code_generator.rb:30` 250.5 | `app/controllers/traces_controller.rb:193` 2899.0, `app/models/trace.rb:112` 1764.5, `app/models/trace.rb:105` 770.0 |
| 27 | Oauth2ApplicationsController#new | 2 / 2 | 12314.0 / 11866.0 | -448.0 | 6540.5 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 365.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 311.0, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 310.0 | `app/views/oauth2_applications/_form.html.erb:8` 2510.0, `app/views/application/_settings_menu.html.erb:16` 484.0, `config/initializers/policy_headers.rb:13` 425.0 |
| 28 | TracesController#index | 27 / 27 | 11747.1 / 12133.4 | 386.3 | 11968.9 | `GEM/prosopite/lib/prosopite.rb:419` 584.9, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 360.9, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 329.3 | `app/controllers/concerns/pagination_methods.rb:27` 1646.5, `app/helpers/application_helper.rb:21` 593.2, `app/views/traces/_trace.html.erb:54` 377.1 |
| 29 | Users::ListsController#show | 19 / 19 | 11888.6 / 11892.4 | 3.8 | 13610.8 | `GEM/prosopite/lib/prosopite.rb:419` 1305.6, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 268.1, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 205.9 | `app/helpers/user_helper.rb:40` 2105.0, `lib/rich_text.rb:111` 706.9, `app/controllers/concerns/pagination_methods.rb:27` 532.0 |
| 30 | SiteController#index | 446 / 446 | 11774.2 / 11774.1 | -0.1 | 11919.5 | `GEM/prosopite/lib/prosopite.rb:419` 1044.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 363.2, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 342.9 | `app/models/user.rb:288` 571.3, `app/views/layouts/_search.html.erb:18` 557.6, `app/views/layouts/_search.html.erb:22` 520.6 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/prosopite/lib/prosopite.rb:419` | `subscribe` | 770.99 / 770.99 | 0.0 | 772.76 | 70% | Data, Array |  | `app/models/user.rb:385` 7%, `app/controllers/api_controller.rb:100` 6% | `query_caller = caller_locations` |
| 2 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` | `extract_non_symbol_default!` | 99.13 / 99.13 | 0.0 | 99.24 | 48% | Array, Hash | ruby-i18n/i18n#764 open upstream work | `app/views/layouts/_header.html.erb:27` 5%, `app/views/layouts/_search.html.erb:36` 4% | `defaults = [options[:default]].flatten` |
| 3 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` | `tag_option` | 96.35 / 96.35 | 0.0 | 96.97 | 40% | String |  | `app/views/layouts/_meta.html.erb:6` 12%, `app/views/layouts/_header.html.erb:38` 6% | `%(#{key}="#{value}")` |
| 4 | `GEM/cancancan/lib/cancan/ability.rb:145` | `can` | 82.4 / 82.43 | 0.03 | 82.48 | 92% | Array, Object |  | `app/abilities/ability.rb:13` 3%, `app/abilities/ability.rb:27` 3% | `add_rule(Rule.new(true, action, subject, *attributes_and_conditions, &` |
| 5 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` | `html_safe` | 75.14 / 75.14 | 0.0 | 75.25 | 52% | String |  | `no app frame` 18%, `app/views/layouts/_header.html.erb:38` 7% | `ActiveSupport::SafeBuffer.new(self)` |
| 6 | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:101` † | `helper_names` | 68.77 / 68.64 | -0.13 | 69.89 | 13% | String, Array |  | `config/initializers/policy_headers.rb:13` 99%, `app/controllers/users_controller.rb:111` 1% | `@path_helpers.map(&:to_s) + @url_helpers.map(&:to_s)` |
| 7 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` | `initialize` | 63.33 / 63.33 | 0.0 | 63.43 | 50% | String |  | `no app frame` 12%, `app/views/layouts/_header.html.erb:38` 9% | `super` |
| 8 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:54` | `translate` | 55.23 / 55.23 | 0.0 | 55.29 | 50% | Hash | ruby-i18n/i18n#765 open upstream work | `app/views/layouts/_header.html.erb:27` 4%, `app/helpers/application_helper.rb:12` 4% | `fallback_options = options.merge(:fallback_in_progress => true, fallba` |
| 9 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:60` | `translate` | 53.81 / 53.81 | 0.0 | 53.87 | 48% | String | ruby-i18n/i18n#763 open upstream work | `app/views/layouts/_header.html.erb:27` 5%, `app/helpers/application_helper.rb:12` 4% | `on_fallback(locale, fallback, key, options) if locale.to_s != fallback` |
| 10 | `GEM/cancancan/lib/cancan/rule.rb:137` | `wrap` | 52.32 / 52.34 | 0.02 | 52.37 | 92% | Array |  | `app/abilities/ability.rb:25` 4%, `app/abilities/ability.rb:11` 4% | `[object]` |
| 11 | `RAILS/activemodel/lib/active_model/attribute.rb:9` | `from_database` | 51.92 / 51.97 | 0.05 | 52.22 | 70% | Object |  | `app/controllers/application_controller.rb:48` 19%, `app/controllers/concerns/pagination_methods.rb:27` 12% | `FromDatabase.new(name, value_before_type_cast, type, nil, value)` |
| 12 | `GEM/cancancan/lib/cancan/ability/rules.rb:28` | `add_rule_to_index` | 49.99 / 50.0 | 0.01 | 50.04 | 92% | Array |  | `app/abilities/ability.rb:8` 14%, `app/abilities/ability.rb:7` 14% | `@rules_index[subject] \|\|= []` |
| 13 | `GEM/prosopite/lib/prosopite.rb:250` † | `create_notifications` | 46.25 / 46.12 | -0.13 | 47.2 | 4% | String, Array |  | `config/initializers/policy_headers.rb:13` 100% | `kaller = state[:prosopite_query_caller][location_key].map(&:to_s)` |
| 14 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` | `get_oid_type` | 44.54 / 44.55 | 0.01 | 44.78 | 70% | Array |  | `app/controllers/api_controller.rb:100` 14%, `app/controllers/application_controller.rb:48` 12% | `type_map.fetch(oid, fmod, sql_type) {` |
| 15 | `GEM/cancancan/lib/cancan/ability/rules.rb:24` | `add_rule_to_index` | 41.2 / 41.22 | 0.01 | 41.24 | 92% | Array |  | `app/abilities/ability.rb:24` 3%, `app/abilities/ability.rb:7` 3% | `subjects = rule.subjects.compact` |
| 16 | `GEM/cancancan/lib/cancan/rule.rb:31` † | `initialize` | 41.2 / 41.22 | 0.01 | 41.24 | 92% | Array |  | `app/abilities/ability.rb:29` 3%, `app/abilities/ability.rb:28` 3% | `@actions = wrap(action).map(&:to_sym)` |
| 17 | `GEM/cancancan/lib/cancan/rule.rb:121` | `parse_attributes_from_extra_args` | 41.2 / 41.22 | 0.01 | 41.24 | 92% | Array |  | `app/abilities/ability.rb:27` 3%, `app/abilities/ability.rb:29` 3% | `[attributes, extra_args]` |
| 18 | `GEM/cancancan/lib/cancan/rule.rb:133` | `wrap` | 41.2 / 41.22 | 0.01 | 41.24 | 92% | Array |  | `app/abilities/ability.rb:24` 3%, `app/abilities/ability.rb:19` 3% | `[]` |
| 19 | `GEM/cancancan/lib/cancan/rule.rb:34` | `initialize` | 40.05 / 40.07 | 0.01 | 40.09 | 92% | Hash |  | `app/abilities/ability.rb:7` 3%, `app/abilities/ability.rb:21` 3% | `@conditions = extra_args \|\| {}` |
| 20 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:237` | `tag_options` | 33.76 / 33.76 | 0.0 | 33.97 | 40% | String |  | `app/views/layouts/_meta.html.erb:6` 9%, `app/views/layouts/_header.html.erb:38` 8% | `output = +""` |
| 21 | `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:348` | `validate` | 31.24 / 31.24 | 0.0 | 31.3 | 99% | String, Array |  | `no app frame` 100% | `if source.include?(";") \|\| source != source.gsub(/[[:space:]]/, "")` |
| 22 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | `merge` | 30.34 / 30.33 | -0.01 | 30.42 | 66% | Array, Object |  | `app/models/user.rb:288` 15%, `app/models/user.rb:385` 13% | `WhereClause.new(predicates \| other.predicates)` |
| 23 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:151` † | `now` | 29.21 / 29.21 | 0.0 | 29.25 | 89% | Data, Array |  | `no app frame` 12%, `config/initializers/policy_headers.rb:13` 5% | `Time.now` |
| 24 | `GEM/i18n/lib/i18n/utils.rb:8` | `except` | 29.1 / 29.1 | 0.0 | 29.14 | 50% | Hash |  | `app/views/layouts/_header.html.erb:27` 4%, `app/helpers/application_helper.rb:12` 3% | `hash.except(*keys)` |
| 25 | `GEM/i18n/lib/i18n.rb:396` | `normalize_keys` | 28.6 / 28.6 | 0.0 | 29.06 | 50% | Array |  | `app/views/layouts/_header.html.erb:27` 4%, `app/helpers/application_helper.rb:12` 3% | `[` |
| 26 | `GEM/i18n/lib/i18n/backend/base.rb:58` | `translate` | 27.66 / 27.66 | 0.0 | 27.69 | 50% | Array |  | `app/views/layouts/_header.html.erb:27` 4%, `app/helpers/application_helper.rb:12` 4% | `values = Utils.except(options, *RESERVED_KEYS) unless options.empty?` |
| 27 | `GEM/rails-controller-testing/lib/rails/controller/testing/template_assertions.rb:39` | `setup_subscriptions` | 27.06 / 27.1 | 0.04 | 27.1 | 48% | String, Array |  | `no app frame` 25%, `app/views/layouts/_header.html.erb:9` 6% | `@_partials[virtual_path.split("/").last] += 1` |
| 28 | `RAILS/activerecord/lib/arel/visitors/postgresql.rb:136` | `visit_Arel_Nodes_IsDistinctFrom` | 26.93 / 26.92 | -0.02 | 26.98 | 75% | String |  | `app/controllers/application_controller.rb:48` 11%, `app/models/user.rb:288` 8% | `BIND_BLOCK = proc { \|i\| "$#{i}" }` |
| 29 | `GEM/i18n/lib/i18n/backend/base.rb:49` | `translate` | 26.4 / 26.4 | 0.0 | 26.43 | 50% | String |  | `app/views/layouts/_header.html.erb:27` 5%, `app/helpers/application_helper.rb:12` 4% | `entry = entry.dup if entry.is_a?(String)` |
| 30 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` | `call` | 26.15 / 26.15 | 0.0 | 26.16 | 100% | Data |  | `config/initializers/policy_headers.rb:13` 17%, `no app frame` 15% | `result_lambda = -> { user_callback.call target, value }` |

## Dev/test-mode work

1796.7 of 7293.3 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | error page | `RUBY/error_highlight/base.rb:94` | 829.51 | 1% | `no app frame` 100% | `Prism.parse_file(absolute_path).value.breadth_first_search { \|node\| no` |
| 2 | error page | `GEM/prism/lib/prism/parse_result.rb:162` | 297.39 | 1% | `no app frame` 100% | `source.lines` |
| 3 | asset lookup | `GEM/sprockets/lib/sprockets/path_utils.rb:236` | 63.52 | 19% | `app/views/layouts/_search.html.erb:18` 48%, `app/views/layouts/_search.html.erb:22` 48% | `next unless File.basename(entry).start_with?(basename)` |
| 4 | error page | `RAILS/actionpack/lib/action_dispatch/middleware/exception_wrapper.rb:332` | 51.6 | 1% | `no app frame` 100% | `lines = source_lines.drop(start).take(6)` |
| 5 | error page | `GEM/prism/lib/prism/node.rb:4628` | 36.19 | 1% | `no app frame` 100% | `compact = [] #: Array[Prism::node]` |
| 6 | error page | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:195` | 33.47 | 1% | `no app frame` 100% | `add_filter { \|line\| line.sub(gems_regexp, gems_result) }` |
| 7 | error page | `GEM/prism/lib/prism/node.rb:30908` | 24.71 | 1% | `no app frame` 100% | `[*body]` |
| 8 | asset lookup | `GEM/sprockets-rails/lib/sprockets/rails/helper.rb:81` | 19.22 | 33% | `app/views/layouts/_meta.html.erb:6` 31%, `app/views/layouts/_meta.html.erb:11` 3% | `File.join(assets_prefix \|\| "/", legacy_debug_path(asset_path, debug))` |
| 9 | error page | `GEM/prism/lib/prism/node.rb:1312` | 16.79 | 1% | `no app frame` 100% | `[*arguments]` |
| 10 | template compile | `GEM/erubi/lib/erubi.rb:134` | 16.23 | 11% | `config/initializers/policy_headers.rb:13` 33%, `no app frame` 20% | `input.scan(regexp) do \|indicator, code, tailch, rspace\|` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activerecord | 915.3 | 933.9 | `postgresql_adapter.rb:880` 44.5, `where_clause.rb:29` 30.3, `postgresql.rb:136` 26.9 |
| ruby stdlib | 867.1 | 1204.3 | `base.rb:94` 829.5, `formatter.rb:174` 7.2, `ipaddr.rb:725` 3.4 |
| gem: prosopite | 856.0 | 859.1 | `prosopite.rb:419` 771.0, `prosopite.rb:250` 46.2, `prosopite.rb:418` 11.3 |
| rails: actionview | 690.1 | 704.2 | `tag_helper.rb:318` 96.3, `tag_helper.rb:237` 33.8, `translation_helper.rb:91` 23.5 |
| rails: activesupport | 654.5 | 687.0 | `output_safety.rb:242` 75.1, `output_safety.rb:71` 63.3, `backtrace_cleaner.rb:195` 33.5 |
| rails: actionpack | 613.5 | 707.7 | `route_set.rb:101` 68.7, `exception_wrapper.rb:332` 51.6, `content_security_policy.rb:348` 31.2 |
| ruby default gem: prism | 498.8 | 717.7 | `parse_result.rb:162` 297.4, `node.rb:4628` 36.2, `node.rb:30908` 24.7 |
| gem: cancancan | 483.1 | 483.7 | `ability.rb:145` 82.4, `rule.rb:137` 52.3, `rules.rb:28` 50.0 |
| app | 398.0 | 430.3 | `migrate.rb:8` 37.6, `_meta.html.erb:6` 26.5, `_header.html.erb:38` 22.1 |
| gem: i18n | 369.6 | 379.1 | `fallbacks.rb:98` 99.1, `fallbacks.rb:54` 55.2, `fallbacks.rb:60` 53.8 |
| gem: inline_svg | 188.4 | 190.4 | `transformations.rb:54` 14.6, `transformations.rb:11` 8.5, `transformations.rb:5` 8.5 |
| gem: sprockets | 183.6 | 186.8 | `path_utils.rb:236` 63.5, `resolve.rb:218` 9.7, `resolve.rb:292` 7.3 |
| gem: nokogiri | 170.1 | 171.2 | `node.rb:1431` 17.7, `node.rb:66` 11.2, `document.rb:85` 9.8 |
| rails: activemodel | 143.5 | 151.8 | `attribute.rb:9` 51.9, `attribute_methods.rb:492` 12.9, `builder.rb:37` 10.2 |
| gem: omniauth | 93.2 | 93.7 | `paths.rb:67` 25.0, `strategy.rb:285` 11.9, `paths.rb:94` 11.9 |
| gem: rack | 66.9 | 68.9 | `request.rb:607` 12.9, `utils.rb:693` 11.7, `body_proxy.rb:12` 4.0 |
| gem: sprockets-rails | 44.7 | 50.2 | `helper.rb:81` 19.2, `route_wrapper.rb:5` 7.8, `helper.rb:186` 2.5 |
| ruby default gem: uri | 39.7 | 40.1 | `rfc2396_parser.rb:320` 11.2, `common.rb:465` 8.2, `rfc2396_parser.rb:291` 7.3 |
| gem: mail | 38.9 | 55.2 | `utilities.rb:215` 5.8, `8bit.rb:14` 3.2, `field_list.rb:71` 2.9 |
| gem: hashie | 38.9 | 39.7 | `mash.rb:641` 15.1, `mash.rb:596` 15.1, `mash.rb:329` 3.6 |
| gem: rails-controller-testing | 34.9 | 35.0 | `template_assertions.rb:39` 27.1, `template_assertions.rb:35` 6.7, `template_assertions.rb:27` 0.7 |
| gem: builder | 33.3 | 34.8 | `xchar.rb:155` 7.2, `xchar.rb:156` 3.9, `xchar.rb:154` 3.8 |
| gem: aasm | 29.4 | 29.9 | `state_machine_store.rb:29` 4.9, `state_machine_store.rb:73` 2.1, `state_machine.rb:11` 2.1 |
| gem: erubi | 28.1 | 31.0 | `erubi.rb:134` 16.2, `erubi.rb:137` 3.5, `erubi.rb:139` 2.1 |
| gem: concurrent-ruby | 25.2 | 25.4 | `safe_initialization.rb:30` 6.0, `non_concurrent_map_backend.rb:131` 3.7, `mutex_lockable_object.rb:32` 2.0 |
| gem: sanitize | 23.0 | 23.3 | `sanitize.rb:203` 6.7, `clean_element.rb:84` 3.3, `sanitize.rb:206` 2.9 |
| gem: loofah | 17.9 | 17.9 | `concerns.rb:172` 6.5, `concerns.rb:43` 4.9, `scrubber.rb:132` 3.3 |
| gem: kramdown | 15.6 | 15.9 | `kramdown.rb:136` 1.5, `kramdown.rb:135` 1.3, `utils.rb:27` 0.8 |
| gem: rack-session | 14.8 | 14.9 | `id.rb:43` 6.5, `id.rb:31` 4.1, `id.rb:275` 1.0 |
| gem: tzinfo | 14.0 | 14.1 | `timestamp.rb:208` 4.4, `timestamp.rb:193` 3.0, `constant_offset_data_timezone_info.rb:52` 2.8 |
| gem: rails-html-sanitizer | 11.4 | 11.4 | `sanitizer.rb:192` 1.6, `sanitizer.rb:33` 1.6, `sanitizer.rb:56` 1.6 |
| gem: http_accept_language | 11.3 | 11.3 | `parser.rb:19` 3.5, `middleware.rb:8` 3.0, `middleware.rb:10` 2.0 |
| gem: addressable | 8.9 | 10.1 | `uri.rb:438` 1.0, `uri.rb:424` 0.8, `uri.rb:486` 0.6 |
| gem: bootstrap_form | 7.8 | 8.4 | `hints.rb:65` 0.8, `bootstrap.rb:102` 0.5, `hints.rb:52` 0.4 |
| gem: doorkeeper | 7.7 | 9.7 | `scopes.rb:14` 2.4, `token.rb:150` 1.4, `token.rb:154` 0.7 |
| rails: railties | 6.0 | 6.1 | `engine.rb:748` 1.0, `logger.rb:24` 1.0, `logger.rb:65` 1.0 |
| gem: rack-cors | 5.9 | 5.9 | `cors.rb:123` 3.3, `result.rb:38` 1.0, `cors.rb:129` 1.0 |
| gem: quad_tile | 5.6 | 7.7 | `quad_tile.rb:13` 4.5, `quad_tile.rb:17` 1.0, `quad_tile.rb:19` 0.1 |
| test harness: webmock | 4.3 | 4.9 | `headers.rb:69` 0.5, `headers.rb:68` 0.4, `uri.rb:62` 0.2 |
| gem: turbo-rails | 3.8 | 3.9 | `request_id_tracking.rb:10` 1.0, `frame_request.rb:36` 0.8, `drive_helper.rb:78` 0.7 |
| gem: argon2 | 3.0 | 3.1 | `hash_format.rb:46` 0.9, `hash_format.rb:17` 0.8, `hash_format.rb:21` 0.2 |
| gem: rack-uri_sanitizer | 3.0 | 3.0 | `uri_sanitizer.rb:10` 3.0 |
| gem: canonical-rails | 3.0 | 3.0 | `tag_helper.rb:4` 0.7, `tag_helper.rb:23` 0.5, `tag_helper.rb:21` 0.4 |
| rails: activestorage | 2.9 | 3.5 | `model.rb:128` 0.6, `one.rb:34` 0.5, `model.rb:284` 0.3 |
| ruby default gem: securerandom | 2.2 | 2.2 | `securerandom.rb:71` 2.2 |
| gem: bootsnap | 2.0 | 2.5 | `kernel_require.rb:11` 1.0, `cache.rb:218` 0.3, `loaded_features_index.rb:118` 0.2 |
| gem: rgeo | 1.8 | 3.3 | `entities.rb:184` 0.5, `entities.rb:187` 0.4, `entities.rb:197` 0.2 |
| gem: rexml | 1.6 | 2.3 | `source.rb:293` 0.1, `source.rb:269` 0.1, `element.rb:2429` 0.1 |
| gem: config | 1.5 | 1.5 | `options.rb:156` 1.4, `options.rb:125` 0.1, `options.rb:123` 0.0 |
| ruby default gem: timeout | 1.3 | 1.3 | `timeout.rb:152` 0.3, `timeout.rb:35` 0.3, `timeout.rb:293` 0.3 |
| gem: rails_param | 1.2 | 1.4 | `validator.rb:51` 0.4, `param_evaluator.rb:11` 0.2, `param.rb:3` 0.2 |
| gem: json | 1.0 | 1.1 | `common.rb:860` 0.8, `common.rb:297` 0.2, `common.rb:377` 0.0 |
| gem: faraday | 1.0 | 1.3 | `nested_params_encoder.rb:108` 0.2, `nested_params_encoder.rb:94` 0.1, `utils.rb:39` 0.1 |
| gem: validates_email_format_of | 0.9 | 1.0 | `validates_email_format_of.rb:256` 0.3, `validates_email_format_of.rb:193` 0.3, `validates_email_format_of.rb:146` 0.1 |
| gem: globalid | 0.9 | 1.1 | `gid.rb:159` 0.2, `gid.rb:95` 0.2, `gid.rb:166` 0.1 |
| rails: activejob | 0.8 | 1.0 | `arguments.rb:141` 0.1, `core.rb:129` 0.1, `arguments.rb:61` 0.1 |
| gem: libxml-ruby | 0.8 | 0.8 | `node.rb:75` 0.2, `node.rb:58` 0.1, `node.rb:61` 0.1 |
| gem: simpleidn | 0.7 | 0.8 | `simpleidn.rb:224` 0.3, `simpleidn.rb:222` 0.1, `simpleidn.rb:235` 0.1 |
| rails: actionmailer | 0.5 | 1.0 | `mail_helper.rb:69` 0.1, `mail_helper.rb:68` 0.1, `base.rb:1009` 0.0 |
| gem: pg | 0.4 | 0.9 | `connection.rb:350` 0.3, `connection.rb:351` 0.1, `connection.rb:844` 0.0 |
| gem: jbuilder | 0.4 | 0.5 | `jbuilder.rb:354` 0.1, `collection_renderer.rb:21` 0.1, `jbuilder_template.rb:150` 0.0 |
| ruby default gem: net-http | 0.3 | 0.4 | `header.rb:203` 0.0, `header.rb:225` 0.0, `header.rb:275` 0.0 |
| gem: bigdecimal | 0.3 | 0.3 | `util.rb:24` 0.2, `util.rb:51` 0.0 |
| gem: noticed | 0.2 | 0.6 | `deliver_by.rb:12` 0.1, `notification_methods.rb:11` 0.0, `deliverable.rb:70` 0.0 |
| gem: openstreetmap-deadlock_retry | 0.2 | 0.2 | `deadlock_retry.rb:21` 0.2, `deadlock_retry.rb:62` 0.0 |
| ruby default gem: erb | 0.2 | 0.2 | `util.rb:65` 0.2 |
| ruby default gem: prettyprint | 0.2 | 0.2 | `prettyprint.rb:404` 0.0, `prettyprint.rb:264` 0.0, `prettyprint.rb:459` 0.0 |
| gem: unicode-display_width | 0.1 | 0.1 | `display_width.rb:220` 0.0, `display_width.rb:60` 0.0, `display_width.rb:218` 0.0 |
| gem: htmlentities | 0.1 | 0.1 | `decoder.rb:10` 0.0, `decoder.rb:25` 0.0, `decoder.rb:33` 0.0 |
| ruby default gem: pp | 0.1 | 0.1 | `pp.rb:542` 0.0, `pp.rb:550` 0.0, `pp.rb:271` 0.0 |
| gem: faraday-net_http | 0.1 | 0.1 | `net_http.rb:95` 0.0, `net_http.rb:211` 0.0, `net_http.rb:137` 0.0 |
| gem: zeitwerk | 0.1 | 0.1 | `cref.rb:36` 0.0, `cref.rb:47` 0.0, `file_system.rb:203` 0.0 |
| gem: marcel | 0.1 | 0.3 | `mime_type.rb:90` 0.0, `magic.rb:18` 0.0, `magic.rb:75` 0.0 |
| gem: logger | 0.0 | 0.1 | `log_device.rb:165` 0.0, `log_device.rb:33` 0.0, `logger.rb:692` 0.0 |
| gem: base64 | 0.0 | 0.1 | `base64.rb:283` 0.0, `base64.rb:310` 0.0, `base64.rb:377` 0.0 |
| gem: active_record_union | 0.0 | 0.1 | `union.rb:15` 0.0, `union.rb:36` 0.0, `union.rb:55` 0.0 |
| gem: omniauth-rails_csrf_protection | 0.0 | 0.0 | `token_verifier.rb:59` 0.0, `token_verifier.rb:55` 0.0 |
| ruby default gem: open3 | 0.0 | 0.1 | `open3.rb:527` 0.0, `open3.rb:790` 0.0, `open3.rb:528` 0.0 |
| gem: cgi | 0.0 | 0.1 | `core.rb:575` 0.0, `core.rb:574` 0.0, `core.rb:579` 0.0 |
| gem: activerecord-postgis | 0.0 | 0.1 | `spatial.rb:76` 0.0, `spatial.rb:39` 0.0, `spatial.rb:64` 0.0 |
| gem: mini_mime | 0.0 | 0.2 | `mini_mime.rb:54` 0.0, `mini_mime.rb:56` 0.0, `mini_mime.rb:174` 0.0 |
| ruby default gem: digest | 0.0 | 0.0 | `digest.rb:83` 0.0, `digest.rb:64` 0.0, `digest.rb:56` 0.0 |
| gem: doorkeeper-openid_connect | 0.0 | 0.3 | `controller.rb:78` 0.0, `openid_connect.rb:145` 0.0, `prompt.rb:73` 0.0 |
| gem: racc | 0.0 | 0.0 | `parser.rb:263` 0.0 |
| gem: jwt | 0.0 | 0.0 | `rsa.rb:122` 0.0, `thumbprint.rb:17` 0.0, `rsa.rb:94` 0.0 |
| gem: lowrail-profile | 0.0 | 0.0 | `profile.rb:95` 0.0, `profile.rb:73` 0.0, `profile.rb:83` 0.0 |
| gem: active_storage_validations | 0.0 | 0.1 | `form_builder.rb:23` 0.0, `form_builder.rb:27` 0.0, `form_builder.rb:40` 0.0 |
| gem: rgeo-activerecord | 0.0 | 0.0 | `spatial_factory_store.rb:47` 0.0, `spatial_factory_store.rb:12` 0.0 |
| gem: omniauth-facebook | 0.0 | 0.0 | `facebook.rb:88` 0.0, `facebook.rb:84` 0.0 |
| gem: omniauth-microsoft_graph | 0.0 | 0.0 | `microsoft_graph.rb:73` 0.0 |
| gem: ffi | 0.0 | 0.3 | `pointer.rb:60` 0.0, `autopointer.rb:88` 0.0, `managedstruct.rb:80` 0.0 |
| gem: omniauth-apple | 0.0 | 0.0 | `apple.rb:63` 0.0 |
| gem: omniauth-google-oauth2 | 0.0 | 0.0 | `google_oauth2.rb:219` 0.0, `google_oauth2.rb:103` 0.0, `google_oauth2.rb:373` 0.0 |
| gem: omniauth-github | 0.0 | 0.0 | `github.rb:78` 0.0 |
| gem: ffi-libarchive | 0.0 | 0.1 | `archive.rb:340` 0.0, `reader.rb:14` 0.0, `reader.rb:81` 0.0 |
| gem: matrix | 0.0 | 0.1 | `matrix.rb:147` 0.0, `matrix.rb:151` 0.0, `matrix.rb:146` 0.0 |
| gem: gd2-ffij | 0.0 | 0.3 | `animated_gif.rb:30` 0.0, `color.rb:39` 0.0, `canvas.rb:76` 0.0 |
| gem: activerecord-import | 0.0 | 0.0 | `import.rb:705` 0.0, `import.rb:724` 0.0, `import.rb:727` 0.0 |
| gem: auth-sanitizer | 0.0 | 0.0 | `filtered_attributes.rb:34` 0.0, `thing_filter.rb:21` 0.0, `thing_filter.rb:23` 0.0 |
| gem: omniauth-oauth2 | 0.0 | 0.0 | `oauth2.rb:63` 0.0, `oauth2.rb:47` 0.0, `oauth2.rb:136` 0.0 |
| gem: oauth2 | 0.0 | 0.0 | `auth_code.rb:22` 0.0, `client.rb:51` 0.0, `client.rb:107` 0.0 |
| gem: snaky_hash | 0.0 | 0.0 | `snake.rb:113` 0.0, `snake.rb:110` 0.0, `snake.rb:115` 0.0 |
| gem: sentry-rails | 0.0 | 0.0 | `active_job.rb:32` 0.0 |
| gem: image_processing | 0.0 | 0.0 | `vips.rb:229` 0.0, `vips.rb:241` 0.0, `chainable.rb:6` 0.0 |
| gem: ruby-vips | 0.0 | 0.2 | `operation.rb:72` 0.0, `operation.rb:499` 0.0, `object.rb:203` 0.0 |
| rails: actiontext | 0.0 | 0.3 | `serialization.rb:6` 0.0, `content.rb:0` 0.0, `content.rb:24` 0.0 |
| gem: msgpack | 0.0 | 0.0 | `factory.rb:16` 0.0, `factory.rb:41` 0.0, `factory.rb:9` 0.0 |
| gem: teaspoon | 0.0 | 0.1 | `engine.rb:65` 0.0 |
| gem: actionpack-page_caching | 0.0 | 0.0 | `pages.rb:55` 0.0, `pages.rb:61` 0.0, `pages.rb:56` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Jobs

| # | Job | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | TraceImporterJob#perform | 7 / 7 | 27336.0 / – |  | 18325.9 |  |  |
| 2 | Noticed::EventJob#perform | 16 / 16 | 10120.0 / 9723.4 | -396.6 | 11196.7 | `GEM/mail/lib/mail/utilities.rb:215` 669.0, `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` 653.3, `GEM/mail/lib/mail/encodings/8bit.rb:14` 403.6 | `app/mailers/user_mailer.rb:237` 322.6, `app/mailers/user_mailer.rb:200` 321.9, `app/mailers/user_mailer.rb:114` 321.8 |
| 3 | TraceLinestringJob#perform | 16 / 16 | 336.3 / 336.3 | 0.0 | 572.2 | `GEM/prosopite/lib/prosopite.rb:419` 94.1, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 8.0, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:151` 8.0 | `app/jobs/trace_linestring_job.rb:93` 152.3, `app/jobs/trace_linestring_job.rb:95` 109.1, `app/jobs/trace_linestring_job.rb:92` 25.0 |
| 4 | ActionMailer::MailDeliveryJob#perform | 2 / 2 | – / – |  | 6276.0 |  |  |
| 5 | TraceDestroyerJob#perform | 1 / 1 | – / – |  | 381.0 |  |  |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/prosopite/lib/prosopite.rb:419` | 372.81 / 366.14 | 95% | `no app frame` 51%, `app/jobs/trace_linestring_job.rb:95` 9% | `query_caller = caller_locations` |
| 2 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` † | 216.0 / 254.0 | 43% | `no app frame` 79%, `app/jobs/trace_importer_job.rb:34` 8% | `@method_name % attr_name` |
| 3 | `GEM/mail/lib/mail/utilities.rb:215` | 218.62 / 180.26 | 36% | `no app frame` 55%, `app/mailers/user_mailer.rb:95` 11% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 4 | `GEM/mail/lib/mail/encodings/8bit.rb:14` | 142.29 / 110.48 | 33% | `no app frame` 95%, `config/initializers/mail_delivery_job.rb:9` 5% | `!str.lines.find { \|line\| line.bytesize > 998 }` |
| 5 | `GEM/mail/lib/mail/field_list.rb:71` † | 109.12 / 90.26 | 36% | `no app frame` 56%, `app/mailers/user_mailer.rb:95` 11% | `fields = select { \|f\| f.responsible_for? field_name }` |
| 6 | `GEM/mail/lib/mail/fields/parameter_hash.rb:22` | 98.81 / 85.05 | 36% | `no app frame` 48%, `app/mailers/user_mailer.rb:95` 15% | `if k =~ /^#{key_pattern}(\*\|$)/i` |
| 7 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:333` | 52.17 / 61.33 | 43% | `no app frame` 79%, `app/jobs/trace_importer_job.rb:34` 8% | `generate_method = "define_method_#{pattern.proxy_target}"` |
| 8 | `RAILS/activesupport/lib/active_support/code_generator.rb:35` | 52.17 / 61.33 | 43% | `no app frame` 79%, `app/jobs/trace_importer_job.rb:34` 8% | `owner.define_method(as, @cache.instance_method(canonical_name))` |
| 9 | `RAILS/activerecord/lib/active_record/attribute_methods.rb:176` | 52.17 / 61.33 | 43% | `no app frame` 73%, `app/jobs/trace_importer_job.rb:34` 10% | `! superclass.instance_method(method_name).owner.is_a?(GeneratedAttribu` |
| 10 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` | 54.19 / 52.0 | 74% | `no app frame` 32%, `app/notifiers/gpx_import_failure_notifier.rb:7` 8% | `type_map.fetch(oid, fmod, sql_type) {` |

### Mails

| # | Mailer action | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | UserMailer#gpx_success | 3 / 3 | 3736.0 / – |  | 4338.3 |  |  |
| 2 | UserMailer#message_notification | 4 / 4 | – / – |  | 8137.8 |  |  |
| 3 | UserMailer#changeset_comment_notification | 1 / 1 | – / – |  | 7837.0 |  |  |
| 4 | UserMailer#diary_comment_notification | 1 / 1 | – / – |  | 5974.0 |  |  |
| 5 | UserMailer#note_comment_notification | 1 / 1 | – / – |  | 5721.0 |  |  |
| 6 | UserMailer#follow_notification | 1 / 1 | – / – |  | 5683.0 |  |  |
| 7 | UserMailer#gpx_failure | 1 / 1 | – / – |  | 4226.0 |  |  |
| 8 | UserMailer#signup_confirm | 1 / 1 | – / – |  | 3738.0 |  |  |
| 9 | UserMailer#email_confirm | 1 / 1 | – / – |  | 3730.0 |  |  |
| 10 | UserMailer#lost_password | 1 / 1 | – / – |  | 3647.0 |  |  |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/mail/lib/mail/utilities.rb:215` | 246.93 / 235.53 | 100% | `app/mailers/user_mailer.rb:114` 24%, `app/mailers/user_mailer.rb:70` 15% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 2 | `GEM/mail/lib/mail/fields/parameter_hash.rb:22` | 131.6 / 129.87 | 100% | `app/mailers/user_mailer.rb:114` 22%, `app/mailers/user_mailer.rb:70` 17% | `if k =~ /^#{key_pattern}(\*\|$)/i` |
| 3 | `GEM/mail/lib/mail/field_list.rb:71` † | 121.87 / 116.27 | 100% | `app/mailers/user_mailer.rb:114` 24%, `app/mailers/user_mailer.rb:70` 15% | `fields = select { \|f\| f.responsible_for? field_name }` |
| 4 | `GEM/mail/lib/mail/parsers/content_type_parser.rb:734` | 95.13 / 93.07 | 100% | `app/mailers/user_mailer.rb:114` 20%, `app/mailers/user_mailer.rb:248` 16% | `_wide = data[p].ord` |
| 5 | `GEM/mail/lib/mail/fields/parameter_hash.rb:56` | 63.67 / 59.33 | 100% | `app/mailers/user_mailer.rb:114` 24%, `app/mailers/user_mailer.rb:70` 13% | `map.sort_by { \|a\| a.first.to_s }.map! do \|key_name, value\|` |
| 6 | `GEM/erubi/lib/erubi.rb:134` (template compile) | 58.93 / 56.33 | 73% | `app/views/user_mailer/gpx_success.text.erb:5` 16%, `app/mailers/user_mailer.rb:237` 16% | `input.scan(regexp) do \|indicator, code, tailch, rspace\|` |
| 7 | `GEM/mail/lib/mail/utilities.rb:291` | 52.8 / 51.07 | 100% | `app/mailers/user_mailer.rb:248` 22%, `app/mailers/user_mailer.rb:114` 16% | `value !~ /\S/` |
| 8 | `GEM/mail/lib/mail/message.rb:2130` | 50.93 / 47.47 | 100% | `app/mailers/user_mailer.rb:114` 24%, `app/mailers/user_mailer.rb:70` 13% | `content_loc_name  = header[:content_location].location rescue nil` |
| 9 | `GEM/mail/lib/mail/utilities.rb:226` | 48.07 / 45.2 | 100% | `app/mailers/user_mailer.rb:114` 23%, `app/mailers/user_mailer.rb:70` 13% | `str.to_s.downcase.tr(Constants::HYPHEN, Constants::UNDERSCORE)` |
| 10 | `GEM/mail/lib/mail/parsers/address_lists_parser.rb:32009` | 45.33 / 45.33 | 100% | `app/mailers/user_mailer.rb:114` 27%, `app/mailers/user_mailer.rb:70` 20% | `_wide = data[p].ord` |
