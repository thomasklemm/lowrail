# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails test -v`
* Ruby: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +YJIT +PRISM [x86_64-linux]
* Rails: 8.1.4.1, test environment
* Counted in run 1: 4230 requests, 42 jobs, 15 mail windows; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 4230 | 9476.6 | 42 | 15 | 0 | 0 |
| run2 | 1 | 4230 | 9476.7 | 42 | 15 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.01 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/models/user.rb:385` | `role?` | 107.28 | 0.0 | 1.24 | `GEM/prosopite/lib/prosopite.rb:419` 46%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 4%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 2% | SiteController#index 28%, SessionsController#create 5%, Api::Changesets::UploadsController#create 5% | `roles.any? { \|r\| r.role == role }` |
| 2 | `app/helpers/user_helper.rb:40` | `user_image_tag` | 96.55 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 46%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 3%, `RAILS/activerecord/lib/arel/visitors/postgresql.rb:136` 2% | SiteController#index 49%, Users::ListsController#show 14%, DiaryEntriesController#index 11% | `elsif user.avatar.attached?` |
| 3 | `app/models/user.rb:288` | `preferred_color_scheme` | 95.41 | 0.0 | 2.69 | `GEM/prosopite/lib/prosopite.rb:419` 27%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `RAILS/activerecord/lib/arel/visitors/postgresql.rb:136` 2% | SiteController#index 63%, UserBlocksController#show 4%, ChangesetsController#index 3% | `color_preferences = preferences.color_schemes.where.not(:v => "auto").` |
| 4 | `app/views/layouts/_search.html.erb:18` |  | 86.41 | 72.64 | 0.3 | `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:54` 6%, `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:4` 5%, `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:13` 5% | SiteController#index 68%, SearchesController#show 18%, ChangesetsController#index 4% | `<%= inline_svg_tag "magnifying_glass.svg" %>` |
| 5 | `app/controllers/application_controller.rb:48` | `authorize_web` | 81.62 | 0.0 | 0.82 | `GEM/prosopite/lib/prosopite.rb:419` 30%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 11%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 6% | SiteController#index 48%, SessionsController#create 9%, UserBlocksController#show 3% | `self.current_user = User.find_by(:id => session[:user], :status => %w[` |
| 6 | `app/views/layouts/_search.html.erb:22` |  | 80.67 | 72.58 | 0.91 | `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:54` 7%, `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:14` 3%, `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:13` 3% | SiteController#index 68%, SearchesController#show 18%, ChangesetsController#index 4% | `<%= inline_svg_tag "directions.svg", :class => "align-bottom" %>` |
| 7 | `app/controllers/api_controller.rb:100` | `setup_user_auth` | 79.67 | 0.0 | 0.16 | `GEM/prosopite/lib/prosopite.rb:419` 55%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 8%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 7% | Api::Changesets::UploadsController#create 12%, Api::ChangesetCommentsController#create 8%, Api::NodesController#update 7% | `self.current_user = User.find(doorkeeper_token.resource_owner_id) if d` |
| 8 | `app/views/layouts/_header.html.erb:53` |  | 66.42 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 46%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 3%, `RAILS/activerecord/lib/arel/visitors/postgresql.rb:136` 2% | SiteController#index 67%, UserBlocksController#show 4%, ChangesetsController#index 3% | `<% if current_user.new_messages.size > 0 %>` |
| 9 | `app/views/application/_auth_button.html.erb:7` |  | 64.62 | 23.45 | 0.32 | `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:54` 4%, `GEM/nokogiri/lib/nokogiri/xml/document.rb:85` 4%, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1431` 4% | SessionsController#new 90%, UsersController#create 8%, UsersController#new 2% | `<%= inline_svg_tag "auth_providers/#{provider}.svg",` |
| 10 | `app/views/layouts/_header.html.erb:38` |  | 59.17 | 0.0 | 21.01 | `RAILS/actionview/lib/action_view/helpers/output_safety_helper.rb:36` 13%, `GEM/uri/lib/uri/rfc2396_parser.rb:320` 12%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:590` 10% | SiteController#index 35%, SearchesController#show 9%, SessionsController#new 8% | `<%= link_to label, path, :class => ["nav-link", "px-1", "py-2", "py-md` |
| 11 | `app/controllers/api_controller.rb:106` | `setup_user_auth` | 53.49 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 48%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 3%, `RAILS/activerecord/lib/arel/visitors/to_sql.rb:790` 3% | Api::Changesets::UploadsController#create 11%, Api::ChangesetCommentsController#create 8%, Api::NodesController#update 7% | `user_block = current_user.blocks.active.take` |
| 12 | `app/controllers/api_controller.rb:146` | `api_call_timeout` | 50.94 | 1.49 | 0.0 | `GEM/cancancan/lib/cancan/ability.rb:80` 6%, `RAILS/actionview/lib/action_view/template_path.rb:23` 5%, `GEM/cancancan/lib/cancan/ability.rb:77` 5% | Api::ChangesetsController#index 8%, Api::Messages::InboxesController#show 5%, Api::ChangesetsController#show 4% | `Timeout.timeout(Settings.api_timeout, &)` |
| 13 | `app/controllers/concerns/pagination_methods.rb:27` | `get_page_items` | 46.41 | 0.0 | 0.09 | `GEM/prosopite/lib/prosopite.rb:419` 23%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 14%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 6% | ChangesetsController#index 23%, TracesController#index 22%, DiaryEntriesController#index 15% | `page_items = page_items.sort_by(&cursor_column).reverse` |
| 14 | `app/views/layouts/_meta.html.erb:6` |  | 44.5 | 5.75 | 25.03 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 25%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:493` 6%, `RAILS/actionview/lib/action_view/helpers/asset_tag_helper.rb:321` 6% | SiteController#index 33%, SearchesController#show 9%, SessionsController#new 8% | `<%= favicon_link_tag "apple-touch-icon-#{size}x#{size}.png", :rel => "` |
| 15 | `app/models/old_node.rb:72` | `save_with_dependencies!` | 44.35 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 48%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 4%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 2% | Api::Changesets::UploadsController#create 70%, Api::NodesController#create 16%, Api::NodesController#update 12% | `save!` |
| 16 | `app/models/user.rb:173` | `lookup` | 43.15 | 0.0 | 0.12 | `GEM/prosopite/lib/prosopite.rb:419` 41%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 9%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 9% | SessionsController#create 100% | `user = find_by("email = ? OR display_name = ?", username, username)` |
| 17 | `app/models/user.rb:392` | `blocked_on_view` | 37.44 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 48%, `RAILS/activerecord/lib/arel/visitors/to_sql.rb:790` 3%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 3% | SessionsController#create 94%, UsersController#auth_success 4%, UsersController#create 1% | `blocks.active.detect(&:needs_view?)` |
| 18 | `app/models/node.rb:249` | `save_with_history!` | 32.74 | 0.0 | 0.03 | `GEM/prosopite/lib/prosopite.rb:419` 44%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 6%, `RAILS/activesupport/lib/active_support/callbacks.rb:362` 3% | Api::Changesets::UploadsController#create 69%, Api::NodesController#create 16%, Api::NodesController#update 13% | `clone.save!` |
| 19 | `config/initializers/inline_svg.rb:14` | `transform` | 32.64 | 0.0 | 0.0 | `GEM/nokogiri/lib/nokogiri/xml/document.rb:85` 10%, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1431` 10%, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1254` 7% | SiteController#index 52%, SessionsController#new 18%, SearchesController#show 13% | `with_svg(doc) do \|svg\|` |
| 20 | `app/views/layouts/_header.html.erb:27` |  | 26.34 | 0.0 | 2.86 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 17%, `GEM/i18n/lib/i18n/interpolate/ruby.rb:33` 13%, `GEM/i18n/lib/i18n/backend/fallbacks.rb:60` 9% | SiteController#index 36%, SearchesController#show 9%, SessionsController#new 8% | `<%= link_to t(".edit_with", :editor => t("editor.#{editor}.description` |
| 21 | `lib/rich_text.rb:111` | `sanitize` | 23.78 | 0.0 | 0.0 | `GEM/sanitize/lib/sanitize.rb:203` 23%, `GEM/sanitize/lib/sanitize/transformers/clean_element.rb:84` 10%, `GEM/sanitize/lib/sanitize.rb:206` 10% | DiaryEntriesController#index 41%, Users::ListsController#show 18%, UserBlocksController#show 7% | `Sanitize.clean(text, Sanitize::Config::OSM).html_safe` |
| 22 | `app/views/layouts/_search.html.erb:43` |  | 22.96 | 0.0 | 0.91 | `RAILS/actionview/lib/action_view/helpers/form_options_helper.rb:797` 11%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 8%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 7% | SiteController#index 68%, SearchesController#show 18%, ChangesetsController#index 4% | `grouped_options_for_select({ t("site.search.providers.description") =>` |
| 23 | `app/views/diary_entries/_diary_entry.html.erb:28` |  | 20.06 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 34%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 3%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 2% | DiaryEntriesController#index 100% | `<% if diary_entry.visible_comments.count > 0 %>` |
| 24 | `app/models/node.rb:271` | `save_with_history!` | 19.66 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 34%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 6%, `RAILS/activesupport/lib/active_support/callbacks.rb:362` 3% | Api::Changesets::UploadsController#create 70%, Api::NodesController#create 16%, Api::NodesController#update 12% | `changeset.save!` |
| 25 | `app/models/user.rb:62` |  | 18.78 | 0.0 | 1.44 | `RAILS/activerecord/lib/active_record/relation/query_methods.rb:2117` 10%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:29` 8%, `RAILS/activerecord/lib/arel/table.rb:85` 8% | SiteController#index 56%, UserBlocksController#show 4%, SiteController#edit 3% | `has_many :new_messages, -> { where(:to_user_visible => true, :muted =>` |
| 26 | `app/models/old_relation.rb:56` | `save_with_dependencies!` | 17.92 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 49%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 3%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 2% | Api::RelationsController#create 46%, Api::Changesets::UploadsController#create 30%, Api::RelationsController#update 18% | `save!` |
| 27 | `app/models/old_relation.rb:73` | `save_with_dependencies!` | 17.61 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 53%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 2%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 2% | Api::RelationsController#create 41%, Api::Changesets::UploadsController#create 38%, Api::RelationsController#update 21% | `member.save!` |
| 28 | `app/controllers/user_blocks_controller.rb:113` | `lookup_user_block` | 17.42 | 0.0 | 0.03 | `GEM/prosopite/lib/prosopite.rb:419` 37%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 6%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 6% | UserBlocksController#show 51%, UserBlocksController#update 44%, UserBlocksController#edit 6% | `@user_block = UserBlock.preload(:user, :creator, :revoker).find(params` |
| 29 | `app/models/node.rb:259` | `save_with_history!` | 17.34 | 0.0 | 0.0 | `GEM/prosopite/lib/prosopite.rb:419` 55%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 3%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 1% | Api::NodesController#update 55%, Api::Changesets::UploadsController#create 39%, Api::NodesController#create 6% | `tag.save!` |
| 30 | `app/abilities/ability.rb:7` | `initialize` | 17.24 | 0.0 | 2.16 | `GEM/cancancan/lib/cancan/ability/rules.rb:28` 37%, `GEM/cancancan/lib/cancan/ability.rb:145` 12%, `GEM/cancancan/lib/cancan/rule.rb:133` 6% | SiteController#index 19%, SessionsController#create 11%, DiaryEntriesController#index 9% | `can :read, [:feature_query, :layers_pane, :legend_pane, :share_pane, :` |

App middleware that hands the request on (the stack below it, not its own work): `config/initializers/policy_headers.rb:13` 301.45, `config/initializers/compressed_requests.rb:37` 133.8 warm objects per request.

548.08 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | UserMutesController#destroy | 2 / 2 | 338920.0 / 338950.0 | 30.0 | 171229.5 | `RAILS/actionview/lib/action_view/buffers.rb:44` 1426.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 654.0, `RAILS/actionview/lib/action_view/helpers/url_helper.rb:438` 639.0 | `config/initializers/policy_headers.rb:13` 497.0, `app/controllers/user_mutes_controller.rb:37` 414.0, `app/controllers/application_controller.rb:48` 387.0 |
| 2 | LayersPanesController#show | 2 / 2 | 325301.0 / 325301.0 | 0.0 | 164023.0 | `RAILS/actionview/lib/action_view/buffers.rb:44` 1400.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 642.0, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:11` 627.0 | `config/initializers/policy_headers.rb:13` 439.0, `lib/map_layers.rb:6` 130.0, `config/initializers/compressed_requests.rb:37` 108.0 |
| 3 | WebglErrorPanesController#show | 2 / 2 | 324512.0 / 324512.0 | 0.0 | 163279.5 | `RAILS/actionview/lib/action_view/buffers.rb:44` 1400.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 642.0, `RAILS/actionview/lib/action_view/helpers/url_helper.rb:438` 627.0 | `config/initializers/policy_headers.rb:13` 460.0, `config/initializers/compressed_requests.rb:37` 96.0, `app/controllers/webgl_error_panes_controller.rb:9` 18.0 |
| 4 | RelationMembersController#show | 4 / 4 | 120882.0 / 120882.0 | 0.0 | 91391.8 | `RAILS/actionview/lib/action_view/buffers.rb:44` 489.7, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 359.7, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 256.0 | `app/views/layouts/_search.html.erb:18` 381.3, `app/views/layouts/_search.html.erb:22` 356.0, `config/initializers/policy_headers.rb:13` 350.7 |
| 5 | IssuesController#reopen | 8 / 8 | 112036.4 / 112036.4 | 0.0 | 98157.8 | `RAILS/actionview/lib/action_view/buffers.rb:44` 423.7, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 206.9, `GEM/prosopite/lib/prosopite.rb:419` 193.4 | `config/initializers/policy_headers.rb:13` 333.9, `app/controllers/issues_controller.rb:105` 181.7, `app/controllers/issues_controller.rb:95` 161.4 |
| 6 | IssuesController#ignore | 8 / 8 | 112020.6 / 112020.6 | 0.0 | 98143.9 | `RAILS/actionview/lib/action_view/buffers.rb:44` 423.7, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 206.9, `GEM/prosopite/lib/prosopite.rb:419` 193.4 | `config/initializers/policy_headers.rb:13` 333.0, `app/controllers/issues_controller.rb:105` 181.7, `app/controllers/issues_controller.rb:85` 161.4 |
| 7 | Accounts::AuthDeletionsController#create | 4 / 4 | 110452.0 / 110453.3 | 1.3 | 83451.5 | `GEM/prosopite/lib/prosopite.rb:419` 532.0, `RAILS/actionview/lib/action_view/buffers.rb:44` 466.7, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 215.3 | `config/initializers/policy_headers.rb:13` 321.3, `app/controllers/accounts/auth_deletions_controller.rb:45` 260.7, `lib/spam_scorer/user.rb:14` 132.7 |
| 8 | IssuesController#show | 9 / 9 | 100116.6 / 100116.6 | 0.0 | 90982.3 | `RAILS/actionview/lib/action_view/buffers.rb:44` 370.8, `GEM/prosopite/lib/prosopite.rb:419` 254.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 222.8 | `config/initializers/policy_headers.rb:13` 376.0, `app/controllers/issues_controller.rb:105` 159.0, `app/controllers/application_controller.rb:48` 132.0 |
| 9 | IssuesController#resolve | 9 / 9 | 98134.6 / 98134.6 | 0.0 | 87817.2 | `RAILS/actionview/lib/action_view/buffers.rb:44` 370.8, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 181.0, `GEM/prosopite/lib/prosopite.rb:419` 169.3 | `config/initializers/policy_headers.rb:13` 335.3, `app/controllers/issues_controller.rb:105` 159.0, `app/controllers/issues_controller.rb:75` 144.5 |
| 10 | Issues::ReportersController#index | 12 / 12 | 96377.4 / 96377.7 | 0.4 | 117051.8 | `RAILS/actionview/lib/action_view/buffers.rb:44` 392.6, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 211.8, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:11` 178.1 | `config/initializers/policy_headers.rb:13` 415.0, `app/controllers/issues/reporters_controller.rb:14` 201.1, `app/controllers/application_controller.rb:48` 144.0 |
| 11 | OldRelationMembersController#show | 6 / 6 | 73552.4 / 73552.8 | 0.4 | 61919.3 | `RAILS/actionview/lib/action_view/buffers.rb:44` 293.8, `GEM/prosopite/lib/prosopite.rb:419` 290.8, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 218.6 | `app/controllers/old_relation_members_controller.rb:7` 445.4, `config/initializers/policy_headers.rb:13` 353.6, `app/views/layouts/_search.html.erb:18` 228.8 |
| 12 | ChangesetsController#show | 34 / 34 | 29076.5 / 29076.7 | 0.2 | 28497.7 | `GEM/prosopite/lib/prosopite.rb:419` 540.8, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 224.5, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 201.1 | `app/views/changesets/_elements.html.erb:6` 302.9, `app/views/changesets/_elements.html.erb:10` 288.1, `app/views/changesets/_elements.html.erb:9` 260.8 |
| 13 | NotesController#index | 19 / 19 | 26402.3 / 26402.3 | 0.1 | 25157.9 | `GEM/prosopite/lib/prosopite.rb:419` 326.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 204.2, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 189.7 | `app/controllers/notes_controller.rb:33` 690.5, `app/helpers/application_helper.rb:21` 290.9, `lib/rich_text.rb:45` 275.8 |
| 14 | (no action name) | 146 / 146 | 25230.0 / 25231.7 | 1.7 | 25062.7 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 284.9, `GEM/nokogiri/lib/nokogiri/xml/document.rb:416` 283.0, `GEM/nokogiri/lib/nokogiri/html5/node.rb:66` 283.0 | `config/initializers/compressed_requests.rb:37` 287.0, `config/initializers/policy_headers.rb:13` 35.8, `config/initializers/content_security_policy.rb:42` 2.0 |
| 15 | DiaryEntriesController#index | 30 / 30 | 23260.3 / 23261.9 | 1.6 | 22697.1 | `GEM/prosopite/lib/prosopite.rb:419` 2041.4, `GEM/cancancan/lib/cancan/ability.rb:145` 649.9, `GEM/cancancan/lib/cancan/ability/rules.rb:28` 471.2 | `app/views/diary_entries/_diary_entry.html.erb:28` 2925.9, `app/helpers/user_helper.rb:40` 1525.0, `lib/rich_text.rb:111` 1421.7 |
| 16 | DiaryCommentsController#create | 5 / 5 | 18426.5 / 18427.5 | 1.0 | 14963.4 | `GEM/prosopite/lib/prosopite.rb:419` 2102.8, `GEM/mail/lib/mail/utilities.rb:215` 657.0, `GEM/mail/lib/mail/encodings/8bit.rb:14` 445.0 | `app/mailers/user_mailer.rb:146` 1409.0, `app/controllers/diary_comments_controller.rb:24` 842.0, `app/controllers/diary_comments_controller.rb:21` 682.8 |
| 17 | SiteController#edit | 29 / 29 | 17629.9 / 17629.2 | -0.7 | 17266.8 | `GEM/prosopite/lib/prosopite.rb:419` 172.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 167.3, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 147.1 | `config/initializers/policy_headers.rb:13` 322.6, `app/models/user.rb:288` 318.7, `app/helpers/user_helper.rb:40` 182.6 |
| 18 | DirectionsController#show | 2 / 2 | 16453.0 / 16453.0 | 0.0 | 18704.5 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 428.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 365.0, `GEM/inline_svg/lib/inline_svg/transform_pipeline/transformations.rb:54` 306.0 | `app/views/directions/show.html.erb:7` 3406.0, `config/initializers/inline_svg.rb:14` 697.0, `app/views/layouts/_search.html.erb:18` 572.0 |
| 19 | Api::Changesets::UploadsController#create | 80 / 80 | 14850.6 / 14851.5 | 0.9 | 14716.9 | `GEM/prosopite/lib/prosopite.rb:419` 5824.5, `GEM/prosopite/lib/prosopite.rb:250` 1116.3, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 291.8 | `app/models/old_node.rb:72` 1658.9, `config/initializers/policy_headers.rb:13` 1351.3, `app/models/node.rb:249` 1218.2 |
| 20 | Users::ListsController#show | 19 / 19 | 13942.8 / 13943.8 | 1.0 | 13427.2 | `GEM/prosopite/lib/prosopite.rb:419` 1845.4, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 285.2, `RAILS/activemodel/lib/active_model/attribute.rb:9` 274.8 | `app/helpers/user_helper.rb:40` 3144.3, `lib/rich_text.rb:111` 1031.1, `app/controllers/concerns/pagination_methods.rb:27` 679.7 |
| 21 | AccountsController#update | 7 / 7 | 13384.2 / 13386.2 | 2.0 | 11807.7 | `GEM/prosopite/lib/prosopite.rb:419` 2018.3, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 258.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 183.3 | `config/initializers/policy_headers.rb:13` 891.5, `app/controllers/concerns/user_methods.rb:45` 821.2, `config/initializers/mail_delivery_job.rb:9` 701.2 |
| 22 | Api::RelationsController#update | 14 / 14 | 13007.2 / 13004.0 | -3.2 | 12287.8 | `GEM/prosopite/lib/prosopite.rb:419` 5507.6, `GEM/prosopite/lib/prosopite.rb:250` 799.4, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 201.6 | `app/models/old_relation.rb:73` 1203.7, `app/models/relation.rb:341` 1162.2, `app/models/old_relation.rb:56` 1077.9 |
| 23 | UsersController#show | 34 / 34 | 12021.6 / 12021.7 | 0.1 | 12164.6 | `GEM/prosopite/lib/prosopite.rb:419` 1635.8, `GEM/cancancan/lib/cancan/ability.rb:145` 324.8, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 225.0 | `app/helpers/user_helper.rb:40` 535.2, `config/initializers/policy_headers.rb:13` 445.9, `app/models/user.rb:385` 372.2 |
| 24 | TracesController#index | 27 / 27 | 11912.2 / 11912.2 | -0.0 | 11701.0 | `GEM/prosopite/lib/prosopite.rb:419` 566.1, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 356.2, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 325.6 | `app/controllers/concerns/pagination_methods.rb:27` 1628.8, `app/helpers/application_helper.rb:21` 586.4, `app/views/traces/_trace.html.erb:54` 373.3 |
| 25 | SiteController#index | 446 / 446 | 11738.1 / 11738.3 | 0.2 | 11758.1 | `GEM/prosopite/lib/prosopite.rb:419` 1028.4, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 363.3, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 343.0 | `app/models/user.rb:288` 568.8, `app/views/layouts/_search.html.erb:18` 557.9, `app/views/layouts/_search.html.erb:22` 520.8 |
| 26 | ChangesetsController#index | 75 / 75 | 11582.3 / 11582.2 | -0.1 | 11615.1 | `GEM/prosopite/lib/prosopite.rb:419` 563.1, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 174.6, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 166.1 | `app/controllers/concerns/pagination_methods.rb:27` 611.2, `config/initializers/policy_headers.rb:13` 241.4, `app/views/layouts/_search.html.erb:18` 208.7 |
| 27 | SiteController#welcome | 15 / 15 | 11547.9 / 11546.1 | -1.8 | 11819.3 | `GEM/prosopite/lib/prosopite.rb:419` 896.3, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 277.3, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 183.9 | `app/models/user.rb:288` 533.1, `config/initializers/compressed_requests.rb:37` 432.0, `app/helpers/user_helper.rb:40` 413.9 |
| 28 | UsersController#create | 45 / 45 | 11177.7 / 11177.5 | -0.2 | 11219.0 | `GEM/prosopite/lib/prosopite.rb:419` 1611.9, `GEM/mail/lib/mail/utilities.rb:215` 237.3, `GEM/mail/lib/mail/encodings/8bit.rb:14` 132.7 | `config/initializers/mail_delivery_job.rb:9` 959.4, `app/mailers/user_mailer.rb:25` 566.2, `app/views/application/_auth_button.html.erb:7` 494.8 |
| 29 | Oauth2ApplicationsController#new | 2 / 2 | 11164.0 / 11164.0 | 0.0 | 6167.5 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 365.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 311.0, `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` 310.0 | `app/views/oauth2_applications/_form.html.erb:8` 2405.0, `app/views/application/_settings_menu.html.erb:16` 481.0, `app/models/user.rb:288` 379.0 |
| 30 | UserBlocksController#show | 33 / 33 | 11051.3 / 11051.3 | -0.0 | 11131.5 | `GEM/prosopite/lib/prosopite.rb:419` 1489.3, `GEM/prosopite/lib/prosopite.rb:250` 293.6, `GEM/cancancan/lib/cancan/ability.rb:145` 255.9 | `app/controllers/user_blocks_controller.rb:113` 1166.3, `config/initializers/policy_headers.rb:13` 771.4, `app/models/user.rb:288` 452.4 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/prosopite/lib/prosopite.rb:419` | `subscribe` | 761.24 / 761.24 | 0.0 | 761.43 | 70% | Data, Array |  | `app/models/user.rb:385` 7%, `app/controllers/api_controller.rb:100` 6% | `query_caller = caller_locations` |
| 2 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:98` | `extract_non_symbol_default!` | 99.23 / 99.23 | 0.0 | 99.23 | 48% | Array, Hash | ruby-i18n/i18n#764 open upstream work | `app/views/layouts/_header.html.erb:27` 5%, `app/views/layouts/_search.html.erb:40` 4% | `defaults = [options[:default]].flatten` |
| 3 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` | `tag_option` | 96.96 / 96.96 | 0.0 | 96.97 | 40% | String |  | `app/views/layouts/_meta.html.erb:6` 12%, `app/views/layouts/_header.html.erb:38` 6% | `%(#{key}="#{value}")` |
| 4 | `GEM/cancancan/lib/cancan/ability.rb:145` | `can` | 82.47 / 82.47 | 0.0 | 82.48 | 92% | Object, Array |  | `app/abilities/ability.rb:21` 3%, `app/abilities/ability.rb:15` 3% | `add_rule(Rule.new(true, action, subject, *attributes_and_conditions, &` |
| 5 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` | `html_safe` | 75.13 / 75.13 | 0.0 | 75.14 | 52% | String |  | `no app frame` 18%, `app/views/layouts/_header.html.erb:38` 7% | `ActiveSupport::SafeBuffer.new(self)` |
| 6 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` | `initialize` | 63.42 / 63.42 | 0.0 | 63.43 | 50% | String |  | `no app frame` 12%, `app/views/layouts/_header.html.erb:38` 9% | `super` |
| 7 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:54` | `translate` | 55.28 / 55.28 | 0.0 | 55.29 | 50% | Hash | ruby-i18n/i18n#765 open upstream work | `app/views/layouts/_header.html.erb:27` 4%, `app/helpers/application_helper.rb:12` 4% | `fallback_options = options.merge(:fallback_in_progress => true, fallba` |
| 8 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:60` | `translate` | 53.85 / 53.85 | 0.0 | 53.86 | 48% | String | ruby-i18n/i18n#763 open upstream work | `app/views/layouts/_header.html.erb:27` 5%, `app/helpers/application_helper.rb:12` 4% | `on_fallback(locale, fallback, key, options) if locale.to_s != fallback` |
| 9 | `GEM/cancancan/lib/cancan/rule.rb:137` | `wrap` | 52.37 / 52.37 | 0.0 | 52.37 | 92% | Array |  | `app/abilities/ability.rb:19` 4%, `app/abilities/ability.rb:22` 4% | `[object]` |
| 10 | `RAILS/activemodel/lib/active_model/attribute.rb:9` | `from_database` | 51.79 / 51.79 | 0.0 | 51.81 | 70% | Object |  | `app/controllers/application_controller.rb:48` 19%, `app/controllers/concerns/pagination_methods.rb:27` 12% | `FromDatabase.new(name, value_before_type_cast, type, nil, value)` |
| 11 | `GEM/cancancan/lib/cancan/ability/rules.rb:28` | `add_rule_to_index` | 50.03 / 50.03 | 0.0 | 50.04 | 92% | Array |  | `app/abilities/ability.rb:8` 14%, `app/abilities/ability.rb:7` 14% | `@rules_index[subject] \|\|= []` |
| 12 | `GEM/prosopite/lib/prosopite.rb:250` † | `create_notifications` | 46.54 / 46.54 | 0.0 | 46.63 | 4% | String, Array |  | `config/initializers/policy_headers.rb:13` 100% | `kaller = state[:prosopite_query_caller][location_key].map(&:to_s)` |
| 13 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` | `get_oid_type` | 44.4 / 44.4 | 0.0 | 44.42 | 70% | Array |  | `app/controllers/api_controller.rb:100` 14%, `app/controllers/application_controller.rb:48` 12% | `type_map.fetch(oid, fmod, sql_type) {` |
| 14 | `GEM/cancancan/lib/cancan/ability/rules.rb:24` | `add_rule_to_index` | 41.24 / 41.24 | 0.0 | 41.24 | 92% | Array |  | `app/abilities/ability.rb:26` 3%, `app/abilities/ability.rb:18` 3% | `subjects = rule.subjects.compact` |
| 15 | `GEM/cancancan/lib/cancan/rule.rb:31` † | `initialize` | 41.24 / 41.24 | 0.0 | 41.24 | 92% | Array |  | `app/abilities/ability.rb:24` 3%, `app/abilities/ability.rb:25` 3% | `@actions = wrap(action).map(&:to_sym)` |
| 16 | `GEM/cancancan/lib/cancan/rule.rb:121` | `parse_attributes_from_extra_args` | 41.24 / 41.24 | 0.0 | 41.24 | 92% | Array |  | `app/abilities/ability.rb:7` 3%, `app/abilities/ability.rb:14` 3% | `[attributes, extra_args]` |
| 17 | `GEM/cancancan/lib/cancan/rule.rb:133` | `wrap` | 41.24 / 41.24 | 0.0 | 41.24 | 92% | Array |  | `app/abilities/ability.rb:12` 3%, `app/abilities/ability.rb:28` 3% | `[]` |
| 18 | `GEM/cancancan/lib/cancan/rule.rb:34` | `initialize` | 40.09 / 40.09 | 0.0 | 40.09 | 92% | Hash |  | `app/abilities/ability.rb:10` 3%, `app/abilities/ability.rb:25` 3% | `@conditions = extra_args \|\| {}` |
| 19 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:237` | `tag_options` | 33.97 / 33.97 | 0.0 | 33.97 | 40% | String |  | `app/views/layouts/_meta.html.erb:6` 9%, `app/views/layouts/_header.html.erb:38` 8% | `output = +""` |
| 20 | `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:348` | `validate` | 31.29 / 31.29 | 0.0 | 31.3 | 99% | String |  | `no app frame` 100% | `if source.include?(";") \|\| source != source.gsub(/[[:space:]]/, "")` |
| 21 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | `merge` | 29.87 / 29.87 | 0.0 | 29.88 | 66% | Array, Object |  | `app/models/user.rb:288` 15%, `app/models/user.rb:385` 13% | `WhereClause.new(predicates \| other.predicates)` |
| 22 | `GEM/i18n/lib/i18n/utils.rb:8` | `except` | 29.13 / 29.13 | 0.0 | 29.13 | 50% | Hash |  | `app/views/layouts/_header.html.erb:27` 4%, `app/helpers/application_helper.rb:12` 3% | `hash.except(*keys)` |
| 23 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:151` † | `now` | 29.1 / 29.1 | 0.0 | 29.1 | 89% | Data |  | `no app frame` 12%, `config/initializers/policy_headers.rb:13` 5% | `Time.now` |
| 24 | `GEM/i18n/lib/i18n.rb:396` | `normalize_keys` | 28.61 / 28.61 | 0.0 | 28.61 | 50% | Array |  | `app/views/layouts/_header.html.erb:27` 4%, `app/helpers/application_helper.rb:12` 4% | `[` |
| 25 | `GEM/i18n/lib/i18n/backend/base.rb:58` | `translate` | 27.68 / 27.68 | 0.0 | 27.69 | 50% | Array |  | `app/views/layouts/_header.html.erb:27` 4%, `app/helpers/application_helper.rb:12` 4% | `values = Utils.except(options, *RESERVED_KEYS) unless options.empty?` |
| 26 | `GEM/rails-controller-testing/lib/rails/controller/testing/template_assertions.rb:39` | `setup_subscriptions` | 26.92 / 26.92 | 0.01 | 26.92 | 48% | String, Array |  | `no app frame` 25%, `app/views/layouts/_header.html.erb:9` 6% | `@_partials[virtual_path.split("/").last] += 1` |
| 27 | `RAILS/activerecord/lib/arel/visitors/postgresql.rb:136` | `visit_Arel_Nodes_IsDistinctFrom` | 26.61 / 26.61 | -0.0 | 26.62 | 74% | String |  | `app/controllers/application_controller.rb:48` 11%, `app/models/user.rb:288` 9% | `BIND_BLOCK = proc { \|i\| "$#{i}" }` |
| 28 | `GEM/i18n/lib/i18n/backend/base.rb:49` | `translate` | 26.43 / 26.43 | 0.0 | 26.43 | 50% | String |  | `app/views/layouts/_header.html.erb:27` 5%, `app/helpers/application_helper.rb:12` 4% | `entry = entry.dup if entry.is_a?(String)` |
| 29 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` | `call` | 26.16 / 26.16 | 0.0 | 26.16 | 100% | Data |  | `config/initializers/policy_headers.rb:13` 17%, `no app frame` 15% | `result_lambda = -> { user_callback.call target, value }` |
| 30 | `GEM/omniauth/lib/omniauth/strategy/paths.rb:67` | `current_path` | 25.02 / 25.02 | 0.0 | 25.03 | 100% | String, MatchData |  | `config/initializers/compressed_requests.rb:37` 100% | `@current_path \|\|= request.path.downcase.squeeze('/').sub(CURRENT_PATH_` |

## Dev/test-mode work

2859.8 of 8222.1 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | error page | `RUBY/error_highlight/base.rb:94` | 1454.15 | 1% | `no app frame` 100% | `Prism.parse_file(absolute_path).value.breadth_first_search { \|node\| no` |
| 2 | error page | `GEM/prism/lib/prism/parse_result.rb:162` | 577.18 | 1% | `no app frame` 100% | `source.lines` |
| 3 | error page | `GEM/prism/lib/prism/node.rb:4628` | 67.16 | 1% | `no app frame` 100% | `compact = [] #: Array[Prism::node]` |
| 4 | asset lookup | `GEM/sprockets/lib/sprockets/path_utils.rb:236` | 64.18 | 19% | `app/views/layouts/_search.html.erb:18` 48%, `app/views/layouts/_search.html.erb:22` 48% | `next unless File.basename(entry).start_with?(basename)` |
| 5 | error page | `RAILS/actionpack/lib/action_dispatch/middleware/exception_wrapper.rb:332` | 63.59 | 1% | `no app frame` 100% | `lines = source_lines.drop(start).take(6)` |
| 6 | error page | `GEM/prism/lib/prism/node.rb:30908` | 42.69 | 1% | `no app frame` 100% | `[*body]` |
| 7 | error page | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:195` | 41.91 | 1% | `no app frame` 100% | `add_filter { \|line\| line.sub(gems_regexp, gems_result) }` |
| 8 | error page | `GEM/prism/lib/prism/node.rb:1312` | 32.47 | 1% | `no app frame` 100% | `[*arguments]` |
| 9 | error page | `GEM/prism/lib/prism/node.rb:10815` | 24.61 | 1% | `no app frame` 100% | `compact = [] #: Array[Prism::node]` |
| 10 | error page | `GEM/prism/lib/prism/node.rb:22105` | 23.73 | 1% | `no app frame` 100% | `[]` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| ruby stdlib | 1489.9 | 1540.6 | `base.rb:94` 1454.2, `formatter.rb:174` 7.3, `ipaddr.rb:725` 3.5 |
| ruby default gem: prism | 936.2 | 969.9 | `parse_result.rb:162` 577.2, `node.rb:4628` 67.2, `node.rb:30908` 42.7 |
| rails: activerecord | 899.6 | 901.7 | `postgresql_adapter.rb:880` 44.4, `where_clause.rb:29` 29.9, `postgresql.rb:136` 26.6 |
| gem: prosopite | 846.7 | 847.0 | `prosopite.rb:419` 761.2, `prosopite.rb:250` 46.5, `prosopite.rb:418` 11.3 |
| rails: actionview | 657.3 | 659.1 | `tag_helper.rb:318` 97.0, `tag_helper.rb:237` 34.0, `translation_helper.rb:91` 23.7 |
| rails: activesupport | 629.3 | 632.5 | `output_safety.rb:242` 75.1, `output_safety.rb:71` 63.4, `backtrace_cleaner.rb:195` 41.9 |
| rails: actionpack | 584.4 | 597.4 | `exception_wrapper.rb:332` 63.6, `content_security_policy.rb:348` 31.3, `content_security_policy.rb:336` 23.5 |
| gem: cancancan | 482.8 | 482.9 | `ability.rb:145` 82.5, `rule.rb:137` 52.4, `rules.rb:28` 50.0 |
| app | 408.0 | 415.8 | `migrate.rb:8` 37.3, `_meta.html.erb:6` 26.6, `_header.html.erb:38` 22.2 |
| gem: i18n | 369.4 | 369.6 | `fallbacks.rb:98` 99.2, `fallbacks.rb:54` 55.3, `fallbacks.rb:60` 53.9 |
| gem: inline_svg | 190.2 | 190.4 | `transformations.rb:54` 14.7, `transformations.rb:16` 8.6, `transformations.rb:14` 8.6 |
| gem: sprockets | 179.3 | 179.7 | `path_utils.rb:236` 64.2, `resolve.rb:218` 9.8, `resolve.rb:292` 7.3 |
| gem: nokogiri | 171.0 | 171.1 | `node.rb:1431` 17.8, `node.rb:66` 11.2, `document.rb:85` 9.9 |
| rails: activemodel | 118.4 | 119.2 | `attribute.rb:9` 51.8, `builder.rb:37` 10.3, `string.rb:39` 5.0 |
| gem: omniauth | 93.5 | 93.6 | `paths.rb:67` 25.0, `strategy.rb:285` 11.9, `paths.rb:94` 11.9 |
| gem: rack | 67.5 | 67.7 | `request.rb:607` 12.9, `utils.rb:693` 11.7, `body_proxy.rb:12` 4.0 |
| gem: mail | 50.6 | 52.6 | `utilities.rb:215` 7.6, `8bit.rb:14` 4.2, `field_list.rb:71` 3.8 |
| gem: sprockets-rails | 49.3 | 50.2 | `helper.rb:81` 19.3, `route_wrapper.rb:5` 12.1, `helper.rb:186` 2.5 |
| ruby default gem: uri | 39.5 | 39.5 | `rfc2396_parser.rb:320` 11.1, `common.rb:465` 8.1, `rfc2396_parser.rb:291` 7.4 |
| gem: hashie | 38.9 | 39.0 | `mash.rb:641` 15.1, `mash.rb:596` 15.1, `mash.rb:329` 3.6 |
| gem: rails-controller-testing | 34.8 | 34.8 | `template_assertions.rb:39` 26.9, `template_assertions.rb:35` 6.7, `template_assertions.rb:27` 0.7 |
| gem: builder | 34.0 | 34.1 | `xchar.rb:155` 7.3, `xchar.rb:156` 3.9, `xchar.rb:154` 3.8 |
| gem: aasm | 29.9 | 29.9 | `state_machine_store.rb:29` 4.9, `state_machine.rb:12` 2.2, `state_machine.rb:11` 2.2 |
| gem: concurrent-ruby | 26.0 | 26.0 | `safe_initialization.rb:30` 6.0, `non_concurrent_map_backend.rb:131` 4.6, `mutex_lockable_object.rb:33` 2.0 |
| gem: sanitize | 23.3 | 23.3 | `sanitize.rb:203` 6.7, `clean_element.rb:84` 3.4, `sanitize.rb:206` 2.9 |
| gem: loofah | 17.9 | 17.9 | `concerns.rb:172` 6.5, `concerns.rb:43` 4.9, `scrubber.rb:132` 3.3 |
| gem: kramdown | 15.9 | 15.9 | `kramdown.rb:136` 1.5, `kramdown.rb:135` 1.4, `utils.rb:27` 0.8 |
| gem: rack-session | 15.0 | 15.0 | `id.rb:43` 6.5, `id.rb:31` 4.3, `id.rb:275` 1.0 |
| gem: tzinfo | 14.1 | 14.1 | `timestamp.rb:208` 4.4, `timestamp.rb:193` 3.0, `constant_offset_data_timezone_info.rb:52` 2.8 |
| gem: erubi | 11.8 | 12.2 | `erubi.rb:134` 6.8, `erubi.rb:137` 1.5, `erubi.rb:139` 0.9 |
| gem: rails-html-sanitizer | 11.4 | 11.4 | `sanitizer.rb:33` 1.6, `sanitizer.rb:56` 1.6, `sanitizer.rb:192` 1.6 |
| gem: http_accept_language | 11.3 | 11.3 | `parser.rb:19` 3.5, `middleware.rb:8` 3.0, `middleware.rb:10` 2.0 |
| gem: addressable | 8.4 | 8.5 | `uri.rb:438` 1.0, `uri.rb:424` 0.6, `uri.rb:486` 0.5 |
| gem: doorkeeper | 8.3 | 8.7 | `scopes.rb:14` 2.4, `token.rb:150` 1.4, `token.rb:154` 0.7 |
| gem: bootstrap_form | 8.3 | 8.4 | `hints.rb:65` 0.8, `bootstrap.rb:102` 0.5, `hints.rb:52` 0.4 |
| gem: quad_tile | 7.4 | 7.7 | `quad_tile.rb:13` 5.9, `quad_tile.rb:17` 1.3, `quad_tile.rb:19` 0.1 |
| rails: railties | 6.0 | 6.0 | `engine.rb:748` 1.0, `logger.rb:24` 1.0, `logger.rb:21` 1.0 |
| gem: rack-cors | 5.9 | 5.9 | `cors.rb:123` 3.3, `result.rb:38` 1.0, `cors.rb:129` 1.0 |
| test harness: webmock | 4.5 | 4.5 | `headers.rb:69` 0.6, `headers.rb:68` 0.5, `uri.rb:62` 0.3 |
| gem: turbo-rails | 3.8 | 3.9 | `request_id_tracking.rb:10` 1.0, `frame_request.rb:36` 0.8, `drive_helper.rb:78` 0.7 |
| gem: rgeo | 3.3 | 3.4 | `entities.rb:184` 0.9, `entities.rb:187` 0.7, `entities.rb:193` 0.4 |
| gem: argon2 | 3.1 | 3.1 | `hash_format.rb:46` 0.9, `hash_format.rb:17` 0.8, `hash_format.rb:22` 0.2 |
| rails: activestorage | 3.1 | 3.2 | `model.rb:128` 0.6, `one.rb:34` 0.5, `model.rb:284` 0.3 |
| gem: canonical-rails | 3.0 | 3.0 | `tag_helper.rb:4` 0.7, `tag_helper.rb:23` 0.5, `tag_helper.rb:21` 0.4 |
| gem: rack-uri_sanitizer | 3.0 | 3.0 | `uri_sanitizer.rb:10` 3.0 |
| ruby default gem: securerandom | 2.2 | 2.2 | `securerandom.rb:71` 2.2 |
| gem: rexml | 1.8 | 2.0 | `source.rb:293` 0.1, `source.rb:269` 0.1, `element.rb:2429` 0.1 |
| gem: bootsnap | 1.4 | 1.5 | `kernel_require.rb:11` 1.1, `yaml.rb:259` 0.2, `cache.rb:218` 0.0 |
| gem: rails_param | 1.3 | 1.3 | `validator.rb:51` 0.4, `param_evaluator.rb:11` 0.2, `param.rb:3` 0.2 |
| ruby default gem: timeout | 1.3 | 1.3 | `timeout.rb:152` 0.3, `timeout.rb:35` 0.3, `timeout.rb:293` 0.3 |
| gem: faraday | 1.2 | 1.2 | `nested_params_encoder.rb:108` 0.2, `nested_params_encoder.rb:94` 0.1, `utils.rb:40` 0.1 |
| gem: json | 1.1 | 1.1 | `common.rb:860` 0.8, `common.rb:297` 0.2, `common.rb:377` 0.0 |
| gem: validates_email_format_of | 1.0 | 1.0 | `validates_email_format_of.rb:256` 0.3, `validates_email_format_of.rb:193` 0.3, `validates_email_format_of.rb:146` 0.1 |
| gem: globalid | 0.9 | 1.0 | `gid.rb:159` 0.2, `gid.rb:95` 0.2, `gid.rb:166` 0.1 |
| rails: activejob | 0.9 | 0.9 | `arguments.rb:141` 0.1, `core.rb:129` 0.1, `arguments.rb:61` 0.1 |
| rails: actionmailer | 0.9 | 1.0 | `mail_helper.rb:69` 0.4, `mail_helper.rb:68` 0.1, `base.rb:1009` 0.0 |
| gem: libxml-ruby | 0.8 | 0.8 | `node.rb:75` 0.2, `node.rb:61` 0.1, `node.rb:58` 0.1 |
| gem: simpleidn | 0.8 | 0.8 | `simpleidn.rb:224` 0.4, `simpleidn.rb:249` 0.1, `simpleidn.rb:235` 0.1 |
| gem: pg | 0.8 | 0.8 | `connection.rb:350` 0.6, `connection.rb:351` 0.1, `connection.rb:844` 0.0 |
| gem: jbuilder | 0.5 | 0.5 | `jbuilder.rb:354` 0.1, `collection_renderer.rb:21` 0.1, `jbuilder_template.rb:150` 0.0 |
| ruby default gem: net-http | 0.4 | 0.4 | `header.rb:203` 0.1, `header.rb:275` 0.0, `header.rb:225` 0.0 |
| gem: bigdecimal | 0.3 | 0.3 | `util.rb:24` 0.2, `util.rb:51` 0.0 |
| gem: noticed | 0.2 | 0.2 | `deliver_by.rb:12` 0.1, `deliverable.rb:70` 0.0, `deliver_by.rb:11` 0.0 |
| gem: marcel | 0.2 | 0.3 | `mime_type.rb:90` 0.1, `magic.rb:18` 0.0, `mime_type.rb:81` 0.0 |
| ruby default gem: prettyprint | 0.2 | 0.2 | `prettyprint.rb:404` 0.0, `prettyprint.rb:264` 0.0, `prettyprint.rb:459` 0.0 |
| gem: openstreetmap-deadlock_retry | 0.2 | 0.2 | `deadlock_retry.rb:21` 0.2 |
| ruby default gem: erb | 0.2 | 0.2 | `util.rb:65` 0.2 |
| gem: config | 0.2 | 0.2 | `options.rb:156` 0.1, `options.rb:125` 0.1, `options.rb:124` 0.0 |
| gem: unicode-display_width | 0.1 | 0.1 | `display_width.rb:220` 0.0, `display_width.rb:60` 0.0, `display_width.rb:218` 0.0 |
| ruby default gem: pp | 0.1 | 0.1 | `pp.rb:542` 0.0, `pp.rb:550` 0.0, `pp.rb:271` 0.0 |
| gem: htmlentities | 0.1 | 0.1 | `decoder.rb:10` 0.0, `decoder.rb:25` 0.0, `htmlentities.rb:44` 0.0 |
| gem: cgi | 0.1 | 0.1 | `core.rb:575` 0.1, `core.rb:574` 0.0, `core.rb:579` 0.0 |
| gem: faraday-net_http | 0.1 | 0.1 | `net_http.rb:95` 0.0, `net_http.rb:137` 0.0, `net_http.rb:165` 0.0 |
| gem: active_storage_validations | 0.1 | 0.1 | `asv_symbolizable.rb:10` 0.0, `vips.rb:41` 0.0, `asv_symbolizable.rb:9` 0.0 |
| ruby default gem: open3 | 0.1 | 0.1 | `open3.rb:527` 0.0, `open3.rb:790` 0.0, `open3.rb:528` 0.0 |
| gem: activerecord-postgis | 0.1 | 0.1 | `spatial.rb:76` 0.0, `spatial.rb:64` 0.0, `spatial.rb:39` 0.0 |
| gem: active_record_union | 0.1 | 0.1 | `union.rb:39` 0.0, `union.rb:49` 0.0, `union.rb:35` 0.0 |
| gem: base64 | 0.1 | 0.1 | `base64.rb:283` 0.0, `base64.rb:310` 0.0, `base64.rb:377` 0.0 |
| gem: logger | 0.0 | 0.1 | `log_device.rb:33` 0.0, `log_device.rb:165` 0.0, `logger.rb:692` 0.0 |
| gem: omniauth-rails_csrf_protection | 0.0 | 0.0 | `token_verifier.rb:59` 0.0, `token_verifier.rb:55` 0.0 |
| gem: ffi | 0.0 | 0.1 | `managedstruct.rb:80` 0.0, `autopointer.rb:88` 0.0, `autopointer.rb:79` 0.0 |
| ruby default gem: digest | 0.0 | 0.0 | `digest.rb:83` 0.0, `digest.rb:64` 0.0, `digest.rb:65` 0.0 |
| gem: ruby-vips | 0.0 | 0.1 | `object.rb:202` 0.0, `object.rb:201` 0.0, `object.rb:203` 0.0 |
| gem: mini_mime | 0.0 | 0.0 | `mini_mime.rb:54` 0.0, `mini_mime.rb:56` 0.0 |
| gem: doorkeeper-openid_connect | 0.0 | 0.1 | `controller.rb:78` 0.0, `openid_connect.rb:145` 0.0, `prompt.rb:73` 0.0 |
| gem: jwt | 0.0 | 0.0 | `rsa.rb:122` 0.0, `thumbprint.rb:17` 0.0, `rsa.rb:94` 0.0 |
| gem: zeitwerk | 0.0 | 0.0 | `cref.rb:36` 0.0, `cref.rb:47` 0.0, `constant_path_validator.rb:13` 0.0 |
| gem: lowrail-profile | 0.0 | 0.0 | `profile.rb:95` 0.0, `profile.rb:55` 0.0, `profile.rb:65` 0.0 |
| gem: rgeo-activerecord | 0.0 | 0.0 | `spatial_factory_store.rb:47` 0.0 |
| gem: omniauth-facebook | 0.0 | 0.0 | `facebook.rb:84` 0.0, `facebook.rb:88` 0.0 |
| gem: omniauth-microsoft_graph | 0.0 | 0.0 | `microsoft_graph.rb:73` 0.0 |
| gem: omniauth-google-oauth2 | 0.0 | 0.0 | `google_oauth2.rb:219` 0.0, `google_oauth2.rb:104` 0.0, `google_oauth2.rb:373` 0.0 |
| gem: omniauth-apple | 0.0 | 0.0 | `apple.rb:63` 0.0 |
| gem: omniauth-github | 0.0 | 0.0 | `github.rb:78` 0.0 |
| gem: racc | 0.0 | 0.0 | `parser.rb:263` 0.0 |
| gem: oauth2 | 0.0 | 0.0 | `client.rb:286` 0.0, `client.rb:57` 0.0, `client.rb:72` 0.0 |
| gem: matrix | 0.0 | 0.1 | `matrix.rb:198` 0.0, `matrix.rb:338` 0.0, `matrix.rb:147` 0.0 |
| gem: omniauth-oauth2 | 0.0 | 0.0 | `oauth2.rb:47` 0.0, `oauth2.rb:72` 0.0, `oauth2.rb:70` 0.0 |
| gem: auth-sanitizer | 0.0 | 0.0 | `thing_filter.rb:21` 0.0, `thing_filter.rb:23` 0.0, `filtered_attributes.rb:35` 0.0 |
| gem: ffi-libarchive | 0.0 | 0.1 | `reader.rb:60` 0.0, `reader.rb:14` 0.0, `reader.rb:122` 0.0 |
| gem: activerecord-import | 0.0 | 0.0 | `import.rb:915` 0.0, `postgresql_adapter.rb:17` 0.0, `import.rb:784` 0.0 |
| gem: teaspoon | 0.0 | 0.0 | `engine.rb:65` 0.0 |
| gem: snaky_hash | 0.0 | 0.0 | `snake.rb:113` 0.0, `snake.rb:75` 0.0, `snake.rb:114` 0.0 |
| gem: image_processing | 0.0 | 0.0 | `vips.rb:79` 0.0, `chainable.rb:77` 0.0, `chainable.rb:6` 0.0 |
| gem: msgpack | 0.0 | 0.0 | `factory.rb:29` 0.0, `factory.rb:41` 0.0, `factory.rb:16` 0.0 |
| gem: gd2-ffij | 0.0 | 0.1 | `animated_gif.rb:36` 0.0, `animated_gif.rb:30` 0.0, `animated_gif.rb:68` 0.0 |
| gem: actionpack-page_caching | 0.0 | 0.0 | `pages.rb:55` 0.0, `pages.rb:61` 0.0, `railtie.rb:8` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Jobs

| # | Job | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | TraceImporterJob#perform | 7 / 7 | 14521.7 / 14528.7 | 7.0 | 14740.4 | `GEM/prosopite/lib/prosopite.rb:419` 1398.7, `GEM/mail/lib/mail/utilities.rb:215` 870.0, `GEM/mail/lib/mail/encodings/8bit.rb:14` 868.0 | `app/mailers/user_mailer.rb:95` 1228.0, `app/mailers/user_mailer.rb:70` 822.5, `app/jobs/trace_importer_job.rb:35` 816.0 |
| 2 | Noticed::EventJob#perform | 16 / 16 | 12766.9 / 12766.9 | 0.1 | 12592.5 | `GEM/mail/lib/mail/utilities.rb:215` 576.1, `GEM/prosopite/lib/prosopite.rb:419` 365.8, `GEM/mail/lib/mail/encodings/8bit.rb:14` 331.2 | `app/mailers/user_mailer.rb:244` 517.6, `app/mailers/user_mailer.rb:114` 386.7, `app/mailers/user_mailer.rb:248` 200.5 |
| 3 | ActionMailer::MailDeliveryJob#perform | 2 / 2 | 688.0 / 688.0 | 0.0 | 4456.0 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 34.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 34.0, `GEM/mail/lib/mail/parsers/content_type_parser.rb:734` 30.0 | `app/mailers/user_mailer.rb:248` 255.0, `config/initializers/mail_delivery_job.rb:9` 74.0, `app/mailers/user_mailer.rb:244` 29.0 |
| 4 | TraceLinestringJob#perform | 16 / 16 | 335.4 / 335.4 | 0.0 | 336.3 | `GEM/prosopite/lib/prosopite.rb:419` 90.9, `GEM/prosopite/lib/prosopite.rb:418` 8.0, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 8.0 | `app/jobs/trace_linestring_job.rb:93` 154.6, `app/jobs/trace_linestring_job.rb:95` 105.9, `app/jobs/trace_linestring_job.rb:92` 25.0 |
| 5 | TraceDestroyerJob#perform | 1 / 1 | – / – |  | 379.0 |  |  |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/prosopite/lib/prosopite.rb:419` | 400.33 / 400.33 | 95% | `no app frame` 51%, `app/jobs/trace_linestring_job.rb:95` 8% | `query_caller = caller_locations` |
| 2 | `GEM/mail/lib/mail/utilities.rb:215` | 349.17 / 349.17 | 36% | `no app frame` 55%, `app/mailers/user_mailer.rb:95` 11% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 3 | `GEM/mail/lib/mail/encodings/8bit.rb:14` | 258.1 / 258.1 | 33% | `no app frame` 95%, `config/initializers/mail_delivery_job.rb:9` 5% | `!str.lines.find { \|line\| line.bytesize > 998 }` |
| 4 | `GEM/mail/lib/mail/field_list.rb:71` † | 174.48 / 174.48 | 36% | `no app frame` 56%, `app/mailers/user_mailer.rb:95` 11% | `fields = select { \|f\| f.responsible_for? field_name }` |
| 5 | `GEM/mail/lib/mail/fields/parameter_hash.rb:22` | 159.45 / 159.5 | 36% | `no app frame` 48%, `app/mailers/user_mailer.rb:95` 15% | `if k =~ /^#{key_pattern}(\*\|$)/i` |
| 6 | `GEM/mail/lib/mail/utilities.rb:226` | 92.76 / 92.76 | 36% | `no app frame` 66%, `app/mailers/user_mailer.rb:95` 7% | `str.to_s.downcase.tr(Constants::HYPHEN, Constants::UNDERSCORE)` |
| 7 | `GEM/mail/lib/mail/utilities.rb:291` | 68.19 / 68.19 | 36% | `no app frame` 52%, `app/mailers/user_mailer.rb:95` 10% | `value !~ /\S/` |
| 8 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` | 59.14 / 59.14 | 60% | `no app frame` 33%, `app/notifiers/gpx_import_failure_notifier.rb:7` 8% | `type_map.fetch(oid, fmod, sql_type) {` |
| 9 | `GEM/mail/lib/mail/parsers/content_type_parser.rb:734` | 55.4 / 55.45 | 36% | `app/mailers/user_mailer.rb:95` 27%, `app/mailers/user_mailer.rb:248` 18% | `_wide = data[p].ord` |
| 10 | `GEM/mail/lib/mail/fields/parameter_hash.rb:56` | 55.12 / 55.12 | 33% | `no app frame` 33%, `app/mailers/user_mailer.rb:95` 17% | `map.sort_by { \|a\| a.first.to_s }.map! do \|key_name, value\|` |

### Mails

| # | Mailer action | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | UserMailer#message_notification | 4 / 4 | 7778.3 / 7776.3 | -2.0 | 7254.8 | `GEM/mail/lib/mail/utilities.rb:215` 569.0, `GEM/mail/lib/mail/field_list.rb:71` 281.0, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 266.3 | `app/mailers/user_mailer.rb:114` 2787.7, `app/mailers/user_mailer.rb:255` 2246.7, `app/views/user_mailer/_message_body.html.erb:8` 283.0 |
| 2 | UserMailer#gpx_success | 3 / 3 | 3739.0 / 3739.0 | 0.0 | 4062.0 | `GEM/mail/lib/mail/utilities.rb:215` 398.0, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 237.0, `GEM/mail/lib/mail/field_list.rb:71` 197.0 | `app/mailers/user_mailer.rb:70` 2464.0, `app/mailers/user_mailer.rb:248` 255.0, `app/views/layouts/user_mailer.html.erb:15` 211.0 |
| 3 | UserMailer#follow_notification | 1 / 1 | – / – |  | 5722.0 |  |  |
| 4 | UserMailer#diary_comment_notification | 1 / 1 | – / – |  | 5603.0 |  |  |
| 5 | UserMailer#note_comment_notification | 1 / 1 | – / – |  | 5496.0 |  |  |
| 6 | UserMailer#changeset_comment_notification | 1 / 1 | – / – |  | 5427.0 |  |  |
| 7 | UserMailer#gpx_failure | 1 / 1 | – / – |  | 4263.0 |  |  |
| 8 | UserMailer#signup_confirm | 1 / 1 | – / – |  | 3741.0 |  |  |
| 9 | UserMailer#email_confirm | 1 / 1 | – / – |  | 3722.0 |  |  |
| 10 | UserMailer#lost_password | 1 / 1 | – / – |  | 3403.0 |  |  |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/mail/lib/mail/utilities.rb:215` | 452.53 / 452.53 | 100% | `app/mailers/user_mailer.rb:114` 24%, `app/mailers/user_mailer.rb:70` 15% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 2 | `GEM/mail/lib/mail/fields/parameter_hash.rb:22` | 234.0 / 234.0 | 100% | `app/mailers/user_mailer.rb:114` 23%, `app/mailers/user_mailer.rb:70` 17% | `if k =~ /^#{key_pattern}(\*\|$)/i` |
| 3 | `GEM/mail/lib/mail/field_list.rb:71` † | 223.07 / 223.07 | 100% | `app/mailers/user_mailer.rb:114` 24%, `app/mailers/user_mailer.rb:70` 15% | `fields = select { \|f\| f.responsible_for? field_name }` |
| 4 | `GEM/mail/lib/mail/parsers/content_type_parser.rb:734` | 170.73 / 170.73 | 100% | `app/mailers/user_mailer.rb:114` 20%, `app/mailers/user_mailer.rb:248` 16% | `_wide = data[p].ord` |
| 5 | `GEM/mail/lib/mail/fields/parameter_hash.rb:56` | 119.0 / 119.0 | 100% | `app/mailers/user_mailer.rb:114` 24%, `app/mailers/user_mailer.rb:70` 13% | `map.sort_by { \|a\| a.first.to_s }.map! do \|key_name, value\|` |
| 6 | `GEM/mail/lib/mail/utilities.rb:291` | 96.67 / 96.67 | 100% | `app/mailers/user_mailer.rb:248` 23%, `app/mailers/user_mailer.rb:114` 16% | `value !~ /\S/` |
| 7 | `GEM/mail/lib/mail/message.rb:2130` | 95.27 / 95.27 | 100% | `app/mailers/user_mailer.rb:114` 24%, `app/mailers/user_mailer.rb:70` 13% | `content_loc_name  = header[:content_location].location rescue nil` |
| 8 | `GEM/mail/lib/mail/utilities.rb:226` | 89.13 / 89.13 | 100% | `app/mailers/user_mailer.rb:114` 23%, `app/mailers/user_mailer.rb:70` 13% | `str.to_s.downcase.tr(Constants::HYPHEN, Constants::UNDERSCORE)` |
| 9 | `GEM/mail/lib/mail/parsers/address_lists_parser.rb:32009` | 79.93 / 79.93 | 100% | `app/mailers/user_mailer.rb:114` 27%, `app/mailers/user_mailer.rb:70` 20% | `_wide = data[p].ord` |
| 10 | `GEM/mail/lib/mail/parser_tools.rb:7` | 78.2 / 78.2 | 100% | `app/mailers/user_mailer.rb:248` 19%, `app/mailers/user_mailer.rb:114` 17% | `data.slice(from_bytes..to_bytes).force_encoding(Encoding::UTF_8)` |
