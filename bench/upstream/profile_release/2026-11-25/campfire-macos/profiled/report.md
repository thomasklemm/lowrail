# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails test -v`
* Ruby: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [arm64-darwin23]
* Rails: 8.2.0.alpha, test environment
* Counted in run 1: 666 requests, 16 jobs, 19 Cable actions in 5 processes; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 5 | 666 | 20435.4 | 16 | 0 | 19 | 0 |
| run2 | 5 | 666 | 20435.9 | 16 | 0 | 19 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.02 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/controllers/concerns/inline_script_hashes.rb:40` | `script_locations` | 2344.65 | 0.0 | 63.24 | `GEM/uri/lib/uri/generic.rb:1007` 16%, `GEM/uri/lib/uri/common.rb:108` 6%, `GEM/uri/lib/uri/rfc3986_parser.rb:85` 6% | SessionsController#create 53%, RoomsController#show 15%, MessagesController#index 7% | `url = URI.join(request.base_url, url)` |
| 2 | `app/controllers/concerns/inline_script_hashes.rb:41` | `script_locations` | 513.92 | 0.0 | 0.0 | `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 25%, `RAILS/actionpack/lib/action_dispatch/http/url.rb:342` 24%, `GEM/rack/lib/rack/request.rb:693` 24% | SessionsController#create 52%, RoomsController#show 15%, MessagesController#index 7% | `origin = url.origin == request.base_url ? request.host_with_port : url` |
| 3 | `app/models/message/pagination.rb:23` | `preload_associations` | 480.8 | 69.44 | 0.0 | `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:28` 3%, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:49` 2%, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:77` 2% | RoomsController#show 54%, MessagesController#index 39%, Messages::ByBotsController#index 5% | `@relation.preload_associations(records)` |
| 4 | `app/models/session.rb:11` | `start!` | 147.53 | 75.74 | 0.37 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 5%, `GEM/securerandom/lib/securerandom.rb:71` 2%, `GEM/sqlite3/lib/sqlite3/statement.rb:58` 2% | SessionsController#create 97%, Users::ProfilesController#update 3%, FirstRunsController#create 0% | `create! user_agent: user_agent, ip_address: ip_address` |
| 5 | `app/helpers/messages_helper.rb:107` | `text_message_presentation` | 130.6 | 22.27 | 0.67 | `GEM/nokogiri/lib/nokogiri/html5/node.rb:66` 5%, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1429` 3%, `GEM/nokogiri/lib/nokogiri/xml/document.rb:416` 3% | MessagesController#index 57%, RoomsController#show 34%, MessagesController#create 7% | `render = -> { auto_link_text h(ContentFilters::TextMessagePresentation` |
| 6 | `app/views/layouts/application.html.erb:23` |  | 105.47 | 50.41 | 0.35 | `RAILS/actionview/lib/action_view/helpers/asset_tag_helper.rb:683` 10%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 10%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:243` 7% | RoomsController#show 67%, Users::SidebarsController#show 10%, SearchesController#index 5% | `<%= stylesheet_link_tag :all, "data-turbo-track": "reload" %>` |
| 7 | `app/views/layouts/application.html.erb:26` |  | 95.98 | 343.93 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:159` 22%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 22%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:243` 12% | RoomsController#show 70%, Users::SidebarsController#show 9%, SearchesController#index 5% | `<%= javascript_importmap_tags %>` |
| 8 | `app/helpers/messages_helper.rb:94` | `message_fragment_cache_key` | 80.71 | 0.0 | 0.0 | `GEM/nokogiri/lib/nokogiri/css/selector_cache.rb:33` 5%, `GEM/nokogiri/lib/nokogiri/xml/document_fragment.rb:175` 5%, `GEM/nokogiri/lib/nokogiri/css/xpath_visitor.rb:94` 5% | RoomsController#show 60%, MessagesController#index 39%, Rooms::RefreshesController#show 1% | `body = message.body.body` |
| 9 | `app/controllers/concerns/inline_script_hashes.rb:39` | `script_locations` | 71.64 | 0.0 | 2.11 | `GEM/json/lib/json/common.rb:364` 100% | SessionsController#create 54%, RoomsController#show 16%, MessagesController#index 7% | `JSON.parse(importmap)["imports"].values.map do \|url\|` |
| 10 | `app/controllers/sessions_controller.rb:11` | `create` | 67.9 | 19.57 | 0.71 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 6%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 4%, `GEM/bcrypt/lib/bcrypt/password.rb:102` 3% | SessionsController#create 100% | `if user = User.active.authenticate_by(email_address: params[:email_add` |
| 11 | `app/views/messages/_actions.html.erb:18` |  | 67.46 | 0.0 | 4.22 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 25%, `RAILS/actionview/lib/action_view/helpers/form_tag_helper.rb:1084` 12%, `RAILS/actionview/lib/action_view/helpers/form_tag_helper.rb:308` 12% | MessagesController#index 58%, RoomsController#show 35%, MessagesController#create 4% | `<%= hidden_field_tag "boost[content]", character %>` |
| 12 | `app/models/current.rb:15` | `account` | 66.8 | 27.17 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 8%, `RAILS/activerecord/lib/active_record/relation/finder_methods.rb:673` 3%, `RAILS/activerecord/lib/active_record/relation/finder_methods.rb:675` 3% | RoomsController#show 68%, Users::SidebarsController#show 9%, AccountsController#edit 5% | `Account.first` |
| 13 | `app/helpers/messages_helper.rb:123` | `auto_link_text` | 60.54 | 0.0 | 0.51 | `GEM/nokogiri/lib/nokogiri/html5/node.rb:66` 10%, `GEM/nokogiri/lib/nokogiri/xml/document.rb:416` 10%, `GEM/loofah/lib/loofah/scrubber.rb:132` 7% | MessagesController#index 57%, RoomsController#show 34%, MessagesController#create 6% | `fragment = Nokogiri::HTML5.fragment(sanitize(html, tags: AUTO_LINK_ALL` |
| 14 | `app/helpers/messages_helper.rb:100` | `message_fragment_cache_key` | 57.89 | 0.0 | 4.74 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 43%, `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 23%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 9% | RoomsController#show 60%, MessagesController#index 39%, Rooms::RefreshesController#show 1% | `dependencies = [ message.attributes, room.attributes.slice("id", "type` |
| 15 | `app/models/message.rb:26` | `plain_text_body` | 55.82 | 0.44 | 0.0 | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:270` 5%, `GEM/nokogiri/lib/nokogiri/css/xpath_visitor.rb:94` 5%, `GEM/nokogiri/lib/nokogiri/css/selector_cache.rb:33` 5% | MessagesController#index 45%, RoomsController#show 34%, Messages::ByBotsController#index 10% | `content = body.body` |
| 16 | `app/models/message/attachment.rb:20` | `create_with_attachment!` | 52.81 | 12.48 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 2%, `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 2%, `RAILS/activerecord/lib/active_record/key.rb:27` 2% | MessagesController#create 68%, Messages::ByBotsController#create 32% | `create!(attributes).tap(&:process_attachment)` |
| 17 | `app/views/messages/_message.html.erb:4` |  | 47.31 | 9.95 | 1.36 | `RAILS/activesupport/lib/active_support/core_ext/object/to_query.rb:50` 30%, `RAILS/activesupport/lib/active_support/core_ext/object/to_query.rb:10` 7%, `RAILS/activesupport/lib/active_support/cache.rb:1045` 5% | RoomsController#show 60%, MessagesController#index 40%, Rooms::RefreshesController#show 1% | `<% cache [ message_fragment_cache_key(message), "presentation-v8" ] do` |
| 18 | `config/routes.rb:59` |  | 47.2 | 0.0 | 2.02 | `RAILS/activesupport/lib/active_support/core_ext/object/to_query.rb:16` 6%, `RAILS/activesupport/lib/active_support/time_with_zone.rb:265` 4%, `RAILS/actionpack/lib/action_dispatch/journey/formatter.rb:134` 4% | RoomsController#show 48%, MessagesController#index 37%, Users::SidebarsController#show 6% | `route_for :user_avatar, user.avatar_token, v: user.updated_at.to_fs(:n` |
| 19 | `app/controllers/concerns/authentication.rb:94` | `set_authentication_cookie` | 46.36 | 0.0 | 0.65 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:171` 8%, `RAILS/activesupport/lib/active_support/core_ext/hash/keys.rb:40` 8%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:166` 6% | SessionsController#create 62%, RoomsController#show 14%, MessagesController#index 6% | `cookies.signed.permanent[:session_token] = { value: session.token, htt` |
| 20 | `app/helpers/messages_helper.rb:36` | `message_tag` | 45.63 | 0.0 | 0.68 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1591` 33%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 19%, `RAILS/activesupport/lib/active_support/inflector/methods.rb:259` 16% | RoomsController#show 48%, MessagesController#index 46%, MessagesController#create 3% | `tag.div id: dom_id(message),` |
| 21 | `app/models/message/pagination.rb:10` | `load` | 45.42 | 6.98 | 0.14 | `RAILS/activerecord/lib/active_record/key.rb:87` 14%, `RAILS/activerecord/lib/active_record/key.rb:14` 14%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 7% | RoomsController#show 52%, MessagesController#index 41%, Messages::ByBotsController#index 6% | `new(relation.skip_preloading!.public_send(direction, size), relation)` |
| 22 | `app/models/ban.rb:7` | `banned?` | 44.35 | 23.9 | 0.0 | `RAILS/activerecord/lib/active_record/relation/finder_methods.rb:439` 4%, `GEM/sqlite3/lib/sqlite3/statement.rb:54` 3%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:28` 2% | SessionsController#create 79%, MessagesController#create 5%, Users::ProfilesController#update 4% | `exists?(ip_address: ip_address)` |
| 23 | `app/helpers/content_filters/sanitize_attributes.rb:11` | `apply` | 41.31 | 0.0 | 0.51 | `GEM/nokogiri/lib/nokogiri/html5/node.rb:66` 15%, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1429` 10%, `GEM/nokogiri/lib/nokogiri/xml/document.rb:416` 8% | MessagesController#index 58%, RoomsController#show 34%, MessagesController#create 5% | `sanitizer.sanitize fragment.to_html, tags: allowed_tags, attributes: a` |
| 24 | `app/views/messages/_message.html.erb:26` |  | 39.07 | 28.47 | 2.05 | `RAILS/activerecord/lib/active_record/integration.rb:59` 10%, `RAILS/actionpack/lib/action_dispatch/http/url.rb:205` 3%, `RAILS/actionpack/lib/action_dispatch/http/url.rb:239` 3% | RoomsController#show 48%, MessagesController#index 46%, MessagesController#create 3% | `<%= render "messages/actions", message: message, url: room_at_message_` |
| 25 | `app/helpers/users/avatars_helper.rb:14` | `avatar_tag` | 38.25 | 0.0 | 4.63 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 10%, `RAILS/activerecord/lib/active_record/integration.rb:59` 7%, `RAILS/actionpack/lib/action_dispatch/journey/formatter.rb:134` 5% | RoomsController#show 52%, MessagesController#index 42%, MessagesController#create 3% | `link_to user_path(user), title: user.title, class: "btn avatar", data:` |
| 26 | `app/views/messages/boosts/_boosts.html.erb:5` |  | 35.84 | 25.17 | 2.69 | `RAILS/actionview/lib/action_view/renderer/collection_renderer.rb:150` 6%, `RAILS/actionview/lib/action_view/renderer/abstract_renderer.rb:44` 4%, `RAILS/actionview/lib/action_view/renderer/collection_renderer.rb:121` 4% | RoomsController#show 38%, MessagesController#index 37%, MessagesController#create 13% | `<%= render partial: "messages/boosts/boost", collection: message.boost` |
| 27 | `app/views/rooms/show.html.erb:17` |  | 34.15 | 7.36 | 0.31 | `RAILS/activesupport/lib/active_support/core_ext/object/to_query.rb:50` 31%, `RAILS/activesupport/lib/active_support/core_ext/object/to_query.rb:10` 12%, `RAILS/activesupport/lib/active_support/cache.rb:1045` 12% | RoomsController#show 100% | `<%= render partial: "messages/message", collection: @messages, cached:` |
| 28 | `app/helpers/users/avatars_helper.rb:15` | `avatar_tag` | 33.56 | 0.0 | 3.71 | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:704` 22%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 11%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:159` 8% | RoomsController#show 52%, MessagesController#index 41%, MessagesController#create 3% | `image_tag fresh_user_avatar_path(user), aria: { hidden: "true" }, size` |
| 29 | `app/helpers/content_filters/remove_solo_unfurled_link_text.rb:6` | `applicable?` | 33.44 | 0.0 | 0.0 | `RAILS/actiontext/lib/action_text/bottom_up_reducer.rb:12` 9%, `RAILS/actiontext/lib/action_text/plain_text_conversion.rb:25` 8%, `RAILS/actiontext/lib/action_text/bottom_up_reducer.rb:25` 6% | MessagesController#index 58%, RoomsController#show 33%, MessagesController#create 6% | `normalize_tweet_url(solo_unfurled_url) == normalize_tweet_url(content.` |
| 30 | `app/controllers/concerns/authentication/session_lookup.rb:7` | `find_session_by_cookie` | 33.3 | 11.86 | 0.24 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 8%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 3% | RoomsController#show 31%, MessagesController#index 19%, MessagesController#create 10% | `[ session, session&.user ]` |

App middleware that hands the request on (the stack below it, not its own work): `config/initializers/uploaded_script_guard.rb:24` 163.12 warm objects per request.

291.78 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | MessagesController#index | 38 / 38 | 29370.8 / 29371.2 | 0.4 | 27015.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 795.2, `GEM/uri/lib/uri/generic.rb:1007` 550.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1591` 482.1 | `app/models/message/pagination.rb:23` 3806.2, `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/helpers/messages_helper.rb:107` 1489.8 |
| 2 | RoomsController#show | 78 / 78 | 25281.7 / 25281.7 | 0.1 | 28104.1 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 613.1, `GEM/uri/lib/uri/generic.rb:1007` 491.0, `GEM/rack/lib/rack/request.rb:693` 376.1 | `app/controllers/concerns/inline_script_hashes.rb:40` 3266.5, `app/models/message/pagination.rb:23` 2372.2, `app/controllers/concerns/inline_script_hashes.rb:41` 726.2 |
| 3 | WelcomeController#show | 14 / 14 | 23746.2 / 23747.9 | 1.7 | 21010.4 | `GEM/rack/lib/rack/request.rb:693` 372.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 294.9, `GEM/uri/lib/uri/rfc3986_parser.rb:85` 284.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3077.2, `app/controllers/concerns/inline_script_hashes.rb:16` 971.8, `app/controllers/concerns/inline_script_hashes.rb:41` 760.0 |
| 4 | SessionsController#create | 251 / 251 | 18474.3 / 18475.1 | 0.8 | 19204.7 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 367.3, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 274.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3341.8, `app/controllers/concerns/inline_script_hashes.rb:41` 717.8, `app/models/session.rb:11` 385.8 |
| 5 | AccountsController#edit | 5 / 5 | 16459.5 / 16457.0 | -2.5 | 71462.8 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 635.0, `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/models/current.rb:15` 1051.5, `app/views/layouts/application.html.erb:23` 903.0 |
| 6 | Rooms::RefreshesController#show | 3 / 3 | 16300.0 / 16307.0 | 7.0 | 19791.3 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 376.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 281.0 | `app/models/message/pagination.rb:23` 4614.0, `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0 |
| 7 | MessagesController#show | 5 / 5 | 14860.7 / 14858.7 | -2.0 | 19905.6 | `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 843.0, `GEM/uri/lib/uri/generic.rb:1007` 550.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 428.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3494.3, `app/controllers/concerns/inline_script_hashes.rb:41` 1140.0, `app/views/layouts/application.html.erb:23` 903.0 |
| 8 | RoomsController#destroy | 5 / 5 | 14522.5 / 14521.5 | -1.0 | 73009.8 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 274.0 | `app/models/room.rb:72` 3800.0, `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0 |
| 9 | Messages::ByBotsController#create | 13 / 13 | 13630.1 / 13625.1 | -5.0 | 12079.8 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 364.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 281.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/models/message/attachment.rb:20` 1388.6, `app/controllers/concerns/inline_script_hashes.rb:41` 720.1 |
| 10 | MessagesController#create | 21 / 21 | 13618.2 / 13619.3 | 1.1 | 13566.3 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 422.5, `GEM/rack/lib/rack/request.rb:693` 325.3 | `app/controllers/concerns/inline_script_hashes.rb:40` 3400.6, `app/models/message/attachment.rb:20` 1503.9, `app/controllers/concerns/inline_script_hashes.rb:41` 855.0 |
| 11 | Messages::ByBotsController#index | 12 / 12 | 13466.6 / 13466.9 | 0.3 | 15972.3 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 365.1, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 359.1 | `app/controllers/concerns/inline_script_hashes.rb:40` 3408.7, `app/models/message/pagination.rb:23` 2265.1, `app/views/messages/_message.json.jbuilder:8` 1080.6 |
| 12 | Users::ProfilesController#show | 10 / 10 | 13118.5 / 13115.7 | -2.8 | 17845.3 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 493.7, `GEM/rack/lib/rack/request.rb:693` 370.7 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `app/controllers/users/profiles_controller.rb:10` 606.7 |
| 13 | Messages::BoostsController#index | 4 / 4 | 12539.0 / 12541.0 | 2.0 | 18409.5 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 393.0, `GEM/rack/lib/rack/request.rb:693` 372.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/views/layouts/application.html.erb:23` 903.0, `app/views/layouts/application.html.erb:26` 748.0 |
| 14 | Users::SidebarsController#show | 17 / 17 | 12422.1 / 12422.1 | 0.0 | 17101.8 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 373.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 282.8 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `app/views/layouts/application.html.erb:23` 602.0 |
| 15 | SessionsController#new | 8 / 8 | 11194.3 / 11197.0 | 2.7 | 11262.3 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 370.3, `GEM/rack/lib/rack/request.rb:693` 365.3 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/views/layouts/application.html.erb:23` 903.0, `app/views/layouts/application.html.erb:26` 748.0 |
| 16 | SearchesController#index | 9 / 9 | 11009.0 / 11013.0 | 4.0 | 29319.8 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.8, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 306.4 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/views/layouts/application.html.erb:23` 722.4, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0 |
| 17 | Rooms::DirectsController#create | 3 / 3 | 8645.0 / 8656.0 | 11.0 | 10717.0 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 380.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 280.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `app/controllers/rooms/directs_controller.rb:28` 614.0 |
| 18 | Rooms::InvolvementsController#update | 5 / 5 | 8549.0 / 8549.0 | 0.0 | 7553.2 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 376.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 277.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `app/controllers/rooms/involvements_controller.rb:23` 704.0 |
| 19 | Users::ProfilesController#update | 16 / 16 | 7548.0 / 7548.1 | 0.1 | 7297.9 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 273.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `app/controllers/users/profiles_controller.rb:14` 425.1 |
| 20 | UnfurlLinksController#create | 12 / 12 | 7015.6 / 7016.6 | 1.0 | 7632.2 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 370.9, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 272.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `lib/restricted_http/private_network_guard.rb:21` 391.3 |
| 21 | Messages::Boosts::ByBotsController#create | 9 / 9 | 6985.0 / 6985.8 | 0.8 | 7550.1 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 365.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 273.3 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `app/controllers/messages/boosts/by_bots_controller.rb:17` 267.8 |
| 22 | SessionsController#destroy | 4 / 4 | 6797.0 / 6795.0 | -2.0 | 6414.0 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 274.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `app/controllers/sessions_controller.rb:37` 288.0 |
| 23 | Users::PushSubscriptionsController#create | 11 / 11 | 6706.0 / 6706.7 | 0.7 | 6924.6 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 371.3, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 272.5 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.2, `config/initializers/uploaded_script_guard.rb:24` 306.8 |
| 24 | Rooms::ClosedsController#update | 5 / 5 | 6540.0 / 6535.0 | -5.0 | 8840.0 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 272.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `config/initializers/uploaded_script_guard.rb:24` 293.0 |
| 25 | Users::BansController#create | 5 / 5 | 6542.5 / 6532.5 | -10.0 | 8262.4 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 273.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `config/initializers/uploaded_script_guard.rb:24` 260.0 |
| 26 | Rooms::DirectsController#destroy | 4 / 4 | 6368.0 / 6376.0 | 8.0 | 7129.3 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 274.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `config/initializers/uploaded_script_guard.rb:24` 270.0 |
| 27 | FirstRunsController#create | 6 / 6 | 6312.5 / 6312.8 | 0.3 | 6548.3 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 365.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 274.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `config/initializers/uploaded_script_guard.rb:24` 272.5 |
| 28 | Accounts::LogosController#show | 5 / 5 | 6141.0 / 6138.0 | -3.0 | 8340.4 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 368.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 272.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `config/initializers/uploaded_script_guard.rb:24` 260.0 |
| 29 | UsersController#new | 3 / 3 | 5911.0 / 5906.0 | -5.0 | 8969.7 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 274.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `config/initializers/uploaded_script_guard.rb:24` 211.0 |
| 30 | Messages::ByBotsController#update | 5 / 5 | 5690.0 / 5680.0 | -10.0 | 8282.8 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 368.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 275.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `config/initializers/uploaded_script_guard.rb:24` 227.0 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/uri/lib/uri/generic.rb:1007` | `split_path` | 528.8 / 528.81 | 0.01 | 532.94 | 97% | String, Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100% | `path.split("/", -1)` |
| 2 | `GEM/rack/lib/rack/request.rb:693` | `split_header` | 362.19 / 362.19 | 0.0 | 364.96 | 99% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 49%, `app/controllers/concerns/inline_script_hashes.rb:41` 48% | `value ? value.strip.split(/[, \t]+/) : []` |
| 3 | `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` | `host` | 286.32 / 286.32 | -0.0 | 289.77 | 100% | String, MatchData |  | `app/controllers/concerns/inline_script_hashes.rb:41` 63%, `app/controllers/concerns/inline_script_hashes.rb:40` 32% | `raw_host_with_port.sub(/:\d+$/, "")` |
| 4 | `RAILS/actionpack/lib/action_dispatch/http/url.rb:342` | `host_with_port` | 264.81 / 264.81 | 0.0 | 266.84 | 99% | String |  | `app/controllers/concerns/inline_script_hashes.rb:41` 66%, `app/controllers/concerns/inline_script_hashes.rb:40` 33% | `"#{host}#{port_string}"` |
| 5 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` | `tag_option` | 198.43 / 198.43 | 0.0 | 198.94 | 32% | String |  | `app/views/layouts/application.html.erb:26` 16%, `app/views/messages/_actions.html.erb:18` 10% | `%(#{key}="#{value}")` |
| 6 | `GEM/uri/lib/uri/rfc3986_parser.rb:85` | `split` | 182.62 / 182.62 | 0.0 | 183.99 | 99% | MatchData, String |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 1% | `if m = RFC3986_URI.match(uri)` |
| 7 | `GEM/uri/lib/uri/common.rb:108` | `escape` | 182.55 / 182.55 | 0.0 | 183.92 | 99% | String, Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 1% | `name.upcase.tr(ReservedChars, EscapedChars)` |
| 8 | `GEM/uri/lib/uri/generic.rb:543` | `split_userinfo` | 179.25 / 179.25 | 0.0 | 180.61 | 100% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 0% | `return nil, nil unless ui` |
| 9 | `GEM/uri/lib/uri/generic.rb:516` | `set_userinfo` | 179.25 / 179.25 | 0.0 | 180.61 | 100% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 0% | `[@user, @password]` |
| 10 | `GEM/uri/lib/uri/common.rb:194` | `for` | 178.04 / 178.04 | 0.0 | 179.4 | 99% | Object |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 0% | `return uri_class.new(scheme, *arguments)` |
| 11 | `GEM/uri/lib/uri/rfc3986_parser.rb:135` | `parse` | 178.04 / 178.04 | 0.0 | 179.4 | 99% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 0% | `URI.for(*self.split(uri), self)` |
| 12 | `GEM/rack/lib/rack/request.rb:595` | `base_url` | 177.32 / 177.32 | 0.0 | 178.67 | 99% | String |  | `app/controllers/concerns/inline_script_hashes.rb:41` 50%, `app/controllers/concerns/inline_script_hashes.rb:40` 50% | `"#{scheme}://#{host_with_port}"` |
| 13 | `GEM/uri/lib/uri/rfc3986_parser.rb:115` | `split` | 173.52 / 173.52 | 0.0 | 174.88 | 97% | String, MatchData |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100%, `app/models/opengraph/fetch.rb:34` 0% | `elsif m = RFC3986_relative_ref.match(uri)` |
| 14 | `GEM/json/lib/json/common.rb:364` | `parse` | 110.35 / 110.33 | -0.02 | 111.09 | 100% | String, Hash |  | `app/controllers/concerns/inline_script_hashes.rb:39` 90%, `app/controllers/concerns/authentication/session_lookup.rb:3` 4% | `Parser.parse(source, opts)` |
| 15 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:243` | `html_safe` | 103.74 / 103.74 | 0.0 | 104.04 | 36% | String |  | `app/views/layouts/application.html.erb:26` 16%, `app/views/layouts/application.html.erb:23` 11% | `ActiveSupport::SafeBuffer.new(self)` |
| 16 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:159` | `xml_name_escape` | 92.92 / 92.92 | 0.0 | 93.26 | 32% | String |  | `app/views/layouts/application.html.erb:26` 34%, `app/helpers/users/avatars_helper.rb:15` 7% | `name = name.to_s` |
| 17 | `GEM/uri/lib/uri/generic.rb:335` | `set_scheme` | 91.88 / 91.88 | 0.0 | 92.56 | 100% | String |  | `app/controllers/concerns/inline_script_hashes.rb:40` 98%, `app/controllers/sessions_controller.rb:13` 1% | `@scheme = v&.downcase` |
| 18 | `GEM/uri/lib/uri/rfc3986_parser.rb:87` | `split` | 91.31 / 91.31 | 0.0 | 91.99 | 99% | String |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 1% | `scheme = m["scheme"]` |
| 19 | `GEM/uri/lib/uri/rfc3986_parser.rb:102` | `split` | 91.28 / 91.28 | 0.0 | 91.96 | 99% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 1% | `[ scheme,` |
| 20 | `GEM/uri/lib/uri/rfc3986_parser.rb:104` | `split` | 91.28 / 91.28 | 0.0 | 91.96 | 99% | String |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 1% | `m["host"],` |
| 21 | `GEM/uri/lib/uri/rfc3986_parser.rb:107` | `split` | 91.28 / 91.28 | 0.0 | 91.96 | 99% | String |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 1% | `(m["path-abempty"] \|\|` |
| 22 | `GEM/uri/lib/uri/http.rb:132` | `origin` | 90.27 / 90.27 | 0.0 | 90.95 | 99% | String |  | `app/controllers/concerns/inline_script_hashes.rb:41` 100% | `"#{scheme}://#{authority}"` |
| 23 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` | `initialize` | 89.67 / 89.67 | 0.0 | 89.96 | 35% | String |  | `app/views/layouts/application.html.erb:26` 19%, `app/views/layouts/application.html.erb:23` 12% | `super` |
| 24 | `GEM/uri/lib/uri/common.rb:274` | `join` | 88.38 / 88.38 | 0.0 | 89.05 | 99% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100% | `DEFAULT_PARSER.join(*str)` |
| 25 | `GEM/uri/lib/uri/rfc3986_parser.rb:116` | `split` | 86.76 / 86.76 | 0.0 | 87.44 | 97% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100%, `app/models/opengraph/fetch.rb:34` 0% | `[ nil, # scheme` |
| 26 | `GEM/uri/lib/uri/generic.rb:1137` | `merge` | 86.76 / 86.76 | 0.0 | 87.43 | 97% | Object |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100% | `base = self.dup` |
| 27 | `GEM/uri/lib/uri/generic.rb:1039` | `merge_path` | 86.49 / 86.49 | 0.0 | 87.16 | 97% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100% | `tmp = []` |
| 28 | `GEM/uri/lib/uri/generic.rb:1051` | `merge_path` | 86.49 / 86.49 | 0.0 | 87.16 | 97% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100% | `base_path = [''] # keep '/' for root directory` |
| 29 | `GEM/uri/lib/uri/generic.rb:1074` | `merge_path` | 86.49 / 86.49 | 0.0 | 87.16 | 97% | String |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100% | `return base_path.join('/')` |
| 30 | `GEM/uri/lib/uri/rfc3986_parser.rb:122` | `split` | 86.49 / 86.49 | 0.0 | 87.16 | 97% | String |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100% | `m["path-absolute"] \|\|` |

## Dev/test-mode work

5981.2 of 15653.1 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | error page | `RUBY/error_highlight/base.rb:94` | 1795.38 | 2% | `no app frame` 100% | `Prism.parse_file(absolute_path).value.breadth_first_search { \|node\| no` |
| 2 | asset lookup | `GEM/importmap-rails/lib/importmap/map.rb:279` † | 751.29 | 5% | `app/controllers/concerns/inline_script_hashes.rb:16` 52%, `app/views/layouts/application.html.erb:26` 48% | `module_filename = filename.relative_path_from(absolute_path)` |
| 3 | error page | `GEM/prism/lib/prism/parse_result.rb:70` | 711.58 | 2% | `no app frame` 100% | `source.lines` |
| 4 | template compile | `GEM/herb/lib/herb.rb:72` | 297.3 | 11% | `no app frame` 20%, `config/initializers/uploaded_script_guard.rb:24` 12% | `Backend.parse(...)` |
| 5 | asset lookup | `GEM/propshaft/lib/propshaft/asset.rb:79` † | 151.77 | 29% | `app/views/layouts/application.html.erb:23` 27%, `app/controllers/concerns/inline_script_hashes.rb:16` 21% | `logical_path.sub(/\.(\w+(\.map)?)$/) { \|ext\| "-#{digest}#{ext}" }` |
| 6 | error page | `GEM/prism/lib/prism/node.rb:2797` | 109.54 | 2% | `no app frame` 99%, `app/views/rooms/show.html.erb:17` 1% | `compact = [] #: Array[Prism::node]` |
| 7 | error page | `GEM/prism/lib/prism/node.rb:18058` | 78.92 | 2% | `no app frame` 100%, `app/views/rooms/show.html.erb:17` 0% | `[*body]` |
| 8 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:40` | 78.68 | 95% | `app/models/message/pagination.rb:23` 31%, `app/models/session.rb:11` 14% | `binds = binds.inspect` |
| 9 | error page | `RAILS/actionpack/lib/action_dispatch/middleware/exception_wrapper.rb:336` | 78.56 | 2% | `no app frame` 100% | `lines = source_lines.drop(start).take(6)` |
| 10 | asset lookup | `GEM/propshaft/lib/propshaft/resolver/dynamic.rb:13` † | 75.89 | 29% | `app/views/layouts/application.html.erb:23` 27%, `app/controllers/concerns/inline_script_hashes.rb:16` 21% | `File.join prefix, asset.digested_path` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| ruby default gem: uri | 2979.5 | 3003.5 | `generic.rb:1007` 528.8, `rfc3986_parser.rb:85` 182.6, `common.rb:108` 182.5 |
| ruby stdlib | 1892.0 | 2674.7 | `base.rb:94` 1795.4, `ipaddr.rb:725` 10.3, `digest.rb:56` 7.9 |
| rails: activesupport | 1723.3 | 1799.9 | `output_safety.rb:243` 103.7, `util.rb:159` 92.9, `output_safety.rb:72` 89.7 |
| rails: activerecord | 1569.6 | 1599.1 | `log_subscriber.rb:40` 78.7, `where_clause.rb:29` 39.4, `integration.rb:59` 38.2 |
| rails: actionpack | 1365.2 | 1432.9 | `url.rb:326` 286.3, `url.rb:342` 264.8, `exception_wrapper.rb:336` 78.6 |
| ruby default gem: prism | 1271.8 | 1672.8 | `parse_result.rb:70` 711.6, `node.rb:2797` 109.5, `node.rb:18058` 78.9 |
| rails: actionview | 1121.3 | 1158.0 | `tag_helper.rb:1587` 198.4, `tag_helper.rb:1591` 82.3, `tag_helper.rb:1511` 60.5 |
| gem: importmap-rails | 930.8 | 1141.7 | `map.rb:279` 751.3, `importmap_tags_helper.rb:44` 30.3, `importmap_tags_helper.rb:30` 30.3 |
| gem: herb | 627.6 | 645.3 | `herb.rb:72` 297.3, `compiler.rb:713` 69.0, `compiler.rb:559` 61.7 |
| gem: rack | 607.4 | 618.1 | `request.rb:693` 362.2, `request.rb:595` 177.3, `utils.rb:408` 7.4 |
| app | 581.2 | 625.3 | `inline_script_hashes.rb:43` 88.4, `inline_script_hashes.rb:42` 88.4, `inline_script_hashes.rb:40` 88.4 |
| gem: nokogiri | 475.6 | 496.8 | `node.rb:66` 38.4, `node.rb:1429` 25.6, `searchable.rb:270` 20.8 |
| gem: propshaft | 265.6 | 964.4 | `asset.rb:79` 151.8, `dynamic.rb:13` 75.9, `asset.rb:97` 19.0 |
| rails: activemodel | 164.7 | 174.4 | `attribute.rb:9` 22.3, `builder.rb:37` 19.5, `string.rb:39` 11.7 |
| gem: json | 119.7 | 120.5 | `common.rb:364` 110.3, `common.rb:1089` 7.1, `common.rb:967` 2.2 |
| gem: sqlite3 | 117.5 | 118.2 | `statement.rb:125` 36.7, `statement.rb:54` 20.2, `statement.rb:186` 19.6 |
| rails: actiontext | 104.4 | 107.3 | `bottom_up_reducer.rb:12` 9.1, `html_conversion.rb:23` 8.1, `plain_text_conversion.rb:25` 7.7 |
| gem: logger | 59.6 | 59.8 | `logger.rb:692` 19.9, `log_device.rb:165` 19.9, `log_device.rb:33` 19.9 |
| gem: tzinfo | 43.6 | 43.8 | `timestamp.rb:208` 20.1, `constant_offset_data_timezone_info.rb:52` 11.3, `timestamp.rb:193` 11.3 |
| gem: loofah | 29.8 | 31.0 | `scrubber.rb:132` 8.4, `concerns.rb:172` 7.9, `concerns.rb:43` 6.5 |
| gem: useragent | 26.8 | 30.2 | `base.rb:120` 20.3, `version.rb:27` 1.4, `user_agent.rb:25` 0.7 |
| gem: concurrent-ruby | 22.0 | 22.5 | `safe_initialization.rb:30` 6.0, `non_concurrent_map_backend.rb:131` 2.9, `mutex_lockable_object.rb:32` 2.0 |
| gem: rails-html-sanitizer | 16.7 | 17.0 | `sanitizer.rb:33` 2.0, `sanitizer.rb:56` 2.0, `sanitizer.rb:191` 2.0 |
| rails: activestorage | 16.4 | 18.1 | `one.rb:34` 3.6, `model.rb:141` 2.3, `model.rb:309` 1.6 |
| gem: turbo-rails | 14.6 | 15.3 | `frames_helper.rb:42` 9.0, `request_id_tracking.rb:10` 1.0, `stream_name.rb:28` 0.8 |
| gem: globalid | 11.0 | 11.7 | `gid.rb:95` 2.8, `gid.rb:159` 2.4, `gid.rb:166` 1.2 |
| ruby default gem: openssl | 11.0 | 11.7 | `hmac.rb:57` 3.7, `hmac.rb:55` 3.7, `digest.rb:38` 2.7 |
| gem: base64 | 10.9 | 11.1 | `base64.rb:283` 7.8, `base64.rb:310` 3.2, `base64.rb:377` 0.0 |
| rails: railties | 8.9 | 9.4 | `logger.rb:57` 2.0, `logger.rb:37` 1.0, `logger.rb:65` 1.0 |
| gem: bcrypt | 7.7 | 7.9 | `password.rb:102` 2.5, `password.rb:103` 1.2, `engine.rb:70` 1.2 |
| gem: debug | 6.3 | 7.5 | `thread_client.rb:903` 1.8, `thread_client.rb:239` 0.9, `thread_client.rb:224` 0.9 |
| gem: i18n | 5.7 | 6.4 | `fallbacks.rb:98` 0.9, `ruby.rb:33` 0.7, `utils.rb:8` 0.6 |
| ruby default gem: securerandom | 4.9 | 4.9 | `securerandom.rb:71` 4.9 |
| gem: rack-session | 4.0 | 4.0 | `id.rb:275` 1.0, `id.rb:277` 1.0, `id.rb:401` 0.9 |
| rails: activejob | 3.6 | 4.3 | `log_subscriber.rb:202` 0.5, `enqueuing.rb:62` 0.3, `queue_adapter.rb:11` 0.2 |
| gem: ruby-vips | 2.5 | 5.6 | `operation.rb:238` 0.3, `operation.rb:81` 0.3, `object.rb:201` 0.2 |
| gem: ffi | 1.7 | 3.5 | `struct_by_reference.rb:69` 0.8, `managedstruct.rb:80` 0.4, `autopointer.rb:88` 0.3 |
| rails: actioncable | 1.7 | 1.9 | `broadcasting.rb:57` 0.3, `test.rb:24` 0.2, `subscriber_map.rb:9` 0.2 |
| gem: jbuilder | 1.4 | 2.9 | `jbuilder_template.rb:140` 0.6, `jbuilder.rb:342` 0.3, `jbuilder_template.rb:72` 0.2 |
| gem: surfguard | 1.4 | 3.2 | `surfguard.rb:344` 0.2, `surfguard.rb:337` 0.1, `surfguard.rb:205` 0.1 |
| test harness: webmock | 1.3 | 5.9 | `headers.rb:69` 0.3, `headers.rb:68` 0.2, `headers.rb:16` 0.1 |
| gem: addressable | 1.3 | 4.2 | `uri.rb:136` 0.1, `uri.rb:486` 0.1, `uri.rb:1544` 0.1 |
| gem: mocha | 1.1 | 1.4 | `expectation_list.rb:55` 0.2, `parameters_matcher.rb:37` 0.2, `invocation.rb:45` 0.1 |
| gem: erubi | 0.7 | 0.8 | `erubi.rb:134` 0.4, `erubi.rb:137` 0.1, `erubi.rb:139` 0.1 |
| gem: marcel | 0.5 | 1.0 | `magic.rb:18` 0.1, `mime_type.rb:136` 0.1, `magic.rb:188` 0.1 |
| ruby default gem: prettyprint | 0.5 | 0.7 | `prettyprint.rb:403` 0.1, `prettyprint.rb:263` 0.1, `prettyprint.rb:458` 0.1 |
| gem: image_processing | 0.3 | 0.6 | `vips.rb:221` 0.1, `pipeline.rb:14` 0.0, `pipeline.rb:62` 0.0 |
| ruby default gem: pp | 0.2 | 0.3 | `pp.rb:542` 0.1, `pp.rb:271` 0.0, `pp.rb:550` 0.0 |
| gem: geared_pagination | 0.1 | 0.3 | `recordset.rb:35` 0.0, `ratios.rb:6` 0.0, `recordset.rb:17` 0.0 |
| gem: lexxy | 0.1 | 0.1 | `lexxy_editor.rb:6` 0.1, `lexxy_editor.rb:14` 0.0, `remote_video.rb:8` 0.0 |
| ruby default gem: timeout | 0.0 | 0.2 | `timeout.rb:292` 0.0, `timeout.rb:152` 0.0, `timeout.rb:293` 0.0 |
| ruby default gem: erb | 0.0 | 0.0 | `util.rb:65` 0.0 |
| gem: rqrcode | 0.0 | 3.1 | `qrcode.rb:15` 0.0, `svg.rb:254` 0.0, `svg.rb:269` 0.0 |
| gem: rqrcode_core | 0.0 | 28.9 | `qr_util.rb:151` 0.0, `qr_alphanumeric.rb:20` 0.0, `qr_code.rb:113` 0.0 |
| ruby default gem: psych | 0.0 | 1.4 | `parser.rb:100` 0.0, `parser.rb:62` 0.0, `parser.rb:89` 0.0 |
| gem: racc | 0.0 | 1.6 | `parser.rb:263` 0.0 |
| ruby default gem: net-protocol | 0.0 | 0.1 | `protocol.rb:341` 0.0, `protocol.rb:283` 0.0, `protocol.rb:158` 0.0 |
| lowrail-profile | 0.0 | 0.0 | `profile.rb:55` 0.0, `profile.rb:65` 0.0 |
| ruby default gem: bundler | 0.0 | 0.2 | `rubygems_integration.rb:212` 0.0, `rubygems_integration.rb:215` 0.0, `rubygems_integration.rb:206` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Jobs

| # | Job | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | Room::PushMessageJob#perform | 10 / 10 | 3657.2 / 3657.2 | 0.0 | 3506.6 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 63.2, `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 55.0, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 52.4 | `app/models/room.rb:91` 510.8, `lib/web_push/pool.rb:13` 466.6, `app/models/message/mentionee.rb:11` 387.2 |
| 2 | Message::BroadcastUnreadRoomJob#perform | 3 / 3 | 938.0 / 938.0 | 0.0 | 986.3 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 24.0, `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 15.0, `GEM/sqlite3/lib/sqlite3/statement.rb:186` 14.0 | `app/models/message/broadcasts.rb:18` 246.0, `app/models/message/broadcasts.rb:16` 153.0, `app/models/membership/connectable.rb:7` 34.0 |
| 3 | Room::DestroyJob#perform | 2 / 2 | – / – |  | 4491.5 |  |  |
| 4 | Bot::WebhookJob#perform | 1 / 1 | – / – |  | 2305.0 |  |  |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `RAILS/activerecord/lib/active_record/log_subscriber.rb:40` (debug logging) | 61.69 / 61.69 | 100% | `app/models/room/message_pusher.rb:10` 20%, `no app frame` 13% | `binds = binds.inspect` |
| 2 | `RAILS/activesupport/lib/active_support/colorize_logging.rb:64` (debug logging) | 42.0 / 42.0 | 100% | `no app frame` 21%, `app/models/room.rb:72` 19% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 3 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | 37.25 / 37.25 | 100% | `app/models/room.rb:72` 19%, `app/models/message/mentionee.rb:11` 15% | `WhereClause.new(predicates \| other.predicates)` |
| 4 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` | 35.25 / 35.25 | 100% | `app/models/room.rb:72` 11%, `app/models/room/message_pusher.rb:54` 11% | `WhereClause.new(predicates + other.predicates)` |
| 5 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` | 33.13 / 33.13 | 100% | `app/models/room.rb:91` 20%, `app/models/room/message_pusher.rb:35` 13% | `to_h { \|elem\| [elem, yield(elem)] } # rubocop:disable Rails/IndexWith` |
| 6 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` | 31.69 / 31.69 | 100% | `app/models/room.rb:91` 16%, `lib/web_push/pool.rb:13` 15% | `val = step` |
| 7 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:118` | 28.25 / 28.25 | 100% | `app/models/room/message_pusher.rb:54` 19%, `app/models/room.rb:72` 11% | `attributes.flat_map do \|key, value\|` |
| 8 | `RAILS/activerecord/lib/arel/table.rb:92` | 28.19 / 28.19 | 100% | `lib/web_push/pool.rb:13` 17%, `app/models/room.rb:72` 11% | `Attribute.new(table, name)` |
| 9 | `RAILS/activesupport/lib/active_support/colorize_logging.rb:62` (debug logging) | 28.0 / 28.0 | 100% | `no app frame` 21%, `app/models/room.rb:72` 19% | `modes = MODES.values_at(*options.compact_blank.keys)` |
| 10 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:28` | 26.5 / 26.5 | 100% | `app/models/room/message_pusher.rb:54` 14%, `app/models/room.rb:72` 12% | `attributes.each_with_object([]) do \|(key, value), result\|` |

### Action Cable

| # | Channel action | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | PresenceChannel#subscribed | 7 / 7 | 1186.0 / 1186.0 | 0.0 | 868.1 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 29.0, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 28.0, `GEM/sqlite3/lib/sqlite3/statement.rb:186` 18.0 | `app/channels/presence_channel.rb:21` 452.0, `app/channels/room_channel.rb:12` 220.5, `app/models/membership/connectable.rb:17` 124.0 |
| 2 | RoomMessagesChannel#subscribed | 7 / 7 | 624.0 / 624.0 | 0.0 | 503.1 | `RAILS/activesupport/lib/active_support/callbacks.rb:180` 16.0, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 12.0, `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/synchronization/safe_initialization.rb:30` 12.0 | `app/channels/room_messages_channel.rb:30` 188.0, `app/channels/room_messages_channel.rb:36` 184.0, `app/channels/room_messages_channel.rb:52` 16.0 |
| 3 | Turbo::StreamsChannel#subscribed | 2 / 2 | – / – |  | 131.5 |  |  |
| 4 | UnreadRoomsChannel#subscribed | 3 / 3 | – / – |  | 93.0 |  |  |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `RAILS/activerecord/lib/active_record/log_subscriber.rb:40` (debug logging) | 9.95 / 9.95 | 63% | `app/channels/presence_channel.rb:21` 26%, `app/channels/room_channel.rb:12` 23% | `binds = binds.inspect` |
| 2 | `RAILS/activesupport/lib/active_support/callbacks.rb:180` | 9.26 / 9.26 | 100% | `no app frame` 100% | `result_lambda = -> { user_callback.call target, value }` |
| 3 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | 6.95 / 6.95 | 63% | `app/channels/room_channel.rb:12` 40%, `app/channels/presence_channel.rb:21` 31% | `WhereClause.new(predicates \| other.predicates)` |
| 4 | `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/synchronization/safe_initialization.rb:30` | 6.95 / 6.95 | 100% | `no app frame` 100% | `super(*args, &block)` |
| 5 | `RAILS/activesupport/lib/active_support/colorize_logging.rb:64` (debug logging) | 5.68 / 5.68 | 63% | `app/channels/presence_channel.rb:21` 28%, `app/channels/room_channel.rb:12` 24% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 6 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` | 5.42 / 5.42 | 47% | `app/channels/presence_channel.rb:21` 47%, `app/channels/room_messages_channel.rb:36` 23% | `to_h { \|elem\| [elem, yield(elem)] } # rubocop:disable Rails/IndexWith` |
| 7 | `RAILS/activesupport/lib/active_support/colorize_logging.rb:62` (debug logging) | 3.79 / 3.79 | 63% | `app/channels/presence_channel.rb:21` 28%, `app/channels/room_channel.rb:12` 24% | `modes = MODES.values_at(*options.compact_blank.keys)` |
| 8 | `RAILS/activerecord/lib/arel/table.rb:92` | 3.58 / 3.58 | 63% | `app/channels/room_channel.rb:12` 28%, `app/models/membership/connectable.rb:17` 21% | `Attribute.new(table, name)` |
| 9 | `RAILS/activerecord/lib/active_record/key.rb:14` | 3.58 / 3.58 | 58% | `app/channels/presence_channel.rb:21` 62%, `app/channels/room_channel.rb:12` 23% | `Single.new(name)` |
| 10 | `RAILS/activerecord/lib/active_record/key.rb:87` | 3.58 / 3.58 | 58% | `app/channels/presence_channel.rb:21` 62%, `app/channels/room_channel.rb:12` 23% | `@columns = [@name].freeze` |
