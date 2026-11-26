# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails test -v`
* Ruby: ruby 3.4.2 (2025-02-15 revision d2930f8e7a) +PRISM [x86_64-linux]
* Rails: 8.1.3.1, test environment
* Counted in run 1: 1061 requests, 9 jobs, 58 Cable actions; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1
* Not attributed: 0.0 objects per request (0.0% of all) are on lines outside the app, Rails, Ruby and the bundle's gems, which no table below ranks; most in `(erb)`

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 1061 | 11020.4 | 9 | 0 | 58 | 0 |
| run2 | 1 | 1061 | 11033.5 | 9 | 0 | 58 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.28 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/views/layouts/application.html.erb:60` |  | 851.13 | 653.08 | 0.63 | `GEM/json/lib/json/common.rb:364` 88%, `RUBY/pathname.rb:51` 3%, `RUBY/pathname.rb:55` 2% | DocumentsController#index 49%, DocumentsController#show 46%, SessionsController#new 3% | `<%= vite_typescript_tag "inertia.tsx" %>` |
| 2 | `app/views/layouts/application.html.erb:62` |  | 846.48 | 651.2 | 0.63 | `GEM/json/lib/json/common.rb:364` 89%, `RUBY/pathname.rb:51` 3%, `RUBY/pathname.rb:55` 2% | DocumentsController#index 49%, DocumentsController#show 46%, SessionsController#new 3% | `<%= vite_typescript_tag 'application' %>` |
| 3 | `app/views/layouts/application.html.erb:57` |  | 844.6 | 642.43 | 0.63 | `GEM/json/lib/json/common.rb:364` 89%, `RUBY/pathname.rb:51` 3%, `RUBY/pathname.rb:55` 2% | DocumentsController#index 49%, DocumentsController#show 46%, SessionsController#new 3% | `<%= vite_stylesheet_tag "application" %>` |
| 4 | `app/controllers/documents_controller.rb:149` | `show` | 125.81 | 7.97 | 0.4 | `GEM/json/lib/json/common.rb:364` 23%, `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:75` 7%, `RAILS/activesupport/lib/active_support/core_ext/hash/indifferent_access.rb:10` 7% | DocumentsController#show 100% | `render inertia: "documents/show", props: {` |
| 5 | `app/controllers/application_controller.rb:62` | `current_user` | 78.66 | 16.94 | 1.1 | `RAILS/activesupport/lib/active_support/messages/rotator.rb:55` 4%, `RAILS/activesupport/lib/active_support/key_generator.rb:63` 3%, `RAILS/actionpack/lib/action_dispatch/middleware/cookies.rb:659` 3% | DocumentsController#index 19%, DocumentsController#show 19%, CommentsController#create 14% | `@current_user = User.find_by(id: session[:user_id])` |
| 6 | `app/controllers/documents_controller.rb:50` | `index` | 71.96 | 8.42 | 0.43 | `GEM/json/lib/json/common.rb:364` 12%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:81` 4%, `GEM/inertia_rails/lib/inertia_rails/props_resolver.rb:82` 4% | DocumentsController#index 100% | `render inertia: "documents/index", props: {` |
| 7 | `app/controllers/documents_controller.rb:77` | `index` | 56.89 | 3.53 | 0.11 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 18%, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:178` 15%, `GEM/sqlite3/lib/sqlite3/statement.rb:186` 10% | DocumentsController#index 100% | `.map { \|pin\| with_ownership.(pin.document).merge(pinned_at: pin.create` |
| 8 | `app/models/activity.rb:11` | `log!` | 41.48 | 14.79 | 0.17 | `RAILS/activemodel/lib/active_model/attribute.rb:13` 3%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 3%, `GEM/sqlite3/lib/sqlite3/statement.rb:58` 3% | Api::DocsController#update 50%, Api::DocsController#create 19%, Api::DocsController#show 5% | `activity = create!(document:, actor_name:, actor_kind:, action:, detai` |
| 9 | `app/models/document.rb:240` | `with_comment_access` | 39.49 | 6.01 | 0.07 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 54%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 5%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 2% | CommentsController#create 91%, CommentsController#resolve 4%, Api::CommentsController#create 3% | `with_lock do` |
| 10 | `app/controllers/application_controller.rb:41` | `ensure_owner_token` | 38.8 | 0.0 | 0.0 | `GEM/uri/lib/uri/common.rb:465` 25%, `GEM/rack/lib/rack/utils.rb:331` 8%, `GEM/json/lib/json/common.rb:364` 8% | DocumentsController#show 17%, CommentsController#create 16%, DocumentsController#index 13% | `return if cookies.signed[:owner_token].present?` |
| 11 | `app/models/document.rb:111` | `live_crdt?` | 36.43 | 9.1 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 3% | Api::DocsController#update 62%, DocumentsController#show 38% | `yjs_state.present? \|\| yjs_document_updates.exists?` |
| 12 | `app/models/document_asset.rb:36` | `store!` | 31.33 | 5.56 | 0.0 | `RAILS/activemodel/lib/active_model/attribute_set.rb:47` 2%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 2%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 2% | Api::UploadsController#create 100% | `asset.file.attach(blob)` |
| 13 | `app/channels/document_meta_channel.rb:14` | `broadcast_event` | 25.62 | 2.49 | 0.83 | `GEM/uri/lib/uri/common.rb:90` 8%, `GEM/globalid/lib/global_id/uri/gid.rb:95` 8%, `GEM/globalid/lib/global_id/uri/gid.rb:159` 6% | DocumentsController#claim 35%, Api::DocsController#update 20%, Api::DocsController#create 8% | `broadcast_to(document, { event: event.to_s, **payload })` |
| 14 | `app/controllers/application_controller.rb:56` | `owner_token` | 24.02 | 0.0 | 0.0 | `GEM/json/lib/json/common.rb:364` 25%, `RAILS/actionpack/lib/action_dispatch/middleware/cookies.rb:639` 7%, `GEM/base64/lib/base64.rb:310` 7% | DocumentsController#index 30%, DocumentsController#show 25%, DocumentsController#claim 9% | `cookies.signed[:owner_token]` |
| 15 | `app/models/document.rb:340` | `claim!` | 23.45 | 4.07 | 0.08 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 3%, `RAILS/activemodel/lib/active_model/attribute.rb:13` 3%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 3% | DocumentsController#claim 94%, DocumentsController#show 6% | `activity = activities.create!(` |
| 16 | `app/controllers/application_controller.rb:47` | `replace_owner_token!` | 22.19 | 0.0 | 0.33 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:146` 9%, `RAILS/activesupport/lib/active_support/core_ext/hash/keys.rb:35` 9%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:141` 6% | SessionsController#create 32%, DocumentsController#index 20%, DocumentsController#show 19% | `cookies.permanent.signed[:owner_token] = {` |
| 17 | `app/models/comment.rb:16` | `post!` | 22.01 | 0.29 | 0.06 | `GEM/i18n/lib/i18n/interpolate/ruby.rb:33` 4%, `GEM/i18n/lib/i18n/backend/base.rb:157` 4%, `GEM/i18n/lib/i18n.rb:396` 4% | CommentsController#create 99%, Api::CommentsController#create 1% | `comment = document.comments.create!(author_name:, author_kind:, body:,` |
| 18 | `app/models/document.rb:181` | `with_write_access` | 20.75 | 4.64 | 0.06 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 32%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 7%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 4% | WritingPassesController#create 37%, SuggestionsController#create 19%, Api::SuggestionsController#create 12% | `with_lock do` |
| 19 | `app/controllers/api/docs_controller.rb:135` | `update` | 18.02 | 1.75 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 20%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 10%, `RAILS/activesupport/lib/active_support/callbacks.rb:362` 9% | Api::DocsController#update 100% | `document.save!` |
| 20 | `app/controllers/api/docs_controller.rb:34` | `create` | 17.09 | 6.92 | 0.03 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 5%, `RAILS/activerecord/lib/arel/table.rb:85` 5%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 5% | Api::DocsController#create 100% | `doc = Document.create!(` |
| 21 | `app/controllers/application_controller.rb:31` | `extend_remembered_session` | 16.62 | 0.17 | 0.0 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` 11%, `RAILS/actionpack/lib/action_controller/metal/rate_limiting.rb:75` 8%, `RAILS/activesupport/lib/active_support/cache.rb:949` 6% | CommentsController#create 23%, DocumentPinsController#create 22%, SessionsController#create 17% | `yield` |
| 22 | `app/controllers/documents_controller.rb:194` | `show` | 16.0 | 3.35 | 0.3 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `RAILS/activerecord/lib/active_record/relation.rb:77` 3% | DocumentsController#show 100% | `suggestions: -> { document.suggestions.pending.order(:created_at).map(` |
| 23 | `app/controllers/documents_controller.rb:197` | `show` | 15.68 | 3.82 | 0.2 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `RAILS/activerecord/lib/active_record/relation.rb:77` 3% | DocumentsController#show 100% | `presences: -> { document.agent_presences.active.map(&:as_props) },` |
| 24 | `app/controllers/documents_controller.rb:195` | `show` | 15.45 | 2.93 | 0.2 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `RAILS/activerecord/lib/active_record/relation.rb:77` 3% | DocumentsController#show 100% | `comments: -> { document.comments.order(:created_at).map(&:as_props) },` |
| 25 | `app/models/document.rb:331` | `claim!` | 15.21 | 5.71 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:146` 6%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:141` 4%, `RAILS/activerecord/lib/arel/table.rb:85` 3% | DocumentsController#claim 94%, DocumentsController#show 6% | `.update_all(attributes) == 1` |
| 26 | `app/controllers/documents_controller.rb:196` | `show` | 14.92 | 3.32 | 0.2 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `RAILS/activerecord/lib/active_record/relation.rb:77` 3% | DocumentsController#show 100% | `activities: -> { document.activities.recent.map(&:as_props) },` |
| 27 | `app/services/document_plain_text.rb:14` | `call` | 14.65 | 0.0 | 0.0 | `GEM/commonmarker/lib/commonmarker/config.rb:94` 82%, `GEM/commonmarker/lib/commonmarker.rb:44` 11%, `GEM/commonmarker/lib/commonmarker/config.rb:78` 2% | DocumentsController#show 46%, Api::DocsController#update 36%, Api::DocsController#create 13% | `Commonmarker.to_html(source, plugins: MARKDOWN_PLUGINS)` |
| 28 | `app/views/layouts/application.html.erb:53` |  | 13.6 | 4.6 | 0.21 | `RUBY/pathname.rb:51` 15%, `RUBY/pathname.rb:55` 12%, `RUBY/pathname.rb:358` 6% | DocumentsController#index 49%, DocumentsController#show 46%, SessionsController#new 3% | `<%= stylesheet_link_tag :app %>` |
| 29 | `app/models/user.rb:56` | `adopt_pins!` | 13.2 | 2.24 | 0.2 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 5%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 4%, `RAILS/activerecord/lib/arel/table.rb:85` 3% | SessionsController#create 93%, OauthCallbacksController#create 4%, RegistrationsController#create 3% | `guest_pins.where(document_id: document_pins.select(:document_id)).dele` |
| 30 | `app/models/user.rb:38` | `claim_documents!` | 12.47 | 4.62 | 0.07 | `RAILS/activerecord/lib/arel/table.rb:85` 4%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:68` 3%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:146` 3% | SessionsController#create 93%, OauthCallbacksController#create 4%, RegistrationsController#create 3% | `Document.where(user_id: nil, owner_token:).update_all(` |

737.86 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | FeedbackRunsController#show | 2 / 2 | 379744.0 / 379759.0 | 15.0 | 190956.0 | `RAILS/actionview/lib/action_view/buffers.rb:44` 1458.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 667.0, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:11` 652.0 | `app/controllers/feedback_runs_controller.rb:45` 217.0, `app/controllers/application_controller.rb:62` 141.0, `app/controllers/application_controller.rb:41` 107.0 |
| 2 | DocumentOgImagesController#show | 4 / 4 | 104262.7 / 104262.7 | 0.0 | 78620.8 | `RAILS/actionview/lib/action_view/buffers.rb:44` 445.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 204.3, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:11` 199.3 | `app/controllers/document_og_images_controller.rb:7` 77.0, `app/controllers/document_og_images_controller.rb:10` 68.0, `app/controllers/document_og_images_controller.rb:16` 37.3 |
| 3 | (no action name) | 15 / 15 | 76368.2 / 76369.4 | 1.2 | 71328.2 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 259.7, `GEM/nokogiri/lib/nokogiri/html5/node.rb:66` 252.4, `GEM/nokogiri/lib/nokogiri/xml/document.rb:416` 252.0 | `app/constraints/admin_constraint.rb:8` 33.8, `app/constraints/admin_constraint.rb:11` 21.9 |
| 4 | DocumentsController#update_editing_lock | 9 / 9 | 45694.9 / 45693.1 | -1.8 | 40887.6 | `RAILS/actionview/lib/action_view/buffers.rb:44` 168.8, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 77.4, `GEM/hashie/lib/hashie/mash.rb:374` 77.0 | `app/models/document.rb:265` 187.8, `app/models/document.rb:271` 148.5, `app/models/document.rb:270` 145.0 |
| 5 | DocumentsController#index | 114 / 114 | 24554.5 / 24635.7 | 81.1 | 24827.6 | `GEM/json/lib/json/common.rb:364` 10474.2, `RUBY/pathname.rb:51` 366.5, `RUBY/pathname.rb:55` 287.5 | `app/views/layouts/application.html.erb:60` 3946.8, `app/views/layouts/application.html.erb:62` 3924.6, `app/views/layouts/application.html.erb:57` 3908.0 |
| 6 | SessionsController#new | 7 / 7 | 23740.0 / 23728.8 | -11.2 | 23715.1 | `GEM/json/lib/json/common.rb:364` 10774.3, `RUBY/pathname.rb:51` 370.0, `RUBY/pathname.rb:55` 290.0 | `app/views/layouts/application.html.erb:57` 4080.2, `app/views/layouts/application.html.erb:60` 4028.3, `app/views/layouts/application.html.erb:62` 4010.0 |
| 7 | DocumentsController#show | 130 / 130 | 22256.4 / 22292.4 | 36.0 | 22328.4 | `GEM/json/lib/json/common.rb:364` 8848.3, `RUBY/pathname.rb:51` 303.6, `RUBY/pathname.rb:55` 238.1 | `app/views/layouts/application.html.erb:60` 3230.8, `app/views/layouts/application.html.erb:62` 3213.4, `app/views/layouts/application.html.erb:57` 3209.4 |
| 8 | CliAuthorizationsController#show | 6 / 6 | 19168.6 / 19161.8 | -6.8 | 20610.2 | `GEM/json/lib/json/common.rb:364` 8629.4, `RUBY/pathname.rb:51` 296.0, `RUBY/pathname.rb:55` 232.0 | `app/views/layouts/application.html.erb:60` 3222.6, `app/views/layouts/application.html.erb:62` 3208.0, `app/views/layouts/application.html.erb:57` 3204.0 |
| 9 | IdentitiesController#update | 20 / 20 | 18681.9 / 18683.5 | 1.5 | 17811.5 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `RAILS/actionview/lib/action_view/buffers.rb:44` 69.7, `GEM/hashie/lib/hashie/mash.rb:410` 58.0 | `app/controllers/identities_controller.rb:16` 60.6, `app/controllers/application_controller.rb:47` 50.8, `app/controllers/identities_controller.rb:11` 43.9 |
| 10 | DocumentsController#claim | 84 / 84 | 10540.4 / 10539.8 | -0.7 | 10441.7 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0, `GEM/hashie/lib/hashie/mash.rb:369` 56.0 | `app/models/document.rb:340` 281.7, `app/models/document.rb:331` 182.9, `app/controllers/application_controller.rb:62` 130.9 |
| 11 | DocumentPinsController#create | 69 / 69 | 6243.0 / 6242.8 | -0.2 | 6187.5 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0, `GEM/hashie/lib/hashie/mash.rb:369` 56.0 | `app/controllers/application_controller.rb:62` 122.0, `app/models/document_pin.rb:36` 76.0, `app/controllers/document_pins_controller.rb:18` 60.2 |
| 12 | WritingPassesController#create | 26 / 26 | 5181.2 / 5184.6 | 3.4 | 5233.7 | `GEM/json/lib/json/common.rb:364` 269.3, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 123.5, `GEM/hashie/lib/hashie/mash.rb:374` 77.0 | `app/models/document.rb:181` 328.3, `app/services/compound_writing/lens_set.rb:10` 260.0, `app/models/writing_pack.rb:26` 204.2 |
| 13 | Api::UploadsController#create | 33 / 33 | 4144.7 / 4143.1 | -1.6 | 4059.1 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0, `GEM/hashie/lib/hashie/mash.rb:369` 56.0 | `app/models/document_asset.rb:36` 1038.7, `app/models/document_asset.rb:23` 301.3, `app/models/document_asset.rb:27` 275.6 |
| 14 | Api::DocsController#show | 10 / 10 | 3690.4 / 3691.0 | 0.6 | 3437.8 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0, `GEM/hashie/lib/hashie/mash.rb:369` 56.0 | `app/models/agent_presence.rb:25` 400.6, `app/models/activity.rb:11` 230.2, `app/services/agent_guide.rb:170` 183.0 |
| 15 | FeedbackRunsController#create | 10 / 10 | 3659.9 / 3669.3 | 9.4 | 4922.0 | `GEM/marcel/lib/marcel/magic.rb:140` 213.0, `GEM/marcel/lib/marcel/magic.rb:136` 200.3, `GEM/marcel/lib/marcel/magic.rb:135` 200.3 | `app/controllers/feedback_runs_controller.rb:21` 1049.2, `app/controllers/feedback_runs_controller.rb:19` 332.1, `app/controllers/application_controller.rb:62` 138.6 |
| 16 | Api::CommentsController#resolve | 4 / 4 | 3177.3 / 3177.7 | 0.3 | 2724.5 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` 280.0, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 168.3, `GEM/hashie/lib/hashie/mash.rb:374` 77.0 | `app/models/agent_presence.rb:17` 952.0, `app/models/document.rb:240` 410.7, `app/controllers/api/comments_controller.rb:31` 148.0 |
| 17 | Api::SuggestionsController#create | 10 / 10 | 2787.3 / 2788.2 | 0.9 | 2903.6 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 84.6, `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0 | `app/models/document.rb:181` 305.2, `app/models/activity.rb:11` 226.0, `app/models/agent_presence.rb:25` 225.6 |
| 18 | RegistrationsController#create | 3 / 3 | 2760.0 / 2768.5 | 8.5 | 3007.7 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0, `GEM/hashie/lib/hashie/mash.rb:369` 56.0 | `app/controllers/registrations_controller.rb:11` 394.0, `app/models/user.rb:56` 200.0, `app/models/user.rb:38` 189.0 |
| 19 | CommentsController#create | 69 / 69 | 2733.6 / 2732.4 | -1.3 | 2769.9 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 314.8, `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0 | `app/models/document.rb:240` 558.0, `app/models/comment.rb:16` 338.4, `app/controllers/application_controller.rb:62` 168.6 |
| 20 | SuggestionsController#reopen | 2 / 2 | 2726.0 / 2726.0 | 0.0 | 2502.0 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 72.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0 | `app/models/document.rb:181` 244.0, `app/models/activity.rb:11` 188.0, `app/controllers/suggestions_controller.rb:90` 144.0 |
| 21 | SuggestionsController#accept | 8 / 8 | 2611.3 / 2609.9 | -1.4 | 2725.1 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 76.4, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 67.1 | `app/models/document.rb:181` 319.4, `app/controllers/application_controller.rb:62` 145.9, `app/controllers/suggestions_controller.rb:76` 144.4 |
| 22 | SuggestionsController#reject | 4 / 4 | 2525.7 / 2532.7 | 7.0 | 2613.5 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 88.3, `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 68.0 | `app/models/document.rb:181` 331.7, `app/controllers/application_controller.rb:62` 147.0, `app/controllers/suggestions_controller.rb:107` 145.0 |
| 23 | SuggestionsController#accept_all | 9 / 9 | 2450.4 / 2452.4 | 2.0 | 2390.2 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0, `GEM/hashie/lib/hashie/mash.rb:369` 56.0 | `app/models/document.rb:181` 245.6, `app/models/suggestion.rb:182` 149.6, `app/models/suggestion.rb:185` 139.5 |
| 24 | Api::DocsController#update | 114 / 114 | 2409.8 / 2409.8 | -0.0 | 2397.1 | `GEM/commonmarker/lib/commonmarker/config.rb:94` 77.9, `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0 | `app/models/document.rb:111` 213.5, `app/models/activity.rb:11` 193.5, `app/controllers/api/docs_controller.rb:135` 169.2 |
| 25 | SuggestionsController#create | 12 / 12 | 2406.4 / 2409.7 | 3.4 | 2387.2 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 151.8, `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0 | `app/models/document.rb:181` 375.1, `app/models/suggestion.rb:40` 280.9, `app/controllers/application_controller.rb:62` 129.4 |
| 26 | DocumentsController#snapshot | 14 / 14 | 2348.7 / 2349.1 | 0.4 | 2262.0 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0, `GEM/hashie/lib/hashie/mash.rb:369` 56.0 | `app/services/yjs_persistence.rb:180` 191.7, `app/services/yjs_persistence.rb:147` 150.8, `app/controllers/application_controller.rb:62` 134.0 |
| 27 | DocumentsController#destroy | 8 / 8 | 2272.3 / 2269.3 | -3.0 | 2131.6 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0, `GEM/hashie/lib/hashie/mash.rb:369` 56.0 | `app/controllers/documents_controller.rb:393` 930.3, `app/controllers/application_controller.rb:62` 114.6, `app/controllers/documents_controller.rb:380` 70.3 |
| 28 | Api::DocsController#index | 2 / 2 | 2153.0 / 2154.0 | 1.0 | 1560.5 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0, `GEM/hashie/lib/hashie/mash.rb:369` 56.0 | `app/models/cli_access_token.rb:21` 324.0, `app/models/cli_access_token.rb:24` 248.0, `app/controllers/api/docs_controller.rb:9` 204.0 |
| 29 | CommentsController#resolve | 7 / 7 | 2152.3 / 2152.8 | 0.5 | 2241.6 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0, `GEM/hashie/lib/hashie/mash.rb:369` 56.0 | `app/models/document.rb:240` 248.7, `app/models/comment.rb:29` 157.3, `app/models/activity.rb:11` 123.3 |
| 30 | OauthCallbacksController#create | 7 / 7 | 2149.8 / 2142.5 | -7.3 | 2353.3 | `GEM/hashie/lib/hashie/mash.rb:374` 92.3, `GEM/hashie/lib/hashie/mash.rb:410` 58.0, `GEM/hashie/lib/hashie/mash.rb:369` 56.0 | `app/controllers/oauth_callbacks_controller.rb:18` 164.3, `app/models/user.rb:56` 100.0, `app/models/user.rb:38` 94.5 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/json/lib/json/common.rb:364` | `parse` | 2350.8 / 2350.57 | -0.22 | 2361.39 | 92% | String, Hash |  | `app/views/layouts/application.html.erb:57` 32%, `app/views/layouts/application.html.erb:60` 32% | `Parser.parse(source, opts)` |
| 2 | `RUBY/pathname.rb:51` | `chop_basename` | 81.11 / 81.11 | 0.0 | 83.23 | 23% | String |  | `app/views/layouts/application.html.erb:60` 31%, `app/views/layouts/application.html.erb:57` 31% | `base = File.basename(path)` |
| 3 | `GEM/hashie/lib/hashie/mash.rb:374` | `convert_key` | 77.08 / 77.08 | 0.0 | 77.16 | 100% | String |  | `no app frame` 100%, `app/controllers/oauth_callbacks_controller.rb:33` 0% | `key.respond_to?(:to_sym) ? key.to_s : key` |
| 4 | `RUBY/pathname.rb:55` | `chop_basename` | 63.61 / 63.61 | 0.0 | 65.55 | 23% | String, Array |  | `app/views/layouts/application.html.erb:62` 31%, `app/views/layouts/application.html.erb:57` 31% | `return path[0, path.rindex(base)], base` |
| 5 | `GEM/hashie/lib/hashie/mash.rb:410` | `log_collision?` | 57.95 / 57.95 | 0.0 | 58.0 | 100% | Array |  | `no app frame` 100% | `return unless respond_to?(method_key)` |
| 6 | `GEM/hashie/lib/hashie/mash.rb:369` | `method_suffix` | 55.95 / 55.95 | 0.0 | 56.0 | 100% | String |  | `no app frame` 100% | `method_name = method_name.to_s` |
| 7 | `RUBY/pathname.rb:358` | `+` | 35.0 / 35.0 | 0.0 | 35.16 | 23% | String, Object |  | `app/views/layouts/application.html.erb:62` 32%, `app/views/layouts/application.html.erb:60` 32% | `Pathname.new(plus(@path, other.to_s))` |
| 8 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` | `within_new_transaction` | 30.05 / 30.05 | 0.0 | 30.31 | 10% | String, Array |  | `app/models/document.rb:240` 71%, `app/models/document.rb:181` 24% | `raise` |
| 9 | `GEM/commonmarker/lib/commonmarker/config.rb:94` | `process_plugins` | 25.73 / 25.73 | 0.0 | 25.78 | 23% | Array, Hash |  | `app/services/document_plain_text.rb:14` 47%, `app/services/document_title.rb:10` 28% | `Commonmarker::Config::OPTIONS[type].each_with_object({}) do \|(key, val` |
| 10 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | `#{method}` | 24.69 / 24.69 | 0.0 | 24.72 | 100% | Hash, Array |  | `no app frame` 32%, `app/controllers/application_controller.rb:62` 5% | `dispatch(:#{method}, ...)` |
| 11 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` | `each` | 21.76 / 21.76 | 0.0 | 21.77 | 81% | String, Array |  | `app/controllers/documents_controller.rb:51` 10%, `app/controllers/api/base_controller.rb:72` 9% | `val = step` |
| 12 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` | `html_safe` | 17.59 / 17.59 | 0.0 | 17.63 | 25% | String |  | `no app frame` 43%, `app/views/layouts/application.html.erb:60` 7% | `ActiveSupport::SafeBuffer.new(self)` |
| 13 | `RAILS/activerecord/lib/arel/table.rb:85` | `[]` | 17.56 / 17.56 | 0.0 | 17.6 | 86% | Struct |  | `app/controllers/documents_controller.rb:77` 21%, `app/models/activity.rb:11` 6% | `Attribute.new(table, name)` |
| 14 | `RUBY/pathname.rb:396` | `plus` | 17.5 / 17.5 | 0.0 | 17.58 | 23% | String, Struct |  | `app/views/layouts/application.html.erb:62` 32%, `app/views/layouts/application.html.erb:60` 32% | `suffix2 = path2[index_list2.first..-1]` |
| 15 | `RUBY/pathname.rb:397` | `plus` | 17.5 / 17.5 | 0.0 | 17.58 | 23% | String, Array |  | `app/views/layouts/application.html.erb:57` 32%, `app/views/layouts/application.html.erb:62` 32% | `r1 ? File.join(prefix1, suffix2) : prefix1 + suffix2` |
| 16 | `RAILS/activemodel/lib/active_model/attribute.rb:9` | `from_database` | 16.6 / 16.6 | 0.0 | 16.62 | 47% | Object |  | `app/controllers/api/docs_controller.rb:135` 22%, `app/models/document.rb:240` 12% | `FromDatabase.new(name, value_before_type_cast, type, nil, value)` |
| 17 | `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:75` | `initialize` | 16.17 / 16.17 | 0.0 | 16.2 | 100% | Array |  | `app/controllers/documents_controller.rb:149` 52%, `app/controllers/documents_controller.rb:50` 16% | `update(constructor)` |
| 18 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` | `call` | 16.1 / 16.1 | 0.0 | 16.11 | 100% | Data |  | `no app frame` 48%, `app/controllers/application_controller.rb:31` 12% | `result_lambda = -> { user_callback.call target, value }` |
| 19 | `GEM/hashie/lib/hashie/mash.rb:387` | `convert_value` | 15.98 / 15.98 | 0.0 | 16.0 | 100% | Array |  | `no app frame` 100% | `Array.new(val.map { \|e\| convert_value(e) })` |
| 20 | `GEM/uri/lib/uri/common.rb:456` | `_encode_uri_component` | 16.07 / 15.79 | -0.28 | 15.96 | 44% | String, MatchData |  | `no app frame` 100%, `app/controllers/concerns/authenticates_user.rb:56` 0% | `str.gsub!(regexp, table)` |
| 21 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` | `create` | 15.88 / 15.88 | 0.0 | 15.89 | 86% | Object, Array |  | `app/models/document.rb:111` 13%, `app/controllers/application_controller.rb:62` 6% | `relation_class_for(model).new(model, ...)` |
| 22 | `RUBY/ipaddr.rb:709` | `in_addr` | 15.86 / 15.86 | 0.0 | 15.87 | 100% | String, Array |  | `no app frame` 100% | `octets = addr.split('.')` |
| 23 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` | `build_handle` | 15.26 / 15.26 | 0.0 | 15.28 | 99% | Object | #59613 merged 2026-11-04, after this app's version, not released yet, #59235 merged 2026-10-21, after this app's version, not released yet | `no app frame` 13%, `app/controllers/application_controller.rb:62` 8% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 24 | `GEM/uri/lib/uri/common.rb:465` | `_decode_uri_component` | 13.69 / 13.59 | -0.1 | 13.66 | 58% | String, MatchData |  | `app/controllers/application_controller.rb:41` 76%, `no app frame` 23% | `str.b.gsub(regexp, TBLDECWWWCOMP_).force_encoding(enc)` |
| 25 | `RUBY/pathname.rb:419` | `join` | 13.39 / 13.39 | 0.0 | 13.44 | 24% | String, Object |  | `app/views/layouts/application.html.erb:62` 30%, `app/views/layouts/application.html.erb:57` 30% | `result = Pathname.new(result) unless Pathname === result` |
| 26 | `RAILS/activesupport/lib/active_support/core_ext/hash/indifferent_access.rb:10` | `with_indifferent_access` | 12.9 / 12.9 | 0.0 | 12.92 | 39% | Hash |  | `app/controllers/documents_controller.rb:149` 65%, `app/controllers/documents_controller.rb:50` 19% | `ActiveSupport::HashWithIndifferentAccess.new(self)` |
| 27 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:217` | `dispatch` | 12.35 / 12.35 | 0.0 | 12.36 | 100% | Array |  | `no app frame` 32%, `app/controllers/application_controller.rb:62` 5% | `@broadcasts.map { \|logger\|` |
| 28 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` | `tag_option` | 12.19 / 12.19 | 0.0 | 12.24 | 23% | String |  | `app/views/layouts/application.html.erb:60` 12%, `app/views/layouts/application.html.erb:62` 5% | `%(#{key}="#{value}")` |
| 29 | `GEM/sqlite3/lib/sqlite3/statement.rb:54` | `bind_params` | 12.06 / 12.06 | 0.0 | 12.08 | 82% | Array, Hash |  | `app/controllers/application_controller.rb:62` 11%, `app/models/activity.rb:11` 5% | `bind_vars.flatten.each do \|var\|` |
| 30 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:287` | `build_handle` | 12.01 / 12.01 | 0.0 | 12.02 | 100% | Array | #59235 merged 2026-10-21, after this app's version, not released yet | `no app frame` 25%, `app/controllers/application_controller.rb:62` 5% | `groups = groups_for(name).map do \|group_klass, grouped_listeners\|` |

## Dev/test-mode work

5335.1 of 10211.7 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | error page | `RUBY/error_highlight/base.rb:94` | 1709.02 | 1% | `no app frame` 100% | `Prism.parse_file(absolute_path).value.breadth_first_search { \|node\| no` |
| 2 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/manifest.rb:156` | 962.36 | 21% | `app/views/layouts/application.html.erb:60` 33%, `app/views/layouts/application.html.erb:62` 33% | `File.join(vite_asset_origin \|\| "/", config.public_output_dir, path)` |
| 3 | error page | `GEM/prism/lib/prism/parse_result.rb:70` | 696.63 | 1% | `no app frame` 100% | `source.lines` |
| 4 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/manifest.rb:167` | 320.79 | 21% | `app/views/layouts/application.html.erb:62` 33%, `app/views/layouts/application.html.erb:57` 33% | `config.origin if dev_server_running? && config.skip_proxy` |
| 5 | asset lookup | `GEM/vite_ruby/lib/vite_ruby.rb:88` † | 314.95 | 21% | `app/views/layouts/application.html.erb:62` 33%, `app/views/layouts/application.html.erb:60` 33% | `return @running if defined?(@running) && Time.now - @running_checked_a` |
| 6 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/manifest.rb:174` | 314.4 | 21% | `app/views/layouts/application.html.erb:62` 33%, `app/views/layouts/application.html.erb:60` 33% | `%w[css assets].each do \|key\|` |
| 7 | error page | `GEM/prism/lib/prism/node.rb:2797` | 71.4 | 1% | `no app frame` 100% | `compact = [] #: Array[Prism::node]` |
| 8 | error page | `RAILS/actionpack/lib/action_dispatch/middleware/exception_wrapper.rb:332` | 70.78 | 1% | `no app frame` 100% | `lines = source_lines.drop(start).take(6)` |
| 9 | error page | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:195` | 59.25 | 1% | `no app frame` 100% | `add_filter { \|line\| line.sub(gems_regexp, gems_result) }` |
| 10 | error page | `GEM/prism/lib/prism/node.rb:18058` | 47.64 | 1% | `no app frame` 100% | `[*body]` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| gem: json | 2354.4 | 2365.1 | `common.rb:364` 2350.7, `common.rb:1089` 3.6, `common.rb:454` 0.1 |
| ruby stdlib | 2061.9 | 2158.0 | `base.rb:94` 1709.0, `pathname.rb:51` 81.1, `pathname.rb:55` 63.6 |
| gem: vite_ruby | 1985.6 | 1995.9 | `manifest.rb:156` 962.4, `manifest.rb:167` 320.8, `vite_ruby.rb:88` 315.0 |
| ruby default gem: prism | 1090.5 | 1146.5 | `parse_result.rb:70` 696.6, `node.rb:2797` 71.4, `node.rb:18058` 47.6 |
| rails: activesupport | 676.8 | 687.0 | `backtrace_cleaner.rb:195` 59.2, `log_subscriber.rb:177` 35.2, `broadcast_logger.rb:129` 24.7 |
| rails: activerecord | 657.6 | 660.7 | `log_subscriber.rb:49` 41.3, `transaction.rb:653` 30.1, `table.rb:85` 17.6 |
| rails: actionpack | 362.4 | 377.4 | `exception_wrapper.rb:332` 70.8, `logger.rb:12` 20.0, `exception_wrapper.rb:333` 11.4 |
| app | 246.8 | 252.3 | `segmenter.rb:42` 30.6, `document_social_preview.rb:62` 25.3, `agent_guide.rb:693` 11.9 |
| gem: hashie | 237.0 | 237.2 | `mash.rb:374` 77.1, `mash.rb:410` 57.9, `mash.rb:369` 55.9 |
| rails: actionview | 133.3 | 137.3 | `tag_helper.rb:309` 12.2, `buffers.rb:44` 11.1, `tag_helper.rb:237` 5.8 |
| rails: activemodel | 77.5 | 79.5 | `attribute.rb:9` 16.6, `string.rb:39` 7.7, `attribute.rb:13` 5.1 |
| gem: inertia_rails | 75.7 | 76.0 | `props_resolver.rb:81` 9.4, `props_resolver.rb:82` 8.3, `testing.rb:24` 7.8 |
| gem: sqlite3 | 61.9 | 62.2 | `statement.rb:125` 21.8, `statement.rb:54` 12.1, `statement.rb:186` 7.8 |
| gem: rack | 61.8 | 62.6 | `request.rb:693` 7.5, `request.rb:604` 5.5, `builder.rb:164` 4.0 |
| gem: nokogiri | 53.7 | 57.8 | `document_fragment.rb:166` 4.3, `node.rb:66` 4.0, `searchable.rb:270` 3.3 |
| ruby default gem: uri | 51.6 | 51.9 | `common.rb:456` 15.9, `common.rb:465` 13.6, `common.rb:90` 2.5 |
| ruby default gem: logger | 44.4 | 44.5 | `log_device.rb:33` 12.3, `log_device.rb:165` 12.3, `logger.rb:692` 12.2 |
| gem: commonmarker | 31.6 | 31.6 | `config.rb:94` 25.7, `commonmarker.rb:44` 3.4, `config.rb:78` 0.5 |
| gem: tzinfo | 20.4 | 22.3 | `timestamp.rb:208` 8.7, `timestamp.rb:193` 4.8, `constant_offset_data_timezone_info.rb:52` 4.5 |
| gem: concurrent-ruby | 19.8 | 19.9 | `safe_initialization.rb:30` 6.0, `non_concurrent_map_backend.rb:131` 2.4, `mutex_lockable_object.rb:32` 2.0 |
| gem: propshaft | 16.1 | 16.6 | `asset.rb:73` 3.4, `helper.rb:128` 3.0, `server.rb:16` 1.7 |
| gem: useragent | 15.5 | 16.4 | `base.rb:120` 4.8, `version.rb:27` 3.2, `user_agent.rb:25` 1.1 |
| gem: i18n | 13.6 | 13.6 | `base.rb:157` 1.9, `i18n.rb:396` 1.8, `ruby.rb:33` 1.7 |
| gem: omniauth | 10.3 | 10.4 | `strategy.rb:470` 2.2, `strategy.rb:169` 2.0, `strategy.rb:458` 1.0 |
| gem: vite_rails | 10.0 | 10.1 | `tag_helpers.rb:106` 1.7, `tag_helpers.rb:59` 0.9, `tag_helpers.rb:46` 0.9 |
| gem: globalid | 9.4 | 9.4 | `gid.rb:95` 2.5, `gid.rb:159` 2.0, `gid.rb:166` 1.0 |
| rails: railties | 9.0 | 9.1 | `logger.rb:57` 3.0, `engine.rb:748` 1.0, `logger.rb:42` 1.0 |
| gem: erubi | 8.5 | 8.9 | `erubi.rb:134` 4.7, `erubi.rb:137` 1.1, `erubi.rb:139` 0.6 |
| gem: ruby-vips | 8.4 | 9.1 | `object.rb:203` 0.8, `object.rb:201` 0.8, `object.rb:202` 0.8 |
| gem: flipper | 7.5 | 7.5 | `memoizer.rb:89` 1.0, `memoizer.rb:67` 1.0, `memoizer.rb:73` 1.0 |
| gem: base64 | 6.7 | 6.7 | `base64.rb:310` 3.8, `base64.rb:283` 2.9, `base64.rb:374` 0.0 |
| rails: actioncable | 6.1 | 6.1 | `broadcasting.rb:53` 1.3, `broadcasting.rb:25` 1.3, `broadcasting.rb:41` 0.9 |
| gem: marcel | 5.7 | 7.5 | `magic.rb:140` 1.8, `magic.rb:135` 1.7, `magic.rb:136` 1.7 |
| gem: loofah | 4.7 | 5.6 | `concerns.rb:172` 2.0, `concerns.rb:43` 1.0, `scrubber.rb:132` 0.6 |
| gem: ffi | 4.2 | 4.5 | `managedstruct.rb:80` 1.4, `autopointer.rb:88` 1.0, `struct_by_reference.rb:69` 0.5 |
| rails: activestorage | 3.3 | 3.6 | `filename.rb:60` 0.4, `disk_service.rb:131` 0.2, `disk_service.rb:196` 0.2 |
| gem: rack-session | 3.0 | 3.0 | `id.rb:277` 1.0, `id.rb:275` 1.0, `id.rb:368` 0.6 |
| gem: ruby_native | 2.7 | 2.8 | `oauth_middleware.rb:18` 1.0, `oauth_middleware.rb:53` 1.0, `native_detection.rb:20` 0.5 |
| gem: rails-html-sanitizer | 2.7 | 3.2 | `sanitizer.rb:33` 0.5, `sanitizer.rb:191` 0.5, `sanitizer.rb:56` 0.5 |
| ruby default gem: securerandom | 2.1 | 2.1 | `securerandom.rb:71` 2.1 |
| gem: bcrypt | 1.5 | 1.5 | `password.rb:102` 0.5, `password.rb:103` 0.2, `engine.rb:70` 0.2 |
| gem: bootsnap | 1.3 | 1.7 | `kernel_require.rb:11` 0.9, `iseq.rb:98` 0.2, `iseq.rb:154` 0.1 |
| rails: activejob | 1.0 | 1.0 | `log_subscriber.rb:207` 0.1, `queue_adapter.rb:11` 0.1, `log_subscriber.rb:201` 0.1 |
| ruby default gem: prettyprint | 0.2 | 0.2 | `prettyprint.rb:403` 0.1, `prettyprint.rb:263` 0.0, `prettyprint.rb:458` 0.0 |
| ruby default gem: pp | 0.1 | 0.1 | `pp.rb:542` 0.0, `pp.rb:271` 0.0, `pp.rb:550` 0.0 |
| gem: zeitwerk | 0.1 | 0.2 | `cref.rb:47` 0.0, `constant_path_validator.rb:13` 0.0, `file_system.rb:203` 0.0 |
| gem: omniauth-rails_csrf_protection | 0.0 | 0.0 | `token_verifier.rb:59` 0.0, `token_verifier.rb:55` 0.0 |
| gem: y-rb | 0.0 | 0.0 | `doc.rb:212` 0.0, `doc.rb:58` 0.0, `transaction.rb:105` 0.0 |
| gem: omniauth-google-oauth2 | 0.0 | 0.0 | `google_oauth2.rb:108` 0.0 |
| gem: flipper-ui | 0.0 | 0.2 | `ui.rb:49` 0.0, `features.rb:13` 0.0, `action.rb:219` 0.0 |
| gem: bigdecimal | 0.0 | 0.0 | `util.rb:24` 0.0, `util.rb:51` 0.0 |
| ruby default gem: erb | 0.0 | 0.0 | `erb.rb:872` 0.0, `compiler.rb:467` 0.0, `compiler.rb:256` 0.0 |
| gem: sanitize | 0.0 | 0.1 | `clean_element.rb:67` 0.0, `sanitize.rb:176` 0.0, `sanitize.rb:204` 0.0 |
| gem: racc | 0.0 | 0.1 | `parser.rb:263` 0.0 |
| gem: rack-protection | 0.0 | 0.0 | `base.rb:41` 0.0, `authenticity_token.rb:110` 0.0 |
| gem: msgpack | 0.0 | 0.0 | `factory.rb:9` 0.0, `factory.rb:27` 0.0, `factory.rb:16` 0.0 |
| ruby default gem: bundler | 0.0 | 0.0 | `rubygems_integration.rb:192` 0.0 |
| rails: actiontext | 0.0 | 0.1 | `serialization.rb:6` 0.0, `content.rb:0` 0.0, `serialization.rb:7` 0.0 |
| lowrail-profile | 0.0 | 0.0 | `profile.rb:65` 0.0 |
| other | 0.0 | 0.0 | `(erb):1` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Jobs

| # | Job | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | WritingReviewerJob#perform | 9 / 9 | 6574.0 / 6578.8 | 4.8 | 6411.2 | `GEM/json/lib/json/common.rb:364` 166.8, `RAILS/activemodel/lib/active_model/attribute.rb:9` 93.6, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 78.5 | `app/jobs/writing_reviewer_job.rb:58` 773.3, `app/models/writing_pass.rb:143` 504.0, `app/models/writing_pass.rb:128` 442.3 |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/json/lib/json/common.rb:364` | 148.22 / 148.22 | 89% | `app/models/writing_pass.rb:143` 33%, `app/models/writing_pass.rb:128` 28% | `Parser.parse(source, opts)` |
| 2 | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` (debug logging) | 144.22 / 144.22 | 100% | `app/jobs/writing_reviewer_job.rb:58` 55%, `app/models/writing_pass.rb:143` 13% | `binds = binds.inspect` |
| 3 | `RAILS/activesupport/lib/active_support/log_subscriber.rb:177` (debug logging) | 93.33 / 93.33 | 100% | `app/models/writing_pass.rb:128` 28%, `app/jobs/writing_reviewer_job.rb:58` 27% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 4 | `RAILS/activemodel/lib/active_model/attribute.rb:9` | 83.22 / 83.22 | 89% | `app/models/writing_pass.rb:143` 55%, `app/jobs/writing_reviewer_job.rb:58` 27% | `FromDatabase.new(name, value_before_type_cast, type, nil, value)` |
| 5 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` | 69.78 / 69.78 | 100% | `app/jobs/writing_reviewer_job.rb:58` 30%, `app/models/writing_pass.rb:145` 28% | `val = step` |
| 6 | `RAILS/activesupport/lib/active_support/log_subscriber.rb:175` (debug logging) | 62.22 / 62.22 | 100% | `app/models/writing_pass.rb:128` 28%, `app/jobs/writing_reviewer_job.rb:58` 27% | `modes = MODES.values_at(*options.compact_blank.keys)` |
| 7 | `RAILS/activerecord/lib/active_record/log_subscriber.rb:77` (debug logging) | 44.44 / 44.44 | 100% | `app/jobs/writing_reviewer_job.rb:58` 57%, `app/models/writing_pass.rb:143` 13% | `[attr&.name, value]` |
| 8 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | 41.78 / 41.78 | 100% | `app/models/writing_pass.rb:128` 21%, `app/jobs/writing_reviewer_job.rb:58` 20% | `dispatch(:#{method}, ...)` |
| 9 | `RAILS/activerecord/lib/arel/table.rb:85` | 37.56 / 37.56 | 89% | `app/jobs/writing_reviewer_job.rb:58` 62%, `app/models/writing_pass.rb:143` 15% | `Attribute.new(table, name)` |
| 10 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` | 32.89 / 32.89 | 100% | `app/models/writing_pass.rb:128` 27%, `app/jobs/writing_reviewer_job.rb:58` 25% | `group_klass.new(grouped_listeners, name, id, payload)` |

### Action Cable

| # | Channel action | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | SyncChannel#subscribed | 33 / 33 | 809.4 / 809.4 | 0.0 | 803.6 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` 19.1, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 16.5, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 16.3 | `app/services/yjs_persistence.rb:116` 155.4, `app/models/document.rb:111` 83.7, `app/channels/sync_channel.rb:44` 68.5 |
| 2 | SyncChannel#receive | 23 / 23 | 677.5 / 677.7 | 0.2 | 652.3 | `RAILS/activesupport/lib/active_support/parameter_filter.rb:112` 29.4, `RAILS/activemodel/lib/active_model/attribute.rb:9` 18.2, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 16.9 | `app/services/yjs_persistence.rb:54` 146.0, `app/services/yjs_persistence.rb:89` 111.8, `app/services/yjs_persistence.rb:56` 69.8 |
| 3 | DocumentMetaChannel#subscribed | 2 / 2 | 190.0 / 190.0 | 0.0 | 214.0 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` 16.0, `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/synchronization/safe_initialization.rb:30` 12.0, `RAILS/activesupport/lib/active_support/callbacks.rb:103` 6.0 | `app/channels/document_meta_channel.rb:6` 44.0, `app/channels/document_meta_channel.rb:9` 0.0, `app/channels/document_meta_channel.rb:10` 0.0 |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` (debug logging) | 25.03 / 25.03 | 85% | `app/channels/sync_channel.rb:44` 16%, `app/services/yjs_persistence.rb:116` 15% | `binds = binds.inspect` |
| 2 | `RAILS/activesupport/lib/active_support/log_subscriber.rb:177` (debug logging) | 21.93 / 21.93 | 85% | `app/services/yjs_persistence.rb:54` 17%, `app/channels/sync_channel.rb:44` 15% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 3 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` | 17.19 / 17.19 | 79% | `app/channels/sync_channel.rb:44` 45%, `app/services/yjs_persistence.rb:56` 17% | `val = step` |
| 4 | `RAILS/activesupport/lib/active_support/log_subscriber.rb:175` (debug logging) | 14.62 / 14.62 | 85% | `app/services/yjs_persistence.rb:54` 17%, `app/channels/sync_channel.rb:44` 15% | `modes = MODES.values_at(*options.compact_blank.keys)` |
| 5 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` | 12.07 / 12.07 | 79% | `app/services/yjs_persistence.rb:116` 45%, `app/models/document.rb:111` 17% | `relation_class_for(model).new(model, ...)` |
| 6 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | 11.59 / 11.59 | 69% | `app/services/yjs_persistence.rb:116` 37%, `app/models/document.rb:111` 34% | `WhereClause.new(predicates \| other.predicates)` |
| 7 | `RAILS/activesupport/lib/active_support/parameter_filter.rb:112` | 11.14 / 11.14 | 35% | `no app frame` 100% | `s = Regexp.escape(item.to_s)` |
| 8 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | 9.52 / 9.52 | 95% | `config/initializers/yjs_instrumentation.rb:52` 18%, `app/services/yjs_persistence.rb:54` 13% | `dispatch(:#{method}, ...)` |
| 9 | `RAILS/activemodel/lib/active_model/attribute.rb:9` | 9.12 / 9.12 | 26% | `app/services/yjs_persistence.rb:54` 57%, `app/services/yjs_persistence.rb:426` 15% | `FromDatabase.new(name, value_before_type_cast, type, nil, value)` |
| 10 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` | 8.19 / 8.19 | 90% | `app/services/yjs_persistence.rb:54` 15%, `app/channels/sync_channel.rb:44` 14% | `group_klass.new(grouped_listeners, name, id, payload)` |
