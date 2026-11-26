# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails test:all -v`
* Ruby: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux]
* Rails: 8.1.4, test environment
* Counted in run 1: 74 requests; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 74 | 3231.8 | 0 | 0 | 0 | 0 |
| run2 | 1 | 74 | 3230.8 | 0 | 0 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.72 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/controllers/users_controller.rb:20` | `index` | 78.93 | 16.05 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 4%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` 3% | UsersController#index 100% | `if user.photo.attached?` |
| 2 | `app/controllers/contacts_controller.rb:19` | `index` | 47.5 | 7.18 | 0.09 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 17%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 5%, `RAILS/activerecord/lib/active_record/result.rb:244` 2% | ContactsController#index 100% | `json.data(paged_contacts) do \|contact\|` |
| 3 | `app/controllers/application_controller.rb:13` |  | 39.55 | 5.84 | 0.43 | `RAILS/activemodel/lib/active_model/serialization.rb:131` 8%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 7%, `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 4% | OrganizationsController#edit 19%, UsersController#edit 16%, OrganizationsController#index 15% | `current_user.as_json(` |
| 4 | `app/views/layouts/application.html.erb:20` |  | 34.3 | 141.35 | 0.73 | `GEM/json/lib/json/common.rb:364` 27%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 10%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 6% | Users::SessionsController#new 22%, UsersController#edit 17%, UsersController#index 17% | `<%= vite_javascript_tag 'application' %>` |
| 5 | `app/controllers/users_controller.rb:13` | `index` | 22.19 | 3.43 | 0.32 | `GEM/inertia_rails/lib/inertia_rails/renderer.rb:138` 6%, `GEM/inertia_rails/lib/inertia_rails/props_resolver/dotted_keys.rb:15` 3%, `RAILS/actionpack/lib/action_dispatch/http/response.rb:496` 2% | UsersController#index 100% | `render inertia: 'Users/Index',` |
| 6 | `app/controllers/organizations_controller.rb:14` | `index` | 22.12 | 3.43 | 0.32 | `GEM/inertia_rails/lib/inertia_rails/renderer.rb:138` 6%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:81` 3%, `GEM/inertia_rails/lib/inertia_rails/props_resolver/dotted_keys.rb:15` 2% | OrganizationsController#index 100% | `render inertia: 'Organizations/Index',` |
| 7 | `app/controllers/users/sessions_controller.rb:4` | `new` | 21.35 | 4.32 | 0.32 | `GEM/inertia_rails/lib/inertia_rails/renderer.rb:138` 5%, `RAILS/actionview/lib/action_view/template/resolver.rb:141` 3%, `RAILS/actionview/lib/action_view/template/resolver.rb:181` 3% | Users::SessionsController#new 100%, Users::SessionsController#create 0% | `render inertia: 'Auth/Login', props: {}` |
| 8 | `app/controllers/contacts_controller.rb:7` | `index` | 20.99 | 3.04 | 0.19 | `RAILS/activerecord/lib/arel/visitors/to_sql.rb:801` 4%, `RAILS/activesupport/lib/active_support/delegation.rb:146` 3%, `GEM/rack/lib/rack/request.rb:693` 3% | ContactsController#index 100% | `pagy(` |
| 9 | `app/controllers/users_controller.rb:26` | `index` | 18.24 | 0.0 | 1.09 | `GEM/cancancan/lib/cancan/ability.rb:80` 26%, `GEM/cancancan/lib/cancan/ability.rb:77` 20%, `GEM/cancancan/lib/cancan/ability/rules.rb:56` 6% | UsersController#index 100% | `json.can { json.edit_user can?(:edit, user) }` |
| 10 | `app/controllers/contacts_controller.rb:15` | `index` | 18.01 | 2.38 | 0.28 | `GEM/inertia_rails/lib/inertia_rails/renderer.rb:138` 7%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:81` 3%, `GEM/inertia_rails/lib/inertia_rails/props_resolver/dotted_keys.rb:15` 3% | ContactsController#index 100% | `render inertia: 'Contacts/Index',` |
| 11 | `app/controllers/organizations_controller.rb:18` | `index` | 17.7 | 4.03 | 0.11 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 23%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 8%, `RAILS/activemodel/lib/active_model/type/string.rb:39` 7% | OrganizationsController#index 100% | `json.data(` |
| 12 | `app/controllers/users_controller.rb:47` | `edit` | 15.86 | 3.27 | 0.2 | `GEM/inertia_rails/lib/inertia_rails/renderer.rb:138` 6%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:81` 3%, `RAILS/actionpack/lib/abstract_controller/rendering.rb:66` 2% | UsersController#edit 100% | `render inertia: 'Users/Edit',` |
| 13 | `app/controllers/users_controller.rb:17` | `index` | 15.07 | 3.51 | 0.11 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 19%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 9%, `RAILS/activerecord/lib/arel/visitors/to_sql.rb:801` 4% | UsersController#index 100% | `json.array! @users do \|user\|` |
| 14 | `app/controllers/users_controller.rb:61` | `edit` | 14.69 | 2.97 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 4%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` 3% | UsersController#edit 100% | `if @user.photo.attached?` |
| 15 | `app/controllers/organizations_controller.rb:7` | `index` | 14.03 | 3.0 | 0.22 | `GEM/rack/lib/rack/request.rb:693` 5%, `RAILS/actionpack/lib/action_dispatch/http/url.rb:325` 2%, `RAILS/activerecord/lib/active_record/relation.rb:98` 2% | OrganizationsController#index 100% | `pagy(` |
| 16 | `app/controllers/concerns/inertia_json.rb:26` | `jbuilder` | 13.49 | 0.0 | 0.55 | `RAILS/actionpack/lib/abstract_controller/rendering.rb:66` 21%, `RAILS/actionview/lib/action_view/base.rb:230` 21%, `RAILS/actionpack/lib/abstract_controller/rendering.rb:63` 12% | UsersController#index 19%, OrganizationsController#index 19%, ContactsController#index 17% | `JbuilderTemplate.new(view_context, &).attributes!` |
| 17 | `app/controllers/users/sessions_controller.rb:9` | `create` | 11.23 | 0.7 | 0.0 | `RAILS/actionview/lib/action_view/template/error.rb:0` 11%, `RAILS/actionview/lib/action_view/template/resolver.rb:209` 4%, `RAILS/actionview/lib/action_view/template/resolver.rb:196` 3% | Users::SessionsController#create 100% | `super` |
| 18 | `app/views/layouts/application.html.erb:17` |  | 11.19 | 178.76 | 0.49 | `GEM/json/lib/json/common.rb:364` 83%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 4%, `RAILS/actionview/lib/action_view/helpers/asset_url_helper.rb:217` 2% | Users::SessionsController#new 22%, OrganizationsController#index 17%, UsersController#index 17% | `<link rel="icon" type="image/png" href="<%= vite_asset_path('images/fa` |
| 19 | `app/controllers/concerns/inertia_csrf.rb:30` | `set_csrf_cookie` | 10.36 | 0.0 | 0.0 | `RUBY/openssl/hmac.rb:36` 11%, `GEM/securerandom/lib/securerandom.rb:71` 8%, `RAILS/actionpack/lib/action_controller/metal/request_forgery_protection.rb:603` 6% | OrganizationsController#index 19%, UsersController#index 19%, ContactsController#index 16% | `value: form_authenticity_token,` |
| 20 | `app/controllers/contacts_controller.rb:65` | `edit` | 9.73 | 1.3 | 0.04 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 5%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 3% | ContactsController#edit 100% | `json.array! current_user.organizations.order(:name), :id, :name` |
| 21 | `app/controllers/organizations_controller.rb:33` | `edit` | 7.68 | 1.16 | 0.12 | `GEM/inertia_rails/lib/inertia_rails/renderer.rb:138` 7%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:81` 4%, `RAILS/actionpack/lib/action_dispatch/http/response.rb:496` 3% | OrganizationsController#edit 100% | `render inertia: 'Organizations/Edit',` |
| 22 | `app/controllers/contacts_controller.rb:43` | `edit` | 7.66 | 1.16 | 0.12 | `GEM/inertia_rails/lib/inertia_rails/renderer.rb:138` 7%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:81` 4%, `GEM/inertia_rails/lib/inertia_rails/props_resolver/dotted_keys.rb:15` 3% | ContactsController#edit 100% | `render inertia: 'Contacts/Edit',` |
| 23 | `app/controllers/organizations_controller.rb:53` | `edit` | 6.45 | 1.3 | 0.04 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 9%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `RAILS/activerecord/lib/active_record/relation.rb:77` 3% | OrganizationsController#edit 100% | `json.array! @organization.contacts.order_by_name,` |
| 24 | `app/controllers/users_controller.rb:30` | `index` | 5.24 | 0.0 | 0.11 | `GEM/cancancan/lib/cancan/ability.rb:80` 27%, `GEM/cancancan/lib/cancan/ability.rb:77` 21%, `GEM/cancancan/lib/cancan/ability/rules.rb:56` 6% | UsersController#index 100% | `create_user: can?(:create, User),` |
| 25 | `app/models/ability.rb:13` | `initialize` | 5.2 | 0.0 | 0.95 | `GEM/cancancan/lib/cancan/ability.rb:145` 18%, `GEM/cancancan/lib/cancan/rule.rb:137` 18%, `GEM/cancancan/lib/cancan/rule.rb:121` 9% | UsersController#index 23%, OrganizationsController#index 23%, ContactsController#index 20% | `can :read, User, account_id: user.account_id, deleted_at: nil` |
| 26 | `config/initializers/pagy.rb:12` | `data_hash` | 4.59 | 0.0 | 0.41 | `GEM/pagy/lib/pagy/modules/abilities/linkable.rb:68` 13%, `GEM/pagy/lib/pagy/modules/abilities/linkable.rb:47` 13%, `GEM/pagy/lib/pagy/toolbox/helpers/support/series.rb:15` 9% | OrganizationsController#index 54%, ContactsController#index 46% | `super.tap { \|hash\| hash[:series] = __send__(:series) }` |
| 27 | `app/controllers/dashboard_controller.rb:3` | `index` | 4.55 | 1.05 | 0.04 | `GEM/inertia_rails/lib/inertia_rails/renderer.rb:138` 4%, `RAILS/actionview/lib/action_view/template/resolver.rb:209` 3%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:208` 2% | DashboardController#index 100% | `render inertia: 'Dashboard/Index',` |
| 28 | `app/models/concerns/soft_delete.rb:7` |  | 4.36 | 0.0 | 0.51 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` 12%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 12%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:166` 12% | OrganizationsController#index 37%, UsersController#index 32%, ContactsController#index 32% | `scope :not_trashed, -> { where(deleted_at: nil) }` |
| 29 | `app/models/ability.rb:18` | `initialize` | 4.26 | 0.0 | 0.95 | `GEM/cancancan/lib/cancan/rule.rb:137` 22%, `GEM/cancancan/lib/cancan/ability.rb:145` 22%, `GEM/cancancan/lib/cancan/ability/rules.rb:24` 11% | UsersController#index 23%, OrganizationsController#index 23%, ContactsController#index 20% | `can :manage, Organization, account_id: user.account_id, deleted_at: ni` |
| 30 | `app/models/ability.rb:17` | `initialize` | 4.26 | 0.0 | 0.95 | `GEM/cancancan/lib/cancan/ability.rb:145` 22%, `GEM/cancancan/lib/cancan/rule.rb:137` 22%, `GEM/cancancan/lib/cancan/rule.rb:121` 11% | OrganizationsController#index 23%, UsersController#index 23%, ContactsController#index 20% | `can :manage, Contact, account_id: user.account_id, deleted_at: nil` |

623.58 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | UsersController#index | 10 / 10 | 3233.6 / 3140.4 | -93.1 | 3779.7 | `GEM/cancancan/lib/cancan/ability.rb:80` 62.1, `GEM/cancancan/lib/cancan/ability.rb:77` 47.8, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 37.2 | `app/controllers/users_controller.rb:20` 649.0, `app/controllers/users_controller.rb:13` 182.4, `app/controllers/users_controller.rb:26` 150.0 |
| 2 | DashboardController#index | 2 / 2 | 2853.0 / 2858.0 | 5.0 | 2181.0 | `GEM/json/lib/json/common.rb:364` 76.0, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0, `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:336` 20.0 | `app/controllers/dashboard_controller.rb:3` 337.0, `app/views/layouts/application.html.erb:20` 141.0, `app/views/layouts/application.html.erb:17` 46.0 |
| 3 | UsersController#edit | 6 / 6 | 2764.0 / 2765.2 | 1.2 | 2914.2 | `GEM/json/lib/json/common.rb:364` 52.0, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0, `GEM/cancancan/lib/cancan/ability.rb:80` 26.0 | `app/controllers/users_controller.rb:47` 234.8, `app/controllers/users_controller.rb:61` 217.4, `app/controllers/application_controller.rb:13` 91.4 |
| 4 | ContactsController#index | 10 / 10 | 2637.1 / 2635.3 | -1.8 | 2861.1 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 75.9, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 27.8, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0 | `app/controllers/contacts_controller.rb:19` 390.6, `app/controllers/contacts_controller.rb:7` 172.6, `app/controllers/contacts_controller.rb:15` 148.1 |
| 5 | OrganizationsController#index | 10 / 10 | 2522.2 / 2525.9 | 3.7 | 2695.8 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 41.9, `GEM/json/lib/json/common.rb:364` 32.4, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0 | `app/controllers/organizations_controller.rb:14` 181.9, `app/controllers/organizations_controller.rb:18` 145.6, `app/controllers/organizations_controller.rb:7` 115.3 |
| 6 | ContactsController#edit | 4 / 4 | 2401.7 / 2399.0 | -2.7 | 2870.8 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 39.3, `GEM/json/lib/json/common.rb:364` 36.0, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0 | `app/controllers/contacts_controller.rb:65` 240.0, `app/controllers/contacts_controller.rb:43` 189.0, `app/controllers/application_controller.rb:13` 134.3 |
| 7 | OrganizationsController#edit | 4 / 4 | 2393.0 / 2377.7 | -15.3 | 6596.3 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 39.3, `GEM/json/lib/json/common.rb:364` 36.0, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0 | `app/controllers/organizations_controller.rb:33` 189.3, `app/controllers/application_controller.rb:13` 182.0, `app/controllers/organizations_controller.rb:53` 159.0 |
| 8 | Users::SessionsController#new | 7 / 7 | 2082.8 / 2148.3 | 65.5 | 2310.6 | `GEM/json/lib/json/common.rb:364` 59.0, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0, `RAILS/activesupport/lib/active_support/inflector/methods.rb:78` 24.0 | `app/controllers/users/sessions_controller.rb:4` 263.3, `app/views/layouts/application.html.erb:20` 94.0, `app/views/layouts/application.html.erb:17` 30.7 |
| 9 | Users::SessionsController#create | 2 / 2 | 1697.0 / 1693.0 | -4.0 | 1659.5 | `RAILS/actionview/lib/action_view/template/error.rb:0` 93.0, `RAILS/actionview/lib/action_view/template/resolver.rb:209` 36.0, `RAILS/actionview/lib/action_view/template_path.rb:23` 24.0 | `app/controllers/users/sessions_controller.rb:9` 831.0, `app/controllers/concerns/auth.rb:17` 20.0, `app/controllers/concerns/inertia_csrf.rb:30` 15.0 |
| 10 | UsersController#new | 2 / 2 | 1645.0 / 1646.0 | 1.0 | 2794.0 | `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0, `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:336` 20.0, `GEM/uri/lib/uri/common.rb:465` 20.0 | `app/controllers/application_controller.rb:13` 188.0, `app/controllers/users_controller.rb:37` 132.0, `app/controllers/concerns/inertia_json.rb:26` 24.0 |
| 11 | (no action name) | 6 / 6 | 115.8 / 115.8 | 0.0 | 115.3 | `GEM/rack/lib/rack/utils.rb:693` 17.4, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:135` 14.4, `GEM/rack/lib/rack/request.rb:649` 8.0 |  |
| 12 | OrganizationsController#update | 1 / 1 | – / – |  | 2295.0 |  |  |
| 13 | UsersController#update | 1 / 1 | – / – |  | 2141.0 |  |  |
| 14 | UsersController#create | 1 / 1 | – / – |  | 2102.0 |  |  |
| 15 | ContactsController#create | 1 / 1 | – / – |  | 2062.0 |  |  |
| 16 | UsersController#destroy | 1 / 1 | – / – |  | 2033.0 |  |  |
| 17 | OrganizationsController#create | 1 / 1 | – / – |  | 2030.0 |  |  |
| 18 | ContactsController#new | 1 / 1 | – / – |  | 1954.0 |  |  |
| 19 | ContactsController#update | 1 / 1 | – / – |  | 1851.0 |  |  |
| 20 | OrganizationsController#destroy | 1 / 1 | – / – |  | 1779.0 |  |  |
| 21 | ContactsController#destroy | 1 / 1 | – / – |  | 1775.0 |  |  |
| 22 | Users::SessionsController#destroy | 1 / 1 | – / – |  | 1363.0 |  |  |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/json/lib/json/common.rb:364` | `parse` | 34.0 / 34.0 | 0.0 | 35.09 | 88% | String, Hash |  | `app/views/layouts/application.html.erb:17` 38%, `app/views/layouts/application.html.erb:20` 38% | `Parser.parse(source, opts)` |
| 2 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` | `cast_result` | 32.73 / 32.73 | 0.0 | 32.93 | 76% | String, Data |  | `app/controllers/contacts_controller.rb:19` 34%, `no app frame` 23% | `ActiveRecord::Result.new(fields, result.values, types.freeze, affected` |
| 3 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` | `get_oid_type` | 22.96 / 22.96 | 0.0 | 23.74 | 76% | Array |  | `no app frame` 41%, `app/controllers/users_controller.rb:20` 16% | `type_map.fetch(oid, fmod, sql_type) {` |
| 4 | `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` | `file_readable?` | 20.39 / 20.39 | 0.0 | 20.76 | 84% | String, Array |  | `no app frame` 100% | `file_path = File.join(@root, path.b)` |
| 5 | `GEM/cancancan/lib/cancan/ability.rb:80` | `can?` | 19.68 / 19.68 | 0.0 | 19.88 | 70% | Data, Array |  | `no app frame` 46%, `app/controllers/users_controller.rb:26` 39% | `results.reject(&:nil?).first \|\| false` |
| 6 | `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:336` | `build_directives` | 17.57 / 17.57 | 0.0 | 17.84 | 89% | String |  | `no app frame` 100% | `"#{directive} #{build_directive(directive, sources, context).join(' ')` |
| 7 | `GEM/uri/lib/uri/common.rb:456` | `_encode_uri_component` | 17.81 / 17.09 | -0.72 | 17.71 | 92% | String, MatchData |  | `no app frame` 99%, `config/initializers/pagy.rb:12` 1% | `str.gsub!(regexp, table)` |
| 8 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | `#{method}` | 16.62 / 16.62 | 0.0 | 16.95 | 92% | Array, Hash |  | `no app frame` 48%, `app/controllers/users_controller.rb:20` 7% | `dispatch(:#{method}, ...)` |
| 9 | `GEM/cancancan/lib/cancan/ability.rb:77` | `can?` | 15.14 / 15.14 | 0.0 | 15.3 | 70% | Data, Array |  | `no app frame` 46%, `app/controllers/users_controller.rb:26` 39% | `results = extract_subjects(subject).lazy.map do \|a_subject\|` |
| 10 | `GEM/uri/lib/uri/common.rb:465` | `_decode_uri_component` | 13.77 / 13.12 | -0.65 | 13.76 | 58% | String, MatchData |  | `no app frame` 100% | `str.b.gsub(regexp, TBLDECWWWCOMP_).force_encoding(enc)` |
| 11 | `RAILS/activemodel/lib/active_model/type/string.rb:39` | `cast_value` | 12.38 / 12.38 | 0.0 | 12.58 | 77% | String |  | `app/controllers/organizations_controller.rb:18` 14%, `app/controllers/application_controller.rb:13` 13% | `when ::String then ::String.new(value)` |
| 12 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | `merge` | 11.84 / 11.84 | 0.0 | 11.95 | 49% | Array, Object |  | `app/controllers/users_controller.rb:20` 60%, `app/controllers/application_controller.rb:13` 14% | `WhereClause.new(predicates \| other.predicates)` |
| 13 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` | `call` | 10.81 / 10.81 | 0.0 | 10.96 | 92% | Data |  | `no app frame` 93%, `app/models/concerns/soft_delete.rb:25` 2% | `result_lambda = -> { user_callback.call target, value }` |
| 14 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:382` | `apply_inflections` | 10.8 / 10.8 | 0.0 | 11.19 | 89% | String, MatchData |  | `no app frame` 97%, `app/controllers/contacts_controller.rb:65` 1% | `rules.each { \|(rule, replacement)\| break if result.sub!(rule, replacem` |
| 15 | `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:348` | `validate` | 10.54 / 10.54 | 0.0 | 10.7 | 89% | String |  | `no app frame` 100% | `if source.include?(";") \|\| source != source.gsub(/[[:space:]]/, "")` |
| 16 | `RAILS/actionpack/lib/action_dispatch/http/request.rb:66` | `initialize` | 9.61 / 9.61 | 0.0 | 9.77 | 100% | Object, Data |  | `no app frame` 99%, `app/controllers/users/sessions_controller.rb:9` 0% | `@rack_request = Rack::Request.new(env)` |
| 17 | `GEM/rack/lib/rack/request.rb:693` | `split_header` | 9.51 / 9.51 | 0.0 | 9.62 | 92% | Array |  | `no app frame` 79%, `app/controllers/organizations_controller.rb:7` 8% | `value ? value.strip.split(/[, \t]+/) : []` |
| 18 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` | `+` | 9.46 / 9.46 | 0.0 | 9.51 | 76% | Object, Array |  | `app/controllers/users_controller.rb:20` 50%, `no app frame` 18% | `WhereClause.new(predicates + other.predicates)` |
| 19 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:78` | `camelize` | 9.45 / 9.45 | 0.0 | 9.62 | 84% | String, MatchData |  | `no app frame` 100% | `string = string.sub(/^[a-z\d]*/) { \|match\| inflections.acronyms[match]` |
| 20 | `GEM/inertia_rails/lib/inertia_rails/renderer.rb:138` | `extract_shared_keys` | 9.14 / 9.14 | 0.0 | 9.31 | 72% | String, Array |  | `app/controllers/users_controller.rb:13` 17%, `app/controllers/organizations_controller.rb:14` 17% | `shared_props.keys.map { \|key\| key.to_s.split('.', 2).first }.uniq` |
| 21 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` | `build_handle` | 9.09 / 9.09 | 0.0 | 9.3 | 92% | Object, Data | #59613 merged 2026-11-04, after this app's version, not released yet, #59235 merged 2026-10-21, after this app's version, not released yet | `no app frame` 36%, `app/controllers/users_controller.rb:20` 13% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 22 | `GEM/cancancan/lib/cancan/ability.rb:145` | `can` | 9.08 / 9.08 | 0.0 | 9.28 | 70% | Array, Object |  | `app/models/ability.rb:13` 15%, `app/models/ability.rb:17` 15% | `add_rule(Rule.new(true, action, subject, *attributes_and_conditions, &` |
| 23 | `GEM/cancancan/lib/cancan/rule.rb:137` | `wrap` | 9.08 / 9.08 | 0.0 | 9.27 | 70% | Array |  | `app/models/ability.rb:14` 15%, `app/models/ability.rb:17` 15% | `[object]` |
| 24 | `RUBY/ipaddr.rb:725` | `in_addr` | 9.05 / 9.05 | 0.0 | 9.19 | 92% | String, Array |  | `no app frame` 100% | `octets = addr.split('.')` |
| 25 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` | `expand_from_hash` | 8.92 / 8.92 | 0.0 | 8.97 | 76% | Array |  | `app/controllers/users_controller.rb:20` 40%, `no app frame` 33% | `attributes.flat_map do \|key, value\|` |
| 26 | `RAILS/activerecord/lib/arel/table.rb:85` | `[]` | 8.86 / 8.86 | 0.0 | 8.95 | 76% | Struct |  | `no app frame` 28%, `app/controllers/users_controller.rb:20` 27% | `Attribute.new(table, name)` |
| 27 | `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:347` | `validate` | 8.78 / 8.78 | 0.0 | 8.92 | 89% | Array |  | `no app frame` 100% | `sources.flatten.each do \|source\|` |
| 28 | `RAILS/actionpack/lib/action_dispatch/http/content_security_policy.rb:359` | `build_directive` | 8.78 / 8.78 | 0.0 | 8.92 | 89% | Array |  | `no app frame` 100% | `resolved_sources = sources.map { \|source\| resolve_source(source, conte` |
| 29 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:166` | `convert_dot_notation_to_hash` | 8.78 / 8.78 | 0.0 | 8.84 | 76% | Array, Hash |  | `app/controllers/users_controller.rb:20` 40%, `no app frame` 34% | `attributes.each_with_object({}) do \|(key, value), converted\|` |
| 30 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:217` | `dispatch` | 8.31 / 8.31 | 0.0 | 8.47 | 92% | Array |  | `no app frame` 48%, `app/controllers/users_controller.rb:20` 7% | `@broadcasts.map { \|logger\|` |

## Dev/test-mode work

659.2 of 2356.9 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/config.rb:41` † | 189.19 | 35% | `app/views/layouts/application.html.erb:20` 50%, `app/views/layouts/application.html.erb:17` 50% | `root.join(public_dir, public_output_dir)` |
| 2 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/config.rb:27` † | 50.0 | 35% | `app/views/layouts/application.html.erb:17` 50%, `app/views/layouts/application.html.erb:20` 50% | `build_output_dir.join(".vite/manifest.json"),` |
| 3 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/config.rb:30` † | 50.0 | 35% | `app/views/layouts/application.html.erb:20` 50%, `app/views/layouts/application.html.erb:17` 50% | `build_output_dir.join(".vite/manifest-assets.json"),` |
| 4 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/builder.rb:50` † | 23.65 | 35% | `app/views/layouts/application.html.erb:20` 50%, `app/views/layouts/application.html.erb:17` 50% | `config.build_cache_dir.join("last#{"-ssr" if ssr}-build-#{config.mode}` |
| 5 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` | 23.54 | 76% | `app/controllers/users_controller.rb:20` 33%, `no app frame` 22% | `binds = binds.inspect` |
| 6 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/builder.rb:77` | 20.43 | 20% | `app/views/layouts/application.html.erb:17` 100% | `stat = File.stat(file)` |
| 7 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:177` | 17.11 | 76% | `no app frame` 26%, `app/controllers/users_controller.rb:20` 21% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 8 | debug logging | `RAILS/actionpack/lib/abstract_controller/logger.rb:12` | 16.04 | 92% | `no app frame` 93%, `app/controllers/users_controller.rb:76` 1% | `singleton_class.delegate :logger, :logger=, to: :config` |
| 9 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/builder.rb:80` | 15.89 | 20% | `app/views/layouts/application.html.erb:17` 100% | `signature = [stat.mtime, stat.size]` |
| 10 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/builder.rb:98` † | 15.89 | 20% | `app/views/layouts/application.html.erb:17` 100% | `Time.now - stat.mtime < 1` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activerecord | 494.7 | 532.1 | `database_statements.rb:176` 32.7, `log_subscriber.rb:49` 23.5, `postgresql_adapter.rb:880` 23.0 |
| gem: vite_ruby | 452.5 | 476.3 | `config.rb:41` 189.2, `config.rb:30` 50.0, `config.rb:27` 50.0 |
| rails: activesupport | 332.8 | 399.4 | `log_subscriber.rb:177` 17.1, `broadcast_logger.rb:129` 16.6, `log_subscriber.rb:175` 11.4 |
| rails: actionpack | 318.1 | 397.4 | `static.rb:145` 20.4, `content_security_policy.rb:336` 17.6, `logger.rb:12` 16.0 |
| gem: cancancan | 187.5 | 192.7 | `ability.rb:80` 19.7, `ability.rb:77` 15.1, `rule.rb:137` 9.1 |
| rails: actionview | 102.3 | 133.2 | `tag_helper.rb:309` 6.8, `base.rb:230` 6.0, `log_subscriber.rb:61` 4.7 |
| gem: rack | 79.2 | 81.1 | `request.rb:693` 9.5, `utils.rb:408` 7.0, `request.rb:649` 6.6 |
| gem: inertia_rails | 75.1 | 78.7 | `renderer.rb:138` 9.1, `props_resolver.rb:81` 4.3, `dotted_keys.rb:15` 3.4 |
| rails: activemodel | 47.7 | 50.4 | `string.rb:39` 12.4, `attribute.rb:9` 6.7, `serialization.rb:131` 4.1 |
| ruby default gem: uri | 42.0 | 43.2 | `common.rb:456` 17.5, `common.rb:465` 13.4, `common.rb:448` 3.0 |
| ruby stdlib | 37.9 | 56.4 | `ipaddr.rb:725` 9.1, `formatter.rb:174` 6.3, `ipaddr.rb:672` 3.6 |
| gem: json | 36.5 | 37.6 | `common.rb:364` 34.0, `common.rb:1089` 2.5 |
| gem: warden | 33.4 | 34.3 | `proxy.rb:334` 4.9, `proxy.rb:348` 3.5, `proxy.rb:31` 2.0 |
| gem: logger | 31.6 | 32.3 | `logger.rb:692` 8.3, `log_device.rb:165` 8.3, `log_device.rb:33` 8.3 |
| app | 30.8 | 37.7 | `inertia_csrf.rb:29` 1.7, `ability.rb:18` 1.4, `ability.rb:13` 1.4 |
| gem: concurrent-ruby | 16.6 | 17.2 | `safe_initialization.rb:30` 5.4, `mutex_lockable_object.rb:32` 1.8, `mutex_lockable_object.rb:33` 1.8 |
| gem: devise | 10.6 | 14.6 | `helpers.rb:128` 1.6, `helpers.rb:117` 0.9, `authenticatable.rb:107` 0.9 |
| gem: pagy | 9.2 | 19.8 | `linkable.rb:68` 0.6, `linkable.rb:47` 0.6, `pagy.rb:59` 0.6 |
| gem: base64 | 8.5 | 8.6 | `base64.rb:283` 4.5, `base64.rb:310` 3.2, `base64.rb:374` 0.9 |
| rails: railties | 8.3 | 8.9 | `logger.rb:57` 1.8, `engine.rb:748` 1.0, `logger.rb:21` 0.9 |
| gem: vite_rails | 7.8 | 8.1 | `tag_helpers.rb:106` 1.4, `tag_helpers.rb:52` 0.7, `tag_helpers.rb:48` 0.7 |
| gem: i18n | 3.7 | 8.2 | `i18n.rb:476` 0.9, `i18n.rb:396` 0.4, `utils.rb:8` 0.4 |
| gem: jbuilder | 3.6 | 4.3 | `jbuilder.rb:354` 2.5, `jbuilder.rb:23` 0.6, `jbuilder.rb:359` 0.5 |
| rails: activestorage | 3.5 | 5.2 | `model.rb:128` 0.9, `model.rb:284` 0.5, `attached.rb:13` 0.5 |
| gem: bootsnap | 3.5 | 15.1 | `iseq.rb:98` 1.7, `cache.rb:218` 0.5, `iseq.rb:154` 0.4 |
| ruby default gem: securerandom | 2.7 | 2.8 | `securerandom.rb:71` 2.7 |
| gem: rack-session | 2.7 | 2.8 | `id.rb:275` 0.9, `id.rb:401` 0.9, `id.rb:277` 0.9 |
| gem: tzinfo | 2.4 | 2.6 | `timestamp.rb:208` 1.1, `timestamp.rb:193` 0.6, `constant_offset_data_timezone_info.rb:52` 0.6 |
| gem: request_store | 1.8 | 1.8 | `middleware.rb:28` 0.9, `middleware.rb:21` 0.9 |
| gem: orm_adapter | 0.5 | 0.6 | `active_record.rb:17` 0.5, `base.rb:105` 0.0, `base.rb:100` 0.0 |
| gem: bcrypt | 0.2 | 0.5 | `password.rb:102` 0.1, `engine.rb:70` 0.0, `password.rb:103` 0.0 |
| gem: pg | 0.0 | 0.0 | `result.rb:17` 0.0 |
| lowrail-profile | 0.0 | 0.0 | `profile.rb:66` 0.0, `profile.rb:56` 0.0 |
| ruby default gem: bundler | 0.0 | 0.0 | `rubygems_integration.rb:192` 0.0 |
| gem: erubi | 0.0 | 1.0 | `erubi.rb:134` 0.0, `erubi.rb:196` 0.0, `erubi.rb:110` 0.0 |
| gem: msgpack | 0.0 | 0.2 | `factory.rb:41` 0.0, `factory.rb:31` 0.0, `factory.rb:29` 0.0 |
| gem: zeitwerk | 0.0 | 0.2 | `constant_path_validator.rb:13` 0.0, `cref.rb:47` 0.0, `callbacks.rb:54` 0.0 |
| gem: responders | 0.0 | 0.9 | `respond_with.rb:48` 0.0, `responders.rb:39` 0.0, `responder.rb:325` 0.0 |
