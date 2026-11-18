# Lowrail profile

Command: `bin/rails test:all -v`, test environment, ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux].

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 74 | 3271.1 | 0 | 0 | 0 | 0 |
| run2 | 1 | 74 | 3270.2 | 0 | 0 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 1.68 objects per request; 2 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/controllers/users_controller.rb:20` | `index` | 78.96 | 16.05 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 4%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 3% | UsersController#index 100% | `if user.photo.attached?` |
| 2 | `app/controllers/contacts_controller.rb:19` | `index` | 47.5 | 7.18 | 0.09 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 17%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 5%, `RAILS/activerecord/lib/active_record/result.rb:244` 2% | ContactsController#index 100% | `json.data(paged_contacts) do \|contact\|` |
| 3 | `app/controllers/application_controller.rb:13` |  | 39.55 | 5.84 | 0.43 | `RAILS/activemodel/lib/active_model/serialization.rb:131` 8%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 7%, `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 4% | OrganizationsController#edit 19%, UsersController#edit 16%, OrganizationsController#index 15% | `current_user.as_json(` |
| 4 | `app/views/layouts/application.html.erb:20` |  | 34.3 | 141.41 | 0.73 | `GEM/json/lib/json/common.rb:364` 27%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 10%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 6% | Users::SessionsController#new 22%, UsersController#index 17%, OrganizationsController#index 17% | `<%= vite_javascript_tag 'application' %>` |
| 5 | `app/controllers/organizations_controller.rb:14` | `index` | 30.26 | 3.43 | 0.32 | `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 8%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:90` 6%, `GEM/inertia_rails/lib/inertia_rails/renderer.rb:129` 5% | OrganizationsController#index 100% | `render inertia: 'Organizations/Index',` |
| 6 | `app/controllers/users_controller.rb:13` | `index` | 26.66 | 3.43 | 0.32 | `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 6%, `GEM/inertia_rails/lib/inertia_rails/renderer.rb:129` 5%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:90` 4% | UsersController#index 100% | `render inertia: 'Users/Index',` |
| 7 | `app/controllers/contacts_controller.rb:15` | `index` | 24.97 | 2.38 | 0.28 | `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 9%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:90` 7%, `GEM/inertia_rails/lib/inertia_rails/renderer.rb:129` 5% | ContactsController#index 100% | `render inertia: 'Contacts/Index',` |
| 8 | `app/controllers/users/sessions_controller.rb:4` | `new` | 23.86 | 4.32 | 0.32 | `GEM/inertia_rails/lib/inertia_rails/renderer.rb:129` 4%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 3%, `RAILS/actionview/lib/action_view/template/resolver.rb:141` 3% | Users::SessionsController#new 100%, Users::SessionsController#create 0% | `render inertia: 'Auth/Login', props: {}` |
| 9 | `app/controllers/users_controller.rb:47` | `edit` | 22.49 | 3.27 | 0.2 | `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 9%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:90` 7%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:120` 5% | UsersController#edit 100% | `render inertia: 'Users/Edit',` |
| 10 | `app/controllers/contacts_controller.rb:7` | `index` | 20.97 | 3.04 | 0.19 | `RAILS/activerecord/lib/arel/visitors/to_sql.rb:801` 4%, `RAILS/activesupport/lib/active_support/delegation.rb:146` 3%, `GEM/rack/lib/rack/request.rb:693` 3% | ContactsController#index 100% | `pagy(` |
| 11 | `app/controllers/users_controller.rb:26` | `index` | 18.24 | 0.0 | 1.09 | `GEM/cancancan/lib/cancan/ability.rb:80` 26%, `GEM/cancancan/lib/cancan/ability.rb:77` 20%, `GEM/cancancan/lib/cancan/ability/rules.rb:56` 6% | UsersController#index 100% | `json.can { json.edit_user can?(:edit, user) }` |
| 12 | `app/controllers/organizations_controller.rb:18` | `index` | 17.7 | 4.03 | 0.11 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 23%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 8%, `RAILS/activemodel/lib/active_model/type/string.rb:39` 7% | OrganizationsController#index 100% | `json.data(` |
| 13 | `app/controllers/users_controller.rb:17` | `index` | 15.07 | 3.51 | 0.11 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 19%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 9%, `RAILS/activerecord/lib/arel/visitors/to_sql.rb:801` 4% | UsersController#index 100% | `json.array! @users do \|user\|` |
| 14 | `app/controllers/users_controller.rb:61` | `edit` | 14.66 | 2.97 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 4%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 3% | UsersController#edit 100% | `if @user.photo.attached?` |
| 15 | `app/controllers/organizations_controller.rb:7` | `index` | 14.03 | 3.0 | 0.22 | `GEM/rack/lib/rack/request.rb:693` 5%, `RAILS/actionpack/lib/action_dispatch/http/url.rb:325` 2%, `GEM/pagy/lib/pagy.rb:67` 2% | OrganizationsController#index 100% | `pagy(` |
| 16 | `app/controllers/concerns/inertia_json.rb:26` | `jbuilder` | 13.54 | 0.0 | 0.55 | `RAILS/actionpack/lib/abstract_controller/rendering.rb:66` 22%, `RAILS/actionview/lib/action_view/base.rb:230` 21%, `RAILS/actionpack/lib/abstract_controller/rendering.rb:63` 12% | OrganizationsController#index 19%, UsersController#index 19%, ContactsController#index 17% | `JbuilderTemplate.new(view_context, &).attributes!` |
| 17 | `app/controllers/contacts_controller.rb:43` | `edit` | 12.54 | 1.16 | 0.12 | `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 10%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:90` 8%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:120` 7% | ContactsController#edit 100% | `render inertia: 'Contacts/Edit',` |
| 18 | `app/controllers/organizations_controller.rb:33` | `edit` | 12.15 | 1.16 | 0.12 | `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 10%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:90` 8%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:120` 7% | OrganizationsController#edit 100% | `render inertia: 'Organizations/Edit',` |
| 19 | `app/controllers/users/sessions_controller.rb:9` | `create` | 11.23 | 0.7 | 0.0 | `RAILS/actionview/lib/action_view/template/error.rb:0` 11%, `RAILS/actionview/lib/action_view/template/resolver.rb:209` 4%, `RAILS/actionview/lib/action_view/template_path.rb:23` 3% | Users::SessionsController#create 100% | `super` |
| 20 | `app/views/layouts/application.html.erb:17` |  | 11.19 | 175.84 | 0.49 | `GEM/json/lib/json/common.rb:364` 83%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 4%, `RAILS/actionview/lib/action_view/helpers/asset_url_helper.rb:280` 2% | Users::SessionsController#new 22%, OrganizationsController#index 17%, UsersController#edit 17% | `<link rel="icon" type="image/png" href="<%= vite_asset_path('images/fa` |
| 21 | `app/controllers/concerns/inertia_csrf.rb:30` | `set_csrf_cookie` | 10.36 | 0.0 | 0.0 | `RUBY/openssl/hmac.rb:36` 11%, `GEM/securerandom/lib/securerandom.rb:71` 8%, `RAILS/actionpack/lib/action_dispatch/request/session.rb:116` 6% | UsersController#index 19%, OrganizationsController#index 19%, ContactsController#index 16% | `value: form_authenticity_token,` |
| 22 | `app/controllers/contacts_controller.rb:65` | `edit` | 9.73 | 1.3 | 0.04 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 5%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 3% | ContactsController#edit 100% | `json.array! current_user.organizations.order(:name), :id, :name` |
| 23 | `app/controllers/organizations_controller.rb:53` | `edit` | 6.45 | 1.3 | 0.04 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 9%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `RAILS/activerecord/lib/active_record/relation.rb:77` 3% | OrganizationsController#edit 100% | `json.array! @organization.contacts.order_by_name,` |
| 24 | `app/controllers/dashboard_controller.rb:3` | `index` | 5.54 | 1.05 | 0.04 | `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 5%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:90` 4%, `GEM/inertia_rails/lib/inertia_rails/renderer.rb:129` 3% | DashboardController#index 100% | `render inertia: 'Dashboard/Index',` |
| 25 | `app/controllers/users_controller.rb:30` | `index` | 5.24 | 0.0 | 0.11 | `GEM/cancancan/lib/cancan/ability.rb:80` 27%, `GEM/cancancan/lib/cancan/ability.rb:77` 21%, `GEM/cancancan/lib/cancan/ability.rb:309` 6% | UsersController#index 100% | `create_user: can?(:create, User),` |
| 26 | `app/models/ability.rb:13` | `initialize` | 5.2 | 0.0 | 0.95 | `GEM/cancancan/lib/cancan/rule.rb:137` 18%, `GEM/cancancan/lib/cancan/ability.rb:145` 18%, `GEM/cancancan/lib/cancan/rule.rb:121` 9% | OrganizationsController#index 23%, UsersController#index 23%, ContactsController#index 20% | `can :read, User, account_id: user.account_id, deleted_at: nil` |
| 27 | `config/initializers/pagy.rb:12` | `data_hash` | 4.59 | 0.0 | 0.41 | `GEM/pagy/lib/pagy/modules/abilities/linkable.rb:47` 13%, `GEM/pagy/lib/pagy/modules/abilities/linkable.rb:68` 13%, `GEM/pagy/lib/pagy/toolbox/helpers/support/series.rb:15` 9% | OrganizationsController#index 54%, ContactsController#index 46% | `super.tap { \|hash\| hash[:series] = __send__(:series) }` |
| 28 | `app/models/concerns/soft_delete.rb:7` |  | 4.36 | 0.0 | 0.51 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:166` 12%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` 12%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:29` 12% | OrganizationsController#index 37%, UsersController#index 32%, ContactsController#index 32% | `scope :not_trashed, -> { where(deleted_at: nil) }` |
| 29 | `app/models/ability.rb:17` | `initialize` | 4.26 | 0.0 | 0.95 | `GEM/cancancan/lib/cancan/ability.rb:145` 22%, `GEM/cancancan/lib/cancan/rule.rb:137` 22%, `GEM/cancancan/lib/cancan/ability/rules.rb:28` 11% | UsersController#index 23%, OrganizationsController#index 23%, ContactsController#index 20% | `can :manage, Contact, account_id: user.account_id, deleted_at: nil` |
| 30 | `app/models/ability.rb:18` | `initialize` | 4.26 | 0.0 | 0.95 | `GEM/cancancan/lib/cancan/rule.rb:137` 22%, `GEM/cancancan/lib/cancan/ability.rb:145` 22%, `GEM/cancancan/lib/cancan/ability/rules.rb:24` 11% | UsersController#index 23%, OrganizationsController#index 23%, ContactsController#index 20% | `can :manage, Organization, account_id: user.account_id, deleted_at: ni` |

626.34 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | UsersController#index | 10 / 10 | 3178.7 / 3227.1 | 48.4 | 3825.5 | `GEM/cancancan/lib/cancan/ability.rb:80` 62.1, `GEM/cancancan/lib/cancan/ability.rb:77` 47.8, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 37.2 | `app/controllers/users_controller.rb:20` 649.2, `app/controllers/users_controller.rb:13` 219.2, `app/controllers/users_controller.rb:26` 150.0 |
| 2 | DashboardController#index | 2 / 2 | 2930.0 / 2930.0 | 0.0 | 2249.0 | `GEM/json/lib/json/common.rb:364` 76.0, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 22.0 | `app/controllers/dashboard_controller.rb:3` 410.0, `app/views/layouts/application.html.erb:20` 141.0, `app/views/layouts/application.html.erb:17` 46.0 |
| 3 | UsersController#edit | 6 / 6 | 2858.8 / 2865.0 | 6.2 | 3013.8 | `GEM/json/lib/json/common.rb:364` 52.0, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 29.0, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0 | `app/controllers/users_controller.rb:47` 332.8, `app/controllers/users_controller.rb:61` 217.0, `app/controllers/application_controller.rb:13` 91.4 |
| 4 | ContactsController#index | 10 / 10 | 2638.6 / 2643.8 | 5.2 | 2837.3 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 75.9, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 27.8, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0 | `app/controllers/contacts_controller.rb:19` 390.6, `app/controllers/contacts_controller.rb:15` 205.3, `app/controllers/contacts_controller.rb:7` 172.4 |
| 5 | ContactsController#edit | 4 / 4 | 2516.0 / 2651.3 | 135.3 | 2991.0 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 39.3, `GEM/json/lib/json/common.rb:364` 36.0, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 32.0 | `app/controllers/contacts_controller.rb:43` 309.3, `app/controllers/contacts_controller.rb:65` 240.0, `app/controllers/application_controller.rb:13` 134.3 |
| 6 | OrganizationsController#index | 10 / 10 | 2538.1 / 2543.3 | 5.2 | 2721.5 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 41.9, `GEM/json/lib/json/common.rb:364` 32.4, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0 | `app/controllers/organizations_controller.rb:14` 248.8, `app/controllers/organizations_controller.rb:18` 145.6, `app/controllers/organizations_controller.rb:7` 115.3 |
| 7 | OrganizationsController#edit | 4 / 4 | 2499.0 / 2514.7 | 15.7 | 6728.3 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 39.3, `GEM/json/lib/json/common.rb:364` 36.0, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 30.0 | `app/controllers/organizations_controller.rb:33` 299.7, `app/controllers/application_controller.rb:13` 182.0, `app/controllers/organizations_controller.rb:53` 159.0 |
| 8 | Users::SessionsController#new | 7 / 7 | 2231.5 / 2167.7 | -63.8 | 2390.0 | `GEM/json/lib/json/common.rb:364` 58.8, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0, `RAILS/activesupport/lib/active_support/inflector/methods.rb:78` 24.0 | `app/controllers/users/sessions_controller.rb:4` 294.3, `app/views/layouts/application.html.erb:20` 94.0, `app/views/layouts/application.html.erb:17` 30.7 |
| 9 | UsersController#new | 2 / 2 | 1717.0 / 1733.0 | 16.0 | 2671.0 | `GEM/uri/lib/uri/common.rb:465` 30.0, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 23.0 | `app/controllers/users_controller.rb:37` 206.0, `app/controllers/application_controller.rb:13` 188.0, `app/controllers/concerns/inertia_json.rb:26` 24.0 |
| 10 | Users::SessionsController#create | 2 / 2 | 1702.0 / 1697.0 | -5.0 | 1676.5 | `RAILS/actionview/lib/action_view/template/error.rb:0` 93.0, `RAILS/actionview/lib/action_view/template/resolver.rb:209` 36.0, `RAILS/actionview/lib/action_view/template/resolver.rb:197` 24.0 | `app/controllers/users/sessions_controller.rb:9` 831.0, `app/controllers/concerns/auth.rb:17` 20.0, `app/controllers/concerns/inertia_csrf.rb:30` 15.0 |
| 11 | (no action name) | 6 / 6 | 115.8 / 115.8 | 0.0 | 115.3 | `GEM/rack/lib/rack/utils.rb:693` 17.4, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:135` 14.4, `GEM/rack/lib/rack/request.rb:649` 8.0 |  |
| 12 | OrganizationsController#update | 1 / 1 | – / – |  | 2277.0 |  |  |
| 13 | UsersController#update | 1 / 1 | – / – |  | 2149.0 |  |  |
| 14 | UsersController#create | 1 / 1 | – / – |  | 2108.0 |  |  |
| 15 | ContactsController#create | 1 / 1 | – / – |  | 2061.0 |  |  |
| 16 | UsersController#destroy | 1 / 1 | – / – |  | 2043.0 |  |  |
| 17 | OrganizationsController#create | 1 / 1 | – / – |  | 2041.0 |  |  |
| 18 | ContactsController#new | 1 / 1 | – / – |  | 2017.0 |  |  |
| 19 | ContactsController#update | 1 / 1 | – / – |  | 1849.0 |  |  |
| 20 | OrganizationsController#destroy | 1 / 1 | – / – |  | 1811.0 |  |  |
| 21 | ContactsController#destroy | 1 / 1 | – / – |  | 1778.0 |  |  |
| 22 | Users::SessionsController#destroy | 1 / 1 | – / – |  | 1359.0 |  |  |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: pull requests from Lowrail's contributions ledger that change this line, and whether the app's version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/json/lib/json/common.rb:364` | `parse` | 33.99 / 34.0 | 0.01 | 35.09 | 88% | String, Hash |  | `app/views/layouts/application.html.erb:17` 38%, `app/views/layouts/application.html.erb:20` 38% | `Parser.parse(source, opts)` |
| 2 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` | `cast_result` | 32.73 / 32.73 | 0.0 | 32.93 | 76% | String, Data |  | `app/controllers/contacts_controller.rb:19` 34%, `no app frame` 23% | `ActiveRecord::Result.new(fields, result.values, types.freeze, affected` |
| 3 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` | `get_oid_type` | 22.96 / 22.96 | 0.0 | 23.74 | 76% | Array |  | `no app frame` 41%, `app/controllers/users_controller.rb:20` 16% | `type_map.fetch(oid, fmod, sql_type) {` |
| 4 | `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` | `file_readable?` | 20.39 / 20.39 | 0.0 | 20.76 | 84% | String, Array |  | `no app frame` 100% | `file_path = File.join(@root, path.b)` |
| 5 | `GEM/cancancan/lib/cancan/ability.rb:80` | `can?` | 19.68 / 19.68 | 0.0 | 19.88 | 70% | Data, Array |  | `no app frame` 46%, `app/controllers/users_controller.rb:26` 39% | `results.reject(&:nil?).first \|\| false` |
| 6 | `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:336` | `build_directives` | 17.57 / 17.57 | 0.0 | 17.84 | 89% | String |  | `no app frame` 100% | `"#{directive} #{build_directive(directive, sources, context).join(' ')` |
| 7 | `GEM/uri/lib/uri/common.rb:456` | `_encode_uri_component` | 16.3 / 17.97 | 1.68 | 17.45 | 92% | String, MatchData |  | `no app frame` 99%, `config/initializers/pagy.rb:12` 1% | `str.gsub!(regexp, table)` |
| 8 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | `#{method}` | 16.62 / 16.62 | 0.0 | 16.95 | 92% | Array, Hash |  | `no app frame` 48%, `app/controllers/users_controller.rb:20` 7% | `dispatch(:#{method}, ...)` |
| 9 | `GEM/cancancan/lib/cancan/ability.rb:77` | `can?` | 15.14 / 15.14 | 0.0 | 15.3 | 70% | Data, Array |  | `no app frame` 46%, `app/controllers/users_controller.rb:26` 39% | `results = extract_subjects(subject).lazy.map do \|a_subject\|` |
| 10 | `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` | `deep_transform_props` | 14.99 / 14.99 | 0.0 | 15.39 | 72% | Array, Hash | inertiajs/inertia-rails#442 open upstream work | `app/controllers/organizations_controller.rb:14` 19%, `app/controllers/contacts_controller.rb:15` 17% | `props.each_with_object({}) do \|(key, prop), transformed_props\|` |
| 11 | `GEM/uri/lib/uri/common.rb:465` | `_decode_uri_component` | 12.46 / 14.05 | 1.59 | 13.62 | 58% | String, MatchData |  | `no app frame` 100% | `str.b.gsub(regexp, TBLDECWWWCOMP_).force_encoding(enc)` |
| 12 | `RAILS/activemodel/lib/active_model/type/string.rb:39` | `cast_value` | 12.38 / 12.38 | 0.0 | 12.58 | 77% | String |  | `app/controllers/organizations_controller.rb:18` 14%, `app/controllers/application_controller.rb:13` 13% | `when ::String then ::String.new(value)` |
| 13 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | `merge` | 11.84 / 11.84 | 0.0 | 11.95 | 49% | Array, Object |  | `app/controllers/users_controller.rb:20` 60%, `app/controllers/application_controller.rb:13` 14% | `WhereClause.new(predicates \| other.predicates)` |
| 14 | `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:90` | `deep_transform_props` | 11.41 / 11.41 | 0.0 | 11.73 | 72% | String |  | `app/controllers/organizations_controller.rb:14` 19%, `app/controllers/contacts_controller.rb:15` 17% | `path = prefix.empty? ? key.to_s : "#{prefix}.#{key}"` |
| 15 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` | `call` | 10.81 / 10.81 | 0.0 | 10.96 | 92% | Data |  | `no app frame` 93%, `app/models/concerns/soft_delete.rb:25` 2% | `result_lambda = -> { user_callback.call target, value }` |
| 16 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:382` | `apply_inflections` | 10.8 / 10.8 | 0.0 | 11.19 | 89% | String, MatchData |  | `no app frame` 97%, `app/controllers/contacts_controller.rb:65` 1% | `rules.each { \|(rule, replacement)\| break if result.sub!(rule, replacem` |
| 17 | `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:348` | `validate` | 10.54 / 10.54 | 0.0 | 10.7 | 89% | String |  | `no app frame` 100% | `if source.include?(";") \|\| source != source.gsub(/[[:space:]]/, "")` |
| 18 | `RAILS/actionpack/lib/action_dispatch/http/request.rb:66` | `initialize` | 9.61 / 9.61 | 0.0 | 9.77 | 100% | Object, Data |  | `no app frame` 99%, `app/controllers/users/sessions_controller.rb:9` 0% | `@rack_request = Rack::Request.new(env)` |
| 19 | `GEM/rack/lib/rack/request.rb:693` | `split_header` | 9.51 / 9.51 | 0.0 | 9.62 | 92% | Array |  | `no app frame` 79%, `app/controllers/organizations_controller.rb:7` 8% | `value ? value.strip.split(/[, \t]+/) : []` |
| 20 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` | `+` | 9.46 / 9.46 | 0.0 | 9.51 | 76% | Object, Array |  | `app/controllers/users_controller.rb:20` 50%, `no app frame` 18% | `WhereClause.new(predicates + other.predicates)` |
| 21 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:78` | `camelize` | 9.45 / 9.45 | 0.0 | 9.62 | 84% | String, MatchData |  | `no app frame` 100% | `string = string.sub(/^[a-z\d]*/) { \|match\| inflections.acronyms[match]` |
| 22 | `GEM/inertia_rails/lib/inertia_rails/renderer.rb:129` | `extract_shared_keys` | 9.14 / 9.14 | 0.0 | 9.31 | 72% | String, Array |  | `app/controllers/organizations_controller.rb:14` 17%, `app/controllers/users_controller.rb:13` 17% | `shared_props.keys.map { \|key\| key.to_s.split('.', 2).first }.uniq` |
| 23 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` | `build_handle` | 9.09 / 9.09 | 0.0 | 9.3 | 92% | Object, Data | #59613 merged 2026-11-04, after this app's version, not released yet, #59235 merged 2026-10-21, after this app's version, not released yet | `no app frame` 36%, `app/controllers/users_controller.rb:20` 13% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 24 | `GEM/cancancan/lib/cancan/ability.rb:145` | `can` | 9.08 / 9.08 | 0.0 | 9.28 | 70% | Array, Object |  | `app/models/ability.rb:13` 15%, `app/models/ability.rb:14` 15% | `add_rule(Rule.new(true, action, subject, *attributes_and_conditions, &` |
| 25 | `GEM/cancancan/lib/cancan/rule.rb:137` | `wrap` | 9.08 / 9.08 | 0.0 | 9.27 | 70% | Array |  | `app/models/ability.rb:13` 15%, `app/models/ability.rb:18` 15% | `[object]` |
| 26 | `RUBY/ipaddr.rb:725` | `in_addr` | 9.05 / 9.05 | 0.0 | 9.19 | 92% | String, Array |  | `no app frame` 100% | `octets = addr.split('.')` |
| 27 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` | `expand_from_hash` | 8.92 / 8.92 | 0.0 | 8.97 | 76% | Array |  | `app/controllers/users_controller.rb:20` 40%, `no app frame` 33% | `attributes.flat_map do \|key, value\|` |
| 28 | `RAILS/activerecord/lib/arel/table.rb:85` | `[]` | 8.86 / 8.86 | 0.0 | 8.95 | 76% | Struct |  | `no app frame` 28%, `app/controllers/users_controller.rb:20` 27% | `Attribute.new(table, name)` |
| 29 | `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:347` | `validate` | 8.78 / 8.78 | 0.0 | 8.92 | 89% | Array |  | `no app frame` 100% | `sources.flatten.each do \|source\|` |
| 30 | `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:359` | `build_directive` | 8.78 / 8.78 | 0.0 | 8.92 | 89% | Array |  | `no app frame` 100% | `resolved_sources = sources.map { \|source\| resolve_source(source, conte` |

## Dev/test-mode work

642.8 of 2391.0 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/config.rb:41` † | 189.19 | 35% | `app/views/layouts/application.html.erb:17` 50%, `app/views/layouts/application.html.erb:20` 50% | `root.join(public_dir, public_output_dir)` |
| 2 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/config.rb:27` † | 50.0 | 35% | `app/views/layouts/application.html.erb:17` 50%, `app/views/layouts/application.html.erb:20` 50% | `build_output_dir.join(".vite/manifest.json"),` |
| 3 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/config.rb:30` † | 50.0 | 35% | `app/views/layouts/application.html.erb:17` 50%, `app/views/layouts/application.html.erb:20` 50% | `build_output_dir.join(".vite/manifest-assets.json"),` |
| 4 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/builder.rb:50` † | 23.65 | 35% | `app/views/layouts/application.html.erb:17` 50%, `app/views/layouts/application.html.erb:20` 50% | `config.build_cache_dir.join("last#{"-ssr" if ssr}-build-#{config.mode}` |
| 5 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` | 23.54 | 76% | `app/controllers/users_controller.rb:20` 33%, `no app frame` 22% | `binds = binds.inspect` |
| 6 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:177` | 17.11 | 76% | `no app frame` 26%, `app/controllers/users_controller.rb:20` 21% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 7 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/builder.rb:77` | 16.05 | 16% | `app/views/layouts/application.html.erb:17` 100% | `stat = File.stat(file)` |
| 8 | debug logging | `RAILS/actionpack/lib/abstract_controller/logger.rb:12` | 16.04 | 92% | `no app frame` 93%, `app/controllers/users_controller.rb:76` 1% | `singleton_class.delegate :logger, :logger=, to: :config` |
| 9 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/builder.rb:80` | 12.49 | 16% | `app/views/layouts/application.html.erb:17` 100% | `signature = [stat.mtime, stat.size]` |
| 10 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/builder.rb:98` † | 12.49 | 16% | `app/views/layouts/application.html.erb:17` 100% | `Time.now - stat.mtime < 1` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activerecord | 494.8 | 532.3 | `database_statements.rb:176` 32.7, `log_subscriber.rb:49` 23.5, `postgresql_adapter.rb:880` 23.0 |
| gem: vite_ruby | 436.2 | 460.0 | `config.rb:41` 189.2, `config.rb:27` 50.0, `config.rb:30` 50.0 |
| rails: activesupport | 336.2 | 402.9 | `log_subscriber.rb:177` 17.1, `broadcast_logger.rb:129` 16.6, `log_subscriber.rb:175` 11.4 |
| rails: actionpack | 323.7 | 403.2 | `static.rb:145` 20.4, `content_security_policy.rb:336` 17.6, `logger.rb:12` 16.0 |
| gem: cancancan | 187.5 | 192.7 | `ability.rb:80` 19.7, `ability.rb:77` 15.1, `ability.rb:145` 9.1 |
| gem: inertia_rails | 116.9 | 121.9 | `props_resolver.rb:89` 15.0, `props_resolver.rb:90` 11.4, `renderer.rb:129` 9.1 |
| rails: actionview | 102.3 | 133.2 | `tag_helper.rb:309` 6.8, `base.rb:230` 6.0, `log_subscriber.rb:61` 4.7 |
| gem: rack | 79.2 | 81.1 | `request.rb:693` 9.5, `utils.rb:408` 7.0, `request.rb:649` 6.6 |
| rails: activemodel | 47.7 | 50.4 | `string.rb:39` 12.4, `attribute.rb:9` 6.7, `serialization.rb:131` 4.1 |
| ruby default gem: uri | 41.4 | 42.8 | `common.rb:456` 17.1, `common.rb:465` 13.3, `common.rb:448` 3.0 |
| ruby stdlib | 38.0 | 56.4 | `ipaddr.rb:725` 9.1, `formatter.rb:174` 6.3, `ipaddr.rb:672` 3.6 |
| gem: json | 36.5 | 37.6 | `common.rb:364` 34.0, `common.rb:1089` 2.5 |
| gem: warden | 33.4 | 34.3 | `proxy.rb:334` 4.9, `proxy.rb:348` 3.5, `proxy.rb:31` 2.0 |
| gem: logger | 31.6 | 32.3 | `logger.rb:692` 8.3, `log_device.rb:165` 8.3, `log_device.rb:33` 8.3 |
| app | 30.8 | 37.7 | `inertia_csrf.rb:29` 1.7, `ability.rb:17` 1.4, `ability.rb:18` 1.4 |
| gem: concurrent-ruby | 16.6 | 17.2 | `safe_initialization.rb:30` 5.4, `mutex_lockable_object.rb:32` 1.8, `mutex_lockable_object.rb:33` 1.8 |
| gem: devise | 10.6 | 14.6 | `helpers.rb:128` 1.6, `helpers.rb:117` 0.9, `authenticatable.rb:107` 0.9 |
| gem: pagy | 9.2 | 19.8 | `linkable.rb:68` 0.6, `pagy.rb:67` 0.6, `pagy.rb:59` 0.6 |
| gem: base64 | 8.5 | 8.6 | `base64.rb:283` 4.5, `base64.rb:310` 3.2, `base64.rb:374` 0.9 |
| rails: railties | 8.3 | 8.9 | `logger.rb:57` 1.8, `engine.rb:748` 1.0, `logger.rb:21` 0.9 |
| gem: vite_rails | 7.8 | 8.1 | `tag_helpers.rb:106` 1.4, `tag_helpers.rb:47` 0.7, `tag_helpers.rb:48` 0.7 |
| gem: i18n | 3.7 | 8.2 | `i18n.rb:476` 0.9, `i18n.rb:396` 0.4, `utils.rb:8` 0.4 |
| gem: jbuilder | 3.6 | 4.3 | `jbuilder.rb:354` 2.5, `jbuilder.rb:23` 0.6, `jbuilder.rb:359` 0.5 |
| rails: activestorage | 3.5 | 5.2 | `model.rb:128` 0.9, `model.rb:284` 0.5, `attached.rb:13` 0.5 |
| gem: bootsnap | 3.5 | 15.1 | `iseq.rb:98` 1.7, `cache.rb:218` 0.5, `iseq.rb:154` 0.4 |
| ruby default gem: securerandom | 2.8 | 2.8 | `securerandom.rb:71` 2.8 |
| gem: rack-session | 2.7 | 2.8 | `id.rb:275` 0.9, `id.rb:401` 0.9, `id.rb:277` 0.9 |
| gem: tzinfo | 2.4 | 2.6 | `timestamp.rb:208` 1.1, `constant_offset_data_timezone_info.rb:52` 0.6, `timestamp.rb:193` 0.6 |
| gem: request_store | 1.8 | 1.8 | `middleware.rb:28` 0.9, `middleware.rb:21` 0.9 |
| gem: orm_adapter | 0.5 | 0.6 | `active_record.rb:17` 0.5, `base.rb:100` 0.0, `base.rb:105` 0.0 |
| gem: bcrypt | 0.2 | 0.5 | `password.rb:102` 0.1, `password.rb:103` 0.0, `engine.rb:70` 0.0 |
| ruby default gem: bundler | 0.0 | 0.0 | `rubygems_integration.rb:192` 0.0 |
| gem: pg | 0.0 | 0.0 | `result.rb:17` 0.0 |
| lowrail-profile | 0.0 | 0.0 | `profile.rb:55` 0.0, `profile.rb:65` 0.0 |
| gem: zeitwerk | 0.0 | 0.2 | `file_system.rb:203` 0.0, `file_system.rb:199` 0.0, `cref.rb:47` 0.0 |
| gem: erubi | 0.0 | 1.0 | `erubi.rb:134` 0.0, `erubi.rb:139` 0.0, `erubi.rb:196` 0.0 |
| gem: msgpack | 0.0 | 0.2 | `factory.rb:41` 0.0, `factory.rb:9` 0.0, `factory.rb:14` 0.0 |
| gem: responders | 0.0 | 0.9 | `respond_with.rb:48` 0.0, `responder.rb:172` 0.0, `responders.rb:39` 0.0 |
