# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bundle exec rspec --seed 1234 --format documentation --exclude-pattern spec/system/**/*_spec.rb`
* Ruby: ruby 4.0.1 (2026-01-13 revision e04267a14b) +PRISM [x86_64-linux]
* Rails: 8.1.4, test environment
* Counted in run 1: 33 requests, 4 mail windows; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 33 | 2945.7 | 0 | 4 | 0 | 0 |
| run2 | 1 | 33 | 2946.0 | 0 | 4 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.12 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/views/layouts/application.html.erb:31` |  | 49.58 | 0.0 | 0.12 | `GEM/json/lib/json/common.rb:302` 32%, `GEM/rails_vite/lib/rails_vite/config.rb:16` 28%, `GEM/rails_vite/lib/rails_vite/config.rb:8` 17% | UsersController#new 100%, SessionsController#new 0%, Settings::SessionsController#index 0% | `<%= vite_tags "application.css", "inertia.tsx" %>` |
| 2 | `app/controllers/application_controller.rb:24` | `perform_authentication` | 27.27 | 8.24 | 0.0 | `GEM/uri/lib/uri/common.rb:465` 3%, `GEM/rack/lib/rack/utils.rb:331` 3%, `RAILS/actionpack/lib/action_dispatch/middleware/cookies.rb:628` 3% | DashboardController#index 15%, SessionsController#new 12%, UsersController#destroy 12% | `Current.session \|\|= Session.find_by_id(cookies.signed[:session_token])` |
| 3 | `app/controllers/users_controller.rb:21` | `create` | 18.33 | 0.42 | 0.09 | `GEM/i18n/lib/i18n.rb:476` 18%, `GEM/i18n/lib/i18n/backend/base.rb:157` 7%, `GEM/i18n/lib/i18n.rb:396` 5% | UsersController#create 100% | `redirect_to sign_up_path, inertia: { errors: @user.errors }` |
| 4 | `app/controllers/users_controller.rb:14` | `create` | 16.42 | 2.73 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 60%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 2%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 1% | UsersController#create 100% | `if @user.save` |
| 5 | `app/controllers/users_controller.rb:28` | `destroy` | 14.24 | 4.55 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 3%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 3%, `GEM/sqlite3/lib/sqlite3/statement.rb:186` 3% | UsersController#destroy 100% | `user.destroy!` |
| 6 | `app/controllers/identity/password_resets_controller.rb:25` | `update` | 13.42 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 70%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 2%, `RAILS/activesupport/lib/active_support/inflector/methods.rb:146` 1% | Identity::PasswordResetsController#update 100% | `if @user.update(user_params)` |
| 7 | `app/controllers/settings/passwords_controller.rb:10` | `update` | 13.21 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 71%, `GEM/bcrypt/lib/bcrypt/password.rb:102` 3%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 3% | Settings::PasswordsController#update 100% | `if @user.update(user_params)` |
| 8 | `app/controllers/settings/emails_controller.rb:10` | `update` | 13.12 | 4.12 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 3%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 3%, `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 3% | Settings::EmailsController#update 100% | `if @user.update(user_params)` |
| 9 | `app/models/current.rb:7` |  | 11.91 | 3.27 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 5%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 3% | Settings::EmailsController#update 33%, Settings::PasswordsController#update 33%, UsersController#destroy 33% | `delegate :user, to: :session, allow_nil: true` |
| 10 | `app/controllers/identity/password_resets_controller.rb:28` | `update` | 10.09 | 0.42 | 0.12 | `GEM/i18n/lib/i18n.rb:476` 13%, `GEM/i18n/lib/i18n/backend/base.rb:157` 4%, `GEM/i18n/lib/i18n.rb:396` 3% | Identity::PasswordResetsController#update 100% | `redirect_to edit_identity_password_reset_path(sid: params[:sid]), iner` |
| 11 | `app/controllers/settings/emails_controller.rb:37` | `resend_email_verification` | 9.36 | 0.73 | 0.03 | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:101` 27%, `GEM/uri/lib/uri/common.rb:90` 3%, `GEM/globalid/lib/global_id/uri/gid.rb:95` 3% | Settings::EmailsController#update 100% | `UserMailer.with(user: @user).email_verification.deliver_later` |
| 12 | `app/controllers/identity/email_verifications_controller.rb:9` | `show` | 7.88 | 2.85 | 0.03 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 5%, `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 5%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 4% | Identity::EmailVerificationsController#show 100% | `@user.update! verified: true` |
| 13 | `app/controllers/identity/password_resets_controller.rb:37` | `set_user` | 7.03 | 0.82 | 0.12 | `RAILS/activesupport/lib/active_support/key_generator.rb:63` 4%, `GEM/rack/lib/rack/request.rb:693` 3%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:55` 3% | Identity::PasswordResetsController#update 50%, Identity::PasswordResetsController#edit 50% | `redirect_to new_identity_password_reset_path, alert: "That password re` |
| 14 | `app/controllers/identity/password_resets_controller.rb:20` | `create` | 6.97 | 0.85 | 0.12 | `RAILS/activesupport/lib/active_support/key_generator.rb:63` 4%, `GEM/uri/lib/uri/common.rb:108` 3%, `GEM/rack/lib/rack/request.rb:693` 3% | Identity::PasswordResetsController#create 100% | `redirect_to new_identity_password_reset_path, alert: "You can't reset ` |
| 15 | `app/controllers/settings/passwords_controller.rb:13` | `update` | 6.82 | 0.42 | 0.09 | `GEM/i18n/lib/i18n/backend/base.rb:157` 6%, `GEM/i18n/lib/i18n.rb:396` 5%, `GEM/i18n/lib/i18n/backend/simple.rb:100` 4% | Settings::PasswordsController#update 100% | `redirect_to settings_password_path, inertia: { errors: @user.errors }` |
| 16 | `app/controllers/identity/password_resets_controller.rb:35` | `set_user` | 6.39 | 1.09 | 0.0 | `GEM/json/lib/json/common.rb:302` 7%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 3%, `RUBY/time.rb:642` 3% | Identity::PasswordResetsController#update 95%, Identity::PasswordResetsController#edit 5% | `@user = User.find_by_token_for!(:password_reset, params[:sid])` |
| 17 | `app/controllers/identity/email_verifications_controller.rb:21` | `set_user` | 6.03 | 1.09 | 0.0 | `GEM/json/lib/json/common.rb:302` 7%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 4%, `RUBY/time.rb:642` 3% | Identity::EmailVerificationsController#show 100% | `@user = User.find_by_token_for!(:email_verification, params[:sid])` |
| 18 | `app/controllers/identity/email_verifications_controller.rb:23` | `set_user` | 3.55 | 0.39 | 0.06 | `RAILS/activesupport/lib/active_support/key_generator.rb:63` 4%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:55` 3%, `GEM/rack/lib/rack/request.rb:693` 3% | Identity::EmailVerificationsController#show 100% | `redirect_to settings_email_path, alert: "That email verification link ` |
| 19 | `app/controllers/identity/email_verifications_controller.rb:10` | `show` | 3.45 | 0.42 | 0.06 | `RAILS/activesupport/lib/active_support/key_generator.rb:63` 4%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:55` 4%, `GEM/uri/lib/uri/common.rb:108` 4% | Identity::EmailVerificationsController#show 100% | `redirect_to root_path, notice: "Thank you for verifying your email add` |
| 20 | `app/controllers/users_controller.rb:30` | `destroy` | 3.42 | 0.42 | 0.09 | `RAILS/activesupport/lib/active_support/key_generator.rb:63` 4%, `GEM/uri/lib/uri/rfc3986_parser.rb:85` 4%, `GEM/rack/lib/rack/request.rb:693` 4% | UsersController#destroy 100% | `redirect_to root_path, notice: "Your account has been deleted", inerti` |
| 21 | `app/controllers/settings/emails_controller.rb:30` | `redirect_to_success` | 3.24 | 0.42 | 0.06 | `RAILS/activesupport/lib/active_support/key_generator.rb:63` 5%, `GEM/uri/lib/uri/common.rb:108` 4%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:55` 4% | Settings::EmailsController#update 100% | `redirect_to settings_email_path, notice: "Your email has been changed"` |
| 22 | `app/controllers/sessions_controller.rb:18` | `create` | 3.24 | 0.42 | 0.06 | `RAILS/activesupport/lib/active_support/key_generator.rb:63` 5%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:55` 4%, `GEM/rack/lib/rack/request.rb:693` 4% | SessionsController#create 100% | `redirect_to sign_in_path, alert: "That email or password is incorrect"` |
| 23 | `app/controllers/identity/password_resets_controller.rb:16` | `create` | 3.18 | 2.42 | 0.12 | `RAILS/activerecord/lib/active_record/core.rb:288` 6%, `GEM/sqlite3/lib/sqlite3/statement.rb:54` 6%, `RAILS/activerecord/lib/active_record/core.rb:326` 4% | Identity::PasswordResetsController#create 100% | `if @user = User.find_by(email: params[:email], verified: true)` |
| 24 | `app/controllers/sessions_controller.rb:12` | `create` | 3.12 | 1.09 | 0.03 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` 7%, `GEM/bcrypt/lib/bcrypt/password.rb:102` 6%, `RAILS/activerecord/lib/active_record/secure_password.rb:42` 5% | SessionsController#create 100% | `if user = User.authenticate_by(email: params[:email], password: params` |
| 25 | `app/controllers/application_controller.rb:28` | `set_current_request_details` | 2.27 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/current_attributes.rb:236` 80%, `RAILS/activesupport/lib/active_support/current_attributes.rb:104` 20% | Identity::PasswordResetsController#create 13%, Identity::PasswordResetsController#update 13%, Identity::EmailVerificationsController#show 13% | `Current.user_agent = request.user_agent` |
| 26 | `app/controllers/application_controller.rb:13` | `authenticate` | 1.94 | 0.42 | 0.03 | `GEM/rack/lib/rack/request.rb:693` 6%, `GEM/uri/lib/uri/rfc3986_parser.rb:85` 6%, `GEM/uri/lib/uri/common.rb:108` 6% | DashboardController#index 100% | `redirect_to sign_in_path unless perform_authentication` |
| 27 | `app/controllers/application_controller.rb:20` | `require_no_authentication` | 1.91 | 0.42 | 0.03 | `GEM/uri/lib/uri/rfc3986_parser.rb:85` 6%, `GEM/rack/lib/rack/request.rb:693` 6%, `GEM/uri/lib/uri/common.rb:108` 6% | SessionsController#new 100%, UsersController#new 0% | `redirect_to root_path` |
| 28 | `app/controllers/users_controller.rb:12` | `create` | 1.45 | 0.0 | 0.0 | `GEM/bcrypt/lib/bcrypt/password.rb:102` 13%, `RAILS/activemodel/lib/active_model/attribute.rb:101` 10%, `GEM/bcrypt/lib/bcrypt/engine.rb:90` 10% | UsersController#create 100% | `@user = User.new(user_params)` |
| 29 | `app/controllers/application_controller.rb:29` | `set_current_request_details` | 1.36 | 0.0 | 0.0 | `GEM/rack/lib/rack/request.rb:693` 100% | Identity::PasswordResetsController#create 13%, Identity::PasswordResetsController#update 13%, Identity::EmailVerificationsController#show 13% | `Current.ip_address = request.ip` |
| 30 | `app/controllers/application_controller.rb:19` | `require_no_authentication` | 1.33 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/key_generator.rb:63` 11%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:55` 9%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:10` 7% | SessionsController#new 100%, UsersController#new 0% | `flash[:notice] = "You are already signed in"` |

366.21 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | UsersController#new | 2 / 2 | 3421.0 / 3421.0 | 0.0 | 2347.5 | `GEM/rails_vite/lib/rails_vite/config.rb:16` 678.0, `GEM/json/lib/json/common.rb:302` 520.0, `RUBY/net/http.rb:1682` 319.0 | `app/views/layouts/application.html.erb:31` 1636.0, `app/controllers/application_controller.rb:24` 108.0, `app/views/layouts/application.html.erb:9` 18.0 |
| 2 | UsersController#create | 2 / 2 | 2164.0 / 2163.0 | -1.0 | 2224.5 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 326.0, `GEM/rails_vite/lib/rails_vite/config.rb:16` 226.0, `GEM/i18n/lib/i18n.rb:476` 111.0 | `app/controllers/users_controller.rb:21` 605.0, `app/controllers/users_controller.rb:14` 542.0, `app/controllers/application_controller.rb:24` 108.0 |
| 3 | Settings::EmailsController#update | 2 / 2 | 2106.0 / 2110.0 | 4.0 | 2301.0 | `GEM/rails_vite/lib/rails_vite/config.rb:16` 226.0, `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:101` 83.0, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 26.0 | `app/controllers/settings/emails_controller.rb:10` 433.0, `app/controllers/settings/emails_controller.rb:37` 309.0, `app/models/current.rb:7` 131.0 |
| 4 | Identity::EmailVerificationsController#show | 3 / 3 | 1973.0 / 1971.0 | -2.0 | 1776.3 | `GEM/rails_vite/lib/rails_vite/config.rb:16` 282.5, `RUBY/find.rb:54` 119.0, `RUBY/find.rb:68` 118.0 | `app/controllers/identity/email_verifications_controller.rb:9` 130.0, `app/controllers/identity/email_verifications_controller.rb:21` 99.5, `app/controllers/identity/email_verifications_controller.rb:23` 58.5 |
| 5 | Settings::PasswordsController#update | 2 / 2 | 1748.0 / 1745.0 | -3.0 | 1857.5 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 310.0, `GEM/rails_vite/lib/rails_vite/config.rb:16` 226.0, `RAILS/activesupport/lib/active_support/inflector/methods.rb:78` 24.0 | `app/controllers/settings/passwords_controller.rb:10` 436.0, `app/controllers/settings/passwords_controller.rb:13` 225.0, `app/models/current.rb:7` 131.0 |
| 6 | UsersController#destroy | 2 / 2 | 1734.0 / 1741.0 | 7.0 | 1435.0 | `GEM/rails_vite/lib/rails_vite/config.rb:16` 226.0, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 24.0, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 24.0 | `app/controllers/users_controller.rb:28` 470.0, `app/models/current.rb:7` 131.0, `app/controllers/users_controller.rb:30` 113.0 |
| 7 | Identity::PasswordResetsController#update | 3 / 3 | 1425.0 / 1423.0 | -2.0 | 1560.0 | `GEM/rails_vite/lib/rails_vite/config.rb:16` 226.0, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 155.0, `RAILS/activesupport/lib/active_support/inflector/methods.rb:80` 28.0 | `app/controllers/identity/password_resets_controller.rb:25` 221.5, `app/controllers/identity/password_resets_controller.rb:28` 166.5, `app/controllers/identity/password_resets_controller.rb:35` 100.0 |
| 8 | SessionsController#create | 2 / 2 | 1077.0 / 1079.0 | 2.0 | 1405.5 | `GEM/rails_vite/lib/rails_vite/config.rb:16` 226.0, `GEM/uri/lib/uri/common.rb:456` 18.0, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 14.0 | `app/controllers/application_controller.rb:24` 108.0, `app/controllers/sessions_controller.rb:18` 107.0, `app/controllers/sessions_controller.rb:12` 103.0 |
| 9 | Identity::PasswordResetsController#edit | 2 / 2 | 989.0 / 985.0 | -4.0 | 2277.0 | `GEM/rails_vite/lib/rails_vite/config.rb:16` 226.0, `RAILS/activesupport/lib/active_support/inflector/methods.rb:80` 28.0, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0 | `app/controllers/identity/password_resets_controller.rb:37` 115.0, `app/controllers/identity/password_resets_controller.rb:35` 11.0, `app/controllers/application_controller.rb:28` 5.0 |
| 10 | SessionsController#new | 2 / 2 | 982.0 / 980.0 | -2.0 | 3237.0 | `GEM/rails_vite/lib/rails_vite/config.rb:16` 226.0, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 12.0 | `app/controllers/application_controller.rb:24` 111.0, `app/controllers/application_controller.rb:20` 63.0, `app/controllers/application_controller.rb:19` 44.0 |
| 11 | Identity::PasswordResetsController#create | 3 / 3 | 963.0 / 964.0 | 1.0 | 1067.7 | `GEM/rails_vite/lib/rails_vite/config.rb:16` 226.0, `RAILS/activesupport/lib/active_support/inflector/methods.rb:80` 28.0, `RAILS/activesupport/lib/active_support/inflector/methods.rb:78` 24.0 | `app/controllers/identity/password_resets_controller.rb:20` 115.0, `app/controllers/identity/password_resets_controller.rb:16` 52.5, `app/controllers/application_controller.rb:28` 5.0 |
| 12 | DashboardController#index | 2 / 2 | 875.0 / 877.0 | 2.0 | 2446.5 | `GEM/rails_vite/lib/rails_vite/config.rb:16` 226.0, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0, `GEM/uri/lib/uri/common.rb:465` 19.0 | `app/controllers/application_controller.rb:24` 132.0, `app/controllers/application_controller.rb:13` 64.0, `app/controllers/application_controller.rb:28` 5.0 |
| 13 | SessionsController#destroy | 1 / 1 | – / – |  | 11162.0 |  |  |
| 14 | Settings::SessionsController#index | 1 / 1 | – / – |  | 4198.0 |  |  |
| 15 | Settings::PasswordsController#show | 1 / 1 | – / – |  | 3967.0 |  |  |
| 16 | Settings::EmailsController#show | 1 / 1 | – / – |  | 3737.0 |  |  |
| 17 | Identity::PasswordResetsController#new | 1 / 1 | – / – |  | 3630.0 |  |  |
| 18 | Identity::EmailVerificationsController#create | 1 / 1 | – / – |  | 1354.0 |  |  |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/rails_vite/lib/rails_vite/config.rb:16` † | `manifest_path` | 332.15 / 332.15 | 0.0 | 342.42 | 100% | String, Array |  | `no app frame` 68%, `app/views/layouts/application.html.erb:31` 32% | `@manifest_path \|\| Rails.root.join("public", build_dir, "manifest.json"` |
| 2 | `GEM/json/lib/json/common.rb:302` | `parse` | 123.27 / 123.27 | 0.0 | 125.21 | 70% | String, Hash |  | `app/views/layouts/application.html.erb:31` 96%, `app/controllers/application_controller.rb:24` 2% | `Parser.parse(source, options)` |
| 3 | `GEM/rails_vite/lib/rails_vite/config.rb:8` † | `dev_meta_path` | 71.0 / 71.0 | 0.0 | 73.15 | 30% | String, Array |  | `app/views/layouts/application.html.erb:31` 94%, `no app frame` 6% | `@dev_meta_path \|\| Rails.root.join("tmp", META_FILENAME)` |
| 4 | `RUBY/net/http.rb:1682` | `connect` | 67.88 / 67.88 | 0.0 | 77.55 | 24% | String, Object |  | `no app frame` 75%, `app/controllers/settings/sessions_controller.rb:7` 12% | `raise e, "Failed to open TCP connection to " +` |
| 5 | `GEM/rails_vite/lib/rails_vite/config.rb:66` † | `load_plugin_meta` | 38.0 / 38.0 | 0.0 | 39.15 | 30% | String, Array |  | `app/views/layouts/application.html.erb:31` 94%, `no app frame` 6% | `build_meta_path = manifest_path.dirname.join(META_FILENAME)` |
| 6 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` | `within_new_transaction` | 28.67 / 28.67 | 0.0 | 38.06 | 12% | String, Array |  | `app/controllers/users_controller.rb:14` 26%, `app/controllers/settings/passwords_controller.rb:10` 25% | `raise` |
| 7 | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:101` † | `helper_names` | 20.12 / 20.12 | 0.0 | 22.64 | 27% | String, Array |  | `no app frame` 89%, `app/controllers/settings/emails_controller.rb:37` 11% | `@path_helpers.map(&:to_s) + @url_helpers.map(&:to_s)` |
| 8 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | `#{method}` | 16.67 / 16.67 | 0.0 | 17.33 | 100% | Hash, Array |  | `no app frame` 55%, `app/controllers/application_controller.rb:24` 7% | `dispatch(:#{method}, ...)` |
| 9 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:80` | `camelize` | 15.09 / 15.09 | 0.0 | 16.3 | 61% | String, MatchData |  | `no app frame` 100% | `string.gsub!(/(?:_\|(\/))([a-z\d]*)/i) do` |
| 10 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:78` | `camelize` | 14.18 / 14.18 | 0.0 | 15.64 | 61% | String, Data |  | `no app frame` 100% | `string = string.sub(/^[a-z\d]*/) { \|match\| inflections.acronyms[match]` |
| 11 | `GEM/uri/lib/uri/common.rb:456` | `_encode_uri_component` | 13.21 / 13.12 | -0.09 | 13.73 | 76% | String, MatchData |  | `no app frame` 100% | `str.gsub!(regexp, table)` |
| 12 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` | `call` | 13.06 / 13.06 | 0.0 | 13.39 | 100% | Data |  | `no app frame` 75%, `app/controllers/settings/emails_controller.rb:10` 5% | `result_lambda = -> { user_callback.call target, value }` |
| 13 | `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` | `file_readable?` | 11.45 / 11.45 | 0.0 | 12.27 | 46% | String, Array |  | `no app frame` 100% | `file_path = File.join(@root, path.b)` |
| 14 | `RAILS/actionpack/lib/action_dispatch/http/request.rb:66` | `initialize` | 9.7 / 9.7 | 0.0 | 10.0 | 100% | Object |  | `no app frame` 100% | `@rack_request = Rack::Request.new(env)` |
| 15 | `RUBY/ipaddr.rb:725` | `in_addr` | 9.7 / 9.7 | 0.0 | 10.0 | 100% | String, Array |  | `no app frame` 100% | `octets = addr.split('.')` |
| 16 | `GEM/rack/lib/rack/request.rb:693` | `split_header` | 8.97 / 8.97 | 0.0 | 9.3 | 100% | Array, String |  | `no app frame` 35%, `app/controllers/application_controller.rb:29` 32% | `value ? value.strip.split(/[, \t]+/) : []` |
| 17 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` | `build_handle` | 8.88 / 8.88 | 0.0 | 9.36 | 100% | Object, Data | #59613 merged 2026-11-04, after this app's version, not released yet, #59235 merged 2026-10-21, after this app's version, not released yet | `no app frame` 32%, `app/controllers/application_controller.rb:24` 14% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 18 | `GEM/uri/lib/uri/common.rb:465` | `_decode_uri_component` | 8.33 / 8.45 | 0.12 | 8.48 | 91% | String, MatchData |  | `no app frame` 73%, `app/controllers/application_controller.rb:24` 27% | `str.b.gsub(regexp, TBLDECWWWCOMP_).force_encoding(enc)` |
| 19 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:217` | `dispatch` | 8.33 / 8.33 | 0.0 | 8.67 | 100% | Array |  | `no app frame` 55%, `app/controllers/application_controller.rb:24` 7% | `@broadcasts.map { \|logger\|` |
| 20 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:287` | `build_handle` | 8.24 / 8.24 | 0.0 | 8.67 | 100% | Array | #59235 merged 2026-10-21, after this app's version, not released yet | `no app frame` 41%, `app/controllers/application_controller.rb:24` 12% | `groups = groups_for(name).map do \|group_klass, grouped_listeners\|` |
| 21 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:208` | `dispatch` | 8.06 / 8.06 | 0.0 | 8.24 | 100% | Data |  | `no app frame` 71%, `app/controllers/settings/sessions_controller.rb:7` 3% | `block = proc { \|*args, **kwargs\|` |
| 22 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:82` | `camelize` | 8.0 / 8.0 | 0.0 | 8.48 | 61% | Data, String |  | `no app frame` 100% | `substituted = inflections.acronyms[word] \|\| word.capitalize! \|\| word` |
| 23 | `GEM/inertia_rails/lib/inertia_rails/ssr.rb:14` † | `vite_dev_server_url` | 7.85 / 7.85 | 0.0 | 8.97 | 24% | String, Array |  | `no app frame` 75%, `app/controllers/settings/sessions_controller.rb:7` 13% | `path = Rails.root.join('tmp/rails-vite.json')` |
| 24 | `RUBY/random/formatter.rb:174` † | `uuid` | 7.64 / 7.64 | 0.0 | 7.85 | 100% | String, Array |  | `no app frame` 89%, `app/controllers/users_controller.rb:43` 3% | `ary.unpack("H8H4H4H4H12").join(?-)` |
| 25 | `RUBY/find.rb:54` | `find` | 7.21 / 7.21 | 0.0 | 14.42 | 6% | String, Data |  | `no app frame` 100% | `s = File.lstat(file)` |
| 26 | `RUBY/net/http.rb:1058` | `HTTP.start` | 7.21 / 7.21 | 0.0 | 8.24 | 24% | String |  | `no app frame` 75%, `app/controllers/settings/sessions_controller.rb:7` 13% | `key = $1.to_sym` |
| 27 | `RUBY/find.rb:68` | `find` | 7.15 / 7.15 | 0.0 | 14.3 | 6% | String, Array |  | `no app frame` 100% | `f = File.join(file, f)` |
| 28 | `RAILS/activesupport/lib/active_support/current_attributes.rb:236` | `resolve_defaults` | 6.79 / 6.79 | 0.0 | 7.0 | 100% | Array, Hash | #59236 merged 2026-10-21, after this app's version, not released yet | `app/controllers/application_controller.rb:28` 57%, `no app frame` 43% | `defaults.each_with_object({}) do \|(key, value), result\|` |
| 29 | `RUBY/find.rb:61` † | `find` | 6.73 / 6.73 | 0.0 | 13.45 | 6% | String, Array |  | `no app frame` 100% | `fs = Dir.children(file, encoding: enc)` |
| 30 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` | `each` | 6.55 / 6.55 | 0.0 | 7.0 | 85% | String, Array |  | `app/models/current.rb:7` 36%, `app/controllers/application_controller.rb:24` 28% | `val = step` |

## Dev/test-mode work

181.4 of 1958.0 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | debug logging | `RAILS/actionpack/lib/abstract_controller/logger.rb:12` | 22.82 | 100% | `no app frame` 76%, `app/controllers/identity/password_resets_controller.rb:41` 2% | `singleton_class.delegate :logger, :logger=, to: :config` |
| 2 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:177` | 14.0 | 85% | `app/controllers/application_controller.rb:24` 25%, `app/models/current.rb:7` 14% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 3 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` | 12.79 | 85% | `app/controllers/application_controller.rb:24` 28%, `app/models/current.rb:7` 19% | `binds = binds.inspect` |
| 4 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:175` | 9.45 | 85% | `app/controllers/application_controller.rb:24` 25%, `app/models/current.rb:7` 14% | `modes = MODES.values_at(*options.compact_blank.keys)` |
| 5 | debug logging | `GEM/logger/lib/logger/log_device.rb:33` | 8.21 | 100% | `no app frame` 57%, `app/controllers/application_controller.rb:24` 7% | `handle_write_errors("writing") {@dev.write(message)}` |
| 6 | debug logging | `GEM/logger/lib/logger/log_device.rb:165` | 8.21 | 100% | `no app frame` 57%, `app/controllers/application_controller.rb:24` 7% | `if @filename && (@shift_age > 0) && (@dev.stat.size > @shift_size)` |
| 7 | debug logging | `RAILS/activesupport/lib/active_support/logger.rb:42` | 8.21 | 100% | `no app frame` 56%, `app/controllers/application_controller.rb:24` 7% | `"#{String === msg ? msg : msg.inspect}\n"` |
| 8 | debug logging | `GEM/logger/lib/logger.rb:685` | 8.06 | 100% | `no app frame` 71%, `app/controllers/settings/sessions_controller.rb:7` 3% | `message = yield` |
| 9 | debug logging | `GEM/logger/lib/logger.rb:692` † | 7.85 | 94% | `no app frame` 55%, `app/controllers/application_controller.rb:24` 8% | `format_message(format_severity(severity), Time.now, progname, message)` |
| 10 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:170` | 4.73 | 85% | `app/controllers/application_controller.rb:24` 25%, `app/models/current.rb:7` 14% | `clear = "\e[#{MODES[:clear]}m"` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| gem: rails_vite | 497.4 | 525.7 | `config.rb:16` 332.2, `config.rb:8` 71.0, `config.rb:66` 38.0 |
| rails: activesupport | 340.1 | 399.6 | `broadcast_logger.rb:129` 16.7, `methods.rb:80` 15.1, `methods.rb:78` 14.2 |
| rails: actionpack | 252.1 | 372.6 | `logger.rb:12` 22.8, `route_set.rb:101` 20.1, `static.rb:145` 11.5 |
| rails: activerecord | 214.8 | 253.7 | `transaction.rb:653` 28.7, `log_subscriber.rb:49` 12.8, `log_subscriber.rb:90` 4.7 |
| ruby stdlib | 153.4 | 210.8 | `http.rb:1682` 67.9, `ipaddr.rb:725` 9.7, `formatter.rb:174` 7.6 |
| gem: json | 125.1 | 127.1 | `common.rb:302` 123.3, `common.rb:860` 1.8 |
| rails: actionview | 62.5 | 110.2 | `tag_helper.rb:309` 3.2, `log_subscriber.rb:61` 3.0, `structured_event_subscriber.rb:61` 2.8 |
| gem: rack | 52.6 | 70.8 | `request.rb:693` 9.0, `body_proxy.rb:12` 3.9, `request.rb:604` 3.2 |
| ruby default gem: uri | 51.5 | 54.2 | `common.rb:456` 13.2, `common.rb:465` 8.4, `common.rb:108` 3.4 |
| gem: inertia_rails | 40.1 | 45.2 | `ssr.rb:14` 7.8, `props_resolver.rb:81` 2.5, `renderer.rb:104` 2.1 |
| gem: logger | 32.3 | 33.5 | `log_device.rb:165` 8.2, `log_device.rb:33` 8.2, `logger.rb:685` 8.1 |
| rails: activemodel | 29.3 | 34.5 | `attribute.rb:9` 4.7, `builder.rb:37` 2.3, `string.rb:39` 2.3 |
| gem: sqlite3 | 19.5 | 22.1 | `statement.rb:125` 6.5, `statement.rb:54` 5.2, `statement.rb:186` 2.2 |
| gem: concurrent-ruby | 18.2 | 19.1 | `safe_initialization.rb:30` 5.8, `mutex_lockable_object.rb:32` 1.9, `mutex_lockable_object.rb:33` 1.9 |
| gem: i18n | 16.8 | 28.9 | `i18n.rb:476` 4.7, `base.rb:157` 2.2, `i18n.rb:396` 1.7 |
| gem: bcrypt | 9.3 | 10.2 | `password.rb:102` 2.9, `password.rb:103` 1.5, `engine.rb:70` 1.2 |
| rails: railties | 8.7 | 8.9 | `logger.rb:57` 1.9, `logger.rb:42` 1.0, `logger.rb:37` 1.0 |
| gem: bootsnap | 4.7 | 29.6 | `iseq.rb:98` 2.2, `cache.rb:218` 0.7, `iseq.rb:154` 0.5 |
| gem: tzinfo | 4.5 | 5.3 | `timestamp.rb:208` 2.1, `timestamp.rb:193` 1.1, `constant_offset_data_timezone_info.rb:52` 1.1 |
| gem: propshaft | 4.4 | 4.6 | `server.rb:16` 1.5, `server.rb:13` 1.0, `server.rb:60` 1.0 |
| rails: activejob | 4.3 | 6.1 | `log_subscriber.rb:207` 0.9, `arguments.rb:141` 0.5, `configured_job.rb:15` 0.3 |
| gem: base64 | 4.1 | 4.3 | `base64.rb:283` 3.0, `base64.rb:310` 1.1 |
| app | 4.1 | 10.7 | `application.html.erb:31` 0.8, `user.rb:20` 0.7, `inertia_controller.rb:7` 0.4 |
| gem: globalid | 3.5 | 4.6 | `gid.rb:95` 0.9, `gid.rb:159` 0.7, `gid.rb:166` 0.4 |
| gem: rack-session | 2.9 | 3.0 | `id.rb:275` 1.0, `id.rb:277` 1.0, `id.rb:401` 0.7 |
| gem: zeitwerk | 2.4 | 3.8 | `cref.rb:47` 0.5, `file_system.rb:203` 0.4, `constant_path_validator.rb:13` 0.4 |
| ruby default gem: securerandom | 1.8 | 1.8 | `securerandom.rb:71` 1.8 |
| gem: capybara-lockstep | 1.1 | 1.2 | `helper.rb:12` 0.2, `helper.rb:9` 0.2, `helper.rb:16` 0.2 |
| rails: actionmailer | 0.6 | 1.0 | `parameterized.rb:149` 0.2, `parameterized.rb:107` 0.1, `parameterized.rb:119` 0.1 |
| gem: solid_queue | 0.2 | 0.3 | `batch_id.rb:20` 0.2 |
| gem: msgpack | 0.0 | 0.5 | `factory.rb:9` 0.0, `factory.rb:41` 0.0, `factory.rb:31` 0.0 |
| gem: jbuilder | 0.0 | 1.1 | `jbuilder_dependency_tracker.rb:0` 0.0, `railtie.rb:10` 0.0, `jbuilder_dependency_tracker.rb:3` 0.0 |
| gem: erubi | 0.0 | 3.3 | `erubi.rb:139` 0.0, `erubi.rb:146` 0.0, `erubi.rb:196` 0.0 |
| gem: useragent | 0.0 | 22.3 | `base.rb:2` 0.0, `browsers.rb:0` 0.0, `user_agent.rb:0` 0.0 |
| lowrail-profile | 0.0 | 0.1 | `profile.rb:66` 0.0, `profile.rb:56` 0.0 |
| rails: actioncable | 0.0 | 0.4 | `engine.rb:21` 0.0, `action_cable_helper.rb:0` 0.0, `action_cable_helper.rb:7` 0.0 |
| rails: activestorage | 0.0 | 0.1 | `engine.rb:215` 0.0 |
| gem: rails-html-sanitizer | 0.0 | 0.1 | `scrubbers.rb:55` 0.0, `sanitizer.rb:157` 0.0 |
| rails: actiontext | 0.0 | 2.5 | `content.rb:29` 0.0, `serialization.rb:6` 0.0, `content.rb:24` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Mails

| # | Mailer action | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | UserMailer#email_verification | 2 / 2 | 700.0 / 700.0 | 0.0 | 1073.5 | `GEM/mail/lib/mail/utilities.rb:215` 36.0, `GEM/mail/lib/mail/parsers/address_lists_parser.rb:32009` 31.0, `GEM/mail/lib/mail/parser_tools.rb:7` 25.0 | `app/mailers/user_mailer.rb:15` 469.0, `app/mailers/user_mailer.rb:13` 55.0, `app/views/user_mailer/email_verification.html.erb:7` 39.0 |
| 2 | UserMailer#password_reset | 2 / 2 | 695.0 / 695.0 | 0.0 | 756.0 | `GEM/mail/lib/mail/utilities.rb:215` 36.0, `GEM/mail/lib/mail/parsers/address_lists_parser.rb:32009` 31.0, `GEM/mail/lib/mail/parser_tools.rb:7` 25.0 | `app/mailers/user_mailer.rb:8` 470.0, `app/views/user_mailer/password_reset.html.erb:5` 38.0, `app/mailers/user_mailer.rb:6` 36.0 |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/mail/lib/mail/utilities.rb:215` | 27.0 / 27.0 | 100% | `app/mailers/user_mailer.rb:8` 50%, `app/mailers/user_mailer.rb:15` 50% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 2 | `GEM/mail/lib/mail/parsers/address_lists_parser.rb:32009` | 23.25 / 23.25 | 100% | `app/mailers/user_mailer.rb:8` 50%, `app/mailers/user_mailer.rb:15` 50% | `_wide = data[p].ord` |
| 3 | `GEM/mail/lib/mail/parser_tools.rb:7` | 18.75 / 18.75 | 100% | `app/mailers/user_mailer.rb:8` 50%, `app/mailers/user_mailer.rb:15` 50% | `data.slice(from_bytes..to_bytes).force_encoding(Encoding::UTF_8)` |
| 4 | `GEM/mail/lib/mail/utilities.rb:291` | 17.25 / 17.25 | 100% | `app/mailers/user_mailer.rb:15` 50%, `app/mailers/user_mailer.rb:8` 50% | `value !~ /\S/` |
| 5 | `GEM/mail/lib/mail/parsers/content_type_parser.rb:734` | 13.5 / 13.5 | 100% | `app/mailers/user_mailer.rb:8` 50%, `app/mailers/user_mailer.rb:15` 50% | `_wide = data[p].ord` |
| 6 | `RAILS/actionview/lib/action_view/log_subscriber.rb:61` (debug logging) | 13.5 / 13.5 | 100% | `app/mailers/user_mailer.rb:15` 50%, `app/mailers/user_mailer.rb:8` 50% | `string = string.sub(rails_root, "")` |
| 7 | `GEM/mail/lib/mail/field_list.rb:71` | 11.25 / 11.25 | 100% | `app/mailers/user_mailer.rb:15` 50%, `app/mailers/user_mailer.rb:8` 50% | `fields = select { \|f\| f.responsible_for? field_name }` |
| 8 | `RAILS/actionview/lib/action_view/structured_event_subscriber.rb:61` † (debug logging) | 11.25 / 11.25 | 100% | `app/mailers/user_mailer.rb:15` 50%, `app/mailers/user_mailer.rb:8` 50% | `string = string.sub("#{rails_root}/", "")` |
| 9 | `GEM/mail/lib/mail/field.rb:176` | 9.0 / 9.0 | 100% | `app/mailers/user_mailer.rb:8` 50%, `app/mailers/user_mailer.rb:15` 50% | `class_name = FIELDS_MAP[name.to_s.downcase]` |
| 10 | `GEM/logger/lib/logger.rb:685` (debug logging) | 7.5 / 7.5 | 100% | `app/mailers/user_mailer.rb:15` 40%, `app/mailers/user_mailer.rb:8` 40% | `message = yield` |
