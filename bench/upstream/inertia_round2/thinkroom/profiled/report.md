# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails test -v`
* Ruby: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux]
* Rails: 8.1.3.1, test environment
* Counted in run 1: 1051 requests, 9 jobs, 58 Cable actions; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1
* Not attributed: 0.0 objects per request (0.0% of all) are on lines outside the app, Rails, Ruby and the bundle's gems, which no table below ranks; most in `(erb)`

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 1051 | 10236.2 | 9 | 0 | 58 | 0 |
| run2 | 1 | 1051 | 10251.6 | 9 | 0 | 58 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.16 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/views/layouts/application.html.erb:60` |  | 755.75 | 524.59 | 0.62 | `GEM/json/lib/json/common.rb:364` 97%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:52` 0%, `RAILS/activesupport/lib/active_support/testing/time_helpers.rb:179` 0% | DocumentsController#index 49%, DocumentsController#show 46%, SessionsController#new 3% | `<%= vite_typescript_tag "inertia.tsx" %>` |
| 2 | `app/views/layouts/application.html.erb:62` |  | 752.83 | 525.56 | 0.62 | `GEM/json/lib/json/common.rb:364` 98%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:52` 0%, `RAILS/activesupport/lib/active_support/testing/time_helpers.rb:179` 0% | DocumentsController#index 49%, DocumentsController#show 46%, SessionsController#new 3% | `<%= vite_typescript_tag 'application' %>` |
| 3 | `app/views/layouts/application.html.erb:57` |  | 752.1 | 517.11 | 0.62 | `GEM/json/lib/json/common.rb:364` 98%, `RAILS/activesupport/lib/active_support/testing/time_helpers.rb:179` 0%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:52` 0% | DocumentsController#index 49%, DocumentsController#show 46%, SessionsController#new 3% | `<%= vite_stylesheet_tag "application" %>` |
| 4 | `app/controllers/documents_controller.rb:149` | `show` | 90.85 | 7.53 | 0.4 | `GEM/json/lib/json/common.rb:364` 31%, `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:75` 9%, `RAILS/activesupport/lib/active_support/core_ext/hash/indifferent_access.rb:10` 9% | DocumentsController#show 100% | `render inertia: "documents/show", props: {` |
| 5 | `app/controllers/application_controller.rb:62` | `current_user` | 74.42 | 16.9 | 1.1 | `RAILS/activesupport/lib/active_support/key_generator.rb:63` 4%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:55` 3%, `GEM/json/lib/json/common.rb:364` 2% | DocumentsController#index 19%, DocumentsController#show 19%, CommentsController#create 14% | `@current_user = User.find_by(id: session[:user_id])` |
| 6 | `app/controllers/documents_controller.rb:50` | `index` | 58.18 | 7.96 | 0.42 | `GEM/json/lib/json/common.rb:364` 14%, `GEM/inertia_rails/lib/inertia_rails/ssr.rb:14` 6%, `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:75` 5% | DocumentsController#index 100% | `render inertia: "documents/index", props: {` |
| 7 | `app/controllers/documents_controller.rb:77` | `index` | 54.88 | 3.47 | 0.11 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` 18%, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:178` 15%, `GEM/sqlite3/lib/sqlite3/statement.rb:186` 11% | DocumentsController#index 100% | `.map { \|pin\| with_ownership.(pin.document).merge(pinned_at: pin.create` |
| 8 | `app/models/activity.rb:11` | `log!` | 39.61 | 14.75 | 0.18 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 3%, `RAILS/activemodel/lib/active_model/attribute.rb:13` 3%, `GEM/sqlite3/lib/sqlite3/statement.rb:58` 3% | Api::DocsController#update 50%, Api::DocsController#create 19%, Api::DocsController#show 5% | `activity = create!(document:, actor_name:, actor_kind:, action:, detai` |
| 9 | `app/models/document.rb:240` | `with_comment_access` | 39.23 | 6.07 | 0.07 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 55%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 5%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 3% | CommentsController#create 91%, CommentsController#resolve 4%, Api::CommentsController#create 3% | `with_lock do` |
| 10 | `app/models/document.rb:111` | `live_crdt?` | 33.6 | 8.96 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:111` 3%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 3% | Api::DocsController#update 63%, DocumentsController#show 37% | `yjs_state.present? \|\| yjs_document_updates.exists?` |
| 11 | `app/controllers/application_controller.rb:41` | `ensure_owner_token` | 32.85 | 0.0 | 0.0 | `GEM/uri/lib/uri/common.rb:465` 14%, `GEM/json/lib/json/common.rb:364` 9%, `GEM/rack/lib/rack/utils.rb:331` 9% | DocumentsController#show 16%, CommentsController#create 14%, DocumentsController#index 13% | `return if cookies.signed[:owner_token].present?` |
| 12 | `app/models/document_asset.rb:36` | `store!` | 30.06 | 5.57 | 0.0 | `RAILS/activemodel/lib/active_model/attribute_set.rb:47` 2%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 2%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 2% | Api::UploadsController#create 100% | `asset.file.attach(blob)` |
| 13 | `app/channels/document_meta_channel.rb:14` | `broadcast_event` | 25.45 | 2.51 | 0.84 | `GEM/uri/lib/uri/common.rb:90` 8%, `GEM/globalid/lib/global_id/uri/gid.rb:95` 8%, `GEM/globalid/lib/global_id/uri/gid.rb:159` 7% | DocumentsController#claim 35%, Api::DocsController#update 20%, Api::DocsController#create 8% | `broadcast_to(document, { event: event.to_s, **payload })` |
| 14 | `app/controllers/application_controller.rb:56` | `owner_token` | 23.8 | 0.0 | 0.0 | `GEM/json/lib/json/common.rb:364` 25%, `RAILS/actionpack/lib/action_dispatch/middleware/cookies.rb:639` 7%, `RAILS/activesupport/lib/active_support/message_verifier.rb:325` 7% | DocumentsController#index 29%, DocumentsController#show 25%, DocumentsController#claim 9% | `cookies.signed[:owner_token]` |
| 15 | `app/models/document.rb:340` | `claim!` | 22.2 | 4.03 | 0.08 | `RAILS/activemodel/lib/active_model/attribute.rb:13` 3%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 3%, `RAILS/activemodel/lib/active_model/type/string.rb:39` 2% | DocumentsController#claim 94%, DocumentsController#show 6% | `activity = activities.create!(` |
| 16 | `app/controllers/application_controller.rb:47` | `replace_owner_token!` | 21.86 | 0.0 | 0.33 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:146` 9%, `RAILS/activesupport/lib/active_support/core_ext/hash/keys.rb:35` 9%, `GEM/tzinfo/lib/tzinfo/timestamp.rb:208` 6% | SessionsController#create 33%, DocumentsController#index 20%, DocumentsController#show 19% | `cookies.permanent.signed[:owner_token] = {` |
| 17 | `app/models/comment.rb:16` | `post!` | 21.21 | 0.28 | 0.06 | `GEM/i18n/lib/i18n/backend/base.rb:157` 4%, `GEM/i18n/lib/i18n/interpolate/ruby.rb:33` 4%, `GEM/i18n/lib/i18n.rb:396` 4% | CommentsController#create 99%, Api::CommentsController#create 1% | `comment = document.comments.create!(author_name:, author_kind:, body:,` |
| 18 | `app/models/document.rb:181` | `with_write_access` | 20.52 | 4.69 | 0.06 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 33%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 8%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 4% | WritingPassesController#create 37%, SuggestionsController#create 19%, Api::SuggestionsController#create 12% | `with_lock do` |
| 19 | `app/controllers/api/docs_controller.rb:135` | `update` | 17.67 | 1.75 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 21%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 10%, `RAILS/activesupport/lib/active_support/callbacks.rb:362` 9% | Api::DocsController#update 100% | `document.save!` |
| 20 | `app/controllers/application_controller.rb:31` | `extend_remembered_session` | 16.3 | 0.17 | 0.0 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` 11%, `RAILS/actionpack/lib/action_controller/metal/rate_limiting.rb:75` 8%, `RAILS/activesupport/lib/active_support/cache.rb:953` 6% | CommentsController#create 23%, DocumentPinsController#create 22%, SessionsController#create 17% | `yield` |
| 21 | `app/controllers/api/docs_controller.rb:34` | `create` | 16.02 | 6.83 | 0.03 | `RAILS/activemodel/lib/active_model/attribute.rb:9` 5%, `RAILS/activerecord/lib/arel/table.rb:85` 5%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 5% | Api::DocsController#create 100% | `doc = Document.create!(` |
| 22 | `app/controllers/documents_controller.rb:194` | `show` | 14.64 | 3.29 | 0.29 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 3%, `RAILS/activerecord/lib/active_record/relation.rb:77` 3% | DocumentsController#show 100% | `suggestions: -> { document.suggestions.pending.order(:created_at).map(` |
| 23 | `app/services/document_plain_text.rb:14` | `call` | 14.6 | 0.0 | 0.0 | `GEM/commonmarker/lib/commonmarker/config.rb:94` 82%, `GEM/commonmarker/lib/commonmarker.rb:44` 11%, `GEM/commonmarker/lib/commonmarker/config.rb:79` 2% | DocumentsController#show 46%, Api::DocsController#update 37%, Api::DocsController#create 13% | `Commonmarker.to_html(source, plugins: MARKDOWN_PLUGINS)` |
| 24 | `app/models/document.rb:331` | `claim!` | 14.32 | 5.6 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:146` 7%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:141` 5%, `RAILS/activerecord/lib/arel/table.rb:85` 3% | DocumentsController#claim 94%, DocumentsController#show 6% | `.update_all(attributes) == 1` |
| 25 | `app/controllers/documents_controller.rb:195` | `show` | 14.11 | 2.87 | 0.19 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `RAILS/activerecord/lib/active_record/relation.rb:77` 3%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 3% | DocumentsController#show 100% | `comments: -> { document.comments.order(:created_at).map(&:as_props) },` |
| 26 | `app/controllers/documents_controller.rb:197` | `show` | 14.03 | 3.65 | 0.2 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `RAILS/activerecord/lib/active_record/relation.rb:77` 3%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 3% | DocumentsController#show 100% | `presences: -> { document.agent_presences.active.map(&:as_props) },` |
| 27 | `app/controllers/documents_controller.rb:196` | `show` | 13.62 | 3.25 | 0.19 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `RAILS/activerecord/lib/active_record/relation.rb:77` 3%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 3% | DocumentsController#show 100% | `activities: -> { document.activities.recent.map(&:as_props) },` |
| 28 | `app/models/user.rb:56` | `adopt_pins!` | 12.59 | 2.26 | 0.2 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 4%, `RAILS/activerecord/lib/active_record/relation.rb:77` 3%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 3% | SessionsController#create 93%, OauthCallbacksController#create 4%, RegistrationsController#create 3% | `guest_pins.where(document_id: document_pins.select(:document_id)).dele` |
| 29 | `app/models/user.rb:38` | `claim_documents!` | 11.92 | 4.6 | 0.07 | `RAILS/activerecord/lib/arel/table.rb:85` 4%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:146` 3%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:68` 3% | SessionsController#create 93%, OauthCallbacksController#create 4%, RegistrationsController#create 3% | `Document.where(user_id: nil, owner_token:).update_all(` |
| 30 | `app/controllers/inertia_controller.rb:17` | `safe_vite_digest` | 11.07 | 20.9 | 0.0 | `RUBY/digest.rb:64` 60%, `RUBY/digest.rb:65` 20%, `RUBY/digest.rb:49` 20% | DocumentsController#show 57%, DocumentsController#index 36%, SessionsController#new 7% | `DIGEST_LOCK.synchronize { @last_digest = ViteRuby.digest }` |

721.9 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | FeedbackRunsController#show | 2 / 2 | 379784.0 / 379776.0 | -8.0 | 190912.0 | `RAILS/actionview/lib/action_view/buffers.rb:44` 1471.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 673.0, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:11` 658.0 | `app/controllers/feedback_runs_controller.rb:45` 205.0, `app/controllers/application_controller.rb:62` 136.0, `app/controllers/application_controller.rb:41` 68.0 |
| 2 | DocumentOgImagesController#show | 4 / 4 | 104312.7 / 104312.7 | 0.0 | 78651.8 | `RAILS/actionview/lib/action_view/buffers.rb:44` 449.3, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 206.3, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:11` 201.3 | `app/controllers/document_og_images_controller.rb:7` 75.3, `app/controllers/document_og_images_controller.rb:10` 64.0, `app/controllers/document_og_images_controller.rb:16` 37.0 |
| 3 | (no action name) | 15 / 15 | 76413.9 / 76413.2 | -0.6 | 71365.7 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 259.7, `GEM/nokogiri/lib/nokogiri/html5/node.rb:66` 252.4, `GEM/nokogiri/lib/nokogiri/xml/document.rb:416` 252.0 | `app/constraints/admin_constraint.rb:8` 26.9, `app/constraints/admin_constraint.rb:11` 21.1 |
| 4 | DocumentsController#update_editing_lock | 9 / 9 | 45667.0 / 45668.6 | 1.6 | 40858.3 | `RAILS/actionview/lib/action_view/buffers.rb:44` 170.4, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 78.1, `GEM/hashie/lib/hashie/mash.rb:374` 77.0 | `app/models/document.rb:265` 183.0, `app/models/document.rb:271` 139.0, `app/models/document.rb:270` 137.0 |
| 5 | DocumentsController#index | 111 / 111 | 21650.9 / 21648.3 | -2.5 | 21850.1 | `GEM/json/lib/json/common.rb:364` 10461.4, `RAILS/activerecord/lib/arel/alias_predication.rb:8` 96.3, `RAILS/activerecord/lib/active_record/associations/join_dependency.rb:178` 80.7 | `app/views/layouts/application.html.erb:60` 3556.7, `app/views/layouts/application.html.erb:62` 3551.2, `app/views/layouts/application.html.erb:57` 3535.3 |
| 6 | SessionsController#new | 7 / 7 | 20748.8 / 20746.3 | -2.5 | 20730.6 | `GEM/json/lib/json/common.rb:364` 10774.8, `RUBY/digest.rb:64` 83.0, `GEM/hashie/lib/hashie/mash.rb:374` 77.0 | `app/views/layouts/application.html.erb:57` 3699.2, `app/views/layouts/application.html.erb:60` 3643.0, `app/views/layouts/application.html.erb:62` 3625.0 |
| 7 | DocumentsController#show | 126 / 126 | 19504.7 / 19618.2 | 113.5 | 19671.9 | `GEM/json/lib/json/common.rb:364` 8863.5, `GEM/commonmarker/lib/commonmarker/config.rb:94` 112.4, `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:75` 79.0 | `app/views/layouts/application.html.erb:60` 2933.0, `app/views/layouts/application.html.erb:57` 2919.1, `app/views/layouts/application.html.erb:62` 2914.8 |
| 8 | IdentitiesController#update | 20 / 20 | 18652.8 / 18652.4 | -0.4 | 17779.6 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `RAILS/actionview/lib/action_view/buffers.rb:44` 70.4, `GEM/hashie/lib/hashie/mash.rb:410` 58.0 | `app/controllers/identities_controller.rb:16` 60.6, `app/controllers/application_controller.rb:47` 50.1, `app/controllers/identities_controller.rb:11` 40.6 |
| 9 | CliAuthorizationsController#show | 6 / 6 | 16733.6 / 16738.2 | 4.6 | 18079.0 | `GEM/json/lib/json/common.rb:364` 8629.2, `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0 | `app/views/layouts/application.html.erb:60` 2914.4, `app/views/layouts/application.html.erb:62` 2900.0, `app/views/layouts/application.html.erb:57` 2896.8 |
| 10 | DocumentsController#claim | 83 / 83 | 10597.3 / 10597.4 | 0.1 | 10496.3 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0, `GEM/hashie/lib/hashie/mash.rb:369` 56.0 | `app/models/document.rb:340` 267.3, `app/models/document.rb:331` 172.7, `app/controllers/application_controller.rb:62` 123.4 |
| 11 | DocumentPinsController#create | 69 / 69 | 6220.7 / 6220.8 | 0.1 | 6164.8 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0, `GEM/hashie/lib/hashie/mash.rb:369` 56.0 | `app/controllers/application_controller.rb:62` 115.2, `app/models/document_pin.rb:36` 74.9, `app/controllers/document_pins_controller.rb:18` 60.2 |
| 12 | WritingPassesController#create | 26 / 26 | 5370.8 / 5370.0 | -0.8 | 5409.5 | `GEM/json/lib/json/common.rb:364` 269.2, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 124.4, `GEM/hashie/lib/hashie/mash.rb:374` 77.0 | `app/models/document.rb:181` 322.4, `app/services/compound_writing/lens_set.rb:10` 244.6, `app/models/writing_pack.rb:26` 204.2 |
| 13 | Api::UploadsController#create | 33 / 33 | 3974.8 / 3974.4 | -0.3 | 3894.8 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0, `GEM/hashie/lib/hashie/mash.rb:369` 56.0 | `app/models/document_asset.rb:36` 987.3, `app/models/document_asset.rb:23` 278.8, `app/models/document_asset.rb:27` 260.5 |
| 14 | Api::DocsController#show | 10 / 10 | 3550.2 / 3550.3 | 0.1 | 3310.6 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0, `GEM/hashie/lib/hashie/mash.rb:369` 56.0 | `app/models/agent_presence.rb:25` 370.7, `app/models/activity.rb:11` 217.8, `app/services/agent_guide.rb:171` 170.6 |
| 15 | Api::CommentsController#resolve | 4 / 4 | 3122.7 / 3122.7 | 0.0 | 2678.3 | `RAILS/activemodel/lib/active_model/attribute_methods.rb:492` 280.0, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 169.7, `GEM/hashie/lib/hashie/mash.rb:374` 77.0 | `app/models/agent_presence.rb:17` 949.3, `app/models/document.rb:240` 404.0, `app/controllers/api/comments_controller.rb:31` 140.3 |
| 16 | FeedbackRunsController#create | 10 / 10 | 2894.6 / 2890.7 | -3.9 | 3989.5 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0, `GEM/hashie/lib/hashie/mash.rb:369` 56.0 | `app/controllers/feedback_runs_controller.rb:21` 393.1, `app/controllers/feedback_runs_controller.rb:19` 309.7, `app/controllers/application_controller.rb:62` 133.3 |
| 17 | Api::SuggestionsController#create | 10 / 10 | 2712.6 / 2712.1 | -0.4 | 2822.6 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 85.2, `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0 | `app/models/document.rb:181` 297.9, `app/models/activity.rb:11` 213.8, `app/models/agent_presence.rb:25` 208.9 |
| 18 | SuggestionsController#reopen | 2 / 2 | 2655.0 / 2656.0 | 1.0 | 2446.5 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 72.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0 | `app/models/document.rb:181` 236.0, `app/models/activity.rb:11` 178.0, `app/controllers/suggestions_controller.rb:90` 138.0 |
| 19 | RegistrationsController#create | 3 / 3 | 2647.5 / 2649.5 | 2.0 | 2884.3 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0, `GEM/hashie/lib/hashie/mash.rb:369` 56.0 | `app/controllers/registrations_controller.rb:11` 367.0, `app/models/user.rb:56` 189.0, `app/models/user.rb:38` 179.0 |
| 20 | CommentsController#create | 69 / 69 | 2630.0 / 2630.4 | 0.4 | 2667.9 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 316.7, `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0 | `app/models/document.rb:240` 549.2, `app/models/comment.rb:16` 323.2, `app/controllers/application_controller.rb:62` 160.8 |
| 21 | SuggestionsController#accept | 8 / 8 | 2537.6 / 2537.0 | -0.6 | 2642.9 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 77.0, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 67.1 | `app/models/document.rb:181` 312.0, `app/controllers/suggestions_controller.rb:76` 138.4, `app/controllers/application_controller.rb:62` 137.9 |
| 22 | SuggestionsController#reject | 4 / 4 | 2461.0 / 2459.3 | -1.7 | 2530.0 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 89.0, `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 68.0 | `app/models/document.rb:181` 324.3, `app/controllers/suggestions_controller.rb:107` 139.0, `app/controllers/application_controller.rb:62` 139.0 |
| 23 | SuggestionsController#accept_all | 9 / 9 | 2382.0 / 2381.8 | -0.3 | 2322.9 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0, `GEM/hashie/lib/hashie/mash.rb:369` 56.0 | `app/models/document.rb:181` 238.9, `app/models/suggestion.rb:182` 141.8, `app/models/suggestion.rb:185` 135.0 |
| 24 | Api::DocsController#update | 112 / 112 | 2366.5 / 2367.1 | 0.6 | 2354.5 | `GEM/commonmarker/lib/commonmarker/config.rb:94` 79.3, `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0 | `app/models/document.rb:111` 200.2, `app/models/activity.rb:11` 186.4, `app/controllers/api/docs_controller.rb:135` 167.4 |
| 25 | SuggestionsController#create | 12 / 12 | 2334.0 / 2332.0 | -2.0 | 2311.8 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 152.7, `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0 | `app/models/document.rb:181` 368.0, `app/models/suggestion.rb:40` 260.3, `app/controllers/application_controller.rb:62` 122.1 |
| 26 | DocumentsController#snapshot | 14 / 14 | 2300.5 / 2299.3 | -1.2 | 2214.7 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0, `GEM/hashie/lib/hashie/mash.rb:369` 56.0 | `app/services/yjs_persistence.rb:180` 180.5, `app/services/yjs_persistence.rb:147` 145.8, `app/controllers/application_controller.rb:62` 126.0 |
| 27 | DocumentsController#destroy | 8 / 8 | 2190.9 / 2191.4 | 0.6 | 2056.4 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0, `GEM/hashie/lib/hashie/mash.rb:369` 56.0 | `app/controllers/documents_controller.rb:393` 878.0, `app/controllers/application_controller.rb:62` 108.3, `app/controllers/documents_controller.rb:380` 69.3 |
| 28 | Api::DocsController#index | 2 / 2 | 2083.0 / 2083.0 | 0.0 | 1522.5 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0, `GEM/hashie/lib/hashie/mash.rb:369` 56.0 | `app/models/cli_access_token.rb:21` 305.0, `app/models/cli_access_token.rb:24` 227.0, `app/controllers/api/docs_controller.rb:9` 202.0 |
| 29 | CommentsController#resolve | 7 / 7 | 2080.2 / 2079.3 | -0.8 | 2162.6 | `GEM/hashie/lib/hashie/mash.rb:374` 77.0, `GEM/hashie/lib/hashie/mash.rb:410` 58.0, `GEM/hashie/lib/hashie/mash.rb:369` 56.0 | `app/models/document.rb:240` 242.3, `app/models/comment.rb:29` 137.7, `app/models/activity.rb:11` 116.7 |
| 30 | OauthCallbacksController#create | 7 / 7 | 2054.5 / 2053.5 | -1.0 | 2255.7 | `GEM/hashie/lib/hashie/mash.rb:374` 92.3, `GEM/hashie/lib/hashie/mash.rb:410` 58.0, `GEM/hashie/lib/hashie/mash.rb:369` 56.0 | `app/controllers/oauth_callbacks_controller.rb:18` 153.3, `app/models/user.rb:56` 94.5, `app/models/user.rb:38` 89.5 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/json/lib/json/common.rb:364` | `parse` | 2309.67 / 2309.83 | 0.16 | 2320.58 | 92% | String, Hash |  | `app/views/layouts/application.html.erb:57` 32%, `app/views/layouts/application.html.erb:62` 32% | `Parser.parse(source, opts)` |
| 2 | `GEM/hashie/lib/hashie/mash.rb:374` | `convert_key` | 77.08 / 77.08 | 0.0 | 77.16 | 100% | String |  | `no app frame` 100%, `app/controllers/oauth_callbacks_controller.rb:33` 0% | `key.respond_to?(:to_sym) ? key.to_s : key` |
| 3 | `GEM/hashie/lib/hashie/mash.rb:410` | `log_collision?` | 57.94 / 57.94 | 0.0 | 58.0 | 100% | Array |  | `no app frame` 100% | `return unless respond_to?(method_key)` |
| 4 | `GEM/hashie/lib/hashie/mash.rb:369` | `method_suffix` | 55.95 / 55.95 | 0.0 | 56.0 | 100% | String |  | `no app frame` 100% | `method_name = method_name.to_s` |
| 5 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` | `within_new_transaction` | 30.53 / 30.53 | 0.0 | 30.79 | 10% | String, Array |  | `app/models/document.rb:240` 71%, `app/models/document.rb:181` 24% | `raise` |
| 6 | `GEM/commonmarker/lib/commonmarker/config.rb:94` | `process_plugins` | 25.82 / 25.82 | 0.0 | 25.87 | 23% | Array, Hash |  | `app/services/document_plain_text.rb:14` 46%, `app/services/document_title.rb:10` 29% | `Commonmarker::Config::OPTIONS[type].each_with_object({}) do \|(key, val` |
| 7 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | `#{method}` | 24.67 / 24.67 | 0.0 | 24.7 | 100% | Array, Hash |  | `no app frame` 32%, `app/controllers/application_controller.rb:62` 5% | `dispatch(:#{method}, ...)` |
| 8 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` | `each` | 21.82 / 21.82 | 0.0 | 21.83 | 81% | String, Array |  | `app/controllers/documents_controller.rb:51` 10%, `app/controllers/api/base_controller.rb:72` 9% | `val = step` |
| 9 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` | `html_safe` | 17.52 / 17.52 | 0.0 | 17.57 | 25% | String |  | `no app frame` 43%, `app/views/layouts/application.html.erb:60` 7% | `ActiveSupport::SafeBuffer.new(self)` |
| 10 | `RAILS/activerecord/lib/arel/table.rb:85` | `[]` | 17.52 / 17.52 | 0.0 | 17.56 | 86% | Struct |  | `app/controllers/documents_controller.rb:77` 21%, `app/models/activity.rb:11` 6% | `Attribute.new(table, name)` |
| 11 | `RAILS/activemodel/lib/active_model/attribute.rb:9` | `from_database` | 16.73 / 16.73 | 0.0 | 16.75 | 47% | Object |  | `app/controllers/api/docs_controller.rb:135` 22%, `app/models/document.rb:240` 12% | `FromDatabase.new(name, value_before_type_cast, type, nil, value)` |
| 12 | `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:75` | `initialize` | 16.64 / 16.64 | 0.0 | 16.66 | 100% | Array |  | `app/controllers/documents_controller.rb:149` 52%, `app/controllers/documents_controller.rb:50` 17% | `update(constructor)` |
| 13 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` | `call` | 16.17 / 16.17 | 0.0 | 16.18 | 100% | Data |  | `no app frame` 47%, `app/controllers/application_controller.rb:31` 12% | `result_lambda = -> { user_callback.call target, value }` |
| 14 | `GEM/hashie/lib/hashie/mash.rb:387` | `convert_value` | 15.98 / 15.98 | 0.0 | 16.0 | 100% | Array |  | `no app frame` 100% | `Array.new(val.map { \|e\| convert_value(e) })` |
| 15 | `RUBY/ipaddr.rb:725` | `in_addr` | 15.92 / 15.92 | 0.0 | 15.93 | 100% | String, Array |  | `no app frame` 100% | `octets = addr.split('.')` |
| 16 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` | `build_handle` | 15.26 / 15.26 | 0.0 | 15.27 | 99% | Object, Data | #59613 merged 2026-11-04, after this app's version, not released yet, #59235 merged 2026-10-21, after this app's version, not released yet | `no app frame` 13%, `app/controllers/application_controller.rb:62` 8% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 17 | `RAILS/activesupport/lib/active_support/core_ext/hash/indifferent_access.rb:10` | `with_indifferent_access` | 13.36 / 13.36 | 0.0 | 13.38 | 39% | Hash |  | `app/controllers/documents_controller.rb:149` 64%, `app/controllers/documents_controller.rb:50` 21% | `ActiveSupport::HashWithIndifferentAccess.new(self)` |
| 18 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:217` | `dispatch` | 12.33 / 12.33 | 0.0 | 12.35 | 100% | Array |  | `no app frame` 32%, `app/controllers/application_controller.rb:62` 5% | `@broadcasts.map { \|logger\|` |
| 19 | `GEM/sqlite3/lib/sqlite3/statement.rb:54` | `bind_params` | 12.06 / 12.06 | 0.0 | 12.07 | 81% | Array, Hash |  | `app/controllers/application_controller.rb:62` 11%, `app/models/activity.rb:11` 5% | `bind_vars.flatten.each do \|var\|` |
| 20 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:287` | `build_handle` | 12.01 / 12.01 | 0.0 | 12.02 | 100% | Array | #59235 merged 2026-10-21, after this app's version, not released yet | `no app frame` 25%, `app/controllers/application_controller.rb:62` 5% | `groups = groups_for(name).map do \|group_klass, grouped_listeners\|` |
| 21 | `GEM/hashie/lib/hashie/mash.rb:101` | `initialize` | 11.99 / 11.99 | 0.0 | 12.0 | 100% | Array |  | `no app frame` 100% | `deep_update(source_hash) if source_hash` |
| 22 | `GEM/hashie/lib/hashie/mash.rb:196` | `dup` | 11.99 / 11.99 | 0.0 | 12.0 | 100% | Hash |  | `no app frame` 100% | `self.class.new(self, default, &default_proc)` |
| 23 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` | `tag_option` | 11.97 / 11.97 | 0.0 | 12.02 | 22% | String |  | `app/views/layouts/application.html.erb:60` 12%, `app/views/layouts/application.html.erb:62` 5% | `%(#{key}="#{value}")` |
| 24 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:235` | `compact_blank` | 11.83 / 11.83 | 0.0 | 11.84 | 90% | Hash |  | `app/controllers/application_controller.rb:62` 10%, `app/models/activity.rb:11` 7% | `reject { \|_k, v\| v.blank? }` |
| 25 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` | `initialize` | 11.63 / 11.63 | 0.0 | 11.67 | 25% | String |  | `no app frame` 24%, `app/views/layouts/application.html.erb:60` 9% | `super` |
| 26 | `RAILS/actionview/lib/action_view/buffers.rb:44` † | `<<` | 11.35 / 11.35 | 0.0 | 11.79 | 1% | String |  | `no app frame` 100% | `value = value.to_s` |
| 27 | `RAILS/actionpack/lib/action_dispatch/http/request.rb:66` | `initialize` | 10.99 / 10.99 | 0.0 | 11.0 | 100% | Object |  | `no app frame` 100% | `@rack_request = Rack::Request.new(env)` |
| 28 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:146` | `change` | 10.82 / 10.81 | -0.02 | 10.84 | 70% | Rational, Data |  | `app/controllers/application_controller.rb:47` 19%, `app/models/activity.rb:11` 10% | `::Time.utc(new_year, new_month, new_day, new_hour, new_min, new_sec)` |
| 29 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | `merge` | 10.53 / 10.53 | 0.0 | 10.55 | 55% | Array, Object |  | `app/models/document.rb:111` 20%, `app/controllers/documents_controller.rb:194` 7% | `WhereClause.new(predicates \| other.predicates)` |
| 30 | `RAILS/activerecord/lib/arel/alias_predication.rb:8` | `as` | 10.08 / 10.08 | 0.0 | 10.17 | 10% | Object, Hash |  | `app/controllers/documents_controller.rb:77` 100% | `Nodes::As.new self, Nodes::SqlLiteral.new(other, retryable: true)` |

## Dev/test-mode work

4985.2 of 9441.5 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | error page | `RUBY/error_highlight/base.rb:94` | 1733.7 | 1% | `no app frame` 100% | `Prism.parse_file(absolute_path).value.breadth_first_search { \|node\| no` |
| 2 | error page | `GEM/prism/lib/prism/parse_result.rb:70` | 706.11 | 1% | `no app frame` 100% | `source.lines` |
| 3 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/manifest.rb:156` | 630.49 | 21% | `app/views/layouts/application.html.erb:62` 33%, `app/views/layouts/application.html.erb:60` 33% | `File.join(vite_asset_origin \|\| "/", config.public_output_dir, path)` |
| 4 | asset lookup | `GEM/vite_ruby/lib/vite_ruby.rb:88` † | 309.28 | 21% | `app/views/layouts/application.html.erb:62` 33%, `app/views/layouts/application.html.erb:60` 33% | `return @running if defined?(@running) && Time.now - @running_checked_a` |
| 5 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/manifest.rb:174` | 308.96 | 21% | `app/views/layouts/application.html.erb:57` 33%, `app/views/layouts/application.html.erb:60` 33% | `%w[css assets].each do \|key\|` |
| 6 | asset lookup | `GEM/vite_ruby/lib/vite_ruby/config.rb:38` † | 175.83 | 21% | `app/views/layouts/application.html.erb:57` 33%, `app/views/layouts/application.html.erb:62` 33% | `root.join(public_dir, public_output_dir)` |
| 7 | error page | `GEM/prism/lib/prism/node.rb:2797` | 72.59 | 1% | `no app frame` 100% | `compact = [] #: Array[Prism::node]` |
| 8 | error page | `RAILS/actionpack/lib/action_dispatch/middleware/exception_wrapper.rb:332` | 71.49 | 1% | `no app frame` 100% | `lines = source_lines.drop(start).take(6)` |
| 9 | error page | `GEM/prism/lib/prism/node.rb:18058` | 48.33 | 1% | `no app frame` 100% | `[*body]` |
| 10 | error page | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:195` | 47.2 | 1% | `no app frame` 100% | `add_filter { \|line\| line.sub(gems_regexp, gems_result) }` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| gem: json | 2313.5 | 2324.3 | `common.rb:364` 2309.7, `common.rb:1089` 3.6, `common.rb:454` 0.1 |
| ruby stdlib | 1818.4 | 1909.6 | `base.rb:94` 1733.7, `ipaddr.rb:725` 15.9, `digest.rb:64` 8.1 |
| gem: vite_ruby | 1602.0 | 1610.9 | `manifest.rb:156` 630.5, `vite_ruby.rb:88` 309.3, `manifest.rb:174` 309.0 |
| ruby default gem: prism | 1106.2 | 1163.0 | `parse_result.rb:70` 706.1, `node.rb:2797` 72.6, `node.rb:18058` 48.3 |
| rails: activesupport | 655.6 | 665.4 | `backtrace_cleaner.rb:195` 47.2, `log_subscriber.rb:177` 35.2, `broadcast_logger.rb:129` 24.7 |
| rails: activerecord | 623.4 | 626.4 | `log_subscriber.rb:49` 41.4, `transaction.rb:653` 30.5, `table.rb:85` 17.5 |
| rails: actionpack | 362.4 | 377.9 | `exception_wrapper.rb:332` 71.5, `logger.rb:12` 20.0, `exception_wrapper.rb:333` 11.6 |
| app | 237.9 | 243.7 | `segmenter.rb:42` 37.0, `document_social_preview.rb:62` 13.0, `agent_guide.rb:693` 11.6 |
| gem: hashie | 237.0 | 237.2 | `mash.rb:374` 77.1, `mash.rb:410` 57.9, `mash.rb:369` 55.9 |
| rails: actionview | 130.1 | 134.2 | `tag_helper.rb:309` 12.0, `buffers.rb:44` 11.3, `tag_helper.rb:237` 5.7 |
| rails: activemodel | 70.3 | 72.3 | `attribute.rb:9` 16.7, `string.rb:39` 7.7, `attribute.rb:13` 5.2 |
| gem: sqlite3 | 61.6 | 61.9 | `statement.rb:125` 21.8, `statement.rb:54` 12.1, `statement.rb:186` 7.8 |
| gem: rack | 61.4 | 62.2 | `request.rb:693` 7.5, `request.rb:604` 5.5, `builder.rb:164` 4.0 |
| gem: nokogiri | 54.0 | 58.4 | `document_fragment.rb:166` 4.3, `node.rb:66` 4.1, `searchable.rb:270` 3.3 |
| gem: logger | 44.4 | 44.4 | `log_device.rb:33` 12.3, `log_device.rb:165` 12.3, `logger.rb:692` 12.1 |
| gem: inertia_rails | 40.0 | 40.3 | `ssr.rb:14` 7.3, `renderer.rb:138` 3.5, `dotted_keys.rb:15` 3.1 |
| ruby default gem: uri | 35.8 | 36.0 | `common.rb:465` 7.3, `common.rb:456` 6.2, `common.rb:90` 2.5 |
| gem: commonmarker | 31.6 | 31.7 | `config.rb:94` 25.8, `commonmarker.rb:44` 3.4, `config.rb:78` 0.5 |
| gem: propshaft | 22.3 | 27.8 | `helper.rb:113` 8.4, `helper.rb:128` 2.9, `server.rb:16` 1.7 |
| gem: tzinfo | 20.4 | 22.3 | `timestamp.rb:208` 8.7, `timestamp.rb:193` 4.8, `constant_offset_data_timezone_info.rb:52` 4.5 |
| gem: concurrent-ruby | 19.8 | 19.9 | `safe_initialization.rb:30` 6.0, `non_concurrent_map_backend.rb:131` 2.4, `mutex_lockable_object.rb:32` 2.0 |
| gem: useragent | 14.6 | 15.5 | `base.rb:120` 4.7, `version.rb:27` 2.1, `user_agent.rb:25` 1.1 |
| gem: i18n | 13.6 | 13.6 | `base.rb:157` 1.9, `i18n.rb:396` 1.8, `ruby.rb:33` 1.6 |
| gem: omniauth | 13.4 | 13.5 | `strategy.rb:470` 2.2, `strategy.rb:510` 2.0, `strategy.rb:169` 2.0 |
| gem: vite_rails | 9.8 | 9.9 | `tag_helpers.rb:106` 1.7, `tag_helpers.rb:47` 0.8, `tag_helpers.rb:48` 0.8 |
| gem: globalid | 9.5 | 9.5 | `gid.rb:95` 2.5, `gid.rb:159` 2.0, `gid.rb:166` 1.0 |
| rails: railties | 9.0 | 9.1 | `logger.rb:57` 2.0, `engine.rb:748` 1.0, `logger.rb:21` 1.0 |
| gem: erubi | 8.6 | 8.9 | `erubi.rb:134` 4.8, `erubi.rb:137` 1.1, `erubi.rb:139` 0.6 |
| gem: ruby-vips | 7.5 | 8.2 | `object.rb:201` 0.8, `object.rb:202` 0.8, `object.rb:203` 0.8 |
| gem: base64 | 6.7 | 6.7 | `base64.rb:310` 3.8, `base64.rb:283` 2.9, `base64.rb:374` 0.0 |
| gem: loofah | 5.8 | 6.9 | `concerns.rb:172` 2.0, `concerns.rb:43` 1.5, `scrubber.rb:132` 1.2 |
| rails: actioncable | 5.7 | 5.7 | `broadcasting.rb:53` 1.4, `broadcasting.rb:25` 1.3, `broadcasting.rb:32` 0.9 |
| gem: flipper | 4.4 | 4.5 | `memoizer.rb:42` 1.0, `flipper.rb:13` 0.4, `adapter_builder.rb:41` 0.4 |
| gem: ffi | 4.2 | 4.6 | `managedstruct.rb:80` 1.4, `autopointer.rb:88` 1.1, `struct_by_reference.rb:69` 0.5 |
| rails: activestorage | 3.3 | 3.7 | `filename.rb:60` 0.4, `disk_service.rb:131` 0.2, `disk_service.rb:196` 0.2 |
| gem: rack-session | 3.0 | 3.0 | `id.rb:277` 1.0, `id.rb:275` 1.0, `id.rb:368` 0.6 |
| gem: rails-html-sanitizer | 2.7 | 3.2 | `sanitizer.rb:33` 0.5, `sanitizer.rb:56` 0.5, `sanitizer.rb:191` 0.5 |
| gem: ruby_native | 2.7 | 2.8 | `oauth_middleware.rb:18` 1.0, `oauth_middleware.rb:53` 1.0, `native_detection.rb:20` 0.5 |
| ruby default gem: securerandom | 2.1 | 2.1 | `securerandom.rb:71` 2.1 |
| gem: bcrypt | 1.5 | 1.5 | `password.rb:102` 0.5, `password.rb:103` 0.2, `engine.rb:70` 0.2 |
| gem: bootsnap | 1.3 | 2.2 | `kernel_require.rb:11` 0.9, `iseq.rb:98` 0.2, `iseq.rb:154` 0.1 |
| rails: activejob | 1.0 | 1.0 | `log_subscriber.rb:207` 0.1, `log_subscriber.rb:23` 0.1, `enqueuing.rb:92` 0.1 |
| gem: marcel | 0.3 | 0.3 | `magic.rb:18` 0.1, `mime_type.rb:90` 0.1, `mime_type.rb:31` 0.0 |
| ruby default gem: prettyprint | 0.2 | 0.3 | `prettyprint.rb:403` 0.1, `prettyprint.rb:263` 0.1, `prettyprint.rb:458` 0.0 |
| ruby default gem: pp | 0.1 | 0.1 | `pp.rb:542` 0.0, `pp.rb:271` 0.0, `pp.rb:550` 0.0 |
| gem: zeitwerk | 0.1 | 0.2 | `cref.rb:47` 0.0, `constant_path_validator.rb:13` 0.0, `file_system.rb:203` 0.0 |
| gem: omniauth-rails_csrf_protection | 0.0 | 0.0 | `token_verifier.rb:59` 0.0, `token_verifier.rb:55` 0.0 |
| gem: y-rb | 0.0 | 0.0 | `doc.rb:212` 0.0, `transaction.rb:105` 0.0, `doc.rb:58` 0.0 |
| gem: omniauth-google-oauth2 | 0.0 | 0.0 | `google_oauth2.rb:108` 0.0 |
| gem: flipper-ui | 0.0 | 0.4 | `ui.rb:49` 0.0, `ui.rb:18` 0.0, `util.rb:47` 0.0 |
| gem: bigdecimal | 0.0 | 0.0 | `util.rb:24` 0.0, `util.rb:51` 0.0 |
| ruby default gem: erb | 0.0 | 0.1 | `erb.rb:1065` 0.0, `compiler.rb:336` 0.0, `compiler.rb:408` 0.0 |
| gem: sanitize | 0.0 | 0.1 | `clean_element.rb:72` 0.0, `sanitize.rb:67` 0.0, `config.rb:28` 0.0 |
| gem: racc | 0.0 | 0.1 | `parser.rb:263` 0.0 |
| gem: msgpack | 0.0 | 0.0 | `factory.rb:16` 0.0, `factory.rb:27` 0.0, `factory.rb:29` 0.0 |
| other | 0.0 | 0.0 | `(erb):1` 0.0 |
| rails: actiontext | 0.0 | 0.1 | `content.rb:25` 0.0, `content.rb:29` 0.0, `content.rb:0` 0.0 |
| ruby default gem: bundler | 0.0 | 0.0 | `rubygems_integration.rb:192` 0.0 |
| lowrail-profile | 0.0 | 0.0 | `profile.rb:66` 0.0, `profile.rb:56` 0.0 |
| gem: rack-protection | 0.0 | 0.0 | `authenticity_token.rb:110` 0.0, `base.rb:41` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Jobs

| # | Job | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | WritingReviewerJob#perform | 9 / 9 | 6506.0 / 6506.0 | 0.0 | 6345.6 | `GEM/json/lib/json/common.rb:364` 166.8, `RAILS/activemodel/lib/active_model/attribute.rb:9` 93.6, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 78.5 | `app/jobs/writing_reviewer_job.rb:58` 722.9, `app/models/writing_pass.rb:143` 455.0, `app/models/writing_pass.rb:128` 428.3 |

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
| 10 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:146` | 33.33 / 33.33 | 89% | `app/jobs/writing_reviewer_job.rb:58` 61%, `app/models/writing_pass.rb:143` 34% | `::Time.utc(new_year, new_month, new_day, new_hour, new_min, new_sec)` |

### Action Cable

| # | Channel action | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | SyncChannel#subscribed | 33 / 33 | 787.0 / 787.0 | 0.0 | 781.5 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` 19.1, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 16.5, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 10.4 | `app/services/yjs_persistence.rb:116` 144.8, `app/models/document.rb:111` 80.0, `app/channels/sync_channel.rb:44` 67.5 |
| 2 | SyncChannel#receive | 23 / 23 | 659.0 / 659.0 | 0.0 | 634.3 | `RAILS/activesupport/lib/active_support/parameter_filter.rb:112` 29.4, `RAILS/activemodel/lib/active_model/attribute.rb:9` 18.2, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 16.9 | `app/services/yjs_persistence.rb:54` 141.7, `app/services/yjs_persistence.rb:89` 104.1, `app/services/yjs_persistence.rb:56` 67.6 |
| 3 | DocumentMetaChannel#subscribed | 2 / 2 | 191.0 / 191.0 | 0.0 | 215.0 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` 16.0, `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/synchronization/safe_initialization.rb:30` 12.0, `RAILS/activesupport/lib/active_support/callbacks.rb:103` 6.0 | `app/channels/document_meta_channel.rb:6` 43.0, `app/channels/document_meta_channel.rb:9` 0.0, `app/channels/document_meta_channel.rb:10` 0.0 |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` (debug logging) | 25.03 / 25.03 | 85% | `app/channels/sync_channel.rb:44` 16%, `app/services/yjs_persistence.rb:116` 15% | `binds = binds.inspect` |
| 2 | `RAILS/activesupport/lib/active_support/log_subscriber.rb:177` (debug logging) | 21.93 / 21.93 | 85% | `app/services/yjs_persistence.rb:54` 17%, `app/channels/sync_channel.rb:44` 15% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 3 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` | 17.19 / 17.19 | 79% | `app/channels/sync_channel.rb:44` 45%, `app/services/yjs_persistence.rb:56` 17% | `val = step` |
| 4 | `RAILS/activesupport/lib/active_support/log_subscriber.rb:175` (debug logging) | 14.62 / 14.62 | 85% | `app/services/yjs_persistence.rb:54` 17%, `app/channels/sync_channel.rb:44` 15% | `modes = MODES.values_at(*options.compact_blank.keys)` |
| 5 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | 11.59 / 11.59 | 69% | `app/services/yjs_persistence.rb:116` 37%, `app/models/document.rb:111` 34% | `WhereClause.new(predicates \| other.predicates)` |
| 6 | `RAILS/activesupport/lib/active_support/parameter_filter.rb:112` | 11.14 / 11.14 | 35% | `no app frame` 100% | `s = Regexp.escape(item.to_s)` |
| 7 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | 9.52 / 9.52 | 95% | `config/initializers/yjs_instrumentation.rb:52` 18%, `app/services/yjs_persistence.rb:54` 13% | `dispatch(:#{method}, ...)` |
| 8 | `RAILS/activemodel/lib/active_model/attribute.rb:9` | 9.12 / 9.12 | 26% | `app/services/yjs_persistence.rb:54` 57%, `app/services/yjs_persistence.rb:426` 15% | `FromDatabase.new(name, value_before_type_cast, type, nil, value)` |
| 9 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` | 8.19 / 8.19 | 90% | `app/services/yjs_persistence.rb:54` 15%, `app/channels/sync_channel.rb:44` 14% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 10 | `GEM/sqlite3/lib/sqlite3/statement.rb:54` | 7.76 / 7.76 | 85% | `app/channels/sync_channel.rb:44` 22%, `app/services/yjs_persistence.rb:116` 20% | `bind_vars.flatten.each do \|var\|` |
