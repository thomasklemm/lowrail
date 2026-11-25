# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails test -v`
* Ruby: ruby 3.4.13 (2026-11-19 revision 48857d6f2e) +PRISM [x86_64-linux]
* Rails: 8.1.4.1, test environment
* Counted in run 1: 920 requests, 2229 jobs, 1337 mail windows; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 920 | 16748.8 | 2229 | 1337 | 0 | 0 |
| run2 | 1 | 920 | 16750.6 | 2229 | 1337 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 1.22 objects per request; 1 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/models/setting.rb:424` | `find_or_default` | 774.13 | 225.89 | 13.15 | `RAILS/activerecord/lib/active_record/relation/query_methods.rb:2117` 4%, `RAILS/activerecord/lib/active_record/relation/query_methods.rb:2154` 3%, `RAILS/activerecord/lib/active_record/relation.rb:98` 3% | AccountController#login 20%, IssuesController#index 11%, IssuesController#create 9% | `setting = where(:name => name).order(:id => :desc).first` |
| 2 | `lib/redmine/job_wrapper.rb:24` | `keep_current_user` | 599.17 | 13.81 | 0.0 | `GEM/css_parser/lib/css_parser/parser.rb:407` 12%, `GEM/css_parser/lib/css_parser/parser.rb:429` 4%, `GEM/css_parser/lib/css_parser.rb:112` 3% | IssuesController#create 40%, IssuesController#update 28%, IssueRelationsController#create 9% | `yield` |
| 3 | `app/models/mailer.rb:746` | `deliver_mail` | 381.81 | 2.35 | 0.0 | `GEM/mail/lib/mail/encodings/8bit.rb:14` 11%, `GEM/mail/lib/mail/utilities.rb:215` 10%, `GEM/mail/lib/mail/utilities.rb:388` 6% | IssuesController#create 41%, IssuesController#update 29%, IssueRelationsController#create 9% | `super` |
| 4 | `app/views/twofa/totp/_new.html.erb:3` |  | 368.53 | 0.0 | 0.03 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_util.rb:93` 70%, `GEM/rqrcode/lib/rqrcode/export/png.rb:105` 15%, `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_polynomial.rb:32` 4% | TwofaController#activate_confirm 100% | `<%= image_tag RQRCode::QRCode.new(twofa_view[:provisioning_uri]).as_pn` |
| 5 | `lib/plugins/acts_as_customizable/lib/acts_as_customizable.rb:94` | `custom_field_values` | 195.36 | 25.77 | 0.0 | `RAILS/activesupport/lib/active_support/descendants_tracker.rb:108` 4%, `RAILS/activesupport/lib/active_support/descendants_tracker.rb:109` 4%, `GEM/sqlite3/lib/sqlite3/statement.rb:159` 3% | IssuesController#create 17%, IssuesController#update 16%, IssuesController#show 16% | `cv = custom_values.detect { \|v\| v.custom_field == field }` |
| 6 | `app/models/mailer.rb:733` | `mail` | 167.85 | 0.0 | 0.12 | `GEM/mail/lib/mail/utilities.rb:215` 13%, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 9%, `GEM/mail/lib/mail/parsers/content_type_parser.rb:734` 8% | IssuesController#create 41%, IssuesController#update 28%, IssueRelationsController#create 9% | `super do \|format\|` |
| 7 | `lib/redmine/i18n.rb:33` | `l` | 137.94 | 0.0 | 17.23 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:60` 25%, `GEM/i18n/lib/i18n/backend/fallbacks.rb:54` 25%, `GEM/i18n/lib/i18n/backend/base.rb:49` 12% | IssuesController#index 35%, IssuesController#show 10%, MyController#account 9% | `::I18n.t(*args)` |
| 8 | `app/models/issue.rb:299` | `available_custom_fields` | 122.26 | 17.93 | 0.0 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` 11%, `RAILS/activerecord/lib/arel/visitors/to_sql.rb:790` 4%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 2% | IssuesController#create 34%, IssuesController#update 22%, IssuesController#show 21% | `(project && tracker) ? (project.all_issue_custom_fields & tracker.cust` |
| 9 | `app/models/user.rb:878` | `allowed_to?` | 119.6 | 15.19 | 1.09 | `RAILS/activerecord/lib/arel/visitors/to_sql.rb:790` 7%, `RAILS/activerecord/lib/arel/table.rb:85` 4%, `RAILS/activerecord/lib/active_record/reflection.rb:214` 3% | IssuesController#index 85%, ProjectsController#index 9%, IssuesController#show 3% | `roles = self.roles.to_a \| [builtin_role]` |
| 10 | `lib/redmine/wiki_formatting/sanitization_filter.rb:132` | `call` | 118.54 | 0.0 | 0.0 | `GEM/sanitize/lib/sanitize.rb:203` 46%, `GEM/sanitize/lib/sanitize.rb:206` 18%, `GEM/sanitize/lib/sanitize/transformers/clean_element.rb:84` 6% | IssuesController#update 25%, IssuesController#create 23%, ProjectsController#index 15% | `Sanitize.clean_node!(doc, allowlist)` |
| 11 | `app/models/user.rb:710` | `membership` | 112.81 | 14.32 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 4%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 3%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 2% | IssuesController#create 31%, IssuesController#update 24%, IssueRelationsController#create 6% | `h[project_id] = memberships.where(:project_id => project_id).first` |
| 12 | `lib/redmine/menu_manager.rb:190` | `render_single_menu_node` | 106.1 | 0.0 | 0.0 | `RAILS/actionpack/lib/action_dispatch/journey/formatter.rb:182` 15%, `RAILS/actionpack/lib/action_dispatch/journey/formatter.rb:158` 7%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 6% | IssuesController#index 16%, IssuesController#show 15%, ProjectsController#show 15% | `link_to(label, use_absolute_controller(url), options)` |
| 13 | `app/models/user.rb:777` | `project_ids_by_role` | 97.34 | 13.51 | 0.36 | `RAILS/activerecord/lib/arel/visitors/to_sql.rb:790` 10%, `RAILS/activerecord/lib/arel/table.rb:85` 3%, `RAILS/activerecord/lib/active_record/reflection.rb:214` 2% | AccountController#login 21%, IssuesController#index 12%, IssuesController#show 12% | `pluck(:user_id, :role_id, :project_id)` |
| 14 | `app/models/issue_query.rb:438` | `issues` | 97.31 | 9.02 | 0.0 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 7%, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:177` 6%, `GEM/sqlite3/lib/sqlite3/statement.rb:159` 6% | IssuesController#index 92%, MyController#page 8% | `issues = scope.to_a` |
| 15 | `app/models/user.rb:742` | `roles_for_project` | 93.71 | 10.05 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `RAILS/activerecord/lib/active_record/relation.rb:348` 4%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 3% | IssuesController#create 31%, IssuesController#update 24%, IssuesController#show 6% | `membership.roles.to_a` |
| 16 | `lib/redmine/project_jump_box.rb:100` | `set_pref_project_ids` | 93.53 | 11.83 | 0.0 | `RUBY/psych/visitors/yaml_tree.rb:72` 9%, `RUBY/psych/tree_builder.rb:97` 8%, `RUBY/psych/nodes/node.rb:33` 6% | IssuesController#update 13%, IssuesController#show 13%, IssuesController#create 6% | `@user.pref.save` |
| 17 | `app/models/project.rb:1352` | `allowed_permissions` | 89.0 | 17.12 | 0.57 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` 8%, `RAILS/activemodel/lib/active_model/type/string.rb:39` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5% | IssuesController#create 15%, ProjectsController#index 13%, IssuesController#update 10% | `enabled_modules.pluck(:name)` |
| 18 | `lib/redmine/views/builders/xml.rb:40` | `tag!` | 88.07 | 0.0 | 7.46 | `GEM/builder/lib/builder/xchar.rb:155` 18%, `GEM/builder/lib/builder/xchar.rb:154` 10%, `GEM/builder/lib/builder/xchar.rb:156` 9% | IssuesController#index 34%, CustomFieldsController#index 19%, IssuesController#show 14% | `super` |
| 19 | `lib/redmine/views/labelled_form_builder.rb:46` | `time_zone_select` | 87.51 | 0.0 | 0.02 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:53` 8%, `RAILS/activesupport/lib/active_support/testing/time_helpers.rb:179` 8%, `RAILS/actionview/lib/action_view/helpers/form_options_helper.rb:797` 8% | MyController#account 90%, UsersController#new 10% | `label_for_field(field, options) + super(field, priority_zones, options` |
| 20 | `app/models/setting.rb:330` | `check_cache` | 72.34 | 20.43 | 0.0 | `RAILS/activerecord/lib/active_record/relation/calculations.rb:512` 4%, `RAILS/activerecord/lib/active_record/connection_adapters/sqlite3/database_statements.rb:123` 4%, `RAILS/activerecord/lib/active_record/relation/calculations.rb:439` 2% | AccountController#login 19%, IssuesController#show 6%, UsersController#show 6% | `settings_updated_on = Setting.maximum(:updated_on)` |
| 21 | `app/models/custom_value.rb:27` | `initialize` | 69.95 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 10%, `RAILS/activemodel/lib/active_model/attribute.rb:13` 6%, `RAILS/activerecord/lib/active_record/associations/association.rb:221` 6% | IssuesController#index 27%, IssuesController#create 22%, IssuesController#show 7% | `super` |
| 22 | `app/models/user_preference.rb:66` | `initialize` | 63.16 | 0.0 | 0.0 | `RUBY/psych/visitors/yaml_tree.rb:72` 13%, `RUBY/psych/tree_builder.rb:97` 8%, `RUBY/psych/nodes/node.rb:33` 7% | AccountController#login 43%, IssuesController#index 14%, WelcomeController#index 12% | `self.others \|\|= {}` |
| 23 | `app/models/user.rb:428` | `pref` | 60.26 | 15.24 | 0.03 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 3%, `RAILS/activerecord/lib/active_record/relation/query_methods.rb:1495` 2% | IssuesController#create 16%, UsersController#show 13%, IssuesController#update 12% | `self.preference \|\|= UserPreference.new(:user => self)` |
| 24 | `app/models/user.rb:983` | `anonymous` | 54.4 | 15.9 | 0.84 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` 8%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 3%, `GEM/sqlite3/lib/sqlite3/statement.rb:76` 2% | AccountController#login 39%, IssuesController#index 11%, IssuesController#show 6% | `anonymous_user = AnonymousUser.unscoped.find_by(:lastname => 'Anonymou` |
| 25 | `app/models/user_preference.rb:85` | `[]=` | 51.93 | 0.0 | 2.06 | `RUBY/psych/visitors/yaml_tree.rb:72` 12%, `RUBY/psych.rb:328` 7%, `RUBY/psych/nodes/node.rb:33` 6% | AccountController#login 42%, IssuesController#index 13%, WelcomeController#index 12% | `h = (read_attribute(:others) \|\| {}).dup` |
| 26 | `app/views/layouts/base.html.erb:12` |  | 48.58 | 39.57 | 0.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 31%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 18%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 17% | AccountController#login 32%, IssuesController#index 10%, MyController#account 9% | `<%= javascript_importmap_tags %>` |
| 27 | `app/models/role.rb:328` | `find_or_create_system_role` | 47.6 | 15.16 | 0.89 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` 6%, `GEM/sqlite3/lib/sqlite3/statement.rb:76` 3%, `RAILS/activerecord/lib/active_record/connection_adapters/sqlite3/database_statements.rb:123` 3% | AccountController#login 17%, IssuesController#index 10%, IssuesController#show 10% | `role = unscoped.find_by(:builtin => builtin)` |
| 28 | `app/models/setting.rb:426` | `find_or_default` | 45.78 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:101` 38%, `RAILS/activemodel/lib/active_model/attribute_set.rb:74` 25%, `RAILS/activerecord/lib/active_record/associations.rb:79` 13% | AccountController#login 21%, IssuesController#index 12%, IssuesController#create 10% | `setting = new` |
| 29 | `app/models/issue.rb:145` | `visible_condition` | 45.25 | 11.3 | 1.1 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 3%, `RAILS/activesupport/lib/active_support/descendants_tracker.rb:108` 3% | UsersController#show 52%, IssueRelationsController#create 17%, ProjectsController#show 10% | `user_ids = [user.id] + user.groups.pluck(:id).compact` |
| 30 | `app/models/group_builtin.rb:47` | `load_instance` | 44.45 | 11.9 | 0.35 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` 8%, `RAILS/activerecord/lib/arel/table.rb:85` 2%, `GEM/sqlite3/lib/sqlite3/statement.rb:76` 2% | AccountController#login 21%, IssuesController#index 13%, IssuesController#show 12% | `Current.instances[self] \|\|= unscoped.order(:id).first \|\| create_instan` |

910.16 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | (no action name) | 10 / 10 | 230017.6 / 229973.6 | -44.0 | 207041.8 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 2783.0, `GEM/nokogiri/lib/nokogiri/xml/document.rb:416` 2766.0, `RAILS/actionpack/lib/action_dispatch/journey/route.rb:20` 2532.0 | `config/initializers/10-patches.rb:102` 4.0 |
| 2 | IssueRelationsController#create | 3 / 3 | 134738.0 / 134738.0 | 0.0 | 93606.0 | `GEM/css_parser/lib/css_parser/parser.rb:407` 2900.0, `GEM/mail/lib/mail/utilities.rb:215` 2733.0, `GEM/mail/lib/mail/encodings/8bit.rb:14` 2118.0 | `lib/redmine/job_wrapper.rb:24` 24677.5, `app/models/mailer.rb:746` 16480.5, `app/models/mailer.rb:733` 6933.0 |
| 3 | FilesController#create | 5 / 5 | 96514.0 / 96514.0 | 0.0 | 78506.4 | `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/collection/map/non_concurrent_map_backend.rb:131` 2145.3, `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/map.rb:245` 2142.0, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 174.8 | `app/models/setting.rb:424` 524.0, `lib/redmine/project_jump_box.rb:100` 486.3, `lib/plugins/acts_as_attachable/lib/acts_as_attachable.rb:145` 268.0 |
| 4 | TwofaController#activate_confirm | 8 / 8 | 55027.6 / 55141.3 | 113.7 | 56475.6 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_util.rb:93` 33851.1, `GEM/rqrcode/lib/rqrcode/export/png.rb:105` 7356.0, `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_polynomial.rb:32` 2057.1 | `app/views/twofa/totp/_new.html.erb:3` 48434.9, `app/models/setting.rb:424` 634.0, `app/helpers/application_helper.rb:578` 320.6 |
| 5 | IssuesController#update | 21 / 21 | 45167.4 / 45177.9 | 10.5 | 45691.5 | `GEM/css_parser/lib/css_parser/parser.rb:407` 899.0, `GEM/mail/lib/mail/utilities.rb:215` 846.5, `GEM/mail/lib/mail/encodings/8bit.rb:14` 656.7 | `lib/redmine/job_wrapper.rb:24` 7641.9, `app/models/mailer.rb:746` 5083.7, `app/models/mailer.rb:733` 2150.1 |
| 6 | IssuesController#create | 36 / 36 | 38062.5 / 38066.7 | 4.2 | 37300.6 | `GEM/css_parser/lib/css_parser/parser.rb:407` 762.3, `GEM/mail/lib/mail/utilities.rb:215` 717.5, `GEM/mail/lib/mail/encodings/8bit.rb:14` 420.7 | `lib/redmine/job_wrapper.rb:24` 6360.4, `app/models/mailer.rb:746` 4089.8, `app/models/setting.rb:424` 1875.6 |
| 7 | ProjectsController#settings | 2 / 2 | 35737.0 / 35746.0 | 9.0 | 35766.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 1498.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 820.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 727.0 | `lib/redmine/menu_manager.rb:190` 1832.0, `lib/plugins/acts_as_customizable/lib/acts_as_customizable.rb:94` 1803.0, `lib/redmine/i18n.rb:33` 1448.0 |
| 8 | IssuesController#new | 4 / 4 | 30999.3 / 30998.0 | -1.3 | 30986.8 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 1052.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 604.3, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 512.7 | `app/models/setting.rb:424` 1960.7, `lib/redmine/menu_manager.rb:190` 1374.0, `app/views/wiki_toolbar/_menus.html.erb:20` 1050.0 |
| 9 | AttachmentsController#destroy | 3 / 3 | 29746.5 / 29746.5 | 0.0 | 20530.7 | `GEM/css_parser/lib/css_parser/parser.rb:407` 580.0, `GEM/mail/lib/mail/utilities.rb:215` 547.0, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 396.0 | `lib/redmine/job_wrapper.rb:24` 4903.5, `app/models/mailer.rb:746` 3230.5, `app/models/setting.rb:424` 1982.0 |
| 10 | IssuesController#edit | 3 / 3 | 28023.5 / 28020.0 | -3.5 | 29688.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 996.5, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 542.5, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 459.0 | `lib/redmine/menu_manager.rb:190` 1641.0, `app/views/wiki_toolbar/_menus.html.erb:20` 1050.0, `lib/plugins/acts_as_customizable/lib/acts_as_customizable.rb:94` 602.0 |
| 11 | IssuesController#index | 45 / 45 | 24797.2 / 24801.9 | 4.8 | 24698.2 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 353.6, `GEM/sqlite3/lib/sqlite3/statement.rb:159` 334.9, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 334.6 | `app/models/user.rb:878` 2129.4, `app/models/issue_query.rb:438` 1876.8, `app/models/setting.rb:424` 1817.3 |
| 12 | TwofaBackupCodesController#create | 2 / 2 | 24003.0 / 23983.0 | -20.0 | 12738.5 | `GEM/css_parser/lib/css_parser/parser.rb:407` 580.0, `GEM/mail/lib/mail/utilities.rb:215` 541.0, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 290.0 | `lib/redmine/job_wrapper.rb:24` 4665.0, `lib/redmine/twofa/base.rb:136` 3340.0, `app/models/mailer.rb:746` 2692.0 |
| 13 | UsersController#new | 3 / 3 | 20681.0 / 20680.5 | -0.5 | 21157.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 722.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 663.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 598.0 | `lib/redmine/views/labelled_form_builder.rb:46` 4023.0, `lib/redmine/views/labelled_form_builder.rb:42` 1166.0, `app/models/application_record.rb:31` 1023.0 |
| 14 | AdminController#projects | 2 / 2 | 19185.0 / 19183.0 | -2.0 | 19255.5 | `GEM/sanitize/lib/sanitize.rb:203` 588.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 543.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 508.0 | `lib/redmine/wiki_formatting/sanitization_filter.rb:132` 1590.0, `lib/redmine/wiki_formatting/inline_attachments_scrubber.rb:33` 1401.0, `lib/redmine/i18n.rb:33` 1096.0 |
| 15 | IssuesController#show | 49 / 49 | 17223.7 / 17222.8 | -0.9 | 16897.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 362.4, `GEM/sqlite3/lib/sqlite3/statement.rb:159` 288.5, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 202.5 | `app/models/setting.rb:424` 781.4, `lib/plugins/acts_as_customizable/lib/acts_as_customizable.rb:94` 584.3, `app/models/issue.rb:299` 485.9 |
| 16 | TimelogController#index | 2 / 2 | 16586.0 / 16586.0 | 0.0 | 16050.0 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` 300.0, `RAILS/activerecord/lib/arel/table.rb:85` 212.0, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 206.0 | `app/controllers/timelog_controller.rb:66` 3040.0, `app/models/custom_field.rb:60` 1319.0, `lib/redmine/views/builders/xml.rb:40` 777.0 |
| 17 | ProjectsController#index | 24 / 24 | 15510.3 / 15510.0 | -0.3 | 15824.0 | `GEM/sanitize/lib/sanitize.rb:203` 286.1, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 179.3, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 159.2 | `app/models/setting.rb:424` 780.7, `lib/redmine/wiki_formatting/sanitization_filter.rb:132` 712.3, `lib/redmine/wiki_formatting/inline_attachments_scrubber.rb:33` 608.4 |
| 18 | ProjectsController#create | 6 / 6 | 14824.4 / 14820.6 | -3.8 | 14122.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 206.4, `GEM/sqlite3/lib/sqlite3/statement.rb:159` 199.8, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 178.0 | `app/controllers/projects_controller.rb:110` 2801.4, `app/models/setting.rb:424` 845.8, `app/models/project.rb:1097` 795.6 |
| 19 | MyController#account | 37 / 37 | 14698.8 / 14701.1 | 2.3 | 14371.2 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 322.2, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 289.2, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 261.2 | `lib/redmine/views/labelled_form_builder.rb:46` 2012.8, `lib/redmine/job_wrapper.rb:24` 779.6, `app/models/setting.rb:424` 732.1 |
| 20 | TwofaController#activate | 6 / 6 | 14302.0 / 14307.6 | 5.6 | 12242.5 | `GEM/css_parser/lib/css_parser/parser.rb:407` 464.0, `GEM/mail/lib/mail/utilities.rb:215` 432.8, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 234.4 | `lib/redmine/job_wrapper.rb:24` 3741.2, `app/models/mailer.rb:746` 2153.6, `app/models/setting.rb:424` 1098.4 |
| 21 | EmailAddressesController#destroy | 2 / 2 | 14275.0 / 14275.0 | 0.0 | 14321.5 | `GEM/css_parser/lib/css_parser/parser.rb:407` 580.0, `GEM/mail/lib/mail/utilities.rb:215` 541.0, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 290.0 | `lib/redmine/job_wrapper.rb:24` 4668.0, `app/models/mailer.rb:746` 2744.0, `app/models/mailer.rb:733` 1259.0 |
| 22 | AccountController#register | 6 / 6 | 13745.2 / 13739.8 | -5.4 | 14726.2 | `GEM/css_parser/lib/css_parser/parser.rb:407` 232.0, `GEM/mail/lib/mail/utilities.rb:215` 215.6, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 116.0 | `app/models/setting.rb:424` 2223.4, `lib/redmine/job_wrapper.rb:24` 1853.6, `app/models/mailer.rb:746` 1018.4 |
| 23 | MyController#password | 8 / 8 | 11593.3 / 11595.1 | 1.9 | 11257.4 | `GEM/css_parser/lib/css_parser/parser.rb:407` 248.6, `GEM/mail/lib/mail/utilities.rb:215` 231.9, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 125.4 | `lib/redmine/job_wrapper.rb:24` 2002.9, `app/models/mailer.rb:746` 1153.7, `app/models/setting.rb:424` 1107.4 |
| 24 | ProjectsController#show | 28 / 28 | 10779.3 / 10780.0 | 0.7 | 11133.6 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 138.4, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 126.7, `GEM/sqlite3/lib/sqlite3/statement.rb:159` 118.9 | `app/models/setting.rb:424` 1021.2, `lib/redmine/menu_manager.rb:190` 541.4, `lib/plugins/acts_as_customizable/lib/acts_as_customizable.rb:94` 416.1 |
| 25 | IssuesController#destroy | 2 / 2 | 10371.0 / 10367.0 | -4.0 | 10473.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 160.0, `GEM/sqlite3/lib/sqlite3/statement.rb:76` 123.0, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 122.0 | `app/models/issue.rb:270` 1996.0, `app/models/issue.rb:177` 1689.0, `lib/redmine/project_jump_box.rb:100` 648.0 |
| 26 | UsersController#destroy | 2 / 2 | 10253.0 / 10245.0 | -8.0 | 11278.5 | `RAILS/activerecord/lib/arel/visitors/to_sql.rb:790` 288.0, `GEM/sqlite3/lib/sqlite3/statement.rb:76` 177.0, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 148.0 | `app/controllers/users_controller.rb:241` 1826.0, `app/models/member_role.rb:81` 486.0, `lib/plugins/acts_as_customizable/lib/acts_as_customizable.rb:177` 446.0 |
| 27 | WelcomeController#index | 21 / 21 | 9679.8 / 9680.0 | 0.2 | 9796.8 | `GEM/sanitize/lib/sanitize.rb:203` 212.8, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 174.3, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 150.3 | `app/models/setting.rb:424` 1921.3, `app/models/news.rb:89` 636.8, `lib/redmine/wiki_formatting/sanitization_filter.rb:132` 418.0 |
| 28 | VersionsController#create | 5 / 5 | 9356.5 / 9353.8 | -2.8 | 8758.8 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 112.0, `GEM/sqlite3/lib/sqlite3/statement.rb:159` 97.5, `RUBY/psych/visitors/yaml_tree.rb:72` 96.0 | `lib/redmine/project_jump_box.rb:100` 648.0, `app/models/setting.rb:424` 477.0, `app/models/issue.rb:145` 460.0 |
| 29 | TimelogController#create | 6 / 6 | 9261.2 / 9261.2 | 0.0 | 9729.8 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` 125.2, `RAILS/activerecord/lib/arel/table.rb:85` 123.4, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 116.8 | `app/models/setting.rb:424` 1082.0, `app/controllers/timelog_controller.rb:129` 398.0, `app/models/time_entry.rb:282` 358.0 |
| 30 | MyController#page | 19 / 19 | 8633.2 / 8639.2 | 5.9 | 8276.5 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` 128.1, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 118.9, `GEM/sqlite3/lib/sqlite3/statement.rb:159` 110.7 | `app/models/setting.rb:424` 548.0, `app/models/issue_query.rb:438` 386.0, `lib/redmine/i18n.rb:33` 321.4 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_util.rb:93` | `rszf` | 256.34 / 257.56 | 1.22 | 299.81 | 1% | Bignum |  | `app/views/twofa/totp/_new.html.erb:3` 100% | `(num >> count) & ((1 << (ARCH_BITS - count)) - 1)` |
| 2 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` | `each` | 119.65 / 119.65 | 0.0 | 119.69 | 99% | String, Array |  | `app/models/issue.rb:299` 12%, `app/models/project.rb:1352` 7% | `val = step` |
| 3 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` | `html_safe` | 118.46 / 118.46 | 0.0 | 118.62 | 38% | String |  | `no app frame` 23%, `app/views/layouts/base.html.erb:12` 8% | `ActiveSupport::SafeBuffer.new(self)` |
| 4 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:318` | `tag_option` | 111.88 / 111.88 | 0.0 | 112.08 | 37% | String |  | `app/views/layouts/base.html.erb:12` 15%, `app/views/wiki_toolbar/_menus.html.erb:20` 8% | `%(#{key}="#{value}")` |
| 5 | `RAILS/activerecord/lib/arel/table.rb:85` | `[]` | 97.28 / 97.28 | 0.0 | 97.3 | 99% | Struct |  | `app/models/setting.rb:424` 22%, `app/models/user.rb:878` 5% | `Attribute.new(table, name)` |
| 6 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` | `+` | 96.53 / 96.53 | 0.0 | 96.55 | 99% | Array, Object |  | `app/models/setting.rb:424` 15%, `lib/plugins/acts_as_customizable/lib/acts_as_customizable.rb:94` 3% | `WhereClause.new(predicates + other.predicates)` |
| 7 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` | `initialize` | 95.29 / 95.29 | 0.0 | 95.42 | 38% | String |  | `no app frame` 19%, `app/views/layouts/base.html.erb:12` 10% | `super` |
| 8 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | `merge` | 88.52 / 88.52 | 0.0 | 88.62 | 73% | Array, Object |  | `app/models/custom_value.rb:27` 8%, `app/models/user.rb:742` 7% | `WhereClause.new(predicates \| other.predicates)` |
| 9 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | `#{method}` | 79.26 / 79.26 | 0.0 | 79.3 | 100% | Array, Hash |  | `app/models/setting.rb:424` 19%, `no app frame` 10% | `dispatch(:#{method}, ...)` |
| 10 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` | `create` | 78.81 / 78.81 | 0.0 | 78.82 | 99% | Object, Hash |  | `app/models/setting.rb:424` 9%, `lib/plugins/acts_as_customizable/lib/acts_as_customizable.rb:94` 7% | `relation_class_for(model).new(model, ...)` |
| 11 | `GEM/css_parser/lib/css_parser/parser.rb:407` | `parse_block_into_rule_sets!` | 78.8 / 78.8 | 0.0 | 79.43 | 8% | String |  | `lib/redmine/job_wrapper.rb:24` 100% | `token = scanner.scan(RULESET_TOKENIZER_RX)` |
| 12 | `RAILS/activerecord/lib/arel.rb:56` | `sql` | 74.5 / 74.5 | 0.0 | 74.52 | 99% | Hash, String |  | `app/models/setting.rb:424` 19%, `lib/redmine/field_format.rb:359` 7% | `Arel::Nodes::SqlLiteral.new(sql_string, retryable: retryable)` |
| 13 | `GEM/mail/lib/mail/utilities.rb:215` | `dasherize` | 74.02 / 74.02 | 0.0 | 74.61 | 8% | String |  | `app/models/mailer.rb:746` 57%, `app/models/mailer.rb:733` 33% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 14 | `RAILS/activerecord/lib/active_record/relation.rb:77` | `initialize` | 70.45 / 70.45 | 0.0 | 70.46 | 99% | Hash |  | `app/models/setting.rb:424` 10%, `lib/plugins/acts_as_customizable/lib/acts_as_customizable.rb:94` 7% | `def initialize(model, table: nil, predicate_builder: nil, values: {})` |
| 15 | `RAILS/activerecord/lib/active_record/connection_adapters/sqlite3/database_statements.rb:123` | `perform_query` | 68.82 / 68.82 | 0.0 | 68.84 | 99% | Array, Hash | #59605 merged 2026-11-04, after this app's version, not released yet | `app/models/setting.rb:424` 32%, `app/models/setting.rb:330` 4% | `ActiveRecord::Result.new(stmt.columns, rows, stmt.types.map { \|t\| type` |
| 16 | `RAILS/activerecord/lib/active_record/relation.rb:98` | `initialize_copy` | 68.71 / 68.71 | 0.0 | 68.73 | 99% | Hash |  | `app/models/setting.rb:424` 32%, `app/models/principal.rb:33` 4% | `@values = @values.dup` |
| 17 | `GEM/sqlite3/lib/sqlite3/statement.rb:76` | `bind_params` | 67.68 / 67.68 | 0.0 | 67.7 | 99% | Array, Hash |  | `app/models/setting.rb:424` 32%, `lib/plugins/acts_as_customizable/lib/acts_as_customizable.rb:94` 3% | `bind_vars.flatten.each do \|var\|` |
| 18 | `RAILS/activerecord/lib/active_record/relation/spawn_methods.rb:10` † | `spawn` | 65.4 / 65.4 | 0.0 | 65.42 | 99% | Object, Class |  | `app/models/setting.rb:424` 33%, `app/models/principal.rb:33` 4% | `already_in_scope?(model.scope_registry) ? model.all : clone` |
| 19 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` | `build_handle` | 64.6 / 64.6 | 0.0 | 64.62 | 100% | Object | #59613 merged 2026-11-04, after this app's version, not released yet, #59235 merged 2026-10-21, after this app's version, not released yet | `app/models/setting.rb:424` 23%, `no app frame` 3% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 20 | `RAILS/activemodel/lib/active_model/type/string.rb:39` | `cast_value` | 64.12 / 64.12 | 0.0 | 64.13 | 99% | String |  | `app/models/setting.rb:111` 12%, `app/models/setting.rb:122` 10% | `when ::String then ::String.new(value)` |
| 21 | `GEM/sanitize/lib/sanitize.rb:203` | `transform_node!` | 60.75 / 60.75 | 0.0 | 61.13 | 15% | String, Data |  | `lib/redmine/wiki_formatting/sanitization_filter.rb:132` 100% | `config[:node_name] = node.name.downcase` |
| 22 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:87` | `expand_from_hash` | 60.29 / 60.29 | 0.0 | 60.3 | 99% | Array |  | `app/models/setting.rb:424` 24%, `app/models/principal.rb:33` 8% | `attributes.flat_map do \|key, value\|` |
| 23 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:235` | `compact_blank` | 57.68 / 57.68 | 0.0 | 57.7 | 99% | Hash |  | `app/models/setting.rb:424` 25%, `app/models/setting.rb:330` 3% | `reject { \|_k, v\| v.blank? }` |
| 24 | `GEM/rqrcode/lib/rqrcode/export/png.rb:105` | `as_png` | 56.28 / 55.97 | -0.31 | 65.29 | 1% | Struct |  | `app/views/twofa/totp/_new.html.erb:3` 100% | `(0...module_px_size).each do \|j\|` |
| 25 | `RAILS/activerecord/lib/arel/nodes/select_statement.rb:11` | `initialize` | 56.03 / 56.03 | 0.0 | 56.04 | 99% | Object, Array |  | `app/models/setting.rb:424` 26%, `app/models/user.rb:878` 7% | `@cores          = [SelectCore.new(relation)]` |
| 26 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:232` | `content_tag_string` | 55.94 / 55.94 | 0.0 | 55.99 | 37% | String |  | `no app frame` 16%, `lib/redmine/views/labelled_form_builder.rb:46` 6% | `"<#{name}#{tag_options}>#{PRE_CONTENT_STRINGS[name]}#{content}</#{name` |
| 27 | `GEM/i18n/lib/i18n/backend/fallbacks.rb:54` | `translate` | 54.17 / 54.17 | 0.0 | 54.17 | 51% | Hash | ruby-i18n/i18n#765 open upstream work | `lib/redmine/i18n.rb:33` 71%, `lib/redmine/i18n.rb:49` 7% | `fallback_options = options.merge(:fallback_in_progress => true, fallba` |
| 28 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:237` | `tag_options` | 53.16 / 53.16 | 0.0 | 53.25 | 37% | String |  | `app/views/layouts/base.html.erb:12` 16%, `lib/redmine/views/labelled_form_builder.rb:46` 7% | `output = +""` |
| 29 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:29` | `references` | 52.79 / 52.79 | 0.0 | 52.8 | 99% | Array |  | `app/models/setting.rb:424` 27%, `app/models/principal.rb:33` 5% | `attributes.each_with_object([]) do \|(key, value), result\|` |
| 30 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:166` | `convert_dot_notation_to_hash` | 52.79 / 52.79 | 0.0 | 52.8 | 99% | Array, Hash |  | `app/models/setting.rb:424` 27%, `app/models/principal.rb:33` 5% | `attributes.each_with_object({}) do \|(key, value), converted\|` |

## Dev/test-mode work

3347.8 of 13415.2 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | error page | `RUBY/error_highlight/base.rb:94` | 1165.71 | 1% | `no app frame` 100% | `Prism.parse_file(absolute_path).value.breadth_first_search { \|node\| no` |
| 2 | error page | `GEM/prism/lib/prism/parse_result.rb:162` | 477.58 | 1% | `no app frame` 100% | `source.lines` |
| 3 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` | 215.77 | 99% | `app/models/setting.rb:424` 24%, `lib/plugins/acts_as_customizable/lib/acts_as_customizable.rb:94` 3% | `binds = binds.inspect` |
| 4 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:177` | 173.04 | 99% | `app/models/setting.rb:424` 25%, `app/models/setting.rb:330` 3% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 5 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:175` | 115.36 | 99% | `app/models/setting.rb:424` 25%, `app/models/setting.rb:330` 3% | `modes = MODES.values_at(*options.compact_blank.keys)` |
| 6 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:77` | 63.33 | 99% | `app/models/setting.rb:424` 23%, `lib/plugins/acts_as_customizable/lib/acts_as_customizable.rb:94` 3% | `[attr&.name, value]` |
| 7 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:26` | 57.68 | 99% | `app/models/setting.rb:424` 25%, `app/models/setting.rb:330` 3% | `"#{payload[:name]} (#{event.duration.round(1)}ms)"` |
| 8 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:90` | 57.68 | 99% | `app/models/setting.rb:424` 25%, `app/models/setting.rb:330` 3% | `case match[1].downcase` |
| 9 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:170` | 57.68 | 99% | `app/models/setting.rb:424` 25%, `app/models/setting.rb:330` 3% | `clear = "\e[#{MODES[:clear]}m"` |
| 10 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:171` | 57.68 | 99% | `app/models/setting.rb:424` 25%, `app/models/setting.rb:330` 3% | `"#{mode}#{color}#{text}#{clear}"` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activerecord | 4433.8 | 4439.7 | `log_subscriber.rb:49` 215.8, `table.rb:85` 97.3, `where_clause.rb:15` 96.5 |
| rails: activesupport | 1852.8 | 1866.5 | `log_subscriber.rb:177` 173.0, `output_safety.rb:242` 118.5, `log_subscriber.rb:175` 115.4 |
| ruby stdlib | 1635.7 | 1807.1 | `base.rb:94` 1165.7, `yaml_tree.rb:72` 42.1, `tree_builder.rb:97` 31.1 |
| app | 893.3 | 914.3 | `role.rb:28` 187.2, `access_control.rb:75` 45.8, `project.rb:1360` 24.1 |
| ruby default gem: prism | 731.8 | 833.5 | `parse_result.rb:162` 477.6, `node.rb:4628` 47.9, `node.rb:30908` 30.4 |
| rails: actionview | 703.0 | 710.6 | `tag_helper.rb:318` 111.9, `tag_helper.rb:232` 55.9, `tag_helper.rb:237` 53.2 |
| rails: actionpack | 663.5 | 723.0 | `exception_wrapper.rb:332` 49.6, `formatter.rb:182` 32.1, `route.rb:20` 22.0 |
| gem: mail | 654.7 | 659.5 | `utilities.rb:215` 74.0, `8bit.rb:14` 45.4, `parameter_hash.rb:22` 39.5 |
| gem: nokogiri | 340.9 | 341.4 | `document.rb:416` 31.9, `searchable.rb:270` 28.8, `node.rb:1254` 22.7 |
| rails: activemodel | 318.3 | 322.1 | `string.rb:39` 64.1, `attribute.rb:13` 26.9, `attribute.rb:101` 24.9 |
| gem: css_parser | 308.3 | 310.8 | `parser.rb:407` 78.8, `parser.rb:429` 24.5, `css_parser.rb:112` 23.0 |
| gem: rqrcode_core | 294.8 | 343.9 | `qr_util.rb:93` 257.0, `qr_polynomial.rb:32` 15.7, `qr_code.rb:256` 3.5 |
| gem: i18n | 275.7 | 276.0 | `fallbacks.rb:54` 54.2, `fallbacks.rb:60` 52.6, `i18n.rb:396` 29.7 |
| gem: sqlite3 | 239.0 | 239.1 | `statement.rb:159` 119.7, `statement.rb:76` 67.7, `statement.rb:80` 21.7 |
| gem: roadie | 123.5 | 124.3 | `style_attribute_builder.rb:25` 15.4, `style_block.rb:21` 12.2, `stylesheet.rb:52` 11.8 |
| gem: builder | 118.6 | 118.7 | `xchar.rb:155` 18.2, `xchar.rb:154` 10.4, `xchar.rb:156` 9.3 |
| gem: sanitize | 114.0 | 114.6 | `sanitize.rb:203` 60.8, `sanitize.rb:206` 23.4, `clean_element.rb:84` 8.2 |
| gem: rqrcode | 65.5 | 76.2 | `png.rb:105` 56.1, `png.rb:104` 9.4, `png.rb:65` 0.0 |
| gem: propshaft | 59.2 | 59.8 | `asset.rb:73` 29.0, `dynamic.rb:11` 14.5, `asset.rb:91` 3.6 |
| gem: rack | 54.4 | 54.7 | `utils.rb:693` 4.2, `body_proxy.rb:12` 4.0, `request.rb:696` 3.8 |
| ruby default gem: logger | 53.3 | 53.4 | `log_device.rb:33` 39.3, `logger.rb:685` 14.0 |
| gem: concurrent-ruby | 47.7 | 47.8 | `non_concurrent_map_backend.rb:131` 17.0, `map.rb:245` 13.1, `safe_initialization.rb:30` 6.0 |
| gem: importmap-rails | 44.1 | 44.3 | `importmap_tags_helper.rb:44` 15.8, `importmap_tags_helper.rb:30` 15.8, `importmap_tags_helper.rb:42` 8.5 |
| gem: loofah | 41.9 | 41.9 | `concerns.rb:172` 19.4, `concerns.rb:177` 4.9, `concerns.rb:43` 4.9 |
| ruby default gem: uri | 37.0 | 37.1 | `common.rb:465` 7.0, `common.rb:90` 4.1, `generic.rb:543` 2.7 |
| gem: rails-html-sanitizer | 36.1 | 36.1 | `sanitizer.rb:165` 9.0, `sanitizer.rb:33` 4.5, `sanitizer.rb:192` 4.5 |
| gem: tzinfo | 35.0 | 35.7 | `timestamp.rb:193` 13.9, `constant_offset_data_timezone_info.rb:52` 7.1, `timestamp.rb:216` 6.6 |
| gem: commonmarker | 22.5 | 22.6 | `config.rb:94` 18.1, `commonmarker.rb:45` 2.7, `config.rb:79` 0.3 |
| gem: globalid | 20.7 | 20.9 | `gid.rb:159` 4.4, `gid.rb:95` 4.1, `gid.rb:166` 2.2 |
| gem: erubi | 15.4 | 15.6 | `erubi.rb:134` 8.9, `erubi.rb:137` 2.0, `erubi.rb:139` 1.2 |
| rails: activejob | 12.7 | 12.8 | `log_subscriber.rb:207` 3.4, `log_subscriber.rb:201` 0.8, `queue_adapter.rb:11` 0.8 |
| gem: debug | 9.7 | 9.8 | `thread_client.rb:903` 2.8, `thread_client.rb:234` 1.4, `thread_client.rb:224` 1.4 |
| rails: railties | 9.0 | 9.0 | `logger.rb:57` 3.0, `engine.rb:748` 1.0, `logger.rb:42` 1.0 |
| gem: chunky_png | 7.8 | 9.1 | `png_encoding.rb:358` 5.5, `canvas.rb:194` 1.8, `chunk.rb:71` 0.0 |
| gem: doorkeeper | 6.1 | 6.3 | `token.rb:120` 1.9, `token.rb:102` 1.4, `token.rb:55` 1.4 |
| rails: actionmailer | 5.7 | 5.8 | `base.rb:1060` 0.5, `base.rb:636` 0.5, `delivery_methods.rb:66` 0.4 |
| gem: rack-session | 4.5 | 4.5 | `id.rb:90` 1.9, `id.rb:277` 1.0, `id.rb:275` 1.0 |
| gem: json | 4.5 | 4.5 | `common.rb:861` 4.3, `common.rb:298` 0.2 |
| gem: rotp | 3.6 | 4.0 | `base32.rb:18` 0.7, `base32.rb:23` 0.5, `base32.rb:50` 0.5 |
| gem: base64 | 2.9 | 2.9 | `base64.rb:310` 1.5, `base64.rb:283` 1.1, `base64.rb:248` 0.3 |
| ruby default gem: securerandom | 2.6 | 2.6 | `securerandom.rb:71` 2.6 |
| gem: mocha | 1.3 | 1.3 | `parameters_matcher.rb:37` 0.3, `expectation_list.rb:55` 0.2, `invocation.rb:45` 0.1 |
| other | 1.1 | 1.1 | `user.rb:301):1` 0.7, `user.rb:309):1` 0.3, `user.rb:299):1` 0.1 |
| gem: marcel | 0.8 | 2.7 | `mime_type.rb:90` 0.2, `magic.rb:81` 0.1, `magic.rb:18` 0.1 |
| gem: addressable | 0.8 | 0.8 | `pure.rb:216` 0.3, `pure.rb:229` 0.1, `pure.rb:217` 0.1 |
| gem: bootsnap | 0.8 | 3.0 | `kernel_require.rb:11` 0.5, `iseq.rb:103` 0.1, `iseq.rb:159` 0.0 |
| gem: roadie-rails | 0.7 | 0.7 | `document_builder.rb:7` 0.1, `automatic.rb:8` 0.1, `inline_on_delivery.rb:25` 0.1 |
| gem: bigdecimal | 0.3 | 0.3 | `util.rb:24` 0.2, `util.rb:51` 0.1 |
| ruby default gem: prettyprint | 0.2 | 0.2 | `prettyprint.rb:404` 0.0, `prettyprint.rb:264` 0.0, `prettyprint.rb:459` 0.0 |
| gem: lowrail-profile | 0.1 | 0.1 | `profile.rb:95` 0.1 |
| ruby default gem: pp | 0.1 | 0.1 | `pp.rb:542` 0.0, `pp.rb:271` 0.0, `pp.rb:268` 0.0 |
| ruby default gem: erb | 0.0 | 0.0 | `util.rb:65` 0.0 |
| ruby default gem: timeout | 0.0 | 0.0 | `timeout.rb:292` 0.0, `timeout.rb:293` 0.0, `timeout.rb:152` 0.0 |
| gem: msgpack | 0.0 | 0.0 | `factory.rb:9` 0.0, `factory.rb:41` 0.0, `factory.rb:16` 0.0 |
| gem: zip_kit | 0.0 | 0.0 | `rails_streaming.rb:55` 0.0, `output_enumerator.rb:134` 0.0, `rails_streaming.rb:47` 0.0 |
| gem: rouge | 0.0 | 1.1 | `lexer.rb:18` 0.0, `lexer.rb:475` 0.0, `lexer.rb:157` 0.0 |
| gem: net-ldap | 0.0 | 0.0 | `ldap.rb:1340` 0.0, `ldap.rb:1237` 0.0, `instrumentation.rb:13` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Jobs

| # | Job | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | DestroyProjectsJob#perform | 2 / 2 | 160796.0 / 160779.0 | -17.0 | 106429.5 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 4148.0, `GEM/sqlite3/lib/sqlite3/statement.rb:76` 2244.0, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 2074.0 | `app/jobs/destroy_project_job.rb:47` 31846.0, `app/models/issue.rb:270` 25019.0, `lib/redmine/nested_set/project_nested_set.rb:135` 12865.0 |
| 2 | DestroyProjectJob#perform | 5 / 5 | 59473.5 / 59473.0 | -0.5 | 73154.2 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 1407.0, `GEM/sqlite3/lib/sqlite3/statement.rb:76` 777.0, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 703.5 | `app/jobs/destroy_project_job.rb:47` 13354.5, `app/models/issue.rb:270` 7085.5, `lib/redmine/job_wrapper.rb:24` 4816.8 |
| 3 | Mailer::DeliveryJob#perform | 2222 / 2222 | 17747.0 / 17746.9 | -0.1 | 17751.5 | `GEM/css_parser/lib/css_parser/parser.rb:407` 579.5, `GEM/mail/lib/mail/utilities.rb:215` 540.1, `GEM/sanitize/lib/sanitize.rb:203` 374.1 | `lib/redmine/job_wrapper.rb:24` 4814.5, `app/models/mailer.rb:746` 3079.1, `app/models/mailer.rb:733` 1375.1 |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/css_parser/lib/css_parser/parser.rb:407` | 579.74 / 579.74 | 100% | `lib/redmine/job_wrapper.rb:24` 100% | `token = scanner.scan(RULESET_TOKENIZER_RX)` |
| 2 | `GEM/mail/lib/mail/utilities.rb:215` | 540.37 / 540.37 | 100% | `app/models/mailer.rb:746` 57%, `app/models/mailer.rb:733` 33% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 3 | `GEM/sanitize/lib/sanitize.rb:203` | 373.83 / 373.83 | 100% | `lib/redmine/wiki_formatting/sanitization_filter.rb:132` 100% | `config[:node_name] = node.name.downcase` |
| 4 | `GEM/mail/lib/mail/encodings/8bit.rb:14` | 347.3 / 347.3 | 96% | `app/models/mailer.rb:746` 100% | `!str.lines.find { \|line\| line.bytesize > 998 }` |
| 5 | `GEM/mail/lib/mail/fields/parameter_hash.rb:22` | 288.27 / 288.28 | 100% | `app/models/mailer.rb:746` 46%, `app/models/mailer.rb:733` 42% | `if k =~ /^#{key_pattern}(\*\|$)/i` |
| 6 | `GEM/mail/lib/mail/field_list.rb:71` | 262.47 / 262.47 | 100% | `app/models/mailer.rb:746` 58%, `app/models/mailer.rb:733` 32% | `fields = select { \|f\| f.responsible_for? field_name }` |
| 7 | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` (debug logging) | 216.9 / 216.9 | 100% | `app/models/setting.rb:424` 11%, `lib/redmine/job_wrapper.rb:24` 9% | `binds = binds.inspect` |
| 8 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` | 205.36 / 205.36 | 100% | `app/models/issue.rb:299` 30%, `lib/plugins/acts_as_customizable/lib/acts_as_customizable.rb:94` 19% | `val = step` |
| 9 | `GEM/mail/lib/mail/utilities.rb:388` | 181.14 / 181.14 | 99% | `app/models/mailer.rb:746` 100% | `charset_encoder.encode(str.dup, from_encoding).encode(to_encoding, :un` |
| 10 | `GEM/css_parser/lib/css_parser/parser.rb:429` | 179.92 / 179.92 | 100% | `lib/redmine/job_wrapper.rb:24` 100% | `current_declarations.gsub!(/\}\s*$/, '')` |

### Mails

| # | Mailer action | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | Mailer#issue_edit | 51 / 51 | 5342.9 / 5342.9 | 0.0 | 5493.0 | `GEM/sanitize/lib/sanitize.rb:203` 452.8, `GEM/mail/lib/mail/utilities.rb:215` 181.3, `GEM/sanitize/lib/sanitize.rb:206` 178.4 | `app/models/mailer.rb:733` 1362.1, `lib/redmine/wiki_formatting/sanitization_filter.rb:132` 1027.0, `app/helpers/issues_helper.rb:669` 223.4 |
| 2 | Mailer#issue_add | 50 / 50 | 4378.9 / 4378.8 | -0.1 | 4514.4 | `GEM/sanitize/lib/sanitize.rb:203` 364.0, `GEM/mail/lib/mail/utilities.rb:215` 185.0, `GEM/sanitize/lib/sanitize.rb:206` 140.0 | `app/models/mailer.rb:733` 1384.8, `lib/redmine/wiki_formatting/sanitization_filter.rb:132` 783.0, `app/models/mailer.rb:734` 135.1 |
| 3 | Mailer#news_added | 50 / 50 | 3954.7 / 3954.8 | 0.1 | 4012.4 | `GEM/sanitize/lib/sanitize.rb:203` 574.0, `GEM/sanitize/lib/sanitize.rb:206` 210.0, `GEM/mail/lib/mail/utilities.rb:215` 181.0 | `app/models/mailer.rb:733` 1384.6, `lib/redmine/wiki_formatting/sanitization_filter.rb:132` 1088.0, `app/models/mailer.rb:734` 135.2 |
| 4 | Mailer#message_posted | 50 / 50 | 3918.7 / 3918.6 | -0.1 | 3981.2 | `GEM/sanitize/lib/sanitize.rb:203` 448.0, `GEM/mail/lib/mail/utilities.rb:215` 182.0, `GEM/sanitize/lib/sanitize.rb:206` 168.0 | `app/models/mailer.rb:733` 1390.9, `lib/redmine/wiki_formatting/sanitization_filter.rb:132` 906.0, `app/models/mailer.rb:734` 135.2 |
| 5 | Mailer#news_comment_added | 50 / 50 | 3551.8 / 3552.1 | 0.3 | 3604.3 | `GEM/sanitize/lib/sanitize.rb:203` 364.0, `GEM/mail/lib/mail/utilities.rb:215` 181.0, `GEM/sanitize/lib/sanitize.rb:206` 140.0 | `app/models/mailer.rb:733` 1387.9, `lib/redmine/wiki_formatting/sanitization_filter.rb:132` 783.0, `app/models/mailer.rb:734` 137.2 |
| 6 | Mailer#document_added | 50 / 50 | 3318.3 / 3318.2 | -0.1 | 3374.8 | `GEM/sanitize/lib/sanitize.rb:203` 364.0, `GEM/mail/lib/mail/utilities.rb:215` 179.0, `GEM/sanitize/lib/sanitize.rb:206` 140.0 | `app/models/mailer.rb:733` 1234.2, `lib/redmine/wiki_formatting/sanitization_filter.rb:132` 783.0, `lib/redmine/wiki_formatting/common_mark/markdown_filter.rb:41` 132.0 |
| 7 | Mailer#wiki_content_updated | 50 / 50 | 3164.7 / 3164.7 | 0.0 | 3221.0 | `GEM/sanitize/lib/sanitize.rb:203` 266.0, `GEM/mail/lib/mail/utilities.rb:215` 181.0, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 122.0 | `app/models/mailer.rb:733` 1323.9, `lib/redmine/wiki_formatting/sanitization_filter.rb:132` 518.0, `app/models/mailer.rb:734` 135.2 |
| 8 | Mailer#test_email | 68 / 68 | 3103.0 / 3103.0 | -0.1 | 3126.4 | `GEM/sanitize/lib/sanitize.rb:203` 247.4, `GEM/mail/lib/mail/utilities.rb:215` 171.0, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 116.7 | `app/models/mailer.rb:733` 1192.3, `lib/redmine/wiki_formatting/sanitization_filter.rb:132` 484.6, `app/models/setting.rb:424` 241.9 |
| 9 | Mailer#wiki_content_added | 50 / 50 | 3054.5 / 3054.6 | 0.1 | 3110.6 | `GEM/sanitize/lib/sanitize.rb:203` 266.0, `GEM/mail/lib/mail/utilities.rb:215` 181.0, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 122.1 | `app/models/mailer.rb:733` 1323.8, `lib/redmine/wiki_formatting/sanitization_filter.rb:132` 518.0, `app/models/mailer.rb:734` 133.2 |
| 10 | Mailer#attachments_added | 50 / 50 | 2907.2 / 2907.2 | 0.0 | 2959.0 | `GEM/sanitize/lib/sanitize.rb:203` 266.0, `GEM/mail/lib/mail/utilities.rb:215` 179.0, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 122.0 | `app/models/mailer.rb:733` 1234.4, `lib/redmine/wiki_formatting/sanitization_filter.rb:132` 518.0, `app/models/mailer.rb:734` 133.0 |
| 11 | Mailer.deliver_mail | 668 / 668 | 2823.2 / 2823.2 | -0.0 | 2822.7 | `GEM/mail/lib/mail/utilities.rb:215` 311.7, `GEM/mail/lib/mail/field_list.rb:71` 155.1, `GEM/mail/lib/mail/utilities.rb:388` 148.1 | `app/models/mailer.rb:746` 2804.2 |
| 12 | Mailer#account_information | 50 / 50 | 2722.3 / 2722.3 | 0.0 | 2769.2 | `GEM/sanitize/lib/sanitize.rb:203` 266.0, `GEM/mail/lib/mail/utilities.rb:215` 177.0, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 122.0 | `app/models/mailer.rb:733` 1233.5, `lib/redmine/wiki_formatting/sanitization_filter.rb:132` 518.0, `app/models/mailer.rb:734` 129.1 |
| 13 | Mailer#lost_password | 50 / 50 | 2709.4 / 2709.4 | 0.0 | 2757.9 | `GEM/sanitize/lib/sanitize.rb:203` 266.0, `GEM/mail/lib/mail/utilities.rb:215` 177.0, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 122.0 | `app/models/mailer.rb:733` 1233.6, `lib/redmine/wiki_formatting/sanitization_filter.rb:132` 518.0, `app/models/mailer.rb:734` 127.0 |
| 14 | Mailer#register | 50 / 50 | 2669.5 / 2669.4 | -0.1 | 2712.1 | `GEM/sanitize/lib/sanitize.rb:203` 266.0, `GEM/mail/lib/mail/utilities.rb:215` 177.0, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 122.1 | `app/models/mailer.rb:733` 1233.6, `lib/redmine/wiki_formatting/sanitization_filter.rb:132` 518.0, `app/models/mailer.rb:735` 127.0 |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/mail/lib/mail/utilities.rb:215` | 245.27 / 245.27 | 100% | `app/models/mailer.rb:746` 63%, `app/models/mailer.rb:733` 36% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 2 | `GEM/sanitize/lib/sanitize.rb:203` | 168.42 / 168.42 | 50% | `lib/redmine/wiki_formatting/sanitization_filter.rb:132` 100% | `config[:node_name] = node.name.downcase` |
| 3 | `GEM/mail/lib/mail/fields/parameter_hash.rb:22` | 128.19 / 128.19 | 100% | `app/models/mailer.rb:746` 53%, `app/models/mailer.rb:733` 47% | `if k =~ /^#{key_pattern}(\*\|$)/i` |
| 4 | `GEM/mail/lib/mail/field_list.rb:71` | 119.75 / 119.75 | 100% | `app/models/mailer.rb:746` 65%, `app/models/mailer.rb:733` 35% | `fields = select { \|f\| f.responsible_for? field_name }` |
| 5 | `GEM/mail/lib/mail/utilities.rb:291` | 81.28 / 81.28 | 100% | `app/models/mailer.rb:746` 67%, `app/models/mailer.rb:733` 28% | `value !~ /\S/` |
| 6 | `GEM/mail/lib/mail/utilities.rb:388` | 73.88 / 73.88 | 50% | `app/models/mailer.rb:746` 100% | `charset_encoder.encode(str.dup, from_encoding).encode(to_encoding, :un` |
| 7 | `GEM/sanitize/lib/sanitize.rb:206` | 63.22 / 63.22 | 50% | `lib/redmine/wiki_formatting/sanitization_filter.rb:132` 100% | `result = transformer.call(**config)` |
| 8 | `GEM/mail/lib/mail/utilities.rb:226` | 60.6 / 60.6 | 100% | `app/models/mailer.rb:746` 72%, `app/models/mailer.rb:733` 26% | `str.to_s.downcase.tr(Constants::HYPHEN, Constants::UNDERSCORE)` |
| 9 | `GEM/mail/lib/mail/parsers/content_type_parser.rb:734` | 52.16 / 52.16 | 50% | `app/models/mailer.rb:733` 100% | `_wide = data[p].ord` |
| 10 | `GEM/mail/lib/mail/utilities.rb:248` | 48.98 / 48.98 | 100% | `app/models/mailer.rb:746` 98%, `app/models/mailer.rb:733` 2% | `string.gsub(TO_CRLF_REGEX, Constants::CRLF)` |
