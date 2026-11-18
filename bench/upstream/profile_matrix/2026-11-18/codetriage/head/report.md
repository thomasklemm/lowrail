# Lowrail profile

Command: `bin/rails test --verbose`, test environment, ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux].

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 100 | 7273.4 | 13 | 4 | 0 | 0 |
| run2 | 1 | 100 | 7274.4 | 13 | 4 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.29 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/controllers/application_controller.rb:9` |  | 175.92 | 18.43 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 6%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 6%, `GEM/json/lib/json/common.rb:364` 4% | PagesController#index 34%, ReposController#show 18%, UsersController#show 13% | `if current_user&.admin?` |
| 2 | `app/views/pages/_repos_with_pagination.html.slim:1` |  | 69.94 | 16.93 | 0.75 | `GEM/rails-controller-testing/lib/rails/controller/testing/template_assertions.rb:39` 6%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 6%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:151` 5% | PagesController#index 100% | `ul.repo-list = render partial: "repos/repo", collection: repos, cached` |
| 3 | `app/views/pages/index.html.slim:4` |  | 56.5 | 14.26 | 1.0 | `RAILS/activesupport/lib/active_support/number_helper/number_converter.rb:160` 3%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 3%, `RAILS/activerecord/lib/active_record/relation/calculations.rb:512` 3% | PagesController#index 100% | `h2.hero-title-secondary Pick your favorite repos to receive a differen` |
| 4 | `app/views/layouts/_app.html.slim:12` |  | 44.96 | 10.08 | 0.56 | `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 19%, `RAILS/actionview/lib/action_view/template/resolver.rb:141` 9%, `RAILS/actionview/lib/action_view/template_path.rb:21` 9% | PagesController#index 42%, ReposController#show 20%, UsersController#edit 14% | `= render "footer"` |
| 5 | `app/views/layouts/_app.html.slim:6` |  | 44.63 | 10.08 | 0.56 | `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 19%, `RAILS/actionview/lib/action_view/template/resolver.rb:141` 9%, `RAILS/actionview/lib/action_view/template_path.rb:21` 9% | PagesController#index 42%, ReposController#show 20%, UsersController#edit 13% | `= render "flashes"` |
| 6 | `app/views/layouts/_app.html.slim:3` |  | 44.49 | 10.08 | 0.56 | `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 18%, `RAILS/actionview/lib/action_view/template/resolver.rb:181` 9%, `RAILS/actionview/lib/action_view/template/resolver.rb:141` 9% | PagesController#index 42%, ReposController#show 20%, UsersController#edit 13% | `= render "head"` |
| 7 | `app/views/layouts/_app.html.slim:7` |  | 44.4 | 10.08 | 0.56 | `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 18%, `RAILS/actionview/lib/action_view/template_path.rb:21` 9%, `RAILS/actionview/lib/action_view/template/resolver.rb:141` 9% | PagesController#index 42%, ReposController#show 20%, UsersController#edit 14% | `= render "nav"` |
| 8 | `app/views/repos/_repo.html.slim:2` |  | 41.07 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 5%, `RAILS/actionpack/lib/action_dispatch/journey/formatter.rb:128` 5%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 5% | PagesController#index 100% | `= link_to repo` |
| 9 | `app/views/layouts/application.html.slim:1` |  | 37.52 | 10.08 | 1.12 | `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 21%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:151` 6%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 6% | PagesController#index 45%, ReposController#show 18%, UsersController#edit 14% | `= render "layouts/app" do` |
| 10 | `app/models/github_fetcher/resource.rb:44` | `response` | 31.03 | 0.0 | 0.02 | `RUBY/psych/parser.rb:62` 13%, `RUBY/psych/tree_builder.rb:97` 13%, `RUBY/psych/nodes/node.rb:33` 6% | ReposController#create 100% | `GitHubBub.get(api_path, options)` |
| 11 | `app/controllers/users_controller.rb:41` | `update` | 30.4 | 6.31 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 14%, `RAILS/activesupport/lib/active_support/values/time_zone.rb:461` 6%, `RAILS/activemodel/lib/active_model/type/time.rb:56` 6% | UsersController#update 100% | `if @user.update(uparams)` |
| 12 | `app/views/users/_form.html.slim:30` |  | 30.16 | 0.0 | 2.0 | `RAILS/actionview/lib/action_view/helpers/form_options_helper.rb:797` 13%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 7%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 7% | UsersController#edit 100% | `options_for_select(available_times_of_day.map { \|time\| [time.to_format` |
| 13 | `app/views/pages/index.html.slim:31` |  | 28.92 | 7.09 | 1.25 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 4%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:151` 3%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 3% | PagesController#index 100% | `- Repo.select("DISTINCT language").map(&:language).compact.sort.each d` |
| 14 | `app/views/application/_head.html.slim:9` |  | 27.21 | 219.05 | 2.24 | `GEM/uri/lib/uri/rfc2396_parser.rb:291` 27%, `RAILS/actionview/lib/action_view/helpers/asset_tag_helper.rb:679` 6%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 6% | PagesController#index 44%, ReposController#show 18%, UsersController#edit 15% | `= stylesheet_link_tag "application", media: "all"` |
| 15 | `app/models/repo.rb:225` | `find_by_full_name` | 25.48 | 6.49 | 0.3 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 10%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 9%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 4% | ReposController#show 90%, ReposController#edit 10%, ReposController#update 0% | `Repo.find_by!(full_name: full_name)` |
| 16 | `app/controllers/pages_controller.rb:64` | `index` | 24.14 | 0.0 | 1.78 | `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:1329` 22%, `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:287` 15%, `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:250` 15% | PagesController#index 100% | `params.permit(:language, :per_page, :page)` |
| 17 | `app/services/git_hub_authenticator.rb:15` | `authenticate` | 23.82 | 5.76 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 18%, `RAILS/activemodel/lib/active_model/type/string.rb:39` 8%, `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 5% | Users::OmniauthCallbacksController#github 100% | `user.update!(user_params)` |
| 18 | `app/views/application/_head.html.slim:19` |  | 23.52 | 161.84 | 1.68 | `GEM/uri/lib/uri/rfc2396_parser.rb:291` 21%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 7%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 7% | PagesController#index 45%, ReposController#show 18%, UsersController#edit 14% | `= javascript_include_tag "application", async: true` |
| 19 | `app/controllers/users/omniauth_callbacks_controller.rb:13` | `github` | 23.04 | 7.08 | 0.12 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 9%, `GEM/tzinfo/lib/tzinfo/timestamp.rb:208` 4%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 3% | Users::OmniauthCallbacksController#github 100% | `sign_in_and_redirect @user, event: :authentication` |
| 20 | `app/models/github_fetcher/resource.rb:38` | `as_json` | 19.74 | 0.0 | 0.0 | `GEM/json/lib/json/common.rb:364` 100% | ReposController#create 100% | `@as_json \|\|= response.json_body` |
| 21 | `app/views/repos/show.html.slim:36` |  | 19.62 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/helpers/form_options_helper.rb:366` 19%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 7%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 7% | ReposController#show 100% | `=> f.select :email_limit, (0..20)` |
| 22 | `app/views/pages/index.html.slim:25` |  | 19.27 | 4.5 | 0.25 | `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 18%, `RAILS/actionview/lib/action_view/template_path.rb:21` 8%, `RAILS/actionview/lib/action_view/template/resolver.rb:181` 8% | PagesController#index 100% | `= render "down"` |
| 23 | `app/models/user.rb:121` | `account_delete_token` | 18.9 | 5.76 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 22%, `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 6%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 3% | UsersController#show 100% | `update_attribute(:account_delete_token, account_delete_token) unless n` |
| 24 | `app/views/pages/index.html.slim:13` |  | 17.22 | 5.95 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 5%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 4%, `RAILS/activerecord/lib/active_record/relation.rb:1507` 3% | PagesController#index 100% | `- if @repos_subs.present?` |
| 25 | `app/controllers/pages_controller.rb:42` | `index` | 16.1 | 0.0 | 0.15 | `GEM/will_paginate/lib/will_paginate/active_record.rb:115` 13%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 7%, `RAILS/activerecord/lib/active_record/relation.rb:98` 5% | PagesController#index 100% | `@repos_subs = current_user.repo_subscriptions.page(valid_params[:page]` |
| 26 | `app/views/pages/index.html.slim:36` |  | 15.27 | 4.5 | 0.5 | `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 25%, `GEM/rails-controller-testing/lib/rails/controller/testing/template_assertions.rb:39` 8%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 7% | PagesController#index 100% | `= render "repos_with_pagination", repos: @repos` |
| 27 | `app/controllers/repos_controller.rb:27` | `show` | 14.83 | 3.79 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 6%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 6%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 3% | ReposController#show 100% | `@repo_sub = current_user.repo_subscriptions_for(@repo.id).first if cur` |
| 28 | `app/controllers/repos_controller.rb:28` | `show` | 14.39 | 0.0 | 0.1 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 8%, `RAILS/activerecord/lib/active_record/relation.rb:77` 4%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 4% | ReposController#show 100% | `@subscribers = @repo.subscribers.select(:private, :avatar_url, :github` |
| 29 | `app/views/subscribers/_avatars.html.slim:1` |  | 14.29 | 3.81 | 0.1 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 8%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 3%, `RAILS/activerecord/lib/active_record/relation/query_methods.rb:1849` 3% | ReposController#show 100% | `- subscribers.each do \|subscriber\|` |
| 30 | `app/views/application/_head.html.slim:12` |  | 14.0 | 88.48 | 2.24 | `GEM/uri/lib/uri/rfc2396_parser.rb:291` 28%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 12%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 12% | PagesController#index 45%, ReposController#show 18%, UsersController#edit 14% | `= favicon_link_tag 'favicon.ico', rel: 'icon', type: 'image/x-icon'` |

927.96 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | ReposController#create | 4 / 4 | 6829.3 / 6829.7 | 0.3 | 5829.8 | `GEM/json/lib/json/common.rb:364` 669.0, `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 218.7, `RUBY/psych/parser.rb:62` 137.3 | `app/models/github_fetcher/resource.rb:44` 1034.3, `app/models/github_fetcher/resource.rb:38` 658.0, `app/controllers/repos_controller.rb:45` 445.3 |
| 2 | PagesController#index | 26 / 26 | 5957.4 / 5959.3 | 1.9 | 9023.9 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 217.1, `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 115.0, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 74.3 | `app/views/pages/_repos_with_pagination.html.slim:1` 279.8, `app/controllers/application_controller.rb:9` 236.7, `app/views/pages/index.html.slim:4` 226.0 |
| 3 | ReposController#show | 14 / 14 | 5776.5 / 5779.5 | 3.1 | 9896.2 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 217.2, `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 111.5, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 72.2 | `app/controllers/application_controller.rb:9` 245.0, `app/models/repo.rb:225` 177.1, `app/views/repos/show.html.slim:36` 150.9 |
| 4 | UsersController#edit | 9 / 9 | 5613.4 / 5611.8 | -1.6 | 7470.2 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 216.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 121.0, `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 100.0 | `app/views/users/_form.html.slim:30` 377.0, `app/views/users/_form.html.slim:13` 103.0, `app/controllers/application_controller.rb:9` 100.3 |
| 5 | UsersController#show | 7 / 7 | 5519.5 / 5521.8 | 2.3 | 8411.4 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 216.0, `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 86.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 74.0 | `app/controllers/application_controller.rb:9` 377.0, `app/models/user.rb:121` 315.0, `app/controllers/users_controller.rb:21` 169.0 |
| 6 | ReposController#new | 5 / 5 | 4915.5 / 4917.3 | 1.8 | 7972.8 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 216.0, `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 189.5, `RAILS/actionview/lib/action_view/template/resolver.rb:141` 67.0 | `app/controllers/application_controller.rb:9` 245.0, `app/views/repos/new.html.slim:43` 182.3, `app/views/repos/new.html.slim:49` 180.0 |
| 7 | ReposController#edit | 3 / 3 | 3314.0 / 3319.0 | 5.0 | 5086.0 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 217.0, `RAILS/activemodel/lib/active_model/attribute.rb:9` 70.5, `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 43.0 | `app/models/repo.rb:225` 123.0, `app/views/repos/edit.html.slim:3` 46.0, `app/views/layouts/_app.html.slim:12` 45.5 |
| 8 | UsersController#token_delete | 3 / 3 | 3228.0 / 3226.5 | -1.5 | 3847.7 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 217.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 45.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 43.5 | `app/controllers/users_controller.rb:53` 153.0, `app/controllers/users_controller.rb:58` 77.5, `app/controllers/application_controller.rb:9` 75.5 |
| 9 | RepoSubscriptionsController#create | 3 / 3 | 3159.0 / 3160.0 | 1.0 | 3165.7 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 217.0, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 49.0, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:151` 41.0 | `app/controllers/repo_subscriptions_controller.rb:37` 557.0, `app/controllers/repo_subscriptions_controller.rb:8` 326.0, `app/controllers/application_controller.rb:9` 278.0 |
| 10 | Users::OmniauthCallbacksController#github | 7 / 7 | 2618.8 / 2616.0 | -2.8 | 2745.3 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 216.0, `RAILS/activemodel/lib/active_model/attribute.rb:9` 105.0, `GEM/hashie/lib/hashie/mash.rb:374` 65.0 | `app/services/git_hub_authenticator.rb:15` 397.0, `app/controllers/users/omniauth_callbacks_controller.rb:13` 384.0, `app/services/git_hub_authenticator.rb:28` 171.0 |
| 11 | UsersController#update | 7 / 7 | 2276.7 / 2278.3 | 1.7 | 2279.7 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 216.2, `RAILS/activemodel/lib/active_model/attribute.rb:9` 70.0, `GEM/uri/lib/uri/common.rb:465` 62.7 | `app/controllers/users_controller.rb:41` 506.7, `app/controllers/application_controller.rb:9` 372.0, `app/controllers/users_controller.rb:42` 93.0 |
| 12 | UsersController#token_destroy | 2 / 2 | 2050.0 / 2044.0 | -6.0 | 2056.0 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 217.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 48.0, `GEM/uri/lib/uri/common.rb:465` 46.0 | `app/controllers/application_controller.rb:9` 373.0, `app/controllers/users_controller.rb:64` 349.0, `app/controllers/users_controller.rb:65` 82.0 |
| 13 | (no action name) | 7 / 7 | 867.8 / 865.7 | -2.2 | 866.0 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 216.0, `GEM/hashie/lib/hashie/mash.rb:374` 41.0, `GEM/hashie/lib/hashie/mash.rb:369` 22.0 |  |
| 14 | Devise::SessionsController#new | 1 / 1 | – / – |  | 7242.0 |  |  |
| 15 | ReposController#update | 1 / 1 | – / – |  | 2364.0 |  |  |
| 16 | IssueAssignmentsController#create | 1 / 1 | – / – |  | 2083.0 |  |  |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: pull requests from Lowrail's contributions ledger that change this line, and whether the app's version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` | `deep_dup` | 214.53 / 214.53 | 0.0 | 216.71 | 100% | Object, String |  | `no app frame` 100%, `app/models/repo.rb:225` 0% | `duplicable? ? dup : self` |
| 2 | `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` † | `shorten_identifier` | 76.42 / 76.42 | 0.0 | 77.57 | 64% | String, Array |  | `app/views/layouts/_app.html.slim:12` 12%, `app/views/layouts/_app.html.slim:6` 12% | `identifier.split('/').last(2).join('/')` |
| 3 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` | `build_handle` | 51.57 / 51.57 | 0.0 | 52.42 | 100% | Object | #59613 merged 2026-11-04, after this app's version, not released yet, #59235 merged 2026-10-21, after this app's version, not released yet | `no app frame` 26%, `app/views/pages/_repos_with_pagination.html.slim:1` 6% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 4 | `RUBY/ripper/lexer.rb:236` | `_push_token` | 49.86 / 49.86 | 0.0 | 72.17 | 6% | Object, Array |  | `no app frame` 55%, `app/views/users/edit.html.slim:9` 13% | `e = Elem.new([lineno(), column()], __callee__, tok, state())` |
| 5 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:151` † | `now` | 47.43 / 47.43 | 0.0 | 48.36 | 100% | Data |  | `no app frame` 23%, `app/views/pages/_repos_with_pagination.html.slim:1` 8% | `Time.now` |
| 6 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` | `tag_option` | 45.87 / 45.87 | 0.0 | 46.42 | 64% | String |  | `app/views/users/_form.html.slim:30` 5%, `app/views/pages/index.html.slim:33` 4% | `%(#{key}="#{value}")` |
| 7 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` | `html_safe` | 41.06 / 41.06 | 0.0 | 41.67 | 64% | String |  | `app/views/repos/_repo.html.slim:2` 6%, `app/views/users/_form.html.slim:30` 5% | `ActiveSupport::SafeBuffer.new(self)` |
| 8 | `GEM/uri/lib/uri/rfc2396_parser.rb:291` | `escape` | 40.39 / 40.39 | 0.0 | 41.14 | 64% | String |  | `app/views/application/_head.html.slim:9` 20%, `app/views/application/_head.html.slim:19` 14% | `str.gsub(unsafe) do` |
| 9 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` | `initialize` | 37.67 / 37.67 | 0.0 | 38.18 | 64% | String |  | `app/views/repos/_repo.html.slim:2` 6%, `app/views/users/_form.html.slim:30` 6% | `super` |
| 10 | `GEM/hashie/lib/hashie/mash.rb:374` | `convert_key` | 36.32 / 36.32 | 0.0 | 36.66 | 100% | String |  | `no app frame` 95%, `app/services/git_hub_authenticator.rb:49` 1% | `key.respond_to?(:to_sym) ? key.to_s : key` |
| 11 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | `#{method}` | 31.18 / 31.18 | 0.0 | 31.62 | 100% | Hash, Array |  | `no app frame` 40%, `app/views/layouts/_app.html.slim:12` 4% | `dispatch(:#{method}, ...)` |
| 12 | `GEM/json/lib/json/common.rb:364` | `parse` | 30.31 / 30.31 | 0.0 | 30.38 | 93% | String, Hash |  | `app/models/github_fetcher/resource.rb:38` 65%, `app/controllers/application_controller.rb:9` 25% | `Parser.parse(source, opts)` |
| 13 | `RUBY/ripper/lexer.rb:177` | `parse` | 30.07 / 30.07 | 0.0 | 43.8 | 6% | String, Array |  | `no app frame` 54%, `app/views/users/edit.html.slim:9` 13% | `super()` |
| 14 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` | `cast_result` | 29.08 / 29.08 | 0.0 | 29.22 | 70% | String, Array | #59278 merged 2026-10-22, after this app's version, not released yet | `app/controllers/application_controller.rb:9` 41%, `app/models/repo.rb:225` 10% | `ar_result = if result.fields.empty?` |
| 15 | `RAILS/actionview/lib/action_view/template/resolver.rb:141` | `_find_all` | 28.95 / 28.95 | 0.0 | 29.36 | 64% | Array |  | `no app frame` 21%, `app/views/layouts/_app.html.slim:7` 16% | `filter_and_sort_by_details(unbound_templates, requested_details).map d` |
| 16 | `RAILS/actionview/lib/action_view/template/resolver.rb:181` | `filter_and_sort_by_details` | 28.95 / 28.95 | 0.0 | 29.36 | 64% | Array |  | `no app frame` 21%, `app/views/layouts/_app.html.slim:7` 16% | `filtered_templates = templates.select do \|template\|` |
| 17 | `RAILS/activemodel/lib/active_model/attribute.rb:9` | `from_database` | 28.41 / 28.41 | 0.0 | 29.11 | 66% | Object |  | `no app frame` 29%, `app/controllers/users_controller.rb:41` 17% | `FromDatabase.new(name, value_before_type_cast, type, nil, value)` |
| 18 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` | `get_oid_type` | 26.93 / 26.93 | 0.0 | 27.03 | 70% | Array |  | `app/controllers/application_controller.rb:9` 43%, `app/models/repo.rb:225` 11% | `type_map.fetch(oid, fmod, sql_type) {` |
| 19 | `GEM/uri/lib/uri/common.rb:465` | `_decode_uri_component` | 26.35 / 26.64 | 0.29 | 26.57 | 94% | String, MatchData |  | `no app frame` 100% | `str.b.gsub(regexp, TBLDECWWWCOMP_).force_encoding(enc)` |
| 20 | `RUBY/ripper/lexer.rb:62` | `initialize` | 25.17 / 25.17 | 0.0 | 36.46 | 6% | String |  | `no app frame` 55%, `app/views/users/edit.html.slim:9` 13% | `@to_s = Ripper.lex_state_name(i)` |
| 21 | `RUBY/ripper/lexer.rb:95` | `initialize` | 24.93 / 24.93 | 0.0 | 36.09 | 6% | Object, Data |  | `no app frame` 55%, `app/views/users/edit.html.slim:9` 13% | `@state = State.new(state)` |
| 22 | `RUBY/ripper/lexer.rb:143` | `to_a` | 24.93 / 24.93 | 0.0 | 36.08 | 6% | Array |  | `no app frame` 55%, `app/views/users/edit.html.slim:9` 13% | `[@pos, @event, @tok, @state]` |
| 23 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:287` | `build_handle` | 24.21 / 24.21 | 0.0 | 24.68 | 100% | Array | #59235 merged 2026-10-21, after this app's version, not released yet | `no app frame` 25%, `app/views/pages/_repos_with_pagination.html.slim:1` 8% | `groups = groups_for(name).map do \|group_klass, grouped_listeners\|` |
| 24 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:294` | `build_handle` | 24.21 / 24.21 | 0.0 | 24.68 | 100% | Object |  | `no app frame` 25%, `app/views/pages/_repos_with_pagination.html.slim:1` 8% | `Handle.new(self, name, id, groups, payload)` |
| 25 | `RAILS/actionview/lib/action_view/template_path.rb:21` | `virtual` | 23.91 / 23.91 | 0.0 | 24.65 | 64% | String |  | `app/views/layouts/_app.html.slim:12` 21%, `app/views/layouts/_app.html.slim:7` 21% | `"#{prefix}/_#{name}"` |
| 26 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:237` | `tag_options` | 23.1 / 23.1 | 0.0 | 23.37 | 64% | String |  | `app/views/users/_form.html.slim:30` 9%, `app/views/repos/show.html.slim:36` 7% | `output = +""` |
| 27 | `GEM/rails-controller-testing/lib/rails/controller/testing/template_assertions.rb:39` | `setup_subscriptions` | 23.09 / 23.09 | 0.0 | 23.62 | 64% | String, Array |  | `app/views/pages/_repos_with_pagination.html.slim:1` 20%, `app/views/layouts/_app.html.slim:7` 11% | `@_partials[virtual_path.split("/").last] += 1` |
| 28 | `GEM/hashie/lib/hashie/mash.rb:369` | `method_suffix` | 21.78 / 21.78 | 0.0 | 22.0 | 100% | String |  | `no app frame` 100% | `method_name = method_name.to_s` |
| 29 | `GEM/hashie/lib/hashie/mash.rb:410` | `log_collision?` | 21.78 / 21.78 | 0.0 | 22.0 | 100% | Array |  | `no app frame` 100% | `return unless respond_to?(method_key)` |
| 30 | `RUBY/random/formatter.rb:174` † | `uuid` | 21.28 / 21.28 | 0.0 | 21.49 | 100% | String, Array |  | `no app frame` 98%, `app/controllers/repos_controller.rb:47` 1% | `ary.unpack("H8H4H4H4H12").join(?-)` |

## Dev/test-mode work

2294.8 of 5471.7 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | asset lookup | `GEM/sprockets/lib/sprockets/path_utils.rb:234` | 146.38 | 64% | `app/views/application/_head.html.slim:9` 33%, `app/views/application/_head.html.slim:19` 19% | `next unless File.basename(entry).start_with?(basename)` |
| 2 | template compile | `GEM/temple/lib/temple/mixins/dispatcher.rb:7` | 89.45 | 6% | `no app frame` 54%, `app/views/users/edit.html.slim:9` 8% | `multi = [:multi]` |
| 3 | asset lookup | `GEM/sprockets/lib/sprockets/http_utils.rb:17` | 73.77 | 64% | `app/views/application/_head.html.slim:9` 36%, `app/views/application/_head.html.slim:19` 33% | `v1, v2 = value.split('/'.freeze, 2)` |
| 4 | asset lookup | `GEM/sprockets/lib/sprockets/http_utils.rb:18` | 73.77 | 64% | `app/views/application/_head.html.slim:9` 36%, `app/views/application/_head.html.slim:19` 33% | `m1, m2 = matcher.split('/'.freeze, 2)` |
| 5 | asset lookup | `GEM/sprockets/lib/sprockets/resolve.rb:218` | 50.48 | 64% | `app/views/application/_head.html.slim:9` 25%, `app/views/application/_head.html.slim:19` 15% | `dirname    = File.dirname(File.join(load_path, logical_name))` |
| 6 | template compile | `GEM/temple/lib/temple/mixins/dispatcher.rb:69` | 41.34 | 6% | `no app frame` 54%, `app/views/users/edit.html.slim:9` 8% | `RUBY` |
| 7 | template compile | `GEM/temple/lib/temple/mixins/dispatcher.rb:98` | 40.71 | 6% | `no app frame` 56%, `app/views/users/edit.html.slim:9` 7% | `child.compile(level + 1, call_method).gsub("\n".freeze, "\n  ".freeze)` |
| 8 | asset lookup | `GEM/sprockets/lib/sprockets/path_utils.rb:101` | 40.46 | 64% | `app/views/application/_head.html.slim:9` 13%, `app/views/application/_footer.html.slim:21` 12% | `path.match?(/^\.\.?($\|#{SEPARATOR_PATTERN})/) ? true : false` |
| 9 | asset lookup | `GEM/sprockets/lib/sprockets/resolve.rb:292` | 37.86 | 64% | `app/views/application/_head.html.slim:9` 25%, `app/views/application/_head.html.slim:19` 15% | `return [], Set.new` |
| 10 | template compile | `GEM/temple/lib/temple/mixins/dispatcher.rb:81` | 36.68 | 6% | `no app frame` 54%, `app/views/users/edit.html.slim:9` 8% | `` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| gem: sprockets | 979.2 | 1127.5 | `path_utils.rb:234` 146.4, `http_utils.rb:17` 73.8, `http_utils.rb:18` 73.8 |
| rails: activesupport | 961.8 | 986.8 | `deep_dup.rb:16` 214.5, `fanout.rb:288` 51.6, `fanout.rb:151` 47.4 |
| gem: temple | 726.3 | 1107.5 | `dispatcher.rb:7` 89.5, `dispatcher.rb:69` 41.3, `dispatcher.rb:98` 40.7 |
| rails: actionview | 550.2 | 586.9 | `tag_helper.rb:309` 45.9, `log_subscriber.rb:61` 29.6, `resolver.rb:181` 29.0 |
| rails: activerecord | 541.5 | 556.8 | `database_statements.rb:165` 29.1, `postgresql_adapter.rb:880` 26.9, `log_subscriber.rb:49` 24.8 |
| rails: actionpack | 383.8 | 444.6 | `static.rb:145` 20.0, `logger.rb:12` 16.9, `visitors.rb:40` 15.6 |
| ruby stdlib | 216.8 | 316.6 | `lexer.rb:236` 49.9, `lexer.rb:177` 30.1, `lexer.rb:62` 25.2 |
| gem: slim | 168.5 | 270.5 | `parser.rb:148` 15.8, `parser.rb:491` 8.1, `parser.rb:511` 6.5 |
| ruby default gem: uri | 101.7 | 118.0 | `rfc2396_parser.rb:291` 40.4, `common.rb:465` 26.5, `common.rb:456` 18.2 |
| gem: hashie | 95.7 | 96.7 | `mash.rb:374` 36.3, `mash.rb:369` 21.8, `mash.rb:410` 21.8 |
| gem: rack-mini-profiler | 93.2 | 94.6 | `railtie.rb:158` 76.4, `mini_profiler.rb:423` 8.0, `client_settings.rb:27` 5.5 |
| app | 90.2 | 99.6 | `_footer.html.slim:21` 2.5, `_footer.html.slim:13` 2.5, `_head.html.slim:12` 2.5 |
| rails: activemodel | 88.6 | 92.5 | `attribute.rb:9` 28.4, `string.rb:39` 18.2, `builder.rb:37` 6.3 |
| gem: sentry-ruby | 78.6 | 79.9 | `hub.rb:292` 16.2, `configuration.rb:762` 6.4, `structured_logger.rb:132` 4.4 |
| gem: sentry-rails | 77.2 | 78.3 | `active_support_logger.rb:22` 16.2, `active_support_logger.rb:18` 16.2, `active_support_logger.rb:27` 16.2 |
| gem: rack | 68.8 | 70.8 | `request.rb:693` 8.3, `utils.rb:331` 6.5, `utils.rb:333` 5.5 |
| gem: logger | 65.6 | 66.6 | `logger.rb:685` 19.1, `log_device.rb:33` 15.5, `log_device.rb:165` 15.5 |
| gem: warden | 39.5 | 40.5 | `proxy.rb:334` 4.7, `proxy.rb:348` 4.0, `hooks.rb:10` 2.3 |
| gem: sprockets-rails | 36.0 | 36.5 | `helper.rb:357` 10.1, `helper.rb:81` 10.1, `helper.rb:356` 5.1 |
| gem: json | 32.5 | 32.6 | `common.rb:364` 30.3, `common.rb:1089` 2.2, `common.rb:454` 0.0 |
| gem: rails-controller-testing | 31.1 | 31.8 | `template_assertions.rb:39` 23.1, `template_assertions.rb:35` 6.1, `template_assertions.rb:27` 1.3 |
| gem: concurrent-ruby | 19.1 | 22.7 | `safe_initialization.rb:30` 5.9, `mutex_lockable_object.rb:32` 2.0, `mutex_lockable_object.rb:33` 2.0 |
| gem: i18n | 16.2 | 17.1 | `utils.rb:8` 2.7, `base.rb:58` 2.2, `i18n.rb:396` 2.2 |
| gem: will_paginate | 15.6 | 16.1 | `active_record.rb:115` 8.1, `page_number.rb:37` 2.6, `page_number.rb:16` 1.9 |
| gem: omniauth | 14.1 | 14.7 | `strategy.rb:470` 2.5, `strategy.rb:510` 2.0, `strategy.rb:169` 2.0 |
| gem: devise | 12.7 | 16.2 | `helpers.rb:128` 4.0, `orm.rb:43` 2.4, `rememberable.rb:56` 1.3 |
| gem: tzinfo | 11.5 | 11.9 | `timestamp.rb:208` 4.8, `timestamp.rb:193` 3.2, `constant_offset_data_timezone_info.rb:52` 3.2 |
| rails: railties | 8.9 | 9.4 | `logger.rb:57` 2.0, `logger.rb:42` 1.0, `logger.rb:24` 1.0 |
| gem: base64 | 7.6 | 7.7 | `base64.rb:283` 4.0, `base64.rb:310` 3.6 |
| gem: mail | 5.7 | 6.6 | `address_lists_parser.rb:32009` 2.4, `parser_tools.rb:7` 0.7, `utilities.rb:291` 0.7 |
| gem: judoscale-ruby | 5.0 | 5.1 | `metrics_store.rb:23` 1.0, `request_metrics.rb:40` 1.0, `request_middleware.rb:22` 1.0 |
| ruby default gem: securerandom | 3.5 | 3.6 | `securerandom.rb:71` 3.5 |
| gem: rack-session | 3.0 | 3.0 | `id.rb:401` 1.0, `id.rb:277` 1.0, `id.rb:275` 1.0 |
| gem: render_async | 2.9 | 3.6 | `view_helper.rb:83` 0.4, `view_helper.rb:53` 0.2, `view_helper.rb:23` 0.2 |
| gem: erubi | 2.6 | 8.4 | `erubi.rb:134` 1.4, `erubi.rb:137` 0.3, `erubi.rb:139` 0.2 |
| gem: valid_email | 2.0 | 2.4 | `validate_email.rb:85` 0.7, `validate_email.rb:30` 0.3, `validate_email.rb:69` 0.2 |
| rails: activejob | 1.6 | 2.0 | `log_subscriber.rb:207` 0.2, `enqueuing.rb:62` 0.1, `log_subscriber.rb:201` 0.1 |
| gem: bootsnap | 1.0 | 1.6 | `cache.rb:218` 0.3, `loaded_features_index.rb:118` 0.2, `loaded_features_index.rb:115` 0.2 |
| gem: bigdecimal | 0.6 | 0.6 | `util.rb:24` 0.6 |
| gem: orm_adapter | 0.6 | 0.6 | `active_record.rb:17` 0.6 |
| gem: local_time | 0.5 | 0.6 | `local_time_helper.rb:11` 0.2, `local_time_helper.rb:53` 0.1, `local_time_helper.rb:8` 0.1 |
| gem: scout_apm | 0.5 | 0.5 | `config.rb:463` 0.2, `agent.rb:20` 0.1, `agent.rb:65` 0.1 |
| gem: omniauth-rails_csrf_protection | 0.2 | 0.2 | `token_verifier.rb:59` 0.1, `token_verifier.rb:55` 0.1 |
| gem: omniauth-github | 0.1 | 0.1 | `github.rb:78` 0.1 |
| test harness: vcr | 0.0 | 22.2 | `http_interaction_list.rb:102` 0.0, `structs.rb:567` 0.0, `http_interaction_list.rb:38` 0.0 |
| gem: sassc-rails | 0.0 | 0.0 | `compressor.rb:26` 0.0, `compressor.rb:24` 0.0 |
| gem: rrrretry | 0.0 | 0.1 | `rrrretry.rb:34` 0.0, `rrrretry.rb:29` 0.0 |
| test harness: webmock | 0.0 | 12.6 | `uri.rb:34` 0.0, `hash_keys_stringifier.rb:18` 0.0, `query_mapper.rb:48` 0.0 |
| gem: coffee-script-source | 0.0 | 0.1 | `source.rb:4` 0.0 |
| gem: addressable | 0.0 | 7.5 | `uri.rb:2458` 0.0, `uri.rb:1619` 0.0, `uri.rb:165` 0.0 |
| gem: ffi | 0.0 | 0.0 | `enum.rb:121` 0.0 |
| gem: responders | 0.0 | 0.2 | `responder.rb:245` 0.0, `respond_with.rb:208` 0.0, `responder.rb:136` 0.0 |
| gem: coffee-script | 0.0 | 0.1 | `coffee_script.rb:42` 0.0, `coffee_script.rb:11` 0.0, `coffee_script.rb:38` 0.0 |
| gem: git_hub_bub | 0.0 | 0.2 | `request.rb:116` 0.0, `request.rb:23` 0.0, `request.rb:98` 0.0 |
| gem: msgpack | 0.0 | 0.2 | `factory.rb:29` 0.0, `factory.rb:9` 0.0, `factory.rb:37` 0.0 |
| gem: autoprefixer-rails | 0.0 | 13.9 | `processor.rb:124` 0.0, `processor.rb:121` 0.0, `processor.rb:117` 0.0 |
| gem: execjs | 0.0 | 0.5 | `external_runtime.rb:28` 0.0, `external_runtime.rb:210` 0.0, `external_runtime.rb:56` 0.0 |
| lowrail-profile | 0.0 | 0.0 | `profile.rb:55` 0.0, `profile.rb:65` 0.0 |
| gem: excon | 0.0 | 4.4 | `utils.rb:69` 0.0, `excon.rb:226` 0.0, `connection.rb:267` 0.0 |
| gem: sassc | 0.0 | 4.6 | `native.rb:55` 0.0, `functions_handler.rb:23` 0.0, `functions_handler.rb:10` 0.0 |
| gem: tilt | 0.0 | 1.0 | `mapping.rb:302` 0.0, `template.rb:341` 0.0, `sass.rb:0` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Jobs

| # | Job | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | BackgroundInactiveEmailJob#perform | 2 / 2 | 75448.0 / 75487.0 | 39.0 | 37895.0 | `GEM/css_parser/lib/css_parser/rule_set.rb:229` 1743.0, `GEM/kramdown/lib/kramdown/utils/entities.rb:0` 1570.0, `GEM/nokogiri/lib/nokogiri/css/node.rb:21` 1542.0 | `app/jobs/background_inactive_email_job.rb:7` 26114.0, `app/mailers/user_mailer.rb:94` 12807.0, `config/initializers/maildown_rails_71_fix.rb:11` 10139.0 |
| 2 | ActionMailer::MailDeliveryJob#perform | 3 / 3 | 26585.0 / 26585.0 | 0.0 | 27796.7 | `GEM/css_parser/lib/css_parser/rule_set.rb:229` 1309.5, `GEM/premailer/lib/premailer/adapter/nokogiri.rb:29` 940.0, `GEM/mail/lib/mail/utilities.rb:215` 680.0 | `app/jobs/send_daily_triage_email_job.rb:44` 18674.0, `app/mailers/user_mailer.rb:54` 1597.5, `app/views/user_mailer/send_daily_triage.md.erb:22` 791.5 |
| 3 | PopulateIssuesJob#perform | 5 / 5 | 1558.3 / 1558.3 | 0.0 | 2011.2 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 29.8, `RUBY/psych/parser.rb:62` 22.5, `RUBY/psych/tree_builder.rb:97` 21.5 | `app/models/github_fetcher/resource.rb:44` 334.3, `app/models/repo.rb:156` 222.5, `app/models/repo.rb:157` 132.5 |
| 4 | UpdateRepoInfoJob#perform | 3 / 3 | 572.0 / 572.0 | 0.0 | 564.3 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 17.0, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 12.5, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 11.0 | `app/models/repo.rb:204` 173.0, `app/models/repo.rb:189` 119.5, `app/models/github_fetcher/resource.rb:53` 12.0 |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/css_parser/lib/css_parser/rule_set.rb:229` | 352.85 / 352.85 | 31% | `app/jobs/send_daily_triage_email_job.rb:44` 41%, `app/jobs/send_single_triage_email_job.rb:16` 31% | `property = property.to_s.downcase` |
| 2 | `GEM/premailer/lib/premailer/adapter/nokogiri.rb:29` | 216.92 / 216.92 | 31% | `app/jobs/send_daily_triage_email_job.rb:44` 50%, `app/jobs/send_single_triage_email_job.rb:16` 25% | `selector.gsub!(/([\s]\|^)([\w]+)/) { \|m\| $1.to_s + $2.to_s.downcase }` |
| 3 | `GEM/mail/lib/mail/utilities.rb:215` | 156.92 / 156.92 | 31% | `app/jobs/send_daily_triage_email_job.rb:44` 37%, `app/jobs/background_inactive_email_job.rb:7` 19% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 4 | `GEM/css_parser/lib/css_parser/parser.rb:378` | 134.54 / 134.54 | 31% | `app/jobs/send_daily_triage_email_job.rb:44` 50%, `app/jobs/background_inactive_email_job.rb:7` 25% | `token = scanner.scan(RULESET_TOKENIZER_RX)` |
| 5 | `GEM/css_parser/lib/css_parser.rb:111` | 109.38 / 109.38 | 31% | `app/jobs/send_daily_triage_email_job.rb:44` 50%, `app/jobs/background_inactive_email_job.rb:7` 25% | `c = selector.scan(NON_ID_ATTRIBUTES_AND_PSEUDO_CLASSES_RX_NC).length` |
| 6 | `GEM/css_parser/lib/css_parser/rule_set.rb:673` | 97.38 / 97.38 | 31% | `app/jobs/send_daily_triage_email_job.rb:44` 47%, `app/jobs/send_single_triage_email_job.rb:16` 27% | `value = decs[(colon + 1)..]` |
| 7 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` | 96.92 / 96.92 | 15% | `app/models/random/cached_id_query.rb:27` 55%, `app/mailers/user_mailer.rb:74` 45% | `@method_name % attr_name` |
| 8 | `GEM/css_parser/lib/css_parser/rule_set.rb:676` | 96.0 / 96.0 | 31% | `app/jobs/send_daily_triage_email_job.rb:44` 47%, `app/jobs/send_single_triage_email_job.rb:16` 27% | `next if property.empty? \|\| value.empty? \|\| value.casecmp?(IMPORTANT)` |
| 9 | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:61` | 88.62 / 88.62 | 31% | `app/jobs/send_daily_triage_email_job.rb:44` 50%, `app/jobs/send_single_triage_email_job.rb:16` 25% | `xpath(*(xpaths + [ns, handler, binds].compact))` |
| 10 | `GEM/mail/lib/mail/fields/parameter_hash.rb:22` | 84.69 / 84.69 | 31% | `app/jobs/send_daily_triage_email_job.rb:44` 33%, `app/jobs/send_single_triage_email_job.rb:16` 17% | `if k =~ /^#{key_pattern}(\*\|$)/i` |

### Mails

| # | Mailer action | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | UserMailer.deliver_mail | 2 / 2 | 2174.0 / 2175.0 | 1.0 | 2268.0 | `GEM/mail/lib/mail/utilities.rb:215` 314.0, `GEM/mail/lib/mail/field_list.rb:71` 156.0, `GEM/mail/lib/mail/parsers/content_transfer_encoding_parser.rb:380` 136.0 |  |
| 2 | UserMailer#poke_inactive | 1 / 1 | – / – |  | 5792.0 |  |  |
| 3 | UserMailer#send_triage | 1 / 1 | – / – |  | 4695.0 |  |  |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/mail/lib/mail/utilities.rb:215` | 199.75 / 199.75 | 100% | `no app frame` 65%, `app/mailers/user_mailer.rb:94` 18% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 2 | `GEM/mail/lib/mail/field_list.rb:71` | 99.0 / 99.0 | 100% | `no app frame` 65%, `app/mailers/user_mailer.rb:94` 18% | `fields = select { \|f\| f.responsible_for? field_name }` |
| 3 | `GEM/mail/lib/mail/fields/parameter_hash.rb:22` | 98.5 / 98.5 | 100% | `no app frame` 53%, `app/mailers/user_mailer.rb:94` 24% | `if k =~ /^#{key_pattern}(\*\|$)/i` |
| 4 | `GEM/mail/lib/mail/utilities.rb:226` | 52.0 / 52.0 | 100% | `no app frame` 73%, `app/mailers/user_mailer.rb:94` 13% | `str.to_s.downcase.tr(Constants::HYPHEN, Constants::UNDERSCORE)` |
| 5 | `GEM/mail/lib/mail/utilities.rb:291` | 50.0 / 50.0 | 100% | `no app frame` 71%, `app/mailers/user_mailer.rb:75` 15% | `value !~ /\S/` |
| 6 | `GEM/kramdown/lib/kramdown/element.rb:498` | 34.25 / 34.25 | 50% | `config/initializers/maildown_rails_71_fix.rb:11` 100% | `@children = []` |
| 7 | `GEM/mail/lib/mail/parsers/content_transfer_encoding_parser.rb:380` | 34.0 / 34.0 | 50% | `no app frame` 100% | `_wide = data[p].ord` |
| 8 | `GEM/kramdown/lib/kramdown/parser/base.rb:115` | 31.0 / 31.0 | 50% | `config/initializers/maildown_rails_71_fix.rb:11` 100% | `tree.children << Element.new(type, text, nil, location: location)` |
| 9 | `GEM/mail/lib/mail/parser_tools.rb:7` | 28.0 / 28.0 | 100% | `no app frame` 42%, `app/mailers/user_mailer.rb:75` 29% | `data.slice(from_bytes..to_bytes).force_encoding(Encoding::UTF_8)` |
| 10 | `GEM/mail/lib/mail/message.rb:1426` | 28.0 / 28.0 | 100% | `no app frame` 70%, `app/mailers/user_mailer.rb:94` 15% | `tmp = header[:content_type].main_type rescue nil` |
