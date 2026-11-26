# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bundle exec rspec --format documentation --seed 1234`
* Ruby: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux]
* Rails: 8.1.4, test environment
* Counted in run 1: 54 requests, 4 mail windows; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 54 | 2182.1 | 0 | 4 | 0 | 0 |
| run2 | 1 | 54 | 2181.9 | 0 | 4 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.41 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/views/layouts/application.html.erb:31` |  | 89.65 | 0.0 | 0.22 | `GEM/json/lib/json/common.rb:302` 31%, `GEM/rails_vite/lib/rails_vite/config.rb:16` 28%, `GEM/rails_vite/lib/rails_vite/config.rb:8` 18% | SessionsController#new 34%, UsersController#new 33%, DashboardController#index 33% | `<%= vite_tags "application.css", "inertia.tsx" %>` |
| 2 | `app/controllers/application_controller.rb:24` | `perform_authentication` | 23.7 | 6.89 | 0.0 | `GEM/uri/lib/uri/common.rb:465` 4%, `GEM/rack/lib/rack/utils.rb:331` 3%, `GEM/sqlite3/lib/sqlite3/statement.rb:54` 3% | DashboardController#index 23%, SessionsController#new 17%, SessionsController#create 17% | `Current.session \|\|= Session.find_by_id(cookies.signed[:session_token])` |
| 3 | `app/controllers/users_controller.rb:21` | `create` | 11.2 | 0.26 | 0.06 | `GEM/i18n/lib/i18n.rb:476` 18%, `GEM/i18n/lib/i18n/backend/base.rb:157` 7%, `GEM/i18n/lib/i18n.rb:396` 5% | UsersController#create 100% | `redirect_to sign_up_path, inertia: { errors: @user.errors }` |
| 4 | `app/controllers/users_controller.rb:14` | `create` | 10.07 | 1.67 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 60%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 2%, `RAILS/activemodel/lib/active_model/error.rb:204` 1% | UsersController#create 100% | `if @user.save` |
| 5 | `app/models/current.rb:7` |  | 9.7 | 2.67 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 5%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 3% | Settings::PasswordsController#update 25%, DashboardController#index 25%, Settings::EmailsController#update 25% | `delegate :user, to: :session, allow_nil: true` |
| 6 | `app/controllers/users_controller.rb:28` | `destroy` | 8.7 | 2.78 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 3%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 3%, `GEM/sqlite3/lib/sqlite3/statement.rb:186` 3% | UsersController#destroy 100% | `user.destroy!` |
| 7 | `app/controllers/identity/password_resets_controller.rb:25` | `update` | 8.24 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 70%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 2%, `RAILS/activesupport/lib/active_support/inflector/methods.rb:146` 1% | Identity::PasswordResetsController#update 100% | `if @user.update(user_params)` |
| 8 | `app/controllers/settings/passwords_controller.rb:10` | `update` | 8.11 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 71%, `GEM/bcrypt/lib/bcrypt/password.rb:102` 3%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 3% | Settings::PasswordsController#update 100% | `if @user.update(user_params)` |
| 9 | `app/controllers/settings/emails_controller.rb:10` | `update` | 8.02 | 2.52 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 3%, `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 3%, `RAILS/activemodel/lib/active_model/type/string.rb:39` 3% | Settings::EmailsController#update 100% | `if @user.update(user_params)` |
| 10 | `app/controllers/sessions_controller.rb:13` | `create` | 6.48 | 1.91 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:149` 3%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 2%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:144` 2% | SessionsController#create 100% | `@session = user.sessions.create!` |
| 11 | `app/controllers/identity/password_resets_controller.rb:28` | `update` | 6.17 | 0.26 | 0.07 | `GEM/i18n/lib/i18n.rb:476` 13%, `GEM/i18n/lib/i18n/backend/base.rb:157` 4%, `GEM/i18n/lib/i18n.rb:396` 3% | Identity::PasswordResetsController#update 100% | `redirect_to edit_identity_password_reset_path(sid: params[:sid]), iner` |
| 12 | `app/controllers/settings/emails_controller.rb:37` | `resend_email_verification` | 5.72 | 0.44 | 0.02 | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:101` 27%, `GEM/globalid/lib/global_id/uri/gid.rb:95` 3%, `GEM/uri/lib/uri/common.rb:90` 3% | Settings::EmailsController#update 100% | `UserMailer.with(user: @user).email_verification.deliver_later` |
| 13 | `app/controllers/identity/email_verifications_controller.rb:9` | `show` | 4.81 | 1.74 | 0.02 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 5%, `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 5%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 4% | Identity::EmailVerificationsController#show 100% | `@user.update! verified: true` |
| 14 | `app/controllers/identity/password_resets_controller.rb:37` | `set_user` | 4.3 | 0.5 | 0.07 | `RAILS/activesupport/lib/active_support/key_generator.rb:63` 4%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:55` 3%, `GEM/uri/lib/uri/rfc3986_parser.rb:85` 3% | Identity::PasswordResetsController#update 50%, Identity::PasswordResetsController#edit 50% | `redirect_to new_identity_password_reset_path, alert: "That password re` |
| 15 | `app/controllers/identity/password_resets_controller.rb:20` | `create` | 4.26 | 0.52 | 0.07 | `RAILS/activesupport/lib/active_support/key_generator.rb:63` 4%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:55` 3%, `GEM/uri/lib/uri/rfc3986_parser.rb:85` 3% | Identity::PasswordResetsController#create 100% | `redirect_to new_identity_password_reset_path, alert: "You can't reset ` |
| 16 | `app/controllers/settings/passwords_controller.rb:13` | `update` | 4.17 | 0.26 | 0.06 | `GEM/i18n/lib/i18n/backend/base.rb:157` 6%, `GEM/i18n/lib/i18n.rb:396` 5%, `GEM/i18n/lib/i18n/backend/simple.rb:100` 4% | Settings::PasswordsController#update 100% | `redirect_to settings_password_path, inertia: { errors: @user.errors }` |
| 17 | `app/controllers/identity/password_resets_controller.rb:35` | `set_user` | 3.91 | 0.67 | 0.0 | `GEM/json/lib/json/common.rb:302` 7%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 3%, `RUBY/time.rb:642` 3% | Identity::PasswordResetsController#update 95%, Identity::PasswordResetsController#edit 5% | `@user = User.find_by_token_for!(:password_reset, params[:sid])` |
| 18 | `app/controllers/sessions_controller.rb:12` | `create` | 3.81 | 1.33 | 0.04 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` 7%, `GEM/bcrypt/lib/bcrypt/password.rb:102` 6%, `RAILS/activerecord/lib/active_record/secure_password.rb:42` 5% | SessionsController#create 100% | `if user = User.authenticate_by(email: params[:email], password: params` |
| 19 | `app/controllers/identity/email_verifications_controller.rb:21` | `set_user` | 3.69 | 0.67 | 0.0 | `GEM/json/lib/json/common.rb:302` 7%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 4%, `RUBY/time.rb:642` 3% | Identity::EmailVerificationsController#show 100% | `@user = User.find_by_token_for!(:email_verification, params[:sid])` |
| 20 | `app/controllers/identity/email_verifications_controller.rb:23` | `set_user` | 2.17 | 0.24 | 0.04 | `RAILS/activesupport/lib/active_support/key_generator.rb:63` 4%, `GEM/rack/lib/rack/request.rb:693` 3%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:55` 3% | Identity::EmailVerificationsController#show 100% | `redirect_to settings_email_path, alert: "That email verification link ` |
| 21 | `app/controllers/identity/email_verifications_controller.rb:10` | `show` | 2.11 | 0.26 | 0.04 | `RAILS/activesupport/lib/active_support/key_generator.rb:63` 4%, `GEM/uri/lib/uri/rfc3986_parser.rb:85` 4%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:55` 4% | Identity::EmailVerificationsController#show 100% | `redirect_to root_path, notice: "Thank you for verifying your email add` |
| 22 | `app/controllers/users_controller.rb:30` | `destroy` | 2.09 | 0.26 | 0.06 | `RAILS/activesupport/lib/active_support/key_generator.rb:63` 4%, `GEM/uri/lib/uri/common.rb:108` 4%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:55` 4% | UsersController#destroy 100% | `redirect_to root_path, notice: "Your account has been deleted", inerti` |
| 23 | `app/controllers/settings/emails_controller.rb:30` | `redirect_to_success` | 1.98 | 0.26 | 0.04 | `RAILS/activesupport/lib/active_support/key_generator.rb:63` 5%, `GEM/rack/lib/rack/request.rb:693` 4%, `GEM/uri/lib/uri/rfc3986_parser.rb:85` 4% | Settings::EmailsController#update 100% | `redirect_to settings_email_path, notice: "Your email has been changed"` |
| 24 | `app/controllers/sessions_controller.rb:16` | `create` | 1.98 | 0.26 | 0.04 | `RAILS/activesupport/lib/active_support/key_generator.rb:63` 5%, `GEM/rack/lib/rack/request.rb:693` 4%, `GEM/uri/lib/uri/rfc3986_parser.rb:85` 4% | SessionsController#create 100% | `redirect_to dashboard_path, notice: "Signed in successfully"` |
| 25 | `app/controllers/sessions_controller.rb:18` | `create` | 1.98 | 0.26 | 0.04 | `RAILS/activesupport/lib/active_support/key_generator.rb:63` 5%, `GEM/uri/lib/uri/rfc3986_parser.rb:85` 4%, `GEM/rack/lib/rack/request.rb:693` 4% | SessionsController#create 100% | `redirect_to sign_in_path, alert: "That email or password is incorrect"` |
| 26 | `app/controllers/identity/password_resets_controller.rb:16` | `create` | 1.94 | 1.48 | 0.07 | `GEM/sqlite3/lib/sqlite3/statement.rb:54` 6%, `RAILS/activerecord/lib/active_record/core.rb:288` 6%, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/database_statements.rb:49` 4% | Identity::PasswordResetsController#create 100% | `if @user = User.find_by(email: params[:email], verified: true)` |
| 27 | `app/controllers/application_controller.rb:28` | `set_current_request_details` | 1.67 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/current_attributes.rb:236` 80%, `RAILS/activesupport/lib/active_support/current_attributes.rb:104` 20%, `RUBY/bundled_gems.rb:111` 0% | SessionsController#create 11%, Identity::PasswordResetsController#create 11%, SessionsController#new 11% | `Current.user_agent = request.user_agent` |
| 28 | `app/controllers/application_controller.rb:13` | `authenticate` | 1.19 | 0.26 | 0.02 | `GEM/uri/lib/uri/rfc3986_parser.rb:85` 6%, `GEM/rack/lib/rack/request.rb:693` 6%, `GEM/uri/lib/uri/common.rb:108` 6% | DashboardController#index 100% | `redirect_to sign_in_path unless perform_authentication` |
| 29 | `app/controllers/application_controller.rb:20` | `require_no_authentication` | 1.17 | 0.26 | 0.02 | `GEM/rack/lib/rack/request.rb:693` 6%, `GEM/uri/lib/uri/common.rb:108` 6%, `GEM/uri/lib/uri/rfc3986_parser.rb:85` 6% | SessionsController#new 100%, UsersController#new 0% | `redirect_to root_path` |
| 30 | `app/controllers/sessions_controller.rb:14` | `create` | 1.13 | 0.0 | 0.02 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:149` 10%, `RAILS/activesupport/lib/active_support/core_ext/hash/keys.rb:35` 10%, `GEM/tzinfo/lib/tzinfo/timestamp.rb:208` 7% | SessionsController#create 100% | `cookies.signed.permanent[:session_token] = { value: @session.id, httpo` |

336.43 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | UsersController#new | 2 / 2 | 3708.0 / 3709.0 | 1.0 | 2491.0 | `GEM/rails_vite/lib/rails_vite/config.rb:16` 678.0, `GEM/json/lib/json/common.rb:302` 490.0, `RUBY/net/http.rb:1682` 333.0 | `app/views/layouts/application.html.erb:31` 1602.0, `app/controllers/application_controller.rb:24` 108.0, `app/views/layouts/application.html.erb:9` 18.0 |
| 2 | DashboardController#index | 3 / 3 | 2490.5 / 2488.5 | -2.0 | 2433.0 | `GEM/rails_vite/lib/rails_vite/config.rb:16` 452.0, `GEM/json/lib/json/common.rb:302` 254.5, `RUBY/net/http.rb:1682` 170.0 | `app/views/layouts/application.html.erb:31` 801.0, `app/controllers/application_controller.rb:24` 148.0, `app/models/current.rb:7` 65.5 |
| 3 | SessionsController#new | 3 / 3 | 2333.0 / 2330.0 | -3.0 | 6856.7 | `GEM/rails_vite/lib/rails_vite/config.rb:16` 452.0, `GEM/json/lib/json/common.rb:302` 263.5, `RUBY/net/http.rb:1682` 166.5 | `app/views/layouts/application.html.erb:31` 818.5, `app/controllers/application_controller.rb:24` 109.5, `app/controllers/application_controller.rb:20` 31.5 |
| 4 | UsersController#create | 2 / 2 | 2165.0 / 2170.0 | 5.0 | 2231.0 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 328.0, `GEM/rails_vite/lib/rails_vite/config.rb:16` 226.0, `GEM/i18n/lib/i18n.rb:476` 111.0 | `app/controllers/users_controller.rb:21` 605.0, `app/controllers/users_controller.rb:14` 544.0, `app/controllers/application_controller.rb:24` 108.0 |
| 5 | Settings::EmailsController#update | 2 / 2 | 2105.0 / 2110.0 | 5.0 | 2302.0 | `GEM/rails_vite/lib/rails_vite/config.rb:16` 226.0, `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:101` 83.0, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 26.0 | `app/controllers/settings/emails_controller.rb:10` 433.0, `app/controllers/settings/emails_controller.rb:37` 309.0, `app/models/current.rb:7` 131.0 |
| 6 | Identity::EmailVerificationsController#show | 3 / 3 | 1969.5 / 1973.5 | 4.0 | 1777.3 | `GEM/rails_vite/lib/rails_vite/config.rb:16` 282.5, `RUBY/find.rb:54` 119.0, `RUBY/find.rb:68` 118.0 | `app/controllers/identity/email_verifications_controller.rb:9` 130.0, `app/controllers/identity/email_verifications_controller.rb:21` 99.5, `app/controllers/identity/email_verifications_controller.rb:23` 58.5 |
| 7 | Settings::PasswordsController#update | 2 / 2 | 1751.0 / 1751.0 | 0.0 | 1856.5 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 312.0, `GEM/rails_vite/lib/rails_vite/config.rb:16` 226.0, `RAILS/activesupport/lib/active_support/inflector/methods.rb:78` 24.0 | `app/controllers/settings/passwords_controller.rb:10` 438.0, `app/controllers/settings/passwords_controller.rb:13` 225.0, `app/models/current.rb:7` 131.0 |
| 8 | UsersController#destroy | 2 / 2 | 1738.0 / 1739.0 | 1.0 | 1434.0 | `GEM/rails_vite/lib/rails_vite/config.rb:16` 226.0, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 24.0, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 24.0 | `app/controllers/users_controller.rb:28` 470.0, `app/models/current.rb:7` 131.0, `app/controllers/users_controller.rb:30` 113.0 |
| 9 | Identity::PasswordResetsController#update | 3 / 3 | 1425.0 / 1424.5 | -0.5 | 1559.7 | `GEM/rails_vite/lib/rails_vite/config.rb:16` 226.0, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 156.0, `RAILS/activesupport/lib/active_support/inflector/methods.rb:80` 28.0 | `app/controllers/identity/password_resets_controller.rb:25` 222.5, `app/controllers/identity/password_resets_controller.rb:28` 166.5, `app/controllers/identity/password_resets_controller.rb:35` 100.0 |
| 10 | SessionsController#create | 3 / 3 | 1351.0 / 1350.5 | -0.5 | 2538.3 | `GEM/rails_vite/lib/rails_vite/config.rb:16` 226.0, `GEM/uri/lib/uri/common.rb:456` 21.5, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 17.0 | `app/controllers/sessions_controller.rb:13` 175.0, `app/controllers/application_controller.rb:24` 108.0, `app/controllers/sessions_controller.rb:12` 103.0 |
| 11 | Identity::PasswordResetsController#edit | 2 / 2 | 991.0 / 984.0 | -7.0 | 2437.5 | `GEM/rails_vite/lib/rails_vite/config.rb:16` 226.0, `RAILS/activesupport/lib/active_support/inflector/methods.rb:80` 28.0, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0 | `app/controllers/identity/password_resets_controller.rb:37` 115.0, `app/controllers/identity/password_resets_controller.rb:35` 11.0, `app/controllers/application_controller.rb:28` 5.0 |
| 12 | Identity::PasswordResetsController#create | 3 / 3 | 962.5 / 962.0 | -0.5 | 1065.3 | `GEM/rails_vite/lib/rails_vite/config.rb:16` 226.0, `RAILS/activesupport/lib/active_support/inflector/methods.rb:80` 28.0, `RAILS/activesupport/lib/active_support/inflector/methods.rb:78` 24.0 | `app/controllers/identity/password_resets_controller.rb:20` 115.0, `app/controllers/identity/password_resets_controller.rb:16` 52.5, `app/controllers/application_controller.rb:28` 5.0 |
| 13 | (no action name) | 18 / 18 | 90.2 / 90.2 | 0.0 | 90.4 | `GEM/rack/lib/rack/utils.rb:693` 17.9, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 8.6, `GEM/rack/lib/rack/request.rb:649` 8.0 |  |
| 14 | Settings::SessionsController#index | 1 / 1 | – / – |  | 4491.0 |  |  |
| 15 | Settings::PasswordsController#show | 1 / 1 | – / – |  | 4256.0 |  |  |
| 16 | Settings::EmailsController#show | 1 / 1 | – / – |  | 4026.0 |  |  |
| 17 | Identity::PasswordResetsController#new | 1 / 1 | – / – |  | 3990.0 |  |  |
| 18 | SessionsController#destroy | 1 / 1 | – / – |  | 2138.0 |  |  |
| 19 | Identity::EmailVerificationsController#create | 1 / 1 | – / – |  | 1350.0 |  |  |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/rails_vite/lib/rails_vite/config.rb:16` † | `manifest_path` | 215.54 / 215.54 | 0.0 | 230.19 | 67% | String, Array |  | `no app frame` 67%, `app/views/layouts/application.html.erb:31` 33% | `@manifest_path \|\| Rails.root.join("public", build_dir, "manifest.json"` |
| 2 | `GEM/json/lib/json/common.rb:302` | `parse` | 76.85 / 76.85 | 0.0 | 86.59 | 48% | String, Hash |  | `app/views/layouts/application.html.erb:31` 96%, `app/controllers/application_controller.rb:24` 2% | `Parser.parse(source, options)` |
| 3 | `RUBY/net/http.rb:1682` | `connect` | 49.46 / 49.46 | 0.0 | 53.76 | 17% | String, Array |  | `no app frame` 77%, `app/controllers/identity/password_resets_controller.rb:12` 11% | `raise e, "Failed to open TCP connection to " +` |
| 4 | `RAILS/activesupport/lib/active_support/error_reporter.rb:280` | `ensure_backtrace` | 47.09 / 47.09 | 0.0 | 51.09 | 17% | String, Array |  | `no app frame` 77%, `app/controllers/settings/sessions_controller.rb:7` 11% | `return unless error.backtrace.nil?` |
| 5 | `GEM/rails_vite/lib/rails_vite/config.rb:8` † | `dev_meta_path` | 43.39 / 43.39 | 0.0 | 49.96 | 19% | String, Array |  | `app/views/layouts/application.html.erb:31` 95%, `no app frame` 5% | `@dev_meta_path \|\| Rails.root.join("tmp", META_FILENAME)` |
| 6 | `GEM/rails_vite/lib/rails_vite/config.rb:66` † | `load_plugin_meta` | 23.22 / 23.22 | 0.0 | 26.74 | 19% | String, Array |  | `app/views/layouts/application.html.erb:31` 95%, `no app frame` 5% | `build_meta_path = manifest_path.dirname.join(META_FILENAME)` |
| 7 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` | `within_new_transaction` | 17.63 / 17.63 | 0.0 | 23.41 | 7% | String, Array |  | `app/controllers/users_controller.rb:14` 26%, `app/controllers/settings/emails_controller.rb:10` 25% | `raise` |
| 8 | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:101` † | `helper_names` | 12.3 / 12.3 | 0.0 | 13.83 | 17% | String, Array |  | `no app frame` 89%, `app/controllers/settings/emails_controller.rb:37` 11% | `@path_helpers.map(&:to_s) + @url_helpers.map(&:to_s)` |
| 9 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | `#{method}` | 11.15 / 11.15 | 0.0 | 11.48 | 67% | Hash, Array |  | `no app frame` 56%, `app/controllers/application_controller.rb:24` 8% | `dispatch(:#{method}, ...)` |
| 10 | `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` | `file_readable?` | 10.89 / 10.89 | 0.0 | 11.39 | 65% | String, Array |  | `no app frame` 100% | `file_path = File.join(@root, path.b)` |
| 11 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:78` | `camelize` | 9.41 / 9.41 | 0.0 | 9.63 | 39% | String, MatchData |  | `no app frame` 100% | `string = string.sub(/^[a-z\d]*/) { \|match\| inflections.acronyms[match]` |
| 12 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:80` | `camelize` | 9.22 / 9.22 | 0.0 | 9.96 | 37% | String, MatchData |  | `no app frame` 100% | `string.gsub!(/(?:_\|(\/))([a-z\d]*)/i) do` |
| 13 | `GEM/uri/lib/uri/common.rb:456` | `_encode_uri_component` | 8.94 / 8.54 | -0.41 | 9.16 | 50% | String, MatchData |  | `no app frame` 100% | `str.gsub!(regexp, table)` |
| 14 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` | `call` | 8.63 / 8.63 | 0.0 | 8.81 | 67% | Data |  | `no app frame` 76%, `app/controllers/settings/emails_controller.rb:10` 5% | `result_lambda = -> { user_callback.call target, value }` |
| 15 | `GEM/rack/lib/rack/utils.rb:693` | `clean_path_info` | 7.91 / 7.91 | 0.0 | 8.0 | 65% | String, MatchData |  | `no app frame` 100% | `parts = path_info.split PATH_SEPS` |
| 16 | `RAILS/actionpack/lib/action_dispatch/http/request.rb:66` | `initialize` | 6.81 / 6.81 | 0.0 | 7.02 | 100% | Object, Data |  | `no app frame` 100% | `@rack_request = Rack::Request.new(env)` |
| 17 | `RUBY/ipaddr.rb:725` | `in_addr` | 6.48 / 6.48 | 0.0 | 6.67 | 67% | String, Array |  | `no app frame` 100% | `octets = addr.split('.')` |
| 18 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` | `build_handle` | 6.13 / 6.13 | 0.0 | 6.37 | 67% | Object, Data | #59613 merged 2026-11-04, after this app's version, not released yet, #59235 merged 2026-10-21, after this app's version, not released yet | `no app frame` 31%, `app/controllers/application_controller.rb:24` 15% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 19 | `GEM/rack/lib/rack/request.rb:693` | `split_header` | 6.13 / 6.13 | 0.0 | 6.19 | 67% | Array, String |  | `no app frame` 37%, `app/controllers/application_controller.rb:29` 32% | `value ? value.strip.split(/[, \t]+/) : []` |
| 20 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:287` | `build_handle` | 5.67 / 5.67 | 0.0 | 5.81 | 67% | Array | #59235 merged 2026-10-21, after this app's version, not released yet | `no app frame` 41%, `app/controllers/application_controller.rb:24` 13% | `groups = groups_for(name).map do \|group_klass, grouped_listeners\|` |
| 21 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:217` | `dispatch` | 5.57 / 5.57 | 0.0 | 5.74 | 67% | Array |  | `no app frame` 56%, `app/controllers/application_controller.rb:24` 8% | `@broadcasts.map { \|logger\|` |
| 22 | `GEM/inertia_rails/lib/inertia_rails/ssr.rb:14` † | `vite_dev_server_url` | 5.48 / 5.48 | 0.0 | 6.17 | 17% | String, Array |  | `no app frame` 78%, `app/controllers/identity/password_resets_controller.rb:12` 11% | `path = Rails.root.join('tmp/rails-vite.json')` |
| 23 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:208` | `dispatch` | 5.22 / 5.22 | 0.0 | 5.44 | 67% | Data |  | `no app frame` 73%, `app/controllers/settings/sessions_controller.rb:7` 3% | `block = proc { \|*args, **kwargs\|` |
| 24 | `GEM/uri/lib/uri/common.rb:465` | `_decode_uri_component` | 5.19 / 5.17 | -0.02 | 5.65 | 57% | String, MatchData |  | `no app frame` 68%, `app/controllers/application_controller.rb:24` 32% | `str.b.gsub(regexp, TBLDECWWWCOMP_).force_encoding(enc)` |
| 25 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` | `each` | 5.11 / 5.11 | 0.0 | 5.54 | 57% | String, Array |  | `app/controllers/application_controller.rb:24` 31%, `app/models/current.rb:7` 30% | `val = step` |
| 26 | `RUBY/random/formatter.rb:174` † | `uuid` | 5.06 / 5.06 | 0.0 | 5.19 | 67% | String, Array |  | `no app frame` 90%, `app/controllers/users_controller.rb:43` 3% | `ary.unpack("H8H4H4H4H12").join(?-)` |
| 27 | `RUBY/net/http.rb:1058` | `HTTP.start` | 5.04 / 5.04 | 0.0 | 5.67 | 17% | String |  | `no app frame` 78%, `app/controllers/settings/sessions_controller.rb:7` 11% | `key = $1.to_sym` |
| 28 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:82` | `camelize` | 4.89 / 4.89 | 0.0 | 5.19 | 37% | Data, String |  | `no app frame` 100% | `substituted = inflections.acronyms[word] \|\| word.capitalize! \|\| word` |
| 29 | `RAILS/activesupport/lib/active_support/current_attributes.rb:236` | `resolve_defaults` | 4.54 / 4.54 | 0.0 | 4.67 | 67% | Array, Hash | #59236 merged 2026-10-21, after this app's version, not released yet | `app/controllers/application_controller.rb:28` 57%, `no app frame` 43% | `defaults.each_with_object({}) do \|(key, value), result\|` |
| 30 | `RUBY/find.rb:54` | `find` | 4.41 / 4.41 | 0.0 | 8.81 | 4% | Data, String |  | `no app frame` 100% | `s = File.lstat(file)` |

## Dev/test-mode work

124.4 of 1390.7 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | debug logging | `RAILS/actionpack/lib/abstract_controller/logger.rb:12` | 15.11 | 67% | `no app frame` 76%, `app/controllers/identity/email_verifications_controller.rb:23` 2% | `singleton_class.delegate :logger, :logger=, to: :config` |
| 2 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:177` | 10.0 | 57% | `app/controllers/application_controller.rb:24` 26%, `app/models/current.rb:7` 14% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 3 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` | 9.09 | 57% | `app/controllers/application_controller.rb:24` 28%, `app/models/current.rb:7` 18% | `binds = binds.inspect` |
| 4 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:175` | 6.74 | 57% | `app/controllers/application_controller.rb:24` 26%, `app/models/current.rb:7` 14% | `modes = MODES.values_at(*options.compact_blank.keys)` |
| 5 | debug logging | `GEM/logger/lib/logger/log_device.rb:33` | 5.5 | 67% | `no app frame` 57%, `app/controllers/application_controller.rb:24` 8% | `handle_write_errors("writing") {@dev.write(message)}` |
| 6 | debug logging | `GEM/logger/lib/logger/log_device.rb:165` | 5.5 | 67% | `no app frame` 57%, `app/controllers/application_controller.rb:24` 8% | `if @filename && (@shift_age > 0) && (@dev.stat.size > @shift_size)` |
| 7 | debug logging | `RAILS/activesupport/lib/active_support/logger.rb:42` | 5.5 | 67% | `no app frame` 57%, `app/controllers/application_controller.rb:24` 8% | `"#{String === msg ? msg : msg.inspect}\n"` |
| 8 | debug logging | `GEM/logger/lib/logger.rb:692` † | 5.28 | 63% | `no app frame` 55%, `app/controllers/application_controller.rb:24` 8% | `format_message(format_severity(severity), Time.now, progname, message)` |
| 9 | debug logging | `GEM/logger/lib/logger.rb:685` | 5.22 | 67% | `no app frame` 73%, `app/controllers/settings/sessions_controller.rb:7` 3% | `message = yield` |
| 10 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:170` | 3.37 | 57% | `app/controllers/application_controller.rb:24` 26%, `app/models/current.rb:7` 14% | `clear = "\e[#{MODES[:clear]}m"` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| gem: rails_vite | 319.2 | 353.9 | `config.rb:16` 215.5, `config.rb:8` 43.4, `config.rb:66` 23.2 |
| rails: activesupport | 280.6 | 331.6 | `error_reporter.rb:280` 47.1, `broadcast_logger.rb:129` 11.1, `log_subscriber.rb:177` 10.0 |
| rails: actionpack | 174.6 | 251.2 | `logger.rb:12` 15.1, `route_set.rb:101` 12.3, `static.rb:145` 10.9 |
| rails: activerecord | 153.7 | 192.7 | `transaction.rb:653` 17.6, `log_subscriber.rb:49` 9.1, `log_subscriber.rb:90` 3.3 |
| ruby stdlib | 106.6 | 144.9 | `http.rb:1682` 49.5, `ipaddr.rb:725` 6.5, `formatter.rb:174` 5.1 |
| gem: json | 78.1 | 87.9 | `common.rb:302` 76.9, `common.rb:860` 1.3 |
| gem: rack | 54.8 | 66.9 | `utils.rb:693` 7.9, `request.rb:693` 6.1, `request.rb:649` 2.8 |
| rails: actionview | 42.3 | 71.5 | `tag_helper.rb:309` 2.2, `log_subscriber.rb:61` 2.1, `structured_event_subscriber.rb:61` 1.9 |
| ruby default gem: uri | 34.6 | 36.7 | `common.rb:456` 8.7, `common.rb:465` 5.2, `rfc3986_parser.rb:85` 2.3 |
| gem: inertia_rails | 26.6 | 30.5 | `ssr.rb:14` 5.5, `renderer.rb:138` 1.7, `configuration.rb:142` 0.8 |
| gem: logger | 21.5 | 22.2 | `log_device.rb:33` 5.5, `log_device.rb:165` 5.5, `logger.rb:692` 5.3 |
| rails: activemodel | 19.8 | 48.8 | `attribute.rb:9` 3.3, `builder.rb:37` 1.6, `string.rb:39` 1.5 |
| gem: sqlite3 | 14.6 | 15.9 | `statement.rb:125` 5.1, `statement.rb:54` 3.7, `statement.rb:186` 1.6 |
| gem: concurrent-ruby | 12.1 | 12.9 | `safe_initialization.rb:30` 3.9, `mutex_lockable_object.rb:33` 1.3, `mutex_lockable_object.rb:32` 1.3 |
| gem: i18n | 10.3 | 17.7 | `i18n.rb:476` 2.9, `base.rb:157` 1.3, `i18n.rb:396` 1.1 |
| rails: railties | 6.1 | 7.0 | `logger.rb:57` 1.3, `engine.rb:748` 1.0, `logger.rb:42` 0.6 |
| gem: bcrypt | 6.1 | 6.6 | `password.rb:102` 1.9, `password.rb:103` 0.9, `engine.rb:70` 0.8 |
| gem: useragent | 5.6 | 22.1 | `version.rb:27` 1.3, `user_agent.rb:25` 0.6, `user_agent.rb:24` 0.5 |
| gem: bootsnap | 3.8 | 22.2 | `iseq.rb:98` 1.9, `cache.rb:218` 0.5, `iseq.rb:154` 0.5 |
| gem: tzinfo | 3.4 | 4.0 | `timestamp.rb:208` 1.6, `constant_offset_data_timezone_info.rb:52` 0.8, `timestamp.rb:193` 0.8 |
| gem: propshaft | 2.9 | 3.1 | `server.rb:16` 1.0, `server.rb:13` 0.6, `server.rb:14` 0.6 |
| app | 2.9 | 7.3 | `application.html.erb:31` 0.6, `user.rb:20` 0.5, `inertia_controller.rb:7` 0.3 |
| gem: base64 | 2.7 | 2.9 | `base64.rb:283` 2.0, `base64.rb:310` 0.7 |
| rails: activejob | 2.6 | 3.7 | `log_subscriber.rb:207` 0.6, `arguments.rb:141` 0.3, `configured_job.rb:15` 0.2 |
| gem: globalid | 2.1 | 2.8 | `gid.rb:95` 0.6, `gid.rb:159` 0.4, `gid.rb:166` 0.2 |
| gem: rack-session | 1.9 | 2.0 | `id.rb:277` 0.6, `id.rb:275` 0.6, `id.rb:401` 0.5 |
| gem: zeitwerk | 1.5 | 2.3 | `cref.rb:47` 0.3, `file_system.rb:203` 0.2, `constant_path_validator.rb:13` 0.2 |
| ruby default gem: securerandom | 1.2 | 1.2 | `securerandom.rb:71` 1.2 |
| gem: capybara-lockstep | 0.7 | 0.8 | `helper.rb:13` 0.1, `helper.rb:12` 0.1, `helper.rb:26` 0.1 |
| rails: actionmailer | 0.4 | 0.6 | `parameterized.rb:149` 0.1, `parameterized.rb:107` 0.1, `message_delivery.rb:104` 0.1 |
| gem: solid_queue | 0.1 | 0.2 | `batch_id.rb:20` 0.1 |
| gem: rails-html-sanitizer | 0.0 | 0.0 | `sanitizer.rb:157` 0.0, `scrubbers.rb:55` 0.0 |
| rails: actioncable | 0.0 | 0.2 | `engine.rb:21` 0.0, `action_cable_helper.rb:7` 0.0, `action_cable_helper.rb:0` 0.0 |
| gem: msgpack | 0.0 | 0.3 | `factory.rb:9` 0.0, `factory.rb:41` 0.0, `factory.rb:14` 0.0 |
| rails: activestorage | 0.0 | 0.0 | `engine.rb:215` 0.0 |
| gem: erubi | 0.0 | 2.0 | `erubi.rb:196` 0.0, `erubi.rb:137` 0.0, `erubi.rb:151` 0.0 |
| gem: jbuilder | 0.0 | 0.7 | `jbuilder_dependency_tracker.rb:0` 0.0, `jbuilder_dependency_tracker.rb:28` 0.0, `railtie.rb:10` 0.0 |
| ruby default gem: bundler | 0.0 | 0.0 | `rubygems_integration.rb:192` 0.0 |
| rails: actiontext | 0.0 | 1.6 | `content.rb:24` 0.0, `rendering.rb:9` 0.0, `engine.rb:92` 0.0 |
| lowrail-profile | 0.0 | 0.0 | `profile.rb:66` 0.0, `profile.rb:56` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Mails

| # | Mailer action | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | UserMailer#email_verification | 2 / 2 | 700.0 / 700.0 | 0.0 | 1074.5 | `GEM/mail/lib/mail/utilities.rb:215` 36.0, `GEM/mail/lib/mail/parsers/address_lists_parser.rb:32009` 31.0, `GEM/mail/lib/mail/parser_tools.rb:7` 25.0 | `app/mailers/user_mailer.rb:15` 469.0, `app/mailers/user_mailer.rb:13` 55.0, `app/views/user_mailer/email_verification.html.erb:7` 39.0 |
| 2 | UserMailer#password_reset | 2 / 2 | 695.0 / 695.0 | 0.0 | 756.0 | `GEM/mail/lib/mail/utilities.rb:215` 36.0, `GEM/mail/lib/mail/parsers/address_lists_parser.rb:32009` 31.0, `GEM/mail/lib/mail/parser_tools.rb:7` 25.0 | `app/mailers/user_mailer.rb:8` 470.0, `app/views/user_mailer/password_reset.html.erb:5` 38.0, `app/mailers/user_mailer.rb:6` 36.0 |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/mail/lib/mail/utilities.rb:215` | 27.0 / 27.0 | 100% | `app/mailers/user_mailer.rb:15` 50%, `app/mailers/user_mailer.rb:8` 50% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 2 | `GEM/mail/lib/mail/parsers/address_lists_parser.rb:32009` | 23.25 / 23.25 | 100% | `app/mailers/user_mailer.rb:15` 50%, `app/mailers/user_mailer.rb:8` 50% | `_wide = data[p].ord` |
| 3 | `GEM/mail/lib/mail/parser_tools.rb:7` | 18.75 / 18.75 | 100% | `app/mailers/user_mailer.rb:15` 50%, `app/mailers/user_mailer.rb:8` 50% | `data.slice(from_bytes..to_bytes).force_encoding(Encoding::UTF_8)` |
| 4 | `GEM/mail/lib/mail/utilities.rb:291` | 17.25 / 17.25 | 100% | `app/mailers/user_mailer.rb:15` 50%, `app/mailers/user_mailer.rb:8` 50% | `value !~ /\S/` |
| 5 | `GEM/mail/lib/mail/parsers/content_type_parser.rb:734` | 13.5 / 13.5 | 100% | `app/mailers/user_mailer.rb:15` 50%, `app/mailers/user_mailer.rb:8` 50% | `_wide = data[p].ord` |
| 6 | `RAILS/actionview/lib/action_view/log_subscriber.rb:61` (debug logging) | 13.5 / 13.5 | 100% | `app/mailers/user_mailer.rb:8` 50%, `app/mailers/user_mailer.rb:15` 50% | `string = string.sub(rails_root, "")` |
| 7 | `GEM/mail/lib/mail/field_list.rb:71` | 11.25 / 11.25 | 100% | `app/mailers/user_mailer.rb:8` 50%, `app/mailers/user_mailer.rb:15` 50% | `fields = select { \|f\| f.responsible_for? field_name }` |
| 8 | `RAILS/actionview/lib/action_view/structured_event_subscriber.rb:61` † (debug logging) | 11.25 / 11.25 | 100% | `app/mailers/user_mailer.rb:15` 50%, `app/mailers/user_mailer.rb:8` 50% | `string = string.sub("#{rails_root}/", "")` |
| 9 | `GEM/mail/lib/mail/field.rb:176` | 9.0 / 9.0 | 100% | `app/mailers/user_mailer.rb:8` 50%, `app/mailers/user_mailer.rb:15` 50% | `class_name = FIELDS_MAP[name.to_s.downcase]` |
| 10 | `GEM/logger/lib/logger.rb:685` (debug logging) | 7.5 / 7.5 | 100% | `app/mailers/user_mailer.rb:8` 40%, `app/mailers/user_mailer.rb:15` 40% | `message = yield` |
