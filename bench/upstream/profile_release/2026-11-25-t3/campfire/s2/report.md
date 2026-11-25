# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails test -v`
* Ruby: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux]
* Rails: 8.2.0.alpha, test environment
* Counted in run 1: 666 requests, 16 jobs, 19 Cable actions; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 666 | 19493.0 | 16 | 0 | 19 | 0 |
| run2 | 1 | 666 | 19492.2 | 16 | 0 | 19 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 1.35 objects per request; 1 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/controllers/concerns/inline_script_hashes.rb:40` | `script_locations` | 2946.5 | 0.0 | 79.46 | `GEM/uri/lib/uri/generic.rb:1007` 16%, `GEM/uri/lib/uri/common.rb:108` 6%, `GEM/uri/lib/uri/rfc3986_parser.rb:85` 6% | SessionsController#create 43%, RoomsController#show 13%, MessagesController#index 6% | `url = URI.join(request.base_url, url)` |
| 2 | `app/controllers/concerns/inline_script_hashes.rb:41` | `script_locations` | 643.52 | 0.0 | 0.0 | `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 25%, `GEM/rack/lib/rack/request.rb:693` 24%, `RAILS/actionpack/lib/action_dispatch/http/url.rb:342` 24% | SessionsController#create 42%, RoomsController#show 13%, MessagesController#index 6% | `origin = url.origin == request.base_url ? request.host_with_port : url` |
| 3 | `app/models/message/pagination.rb:23` | `preload_associations` | 556.05 | 80.0 | 0.0 | `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:28` 3%, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:49` 2%, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:77` 2% | RoomsController#show 53%, MessagesController#index 36%, Messages::ByBotsController#index 8% | `@relation.preload_associations(records)` |
| 4 | `app/models/session.rb:11` | `start!` | 170.61 | 77.29 | 0.37 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 5%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:171` 4%, `GEM/tzinfo/lib/tzinfo/timestamp.rb:208` 3% | SessionsController#create 96%, Users::ProfilesController#update 3%, UsersController#create 0% | `create! user_agent: user_agent, ip_address: ip_address` |
| 5 | `app/helpers/messages_helper.rb:107` | `text_message_presentation` | 136.66 | 19.55 | 0.76 | `GEM/nokogiri/lib/nokogiri/html5/node.rb:66` 5%, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1429` 3%, `GEM/nokogiri/lib/nokogiri/xml/document.rb:416` 3% | MessagesController#index 55%, RoomsController#show 32%, MessagesController#create 7% | `render = -> { auto_link_text h(ContentFilters::TextMessagePresentation` |
| 6 | `app/views/layouts/application.html.erb:23` |  | 132.04 | 14.26 | 0.45 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 11%, `RAILS/actionview/lib/action_view/helpers/asset_tag_helper.rb:683` 11%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` 7% | RoomsController#show 55%, Users::SidebarsController#show 12%, Users::ProfilesController#show 7% | `<%= stylesheet_link_tag :all, "data-turbo-track": "reload" %>` |
| 7 | `app/views/layouts/application.html.erb:26` |  | 123.42 | 417.6 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:159` 22%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 22%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:243` 12% | RoomsController#show 59%, Users::SidebarsController#show 11%, Users::ProfilesController#show 6% | `<%= javascript_importmap_tags %>` |
| 8 | `app/helpers/messages_helper.rb:94` | `message_fragment_cache_key` | 92.34 | 0.0 | 0.0 | `GEM/nokogiri/lib/nokogiri/css/xpath_visitor.rb:94` 5%, `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:270` 5%, `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:238` 5% | RoomsController#show 61%, MessagesController#index 38%, Rooms::RefreshesController#show 1% | `body = message.body.body` |
| 9 | `app/models/current.rb:15` | `account` | 88.65 | 35.98 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 8%, `RAILS/activerecord/lib/arel.rb:60` 3%, `RAILS/activerecord/lib/active_record/relation/finder_methods.rb:675` 3% | RoomsController#show 55%, Users::SidebarsController#show 10%, AccountsController#edit 7% | `Account.first` |
| 10 | `app/controllers/concerns/inline_script_hashes.rb:39` | `script_locations` | 87.29 | 0.0 | 2.65 | `GEM/json/lib/json/common.rb:364` 100% | SessionsController#create 43%, RoomsController#show 13%, MessagesController#index 7% | `JSON.parse(importmap)["imports"].values.map do \|url\|` |
| 11 | `app/models/message/attachment.rb:20` | `create_with_attachment!` | 73.87 | 15.71 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:171` 3%, `GEM/tzinfo/lib/tzinfo/timestamp.rb:208` 2%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:166` 2% | MessagesController#create 68%, Messages::ByBotsController#create 32% | `create!(attributes).tap(&:process_attachment)` |
| 12 | `app/models/message.rb:26` | `plain_text_body` | 70.08 | 0.53 | 0.0 | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:270` 5%, `GEM/nokogiri/lib/nokogiri/css/xpath_visitor.rb:94` 5%, `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:238` 5% | MessagesController#index 36%, RoomsController#show 27%, Messages::ByBotsController#index 24% | `content = body.body` |
| 13 | `app/views/messages/_actions.html.erb:18` |  | 69.96 | 0.0 | 4.37 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 25%, `RAILS/actionview/lib/action_view/helpers/form_tag_helper.rb:308` 13%, `RAILS/actionview/lib/action_view/helpers/form_tag_helper.rb:1084` 12% | MessagesController#index 56%, RoomsController#show 34%, MessagesController#create 5% | `<%= hidden_field_tag "boost[content]", character %>` |
| 14 | `app/controllers/sessions_controller.rb:11` | `create` | 68.84 | 19.9 | 0.72 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 6%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 4%, `GEM/bcrypt/lib/bcrypt/password.rb:102` 3% | SessionsController#create 100% | `if user = User.active.authenticate_by(email_address: params[:email_add` |
| 15 | `app/helpers/messages_helper.rb:100` | `message_fragment_cache_key` | 67.27 | 0.0 | 5.54 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 43%, `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 23%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 9% | RoomsController#show 62%, MessagesController#index 37%, Rooms::RefreshesController#show 2% | `dependencies = [ message.attributes, room.attributes.slice("id", "type` |
| 16 | `app/helpers/messages_helper.rb:123` | `auto_link_text` | 63.39 | 0.0 | 0.53 | `GEM/nokogiri/lib/nokogiri/xml/document.rb:416` 10%, `GEM/nokogiri/lib/nokogiri/html5/node.rb:66` 10%, `GEM/loofah/lib/loofah/scrubber.rb:132` 7% | MessagesController#index 55%, RoomsController#show 33%, MessagesController#create 7% | `fragment = Nokogiri::HTML5.fragment(sanitize(html, tags: AUTO_LINK_ALL` |
| 17 | `config/routes.rb:59` |  | 59.39 | 0.0 | 2.55 | `RAILS/activesupport/lib/active_support/core_ext/object/to_query.rb:16` 6%, `RAILS/activesupport/lib/active_support/core_ext/object/to_query.rb:92` 4%, `RAILS/actionpack/lib/action_dispatch/http/url.rb:205` 4% | RoomsController#show 44%, MessagesController#index 30%, Messages::ByBotsController#index 8% | `route_for :user_avatar, user.avatar_token, v: user.updated_at.to_fs(:n` |
| 18 | `app/views/messages/_message.html.erb:4` |  | 57.64 | 12.15 | 1.52 | `RAILS/activesupport/lib/active_support/core_ext/object/to_query.rb:50` 30%, `RAILS/activesupport/lib/active_support/core_ext/object/to_query.rb:10` 7%, `RAILS/activesupport/lib/active_support/cache.rb:131` 5% | RoomsController#show 66%, MessagesController#index 32%, Rooms::RefreshesController#show 2% | `<% cache [ message_fragment_cache_key(message), "presentation-v8" ] do` |
| 19 | `app/controllers/concerns/authentication.rb:94` | `set_authentication_cookie` | 55.29 | 0.0 | 0.78 | `RAILS/activesupport/lib/active_support/core_ext/hash/keys.rb:40` 9%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:171` 9%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:166` 6% | SessionsController#create 53%, RoomsController#show 13%, MessagesController#index 6% | `cookies.signed.permanent[:session_token] = { value: session.token, htt` |
| 20 | `app/models/ban.rb:7` | `banned?` | 54.47 | 29.34 | 0.0 | `RAILS/activerecord/lib/active_record/relation/finder_methods.rb:439` 4%, `GEM/sqlite3/lib/sqlite3/statement.rb:54` 3%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:118` 2% | SessionsController#create 65%, MessagesController#create 5%, Users::ProfilesController#update 4% | `exists?(ip_address: ip_address)` |
| 21 | `app/models/message/pagination.rb:10` | `load` | 53.72 | 8.11 | 0.16 | `RAILS/activerecord/lib/active_record/key.rb:14` 14%, `RAILS/activerecord/lib/active_record/key.rb:87` 14%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 7% | RoomsController#show 49%, MessagesController#index 37%, Messages::ByBotsController#index 11% | `new(relation.skip_preloading!.public_send(direction, size), relation)` |
| 22 | `app/controllers/concerns/authentication/session_lookup.rb:7` | `find_session_by_cookie` | 52.06 | 18.38 | 0.37 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 8%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 4% | RoomsController#show 22%, MessagesController#index 14%, MessagesController#create 8% | `[ session, session&.user ]` |
| 23 | `app/helpers/messages_helper.rb:36` | `message_tag` | 50.96 | 0.0 | 0.76 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1591` 33%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 19%, `RAILS/activesupport/lib/active_support/inflector/methods.rb:259` 16% | RoomsController#show 51%, MessagesController#index 42%, MessagesController#create 4% | `tag.div id: dom_id(message),` |
| 24 | `app/views/messages/_message.html.erb:26` |  | 43.52 | 25.12 | 2.28 | `RAILS/activerecord/lib/active_record/integration.rb:59` 10%, `RAILS/actionpack/lib/action_dispatch/journey/formatter.rb:134` 3%, `RAILS/actionpack/lib/action_dispatch/http/url.rb:205` 3% | RoomsController#show 51%, MessagesController#index 42%, MessagesController#create 4% | `<%= render "messages/actions", message: message, url: room_at_message_` |
| 25 | `app/helpers/users/avatars_helper.rb:14` | `avatar_tag` | 43.38 | 0.0 | 5.25 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 10%, `RAILS/activerecord/lib/active_record/integration.rb:59` 7%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:243` 5% | RoomsController#show 53%, MessagesController#index 37%, MessagesController#create 3% | `link_to user_path(user), title: user.title, class: "btn avatar", data:` |
| 26 | `app/helpers/content_filters/sanitize_attributes.rb:11` | `apply` | 43.05 | 0.0 | 0.53 | `GEM/nokogiri/lib/nokogiri/html5/node.rb:66` 15%, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1429` 10%, `GEM/nokogiri/lib/nokogiri/xml/document.rb:416` 8% | MessagesController#index 56%, RoomsController#show 33%, MessagesController#create 6% | `sanitizer.sanitize fragment.to_html, tags: allowed_tags, attributes: a` |
| 27 | `app/views/messages/boosts/_boosts.html.erb:5` |  | 41.84 | 28.55 | 3.01 | `RAILS/actionview/lib/action_view/renderer/collection_renderer.rb:150` 5%, `RAILS/actionview/lib/action_view/renderer/collection_renderer.rb:121` 4%, `RAILS/actionview/lib/action_view/renderer/abstract_renderer.rb:44` 4% | RoomsController#show 38%, MessagesController#index 32%, MessagesController#create 14% | `<%= render partial: "messages/boosts/boost", collection: message.boost` |
| 28 | `app/controllers/concerns/authentication/session_lookup.rb:3` | `find_session_by_cookie` | 41.37 | 0.0 | 0.0 | `GEM/uri/lib/uri/common.rb:465` 16%, `GEM/json/lib/json/common.rb:364` 8%, `GEM/rack/lib/rack/utils.rb:331` 8% | RoomsController#show 28%, MessagesController#index 13%, MessagesController#create 6% | `if token = cookies.signed[:session_token]` |
| 29 | `app/views/rooms/show.html.erb:17` |  | 39.82 | 7.67 | 0.34 | `RAILS/activesupport/lib/active_support/core_ext/object/to_query.rb:50` 31%, `RAILS/activesupport/lib/active_support/core_ext/object/to_query.rb:10` 12%, `RAILS/activesupport/lib/active_support/cache.rb:1045` 12% | RoomsController#show 100% | `<%= render partial: "messages/message", collection: @messages, cached:` |
| 30 | `app/models/message.rb:27` | `plain_text_body` | 38.97 | 0.0 | 0.0 | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:270` 9%, `GEM/nokogiri/lib/nokogiri/css/xpath_visitor.rb:94` 9%, `GEM/nokogiri/lib/nokogiri/css/selector_cache.rb:33` 9% | RoomsController#show 46%, MessagesController#index 37%, Messages::ByBotsController#index 8% | `text = if content && content.fragment.find_all(ActionText::Attachment.` |

App middleware that hands the request on (the stack below it, not its own work): `config/initializers/uploaded_script_guard.rb:24` 213.96 warm objects per request.

344.09 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | MessagesController#index | 38 / 38 | 27170.6 / 27167.5 | -3.1 | 26602.6 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 716.5, `GEM/uri/lib/uri/generic.rb:1007` 550.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1591` 434.4 | `app/models/message/pagination.rb:23` 3639.8, `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/helpers/messages_helper.rb:107` 1341.8 |
| 2 | RoomsController#show | 78 / 78 | 25845.8 / 25842.9 | -2.9 | 25594.4 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 629.9, `GEM/uri/lib/uri/generic.rb:1007` 494.0, `GEM/rack/lib/rack/request.rb:693` 377.4 | `app/controllers/concerns/inline_script_hashes.rb:40` 3270.6, `app/models/message/pagination.rb:23` 2525.9, `app/controllers/concerns/inline_script_hashes.rb:41` 725.8 |
| 3 | Rooms::RefreshesController#show | 3 / 3 | 21330.0 / 21334.5 | 4.5 | 19697.0 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 378.0, `RAILS/actionview/lib/action_view/render_parser.rb:16` 303.0 | `app/models/message/pagination.rb:23` 4638.5, `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/views/rooms/refreshes/show.turbo_stream.erb:2` 1034.0 |
| 4 | SessionsController#create | 251 / 251 | 20440.8 / 20440.1 | -0.7 | 20386.8 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 367.4, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 274.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3341.8, `app/controllers/concerns/inline_script_hashes.rb:41` 717.8, `app/models/session.rb:11` 437.5 |
| 5 | WelcomeController#show | 14 / 14 | 18999.8 / 18996.3 | -3.5 | 19880.1 | `GEM/rack/lib/rack/request.rb:693` 344.3, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 260.8, `GEM/uri/lib/uri/rfc3986_parser.rb:85` 253.2 | `app/controllers/concerns/inline_script_hashes.rb:40` 2866.7, `app/controllers/concerns/inline_script_hashes.rb:16` 772.8, `app/controllers/concerns/inline_script_hashes.rb:41` 685.4 |
| 6 | Messages::ByBotsController#index | 12 / 12 | 15992.0 / 15992.6 | 0.6 | 15695.5 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 365.1, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 333.5 | `app/controllers/concerns/inline_script_hashes.rb:40` 3385.2, `app/models/message/pagination.rb:23` 2581.4, `app/views/messages/_message.json.jbuilder:8` 2012.5 |
| 7 | AccountsController#edit | 5 / 5 | 15825.5 / 15818.0 | -7.5 | 64617.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 635.0, `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/models/current.rb:15` 1051.3, `app/views/layouts/application.html.erb:23` 872.0 |
| 8 | MessagesController#show | 5 / 5 | 14217.8 / 14219.0 | 1.3 | 19192.8 | `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 702.5, `GEM/uri/lib/uri/generic.rb:1007` 550.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 428.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3456.8, `app/controllers/concerns/inline_script_hashes.rb:41` 1035.0, `app/views/layouts/application.html.erb:23` 872.0 |
| 9 | Users::ProfilesController#show | 10 / 10 | 13790.6 / 13783.6 | -7.0 | 14815.5 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 574.6, `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 371.1 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.6, `app/controllers/users/profiles_controller.rb:10` 705.1 |
| 10 | MessagesController#create | 21 / 21 | 13588.8 / 13585.9 | -2.9 | 13566.2 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 394.2, `GEM/rack/lib/rack/request.rb:693` 334.6 | `app/controllers/concerns/inline_script_hashes.rb:40` 3389.2, `app/models/message/attachment.rb:20` 1661.3, `app/controllers/concerns/inline_script_hashes.rb:41` 828.0 |
| 11 | QrCodeController#show | 3 / 3 | 12839.0 / 12839.5 | 0.5 | 12499.0 | `GEM/rqrcode_core/lib/rqrcode_core/qrcode/qr_util.rb:93` 5784.5, `GEM/rqrcode/lib/rqrcode/export/svg.rb:181` 1020.0, `GEM/uri/lib/uri/generic.rb:1007` 550.0 | `app/controllers/qr_code_controller.rb:6` 7584.0, `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0 |
| 12 | Users::SidebarsController#show | 17 / 17 | 12541.9 / 12539.4 | -2.4 | 13065.4 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.3, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 318.1 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `app/views/layouts/application.html.erb:23` 654.0 |
| 13 | FirstRunsController#show | 2 / 2 | 12464.0 / 12464.0 | 0.0 | 8931.0 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 427.0, `GEM/rack/lib/rack/request.rb:693` 364.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/views/layouts/application.html.erb:23` 872.0, `app/views/layouts/application.html.erb:26` 748.0 |
| 14 | Messages::ByBotsController#create | 13 / 13 | 11742.2 / 11742.8 | 0.6 | 11379.5 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 364.3, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 280.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/models/message/attachment.rb:20` 1331.1, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0 |
| 15 | SearchesController#index | 9 / 9 | 11665.9 / 11665.1 | -0.8 | 13166.2 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.5, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 350.1 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/views/layouts/application.html.erb:23` 763.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0 |
| 16 | Messages::BoostsController#index | 4 / 4 | 11598.0 / 11599.3 | 1.3 | 11676.8 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 367.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/views/layouts/application.html.erb:23` 872.0, `app/views/layouts/application.html.erb:26` 748.0 |
| 17 | RoomsController#destroy | 5 / 5 | 10787.8 / 10788.5 | 0.8 | 85069.6 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 273.5 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/models/room.rb:72` 2019.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0 |
| 18 | MessagesController#update | 3 / 3 | 10167.0 / 10171.5 | 4.5 | 9069.7 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 275.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/messages_controller.rb:46` 2557.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0 |
| 19 | SessionsController#new | 8 / 8 | 9850.4 / 9850.4 | 0.0 | 10289.6 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 364.6, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 325.4 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/views/layouts/application.html.erb:23` 747.4, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0 |
| 20 | Rooms::DirectsController#create | 3 / 3 | 9068.5 / 9076.5 | 8.0 | 9910.7 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 380.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 280.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `app/controllers/rooms/directs_controller.rb:28` 635.0 |
| 21 | Messages::ByBotsController#update | 5 / 5 | 8711.5 / 8712.8 | 1.3 | 8237.4 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 365.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 274.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/messages_controller.rb:46` 1213.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0 |
| 22 | Messages::BoostsController#create | 2 / 2 | 8086.0 / 8093.0 | 7.0 | 8265.5 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 376.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 278.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/messages/boosts_controller.rb:12` 853.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0 |
| 23 | Autocompletable::UsersController#index | 4 / 4 | 8072.7 / 8073.7 | 1.0 | 7691.3 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 272.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/views/autocompletable/users/index.json.jbuilder:1` 1284.7, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0 |
| 24 | Rooms::ClosedsController#create | 2 / 2 | 8027.0 / 8024.0 | -3.0 | 7133.0 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 275.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `app/controllers/rooms/closeds_controller.rb:65` 328.0 |
| 25 | Users::BansController#create | 5 / 5 | 7825.5 / 7824.0 | -1.5 | 8027.8 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 273.5 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `app/models/user/bannable.rb:30` 340.5 |
| 26 | Rooms::ClosedsController#update | 5 / 5 | 7752.3 / 7775.0 | 22.8 | 8418.0 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 274.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `config/initializers/uploaded_script_guard.rb:24` 326.3 |
| 27 | MessagesController#destroy | 3 / 3 | 7599.5 / 7599.0 | -0.5 | 7930.7 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 273.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `app/controllers/messages_controller.rb:57` 581.0 |
| 28 | UnfurlLinksController#create | 12 / 12 | 7501.4 / 7500.2 | -1.2 | 7612.6 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 371.3, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 272.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `lib/restricted_http/private_network_guard.rb:21` 639.7 |
| 29 | Rooms::DirectsController#destroy | 4 / 4 | 7344.0 / 7349.0 | 5.0 | 7222.5 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 274.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `config/initializers/uploaded_script_guard.rb:24` 269.0 |
| 30 | Users::ProfilesController#update | 16 / 16 | 7271.3 / 7271.9 | 0.5 | 7342.5 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 273.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `app/controllers/users/profiles_controller.rb:14` 383.7 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/uri/lib/uri/generic.rb:1007` | `split_path` | 532.1 / 532.1 | 0.0 | 532.93 | 97% | String, Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100% | `path.split("/", -1)` |
| 2 | `GEM/rack/lib/rack/request.rb:693` | `split_header` | 364.4 / 364.4 | 0.0 | 364.95 | 99% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 49%, `app/controllers/concerns/inline_script_hashes.rb:41` 48% | `value ? value.strip.split(/[, \t]+/) : []` |
| 3 | `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` | `host` | 288.61 / 288.61 | 0.0 | 289.58 | 100% | String, MatchData |  | `app/controllers/concerns/inline_script_hashes.rb:41` 63%, `app/controllers/concerns/inline_script_hashes.rb:40` 32% | `raw_host_with_port.sub(/:\d+$/, "")` |
| 4 | `RAILS/actionpack/lib/action_dispatch/http/url.rb:342` | `host_with_port` | 266.43 / 266.43 | 0.0 | 266.83 | 99% | String |  | `app/controllers/concerns/inline_script_hashes.rb:41` 66%, `app/controllers/concerns/inline_script_hashes.rb:40` 33% | `"#{host}#{port_string}"` |
| 5 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` | `tag_option` | 193.62 / 193.62 | 0.0 | 194.08 | 32% | String |  | `app/views/layouts/application.html.erb:26` 17%, `app/views/messages/_actions.html.erb:18` 9% | `%(#{key}="#{value}")` |
| 6 | `GEM/uri/lib/uri/rfc3986_parser.rb:85` | `split` | 183.71 / 183.71 | 0.0 | 183.99 | 99% | MatchData, String |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 1% | `if m = RFC3986_URI.match(uri)` |
| 7 | `GEM/uri/lib/uri/common.rb:108` | `escape` | 183.64 / 183.64 | 0.0 | 183.91 | 99% | String |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 1% | `name.upcase.tr(ReservedChars, EscapedChars)` |
| 8 | `GEM/uri/lib/uri/generic.rb:543` | `split_userinfo` | 180.34 / 180.36 | 0.02 | 180.62 | 100% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 0% | `return nil, nil unless ui` |
| 9 | `GEM/uri/lib/uri/generic.rb:516` | `set_userinfo` | 180.34 / 180.34 | 0.0 | 180.61 | 100% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 0% | `[@user, @password]` |
| 10 | `GEM/uri/lib/uri/common.rb:194` | `for` | 179.12 / 179.12 | 0.0 | 179.39 | 99% | Object |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 0% | `return uri_class.new(scheme, *arguments)` |
| 11 | `GEM/uri/lib/uri/rfc3986_parser.rb:135` | `parse` | 179.12 / 179.12 | 0.0 | 179.39 | 99% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 0% | `URI.for(*self.split(uri), self)` |
| 12 | `GEM/rack/lib/rack/request.rb:595` | `base_url` | 178.4 / 178.4 | 0.0 | 178.67 | 99% | String |  | `app/controllers/concerns/inline_script_hashes.rb:41` 50%, `app/controllers/concerns/inline_script_hashes.rb:40` 50% | `"#{scheme}://#{host_with_port}"` |
| 13 | `GEM/uri/lib/uri/rfc3986_parser.rb:115` | `split` | 174.6 / 174.6 | 0.0 | 174.87 | 97% | String, MatchData |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100%, `app/models/opengraph/fetch.rb:34` 0% | `elsif m = RFC3986_relative_ref.match(uri)` |
| 14 | `GEM/json/lib/json/common.rb:364` | `parse` | 109.57 / 108.22 | -1.35 | 110.43 | 100% | String, Hash |  | `app/controllers/concerns/inline_script_hashes.rb:39` 89%, `app/controllers/concerns/authentication/session_lookup.rb:3` 4% | `Parser.parse(source, opts)` |
| 15 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:243` | `html_safe` | 101.68 / 101.68 | 0.0 | 101.95 | 36% | String |  | `app/views/layouts/application.html.erb:26` 17%, `app/views/layouts/application.html.erb:23` 11% | `ActiveSupport::SafeBuffer.new(self)` |
| 16 | `GEM/uri/lib/uri/generic.rb:335` | `set_scheme` | 92.42 / 92.42 | 0.0 | 92.56 | 100% | String |  | `app/controllers/concerns/inline_script_hashes.rb:40` 98%, `app/controllers/sessions_controller.rb:13` 1% | `@scheme = v&.downcase` |
| 17 | `GEM/uri/lib/uri/rfc3986_parser.rb:87` | `split` | 91.86 / 91.86 | 0.0 | 92.0 | 99% | String, Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 1% | `scheme = m["scheme"]` |
| 18 | `GEM/uri/lib/uri/rfc3986_parser.rb:104` | `split` | 91.83 / 91.83 | 0.0 | 91.97 | 99% | String, Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 1% | `m["host"],` |
| 19 | `GEM/uri/lib/uri/rfc3986_parser.rb:102` | `split` | 91.83 / 91.83 | 0.0 | 91.96 | 99% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 1% | `[ scheme,` |
| 20 | `GEM/uri/lib/uri/rfc3986_parser.rb:107` | `split` | 91.83 / 91.83 | 0.0 | 91.96 | 99% | String |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 1% | `(m["path-abempty"] \|\|` |
| 21 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:159` | `xml_name_escape` | 91.45 / 91.45 | 0.0 | 91.76 | 32% | String |  | `app/views/layouts/application.html.erb:26` 35%, `app/helpers/users/avatars_helper.rb:15` 7% | `name = name.to_s` |
| 22 | `GEM/uri/lib/uri/http.rb:132` | `origin` | 90.81 / 90.81 | 0.0 | 90.95 | 99% | String |  | `app/controllers/concerns/inline_script_hashes.rb:41` 100% | `"#{scheme}://#{authority}"` |
| 23 | `GEM/uri/lib/uri/common.rb:274` | `join` | 88.92 / 88.92 | 0.0 | 89.05 | 99% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100% | `DEFAULT_PARSER.join(*str)` |
| 24 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` | `initialize` | 87.94 / 87.97 | 0.03 | 88.23 | 35% | String, Array |  | `app/views/layouts/application.html.erb:26` 19%, `app/views/layouts/application.html.erb:23` 13% | `super` |
| 25 | `GEM/uri/lib/uri/rfc3986_parser.rb:116` | `split` | 87.3 / 87.3 | 0.0 | 87.44 | 97% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100%, `app/models/opengraph/fetch.rb:34` 0% | `[ nil, # scheme` |
| 26 | `GEM/uri/lib/uri/generic.rb:1137` | `merge` | 87.3 / 87.3 | 0.0 | 87.43 | 97% | Object |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100% | `base = self.dup` |
| 27 | `GEM/uri/lib/uri/generic.rb:1039` | `merge_path` | 87.03 / 87.03 | 0.0 | 87.16 | 97% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100% | `tmp = []` |
| 28 | `GEM/uri/lib/uri/generic.rb:1051` | `merge_path` | 87.03 / 87.03 | 0.0 | 87.16 | 97% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100% | `base_path = [''] # keep '/' for root directory` |
| 29 | `GEM/uri/lib/uri/generic.rb:1074` | `merge_path` | 87.03 / 87.03 | 0.0 | 87.16 | 97% | String |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100% | `return base_path.join('/')` |
| 30 | `GEM/uri/lib/uri/rfc3986_parser.rb:122` | `split` | 87.03 / 87.03 | 0.0 | 87.16 | 97% | String |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100% | `m["path-absolute"] \|\|` |

## Dev/test-mode work

6932.9 of 16609.9 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | error page | `RUBY/error_highlight/base.rb:94` | 2765.94 | 2% | `no app frame` 100% | `Prism.parse_file(absolute_path).value.breadth_first_search { \|node\| no` |
| 2 | error page | `GEM/prism/lib/prism/parse_result.rb:70` | 1147.75 | 2% | `no app frame` 100% | `source.lines` |
| 3 | asset lookup | `GEM/importmap-rails/lib/importmap/map.rb:279` † | 661.12 | 4% | `app/views/layouts/application.html.erb:26` 50%, `app/controllers/concerns/inline_script_hashes.rb:16` 50% | `module_filename = filename.relative_path_from(absolute_path)` |
| 4 | error page | `GEM/prism/lib/prism/node.rb:2797` | 137.83 | 2% | `no app frame` 100%, `app/views/rooms/show.html.erb:17` 0% | `compact = [] #: Array[Prism::node]` |
| 5 | template compile | `GEM/herb/lib/herb.rb:72` | 125.09 | 6% | `no app frame` 47%, `config/initializers/uploaded_script_guard.rb:24` 15% | `Backend.parse(...)` |
| 6 | error page | `RAILS/actionpack/lib/action_dispatch/middleware/exception_wrapper.rb:336` | 101.59 | 2% | `no app frame` 100% | `lines = source_lines.drop(start).take(6)` |
| 7 | error page | `GEM/prism/lib/prism/node.rb:18058` | 93.02 | 2% | `no app frame` 100%, `app/views/rooms/refreshes/show.turbo_stream.erb:2` 0% | `[*body]` |
| 8 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:40` | 78.91 | 95% | `app/models/message/pagination.rb:23` 31%, `app/models/session.rb:11` 14% | `binds = binds.inspect` |
| 9 | error page | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:205` | 75.86 | 2% | `no app frame` 100% | `add_filter(&Ractors.shareable_proc  { \|line\| line.sub(gems_regexp, gem` |
| 10 | error page | `GEM/prism/lib/prism/node.rb:841` | 67.18 | 2% | `no app frame` 100%, `app/views/rooms/show.html.erb:17` 0% | `[*arguments]` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| ruby default gem: uri | 2998.7 | 3003.8 | `generic.rb:1007` 532.1, `rfc3986_parser.rb:85` 183.7, `common.rb:108` 183.6 |
| ruby stdlib | 2873.0 | 3188.2 | `base.rb:94` 2765.9, `ipaddr.rb:725` 10.4, `digest.rb:56` 7.9 |
| ruby default gem: prism | 1897.8 | 2063.7 | `parse_result.rb:70` 1147.7, `node.rb:2797` 137.8, `node.rb:18058` 93.0 |
| rails: activesupport | 1749.6 | 1776.1 | `output_safety.rb:243` 101.7, `util.rb:159` 91.5, `output_safety.rb:72` 88.0 |
| rails: activerecord | 1583.1 | 1592.2 | `log_subscriber.rb:40` 78.9, `where_clause.rb:29` 39.3, `integration.rb:59` 37.5 |
| rails: actionpack | 1414.7 | 1453.6 | `url.rb:326` 288.6, `url.rb:342` 266.4, `exception_wrapper.rb:336` 101.6 |
| rails: actionview | 1051.2 | 1066.6 | `tag_helper.rb:1587` 193.6, `tag_helper.rb:1591` 80.1, `tag_helper.rb:1511` 59.4 |
| gem: importmap-rails | 833.3 | 902.4 | `map.rb:279` 661.1, `importmap_tags_helper.rb:30` 31.4, `importmap_tags_helper.rb:44` 31.4 |
| gem: rack | 611.6 | 613.9 | `request.rb:693` 364.4, `request.rb:595` 178.4, `utils.rb:408` 7.4 |
| app | 589.0 | 616.7 | `inline_script_hashes.rb:42` 88.9, `inline_script_hashes.rb:43` 88.9, `inline_script_hashes.rb:40` 88.9 |
| gem: nokogiri | 458.0 | 459.0 | `node.rb:66` 35.8, `node.rb:1429` 23.9, `searchable.rb:270` 20.3 |
| gem: herb | 275.3 | 296.9 | `herb.rb:72` 125.1, `compiler.rb:713` 31.2, `compiler.rb:559` 25.0 |
| rails: activemodel | 156.0 | 158.5 | `attribute.rb:9` 22.3, `builder.rb:37` 19.6, `string.rb:39` 11.7 |
| gem: json | 118.3 | 119.8 | `common.rb:364` 108.9, `common.rb:1089` 7.2, `common.rb:967` 2.2 |
| gem: sqlite3 | 110.4 | 110.7 | `statement.rb:125` 35.9, `statement.rb:54` 20.3, `statement.rb:186` 16.2 |
| rails: actiontext | 102.7 | 103.2 | `bottom_up_reducer.rb:12` 8.9, `html_conversion.rb:23` 8.0, `plain_text_conversion.rb:25` 7.5 |
| gem: logger | 59.6 | 59.6 | `logger.rb:692` 19.9, `log_device.rb:165` 19.9, `log_device.rb:33` 19.9 |
| gem: tzinfo | 53.8 | 53.8 | `timestamp.rb:208` 24.2, `constant_offset_data_timezone_info.rb:52` 13.3, `timestamp.rb:193` 13.3 |
| gem: propshaft | 43.3 | 47.3 | `static.rb:18` 36.5, `helper.rb:85` 5.4, `server.rb:62` 1.0 |
| gem: useragent | 29.4 | 30.1 | `base.rb:120` 21.9, `version.rb:27` 1.4, `user_agent.rb:25` 0.7 |
| gem: loofah | 28.1 | 28.6 | `scrubber.rb:132` 7.8, `concerns.rb:172` 7.3, `concerns.rb:43` 6.0 |
| gem: concurrent-ruby | 22.2 | 22.3 | `safe_initialization.rb:30` 6.0, `non_concurrent_map_backend.rb:131` 3.3, `mutex_lockable_object.rb:33` 2.0 |
| rails: activestorage | 17.3 | 18.4 | `one.rb:34` 3.5, `model.rb:141` 2.3, `model.rb:309` 1.6 |
| gem: rails-html-sanitizer | 15.6 | 15.7 | `sanitizer.rb:191` 1.8, `sanitizer.rb:33` 1.8, `sanitizer.rb:56` 1.8 |
| gem: turbo-rails | 15.2 | 15.4 | `frames_helper.rb:42` 9.1, `request_id_tracking.rb:10` 1.0, `stream_name.rb:28` 0.8 |
| gem: globalid | 11.5 | 11.7 | `gid.rb:95` 2.8, `gid.rb:159` 2.4, `gid.rb:166` 1.2 |
| ruby default gem: openssl | 11.1 | 11.3 | `hmac.rb:55` 3.7, `hmac.rb:57` 3.7, `digest.rb:38` 2.9 |
| gem: base64 | 11.1 | 11.1 | `base64.rb:283` 7.8, `base64.rb:310` 3.2, `base64.rb:373` 0.0 |
| rails: railties | 9.0 | 9.2 | `logger.rb:57` 2.0, `logger.rb:37` 1.0, `logger.rb:65` 1.0 |
| gem: bcrypt | 7.9 | 7.9 | `password.rb:102` 2.5, `password.rb:103` 1.2, `engine.rb:70` 1.2 |
| gem: i18n | 5.7 | 6.0 | `fallbacks.rb:98` 0.9, `ruby.rb:33` 0.7, `utils.rb:8` 0.6 |
| ruby default gem: securerandom | 4.8 | 4.8 | `securerandom.rb:71` 4.8 |
| rails: activejob | 4.1 | 4.3 | `log_subscriber.rb:202` 0.6, `enqueuing.rb:62` 0.3, `queue_adapter.rb:11` 0.3 |
| gem: rack-session | 4.0 | 4.0 | `id.rb:275` 1.0, `id.rb:277` 1.0, `id.rb:401` 0.9 |
| test harness: webmock | 3.7 | 5.9 | `headers.rb:69` 0.7, `headers.rb:68` 0.6, `headers.rb:16` 0.3 |
| gem: addressable | 3.2 | 4.0 | `uri.rb:136` 0.2, `uri.rb:486` 0.2, `uri.rb:1544` 0.2 |
| gem: debug | 3.2 | 5.0 | `thread_client.rb:903` 0.9, `thread_client.rb:223` 0.5, `session.rb:140` 0.5 |
| gem: surfguard | 2.9 | 3.2 | `surfguard.rb:344` 0.3, `surfguard.rb:205` 0.2, `surfguard.rb:337` 0.2 |
| gem: jbuilder | 2.8 | 2.9 | `jbuilder_template.rb:140` 1.2, `jbuilder.rb:342` 0.6, `jbuilder_template.rb:72` 0.3 |
| gem: ruby-vips | 2.6 | 4.1 | `object.rb:201` 0.3, `object.rb:202` 0.3, `object.rb:203` 0.3 |
| gem: ffi | 1.8 | 2.5 | `managedstruct.rb:80` 0.6, `struct_by_reference.rb:69` 0.5, `autopointer.rb:88` 0.5 |
| rails: actioncable | 1.8 | 1.9 | `broadcasting.rb:57` 0.4, `test.rb:24` 0.2, `subscriber_map.rb:9` 0.2 |
| gem: mocha | 1.2 | 1.4 | `expectation_list.rb:55` 0.2, `parameters_matcher.rb:37` 0.2, `invocation.rb:45` 0.1 |
| gem: marcel | 0.7 | 1.0 | `magic.rb:18` 0.1, `mime_type.rb:136` 0.1, `magic.rb:197` 0.1 |
| ruby default gem: prettyprint | 0.6 | 0.7 | `prettyprint.rb:403` 0.2, `prettyprint.rb:263` 0.1, `prettyprint.rb:458` 0.1 |
| gem: erubi | 0.6 | 0.6 | `erubi.rb:134` 0.3, `erubi.rb:137` 0.1, `erubi.rb:139` 0.1 |
| gem: image_processing | 0.4 | 0.5 | `vips.rb:221` 0.1, `pipeline.rb:14` 0.0, `pipeline.rb:62` 0.0 |
| ruby default gem: pp | 0.3 | 0.3 | `pp.rb:542` 0.1, `pp.rb:271` 0.1, `pp.rb:550` 0.1 |
| gem: geared_pagination | 0.2 | 0.2 | `recordset.rb:35` 0.0, `ratios.rb:6` 0.0, `portion_at_offset.rb:20` 0.0 |
| gem: lexxy | 0.1 | 0.1 | `lexxy_editor.rb:6` 0.1, `remote_video.rb:8` 0.0, `blob_with_preview_url.rb:6` 0.0 |
| ruby default gem: timeout | 0.1 | 0.1 | `timeout.rb:292` 0.0, `timeout.rb:152` 0.0, `timeout.rb:293` 0.0 |
| gem: rqrcode_core | 0.1 | 28.9 | `qr_alphanumeric.rb:20` 0.0, `qr_numeric.rb:14` 0.0, `qr_code.rb:214` 0.0 |
| ruby default gem: net-protocol | 0.0 | 0.0 | `protocol.rb:323` 0.0, `protocol.rb:283` 0.0, `protocol.rb:341` 0.0 |
| gem: rqrcode | 0.0 | 3.1 | `qrcode.rb:15` 0.0, `svg.rb:242` 0.0, `svg.rb:264` 0.0 |
| lowrail-profile | 0.0 | 0.0 | `profile.rb:55` 0.0, `profile.rb:65` 0.0 |
| ruby default gem: erb | 0.0 | 0.0 | `util.rb:65` 0.0 |
| gem: zeitwerk | 0.0 | 0.0 | `cref.rb:57` 0.0, `loader.rb:511` 0.0, `inflector.rb:16` 0.0 |
| ruby default gem: psych | 0.0 | 2.3 | `to_ruby.rb:20` 0.0, `psych.rb:696` 0.0, `to_ruby.rb:173` 0.0 |
| ruby default gem: bundler | 0.0 | 0.0 | `rubygems_integration.rb:206` 0.0, `rubygems_integration.rb:201` 0.0, `shared_helpers.rb:22` 0.0 |
| gem: rails_autolink | 0.0 | 0.2 | `helpers.rb:6` 0.0, `helpers.rb:0` 0.0, `helpers.rb:84` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Jobs

| # | Job | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | Room::DestroyJob#perform | 2 / 2 | 7376.0 / 7376.0 | 0.0 | 4578.5 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 156.0, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 92.0, `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 86.0 | `app/models/room.rb:72` 4037.0, `app/models/room.rb:73` 366.0, `app/models/room.rb:66` 357.0 |
| 2 | Room::PushMessageJob#perform | 10 / 10 | 3444.9 / 3444.9 | 0.0 | 3513.4 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 60.7, `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 50.8, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 49.8 | `app/models/room.rb:91` 512.9, `lib/web_push/pool.rb:13` 389.6, `app/models/message/mentionee.rb:11` 385.3 |
| 3 | Message::BroadcastUnreadRoomJob#perform | 3 / 3 | 963.5 / 978.5 | 15.0 | 989.7 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 24.0, `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 15.0, `RAILS/activerecord/lib/active_record/relation/spawn_methods.rb:10` 13.0 | `app/models/message/broadcasts.rb:18` 239.0, `app/models/message/broadcasts.rb:16` 152.5, `app/models/message/broadcasts.rb:27` 151.5 |
| 4 | Bot::WebhookJob#perform | 1 / 1 | – / – |  | 2285.0 |  |  |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `RAILS/activerecord/lib/active_record/log_subscriber.rb:40` (debug logging) | 78.38 / 78.38 | 100% | `app/models/room/message_pusher.rb:10` 20%, `no app frame` 13% | `binds = binds.inspect` |
| 2 | `RAILS/activesupport/lib/active_support/colorize_logging.rb:64` (debug logging) | 51.0 / 51.0 | 100% | `no app frame` 21%, `app/models/room.rb:72` 19% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 3 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | 47.75 / 47.75 | 100% | `app/models/room.rb:72` 19%, `app/models/message/mentionee.rb:11` 15% | `WhereClause.new(predicates \| other.predicates)` |
| 4 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` | 46.38 / 46.38 | 100% | `app/models/room.rb:72` 11%, `app/models/room/message_pusher.rb:54` 11% | `WhereClause.new(predicates + other.predicates)` |
| 5 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` | 42.75 / 42.75 | 100% | `app/models/room.rb:91` 20%, `app/models/room/message_pusher.rb:35` 13% | `to_h { \|elem\| [elem, yield(elem)] } # rubocop:disable Rails/IndexWith` |
| 6 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` | 40.44 / 40.44 | 100% | `app/models/room.rb:91` 16%, `lib/web_push/pool.rb:13` 15% | `val = step` |
| 7 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:118` | 37.5 / 37.5 | 100% | `app/models/room/message_pusher.rb:54` 19%, `app/models/room.rb:72` 11% | `attributes.flat_map do \|key, value\|` |
| 8 | `RAILS/activerecord/lib/arel/table.rb:92` | 36.31 / 36.31 | 100% | `lib/web_push/pool.rb:13` 17%, `app/models/room.rb:72` 11% | `Attribute.new(table, name)` |
| 9 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:28` | 35.0 / 35.0 | 100% | `app/models/room/message_pusher.rb:54` 14%, `app/models/room.rb:72` 12% | `attributes.each_with_object([]) do \|(key, value), result\|` |
| 10 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:203` | 35.0 / 35.0 | 100% | `app/models/room/message_pusher.rb:54` 14%, `app/models/room.rb:72` 12% | `attributes.each_with_object({}) do \|(key, value), converted\|` |

### Action Cable

| # | Channel action | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | PresenceChannel#subscribed | 7 / 7 | 927.7 / 927.7 | 0.0 | 854.4 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 22.7, `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 19.3, `RAILS/activerecord/lib/active_record/key.rb:87` 14.0 | `app/channels/presence_channel.rb:21` 284.8, `app/channels/room_channel.rb:12` 236.5, `app/models/membership/connectable.rb:17` 90.3 |
| 2 | RoomMessagesChannel#subscribed | 7 / 7 | 468.5 / 468.5 | 0.0 | 496.0 | `RAILS/activesupport/lib/active_support/callbacks.rb:180` 14.7, `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/synchronization/safe_initialization.rb:30` 11.0, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 8.0 | `app/channels/room_messages_channel.rb:30` 144.2, `app/channels/room_messages_channel.rb:36` 122.7, `app/channels/room_messages_channel.rb:52` 11.7 |
| 3 | Turbo::StreamsChannel#subscribed | 2 / 2 | 116.0 / 116.0 | 0.0 | 127.0 | `RAILS/activesupport/lib/active_support/callbacks.rb:180` 8.0, `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/synchronization/safe_initialization.rb:30` 6.0, `RAILS/actioncable/lib/action_cable/server/tagged_logger_proxy.rb:27` 4.0 | `app/channels/concerns/room_streams_are_authorized.rb:10` 34.0, `app/channels/concerns/room_streams_are_authorized.rb:7` 16.0 |
| 4 | UnreadRoomsChannel#subscribed | 3 / 3 | 82.5 / 82.5 | 0.0 | 86.0 | `RAILS/activesupport/lib/active_support/callbacks.rb:180` 8.0, `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/synchronization/safe_initialization.rb:30` 6.0, `RAILS/actioncable/lib/action_cable/server/tagged_logger_proxy.rb:27` 4.0 | `app/channels/unread_rooms_channel.rb:10` 18.5 |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `RAILS/activerecord/lib/active_record/log_subscriber.rb:40` (debug logging) | 14.84 / 14.84 | 63% | `app/channels/presence_channel.rb:21` 26%, `app/channels/room_channel.rb:12` 23% | `binds = binds.inspect` |
| 2 | `RAILS/activesupport/lib/active_support/callbacks.rb:180` | 11.37 / 11.37 | 100% | `no app frame` 100% | `result_lambda = -> { user_callback.call target, value }` |
| 3 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | 10.32 / 10.32 | 63% | `app/channels/room_channel.rb:12` 40%, `app/channels/presence_channel.rb:21` 31% | `WhereClause.new(predicates \| other.predicates)` |
| 4 | `RAILS/activesupport/lib/active_support/colorize_logging.rb:64` (debug logging) | 8.53 / 8.53 | 63% | `app/channels/presence_channel.rb:21` 28%, `app/channels/room_channel.rb:12` 24% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 5 | `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/synchronization/safe_initialization.rb:30` | 8.53 / 8.53 | 100% | `no app frame` 100% | `super(*args, &block)` |
| 6 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` | 8.21 / 8.21 | 47% | `app/channels/presence_channel.rb:21` 47%, `app/channels/room_messages_channel.rb:36` 23% | `to_h { \|elem\| [elem, yield(elem)] } # rubocop:disable Rails/IndexWith` |
| 7 | `RAILS/activesupport/lib/active_support/colorize_logging.rb:62` (debug logging) | 5.68 / 5.68 | 63% | `app/channels/presence_channel.rb:21` 28%, `app/channels/room_channel.rb:12` 24% | `modes = MODES.values_at(*options.compact_blank.keys)` |
| 8 | `RAILS/activerecord/lib/arel/table.rb:92` | 5.53 / 5.53 | 63% | `app/channels/room_channel.rb:12` 28%, `app/models/membership/connectable.rb:17` 21% | `Attribute.new(table, name)` |
| 9 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` | 5.47 / 5.47 | 63% | `app/channels/presence_channel.rb:21` 38%, `app/channels/room_messages_channel.rb:36` 26% | `val = step` |
| 10 | `RAILS/activerecord/lib/active_record/key.rb:14` | 5.26 / 5.26 | 58% | `app/channels/presence_channel.rb:21` 62%, `app/channels/room_channel.rb:12` 23% | `Single.new(name)` |
