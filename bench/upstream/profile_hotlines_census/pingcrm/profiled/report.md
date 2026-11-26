# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails test:all -v`
* Ruby: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux]
* Rails: 8.1.4, test environment
* Counted in run 1: 73 requests; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 73 | 3474.9 | 0 | 0 | 0 | 0 |
| run2 | 1 | 73 | 3475.8 | 0 | 0 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.49 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/controllers/users_controller.rb:20` | `index` | 74.1 | 15.07 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 4%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` 3% | UsersController#index 100% | `if user.photo.attached?` |
| 2 | `app/controllers/contacts_controller.rb:19` | `index` | 63.22 | 8.7 | 0.11 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 18%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 4%, `RAILS/activerecord/lib/active_record/result.rb:244` 2% | ContactsController#index 100% | `json.data(paged_contacts) do \|contact\|` |
| 3 | `app/controllers/application_controller.rb:13` |  | 38.51 | 5.92 | 0.45 | `RAILS/activemodel/lib/active_model/serialization.rb:131` 9%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 7%, `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 4% | UsersController#edit 16%, ContactsController#index 16%, OrganizationsController#index 16% | `current_user.as_json(` |
| 4 | `app/views/layouts/application.html.erb:20` |  | 36.7 | 151.27 | 0.78 | `GEM/json/lib/json/common.rb:364` 27%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 10%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 6% | Users::SessionsController#new 21%, UsersController#index 16%, ContactsController#index 16% | `<%= vite_javascript_tag 'application' %>` |
| 5 | `app/controllers/contacts_controller.rb:15` | `index` | 30.75 | 3.48 | 0.33 | `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 8%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:90` 6%, `GEM/inertia_rails/lib/inertia_rails/renderer.rb:129` 5% | ContactsController#index 100% | `render inertia: 'Contacts/Index',` |
| 6 | `app/controllers/organizations_controller.rb:14` | `index` | 30.66 | 3.48 | 0.33 | `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 8%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:90` 6%, `GEM/inertia_rails/lib/inertia_rails/renderer.rb:129` 5% | OrganizationsController#index 100% | `render inertia: 'Organizations/Index',` |
| 7 | `app/controllers/users_controller.rb:13` | `index` | 24.74 | 3.42 | 0.29 | `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 6%, `GEM/inertia_rails/lib/inertia_rails/renderer.rb:129` 5%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:90` 5% | UsersController#index 100% | `render inertia: 'Users/Index',` |
| 8 | `app/controllers/users/sessions_controller.rb:4` | `new` | 24.16 | 4.38 | 0.33 | `GEM/inertia_rails/lib/inertia_rails/renderer.rb:129` 4%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 3%, `RAILS/actionview/lib/action_view/template/resolver.rb:181` 3% | Users::SessionsController#new 100%, Users::SessionsController#create 0% | `render inertia: 'Auth/Login', props: {}` |
| 9 | `app/controllers/contacts_controller.rb:7` | `index` | 23.05 | 3.44 | 0.22 | `RAILS/activerecord/lib/arel/visitors/to_sql.rb:801` 4%, `GEM/rack/lib/rack/request.rb:693` 3%, `RAILS/activesupport/lib/active_support/delegation.rb:146` 3% | ContactsController#index 100% | `pagy(` |
| 10 | `app/controllers/users_controller.rb:47` | `edit` | 22.79 | 3.32 | 0.21 | `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 9%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:90` 7%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:120` 5% | UsersController#edit 100% | `render inertia: 'Users/Edit',` |
| 11 | `app/controllers/organizations_controller.rb:18` | `index` | 20.88 | 4.08 | 0.11 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 27%, `RAILS/activemodel/lib/active_model/type/string.rb:39` 8%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 7% | OrganizationsController#index 100% | `json.data(` |
| 12 | `app/controllers/users_controller.rb:26` | `index` | 17.11 | 0.0 | 1.03 | `GEM/cancancan/lib/cancan/ability.rb:80` 26%, `GEM/cancancan/lib/cancan/ability.rb:77` 20%, `GEM/cancancan/lib/cancan/ability/rules.rb:56` 6% | UsersController#index 100% | `json.can { json.edit_user can?(:edit, user) }` |
| 13 | `app/controllers/users_controller.rb:61` | `edit` | 14.86 | 3.01 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 4%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:166` 3% | UsersController#edit 100% | `if @user.photo.attached?` |
| 14 | `app/controllers/organizations_controller.rb:7` | `index` | 14.19 | 3.04 | 0.22 | `GEM/rack/lib/rack/request.rb:693` 5%, `RAILS/activerecord/lib/active_record/relation/spawn_methods.rb:10` 2%, `GEM/pagy/lib/pagy.rb:67` 2% | OrganizationsController#index 100% | `pagy(` |
| 15 | `app/controllers/users_controller.rb:17` | `index` | 13.74 | 3.14 | 0.1 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 19%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 9%, `RAILS/activerecord/lib/arel/visitors/to_sql.rb:801` 5% | UsersController#index 100% | `json.array! @users do \|user\|` |
| 16 | `app/controllers/concerns/inertia_json.rb:26` | `jbuilder` | 13.7 | 0.0 | 0.56 | `RAILS/actionpack/lib/abstract_controller/rendering.rb:66` 22%, `RAILS/actionview/lib/action_view/base.rb:230` 21%, `RAILS/actionpack/lib/abstract_controller/rendering.rb:63` 12% | OrganizationsController#index 19%, ContactsController#index 19%, UsersController#index 17% | `JbuilderTemplate.new(view_context, &).attributes!` |
| 17 | `app/controllers/contacts_controller.rb:43` | `edit` | 12.73 | 1.18 | 0.12 | `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 10%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:90` 8%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:120` 7% | ContactsController#edit 100% | `render inertia: 'Contacts/Edit',` |
| 18 | `app/controllers/organizations_controller.rb:33` | `edit` | 12.3 | 1.18 | 0.12 | `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 10%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:90` 8%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:120` 7% | OrganizationsController#edit 100% | `render inertia: 'Organizations/Edit',` |
| 19 | `app/views/layouts/application.html.erb:17` |  | 11.97 | 185.62 | 0.52 | `GEM/json/lib/json/common.rb:364` 83%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 4%, `RAILS/actionview/lib/action_view/helpers/asset_url_helper.rb:208` 2% | Users::SessionsController#new 21%, OrganizationsController#index 16%, UsersController#index 16% | `<link rel="icon" type="image/png" href="<%= vite_asset_path('images/fa` |
| 20 | `app/controllers/users/sessions_controller.rb:9` | `create` | 11.56 | 0.71 | 0.0 | `RAILS/actionview/lib/action_view/template/error.rb:0` 11%, `RAILS/actionview/lib/action_view/template/resolver.rb:209` 4%, `RAILS/actionview/lib/action_view/template_path.rb:23` 3% | Users::SessionsController#create 100% | `super` |
| 21 | `app/controllers/concerns/inertia_csrf.rb:30` | `set_csrf_cookie` | 10.01 | 0.0 | 0.0 | `RUBY/openssl/hmac.rb:36` 12%, `GEM/securerandom/lib/securerandom.rb:71` 6%, `RAILS/actionpack/lib/action_controller/metal/request_forgery_protection.rb:603` 6% | OrganizationsController#index 19%, ContactsController#index 19%, UsersController#index 16% | `value: form_authenticity_token,` |
| 22 | `app/controllers/contacts_controller.rb:65` | `edit` | 9.86 | 1.32 | 0.04 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 5%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 2% | ContactsController#edit 100% | `json.array! current_user.organizations.order(:name), :id, :name` |
| 23 | `app/controllers/organizations_controller.rb:53` | `edit` | 6.53 | 1.32 | 0.04 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 9%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `RAILS/activerecord/lib/active_record/relation.rb:77` 3% | OrganizationsController#edit 100% | `json.array! @organization.contacts.order_by_name,` |
| 24 | `app/controllers/dashboard_controller.rb:3` | `index` | 6.29 | 1.07 | 0.04 | `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 5%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:90` 3%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:120` 3% | DashboardController#index 100% | `render inertia: 'Dashboard/Index',` |
| 25 | `app/models/ability.rb:13` | `initialize` | 5.27 | 0.0 | 0.96 | `GEM/cancancan/lib/cancan/rule.rb:137` 18%, `GEM/cancancan/lib/cancan/ability.rb:145` 18%, `GEM/cancancan/lib/cancan/rule.rb:121` 9% | OrganizationsController#index 23%, ContactsController#index 23%, UsersController#index 20% | `can :read, User, account_id: user.account_id, deleted_at: nil` |
| 26 | `config/initializers/pagy.rb:12` | `data_hash` | 4.95 | 0.0 | 0.44 | `GEM/pagy/lib/pagy/modules/abilities/linkable.rb:68` 13%, `GEM/pagy/lib/pagy/modules/abilities/linkable.rb:47` 13%, `GEM/pagy/lib/pagy/toolbox/helpers/support/series.rb:15` 9% | OrganizationsController#index 51%, ContactsController#index 49% | `super.tap { \|hash\| hash[:series] = __send__(:series) }` |
| 27 | `app/models/concerns/soft_delete.rb:7` |  | 4.66 | 0.0 | 0.55 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 12%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:29` 12%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` 12% | OrganizationsController#index 35%, ContactsController#index 35%, UsersController#index 30% | `scope :not_trashed, -> { where(deleted_at: nil) }` |
| 28 | `app/controllers/users_controller.rb:30` | `index` | 4.63 | 0.0 | 0.1 | `GEM/cancancan/lib/cancan/ability.rb:80` 27%, `GEM/cancancan/lib/cancan/ability.rb:77` 21%, `GEM/cancancan/lib/cancan/ability.rb:309` 6% | UsersController#index 100% | `create_user: can?(:create, User),` |
| 29 | `app/models/ability.rb:17` | `initialize` | 4.32 | 0.0 | 0.96 | `GEM/cancancan/lib/cancan/rule.rb:137` 22%, `GEM/cancancan/lib/cancan/ability.rb:145` 22%, `GEM/cancancan/lib/cancan/ability/rules.rb:24` 11% | ContactsController#index 23%, OrganizationsController#index 23%, UsersController#index 20% | `can :manage, Contact, account_id: user.account_id, deleted_at: nil` |
| 30 | `app/models/ability.rb:18` | `initialize` | 4.32 | 0.0 | 0.96 | `GEM/cancancan/lib/cancan/rule.rb:137` 22%, `GEM/cancancan/lib/cancan/ability.rb:145` 22%, `GEM/cancancan/lib/cancan/ability/rules.rb:28` 11% | ContactsController#index 23%, OrganizationsController#index 23%, UsersController#index 20% | `can :manage, Organization, account_id: user.account_id, deleted_at: ni` |

641.6 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | UsersController#index | 9 / 9 | 3361.1 / 3367.5 | 6.4 | 4026.0 | `GEM/cancancan/lib/cancan/ability.rb:80` 63.4, `GEM/cancancan/lib/cancan/ability.rb:77` 48.8, `GEM/json/lib/json/common.rb:364` 41.6 | `app/controllers/users_controller.rb:20` 676.1, `app/controllers/users_controller.rb:13` 225.8, `app/controllers/users_controller.rb:26` 156.1 |
| 2 | ContactsController#index | 10 / 10 | 3146.9 / 3150.1 | 3.2 | 2958.7 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 102.4, `GEM/json/lib/json/common.rb:364` 38.8, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 32.4 | `app/controllers/contacts_controller.rb:19` 512.8, `app/controllers/contacts_controller.rb:15` 249.4, `app/controllers/contacts_controller.rb:7` 187.0 |
| 3 | UsersController#edit | 6 / 6 | 2907.8 / 2911.0 | 3.2 | 3055.2 | `GEM/json/lib/json/common.rb:364` 60.2, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 29.0, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0 | `app/controllers/users_controller.rb:47` 332.8, `app/controllers/users_controller.rb:61` 217.0, `app/controllers/application_controller.rb:13` 91.4 |
| 4 | DashboardController#index | 2 / 2 | 2658.0 / 2659.0 | 1.0 | 2272.0 | `GEM/json/lib/json/common.rb:364` 88.0, `GEM/uri/lib/uri/common.rb:465` 28.0, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0 | `app/controllers/dashboard_controller.rb:3` 459.0, `app/views/layouts/application.html.erb:20` 141.0, `app/views/layouts/application.html.erb:17` 46.0 |
| 5 | OrganizationsController#edit | 4 / 4 | 2604.3 / 2597.7 | -6.7 | 2956.0 | `GEM/json/lib/json/common.rb:364` 41.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 39.3, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 30.0 | `app/controllers/organizations_controller.rb:33` 299.3, `app/controllers/organizations_controller.rb:53` 159.0, `app/controllers/application_controller.rb:13` 134.3 |
| 6 | OrganizationsController#index | 10 / 10 | 2587.4 / 2585.8 | -1.7 | 2915.4 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 54.3, `GEM/json/lib/json/common.rb:364` 38.8, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0 | `app/controllers/organizations_controller.rb:14` 248.7, `app/controllers/organizations_controller.rb:18` 169.3, `app/controllers/organizations_controller.rb:7` 115.1 |
| 7 | ContactsController#edit | 4 / 4 | 2550.7 / 2557.0 | 6.3 | 2885.8 | `GEM/json/lib/json/common.rb:364` 41.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 39.3, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 32.0 | `app/controllers/contacts_controller.rb:43` 309.7, `app/controllers/contacts_controller.rb:65` 240.0, `app/controllers/application_controller.rb:13` 134.3 |
| 8 | Users::SessionsController#new | 7 / 7 | 2132.8 / 2194.7 | 61.8 | 5537.6 | `GEM/json/lib/json/common.rb:364` 63.5, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0, `RAILS/activesupport/lib/active_support/inflector/methods.rb:78` 24.0 | `app/controllers/users/sessions_controller.rb:4` 294.0, `app/views/layouts/application.html.erb:20` 94.0, `app/views/layouts/application.html.erb:17` 30.7 |
| 9 | Users::SessionsController#create | 2 / 2 | 1751.0 / 1720.0 | -31.0 | 1978.0 | `RAILS/actionview/lib/action_view/template/error.rb:0` 92.0, `RAILS/actionview/lib/action_view/template/resolver.rb:209` 36.0, `RAILS/actionview/lib/action_view/template/resolver.rb:197` 24.0 | `app/controllers/users/sessions_controller.rb:9` 844.0, `app/controllers/concerns/auth.rb:17` 27.0, `app/controllers/concerns/inertia_csrf.rb:30` 15.0 |
| 10 | UsersController#new | 2 / 2 | 1728.0 / 1728.0 | 0.0 | 2671.5 | `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0, `GEM/uri/lib/uri/common.rb:456` 26.0, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` 23.0 | `app/controllers/users_controller.rb:37` 206.0, `app/controllers/application_controller.rb:13` 188.0, `app/controllers/concerns/inertia_json.rb:26` 24.0 |
| 11 | (no action name) | 6 / 6 | 115.8 / 115.8 | 0.0 | 115.3 | `GEM/rack/lib/rack/utils.rb:693` 17.4, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:135` 14.4, `GEM/rack/lib/rack/request.rb:649` 8.0 |  |
| 12 | UsersController#update | 1 / 1 | – / – |  | 2152.0 |  |  |
| 13 | UsersController#create | 1 / 1 | – / – |  | 2122.0 |  |  |
| 14 | ContactsController#create | 1 / 1 | – / – |  | 2037.0 |  |  |
| 15 | UsersController#destroy | 1 / 1 | – / – |  | 2040.0 |  |  |
| 16 | OrganizationsController#create | 1 / 1 | – / – |  | 2039.0 |  |  |
| 17 | ContactsController#new | 1 / 1 | – / – |  | 2001.0 |  |  |
| 18 | ContactsController#update | 1 / 1 | – / – |  | 1840.0 |  |  |
| 19 | OrganizationsController#update | 1 / 1 | – / – |  | 1831.0 |  |  |
| 20 | OrganizationsController#destroy | 1 / 1 | – / – |  | 1780.0 |  |  |
| 21 | ContactsController#destroy | 1 / 1 | – / – |  | 1766.0 |  |  |
| 22 | Users::SessionsController#destroy | 1 / 1 | – / – |  | 1365.0 |  |  |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/json/lib/json/common.rb:364` | `parse` | 38.81 / 38.84 | 0.03 | 39.93 | 92% | String, Hash |  | `app/views/layouts/application.html.erb:17` 34%, `app/views/layouts/application.html.erb:20` 34% | `Parser.parse(source, opts)` |
| 2 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` | `cast_result` | 32.93 / 32.93 | 0.0 | 33.05 | 80% | String, Data |  | `app/controllers/contacts_controller.rb:19` 35%, `no app frame` 23% | `ActiveRecord::Result.new(fields, result.values, types.freeze, affected` |
| 3 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` | `get_oid_type` | 24.26 / 24.26 | 0.0 | 24.44 | 80% | Array |  | `no app frame` 44%, `app/controllers/users_controller.rb:20` 15% | `type_map.fetch(oid, fmod, sql_type) {` |
| 4 | `GEM/uri/lib/uri/common.rb:465` | `_decode_uri_component` | 21.74 / 22.23 | 0.49 | 22.29 | 90% | String, MatchData |  | `no app frame` 100% | `str.b.gsub(regexp, TBLDECWWWCOMP_).force_encoding(enc)` |
| 5 | `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` | `file_readable?` | 20.3 / 20.3 | 0.0 | 20.67 | 84% | String, Array |  | `no app frame` 100% | `file_path = File.join(@root, path.b)` |
| 6 | `GEM/cancancan/lib/cancan/ability.rb:80` | `can?` | 19.23 / 19.23 | 0.0 | 19.42 | 70% | Data, Array |  | `no app frame` 47%, `app/controllers/users_controller.rb:26` 39% | `results.reject(&:nil?).first \|\| false` |
| 7 | `GEM/uri/lib/uri/common.rb:456` | `_encode_uri_component` | 17.77 / 18.23 | 0.47 | 18.25 | 92% | String, MatchData |  | `no app frame` 99%, `config/initializers/pagy.rb:12` 1% | `str.gsub!(regexp, table)` |
| 8 | `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:336` | `build_directives` | 17.53 / 17.53 | 0.0 | 17.81 | 89% | String |  | `no app frame` 100% | `"#{directive} #{build_directive(directive, sources, context).join(' ')` |
| 9 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | `#{method}` | 16.79 / 16.79 | 0.0 | 17.04 | 92% | Hash, Array |  | `no app frame` 48%, `app/controllers/users_controller.rb:20` 7% | `dispatch(:#{method}, ...)` |
| 10 | `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:89` | `deep_transform_props` | 15.37 / 15.37 | 0.0 | 15.49 | 71% | Array, Hash | inertiajs/inertia-rails#442 merged 2026-11-18, after this app's version, not released yet | `app/controllers/organizations_controller.rb:14` 19%, `app/controllers/contacts_controller.rb:15` 17% | `props.each_with_object({}) do \|(key, prop), transformed_props\|` |
| 11 | `GEM/cancancan/lib/cancan/ability.rb:77` | `can?` | 14.79 / 14.79 | 0.0 | 14.93 | 70% | Data, Array |  | `no app frame` 47%, `app/controllers/users_controller.rb:26` 39% | `results = extract_subjects(subject).lazy.map do \|a_subject\|` |
| 12 | `RAILS/activemodel/lib/active_model/type/string.rb:39` | `cast_value` | 12.42 / 12.42 | 0.0 | 12.45 | 77% | String |  | `app/controllers/organizations_controller.rb:18` 14%, `app/controllers/application_controller.rb:13` 13% | `when ::String then ::String.new(value)` |
| 13 | `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:90` | `deep_transform_props` | 11.71 / 11.71 | 0.0 | 11.79 | 71% | String |  | `app/controllers/organizations_controller.rb:14` 19%, `app/controllers/contacts_controller.rb:15` 17% | `path = prefix.empty? ? key.to_s : "#{prefix}.#{key}"` |
| 14 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | `merge` | 11.56 / 11.56 | 0.0 | 11.78 | 48% | Object, Array |  | `app/controllers/users_controller.rb:20` 59%, `app/controllers/application_controller.rb:13` 15% | `WhereClause.new(predicates \| other.predicates)` |
| 15 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:382` | `apply_inflections` | 11.22 / 11.22 | 0.0 | 11.51 | 85% | String, MatchData |  | `no app frame` 94%, `app/controllers/contacts_controller.rb:65` 1% | `rules.each { \|(rule, replacement)\| break if result.sub!(rule, replacem` |
| 16 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` | `call` | 10.79 / 10.79 | 0.0 | 10.96 | 92% | Data |  | `no app frame` 93%, `app/models/concerns/soft_delete.rb:25` 2% | `result_lambda = -> { user_callback.call target, value }` |
| 17 | `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:348` | `validate` | 10.52 / 10.52 | 0.0 | 10.68 | 89% | String |  | `no app frame` 100% | `if source.include?(";") \|\| source != source.gsub(/[[:space:]]/, "")` |
| 18 | `RAILS/actionpack/lib/action_dispatch/http/request.rb:66` | `initialize` | 9.6 / 9.6 | 0.0 | 9.77 | 100% | Object, Data |  | `no app frame` 99%, `app/controllers/users/sessions_controller.rb:9` 0% | `@rack_request = Rack::Request.new(env)` |
| 19 | `GEM/rack/lib/rack/request.rb:693` | `split_header` | 9.53 / 9.53 | 0.0 | 9.64 | 92% | Array |  | `no app frame` 79%, `app/controllers/organizations_controller.rb:7` 8% | `value ? value.strip.split(/[, \t]+/) : []` |
| 20 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` | `+` | 9.4 / 9.4 | 0.0 | 9.42 | 80% | Object, Array |  | `app/controllers/users_controller.rb:20` 49%, `no app frame` 19% | `WhereClause.new(predicates + other.predicates)` |
| 21 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` | `build_handle` | 9.3 / 9.3 | 0.0 | 9.4 | 92% | Object, Data | #59613 merged 2026-11-04, after this app's version, not released yet, #59235 merged 2026-10-21, after this app's version, not released yet | `no app frame` 37%, `app/controllers/users_controller.rb:20` 13% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 22 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:78` | `camelize` | 9.23 / 9.23 | 0.0 | 9.64 | 84% | String, MatchData |  | `no app frame` 100% | `string = string.sub(/^[a-z\d]*/) { \|match\| inflections.acronyms[match]` |
| 23 | `GEM/inertia_rails/lib/inertia_rails/renderer.rb:129` | `extract_shared_keys` | 9.08 / 9.08 | 0.0 | 9.26 | 71% | Array, String |  | `app/controllers/organizations_controller.rb:14` 17%, `app/controllers/users/sessions_controller.rb:4` 15% | `shared_props.keys.map { \|key\| key.to_s.split('.', 2).first }.uniq` |
| 24 | `RUBY/ipaddr.rb:725` | `in_addr` | 9.04 / 9.04 | 0.0 | 9.18 | 92% | String, Array |  | `no app frame` 100% | `octets = addr.split('.')` |
| 25 | `GEM/cancancan/lib/cancan/ability.rb:145` | `can` | 9.01 / 9.01 | 0.0 | 9.22 | 70% | Array, Object |  | `app/models/ability.rb:13` 15%, `app/models/ability.rb:14` 15% | `add_rule(Rule.new(true, action, subject, *attributes_and_conditions, &` |
| 26 | `GEM/cancancan/lib/cancan/rule.rb:137` | `wrap` | 9.01 / 9.01 | 0.0 | 9.21 | 70% | Array |  | `app/models/ability.rb:14` 15%, `app/models/ability.rb:13` 15% | `[object]` |
| 27 | `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:120` | `deep_transform_props` | 8.92 / 8.92 | 0.0 | 9.0 | 71% | Array | inertiajs/inertia-rails#442 merged 2026-11-18, after this app's version, not released yet | `app/controllers/users_controller.rb:47` 16%, `app/controllers/organizations_controller.rb:14` 16% | `rescue_enabled = prop.try(:rescue?)` |
| 28 | `RAILS/activerecord/lib/arel/table.rb:85` | `[]` | 8.9 / 8.9 | 0.0 | 8.95 | 80% | Struct |  | `no app frame` 29%, `app/controllers/users_controller.rb:20` 26% | `Attribute.new(table, name)` |
| 29 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` | `expand_from_hash` | 8.85 / 8.85 | 0.0 | 8.88 | 80% | Array |  | `app/controllers/users_controller.rb:20` 39%, `no app frame` 34% | `attributes.flat_map do \|key, value\|` |
| 30 | `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:347` | `validate` | 8.77 / 8.77 | 0.0 | 8.9 | 89% | Array |  | `no app frame` 100% | `sources.flatten.each do \|source\|` |

## Dev/test-mode work

640.9 of 2425.5 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/config.rb:41` † | 191.78 | 36% | `app/views/layouts/application.html.erb:20` 50%, `app/views/layouts/application.html.erb:17` 50% | `root.join(public_dir, public_output_dir)` |
| 2 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/config.rb:27` † | 50.68 | 36% | `app/views/layouts/application.html.erb:20` 50%, `app/views/layouts/application.html.erb:17` 50% | `build_output_dir.join(".vite/manifest.json"),` |
| 3 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/config.rb:30` † | 50.68 | 36% | `app/views/layouts/application.html.erb:17` 50%, `app/views/layouts/application.html.erb:20` 50% | `build_output_dir.join(".vite/manifest-assets.json"),` |
| 4 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/builder.rb:50` † | 23.97 | 36% | `app/views/layouts/application.html.erb:17` 50%, `app/views/layouts/application.html.erb:20` 50% | `config.build_cache_dir.join("last#{"-ssr" if ssr}-build-#{config.mode}` |
| 5 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` | 23.73 | 80% | `app/controllers/users_controller.rb:20` 31%, `no app frame` 23% | `binds = binds.inspect` |
| 6 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:177` | 17.34 | 80% | `no app frame` 27%, `app/controllers/users_controller.rb:20` 20% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 7 | debug logging | `RAILS/actionpack/lib/abstract_controller/logger.rb:12` | 16.05 | 92% | `no app frame` 93%, `app/controllers/users_controller.rb:104` 1% | `singleton_class.delegate :logger, :logger=, to: :config` |
| 8 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/builder.rb:77` | 14.79 | 15% | `app/views/layouts/application.html.erb:17` 100% | `stat = File.stat(file)` |
| 9 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:175` | 11.59 | 80% | `no app frame` 27%, `app/controllers/users_controller.rb:20` 20% | `modes = MODES.values_at(*options.compact_blank.keys)` |
| 10 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/builder.rb:80` | 11.51 | 15% | `app/views/layouts/application.html.erb:17` 100% | `signature = [stat.mtime, stat.size]` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activerecord | 501.8 | 540.7 | `database_statements.rb:176` 32.9, `postgresql_adapter.rb:880` 24.3, `log_subscriber.rb:49` 23.7 |
| gem: vite_ruby | 433.0 | 457.1 | `config.rb:41` 191.8, `config.rb:27` 50.7, `config.rb:30` 50.7 |
| rails: activesupport | 348.4 | 426.9 | `log_subscriber.rb:177` 17.3, `broadcast_logger.rb:129` 16.8, `log_subscriber.rb:175` 11.6 |
| rails: actionpack | 323.1 | 484.7 | `static.rb:145` 20.3, `content_security_policy.rb:336` 17.5, `logger.rb:12` 16.1 |
| gem: cancancan | 183.3 | 189.5 | `ability.rb:80` 19.2, `ability.rb:77` 14.8, `ability.rb:145` 9.0 |
| gem: inertia_rails | 118.2 | 122.0 | `props_resolver.rb:89` 15.4, `props_resolver.rb:90` 11.7, `renderer.rb:129` 9.1 |
| rails: actionview | 102.0 | 134.8 | `tag_helper.rb:309` 6.8, `base.rb:230` 6.2, `log_subscriber.rb:61` 4.8 |
| gem: rack | 83.3 | 85.2 | `request.rb:693` 9.5, `utils.rb:408` 7.0, `request.rb:649` 6.6 |
| ruby default gem: uri | 51.2 | 53.0 | `common.rb:465` 22.0, `common.rb:456` 18.0, `common.rb:448` 3.0 |
| rails: activemodel | 49.0 | 51.7 | `string.rb:39` 12.4, `attribute.rb:9` 7.4, `serialization.rb:131` 4.2 |
| gem: json | 41.3 | 42.5 | `common.rb:364` 38.8, `common.rb:1089` 2.5 |
| ruby stdlib | 38.3 | 58.4 | `ipaddr.rb:725` 9.0, `formatter.rb:174` 6.3, `ipaddr.rb:672` 3.6 |
| gem: warden | 33.4 | 34.5 | `proxy.rb:334` 4.9, `proxy.rb:348` 3.5, `proxy.rb:31` 2.0 |
| gem: logger | 31.9 | 32.5 | `log_device.rb:165` 8.4, `log_device.rb:33` 8.4, `logger.rb:692` 8.4 |
| app | 30.7 | 38.8 | `inertia_csrf.rb:29` 1.7, `ability.rb:14` 1.4, `ability.rb:18` 1.4 |
| gem: concurrent-ruby | 16.7 | 17.3 | `safe_initialization.rb:30` 5.4, `mutex_lockable_object.rb:33` 1.8, `mutex_lockable_object.rb:32` 1.8 |
| gem: devise | 10.6 | 23.5 | `helpers.rb:128` 1.6, `authenticatable.rb:107` 0.9, `helpers.rb:117` 0.9 |
| gem: base64 | 9.8 | 9.9 | `base64.rb:283` 4.5, `base64.rb:310` 4.5, `base64.rb:374` 0.9 |
| gem: pagy | 9.3 | 20.1 | `pagy.rb:67` 0.7, `linkable.rb:68` 0.7, `pagy.rb:59` 0.7 |
| rails: railties | 8.2 | 9.3 | `logger.rb:57` 1.8, `engine.rb:748` 1.0, `logger.rb:24` 0.9 |
| gem: vite_rails | 7.9 | 8.2 | `tag_helpers.rb:106` 1.4, `tag_helpers.rb:46` 0.7, `tag_helpers.rb:52` 0.7 |
| gem: bootsnap | 4.3 | 17.2 | `iseq.rb:98` 2.1, `cache.rb:218` 0.6, `iseq.rb:154` 0.5 |
| gem: i18n | 3.8 | 8.0 | `i18n.rb:476` 0.9, `i18n.rb:396` 0.5, `utils.rb:8` 0.4 |
| rails: activestorage | 3.6 | 6.0 | `model.rb:128` 0.9, `model.rb:284` 0.7, `model.rb:114` 0.5 |
| gem: jbuilder | 3.3 | 4.3 | `jbuilder.rb:354` 2.2, `jbuilder.rb:23` 0.7, `jbuilder.rb:359` 0.5 |
| gem: rack-session | 2.7 | 2.8 | `id.rb:275` 0.9, `id.rb:401` 0.9, `id.rb:277` 0.9 |
| gem: tzinfo | 2.6 | 2.6 | `timestamp.rb:208` 1.2, `constant_offset_data_timezone_info.rb:52` 0.6, `timestamp.rb:193` 0.6 |
| ruby default gem: securerandom | 2.1 | 2.2 | `securerandom.rb:71` 2.1 |
| gem: request_store | 1.8 | 1.8 | `middleware.rb:28` 0.9, `middleware.rb:21` 0.9 |
| gem: orm_adapter | 0.5 | 0.6 | `active_record.rb:17` 0.5, `base.rb:110` 0.0, `active_record.rb:54` 0.0 |
| gem: bcrypt | 0.2 | 0.5 | `password.rb:102` 0.1, `password.rb:103` 0.0, `engine.rb:70` 0.0 |
| gem: pg | 0.0 | 0.1 | `result.rb:17` 0.0 |
| gem: erubi | 0.0 | 1.0 | `erubi.rb:196` 0.0, `erubi.rb:134` 0.0, `erubi.rb:139` 0.0 |
| gem: zeitwerk | 0.0 | 0.2 | `file_system.rb:199` 0.0, `cref.rb:47` 0.0, `file_system.rb:152` 0.0 |
| gem: msgpack | 0.0 | 0.2 | `factory.rb:41` 0.0, `factory.rb:9` 0.0, `factory.rb:29` 0.0 |
| gem: responders | 0.0 | 0.9 | `respond_with.rb:43` 0.0, `respond_with.rb:58` 0.0, `responders.rb:39` 0.0 |
| ruby default gem: bundler | 0.0 | 0.0 | `rubygems_integration.rb:192` 0.0 |
| lowrail-profile | 0.0 | 0.0 | `profile.rb:66` 0.0, `profile.rb:56` 0.0 |
