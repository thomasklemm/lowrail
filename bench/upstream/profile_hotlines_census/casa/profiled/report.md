# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bundle exec rspec spec/requests --seed 1234 --format documentation`
* Ruby: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux]
* Rails: 8.1.4, test environment
* Counted in run 1: 975 requests, 42 mail windows; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1
* Not attributed: 0.0 objects per request (0.0% of all) are on lines outside the app, Rails, Ruby and the bundle's gems, which no table below ranks; most in `(erb)`

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 975 | 15754.4 | 0 | 42 | 0 | 0 |
| run2 | 1 | 975 | 15754.2 | 0 | 42 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.06 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/models/case_court_report.rb:18` | `generate_to_string` | 3541.45 | 0.0 | 0.0 | `GEM/nokogiri/lib/nokogiri/xml/xpath_context.rb:10` 18%, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1255` 17%, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1253` 17% | CaseCourtReportsController#generate 91%, CourtDatesController#show 9% | `@template.render_to_string(@context)` |
| 2 | `app/controllers/application_controller.rb:41` | `set_active_banner` | 244.48 | 20.59 | 0.0 | `GEM/prosopite/lib/prosopite.rb:286` 53%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 2%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 2% | CaseContacts::FormController#update 7%, EmancipationsController#save 6%, CaseAssignmentsController#create 3% | `@active_banner = current_organization.banners.active.first` |
| 3 | `app/services/twilio_service.rb:15` | `client` | 141.1 | 0.02 | 0.01 | `RUBY/bundled_gems.rb:60` 3%, `RUBY/bundled_gems.rb:111` 3%, `RUBY/bundled_gems.rb:98` 2% | SupervisorsController#create 100%, CasaAdminsController#create 0%, VolunteersController#create 0% | `@client = Twilio::REST::Client.new(@api_key, @api_secret, @acc_sid)` |
| 4 | `app/models/contact_type_group.rb:35` | `generate_for_org!` | 102.87 | 15.07 | 0.0 | `GEM/prosopite/lib/prosopite.rb:286` 52%, `GEM/bugsnag/lib/bugsnag/integrations/railtie.rb:28` 1%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 1% | AllCasaAdmins::CasaOrgsController#create 100% | `ContactType.find_or_create_by!(` |
| 5 | `app/validators/user_validator.rb:56` | `validate_uniqueness` | 101.71 | 13.74 | 0.63 | `GEM/prosopite/lib/prosopite.rb:286` 56%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 7%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 7% | SupervisorsController#update 8%, UsersController#update_email 8%, CaseContactReportsController#index 7% | `existing_record = record.class.find_by(attribute => record[attribute])` |
| 6 | `config/initializers/sent_email_event.rb:7` |  | 91.66 | 12.97 | 0.07 | `GEM/prosopite/lib/prosopite.rb:286` 44%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 4%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 4% | UsersController#update_email 13%, ImportsController#create 12%, VolunteersController#reminder 10% | `SentEmail.create(` |
| 7 | `app/controllers/case_contacts/form_controller.rb:84` | `update` | 86.65 | 9.5 | 0.0 | `GEM/prosopite/lib/prosopite.rb:286` 35%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 2%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 2% | CaseContacts::FormController#update 100% | `if @case_contact.update(case_contact_params)` |
| 8 | `app/views/layouts/casa_app.html.erb:20` |  | 85.01 | 5.86 | 0.16 | `GEM/prosopite/lib/prosopite.rb:286` 52%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 2%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 2% | CasaCasesController#index 7%, CaseContacts::CaseContactsNewDesignController#index 6%, UsersController#update_password 5% | `<% role_badge_class = {"Volunteer" => "bg-sky-50 text-sky-700", "Super` |
| 9 | `app/models/concerns/api.rb:11` | `initialize_api_credentials` | 75.92 | 9.35 | 0.11 | `GEM/prosopite/lib/prosopite.rb:286` 41%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 2%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 2% | ImportsController#create 15%, CaseContactReportsController#index 12%, CasaAdminsController#create 7% | `create_api_credential unless api_credential` |
| 10 | `app/controllers/case_contacts/form_controller.rb:113` | `set_case_contact` | 74.83 | 5.04 | 0.05 | `GEM/prosopite/lib/prosopite.rb:286` 52%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 4%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 4% | CaseContacts::FormController#update 92%, CaseContacts::FormController#show 8% | `.find(params[:case_contact_id])` |
| 11 | `app/views/layouts/casa_app.html.erb:60` |  | 72.53 | 5.69 | 0.49 | `GEM/prosopite/lib/prosopite.rb:286` 61%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 2%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 2% | CasaCasesController#index 7%, CaseContacts::CaseContactsNewDesignController#index 6%, UsersController#update_password 5% | `[custom_link.text, "bi-link-45deg", custom_link.url, nil, true, true]` |
| 12 | `app/models/user.rb:93` | `create_preference_set` | 69.16 | 9.35 | 0.0 | `GEM/prosopite/lib/prosopite.rb:286` 45%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 1%, `GEM/bugsnag/lib/bugsnag/integrations/railtie.rb:28` 1% | ImportsController#create 15%, CaseContactReportsController#index 12%, CasaAdminsController#create 7% | `self.preference_set = PreferenceSet.create` |
| 13 | `app/views/layouts/casa_app.html.erb:76` |  | 60.13 | 4.83 | 3.22 | `GEM/rails-controller-testing/lib/rails/controller/testing/template_assertions.rb:39` 11%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 5%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:287` 5% | CaseContacts::CaseContactsNewDesignController#index 6%, CasaCasesController#index 6%, UsersController#update_password 5% | `<% end %>` |
| 14 | `app/policies/application_policy.rb:58` | `same_org?` | 50.22 | 4.14 | 0.0 | `GEM/prosopite/lib/prosopite.rb:286` 54%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 4%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 4% | EmancipationsController#save 27%, VolunteersController#reminder 8%, SupervisorsController#edit 6% | `user&.casa_org.present? && user.casa_org == record&.casa_org` |
| 15 | `app/services/create_casa_admin_service.rb:21` | `create!` | 45.5 | 2.65 | 0.0 | `GEM/mail/lib/mail/utilities.rb:215` 10%, `GEM/mail/lib/mail/encodings/8bit.rb:14` 8%, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 5% | CasaAdminsController#create 67%, AllCasaAdmins::CasaAdminsController#create 33% | `@casa_admin.invite!(@current_user)` |
| 16 | `app/models/casa_case.rb:206` | `update_cleaning_contact_types` | 41.64 | 4.45 | 0.0 | `GEM/prosopite/lib/prosopite.rb:286` 39%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 2%, `RAILS/activesupport/lib/active_support/callbacks.rb:362` 1% | CasaCasesController#update 100% | `update!(args)` |
| 17 | `app/lib/importers/file_importer.rb:50` | `create_user_record` | 40.63 | 2.19 | 0.0 | `GEM/mail/lib/mail/utilities.rb:215` 10%, `GEM/mail/lib/mail/encodings/8bit.rb:14` 8%, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 5% | ImportsController#create 100% | `user.invite!` |
| 18 | `app/views/case_contacts/case_contacts_new_design/index.html.erb:127` |  | 39.33 | 1.54 | 0.0 | `GEM/prosopite/lib/prosopite.rb:286` 20%, `RAILS/activerecord/lib/arel/alias_predication.rb:8` 7%, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:177` 6% | CaseContacts::CaseContactsNewDesignController#index 100% | `<% answers = contact.contact_topic_answers.reject { \|a\| a.value.blank?` |
| 19 | `app/controllers/casa_cases_controller.rb:64` | `create` | 37.09 | 4.44 | 0.0 | `GEM/prosopite/lib/prosopite.rb:286` 44%, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 6%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 2% | CasaCasesController#create 100% | `if @casa_case.save` |
| 20 | `app/services/case_contacts_export_csv_service.rb:19` | `perform` | 35.78 | 2.58 | 0.0 | `GEM/prosopite/lib/prosopite.rb:286` 46%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` 3%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 3% | CaseContactReportsController#index 97%, CasaCasesController#show 3% | `if case_contacts.present?` |
| 21 | `app/controllers/case_court_reports_controller.rb:117` | `save_report` | 32.71 | 3.74 | 0.02 | `GEM/prosopite/lib/prosopite.rb:286` 26%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 2%, `RAILS/activesupport/lib/active_support/callbacks.rb:362` 2% | CaseCourtReportsController#generate 100% | `casa_case.court_reports.attach(` |
| 22 | `app/models/contact_type_group.rb:29` | `generate_for_org!` | 32.67 | 4.8 | 0.0 | `GEM/prosopite/lib/prosopite.rb:286` 51%, `GEM/bugsnag/lib/bugsnag/integrations/railtie.rb:28` 1%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 1% | AllCasaAdmins::CasaOrgsController#create 100% | `group = ContactTypeGroup.find_or_create_by!(` |
| 23 | `app/controllers/case_contacts/form_controller.rb:230` | `create_additional_case_contacts` | 32.67 | 4.28 | 0.0 | `GEM/prosopite/lib/prosopite.rb:286` 50%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 2%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 2% | CaseContacts::FormController#update 100% | `new_case_contact.save!` |
| 24 | `app/models/case_court_report_context.rb:42` | `case_contacts` | 29.64 | 0.93 | 0.02 | `GEM/prosopite/lib/prosopite.rb:286` 21%, `RAILS/activerecord/lib/arel/table.rb:85` 6%, `RAILS/activerecord/lib/active_record/reflection.rb:214` 3% | CaseCourtReportsController#generate 66%, CourtDatesController#show 34% | `return [] unless interviewees.size.positive?` |
| 25 | `app/controllers/casa_cases_controller.rb:219` | `set_casa_case` | 27.79 | 1.93 | 0.1 | `GEM/prosopite/lib/prosopite.rb:286` 42%, `GEM/friendly_id/lib/friendly_id/finder_methods.rb:36` 14%, `RAILS/activerecord/lib/arel/table.rb:85` 2% | CasaCasesController#update 37%, CasaCasesController#deactivate 22%, CasaCasesController#show 18% | `@casa_case = current_organization.casa_cases.friendly.find(params[:id]` |
| 26 | `app/models/hearing_type.rb:23` | `generate_for_org!` | 26.9 | 4.09 | 0.0 | `GEM/prosopite/lib/prosopite.rb:286` 53%, `GEM/bugsnag/lib/bugsnag/integrations/railtie.rb:28` 1%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 1% | AllCasaAdmins::CasaOrgsController#create 100% | `HearingType.find_or_create_by!(` |
| 27 | `app/controllers/case_assignments_controller.rb:88` | `case_assignment_parent` | 23.8 | 2.6 | 0.07 | `GEM/prosopite/lib/prosopite.rb:286` 57%, `RAILS/activerecord/lib/arel/table.rb:85` 4%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 3% | CaseAssignmentsController#create 93%, CaseAssignmentsController#destroy 7% | `CasaCase.friendly.find(params[:casa_case_id])` |
| 28 | `app/views/layouts/_nav_link.html.erb:7` |  | 22.39 | 0.0 | 5.28 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 16%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 15%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 15% | CaseContacts::CaseContactsNewDesignController#index 6%, CasaCasesController#index 6%, UsersController#update_password 5% | `<i class="bi <%= icon %> shrink-0 text-base" aria-hidden="true"></i>` |
| 29 | `app/controllers/emancipations_controller.rb:31` | `show` | 22.17 | 0.03 | 0.01 | `GEM/nokogiri/lib/nokogiri/xml/xpath_context.rb:10` 16%, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1255` 16%, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1253` 15% | EmancipationsController#show 100% | `send_data((@template.render_to_string context, type: :docx), filename:` |
| 30 | `app/controllers/users_controller.rb:125` | `update_user_email` | 22.01 | 1.67 | 0.02 | `GEM/prosopite/lib/prosopite.rb:286` 11%, `GEM/mail/lib/mail/encodings/8bit.rb:14` 10%, `GEM/mail/lib/mail/utilities.rb:215` 4% | UsersController#update_email 100% | `@user.update({email: email_params[:email]&.strip})` |

1124.6 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | CaseCourtReportsController#generate | 22 / 22 | 161968.5 / 161972.8 | 4.2 | 154863.4 | `GEM/nokogiri/lib/nokogiri/xml/xpath_context.rb:10` 26354.5, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1255` 25616.0, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1253` 25597.1 | `app/models/case_court_report.rb:18` 149613.3, `app/controllers/case_court_reports_controller.rb:117` 1518.8, `app/models/case_court_report_context.rb:42` 911.3 |
| 2 | SupervisorsController#create | 5 / 5 | 52703.0 / 52701.8 | -1.3 | 47093.0 | `GEM/prosopite/lib/prosopite.rb:286` 3218.3, `RUBY/bundled_gems.rb:60` 1188.5, `RUBY/bundled_gems.rb:111` 1094.5 | `app/services/twilio_service.rb:15` 34386.0, `app/controllers/supervisors_controller.rb:39` 4972.3, `app/controllers/supervisors_controller.rb:38` 1356.8 |
| 3 | CourtDatesController#show | 11 / 11 | 41686.9 / 41685.8 | -1.1 | 39363.8 | `GEM/nokogiri/lib/nokogiri/xml/xpath_context.rb:10` 5164.4, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1255` 5019.2, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1253` 5009.4 | `app/models/case_court_report.rb:18` 31103.5, `app/models/case_court_report_context.rb:42` 976.2, `app/models/case_court_report_context.rb:155` 627.3 |
| 4 | AllCasaAdmins::CasaOrgsController#create | 7 / 7 | 38934.0 / 38935.2 | 1.2 | 33910.9 | `GEM/prosopite/lib/prosopite.rb:286` 14317.7, `GEM/bugsnag/lib/bugsnag/integrations/railtie.rb:28` 432.7, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 398.7 | `app/models/contact_type_group.rb:35` 16716.8, `app/models/contact_type_group.rb:29` 5309.7, `app/models/hearing_type.rb:23` 4371.7 |
| 5 | CaseContactsController#index | 4 / 4 | 26001.7 / 25940.7 | -61.0 | 26409.5 | `GEM/prosopite/lib/prosopite.rb:286` 4328.3, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 233.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 221.3 | `app/models/case_contact.rb:387` 5797.3, `app/controllers/concerns/loads_case_contacts.rb:32` 686.0, `app/decorators/case_contacts_decorator.rb:22` 601.0 |
| 6 | CaseContacts::CaseContactsNewDesignController#index | 11 / 11 | 25106.8 / 25106.0 | -0.8 | 23215.4 | `GEM/prosopite/lib/prosopite.rb:286` 2412.4, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 383.3, `RAILS/activerecord/lib/arel/alias_predication.rb:8` 315.9 | `app/views/case_contacts/case_contacts_new_design/index.html.erb:127` 3834.7, `app/controllers/case_contacts/case_contacts_new_design_controller.rb:22` 874.1, `app/views/case_contacts/case_contacts_new_design/index.html.erb:126` 829.0 |
| 7 | CasaOrgController#edit | 2 / 2 | 23254.0 / 23260.0 | 6.0 | 22795.5 | `GEM/prosopite/lib/prosopite.rb:286` 4545.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 335.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 204.0 | `app/views/casa_org/edit.html.erb:70` 530.0, `app/views/layouts/casa_app.html.erb:20` 525.0, `app/views/casa_org/_contact_types.html.erb:21` 462.0 |
| 8 | ReportsController#index | 3 / 3 | 21384.5 / 21379.5 | -5.0 | 16442.7 | `GEM/prosopite/lib/prosopite.rb:286` 3093.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 283.5, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 177.0 | `app/models/concerns/api.rb:11` 702.0, `app/models/user.rb:93` 641.0, `app/views/reports/index.html.erb:76` 549.5 |
| 9 | CaseContacts::FormController#new | 5 / 5 | 21280.5 / 21325.3 | 44.8 | 21963.8 | `GEM/prosopite/lib/prosopite.rb:286` 2794.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 281.8, `RAILS/actionview/lib/action_view/helpers/form_tag_helper.rb:106` 176.3 | `app/controllers/case_contacts/form_controller.rb:122` 751.8, `app/controllers/case_contacts/form_controller.rb:159` 570.3, `app/controllers/case_contacts/form_controller.rb:139` 552.8 |
| 10 | SupervisorsController#index | 3 / 3 | 20278.5 / 20284.5 | 6.0 | 20949.0 | `GEM/prosopite/lib/prosopite.rb:286` 3218.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 179.0, `GEM/uri/lib/uri/rfc2396_parser.rb:291` 164.0 | `app/views/supervisors/index.html.erb:267` 734.0, `app/models/concerns/api.rb:11` 691.0, `app/models/user.rb:93` 630.0 |
| 11 | AnalyticsController#index | 7 / 7 | 20245.3 / 20243.2 | -2.2 | 29005.1 | `GEM/prosopite/lib/prosopite.rb:286` 2613.2, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:144` 401.3, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:149` 366.2 | `app/models/metrics_report.rb:92` 1123.2, `app/models/metrics_report.rb:25` 787.3, `app/models/metrics_report.rb:24` 773.8 |
| 12 | ImportsController#create | 10 / 10 | 19353.1 / 19351.4 | -1.7 | 18249.2 | `GEM/prosopite/lib/prosopite.rb:286` 4451.6, `GEM/mail/lib/mail/utilities.rb:215` 432.9, `GEM/mail/lib/mail/encodings/8bit.rb:14` 352.0 | `app/lib/importers/file_importer.rb:50` 4402.1, `app/models/concerns/api.rb:11` 1257.4, `app/lib/importers/file_importer.rb:49` 1231.3 |
| 13 | UsersController#edit | 2 / 2 | 19085.0 / 19085.0 | 0.0 | 20240.5 | `GEM/prosopite/lib/prosopite.rb:286` 2144.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 255.0, `GEM/uri/lib/uri/rfc2396_parser.rb:291` 164.0 | `app/controllers/users_controller.rb:97` 1188.0, `app/views/layouts/casa_app.html.erb:20` 518.0, `app/views/users/_languages.html.erb:17` 500.0 |
| 14 | ImportsController#index | 2 / 2 | 18331.0 / 18334.0 | 3.0 | 11346.0 | `GEM/prosopite/lib/prosopite.rb:286` 1850.0, `RAILS/activesupport/lib/active_support/testing/time_helpers.rb:179` 175.0, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:53` 175.0 | `app/models/concerns/api.rb:11` 657.0, `app/models/user.rb:93` 596.0, `app/validators/user_validator.rb:56` 521.0 |
| 15 | VolunteersController#edit | 8 / 8 | 17804.1 / 17784.3 | -19.9 | 19154.6 | `GEM/prosopite/lib/prosopite.rb:286` 3086.6, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 214.3, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 201.9 | `app/helpers/ui_helper.rb:10` 804.4, `app/helpers/ui_helper.rb:17` 792.3, `app/views/volunteers/_manage_supervisor.erb:37` 524.9 |
| 16 | CourtDatesController#edit | 2 / 2 | 17747.0 / 17754.0 | 7.0 | 11083.5 | `GEM/prosopite/lib/prosopite.rb:286` 2183.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 195.0, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:53` 169.0 | `app/views/layouts/casa_app.html.erb:20` 521.0, `app/controllers/court_dates_controller.rb:69` 499.0, `app/views/casa_cases/_court_orders.html.erb:66` 479.0 |
| 17 | SupervisorsController#new | 2 / 2 | 17704.0 / 17699.0 | -5.0 | 10595.0 | `GEM/prosopite/lib/prosopite.rb:286` 1850.0, `GEM/uri/lib/uri/rfc2396_parser.rb:291` 164.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 132.0 | `app/models/concerns/api.rb:11` 688.0, `app/models/user.rb:93` 627.0, `app/views/layouts/casa_app.html.erb:20` 516.0 |
| 18 | CasaCasesController#index | 12 / 12 | 17589.3 / 17579.8 | -9.5 | 17775.2 | `GEM/prosopite/lib/prosopite.rb:286` 1763.5, `GEM/uri/lib/uri/rfc2396_parser.rb:291` 164.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 152.3 | `app/views/casa_cases/index.html.erb:59` 1090.6, `app/views/layouts/casa_app.html.erb:20` 517.5, `app/controllers/casa_cases_controller.rb:18` 470.6 |
| 19 | PlacementsController#update | 2 / 2 | 17350.0 / 17344.0 | -6.0 | 11476.5 | `GEM/prosopite/lib/prosopite.rb:286` 1844.0, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 440.0, `GEM/uri/lib/uri/rfc2396_parser.rb:291` 164.0 | `app/controllers/placements_controller.rb:39` 1143.0, `app/views/layouts/casa_app.html.erb:20` 518.0, `app/controllers/placements_controller.rb:59` 496.0 |
| 20 | VolunteersController#create | 6 / 6 | 17296.8 / 17293.8 | -3.0 | 16795.2 | `GEM/prosopite/lib/prosopite.rb:286` 2706.6, `GEM/mail/lib/mail/utilities.rb:215` 389.6, `GEM/mail/lib/mail/encodings/8bit.rb:14` 316.8 | `app/controllers/volunteers_controller.rb:48` 3979.0, `config/initializers/sent_email_event.rb:7` 1065.0, `app/controllers/volunteers_controller.rb:45` 906.0 |
| 21 | CaseGroupsController#index | 2 / 2 | 17032.0 / 17030.0 | -2.0 | 17670.5 | `GEM/prosopite/lib/prosopite.rb:286` 1920.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 189.0, `GEM/uri/lib/uri/rfc2396_parser.rb:291` 164.0 | `app/views/case_groups/index.html.erb:40` 1587.0, `app/views/layouts/casa_app.html.erb:20` 525.0, `app/controllers/application_controller.rb:41` 462.0 |
| 22 | AllCasaAdmins::MetricsController#index | 6 / 6 | 16705.0 / 16687.0 | -18.0 | 17433.3 | `GEM/prosopite/lib/prosopite.rb:286` 1692.6, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:144` 357.6, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:149` 322.4 | `app/models/metrics_report.rb:92` 1241.0, `app/models/metrics_report.rb:25` 801.0, `app/models/metrics_report.rb:26` 774.6 |
| 23 | NotificationsController#index | 7 / 7 | 16600.3 / 16599.8 | -0.5 | 16453.3 | `GEM/prosopite/lib/prosopite.rb:286` 2079.2, `RAILS/activesupport/lib/active_support/testing/time_helpers.rb:179` 164.0, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:53` 164.0 | `app/models/health.rb:7` 804.3, `app/helpers/notifications_helper.rb:23` 630.3, `app/controllers/application_controller.rb:41` 465.0 |
| 24 | CaseContacts::FormController#show | 6 / 6 | 16552.0 / 16555.2 | 3.2 | 17904.2 | `GEM/prosopite/lib/prosopite.rb:286` 2573.4, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 169.2, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 117.8 | `app/controllers/case_contacts/form_controller.rb:113` 1184.8, `app/controllers/case_contacts/form_controller.rb:122` 761.6, `app/controllers/application_controller.rb:41` 466.0 |
| 25 | CaseCourtReportsController#index | 3 / 3 | 16518.5 / 16522.5 | 4.0 | 17607.3 | `GEM/prosopite/lib/prosopite.rb:286` 1462.0, `GEM/uri/lib/uri/rfc2396_parser.rb:291` 164.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 145.0 | `app/views/case_court_reports/_generate_docx.html.erb:23` 1761.5, `app/views/layouts/casa_app.html.erb:20` 519.5, `app/controllers/application_controller.rb:41` 456.5 |
| 26 | CasaAdminsController#create | 8 / 8 | 16399.7 / 16335.0 | -64.7 | 14744.1 | `GEM/prosopite/lib/prosopite.rb:286` 2498.4, `GEM/mail/lib/mail/utilities.rb:215` 417.4, `GEM/mail/lib/mail/encodings/8bit.rb:14` 339.4 | `app/services/create_casa_admin_service.rb:21` 4230.3, `app/services/create_casa_admin_service.rb:20` 1159.1, `config/initializers/sent_email_event.rb:7` 1141.6 |
| 27 | AllCasaAdmins::CasaOrgsController#show | 3 / 3 | 16107.5 / 16105.5 | -2.0 | 16316.3 | `GEM/prosopite/lib/prosopite.rb:286` 2635.5, `GEM/uri/lib/uri/rfc2396_parser.rb:291` 169.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 109.0 | `app/models/all_casa_admins/casa_org_metrics.rb:15` 583.5, `app/views/all_casa_admins/casa_orgs/show.html.erb:32` 431.5, `app/models/all_casa_admins/casa_org_metrics.rb:17` 423.5 |
| 28 | VolunteersController#update | 4 / 4 | 15906.3 / 15963.7 | 57.3 | 14173.3 | `GEM/prosopite/lib/prosopite.rb:286` 3394.7, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 247.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` 230.3 | `app/validators/user_validator.rb:56` 1292.7, `app/controllers/volunteers_controller.rb:78` 740.3, `app/models/concerns/api.rb:11` 691.0 |
| 29 | MileageRatesController#create | 3 / 3 | 15826.0 / 15916.5 | 90.5 | 12094.3 | `GEM/prosopite/lib/prosopite.rb:286` 1075.0, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 463.0, `GEM/uri/lib/uri/rfc2396_parser.rb:291` 164.0 | `app/controllers/mileage_rates_controller.rb:21` 1048.5, `app/views/layouts/casa_app.html.erb:20` 528.0, `app/controllers/application_controller.rb:41` 465.0 |
| 30 | PlacementsController#index | 3 / 3 | 15669.0 / 15757.5 | 88.5 | 15678.7 | `GEM/prosopite/lib/prosopite.rb:286` 1786.0, `GEM/uri/lib/uri/rfc2396_parser.rb:291` 164.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 112.0 | `app/views/placements/index.html.erb:36` 630.0, `app/views/placements/index.html.erb:24` 535.5, `app/views/layouts/casa_app.html.erb:20` 518.0 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/prosopite/lib/prosopite.rb:286` | `subscribe` | 1600.74 / 1600.74 | 0.0 | 1604.58 | 94% | Data, Array |  | `app/controllers/application_controller.rb:41` 10%, `no app frame` 5% | `query_caller = caller_locations` |
| 2 | `GEM/nokogiri/lib/nokogiri/xml/xpath_context.rb:10` | `register_namespaces` | 622.37 / 622.37 | 0.0 | 624.13 | 3% | String, MatchData |  | `app/models/case_court_report.rb:18` 99%, `app/controllers/emancipations_controller.rb:31` 1% | `key = key.to_s.gsub(/.*:/, "") # strip off 'xmlns:' or 'xml:'` |
| 3 | `GEM/nokogiri/lib/nokogiri/xml/node.rb:1255` | `namespaces` | 604.86 / 604.92 | 0.06 | 606.63 | 3% | String |  | `app/models/case_court_report.rb:18` 99%, `app/controllers/emancipations_controller.rb:31` 1% | `hash[key] = ns.href` |
| 4 | `GEM/nokogiri/lib/nokogiri/xml/node.rb:1253` | `namespaces` | 604.41 / 604.41 | 0.0 | 606.12 | 3% | String, Data |  | `app/models/case_court_report.rb:18` 99%, `app/controllers/emancipations_controller.rb:31` 1% | `prefix = ns.prefix` |
| 5 | `GEM/nokogiri/lib/nokogiri/xml/node.rb:1254` | `namespaces` | 604.41 / 604.41 | 0.0 | 606.11 | 3% | String |  | `app/models/case_court_report.rb:18` 99%, `app/controllers/emancipations_controller.rb:31` 1% | `key = prefix ? "xmlns:#{prefix}" : "xmlns"` |
| 6 | `GEM/sablon/lib/sablon/parser/mail_merge.rb:137` | `parse_fields` | 182.37 / 182.37 | 0.0 | 182.6 | 3% | String |  | `app/models/case_court_report.rb:18` 100%, `app/controllers/emancipations_controller.rb:31` 0% | `elsif node.name == "fldChar" && node["w:fldCharType"] == "begin"` |
| 7 | `GEM/sablon/lib/sablon/parser/mail_merge.rb:135` | `parse_fields` | 179.62 / 179.62 | 0.0 | 179.84 | 3% | String |  | `app/models/case_court_report.rb:18` 100%, `app/controllers/emancipations_controller.rb:31` 0% | `if node.name == "fldSimple"` |
| 8 | `GEM/nokogiri/lib/nokogiri/xml/node.rb:1369` | `traverse` | 175.12 / 175.12 | 0.0 | 175.33 | 3% | Data |  | `app/models/case_court_report.rb:18` 100%, `app/controllers/emancipations_controller.rb:31` 0% | `children.each { \|j\| j.traverse(&block) }` |
| 9 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` | `cast_result` | 83.28 / 83.28 | 0.0 | 83.35 | 96% | String, Array | #59278 merged 2026-10-22, after this app's version, not released yet | `app/validators/user_validator.rb:56` 12%, `app/controllers/application_controller.rb:41` 7% | `ar_result = if result.fields.empty?` |
| 10 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql_adapter.rb:880` | `get_oid_type` | 75.65 / 75.65 | 0.0 | 75.87 | 96% | Array |  | `app/validators/user_validator.rb:56` 12%, `app/controllers/application_controller.rb:41` 7% | `type_map.fetch(oid, fmod, sql_type) {` |
| 11 | `RAILS/activemodel/lib/active_model/attribute.rb:9` | `from_database` | 72.9 / 72.9 | 0.0 | 73.15 | 94% | Object |  | `no app frame` 70%, `app/controllers/case_contacts/form_controller.rb:84` 3% | `FromDatabase.new(name, value_before_type_cast, type, nil, value)` |
| 12 | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:101` † | `helper_names` | 70.0 / 70.0 | 0.0 | 70.53 | 14% | String, Array |  | `no app frame` 97%, `app/controllers/supervisors_controller.rb:76` 1% | `@path_helpers.map(&:to_s) + @url_helpers.map(&:to_s)` |
| 13 | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:61` | `search` | 69.99 / 69.99 | 0.0 | 70.2 | 3% | Array |  | `app/models/case_court_report.rb:18` 99%, `app/controllers/emancipations_controller.rb:31` 1% | `xpath(*(xpaths + [ns, handler, binds].compact))` |
| 14 | `RAILS/activerecord/lib/arel/table.rb:85` | `[]` | 66.37 / 66.37 | 0.0 | 66.58 | 96% | Struct |  | `no app frame` 41%, `app/controllers/application_controller.rb:41` 3% | `Attribute.new(table, name)` |
| 15 | `GEM/bugsnag/lib/bugsnag/integrations/railtie.rb:28` | `event_subscription` | 64.43 / 64.43 | 0.0 | 64.53 | 96% | String, Hash |  | `no app frame` 51%, `app/controllers/application_controller.rb:41` 4% | `binds = data[:binds].each_with_object({}) { \|bind, output\| output[bind` |
| 16 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` | `build_handle` | 60.47 / 60.47 | 0.0 | 60.63 | 100% | Object, Data | #59613 merged 2026-11-04, after this app's version, not released yet, #59235 merged 2026-10-21, after this app's version, not released yet | `no app frame` 34%, `app/views/layouts/casa_app.html.erb:76` 7% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 17 | `RAILS/activerecord/lib/arel/visitors/postgresql.rb:136` | `visit_Arel_Nodes_IsDistinctFrom` | 57.89 / 57.89 | 0.0 | 57.97 | 96% | String |  | `no app frame` 65%, `app/controllers/application_controller.rb:41` 4% | `BIND_BLOCK = proc { \|i\| "$#{i}" }` |
| 18 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` | `tag_option` | 46.56 / 46.56 | 0.0 | 46.8 | 30% | String |  | `app/views/layouts/_nav_link.html.erb:7` 10%, `app/views/shared/_favicons.html.erb:6` 2% | `%(#{key}="#{value}")` |
| 19 | `GEM/uri/lib/uri/rfc2396_parser.rb:291` | `escape` | 43.47 / 43.47 | 0.0 | 43.64 | 27% | String |  | `app/views/shared/_favicons.html.erb:12` 7%, `app/views/shared/_favicons.html.erb:14` 7% | `str.gsub(unsafe) do` |
| 20 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` | `within_new_transaction` | 41.99 / 41.99 | 0.0 | 42.45 | 9% | String, Array |  | `app/controllers/case_assignments_controller.rb:17` 9%, `no app frame` 7% | `raise` |
| 21 | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:270` | `xpath_impl` | 40.55 / 40.55 | 0.0 | 40.56 | 10% | Data, Array |  | `app/models/case_court_report.rb:18` 97%, `config/initializers/field_error_proc.rb:16` 1% | `context.evaluate(path, handler)` |
| 22 | `GEM/nokogiri/lib/nokogiri/xml/node.rb:1252` | `namespaces` | 40.24 / 40.24 | 0.0 | 40.28 | 9% | Array, Hash |  | `app/models/case_court_report.rb:18` 98%, `config/initializers/field_error_proc.rb:16` 1% | `namespace_scopes.each_with_object({}) do \|ns, hash\|` |
| 23 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` | `call` | 39.52 / 39.52 | 0.0 | 39.54 | 100% | Data |  | `no app frame` 63%, `app/controllers/case_contacts/form_controller.rb:84` 3% | `result_lambda = -> { user_callback.call target, value }` |
| 24 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:176` | `cast_result` | 39.39 / 39.39 | 0.0 | 39.43 | 96% | Array, String |  | `no app frame` 11%, `config/initializers/sent_email_event.rb:7` 6% | `ActiveRecord::Result.new(fields, result.values, types.freeze, affected` |
| 25 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:151` † | `now` | 37.36 / 37.36 | 0.0 | 37.47 | 88% | Data |  | `no app frame` 30%, `app/views/layouts/casa_app.html.erb:76` 11% | `Time.now` |
| 26 | `RAILS/activesupport/lib/active_support/callbacks.rb:362` | `make_lambda` | 36.88 / 36.88 | 0.0 | 36.9 | 92% | Array |  | `no app frame` 65%, `app/models/user.rb:172` 3% | `target.send(@method_name, &block)` |
| 27 | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:216` | `extract_params` | 35.97 / 35.97 | 0.0 | 35.97 | 10% | Array |  | `app/models/case_court_report.rb:18` 98%, `app/controllers/emancipations_controller.rb:31` 1% | `hashes = []` |
| 28 | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:221` | `extract_params` | 35.97 / 35.97 | 0.0 | 35.97 | 10% | Array |  | `app/models/case_court_report.rb:18` 98%, `app/controllers/emancipations_controller.rb:31` 1% | `ns, binds = hashes.reverse` |
| 29 | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:225` | `extract_params` | 35.97 / 35.97 | 0.0 | 35.97 | 10% | Array |  | `app/models/case_court_report.rb:18` 98%, `app/controllers/emancipations_controller.rb:31` 1% | `[params, handler, ns, binds]` |
| 30 | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:57` | `search` | 34.99 / 34.99 | 0.0 | 35.1 | 3% | Array |  | `app/models/case_court_report.rb:18` 99%, `app/controllers/emancipations_controller.rb:31` 1% | `xpaths = paths.map(&:to_s).map do \|path\|` |

## Dev/test-mode work

3745.6 of 13631.5 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | reload check | `RAILS/activesupport/lib/active_support/file_update_checker.rb:135` | 783.2 | 100% | `no app frame` 100% | `mtime = File.mtime(path)` |
| 2 | reload check | `RAILS/activesupport/lib/active_support/file_update_checker.rb:109` † | 442.55 | 100% | `no app frame` 100% | `all.concat(Dir[*@globs]) if @globs` |
| 3 | asset lookup | `GEM/sprockets/lib/sprockets/path_utils.rb:234` | 284.37 | 27% | `app/views/shared/_favicons.html.erb:12` 7%, `app/views/shared/_favicons.html.erb:4` 7% | `next unless File.basename(entry).start_with?(basename)` |
| 4 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` | 154.81 | 96% | `no app frame` 53%, `app/controllers/application_controller.rb:41` 4% | `binds = binds.inspect` |
| 5 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:177` | 89.01 | 96% | `no app frame` 38%, `app/controllers/application_controller.rb:41` 5% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 6 | asset lookup | `GEM/sprockets/lib/sprockets/uri_tar.rb:18` | 61.84 | 27% | `app/views/layouts/casa_app.html.erb:16` 6%, `app/views/layouts/casa_app.html.erb:15` 6% | `@scheme, _, @path = uri.partition("://".freeze)` |
| 7 | asset lookup | `GEM/sprockets/lib/sprockets/resolve.rb:218` | 61.4 | 27% | `app/views/shared/_favicons.html.erb:11` 7%, `app/views/shared/_favicons.html.erb:12` 7% | `dirname    = File.dirname(File.join(load_path, logical_name))` |
| 8 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:175` | 59.46 | 96% | `no app frame` 38%, `app/controllers/application_controller.rb:41` 5% | `modes = MODES.values_at(*options.compact_blank.keys)` |
| 9 | asset lookup | `GEM/sprockets/lib/sprockets/encoding_utils.rb:51` † | 56.6 | 27% | `app/views/shared/_favicons.html.erb:2` 6%, `app/views/shared/_favicons.html.erb:4` 6% | `Marshal.load(marshaled)` |
| 10 | asset lookup | `GEM/sprockets/lib/sprockets/digest_utils.rb:88` | 51.09 | 27% | `app/views/shared/_favicons.html.erb:10` 6%, `app/views/shared/_favicons.html.erb:2` 6% | `build_digest(obj).digest` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| gem: nokogiri | 3031.9 | 3050.1 | `xpath_context.rb:10` 622.4, `node.rb:1255` 604.9, `node.rb:1253` 604.4 |
| rails: activesupport | 2386.2 | 2416.2 | `file_update_checker.rb:135` 783.2, `file_update_checker.rb:109` 442.5, `log_subscriber.rb:177` 89.0 |
| rails: activerecord | 2010.6 | 2027.5 | `log_subscriber.rb:49` 154.8, `database_statements.rb:165` 83.3, `postgresql_adapter.rb:880` 75.7 |
| gem: sprockets | 1719.1 | 1726.1 | `path_utils.rb:234` 284.4, `uri_tar.rb:18` 61.8, `resolve.rb:218` 61.4 |
| gem: prosopite | 1641.8 | 1645.7 | `prosopite.rb:286` 1600.7, `prosopite.rb:285` 29.7, `prosopite.rb:288` 6.0 |
| gem: sablon | 483.4 | 485.4 | `mail_merge.rb:137` 182.4, `mail_merge.rb:135` 179.6, `mail_merge.rb:17` 31.4 |
| rails: actionview | 387.9 | 398.2 | `tag_helper.rb:309` 46.6, `tag_helper.rb:237` 17.1, `tag_helper.rb:232` 12.5 |
| rails: actionpack | 377.7 | 424.5 | `route_set.rb:101` 70.0, `visitors.rb:40` 11.0, `request.rb:66` 10.9 |
| rails: activemodel | 269.7 | 276.3 | `attribute.rb:9` 72.9, `attribute.rb:13` 25.5, `string.rb:39` 20.5 |
| gem: bugsnag | 209.9 | 210.4 | `railtie.rb:28` 64.4, `railtie.rb:29` 25.4, `circular_buffer.rb:59` 23.8 |
| gem: mail | 205.7 | 211.1 | `utilities.rb:215` 22.9, `8bit.rb:14` 22.6, `field_list.rb:71` 11.1 |
| ruby default gem: uri | 167.8 | 168.5 | `rfc2396_parser.rb:291` 43.5, `rfc3986_parser.rb:85` 19.5, `common.rb:456` 19.4 |
| app | 148.3 | 168.7 | `_nav_link.html.erb:7` 7.1, `_nav_link.html.erb:1` 4.6, `casa_app.html.erb:76` 4.3 |
| ruby stdlib | 79.7 | 353.7 | `fileutils.rb:2461` 17.1, `formatter.rb:174` 14.1, `ipaddr.rb:725` 9.2 |
| gem: rack | 76.0 | 76.9 | `utils.rb:693` 10.5, `request.rb:693` 7.2, `body_proxy.rb:12` 6.0 |
| gem: tzinfo | 62.2 | 63.3 | `timestamp.rb:208` 24.0, `constant_offset_data_timezone_info.rb:52` 14.7, `timestamp.rb:193` 14.6 |
| gem: i18n | 54.9 | 55.2 | `base.rb:157` 7.8, `i18n.rb:396` 7.5, `utils.rb:8` 5.7 |
| gem: rubyzip | 52.9 | 54.1 | `extra_field.rb:59` 6.6, `extra_field.rb:72` 5.1, `inflater.rb:36` 2.8 |
| gem: logger | 51.7 | 51.8 | `log_device.rb:165` 17.1, `log_device.rb:33` 17.1, `logger.rb:692` 15.3 |
| gem: warden | 44.9 | 44.9 | `proxy.rb:334` 6.4, `proxy.rb:348` 4.6, `proxy.rb:218` 3.6 |
| gem: erubi | 36.3 | 37.6 | `erubi.rb:134` 20.1, `erubi.rb:137` 4.6, `erubi.rb:139` 2.6 |
| gem: lograge | 32.4 | 32.4 | `key_value.rb:19` 13.1, `key_value.rb:27` 3.0, `base.rb:73` 2.0 |
| gem: concurrent-ruby | 29.7 | 30.7 | `safe_initialization.rb:30` 6.0, `non_concurrent_map_backend.rb:131` 5.1, `non_concurrent_map_backend.rb:26` 3.5 |
| test harness: rspec-mocks | 27.8 | 30.1 | `recorder.rb:135` 8.6, `message_chains.rb:7` 6.3, `recorder.rb:173` 1.6 |
| gem: devise | 27.6 | 28.1 | `orm.rb:43` 6.0, `helpers.rb:128` 2.7, `store_location.rb:68` 1.8 |
| gem: sprockets-rails | 26.3 | 29.4 | `helper.rb:81` 8.5, `helper.rb:357` 8.5, `helper.rb:356` 4.3 |
| gem: rails-controller-testing | 24.5 | 24.6 | `template_assertions.rb:39` 18.5, `template_assertions.rb:35` 4.8, `template_assertions.rb:27` 0.8 |
| gem: authtrail | 21.6 | 21.6 | `authtrail.rb:18` 16.2, `manager.rb:33` 0.9, `authtrail.rb:25` 0.9 |
| gem: flipper | 21.3 | 21.4 | `wrapper.rb:32` 3.0, `memoizable.rb:97` 3.0, `dsl.rb:239` 2.0 |
| gem: pretender | 14.8 | 14.9 | `pretender.rb:31` 14.8, `pretender.rb:55` 0.0 |
| gem: pundit | 12.0 | 12.0 | `context.rb:179` 2.4, `policy_finder.rb:108` 2.4, `context.rb:166` 2.4 |
| gem: friendly_id | 8.1 | 8.9 | `finder_methods.rb:36` 5.2, `finder_methods.rb:78` 0.6, `scoped.rb:164` 0.3 |
| test harness: webmock | 6.5 | 7.4 | `headers.rb:69` 1.4, `headers.rb:68` 1.1, `headers.rb:16` 0.5 |
| rails: railties | 6.2 | 6.4 | `engine.rb:748` 1.0, `finisher.rb:194` 1.0, `logger.rb:24` 1.0 |
| test harness: rspec-support | 4.5 | 4.6 | `caller_filter.rb:67` 1.4, `method_signature_verifier.rb:135` 0.5, `fuzzy_matcher.rb:35` 0.4 |
| gem: groupdate | 4.4 | 4.9 | `magic.rb:102` 1.1, `postgresql_adapter.rb:42` 0.3, `relation.rb:16` 0.3 |
| ruby default gem: securerandom | 4.4 | 4.4 | `securerandom.rb:71` 4.4 |
| gem: base64 | 4.1 | 4.1 | `base64.rb:283` 3.9, `base64.rb:310` 0.2 |
| gem: addressable | 3.7 | 4.5 | `uri.rb:486` 0.2, `uri.rb:1544` 0.2, `uri.rb:584` 0.2 |
| gem: draper | 3.2 | 3.3 | `decoratable.rb:80` 0.5, `view_context.rb:39` 0.5, `decoratable.rb:25` 0.4 |
| gem: json | 3.1 | 3.1 | `common.rb:1089` 3.1, `common.rb:1130` 0.0, `common.rb:1124` 0.0 |
| gem: rack-session | 3.0 | 3.0 | `id.rb:277` 1.0, `id.rb:275` 1.0, `id.rb:401` 1.0 |
| rails: actionmailer | 2.8 | 2.8 | `base.rb:1009` 0.4, `delivery_methods.rb:66` 0.3, `base.rb:953` 0.3 |
| gem: ostruct | 2.6 | 2.7 | `ostruct.rb:238` 0.7, `ostruct.rb:237` 0.7, `ostruct.rb:248` 0.5 |
| rails: activestorage | 2.5 | 2.8 | `disk_service.rb:196` 0.2, `disk_service.rb:131` 0.2, `service.rb:176` 0.1 |
| gem: amazing_print | 2.5 | 2.6 | `class.rb:19` 1.2, `class.rb:21` 0.9, `awesome_method_array.rb:19` 0.4 |
| gem: view_component | 2.3 | 4.8 | `base.rb:21` 0.6, `base.rb:139` 0.5, `base.rb:401` 0.4 |
| gem: csv | 2.0 | 3.7 | `row.rb:206` 0.1, `writer.rb:51` 0.1, `writer.rb:154` 0.1 |
| gem: rack-cors | 2.0 | 2.1 | `result.rb:38` 1.0, `cors.rb:129` 1.0, `cors.rb:123` 0.0 |
| gem: request_store | 2.0 | 2.0 | `middleware.rb:28` 1.0, `middleware.rb:21` 1.0, `request_store.rb:15` 0.0 |
| gem: bcrypt | 1.9 | 2.0 | `password.rb:102` 0.5, `engine.rb:90` 0.3, `password.rb:103` 0.3 |
| gem: faraday | 1.1 | 3.5 | `utils.rb:32` 0.3, `utils.rb:31` 0.2, `utils.rb:33` 0.0 |
| gem: httparty | 1.1 | 1.3 | `httparty.rb:644` 0.3, `httparty.rb:640` 0.1, `httparty.rb:639` 0.1 |
| gem: turbo-rails | 1.0 | 1.0 | `request_id_tracking.rb:10` 1.0, `frames_helper.rb:45` 0.0, `frames_helper.rb:42` 0.0 |
| ruby default gem: net-http | 0.9 | 1.0 | `header.rb:205` 0.2, `header.rb:195` 0.1, `header.rb:468` 0.1 |
| gem: globalid | 0.9 | 1.2 | `gid.rb:95` 0.2, `gid.rb:159` 0.2, `gid.rb:166` 0.1 |
| rails: actiontext | 0.7 | 1.0 | `fragment.rb:38` 0.1, `html_conversion.rb:23` 0.1, `plain_text_conversion.rb:134` 0.0 |
| gem: paranoia | 0.7 | 0.8 | `paranoia.rb:329` 0.7, `paranoia.rb:34` 0.0, `paranoia.rb:25` 0.0 |
| gem: noticed | 0.5 | 1.2 | `readable.rb:7` 0.4, `deliver_by.rb:12` 0.0, `notification.rb:10` 0.0 |
| gem: twilio-ruby | 0.5 | 124.7 | `version.rb:46` 0.0, `domain.rb:16` 0.0, `http_client.rb:38` 0.0 |
| rails: activejob | 0.4 | 0.5 | `log_subscriber.rb:207` 0.1, `arguments.rb:141` 0.0, `arguments.rb:192` 0.0 |
| gem: pagy | 0.3 | 0.3 | `shared_methods.rb:12` 0.1, `backend.rb:16` 0.1, `shared_methods.rb:23` 0.0 |
| gem: orm_adapter | 0.3 | 0.3 | `base.rb:105` 0.1, `base.rb:100` 0.1, `active_record.rb:54` 0.1 |
| gem: loofah | 0.3 | 4.2 | `concerns.rb:172` 0.1, `concerns.rb:43` 0.1, `scrubber.rb:132` 0.0 |
| gem: zeitwerk | 0.2 | 0.3 | `cref.rb:47` 0.0, `cref.rb:36` 0.0, `file_system.rb:199` 0.0 |
| gem: marcel | 0.2 | 0.3 | `magic.rb:18` 0.1, `mime_type.rb:90` 0.0, `magic.rb:75` 0.0 |
| gem: wicked | 0.2 | 0.2 | `steps.rb:56` 0.1, `wizard.rb:63` 0.1, `wizard.rb:64` 0.1 |
| gem: filterrific | 0.2 | 0.3 | `param_set.rb:117` 0.1, `action_controller_extension.rb:56` 0.0, `action_controller_extension.rb:69` 0.0 |
| gem: devise_invitable | 0.2 | 0.2 | `models.rb:162` 0.0, `models.rb:211` 0.0, `models.rb:139` 0.0 |
| gem: responders | 0.1 | 0.2 | `respond_with.rb:248` 0.0, `responder.rb:243` 0.0, `respond_with.rb:208` 0.0 |
| gem: rails-html-sanitizer | 0.1 | 1.9 | `sanitizer.rb:33` 0.0, `sanitizer.rb:191` 0.0, `sanitizer.rb:56` 0.0 |
| gem: pg | 0.1 | 0.1 | `date.rb:14` 0.1, `date.rb:13` 0.0, `result.rb:17` 0.0 |
| lowrail-profile | 0.1 | 0.1 | `profile.rb:107` 0.1, `profile.rb:66` 0.0, `profile.rb:117` 0.0 |
| test harness: rspec-expectations | 0.0 | 0.1 | `match.rb:54` 0.0, `composable.rb:46` 0.0, `aliased_matcher.rb:25` 0.0 |
| gem: scout_apm | 0.0 | 0.1 | `config.rb:463` 0.0, `agent.rb:20` 0.0, `agent.rb:64` 0.0 |
| gem: faraday-net_http | 0.0 | 0.2 | `net_http.rb:81` 0.0, `net_http.rb:80` 0.0, `net_http.rb:137` 0.0 |
| gem: bigdecimal | 0.0 | 0.0 | `util.rb:73` 0.0 |
| gem: racc | 0.0 | 0.1 | `parser.rb:263` 0.0 |
| gem: flipper-ui | 0.0 | 0.0 | `ui.rb:49` 0.0 |
| gem: jbuilder | 0.0 | 0.1 | `jbuilder_dependency_tracker.rb:0` 0.0, `jbuilder_dependency_tracker.rb:4` 0.0, `jbuilder_dependency_tracker.rb:42` 0.0 |
| other | 0.0 | 0.0 | `(erb):1` 0.0 |
| gem: caxlsx_rails | 0.0 | 0.0 | `railtie.rb:9` 0.0, `template_handler.rb:12` 0.0 |
| ruby default gem: pp | 0.0 | 0.1 | `pp.rb:97` 0.0, `pp.rb:542` 0.0, `pp.rb:271` 0.0 |
| gem: pdf-forms | 0.0 | 0.0 | `pdf_forms.rb:16` 0.0, `pdftk_wrapper.rb:184` 0.0, `pdftk_wrapper.rb:31` 0.0 |
| rails: actioncable | 0.0 | 0.0 | `action_cable_helper.rb:0` 0.0, `engine.rb:21` 0.0, `action_cable_helper.rb:7` 0.0 |
| ruby default gem: prettyprint | 0.0 | 0.2 | `prettyprint.rb:96` 0.0, `prettyprint.rb:94` 0.0, `prettyprint.rb:95` 0.0 |
| ruby default gem: erb | 0.0 | 0.1 | `erb.rb:893` 0.0, `erb.rb:1026` 0.0, `compiler.rb:323` 0.0 |
| ruby default gem: prism | 0.0 | 175.3 | `node.rb:6022` 0.0, `node.rb:16011` 0.0, `node.rb:15096` 0.0 |
| gem: htmlentities | 0.0 | 0.1 | `htmlentities.rb:33` 0.0, `encoder.rb:95` 0.0, `encoder.rb:90` 0.0 |
| gem: cliver | 0.0 | 0.0 | `detector.rb:13` 0.0, `dependency.rb:52` 0.0, `detector.rb:36` 0.0 |
| gem: blueprinter | 0.0 | 0.7 | `base.rb:371` 0.0, `configuration.rb:47` 0.0, `reflection.rb:9` 0.0 |
| gem: caxlsx | 0.0 | 6.9 | `page_margins.rb:60` 0.0, `sheet_pr.rb:6` 0.0, `styles.rb:550` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Mails

| # | Mailer action | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | Devise::Mailer#invitation_instructions | 17 / 17 | 3329.9 / 3328.1 | -1.8 | 3329.7 | `GEM/prosopite/lib/prosopite.rb:286` 449.4, `GEM/mail/lib/mail/utilities.rb:215` 171.0, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 122.3 | `config/initializers/sent_email_event.rb:7` 1163.1, `app/lib/importers/file_importer.rb:50` 604.8, `app/views/devise/mailer/invitation_instructions.html.erb:8` 83.1 |
| 2 | Devise::Mailer.deliver_mail | 21 / 21 | 2205.6 / 2204.1 | -1.5 | 2217.2 | `GEM/mail/lib/mail/encodings/8bit.rb:14` 360.8, `GEM/mail/lib/mail/utilities.rb:215` 265.2, `GEM/mail/lib/mail/field_list.rb:71` 131.4 | `app/lib/importers/file_importer.rb:50` 740.0, `app/models/user.rb:185` 213.8 |
| 3 | Devise::Mailer#email_changed | 4 / 4 | 2106.7 / 2106.7 | 0.0 | 2167.3 | `GEM/prosopite/lib/prosopite.rb:286` 430.0, `GEM/mail/lib/mail/parsers/address_lists_parser.rb:32009` 62.7, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:165` 57.0 | `config/initializers/sent_email_event.rb:7` 1151.0, `app/models/user.rb:185` 647.7, `app/models/concerns/roles.rb:5` 27.0 |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/prosopite/lib/prosopite.rb:286` | 212.14 / 212.14 | 50% | `config/initializers/sent_email_event.rb:7` 100% | `query_caller = caller_locations` |
| 2 | `GEM/mail/lib/mail/utilities.rb:215` | 202.38 / 202.38 | 100% | `no app frame` 61%, `app/lib/importers/file_importer.rb:50` 33% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 3 | `GEM/mail/lib/mail/encodings/8bit.rb:14` | 171.81 / 171.81 | 50% | `no app frame` 57%, `app/lib/importers/file_importer.rb:50` 31% | `!str.lines.find { \|line\| line.bytesize > 998 }` |
| 4 | `GEM/mail/lib/mail/fields/parameter_hash.rb:22` | 103.43 / 103.33 | 91% | `no app frame` 64%, `app/lib/importers/file_importer.rb:50` 35% | `if k =~ /^#{key_pattern}(\*\|$)/i` |
| 5 | `GEM/mail/lib/mail/field_list.rb:71` | 99.69 / 99.69 | 100% | `no app frame` 62%, `app/lib/importers/file_importer.rb:50` 34% | `fields = select { \|f\| f.responsible_for? field_name }` |
| 6 | `GEM/mail/lib/mail/utilities.rb:291` | 51.33 / 51.33 | 100% | `no app frame` 56%, `app/lib/importers/file_importer.rb:50` 31% | `value !~ /\S/` |
| 7 | `GEM/mail/lib/mail/utilities.rb:226` | 49.71 / 49.71 | 91% | `no app frame` 62%, `app/lib/importers/file_importer.rb:50` 34% | `str.to_s.downcase.tr(Constants::HYPHEN, Constants::UNDERSCORE)` |
| 8 | `GEM/mail/lib/mail/parsers/content_type_parser.rb:734` | 43.33 / 42.79 | 50% | `no app frame` 63%, `app/lib/importers/file_importer.rb:50` 33% | `_wide = data[p].ord` |
| 9 | `GEM/mail/lib/mail/parsers/content_transfer_encoding_parser.rb:380` | 34.29 / 34.29 | 50% | `no app frame` 63%, `app/lib/importers/file_importer.rb:50` 35% | `_wide = data[p].ord` |
| 10 | `GEM/mail/lib/mail/parser_tools.rb:7` | 31.02 / 31.02 | 100% | `no app frame` 57%, `app/lib/importers/file_importer.rb:50` 31% | `data.slice(from_bytes..to_bytes).force_encoding(Encoding::UTF_8)` |
