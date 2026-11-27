# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bundle exec rspec spec/requests --seed 1234 --format documentation`
* Ruby: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux]
* Rails: 8.2.0.alpha, test environment
* Counted in run 1: 975 requests, 42 mail windows; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1
* Not attributed: 0.0 objects per request (0.0% of all) are on lines outside the app, Rails, Ruby and the bundle's gems, which no table below ranks; most in `(erb)`

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 975 | 15194.4 | 0 | 42 | 0 | 0 |
| run2 | 1 | 975 | 15193.6 | 0 | 42 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.03 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/models/case_court_report.rb:18` | `generate_to_string` | 3542.17 | 0.0 | 0.0 | `GEM/nokogiri/lib/nokogiri/xml/xpath_context.rb:10` 18%, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1257` 17%, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1255` 17% | CaseCourtReportsController#generate 91%, CourtDatesController#show 9% | `@template.render_to_string(@context)` |
| 2 | `app/controllers/application_controller.rb:41` | `set_active_banner` | 210.57 | 26.94 | 0.0 | `GEM/prosopite/lib/prosopite.rb:286` 62%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:22` 2%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:228` 2% | CaseContacts::FormController#update 7%, EmancipationsController#save 6%, CaseAssignmentsController#create 3% | `@active_banner = current_organization.banners.active.first` |
| 3 | `app/services/twilio_service.rb:15` | `client` | 141.09 | 0.02 | 0.01 | `RUBY/bundled_gems.rb:60` 3%, `RUBY/bundled_gems.rb:111` 3%, `RUBY/bundled_gems.rb:98` 2% | SupervisorsController#create 100%, CasaAdminsController#create 0%, VolunteersController#create 0% | `@client = Twilio::REST::Client.new(@api_key, @api_secret, @acc_sid)` |
| 4 | `app/models/contact_type_group.rb:35` | `generate_for_org!` | 95.62 | 18.68 | 0.0 | `GEM/prosopite/lib/prosopite.rb:286` 56%, `GEM/bugsnag/lib/bugsnag/integrations/railtie.rb:28` 2%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:379` 1% | AllCasaAdmins::CasaOrgsController#create 100% | `ContactType.find_or_create_by!(` |
| 5 | `app/validators/user_validator.rb:56` | `validate_uniqueness` | 90.41 | 18.67 | 0.63 | `GEM/prosopite/lib/prosopite.rb:286` 64%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:228` 8%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:256` 2% | SupervisorsController#update 8%, UsersController#update_email 8%, CaseContactReportsController#index 7% | `existing_record = record.class.find_by(attribute => record[attribute])` |
| 6 | `config/initializers/sent_email_event.rb:7` |  | 80.3 | 17.21 | 0.07 | `GEM/prosopite/lib/prosopite.rb:286` 50%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:228` 5%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:256` 3% | UsersController#update_email 13%, ImportsController#create 12%, VolunteersController#reminder 9% | `SentEmail.create(` |
| 7 | `app/views/layouts/casa_app.html.erb:20` |  | 74.56 | 7.81 | 0.16 | `GEM/prosopite/lib/prosopite.rb:286` 59%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:228` 2%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:22` 2% | CasaCasesController#index 7%, CaseContacts::CaseContactsNewDesignController#index 6%, UsersController#update_password 5% | `<% role_badge_class = {"Volunteer" => "bg-sky-50 text-sky-700", "Super` |
| 8 | `app/controllers/case_contacts/form_controller.rb:84` | `update` | 73.86 | 10.98 | 0.0 | `GEM/prosopite/lib/prosopite.rb:286` 41%, `RAILS/activemodel/lib/active_model/attribute.rb:10` 2%, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:677` 2% | CaseContacts::FormController#update 100% | `if @case_contact.update(case_contact_params)` |
| 9 | `app/models/concerns/api.rb:11` | `initialize_api_credentials` | 68.17 | 11.9 | 0.11 | `GEM/prosopite/lib/prosopite.rb:286` 46%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:228` 2%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:22` 2% | ImportsController#create 15%, CaseContactReportsController#index 12%, CasaAdminsController#create 7% | `create_api_credential unless api_credential` |
| 10 | `app/controllers/case_contacts/form_controller.rb:113` | `set_case_contact` | 67.66 | 6.85 | 0.05 | `GEM/prosopite/lib/prosopite.rb:286` 58%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:228` 5%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:256` 2% | CaseContacts::FormController#update 92%, CaseContacts::FormController#show 8% | `.find(params[:case_contact_id])` |
| 11 | `app/views/layouts/casa_app.html.erb:60` |  | 64.26 | 7.65 | 0.49 | `GEM/prosopite/lib/prosopite.rb:286` 69%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:22` 2%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:228` 2% | CasaCasesController#index 7%, CaseContacts::CaseContactsNewDesignController#index 6%, UsersController#update_password 5% | `[custom_link.text, "bi-link-45deg", custom_link.url, nil, true, true]` |
| 12 | `app/models/user.rb:93` | `create_preference_set` | 63.52 | 11.9 | 0.0 | `GEM/prosopite/lib/prosopite.rb:286` 49%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:22` 2%, `GEM/bugsnag/lib/bugsnag/integrations/railtie.rb:28` 2% | ImportsController#create 15%, CaseContactReportsController#index 12%, CasaAdminsController#create 7% | `self.preference_set = PreferenceSet.create` |
| 13 | `app/views/layouts/casa_app.html.erb:76` |  | 56.15 | 46.56 | 3.22 | `GEM/rails-controller-testing/lib/rails/controller/testing/template_assertions.rb:39` 11%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:379` 9%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:381` 6% | CaseContacts::CaseContactsNewDesignController#index 6%, CasaCasesController#index 6%, UsersController#update_password 5% | `<% end %>` |
| 14 | `app/services/create_casa_admin_service.rb:21` | `create!` | 44.1 | 4.23 | 0.0 | `GEM/mail/lib/mail/utilities.rb:215` 10%, `GEM/mail/lib/mail/encodings/8bit.rb:14` 8%, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 5% | CasaAdminsController#create 67%, AllCasaAdmins::CasaAdminsController#create 33% | `@casa_admin.invite!(@current_user)` |
| 15 | `app/policies/application_policy.rb:58` | `same_org?` | 43.46 | 5.52 | 0.0 | `GEM/prosopite/lib/prosopite.rb:286` 64%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:228` 5%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:256` 4% | EmancipationsController#save 28%, VolunteersController#reminder 8%, SupervisorsController#edit 6% | `user&.casa_org.present? && user.casa_org == record&.casa_org` |
| 16 | `app/lib/importers/file_importer.rb:50` | `create_user_record` | 39.62 | 3.56 | 0.0 | `GEM/mail/lib/mail/utilities.rb:215` 10%, `GEM/mail/lib/mail/encodings/8bit.rb:14` 8%, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 5% | ImportsController#create 100% | `user.invite!` |
| 17 | `app/views/case_contacts/case_contacts_new_design/index.html.erb:127` |  | 37.1 | 1.98 | 0.0 | `GEM/prosopite/lib/prosopite.rb:286` 21%, `RAILS/activerecord/lib/arel/alias_predication.rb:8` 8%, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:190` 6% | CaseContacts::CaseContactsNewDesignController#index 100% | `<% answers = contact.contact_topic_answers.reject { \|a\| a.value.blank?` |
| 18 | `app/models/casa_case.rb:206` | `update_cleaning_contact_types` | 34.35 | 5.76 | 0.0 | `GEM/prosopite/lib/prosopite.rb:286` 39%, `RAILS/activesupport/lib/active_support/callbacks.rb:399` 2%, `RAILS/activemodel/lib/active_model/attribute.rb:10` 1% | CasaCasesController#update 100% | `update!(args)` |
| 19 | `app/controllers/casa_cases_controller.rb:64` | `create` | 33.84 | 5.64 | 0.0 | `GEM/prosopite/lib/prosopite.rb:286` 48%, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:677` 7%, `RAILS/activesupport/lib/active_support/callbacks.rb:399` 1% | CasaCasesController#create 100% | `if @casa_case.save` |
| 20 | `app/services/case_contacts_export_csv_service.rb:19` | `perform` | 33.07 | 3.35 | 0.0 | `GEM/prosopite/lib/prosopite.rb:286` 50%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:256` 3%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:228` 3% | CaseContactReportsController#index 97%, CasaCasesController#show 3% | `if case_contacts.present?` |
| 21 | `app/models/contact_type_group.rb:29` | `generate_for_org!` | 30.41 | 5.94 | 0.0 | `GEM/prosopite/lib/prosopite.rb:286` 55%, `GEM/bugsnag/lib/bugsnag/integrations/railtie.rb:28` 2%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:379` 1% | AllCasaAdmins::CasaOrgsController#create 100% | `group = ContactTypeGroup.find_or_create_by!(` |
| 22 | `app/controllers/case_court_reports_controller.rb:117` | `save_report` | 30.28 | 4.08 | 0.02 | `GEM/prosopite/lib/prosopite.rb:286` 28%, `GEM/marcel/lib/marcel/magic/zip.rb:194` 3%, `GEM/marcel/lib/marcel/magic/zip.rb:180` 2% | CaseCourtReportsController#generate 100% | `casa_case.court_reports.attach(` |
| 23 | `app/controllers/case_contacts/form_controller.rb:230` | `create_additional_case_contacts` | 29.37 | 4.75 | 0.0 | `GEM/prosopite/lib/prosopite.rb:286` 56%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:228` 2%, `GEM/bugsnag/lib/bugsnag/integrations/railtie.rb:28` 2% | CaseContacts::FormController#update 100% | `new_case_contact.save!` |
| 24 | `app/models/hearing_type.rb:23` | `generate_for_org!` | 25.13 | 5.07 | 0.0 | `GEM/prosopite/lib/prosopite.rb:286` 57%, `GEM/bugsnag/lib/bugsnag/integrations/railtie.rb:28` 2%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:379` 1% | AllCasaAdmins::CasaOrgsController#create 100% | `HearingType.find_or_create_by!(` |
| 25 | `app/models/case_court_report_context.rb:42` | `case_contacts` | 25.07 | 1.23 | 0.02 | `GEM/prosopite/lib/prosopite.rb:286` 25%, `RAILS/activerecord/lib/arel/table.rb:105` 7%, `RAILS/activerecord/lib/arel/nodes/select_statement.rb:11` 3% | CaseCourtReportsController#generate 66%, CourtDatesController#show 34% | `return [] unless interviewees.size.positive?` |
| 26 | `app/controllers/casa_cases_controller.rb:219` | `set_casa_case` | 24.68 | 2.51 | 0.1 | `GEM/prosopite/lib/prosopite.rb:286` 48%, `GEM/friendly_id/lib/friendly_id/finder_methods.rb:36` 15%, `RAILS/activerecord/lib/arel/table.rb:105` 3% | CasaCasesController#update 36%, CasaCasesController#deactivate 21%, CasaCasesController#show 18% | `@casa_case = current_organization.casa_cases.friendly.find(params[:id]` |
| 27 | `app/controllers/emancipations_controller.rb:31` | `show` | 22.12 | 0.12 | 0.01 | `GEM/nokogiri/lib/nokogiri/xml/xpath_context.rb:10` 16%, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1257` 16%, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1255` 15% | EmancipationsController#show 100% | `send_data((@template.render_to_string context, type: :docx), filename:` |
| 28 | `app/controllers/case_assignments_controller.rb:88` | `case_assignment_parent` | 21.61 | 3.46 | 0.07 | `GEM/prosopite/lib/prosopite.rb:286` 62%, `RAILS/activerecord/lib/arel/table.rb:105` 4%, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:228` 3% | CaseAssignmentsController#create 93%, CaseAssignmentsController#destroy 7% | `CasaCase.friendly.find(params[:casa_case_id])` |
| 29 | `app/controllers/users_controller.rb:125` | `update_user_email` | 20.95 | 2.5 | 0.02 | `GEM/prosopite/lib/prosopite.rb:286` 12%, `GEM/mail/lib/mail/encodings/8bit.rb:14` 10%, `GEM/mail/lib/mail/utilities.rb:215` 5% | UsersController#update_email 100% | `@user.update({email: email_params[:email]&.strip})` |
| 30 | `app/controllers/supervisors_controller.rb:39` | `create` | 19.69 | 1.89 | 0.0 | `GEM/mail/lib/mail/utilities.rb:215` 10%, `GEM/mail/lib/mail/encodings/8bit.rb:14` 8%, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 5% | SupervisorsController#create 100% | `@supervisor.invite!(current_user)` |

974.7 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | CaseCourtReportsController#generate | 22 / 22 | 161036.4 / 161041.4 | 5.0 | 153945.6 | `GEM/nokogiri/lib/nokogiri/xml/xpath_context.rb:10` 26354.5, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1257` 25610.0, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1255` 25597.1 | `app/models/case_court_report.rb:18` 149608.9, `app/controllers/case_court_reports_controller.rb:117` 1406.0, `app/models/case_court_report_context.rb:42` 768.3 |
| 2 | SupervisorsController#create | 5 / 5 | 52110.3 / 52107.5 | -2.8 | 46230.2 | `GEM/prosopite/lib/prosopite.rb:286` 3231.0, `RUBY/bundled_gems.rb:60` 1188.5, `RUBY/bundled_gems.rb:111` 1094.5 | `app/services/twilio_service.rb:15` 34383.5, `app/controllers/supervisors_controller.rb:39` 4798.3, `app/controllers/supervisors_controller.rb:38` 1219.8 |
| 3 | CourtDatesController#show | 11 / 11 | 41184.2 / 41177.5 | -6.7 | 38876.7 | `GEM/nokogiri/lib/nokogiri/xml/xpath_context.rb:10` 5164.4, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1257` 5018.6, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1256` 5009.4 | `app/models/case_court_report.rb:18` 31183.1, `app/models/case_court_report_context.rb:42` 831.4, `app/models/case_court_report_context.rb:155` 556.1 |
| 4 | AllCasaAdmins::CasaOrgsController#create | 7 / 7 | 38183.3 / 38205.2 | 21.8 | 33268.6 | `GEM/prosopite/lib/prosopite.rb:286` 14342.0, `GEM/bugsnag/lib/bugsnag/integrations/railtie.rb:28` 432.7, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:379` 401.7 | `app/models/contact_type_group.rb:35` 15538.3, `app/models/contact_type_group.rb:29` 4942.2, `app/models/hearing_type.rb:23` 4083.7 |
| 5 | CaseContacts::CaseContactsNewDesignController#index | 11 / 11 | 25886.4 / 25880.2 | -6.2 | 23841.8 | `GEM/prosopite/lib/prosopite.rb:286` 2394.3, `RAILS/activerecord/lib/arel/alias_predication.rb:8` 315.9, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:245` 303.5 | `app/views/case_contacts/case_contacts_new_design/index.html.erb:127` 3617.4, `app/controllers/case_contacts/case_contacts_new_design_controller.rb:22` 796.5, `app/views/case_contacts/case_contacts_new_design/index.html.erb:126` 700.6 |
| 6 | CaseContactsController#index | 4 / 4 | 25226.3 / 25267.0 | 40.7 | 25776.3 | `GEM/prosopite/lib/prosopite.rb:286` 4318.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:228` 221.3, `RAILS/activerecord/lib/arel/alias_predication.rb:8` 195.0 | `app/models/case_contact.rb:387` 5567.3, `app/controllers/concerns/loads_case_contacts.rb:32` 684.0, `app/decorators/case_contacts_decorator.rb:22` 531.7 |
| 7 | CasaOrgController#edit | 2 / 2 | 22842.0 / 22841.0 | -1.0 | 22174.0 | `GEM/prosopite/lib/prosopite.rb:286` 4546.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:245` 208.0, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:379` 203.0 | `app/views/casa_org/edit.html.erb:70` 466.0, `app/views/layouts/casa_app.html.erb:20` 462.0, `app/views/casa_org/_contact_types.html.erb:21` 428.0 |
| 8 | ReportsController#index | 3 / 3 | 20222.5 / 20303.5 | 81.0 | 15777.3 | `GEM/prosopite/lib/prosopite.rb:286` 3093.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:228` 177.0, `GEM/uri/lib/uri/rfc2396_parser.rb:291` 164.0 | `app/models/concerns/api.rb:11` 629.0, `app/models/user.rb:93` 587.0, `app/views/reports/index.html.erb:84` 476.0 |
| 9 | CaseContacts::FormController#new | 5 / 5 | 19973.3 / 19973.0 | -0.3 | 20607.0 | `GEM/prosopite/lib/prosopite.rb:286` 2598.5, `GEM/uri/lib/uri/rfc2396_parser.rb:291` 164.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:245` 154.3 | `app/controllers/case_contacts/form_controller.rb:122` 690.3, `app/controllers/case_contacts/form_controller.rb:159` 538.3, `app/controllers/case_contacts/form_controller.rb:139` 507.8 |
| 10 | SupervisorsController#index | 3 / 3 | 19639.5 / 19603.5 | -36.0 | 20487.3 | `GEM/prosopite/lib/prosopite.rb:286` 3215.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:228` 179.0, `GEM/uri/lib/uri/rfc2396_parser.rb:291` 164.0 | `app/views/supervisors/index.html.erb:267` 634.5, `app/models/concerns/api.rb:11` 618.0, `app/models/user.rb:93` 576.0 |
| 11 | AnalyticsController#index | 7 / 7 | 19144.5 / 19143.2 | -1.3 | 29429.7 | `GEM/prosopite/lib/prosopite.rb:286` 2609.7, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:173` 376.2, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:245` 279.2 | `app/models/metrics_report.rb:92` 1091.8, `app/models/metrics_report.rb:25` 719.3, `app/models/metrics_report.rb:26` 711.8 |
| 12 | ImportsController#create | 10 / 10 | 18801.1 / 18796.4 | -4.7 | 17722.6 | `GEM/prosopite/lib/prosopite.rb:286` 4467.2, `RAILS/activesupport/lib/active_support/testing/time_helpers.rb:190` 432.9, `GEM/mail/lib/mail/utilities.rb:215` 432.9 | `app/lib/importers/file_importer.rb:50` 4291.7, `app/models/concerns/api.rb:11` 1140.6, `app/lib/importers/file_importer.rb:49` 1130.8 |
| 13 | UsersController#edit | 2 / 2 | 18161.0 / 18165.0 | 4.0 | 19331.0 | `GEM/prosopite/lib/prosopite.rb:286` 2124.0, `GEM/uri/lib/uri/rfc2396_parser.rb:291` 164.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:245` 131.0 | `app/controllers/users_controller.rb:97` 1036.0, `app/views/layouts/casa_app.html.erb:20` 451.0, `app/views/users/_languages.html.erb:17` 438.0 |
| 14 | ImportsController#index | 2 / 2 | 17959.0 / 17966.0 | 7.0 | 10910.0 | `GEM/prosopite/lib/prosopite.rb:286` 1862.0, `RAILS/activesupport/lib/active_support/testing/time_helpers.rb:190` 396.0, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:59` 198.0 | `app/models/concerns/api.rb:11` 597.0, `app/models/user.rb:93` 555.0, `app/views/layouts/casa_app.html.erb:76` 474.0 |
| 15 | CaseGroupsController#index | 2 / 2 | 17626.0 / 17625.0 | -1.0 | 18262.0 | `GEM/prosopite/lib/prosopite.rb:286` 1903.0, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:379` 172.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:245` 172.0 | `app/views/case_groups/index.html.erb:40` 1468.0, `app/views/layouts/casa_app.html.erb:20` 458.0, `app/controllers/application_controller.rb:41` 395.0 |
| 16 | SupervisorsController#new | 2 / 2 | 17368.0 / 17419.0 | 51.0 | 10592.5 | `GEM/prosopite/lib/prosopite.rb:286` 1862.0, `GEM/uri/lib/uri/rfc2396_parser.rb:291` 164.0, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:379` 114.0 | `app/models/concerns/api.rb:11` 615.0, `app/models/user.rb:93` 573.0, `app/views/layouts/casa_app.html.erb:20` 449.0 |
| 17 | CourtDatesController#edit | 2 / 2 | 17354.0 / 17350.0 | -4.0 | 10820.5 | `GEM/prosopite/lib/prosopite.rb:286` 2185.0, `RAILS/activesupport/lib/active_support/testing/time_helpers.rb:190` 420.0, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:59` 210.0 | `app/views/layouts/casa_app.html.erb:76` 474.0, `app/views/layouts/casa_app.html.erb:20` 461.0, `app/controllers/court_dates_controller.rb:69` 438.0 |
| 18 | VolunteersController#edit | 8 / 8 | 17176.9 / 17173.7 | -3.1 | 18505.4 | `GEM/prosopite/lib/prosopite.rb:286` 3100.1, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:228` 214.3, `RAILS/activerecord/lib/arel/alias_predication.rb:8` 197.1 | `app/helpers/ui_helper.rb:10` 747.6, `app/helpers/ui_helper.rb:17` 731.9, `app/views/volunteers/_manage_supervisor.erb:37` 458.6 |
| 19 | PlacementsController#update | 2 / 2 | 17074.0 / 17080.0 | 6.0 | 11206.5 | `GEM/prosopite/lib/prosopite.rb:286` 1859.0, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:677` 437.0, `GEM/uri/lib/uri/rfc2396_parser.rb:291` 164.0 | `app/controllers/placements_controller.rb:39` 1034.0, `app/views/layouts/casa_app.html.erb:20` 455.0, `app/controllers/placements_controller.rb:59` 431.0 |
| 20 | CasaCasesController#index | 12 / 12 | 16989.5 / 16978.6 | -10.9 | 17093.7 | `GEM/prosopite/lib/prosopite.rb:286` 1750.2, `GEM/uri/lib/uri/rfc2396_parser.rb:291` 164.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:245` 112.5 | `app/views/casa_cases/index.html.erb:59` 1033.2, `app/views/layouts/casa_app.html.erb:20` 450.5, `app/controllers/casa_cases_controller.rb:18` 440.0 |
| 21 | VolunteersController#create | 6 / 6 | 16787.2 / 16785.8 | -1.4 | 16293.2 | `GEM/prosopite/lib/prosopite.rb:286` 2712.2, `GEM/mail/lib/mail/utilities.rb:215` 389.6, `GEM/mail/lib/mail/encodings/8bit.rb:14` 316.8 | `app/controllers/volunteers_controller.rb:48` 3838.2, `config/initializers/sent_email_event.rb:7` 929.0, `app/controllers/volunteers_controller.rb:45` 841.8 |
| 22 | NotificationsController#index | 7 / 7 | 16526.3 / 16525.2 | -1.2 | 16419.1 | `GEM/prosopite/lib/prosopite.rb:286` 2066.2, `RAILS/activesupport/lib/active_support/testing/time_helpers.rb:190` 367.0, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:59` 183.5 | `app/models/health.rb:7` 708.0, `app/helpers/notifications_helper.rb:23` 577.3, `app/views/layouts/casa_app.html.erb:76` 438.2 |
| 23 | CaseCourtReportsController#index | 3 / 3 | 16369.5 / 16369.0 | -0.5 | 17411.7 | `GEM/prosopite/lib/prosopite.rb:286` 1463.0, `GEM/uri/lib/uri/rfc2396_parser.rb:291` 164.0, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:379` 110.5 | `app/views/case_court_reports/_generate_docx.html.erb:23` 1709.0, `app/views/layouts/casa_app.html.erb:20` 452.5, `app/controllers/application_controller.rb:41` 389.5 |
| 24 | CasaAdminsController#create | 8 / 8 | 15942.1 / 15944.6 | 2.4 | 14397.8 | `GEM/prosopite/lib/prosopite.rb:286` 2507.3, `GEM/mail/lib/mail/utilities.rb:215` 417.4, `GEM/mail/lib/mail/encodings/8bit.rb:14` 339.4 | `app/services/create_casa_admin_service.rb:21` 4097.0, `app/services/create_casa_admin_service.rb:20` 1046.3, `config/initializers/sent_email_event.rb:7` 997.0 |
| 25 | AllCasaAdmins::MetricsController#index | 6 / 6 | 15807.4 / 15778.6 | -28.8 | 16429.3 | `GEM/prosopite/lib/prosopite.rb:286` 1692.4, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:173` 322.4, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:168` 186.4 | `app/models/metrics_report.rb:92` 1224.2, `app/models/metrics_report.rb:25` 730.0, `app/models/metrics_report.rb:26` 712.4 |
| 26 | MileageRatesController#create | 3 / 3 | 15732.5 / 15730.0 | -2.5 | 11950.0 | `GEM/prosopite/lib/prosopite.rb:286` 1069.0, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:677` 450.0, `GEM/uri/lib/uri/rfc2396_parser.rb:291` 164.0 | `app/controllers/mileage_rates_controller.rb:21` 999.5, `app/views/layouts/casa_app.html.erb:20` 461.0, `app/controllers/application_controller.rb:41` 398.0 |
| 27 | CaseContacts::FormController#show | 6 / 6 | 15700.6 / 15675.6 | -25.0 | 16946.8 | `GEM/prosopite/lib/prosopite.rb:286` 2603.4, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:228` 117.8, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:379` 108.4 | `app/controllers/case_contacts/form_controller.rb:113` 1071.2, `app/controllers/case_contacts/form_controller.rb:122` 695.8, `app/controllers/application_controller.rb:41` 403.0 |
| 28 | AllCasaAdmins::CasaOrgsController#show | 3 / 3 | 15564.5 / 15564.0 | -0.5 | 15718.0 | `GEM/prosopite/lib/prosopite.rb:286` 2676.5, `GEM/uri/lib/uri/rfc2396_parser.rb:291` 169.0, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:228` 109.0 | `app/models/all_casa_admins/casa_org_metrics.rb:15` 497.5, `app/models/all_casa_admins/casa_org_metrics.rb:17` 393.5, `app/views/all_casa_admins/casa_orgs/show.html.erb:32` 380.5 |
| 29 | PlacementsController#index | 3 / 3 | 15494.5 / 15492.5 | -2.0 | 15387.7 | `GEM/prosopite/lib/prosopite.rb:286` 1801.0, `GEM/uri/lib/uri/rfc2396_parser.rb:291` 164.0, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:379` 98.0 | `app/views/placements/index.html.erb:36` 583.5, `app/views/placements/index.html.erb:24` 508.5, `app/views/layouts/casa_app.html.erb:20` 454.0 |
| 30 | OtherDutiesController#index | 3 / 3 | 15263.5 / 15270.0 | 6.5 | 15219.7 | `GEM/prosopite/lib/prosopite.rb:286` 1240.0, `GEM/uri/lib/uri/rfc2396_parser.rb:291` 164.0, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:379` 97.5 | `app/controllers/other_duties_controller.rb:23` 956.5, `app/views/layouts/casa_app.html.erb:20` 451.0, `app/controllers/application_controller.rb:41` 388.0 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/prosopite/lib/prosopite.rb:286` | `subscribe` | 1609.84 / 1609.84 | 0.0 | 1613.67 | 94% | Data, Array |  | `app/controllers/application_controller.rb:41` 10%, `no app frame` 5% | `query_caller = caller_locations` |
| 2 | `GEM/nokogiri/lib/nokogiri/xml/xpath_context.rb:10` | `register_namespaces` | 622.37 / 622.37 | 0.0 | 624.13 | 3% | String, MatchData |  | `app/models/case_court_report.rb:18` 99%, `app/controllers/emancipations_controller.rb:31` 1% | `key = key.to_s.gsub(/.*:/, "") # strip off 'xmlns:' or 'xml:'` |
| 3 | `GEM/nokogiri/lib/nokogiri/xml/node.rb:1257` | `namespaces` | 604.81 / 604.78 | -0.03 | 606.54 | 3% | String |  | `app/models/case_court_report.rb:18` 99%, `app/controllers/emancipations_controller.rb:31` 1% | `hash[key] = ns.href` |
| 4 | `GEM/nokogiri/lib/nokogiri/xml/node.rb:1255` | `namespaces` | 604.41 / 604.41 | 0.0 | 606.12 | 3% | String, Data |  | `app/models/case_court_report.rb:18` 99%, `app/controllers/emancipations_controller.rb:31` 1% | `prefix = ns.prefix` |
| 5 | `GEM/nokogiri/lib/nokogiri/xml/node.rb:1256` | `namespaces` | 604.41 / 604.41 | 0.0 | 606.11 | 3% | String |  | `app/models/case_court_report.rb:18` 99%, `app/controllers/emancipations_controller.rb:31` 1% | `key = prefix ? "xmlns:#{prefix}" : "xmlns"` |
| 6 | `GEM/sablon/lib/sablon/parser/mail_merge.rb:137` | `parse_fields` | 182.37 / 182.37 | 0.0 | 182.6 | 3% | String |  | `app/models/case_court_report.rb:18` 100%, `app/controllers/emancipations_controller.rb:31` 0% | `elsif node.name == "fldChar" && node["w:fldCharType"] == "begin"` |
| 7 | `GEM/sablon/lib/sablon/parser/mail_merge.rb:135` | `parse_fields` | 179.62 / 179.62 | 0.0 | 179.84 | 3% | String |  | `app/models/case_court_report.rb:18` 100%, `app/controllers/emancipations_controller.rb:31` 0% | `if node.name == "fldSimple"` |
| 8 | `GEM/nokogiri/lib/nokogiri/xml/node.rb:1371` | `traverse` | 175.12 / 175.12 | 0.0 | 175.33 | 3% | Data |  | `app/models/case_court_report.rb:18` 100%, `app/controllers/emancipations_controller.rb:31` 0% | `children.each { \|j\| j.traverse(&block) }` |
| 9 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:228` | `cast_result` | 83.32 / 83.32 | 0.0 | 83.42 | 96% | String, Array |  | `app/validators/user_validator.rb:56` 12%, `app/controllers/application_controller.rb:41` 7% | `ar_result = if (fields = result.fields).empty?` |
| 10 | `RAILS/activemodel/lib/active_model/attribute.rb:10` | `from_database` | 71.58 / 71.58 | 0.0 | 71.75 | 92% | Object |  | `no app frame` 71%, `app/controllers/case_contacts/form_controller.rb:84` 2% | `FromDatabase.new(name, value_before_type_cast, type, nil, value)` |
| 11 | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:61` | `search` | 69.99 / 69.99 | 0.0 | 70.2 | 3% | Array |  | `app/models/case_court_report.rb:18` 99%, `app/controllers/emancipations_controller.rb:31` 1% | `xpath(*(xpaths + [ns, handler, binds].compact))` |
| 12 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:379` | `build_handle` | 68.97 / 68.97 | 0.0 | 69.15 | 100% | Object, Data |  | `no app frame` 32%, `app/views/layouts/casa_app.html.erb:76` 9% | `instances << group_klass.new(grouped_listeners, name, id, payload)` |
| 13 | `RAILS/activerecord/lib/arel/table.rb:105` | `[]` | 66.95 / 66.95 | 0.0 | 67.16 | 96% | Struct |  | `no app frame` 40%, `app/controllers/application_controller.rb:41` 3% | `Attribute.new(table, name)` |
| 14 | `GEM/bugsnag/lib/bugsnag/integrations/railtie.rb:28` | `event_subscription` | 64.38 / 64.38 | 0.0 | 64.48 | 96% | String, Hash |  | `no app frame` 51%, `app/controllers/application_controller.rb:41` 4% | `binds = data[:binds].each_with_object({}) { \|bind, output\| output[bind` |
| 15 | `GEM/uri/lib/uri/rfc2396_parser.rb:291` | `escape` | 43.47 / 43.47 | 0.0 | 43.64 | 27% | String |  | `app/views/shared/_favicons.html.erb:11` 7%, `app/views/shared/_favicons.html.erb:5` 7% | `str.gsub(unsafe) do` |
| 16 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:677` | `within_new_transaction` | 41.26 / 41.26 | 0.0 | 41.71 | 9% | String, Array |  | `app/controllers/case_assignments_controller.rb:17` 9%, `no app frame` 7% | `raise` |
| 17 | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:270` | `xpath_impl` | 40.59 / 40.59 | 0.0 | 40.6 | 10% | Data, Array |  | `app/models/case_court_report.rb:18` 97%, `config/initializers/field_error_proc.rb:16` 1% | `context.evaluate(path, handler)` |
| 18 | `GEM/nokogiri/lib/nokogiri/xml/node.rb:1254` | `namespaces` | 40.24 / 40.24 | 0.0 | 40.28 | 9% | Array, Hash |  | `app/models/case_court_report.rb:18` 98%, `config/initializers/field_error_proc.rb:16` 1% | `namespace_scopes.each_with_object({}) do \|ns, hash\|` |
| 19 | `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:256` | `cast_result` | 39.5 / 39.5 | 0.0 | 39.58 | 96% | Array, String |  | `no app frame` 11%, `config/initializers/sent_email_event.rb:7` 6% | `ActiveRecord::Result.new(fields, result.values, types.freeze, affected` |
| 20 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:331` | `index_with` | 38.93 / 38.93 | 0.0 | 39.23 | 91% | Array, Hash |  | `no app frame` 71%, `app/views/case_contacts/case_contacts_new_design/index.html.erb:127` 2% | `to_h { \|elem\| [elem, yield(elem)] } # rubocop:disable Rails/IndexWith` |
| 21 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:227` † | `now` | 38.48 / 38.48 | 0.0 | 38.59 | 88% | Data |  | `no app frame` 29%, `app/views/layouts/casa_app.html.erb:76` 10% | `Time.now` |
| 22 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:173` | `change` | 37.91 / 37.9 | -0.01 | 38.59 | 86% | Rational, Data |  | `no app frame` 54%, `app/models/metrics_report.rb:96` 6% | `::Time.utc(new_year, new_month, new_day, new_hour, new_min, new_sec)` |
| 23 | `RAILS/activesupport/lib/active_support/callbacks.rb:399` | `make_lambda` | 36.88 / 36.88 | 0.0 | 36.91 | 92% | Array |  | `no app frame` 65%, `app/models/user.rb:172` 3% | `target.send(@method_name, &block)` |
| 24 | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:216` | `extract_params` | 35.99 / 35.99 | 0.0 | 35.99 | 10% | Array |  | `app/models/case_court_report.rb:18` 98%, `app/controllers/emancipations_controller.rb:31` 1% | `hashes = []` |
| 25 | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:221` | `extract_params` | 35.99 / 35.99 | 0.0 | 35.99 | 10% | Array |  | `app/models/case_court_report.rb:18` 98%, `app/controllers/emancipations_controller.rb:31` 1% | `ns, binds = hashes.reverse` |
| 26 | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:225` | `extract_params` | 35.99 / 35.99 | 0.0 | 35.99 | 10% | Array |  | `app/models/case_court_report.rb:18` 98%, `app/controllers/emancipations_controller.rb:31` 1% | `[params, handler, ns, binds]` |
| 27 | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:57` | `search` | 34.99 / 34.99 | 0.0 | 35.1 | 3% | Array |  | `app/models/case_court_report.rb:18` 99%, `app/controllers/emancipations_controller.rb:31` 1% | `xpaths = paths.map(&:to_s).map do \|path\|` |
| 28 | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:59` | `search` | 34.99 / 34.99 | 0.0 | 35.1 | 3% | Array |  | `app/models/case_court_report.rb:18` 99%, `app/controllers/emancipations_controller.rb:31` 1% | `end.flatten.uniq` |
| 29 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:22` | `-` | 34.49 / 34.49 | 0.0 | 34.54 | 87% | Array, Object |  | `app/controllers/application_controller.rb:41` 19%, `app/views/layouts/casa_app.html.erb:60` 6% | `WhereClause.new(predicates - other.predicates)` |
| 30 | `GEM/sablon/lib/sablon/parser/mail_merge.rb:17` | `expression` | 31.45 / 31.45 | 0.0 | 31.47 | 3% | String, MatchData |  | `app/models/case_court_report.rb:18` 100%, `app/controllers/emancipations_controller.rb:31` 0% | `$1 if @raw_expression =~ KEY_PATTERN` |

## Dev/test-mode work

4226.0 of 13270.7 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | reload check | `RAILS/activesupport/lib/active_support/file_update_checker.rb:138` | 783.2 | 100% | `no app frame` 100% | `mtime = File.mtime(path)` |
| 2 | reload check | `RAILS/activesupport/lib/active_support/file_update_checker.rb:112` † | 442.55 | 100% | `no app frame` 100% | `all.concat(Dir[*@globs]) if @globs` |
| 3 | asset lookup | `GEM/sprockets/lib/sprockets/path_utils.rb:234` | 284.37 | 27% | `app/views/shared/_favicons.html.erb:16` 7%, `app/views/shared/_favicons.html.erb:6` 7% | `next unless File.basename(entry).start_with?(basename)` |
| 4 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:40` | 154.71 | 96% | `no app frame` 54%, `app/controllers/application_controller.rb:41` 4% | `binds = binds.inspect` |
| 5 | debug logging | `RAILS/activesupport/lib/active_support/colorize_logging.rb:63` | 88.89 | 96% | `no app frame` 40%, `app/controllers/application_controller.rb:41` 5% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 6 | debug logging | `RAILS/activesupport/lib/active_support/event_reporter.rb:472` | 74.9 | 100% | `no app frame` 33%, `app/views/layouts/casa_app.html.erb:76` 9% | `caller_location = caller_locations(caller_depth, 1)&.first` |
| 7 | asset lookup | `GEM/sprockets/lib/sprockets/encoding_utils.rb:51` † | 69.29 | 27% | `app/views/shared/_favicons.html.erb:2` 6%, `app/views/shared/_favicons.html.erb:6` 6% | `Marshal.load(marshaled)` |
| 8 | asset lookup | `GEM/sprockets/lib/sprockets/uri_tar.rb:18` | 61.84 | 27% | `app/views/layouts/casa_app.html.erb:15` 6%, `app/views/layouts/casa_app.html.erb:16` 6% | `@scheme, _, @path = uri.partition("://".freeze)` |
| 9 | asset lookup | `GEM/sprockets/lib/sprockets/resolve.rb:218` | 61.4 | 27% | `app/views/shared/_favicons.html.erb:10` 7%, `app/views/shared/_favicons.html.erb:11` 7% | `dirname    = File.dirname(File.join(load_path, logical_name))` |
| 10 | debug logging | `RAILS/activesupport/lib/active_support/colorize_logging.rb:61` | 59.85 | 96% | `no app frame` 39%, `app/controllers/application_controller.rb:41` 5% | `modes = MODES.values_at(*options.compact_blank.keys)` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| gem: nokogiri | 3027.7 | 3036.1 | `xpath_context.rb:10` 622.4, `node.rb:1257` 604.8, `node.rb:1256` 604.4 |
| rails: activesupport | 2553.1 | 2588.1 | `file_update_checker.rb:138` 783.2, `file_update_checker.rb:112` 442.5, `colorize_logging.rb:63` 88.9 |
| gem: sprockets | 1730.1 | 1738.0 | `path_utils.rb:234` 284.4, `encoding_utils.rb:51` 69.0, `uri_tar.rb:18` 61.8 |
| gem: prosopite | 1650.8 | 1654.8 | `prosopite.rb:286` 1609.8, `prosopite.rb:285` 29.7, `prosopite.rb:288` 6.0 |
| rails: activerecord | 1634.2 | 1652.3 | `log_subscriber.rb:40` 154.7, `database_statements.rb:228` 83.3, `table.rb:105` 66.9 |
| gem: sablon | 483.4 | 485.3 | `mail_merge.rb:137` 182.4, `mail_merge.rb:135` 179.6, `mail_merge.rb:17` 31.4 |
| rails: actionview | 314.4 | 321.3 | `structured_event_subscriber.rb:72` 24.9, `tag_helper.rb:1545` 15.2, `log_subscriber.rb:72` 13.5 |
| rails: actionpack | 303.9 | 362.2 | `structured_event_subscriber.rb:59` 38.9, `log_subscriber.rb:17` 8.0, `builder.rb:31` 6.6 |
| rails: activemodel | 251.5 | 256.4 | `attribute.rb:10` 71.6, `attribute_set.rb:607` 27.8, `attribute.rb:14` 25.5 |
| gem: bugsnag | 212.7 | 213.2 | `railtie.rb:28` 64.4, `railtie.rb:29` 25.3, `circular_buffer.rb:59` 24.4 |
| gem: mail | 205.7 | 211.1 | `utilities.rb:215` 22.9, `8bit.rb:14` 22.6, `field_list.rb:71` 11.1 |
| ruby default gem: uri | 168.0 | 168.7 | `rfc2396_parser.rb:291` 43.5, `rfc3986_parser.rb:85` 19.5, `common.rb:456` 19.2 |
| app | 148.5 | 169.5 | `_nav_link.html.erb:7` 7.1, `_nav_link.html.erb:1` 4.6, `casa_app.html.erb:76` 4.3 |
| gem: logger | 78.2 | 78.4 | `log_device.rb:165` 26.9, `log_device.rb:33` 26.9, `logger.rb:692` 24.4 |
| gem: rack | 75.6 | 75.9 | `utils.rb:693` 10.5, `request.rb:693` 7.2, `body_proxy.rb:12` 6.0 |
| ruby stdlib | 68.1 | 345.8 | `fileutils.rb:2461` 17.1, `formatter.rb:174` 14.1, `bundled_gems.rb:60` 7.1 |
| gem: i18n | 54.8 | 55.1 | `base.rb:157` 7.8, `i18n.rb:396` 7.5, `utils.rb:8` 5.7 |
| gem: rubyzip | 52.9 | 54.0 | `extra_field.rb:59` 6.6, `extra_field.rb:72` 5.1, `inflater.rb:36` 2.8 |
| gem: warden | 44.9 | 44.9 | `proxy.rb:334` 6.4, `proxy.rb:348` 4.6, `proxy.rb:218` 3.6 |
| gem: erubi | 36.3 | 37.6 | `erubi.rb:134` 20.1, `erubi.rb:137` 4.6, `erubi.rb:139` 2.6 |
| gem: tzinfo | 35.9 | 36.7 | `timestamp.rb:208` 11.9, `constant_offset_data_timezone_info.rb:52` 7.3, `timestamp.rb:193` 6.9 |
| gem: lograge | 32.4 | 32.4 | `key_value.rb:19` 13.1, `key_value.rb:27` 3.0, `base.rb:73` 2.0 |
| gem: authtrail | 31.5 | 31.6 | `authtrail.rb:18` 24.3, `authtrail.rb:25` 1.8, `manager.rb:9` 0.9 |
| gem: devise | 30.0 | 30.5 | `orm.rb:43` 6.0, `helpers.rb:128` 2.7, `store_location.rb:68` 1.8 |
| test harness: rspec-mocks | 27.9 | 30.3 | `recorder.rb:135` 8.6, `message_chains.rb:7` 6.4, `recorder.rb:173` 1.7 |
| gem: sprockets-rails | 26.3 | 29.3 | `helper.rb:357` 8.5, `helper.rb:81` 8.5, `helper.rb:356` 4.3 |
| gem: rails-controller-testing | 24.4 | 24.5 | `template_assertions.rb:39` 18.5, `template_assertions.rb:35` 4.8, `template_assertions.rb:27` 0.8 |
| gem: flipper | 21.3 | 21.4 | `wrapper.rb:32` 3.0, `memoizable.rb:97` 3.0, `memoizable.rb:93` 2.0 |
| gem: pg | 15.0 | 15.1 | `connection.rb:407` 14.9, `date.rb:14` 0.1, `date.rb:13` 0.0 |
| gem: pretender | 14.8 | 14.9 | `pretender.rb:31` 14.8, `pretender.rb:55` 0.0 |
| gem: pundit | 12.0 | 12.0 | `context.rb:179` 2.4, `policy_finder.rb:108` 2.4, `context.rb:166` 2.4 |
| gem: friendly_id | 8.1 | 8.9 | `finder_methods.rb:36` 5.1, `finder_methods.rb:78` 0.6, `scoped.rb:164` 0.3 |
| rails: railties | 6.4 | 6.7 | `logger.rb:29` 1.0, `finisher.rb:199` 1.0, `engine.rb:852` 1.0 |
| gem: concurrent-ruby | 6.3 | 7.3 | `non_concurrent_map_backend.rb:26` 2.9, `mri_map_backend.rb:14` 1.6, `non_concurrent_map_backend.rb:120` 1.6 |
| test harness: webmock | 6.3 | 7.2 | `headers.rb:69` 1.3, `headers.rb:68` 1.1, `headers.rb:16` 0.5 |
| test harness: rspec-support | 4.5 | 4.6 | `caller_filter.rb:67` 1.4, `method_signature_verifier.rb:135` 0.5, `fuzzy_matcher.rb:35` 0.4 |
| ruby default gem: securerandom | 4.4 | 4.4 | `securerandom.rb:71` 4.4 |
| gem: groupdate | 4.4 | 4.9 | `magic.rb:102` 1.1, `postgresql_adapter.rb:42` 0.3, `relation.rb:16` 0.3 |
| gem: base64 | 4.1 | 4.1 | `base64.rb:283` 3.9, `base64.rb:310` 0.2 |
| gem: addressable | 3.7 | 4.5 | `uri.rb:486` 0.2, `uri.rb:1544` 0.2, `uri.rb:428` 0.2 |
| gem: draper | 3.2 | 3.3 | `decoratable.rb:80` 0.5, `view_context.rb:39` 0.5, `decoratable.rb:25` 0.4 |
| rails: activestorage | 3.1 | 3.8 | `filename.rb:70` 0.3, `disk_service.rb:130` 0.2, `disk_service.rb:195` 0.2 |
| gem: json | 3.1 | 3.1 | `common.rb:1089` 3.1, `common.rb:1124` 0.0, `common.rb:1130` 0.0 |
| rails: actionmailer | 3.0 | 3.1 | `base.rb:1019` 0.4, `base.rb:642` 0.3, `base.rb:963` 0.3 |
| gem: rack-session | 3.0 | 3.0 | `id.rb:275` 1.0, `id.rb:277` 1.0, `id.rb:401` 1.0 |
| gem: marcel | 2.7 | 3.0 | `zip.rb:194` 0.8, `zip.rb:180` 0.6, `zip.rb:178` 0.3 |
| gem: ostruct | 2.6 | 2.7 | `ostruct.rb:238` 0.7, `ostruct.rb:237` 0.7, `ostruct.rb:249` 0.5 |
| gem: amazing_print | 2.5 | 2.6 | `class.rb:19` 1.2, `class.rb:21` 0.9, `awesome_method_array.rb:19` 0.4 |
| gem: rack-cors | 2.1 | 2.1 | `result.rb:38` 1.0, `cors.rb:129` 1.0, `cors.rb:123` 0.0 |
| gem: csv | 2.0 | 3.7 | `row.rb:206` 0.1, `writer.rb:51` 0.1, `writer.rb:154` 0.1 |
| gem: request_store | 2.0 | 2.0 | `middleware.rb:28` 1.0, `middleware.rb:21` 1.0, `request_store.rb:15` 0.0 |
| gem: bcrypt | 1.9 | 2.0 | `password.rb:102` 0.5, `engine.rb:90` 0.3, `password.rb:103` 0.3 |
| gem: view_component | 1.8 | 4.3 | `base.rb:21` 0.6, `base.rb:401` 0.4, `base.rb:308` 0.3 |
| gem: faraday | 1.1 | 3.5 | `utils.rb:32` 0.3, `utils.rb:31` 0.2, `utils.rb:33` 0.0 |
| gem: httparty | 1.1 | 1.3 | `httparty.rb:644` 0.3, `httparty.rb:640` 0.1, `httparty.rb:639` 0.1 |
| gem: turbo-rails | 1.0 | 1.1 | `request_id_tracking.rb:10` 1.0, `frames_helper.rb:45` 0.0, `frames_helper.rb:42` 0.0 |
| gem: globalid | 0.9 | 1.2 | `gid.rb:95` 0.2, `gid.rb:159` 0.2, `gid.rb:166` 0.1 |
| ruby default gem: net-http | 0.9 | 1.0 | `header.rb:205` 0.2, `header.rb:468` 0.1, `header.rb:195` 0.1 |
| rails: actiontext | 0.8 | 1.2 | `fragment.rb:36` 0.1, `html_conversion.rb:21` 0.1, `fragment.rb:41` 0.0 |
| gem: paranoia | 0.7 | 0.8 | `paranoia.rb:329` 0.7, `paranoia.rb:34` 0.0, `paranoia.rb:65` 0.0 |
| gem: zeitwerk | 0.6 | 0.7 | `cref.rb:47` 0.1, `cref.rb:36` 0.1, `file_system.rb:199` 0.1 |
| gem: noticed | 0.5 | 1.2 | `readable.rb:7` 0.4, `deliver_by.rb:12` 0.0, `notification.rb:10` 0.0 |
| gem: twilio-ruby | 0.5 | 124.6 | `version.rb:46` 0.0, `http_client.rb:38` 0.0, `domain.rb:16` 0.0 |
| rails: activejob | 0.4 | 0.4 | `log_subscriber.rb:202` 0.1, `configured_job.rb:15` 0.0, `arguments.rb:250` 0.0 |
| gem: pagy | 0.3 | 0.3 | `shared_methods.rb:12` 0.1, `backend.rb:16` 0.1, `shared_methods.rb:18` 0.0 |
| gem: orm_adapter | 0.3 | 0.3 | `base.rb:105` 0.1, `base.rb:100` 0.1, `base.rb:110` 0.1 |
| gem: loofah | 0.3 | 0.3 | `concerns.rb:172` 0.1, `concerns.rb:43` 0.1, `scrubber.rb:132` 0.0 |
| gem: wicked | 0.2 | 0.2 | `steps.rb:56` 0.1, `wizard.rb:63` 0.1, `wizard.rb:64` 0.1 |
| gem: filterrific | 0.2 | 0.3 | `param_set.rb:117` 0.1, `action_controller_extension.rb:56` 0.0, `action_controller_extension.rb:69` 0.0 |
| lowrail-profile | 0.2 | 0.2 | `profile.rb:115` 0.2, `profile.rb:66` 0.0, `profile.rb:56` 0.0 |
| gem: devise_invitable | 0.2 | 0.2 | `models.rb:139` 0.0, `models.rb:162` 0.0, `models.rb:211` 0.0 |
| gem: rails-html-sanitizer | 0.2 | 0.2 | `sanitizer.rb:165` 0.0, `sanitizer.rb:33` 0.0, `sanitizer.rb:56` 0.0 |
| gem: responders | 0.1 | 0.2 | `respond_with.rb:248` 0.0, `responder.rb:243` 0.0, `responder.rb:150` 0.0 |
| test harness: rspec-expectations | 0.0 | 0.1 | `match.rb:54` 0.0, `composable.rb:46` 0.0, `aliased_matcher.rb:25` 0.0 |
| gem: scout_apm | 0.0 | 0.1 | `config.rb:463` 0.0, `agent.rb:20` 0.0, `agent.rb:65` 0.0 |
| gem: faraday-net_http | 0.0 | 0.2 | `net_http.rb:81` 0.0, `net_http.rb:80` 0.0, `net_http.rb:176` 0.0 |
| gem: bigdecimal | 0.0 | 0.0 | `util.rb:73` 0.0 |
| gem: racc | 0.0 | 0.1 | `parser.rb:263` 0.0 |
| gem: caxlsx_rails | 0.0 | 0.0 | `railtie.rb:9` 0.0, `template_handler.rb:12` 0.0 |
| other | 0.0 | 0.0 | `(erb):1` 0.0 |
| ruby default gem: pp | 0.0 | 0.1 | `pp.rb:271` 0.0, `pp.rb:97` 0.0, `pp.rb:151` 0.0 |
| gem: flipper-ui | 0.0 | 0.0 | `ui.rb:49` 0.0 |
| gem: jbuilder | 0.0 | 0.1 | `jbuilder_dependency_tracker.rb:42` 0.0, `jbuilder_dependency_tracker.rb:28` 0.0, `railtie.rb:10` 0.0 |
| ruby default gem: prettyprint | 0.0 | 0.2 | `prettyprint.rb:166` 0.0, `prettyprint.rb:88` 0.0, `prettyprint.rb:94` 0.0 |
| rails: actioncable | 0.0 | 0.0 | `action_cable_helper.rb:5` 0.0, `action_cable_helper.rb:0` 0.0, `engine.rb:24` 0.0 |
| gem: cliver | 0.0 | 0.0 | `dependency.rb:54` 0.0, `dependency.rb:84` 0.0, `dependency.rb:203` 0.0 |
| gem: pdf-forms | 0.0 | 0.0 | `pdftk_wrapper.rb:182` 0.0, `pdf_forms.rb:16` 0.0, `pdftk_wrapper.rb:31` 0.0 |
| gem: htmlentities | 0.0 | 0.1 | `encoder.rb:90` 0.0, `encoder.rb:61` 0.0, `encoder.rb:89` 0.0 |
| gem: pghero | 0.0 | 0.6 | `pghero.rb:133` 0.0, `home_controller.rb:12` 0.0, `home_controller.rb:26` 0.0 |
| ruby default gem: erb | 0.0 | 0.1 | `compiler.rb:467` 0.0, `compiler.rb:277` 0.0, `compiler.rb:432` 0.0 |
| ruby default gem: prism | 0.0 | 178.0 | `node.rb:2797` 0.0, `node.rb:16771` 0.0, `node.rb:19661` 0.0 |
| rails: actionmailbox | 0.0 | 0.4 | `inbound_emails_controller.rb:62` 0.0, `inbound_emails_controller.rb:0` 0.0, `inbound_emails_controller.rb:49` 0.0 |
| gem: caxlsx | 0.0 | 6.9 | `workbook.rb:162` 0.0, `cell.rb:259` 0.0, `comments.rb:5` 0.0 |
| gem: blueprinter | 0.0 | 0.7 | `base.rb:121` 0.0, `reflection.rb:34` 0.0, `configuration.rb:71` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Mails

| # | Mailer action | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | Devise::Mailer#invitation_instructions | 17 / 17 | 3304.4 / 3304.3 | -0.1 | 3304.7 | `GEM/prosopite/lib/prosopite.rb:286` 461.4, `GEM/mail/lib/mail/utilities.rb:215` 171.0, `GEM/mail/lib/mail/fields/parameter_hash.rb:22` 122.5 | `config/initializers/sent_email_event.rb:7` 1014.4, `app/lib/importers/file_importer.rb:50` 597.4, `app/views/devise/mailer/invitation_instructions.html.erb:8` 67.4 |
| 2 | Devise::Mailer.deliver_mail | 21 / 21 | 2196.0 / 2195.8 | -0.2 | 2208.9 | `GEM/mail/lib/mail/encodings/8bit.rb:14` 360.8, `GEM/mail/lib/mail/utilities.rb:215` 265.2, `GEM/mail/lib/mail/field_list.rb:71` 131.4 | `app/lib/importers/file_importer.rb:50` 737.6, `app/models/user.rb:185` 211.4 |
| 3 | Devise::Mailer#email_changed | 4 / 4 | 2037.7 / 2037.7 | 0.0 | 2098.5 | `GEM/prosopite/lib/prosopite.rb:286` 442.0, `GEM/mail/lib/mail/parsers/address_lists_parser.rb:32009` 62.7, `RAILS/activerecord/lib/active_record/connection_adapters/postgresql/database_statements.rb:228` 57.0 | `config/initializers/sent_email_event.rb:7` 992.0, `app/models/user.rb:185` 616.7, `app/models/concerns/roles.rb:5` 27.0 |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/prosopite/lib/prosopite.rb:286` | 217.86 / 217.86 | 50% | `config/initializers/sent_email_event.rb:7` 100% | `query_caller = caller_locations` |
| 2 | `GEM/mail/lib/mail/utilities.rb:215` | 202.38 / 202.38 | 100% | `no app frame` 61%, `app/lib/importers/file_importer.rb:50` 33% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 3 | `GEM/mail/lib/mail/encodings/8bit.rb:14` | 171.81 / 171.81 | 50% | `no app frame` 57%, `app/lib/importers/file_importer.rb:50` 31% | `!str.lines.find { \|line\| line.bytesize > 998 }` |
| 4 | `GEM/mail/lib/mail/fields/parameter_hash.rb:22` | 103.43 / 103.43 | 91% | `no app frame` 64%, `app/lib/importers/file_importer.rb:50` 35% | `if k =~ /^#{key_pattern}(\*\|$)/i` |
| 5 | `GEM/mail/lib/mail/field_list.rb:71` | 99.69 / 99.69 | 100% | `no app frame` 62%, `app/lib/importers/file_importer.rb:50` 34% | `fields = select { \|f\| f.responsible_for? field_name }` |
| 6 | `GEM/mail/lib/mail/utilities.rb:291` | 51.33 / 51.33 | 100% | `no app frame` 56%, `app/lib/importers/file_importer.rb:50` 31% | `value !~ /\S/` |
| 7 | `GEM/mail/lib/mail/utilities.rb:226` | 49.71 / 49.71 | 91% | `no app frame` 62%, `app/lib/importers/file_importer.rb:50` 34% | `str.to_s.downcase.tr(Constants::HYPHEN, Constants::UNDERSCORE)` |
| 8 | `GEM/mail/lib/mail/parsers/content_type_parser.rb:734` | 43.07 / 43.0 | 50% | `no app frame` 63%, `app/lib/importers/file_importer.rb:50` 33% | `_wide = data[p].ord` |
| 9 | `GEM/mail/lib/mail/parsers/content_transfer_encoding_parser.rb:380` | 34.29 / 34.29 | 50% | `no app frame` 63%, `app/lib/importers/file_importer.rb:50` 35% | `_wide = data[p].ord` |
| 10 | `GEM/mail/lib/mail/parser_tools.rb:7` | 31.02 / 31.02 | 100% | `no app frame` 57%, `app/lib/importers/file_importer.rb:50` 31% | `data.slice(from_bytes..to_bytes).force_encoding(Encoding::UTF_8)` |
