# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails test --verbose`
* Ruby: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux]
* Rails: 8.1.4, test environment
* Counted in run 1: 100 requests, 13 jobs, 4 mail windows; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 100 | 5944.0 | 13 | 4 | 0 | 0 |
| run2 | 1 | 100 | 5944.6 | 13 | 4 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.45 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/controllers/application_controller.rb:9` |  | 175.92 | 18.43 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 6%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 6%, `GEM/json/lib/json/common.rb:364` 4% | PagesController#index 34%, ReposController#show 18%, UsersController#show 13% | `if current_user&.admin?` |
| 2 | `app/views/pages/_repos_with_pagination.html.slim:1` |  | 69.93 | 16.93 | 0.75 | `GEM/rails-controller-testing/lib/rails/controller/testing/template_assertions.rb:39` 6%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 6%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:151` 5% | PagesController#index 100% | `ul.repo-list = render partial: "repos/repo", collection: repos, cached` |
| 3 | `app/views/pages/index.html.slim:4` |  | 56.5 | 14.26 | 1.0 | `RAILS/activerecord/lib/active_record/relation/calculations.rb:512` 3%, `RAILS/activesupport/lib/active_support/number_helper/number_to_delimited_converter.rb:16` 3%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 3% | PagesController#index 100% | `h2.hero-title-secondary Pick your favorite repos to receive a differen` |
| 4 | `app/views/layouts/_app.html.slim:12` |  | 44.96 | 10.08 | 0.56 | `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 19%, `RAILS/actionview/lib/action_view/template_path.rb:21` 9%, `RAILS/actionview/lib/action_view/template/resolver.rb:141` 9% | PagesController#index 42%, ReposController#show 20%, UsersController#edit 14% | `= render "footer"` |
| 5 | `app/views/layouts/_app.html.slim:6` |  | 44.63 | 10.08 | 0.56 | `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 19%, `RAILS/actionview/lib/action_view/template/resolver.rb:181` 9%, `RAILS/actionview/lib/action_view/template_path.rb:21` 9% | PagesController#index 42%, ReposController#show 20%, UsersController#edit 13% | `= render "flashes"` |
| 6 | `app/views/layouts/_app.html.slim:3` |  | 44.49 | 10.08 | 0.56 | `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 18%, `RAILS/actionview/lib/action_view/template/resolver.rb:181` 9%, `RAILS/actionview/lib/action_view/template_path.rb:21` 9% | PagesController#index 42%, ReposController#show 20%, UsersController#edit 13% | `= render "head"` |
| 7 | `app/views/layouts/_app.html.slim:7` |  | 44.4 | 10.08 | 0.56 | `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 18%, `RAILS/actionview/lib/action_view/template/resolver.rb:181` 9%, `RAILS/actionview/lib/action_view/template/resolver.rb:141` 9% | PagesController#index 42%, ReposController#show 20%, UsersController#edit 14% | `= render "nav"` |
| 8 | `app/views/repos/_repo.html.slim:2` |  | 41.07 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 5%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 5%, `RAILS/actionpack/lib/action_dispatch/journey/formatter.rb:128` 5% | PagesController#index 100% | `= link_to repo` |
| 9 | `app/views/layouts/application.html.slim:1` |  | 37.52 | 10.08 | 1.12 | `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 21%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:151` 6%, `GEM/rails-controller-testing/lib/rails/controller/testing/template_assertions.rb:39` 6% | PagesController#index 45%, ReposController#show 18%, UsersController#edit 14% | `= render "layouts/app" do` |
| 10 | `app/models/github_fetcher/resource.rb:44` | `response` | 31.03 | 0.0 | 0.02 | `RUBY/psych/parser.rb:62` 13%, `RUBY/psych/tree_builder.rb:97` 13%, `RUBY/psych/nodes/node.rb:33` 6% | ReposController#create 100% | `GitHubBub.get(api_path, options)` |
| 11 | `app/controllers/users_controller.rb:41` | `update` | 30.4 | 6.31 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 14%, `RAILS/activesupport/lib/active_support/values/time_zone.rb:461` 6%, `RAILS/activemodel/lib/active_model/type/time.rb:56` 6% | UsersController#update 100% | `if @user.update(uparams)` |
| 12 | `app/views/users/_form.html.slim:30` |  | 30.16 | 0.0 | 2.0 | `RAILS/actionview/lib/action_view/helpers/form_options_helper.rb:797` 13%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 7%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 7% | UsersController#edit 100% | `options_for_select(available_times_of_day.map { \|time\| [time.to_format` |
| 13 | `app/views/pages/index.html.slim:31` |  | 28.92 | 7.09 | 1.25 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 4%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:151` 3%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 3% | PagesController#index 100% | `- Repo.select("DISTINCT language").map(&:language).compact.sort.each d` |
| 14 | `app/models/repo.rb:225` | `find_by_full_name` | 25.48 | 6.49 | 0.3 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 10%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 9%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 4% | ReposController#show 90%, ReposController#edit 10%, ReposController#update 0% | `Repo.find_by!(full_name: full_name)` |
| 15 | `app/controllers/pages_controller.rb:64` | `index` | 24.14 | 0.0 | 1.78 | `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:1329` 22%, `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:1287` 15%, `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:250` 15% | PagesController#index 100% | `params.permit(:language, :per_page, :page)` |
| 16 | `app/services/git_hub_authenticator.rb:15` | `authenticate` | 23.82 | 5.76 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 18%, `RAILS/activemodel/lib/active_model/type/string.rb:39` 8%, `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 5% | Users::OmniauthCallbacksController#github 100% | `user.update!(user_params)` |
| 17 | `app/controllers/users/omniauth_callbacks_controller.rb:13` | `github` | 23.04 | 7.08 | 0.12 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 9%, `GEM/tzinfo/lib/tzinfo/timestamp.rb:208` 4%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 3% | Users::OmniauthCallbacksController#github 100% | `sign_in_and_redirect @user, event: :authentication` |
| 18 | `app/views/application/_head.html.slim:9` |  | 19.93 | 6.69 | 2.24 | `RAILS/actionview/lib/action_view/helpers/asset_tag_helper.rb:679` 8%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 8%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 8% | PagesController#index 44%, ReposController#show 18%, UsersController#edit 16% | `= stylesheet_link_tag "application", media: "all"` |
| 19 | `app/models/github_fetcher/resource.rb:38` | `as_json` | 19.74 | 0.0 | 0.0 | `GEM/json/lib/json/common.rb:364` 100% | ReposController#create 100% | `@as_json \|\|= response.json_body` |
| 20 | `app/views/repos/show.html.slim:36` |  | 19.62 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/helpers/form_options_helper.rb:366` 19%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 7%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 7% | ReposController#show 100% | `=> f.select :email_limit, (0..20)` |
| 21 | `app/views/pages/index.html.slim:25` |  | 19.26 | 4.5 | 0.25 | `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 18%, `RAILS/actionview/lib/action_view/template/resolver.rb:181` 8%, `RAILS/actionview/lib/action_view/template/resolver.rb:141` 8% | PagesController#index 100% | `= render "down"` |
| 22 | `app/models/user.rb:121` | `account_delete_token` | 18.9 | 5.76 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 22%, `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 6%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 3% | UsersController#show 100% | `update_attribute(:account_delete_token, account_delete_token) unless n` |
| 23 | `app/views/application/_head.html.slim:19` |  | 18.48 | 5.04 | 1.68 | `RAILS/actionview/lib/action_view/helpers/asset_tag_helper.rb:679` 9%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 9%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 9% | PagesController#index 45%, ReposController#show 18%, UsersController#edit 14% | `= javascript_include_tag "application", async: true` |
| 24 | `app/views/pages/index.html.slim:13` |  | 17.22 | 5.95 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 5%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 4%, `RAILS/activerecord/lib/active_record/relation.rb:1507` 3% | PagesController#index 100% | `- if @repos_subs.present?` |
| 25 | `app/controllers/pages_controller.rb:42` | `index` | 16.1 | 0.0 | 0.15 | `GEM/will_paginate/lib/will_paginate/active_record.rb:115` 13%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 7%, `RAILS/activerecord/lib/active_record/relation.rb:98` 5% | PagesController#index 100% | `@repos_subs = current_user.repo_subscriptions.page(valid_params[:page]` |
| 26 | `app/views/pages/index.html.slim:36` |  | 15.26 | 4.5 | 0.5 | `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 25%, `GEM/rails-controller-testing/lib/rails/controller/testing/template_assertions.rb:39` 8%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:151` 7% | PagesController#index 100% | `= render "repos_with_pagination", repos: @repos` |
| 27 | `app/controllers/repos_controller.rb:27` | `show` | 14.83 | 3.79 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 6%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 6%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 3% | ReposController#show 100% | `@repo_sub = current_user.repo_subscriptions_for(@repo.id).first if cur` |
| 28 | `app/controllers/repos_controller.rb:28` | `show` | 14.39 | 0.0 | 0.1 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 8%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 4%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 4% | ReposController#show 100% | `@subscribers = @repo.subscribers.select(:private, :avatar_url, :github` |
| 29 | `app/views/subscribers/_avatars.html.slim:1` |  | 14.29 | 3.81 | 0.1 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 8%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 3%, `RAILS/activerecord/lib/active_record/relation/query_methods.rb:1849` 3% | ReposController#show 100% | `- subscribers.each do \|subscriber\|` |
| 30 | `app/views/repos/_issues.html.slim:1` |  | 13.57 | 4.21 | 0.1 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 7%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 4%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:151` 3% | ReposController#show 100% | `- if @issues.each && @issues.empty?` |

892.37 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | ReposController#create | 4 / 4 | 6238.3 / 6246.0 | 7.7 | 5379.8 | `GEM/json/lib/json/common.rb:364` 669.0, `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 218.7, `RUBY/psych/parser.rb:62` 137.3 | `app/models/github_fetcher/resource.rb:44` 1034.3, `app/models/github_fetcher/resource.rb:38` 658.0, `app/controllers/repos_controller.rb:45` 446.7 |
| 2 | ReposController#show | 14 / 14 | 4445.5 / 4444.8 | -0.7 | 8537.1 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 217.2, `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 111.5, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 72.2 | `app/controllers/application_controller.rb:9` 245.0, `app/models/repo.rb:225` 177.1, `app/views/repos/show.html.slim:36` 150.9 |
| 3 | PagesController#index | 26 / 26 | 4281.2 / 4281.8 | 0.7 | 6677.7 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 217.1, `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 115.0, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 74.3 | `app/views/pages/_repos_with_pagination.html.slim:1` 279.7, `app/controllers/application_controller.rb:9` 236.7, `app/views/pages/index.html.slim:4` 226.0 |
| 4 | UsersController#edit | 9 / 9 | 3930.3 / 3933.1 | 2.9 | 5786.6 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 216.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 121.0, `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 100.0 | `app/views/users/_form.html.slim:30` 377.0, `app/views/users/_form.html.slim:13` 103.0, `app/controllers/application_controller.rb:9` 100.3 |
| 5 | UsersController#show | 7 / 7 | 3839.5 / 3841.8 | 2.3 | 6731.3 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 216.0, `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 86.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 74.0 | `app/controllers/application_controller.rb:9` 377.0, `app/models/user.rb:121` 315.0, `app/controllers/users_controller.rb:21` 169.0 |
| 6 | ReposController#new | 5 / 5 | 3239.8 / 3239.8 | 0.0 | 6288.4 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 216.0, `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 189.5, `RAILS/actionview/lib/action_view/template/resolver.rb:181` 67.0 | `app/controllers/application_controller.rb:9` 245.0, `app/views/repos/new.html.slim:43` 182.3, `app/views/repos/new.html.slim:49` 180.0 |
| 7 | RepoSubscriptionsController#create | 3 / 3 | 3118.5 / 3118.0 | -0.5 | 3124.7 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 217.0, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 49.0, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:151` 41.0 | `app/controllers/repo_subscriptions_controller.rb:37` 557.0, `app/controllers/repo_subscriptions_controller.rb:8` 326.0, `app/controllers/application_controller.rb:9` 278.0 |
| 8 | Users::OmniauthCallbacksController#github | 7 / 7 | 2571.3 / 2579.3 | 8.0 | 2708.3 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 216.0, `RAILS/activemodel/lib/active_model/attribute.rb:9` 105.0, `GEM/hashie/lib/hashie/mash.rb:374` 65.0 | `app/services/git_hub_authenticator.rb:15` 397.0, `app/controllers/users/omniauth_callbacks_controller.rb:13` 384.0, `app/services/git_hub_authenticator.rb:28` 171.0 |
| 9 | ReposController#edit | 3 / 3 | 2452.0 / 2452.5 | 0.5 | 3948.3 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 217.0, `RAILS/activemodel/lib/active_model/attribute.rb:9` 70.5, `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` 43.0 | `app/models/repo.rb:225` 123.0, `app/views/repos/edit.html.slim:3` 46.0, `app/views/layouts/_app.html.slim:3` 45.5 |
| 10 | UsersController#token_delete | 3 / 3 | 2362.0 / 2357.0 | -5.0 | 2710.7 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 217.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 45.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 43.5 | `app/controllers/users_controller.rb:53` 153.0, `app/controllers/users_controller.rb:58` 77.5, `app/controllers/application_controller.rb:9` 75.5 |
| 11 | UsersController#update | 7 / 7 | 2235.5 / 2234.0 | -1.5 | 2234.0 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 216.2, `RAILS/activemodel/lib/active_model/attribute.rb:9` 70.0, `GEM/uri/lib/uri/common.rb:465` 63.5 | `app/controllers/users_controller.rb:41` 506.7, `app/controllers/application_controller.rb:9` 372.0, `app/controllers/users_controller.rb:42` 93.0 |
| 12 | UsersController#token_destroy | 2 / 2 | 2007.0 / 1993.0 | -14.0 | 2009.0 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 217.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 48.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 46.0 | `app/controllers/application_controller.rb:9` 373.0, `app/controllers/users_controller.rb:64` 349.0, `app/controllers/users_controller.rb:65` 82.0 |
| 13 | (no action name) | 7 / 7 | 824.2 / 826.2 | 2.0 | 826.1 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 216.0, `GEM/hashie/lib/hashie/mash.rb:374` 41.0, `RUBY/random/formatter.rb:174` 21.0 |  |
| 14 | Devise::SessionsController#new | 1 / 1 | – / – |  | 5549.0 |  |  |
| 15 | ReposController#update | 1 / 1 | – / – |  | 2314.0 |  |  |
| 16 | IssueAssignmentsController#create | 1 / 1 | – / – |  | 2033.0 |  |  |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` | `deep_dup` | 214.53 / 214.53 | 0.0 | 216.71 | 100% | Object, String |  | `no app frame` 100%, `app/models/repo.rb:225` 0% | `duplicable? ? dup : self` |
| 2 | `GEM/rack-mini-profiler/lib/mini_profiler_rails/railtie.rb:158` † | `shorten_identifier` | 76.42 / 76.42 | 0.0 | 77.57 | 64% | String, Array |  | `app/views/layouts/_app.html.slim:12` 12%, `app/views/layouts/_app.html.slim:6` 12% | `identifier.split('/').last(2).join('/')` |
| 3 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` | `build_handle` | 51.57 / 51.57 | 0.0 | 52.42 | 100% | Object | #59613 merged 2026-11-04, after this app's version, not released yet, #59235 merged 2026-10-21, after this app's version, not released yet | `no app frame` 26%, `app/views/pages/_repos_with_pagination.html.slim:1` 6% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 4 | `RUBY/ripper/lexer.rb:236` | `_push_token` | 49.86 / 49.86 | 0.0 | 72.17 | 6% | Object, Array |  | `no app frame` 55%, `app/views/users/edit.html.slim:9` 13% | `e = Elem.new([lineno(), column()], __callee__, tok, state())` |
| 5 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:151` † | `now` | 47.43 / 47.43 | 0.0 | 48.36 | 100% | Data |  | `no app frame` 23%, `app/views/pages/_repos_with_pagination.html.slim:1` 8% | `Time.now` |
| 6 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` | `tag_option` | 45.87 / 45.87 | 0.0 | 46.42 | 64% | String |  | `app/views/users/_form.html.slim:30` 5%, `app/views/pages/index.html.slim:33` 4% | `%(#{key}="#{value}")` |
| 7 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` | `html_safe` | 41.06 / 41.06 | 0.0 | 41.67 | 64% | String |  | `app/views/repos/_repo.html.slim:2` 6%, `app/views/users/_form.html.slim:30` 5% | `ActiveSupport::SafeBuffer.new(self)` |
| 8 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` | `initialize` | 37.67 / 37.67 | 0.0 | 38.18 | 64% | String |  | `app/views/repos/_repo.html.slim:2` 6%, `app/views/users/_form.html.slim:30` 6% | `super` |
| 9 | `GEM/hashie/lib/hashie/mash.rb:374` | `convert_key` | 36.32 / 36.32 | 0.0 | 36.66 | 100% | String |  | `no app frame` 95%, `app/services/git_hub_authenticator.rb:49` 1% | `key.respond_to?(:to_sym) ? key.to_s : key` |
| 10 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | `#{method}` | 31.18 / 31.18 | 0.0 | 31.62 | 100% | Hash, Array |  | `no app frame` 40%, `app/views/layouts/_app.html.slim:6` 4% | `dispatch(:#{method}, ...)` |
| 11 | `GEM/json/lib/json/common.rb:364` | `parse` | 30.21 / 30.21 | 0.0 | 30.32 | 92% | String, Hash |  | `app/models/github_fetcher/resource.rb:38` 65%, `app/controllers/application_controller.rb:9` 25% | `Parser.parse(source, opts)` |
| 12 | `RUBY/ripper/lexer.rb:177` | `parse` | 30.07 / 30.07 | 0.0 | 43.8 | 6% | String, Array |  | `no app frame` 54%, `app/views/users/edit.html.slim:9` 13% | `super()` |
| 13 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` | `cast_result` | 29.08 / 29.08 | 0.0 | 29.22 | 70% | String, Array | #59278 merged 2026-10-22, after this app's version, not released yet | `app/controllers/application_controller.rb:9` 41%, `app/models/repo.rb:225` 10% | `ar_result = if result.fields.empty?` |
| 14 | `RAILS/actionview/lib/action_view/template/resolver.rb:141` | `_find_all` | 28.95 / 28.95 | 0.0 | 29.36 | 64% | Array |  | `no app frame` 21%, `app/views/layouts/_app.html.slim:3` 16% | `filter_and_sort_by_details(unbound_templates, requested_details).map d` |
| 15 | `RAILS/actionview/lib/action_view/template/resolver.rb:181` | `filter_and_sort_by_details` | 28.95 / 28.95 | 0.0 | 29.36 | 64% | Array |  | `no app frame` 21%, `app/views/layouts/_app.html.slim:3` 16% | `filtered_templates = templates.select do \|template\|` |
| 16 | `RAILS/activemodel/lib/active_model/attribute.rb:9` | `from_database` | 28.41 / 28.41 | 0.0 | 29.11 | 66% | Object |  | `no app frame` 29%, `app/services/git_hub_authenticator.rb:15` 17% | `FromDatabase.new(name, value_before_type_cast, type, nil, value)` |
| 17 | `GEM/uri/lib/uri/common.rb:465` | `_decode_uri_component` | 26.88 / 27.33 | 0.45 | 27.17 | 94% | String, MatchData |  | `no app frame` 100% | `str.b.gsub(regexp, TBLDECWWWCOMP_).force_encoding(enc)` |
| 18 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` | `get_oid_type` | 26.93 / 26.93 | 0.0 | 27.03 | 70% | Array |  | `app/controllers/application_controller.rb:9` 43%, `app/models/repo.rb:225` 11% | `type_map.fetch(oid, fmod, sql_type) {` |
| 19 | `RUBY/ripper/lexer.rb:62` | `initialize` | 25.09 / 25.11 | 0.02 | 36.33 | 6% | String |  | `no app frame` 55%, `app/views/users/edit.html.slim:9` 13% | `@to_s = Ripper.lex_state_name(i)` |
| 20 | `RUBY/ripper/lexer.rb:95` | `initialize` | 24.93 / 24.93 | 0.0 | 36.09 | 6% | Object, Data |  | `no app frame` 55%, `app/views/users/edit.html.slim:9` 13% | `@state = State.new(state)` |
| 21 | `RUBY/ripper/lexer.rb:143` | `to_a` | 24.93 / 24.93 | 0.0 | 36.08 | 6% | Array |  | `no app frame` 55%, `app/views/users/edit.html.slim:9` 13% | `[@pos, @event, @tok, @state]` |
| 22 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:287` | `build_handle` | 24.21 / 24.21 | 0.0 | 24.68 | 100% | Array | #59235 merged 2026-10-21, after this app's version, not released yet | `no app frame` 25%, `app/views/pages/_repos_with_pagination.html.slim:1` 8% | `groups = groups_for(name).map do \|group_klass, grouped_listeners\|` |
| 23 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:294` | `build_handle` | 24.21 / 24.21 | 0.0 | 24.68 | 100% | Object |  | `no app frame` 25%, `app/views/pages/_repos_with_pagination.html.slim:1` 8% | `Handle.new(self, name, id, groups, payload)` |
| 24 | `RAILS/actionview/lib/action_view/template_path.rb:21` | `virtual` | 23.91 / 23.91 | 0.0 | 24.65 | 64% | String |  | `app/views/layouts/_app.html.slim:6` 21%, `app/views/layouts/_app.html.slim:12` 21% | `"#{prefix}/_#{name}"` |
| 25 | `GEM/rails-controller-testing/lib/rails/controller/testing/template_assertions.rb:39` | `setup_subscriptions` | 23.22 / 23.0 | -0.22 | 23.64 | 64% | String, Array |  | `app/views/pages/_repos_with_pagination.html.slim:1` 20%, `app/views/layouts/_app.html.slim:12` 11% | `@_partials[virtual_path.split("/").last] += 1` |
| 26 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:237` | `tag_options` | 23.1 / 23.1 | 0.0 | 23.37 | 64% | String |  | `app/views/users/_form.html.slim:30` 9%, `app/views/repos/show.html.slim:36` 7% | `output = +""` |
| 27 | `RUBY/random/formatter.rb:174` † | `uuid` | 21.28 / 21.28 | 0.0 | 21.49 | 100% | String, Array |  | `no app frame` 98%, `app/controllers/repo_subscriptions_controller.rb:9` 1% | `ary.unpack("H8H4H4H4H12").join(?-)` |
| 28 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` | `cast_result` | 20.99 / 20.99 | 0.0 | 21.33 | 70% | String, Array |  | `app/controllers/application_controller.rb:9` 28%, `app/views/pages/_repos_with_pagination.html.slim:1` 20% | `ActiveRecord::Result.new(fields, result.values, types.freeze, affected` |
| 29 | `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` | `file_readable?` | 19.98 / 19.98 | 0.0 | 20.25 | 75% | String, Array |  | `no app frame` 100% | `file_path = File.join(@root, path.b)` |
| 30 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` | `xml_name_escape` | 19.3 / 19.3 | 0.0 | 19.48 | 64% | String |  | `app/views/users/_form.html.slim:30` 11%, `app/views/application/_footer.html.slim:21` 10% | `name = name.to_s` |

## Dev/test-mode work

1299.8 of 4393.5 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | template compile | `GEM/temple/lib/temple/mixins/dispatcher.rb:7` | 89.45 | 6% | `no app frame` 54%, `app/views/users/edit.html.slim:9` 8% | `multi = [:multi]` |
| 2 | template compile | `GEM/temple/lib/temple/mixins/dispatcher.rb:96` | 46.69 | 6% | `no app frame` 54%, `app/views/users/edit.html.slim:9` 8% | `each do \|key, child\|` |
| 3 | template compile | `GEM/temple/lib/temple/mixins/dispatcher.rb:69` | 41.52 | 6% | `no app frame` 54%, `app/views/users/edit.html.slim:9` 8% | `RUBY` |
| 4 | template compile | `GEM/temple/lib/temple/mixins/dispatcher.rb:109` | 35.49 | 6% | `no app frame` 53%, `app/views/users/edit.html.slim:9` 8% | `# based on the including classe's methods.` |
| 5 | template compile | `GEM/temple/lib/temple/static_analyzer.rb:59` | 33.96 | 6% | `no app frame` 55%, `app/views/users/edit.html.slim:9` 12% | `SyntaxChecker.new(code).parse` |
| 6 | template compile | `GEM/temple/lib/temple/mixins/dispatcher.rb:79` | 32.68 | 6% | `no app frame` 54%, `app/views/users/edit.html.slim:9` 8% | `class DispatchNode < Hash` |
| 7 | template compile | `GEM/temple/lib/temple/map.rb:26` | 31.9 | 6% | `no app frame` 37%, `app/views/layouts/_app.html.slim:7` 6% | `@map.inject([]) {\|keys, h\| keys.concat(h.keys) }.uniq` |
| 8 | template compile | `GEM/temple/lib/temple/mixins/dispatcher.rb:81` | 31.09 | 6% | `no app frame` 54%, `app/views/users/edit.html.slim:9` 8% | `` |
| 9 | debug logging | `RAILS/actionview/lib/action_view/log_subscriber.rb:61` | 29.64 | 64% | `no app frame` 38%, `app/views/layouts/application.html.slim:1` 8% | `string = string.sub(rails_root, "")` |
| 10 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:177` | 27.12 | 91% | `app/controllers/application_controller.rb:9` 12%, `app/views/pages/index.html.slim:4` 11% | `"\e[#{modes.join(";")}m" if modes.any?` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activesupport | 961.8 | 986.8 | `deep_dup.rb:16` 214.5, `fanout.rb:288` 51.6, `fanout.rb:151` 47.4 |
| gem: temple | 726.0 | 1107.5 | `dispatcher.rb:7` 89.5, `dispatcher.rb:96` 46.7, `dispatcher.rb:69` 41.5 |
| rails: actionview | 550.2 | 586.8 | `tag_helper.rb:309` 45.9, `log_subscriber.rb:61` 29.6, `resolver.rb:141` 29.0 |
| rails: activerecord | 541.5 | 556.8 | `database_statements.rb:165` 29.1, `postgresql_adapter.rb:880` 26.9, `log_subscriber.rb:49` 24.8 |
| rails: actionpack | 383.5 | 444.3 | `static.rb:145` 20.0, `logger.rb:12` 16.9, `visitors.rb:40` 15.6 |
| ruby stdlib | 216.6 | 309.5 | `lexer.rb:236` 49.9, `lexer.rb:177` 30.1, `lexer.rb:62` 25.1 |
| gem: slim | 168.4 | 270.4 | `parser.rb:148` 15.8, `parser.rb:491` 8.1, `parser.rb:511` 6.5 |
| gem: rack-mini-profiler | 93.2 | 94.6 | `railtie.rb:158` 76.4, `mini_profiler.rb:423` 8.0, `client_settings.rb:27` 5.5 |
| app | 90.2 | 99.6 | `_head.html.slim:9` 2.5, `_head.html.slim:12` 2.5, `_head.html.slim:11` 2.5 |
| rails: activemodel | 88.5 | 92.5 | `attribute.rb:9` 28.4, `string.rb:39` 18.2, `builder.rb:37` 6.3 |
| gem: sentry-ruby | 78.7 | 80.0 | `hub.rb:292` 16.2, `configuration.rb:762` 6.4, `structured_logger.rb:132` 4.4 |
| gem: sentry-rails | 77.2 | 78.3 | `active_support_logger.rb:22` 16.2, `active_support_logger.rb:18` 16.2, `active_support_logger.rb:27` 16.2 |
| gem: rack | 68.8 | 70.8 | `request.rb:693` 8.3, `utils.rb:331` 6.5, `utils.rb:333` 5.5 |
| gem: logger | 65.6 | 66.6 | `logger.rb:685` 19.1, `log_device.rb:33` 15.5, `log_device.rb:165` 15.5 |
| ruby default gem: uri | 62.2 | 63.7 | `common.rb:465` 27.1, `common.rb:456` 18.8, `common.rb:108` 1.8 |
| gem: hashie | 52.2 | 52.7 | `mash.rb:374` 36.3, `mash.rb:101` 5.9, `mash.rb:196` 5.9 |
| gem: warden | 39.5 | 40.5 | `proxy.rb:334` 4.7, `proxy.rb:348` 4.0, `manager.rb:52` 2.3 |
| gem: json | 32.4 | 32.5 | `common.rb:364` 30.2, `common.rb:1089` 2.2 |
| gem: rails-controller-testing | 31.1 | 31.8 | `template_assertions.rb:39` 23.1, `template_assertions.rb:35` 6.1, `template_assertions.rb:27` 1.3 |
| gem: sprockets-rails | 20.8 | 21.1 | `helper.rb:81` 10.1, `helper.rb:199` 1.3, `helper.rb:157` 1.3 |
| gem: concurrent-ruby | 19.0 | 19.6 | `safe_initialization.rb:30` 5.9, `mutex_lockable_object.rb:32` 2.0, `mutex_lockable_object.rb:33` 2.0 |
| gem: i18n | 16.2 | 17.1 | `utils.rb:8` 2.7, `base.rb:58` 2.2, `i18n.rb:396` 2.2 |
| gem: will_paginate | 15.6 | 16.1 | `active_record.rb:115` 8.1, `page_number.rb:37` 2.6, `page_number.rb:16` 1.9 |
| gem: omniauth | 14.1 | 14.7 | `strategy.rb:470` 2.5, `strategy.rb:169` 2.0, `strategy.rb:510` 2.0 |
| gem: devise | 12.7 | 16.2 | `helpers.rb:128` 4.0, `orm.rb:43` 2.4, `rememberable.rb:56` 1.3 |
| gem: tzinfo | 11.5 | 11.9 | `timestamp.rb:208` 4.8, `timestamp.rb:193` 3.2, `constant_offset_data_timezone_info.rb:52` 3.2 |
| rails: railties | 8.9 | 9.4 | `logger.rb:57` 2.0, `logger.rb:37` 1.0, `logger.rb:61` 1.0 |
| gem: base64 | 7.6 | 7.7 | `base64.rb:283` 4.0, `base64.rb:310` 3.6 |
| gem: mail | 5.7 | 6.6 | `address_lists_parser.rb:32009` 2.4, `parser_tools.rb:7` 0.7, `utilities.rb:291` 0.7 |
| gem: judoscale-ruby | 5.0 | 5.1 | `request_middleware.rb:24` 1.0, `request_middleware.rb:22` 1.0, `request_metrics.rb:40` 1.0 |
| ruby default gem: securerandom | 3.5 | 3.6 | `securerandom.rb:71` 3.5 |
| gem: rack-session | 3.0 | 3.0 | `id.rb:401` 1.0, `id.rb:275` 1.0, `id.rb:277` 1.0 |
| gem: render_async | 2.9 | 3.6 | `view_helper.rb:83` 0.4, `view_helper.rb:23` 0.2, `view_helper.rb:38` 0.2 |
| gem: erubi | 2.6 | 8.4 | `erubi.rb:134` 1.4, `erubi.rb:137` 0.3, `erubi.rb:139` 0.2 |
| gem: valid_email | 2.0 | 2.4 | `validate_email.rb:85` 0.7, `validate_email.rb:30` 0.3, `validate_email.rb:69` 0.2 |
| rails: activejob | 1.6 | 2.0 | `log_subscriber.rb:207` 0.2, `enqueuing.rb:62` 0.1, `log_subscriber.rb:201` 0.1 |
| gem: bootsnap | 1.0 | 1.5 | `cache.rb:218` 0.3, `loaded_features_index.rb:118` 0.2, `loaded_features_index.rb:115` 0.2 |
| gem: bigdecimal | 0.6 | 0.6 | `util.rb:24` 0.6 |
| gem: orm_adapter | 0.6 | 0.6 | `active_record.rb:17` 0.6 |
| gem: local_time | 0.5 | 0.6 | `local_time_helper.rb:11` 0.2, `local_time_helper.rb:53` 0.1, `local_time_helper.rb:8` 0.1 |
| gem: scout_apm | 0.5 | 0.5 | `config.rb:463` 0.2, `agent.rb:20` 0.1, `agent.rb:65` 0.1 |
| gem: omniauth-rails_csrf_protection | 0.2 | 0.2 | `token_verifier.rb:59` 0.1, `token_verifier.rb:55` 0.1 |
| gem: omniauth-github | 0.1 | 0.1 | `github.rb:78` 0.1 |
| gem: responders | 0.0 | 0.2 | `respond_with.rb:48` 0.0, `responder.rb:161` 0.0, `respond_with.rb:214` 0.0 |
| gem: rrrretry | 0.0 | 0.1 | `rrrretry.rb:34` 0.0, `rrrretry.rb:29` 0.0 |
| gem: tilt | 0.0 | 1.0 | `sass.rb:80` 0.0, `sass.rb:21` 0.0, `mapping.rb:321` 0.0 |
| gem: sassc | 0.0 | 2.4 | `native.rb:51` 0.0, `script.rb:12` 0.0, `functions_handler.rb:17` 0.0 |
| gem: msgpack | 0.0 | 0.2 | `factory.rb:27` 0.0, `factory.rb:9` 0.0, `factory.rb:37` 0.0 |
| gem: addressable | 0.0 | 7.5 | `uri.rb:1417` 0.0, `uri.rb:239` 0.0, `uri.rb:2491` 0.0 |
| lowrail-profile | 0.0 | 0.0 | `profile.rb:66` 0.0, `profile.rb:56` 0.0 |
| test harness: vcr | 0.0 | 22.2 | `structs.rb:351` 0.0, `structs.rb:507` 0.0, `linked_cassette.rb:58` 0.0 |
| gem: git_hub_bub | 0.0 | 0.2 | `request.rb:40` 0.0, `request.rb:19` 0.0, `request.rb:116` 0.0 |
| gem: excon | 0.0 | 4.4 | `mock.rb:30` 0.0, `connection.rb:437` 0.0, `utils.rb:73` 0.0 |
| gem: ffi | 0.0 | 0.0 | `enum.rb:121` 0.0 |
| test harness: webmock | 0.0 | 12.6 | `headers.rb:29` 0.0, `excon_adapter.rb:116` 0.0, `stub_registry.rb:80` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Jobs

| # | Job | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | BackgroundInactiveEmailJob#perform | 2 / 2 | 69627.0 / 69646.0 | 19.0 | 34974.5 | `GEM/css_parser/lib/css_parser/rule_set.rb:229` 1743.0, `GEM/kramdown/lib/kramdown/utils/entities.rb:0` 1569.0, `GEM/nokogiri/lib/nokogiri/css/node.rb:21` 1542.0 | `app/jobs/background_inactive_email_job.rb:7` 26011.0, `app/mailers/user_mailer.rb:94` 12808.0, `config/initializers/maildown_rails_71_fix.rb:11` 10120.0 |
| 2 | ActionMailer::MailDeliveryJob#perform | 3 / 3 | 25798.5 / 25798.5 | 0.0 | 27078.3 | `GEM/css_parser/lib/css_parser/rule_set.rb:229` 1309.5, `GEM/premailer/lib/premailer/adapter/nokogiri.rb:29` 940.0, `GEM/mail/lib/mail/utilities.rb:215` 680.0 | `app/jobs/send_daily_triage_email_job.rb:44` 18626.0, `app/mailers/user_mailer.rb:54` 1599.5, `app/views/user_mailer/send_daily_triage.md.erb:22` 791.5 |
| 3 | PopulateIssuesJob#perform | 5 / 5 | 1558.3 / 1558.3 | 0.0 | 1970.8 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 29.8, `RUBY/psych/parser.rb:62` 22.5, `RUBY/psych/tree_builder.rb:97` 21.5 | `app/models/github_fetcher/resource.rb:44` 334.3, `app/models/repo.rb:156` 222.5, `app/models/repo.rb:157` 132.5 |
| 4 | UpdateRepoInfoJob#perform | 3 / 3 | 572.0 / 572.0 | 0.0 | 564.3 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 17.0, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 12.5, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 11.0 | `app/models/repo.rb:204` 173.0, `app/models/repo.rb:189` 119.5, `app/models/repo.rb:47` 12.0 |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/css_parser/lib/css_parser/rule_set.rb:229` | 352.85 / 352.85 | 31% | `app/jobs/send_daily_triage_email_job.rb:44` 41%, `app/jobs/send_single_triage_email_job.rb:16` 31% | `property = property.to_s.downcase` |
| 2 | `GEM/premailer/lib/premailer/adapter/nokogiri.rb:29` | 216.92 / 216.92 | 31% | `app/jobs/send_daily_triage_email_job.rb:44` 50%, `app/jobs/background_inactive_email_job.rb:7` 25% | `selector.gsub!(/([\s]\|^)([\w]+)/) { \|m\| $1.to_s + $2.to_s.downcase }` |
| 3 | `GEM/mail/lib/mail/utilities.rb:215` | 156.92 / 156.92 | 31% | `app/jobs/send_daily_triage_email_job.rb:44` 37%, `app/jobs/background_inactive_email_job.rb:7` 19% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 4 | `GEM/css_parser/lib/css_parser/parser.rb:378` | 134.54 / 134.54 | 31% | `app/jobs/send_daily_triage_email_job.rb:44` 50%, `app/jobs/background_inactive_email_job.rb:7` 25% | `token = scanner.scan(RULESET_TOKENIZER_RX)` |
| 5 | `GEM/css_parser/lib/css_parser.rb:111` | 109.38 / 109.38 | 31% | `app/jobs/send_daily_triage_email_job.rb:44` 50%, `app/jobs/background_inactive_email_job.rb:7` 25% | `c = selector.scan(NON_ID_ATTRIBUTES_AND_PSEUDO_CLASSES_RX_NC).length` |
| 6 | `GEM/css_parser/lib/css_parser/rule_set.rb:673` | 97.38 / 97.38 | 31% | `app/jobs/send_daily_triage_email_job.rb:44` 47%, `app/jobs/send_single_triage_email_job.rb:16` 27% | `value = decs[(colon + 1)..]` |
| 7 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` | 96.92 / 96.92 | 15% | `app/models/random/cached_id_query.rb:27` 55%, `app/mailers/user_mailer.rb:74` 45% | `@method_name % attr_name` |
| 8 | `GEM/css_parser/lib/css_parser/rule_set.rb:676` | 96.0 / 96.0 | 31% | `app/jobs/send_daily_triage_email_job.rb:44` 47%, `app/jobs/send_single_triage_email_job.rb:16` 27% | `next if property.empty? \|\| value.empty? \|\| value.casecmp?(IMPORTANT)` |
| 9 | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:61` | 88.62 / 88.62 | 31% | `app/jobs/send_daily_triage_email_job.rb:44` 50%, `app/jobs/send_single_triage_email_job.rb:16` 25% | `xpath(*(xpaths + [ns, handler, binds].compact))` |
| 10 | `GEM/mail/lib/mail/fields/parameter_hash.rb:22` | 85.0 / 84.92 | 31% | `app/jobs/send_daily_triage_email_job.rb:44` 33%, `app/jobs/send_single_triage_email_job.rb:16` 17% | `if k =~ /^#{key_pattern}(\*\|$)/i` |

### Mails

| # | Mailer action | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | UserMailer.deliver_mail | 2 / 2 | 2177.0 / 2177.0 | 0.0 | 2270.0 | `GEM/mail/lib/mail/utilities.rb:215` 314.0, `GEM/mail/lib/mail/field_list.rb:71` 156.0, `GEM/mail/lib/mail/parsers/content_transfer_encoding_parser.rb:380` 136.0 |  |
| 2 | UserMailer#poke_inactive | 1 / 1 | – / – |  | 5264.0 |  |  |
| 3 | UserMailer#send_triage | 1 / 1 | – / – |  | 4188.0 |  |  |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/mail/lib/mail/utilities.rb:215` | 199.75 / 199.75 | 100% | `no app frame` 65%, `app/mailers/user_mailer.rb:94` 18% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 2 | `GEM/mail/lib/mail/field_list.rb:71` | 99.0 / 99.0 | 100% | `no app frame` 65%, `app/mailers/user_mailer.rb:75` 18% | `fields = select { \|f\| f.responsible_for? field_name }` |
| 3 | `GEM/mail/lib/mail/fields/parameter_hash.rb:22` | 98.5 / 98.5 | 100% | `no app frame` 53%, `app/mailers/user_mailer.rb:94` 24% | `if k =~ /^#{key_pattern}(\*\|$)/i` |
| 4 | `GEM/mail/lib/mail/utilities.rb:226` | 52.0 / 52.0 | 100% | `no app frame` 73%, `app/mailers/user_mailer.rb:94` 13% | `str.to_s.downcase.tr(Constants::HYPHEN, Constants::UNDERSCORE)` |
| 5 | `GEM/mail/lib/mail/utilities.rb:291` | 50.0 / 50.0 | 100% | `no app frame` 71%, `app/mailers/user_mailer.rb:75` 15% | `value !~ /\S/` |
| 6 | `GEM/kramdown/lib/kramdown/element.rb:498` | 34.25 / 34.25 | 50% | `config/initializers/maildown_rails_71_fix.rb:11` 100% | `@children = []` |
| 7 | `GEM/mail/lib/mail/parsers/content_transfer_encoding_parser.rb:380` | 34.0 / 34.0 | 50% | `no app frame` 100% | `_wide = data[p].ord` |
| 8 | `GEM/kramdown/lib/kramdown/parser/base.rb:115` | 31.0 / 31.0 | 50% | `config/initializers/maildown_rails_71_fix.rb:11` 100% | `tree.children << Element.new(type, text, nil, location: location)` |
| 9 | `GEM/mail/lib/mail/parser_tools.rb:7` | 28.0 / 28.0 | 100% | `no app frame` 42%, `app/mailers/user_mailer.rb:94` 29% | `data.slice(from_bytes..to_bytes).force_encoding(Encoding::UTF_8)` |
| 10 | `GEM/mail/lib/mail/message.rb:1426` | 28.0 / 28.0 | 100% | `no app frame` 70%, `app/mailers/user_mailer.rb:94` 15% | `tmp = header[:content_type].main_type rescue nil` |
