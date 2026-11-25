# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails test -v`
* Ruby: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux]
* Rails: 8.2.0.alpha, test environment
* Counted in run 1: 666 requests, 16 jobs, 19 Cable actions in 8 processes; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 8 | 666 | 20927.6 | 16 | 0 | 19 | 0 |
| run2 | 8 | 666 | 20928.2 | 16 | 0 | 19 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 1.43 objects per request; 1 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/controllers/concerns/inline_script_hashes.rb:40` | `script_locations` | 2157.56 | 0.0 | 58.24 | `GEM/uri/lib/uri/generic.rb:1007` 16%, `GEM/uri/lib/uri/common.rb:108` 6%, `GEM/uri/lib/uri/rfc3986_parser.rb:85` 6% | SessionsController#create 57%, RoomsController#show 16%, MessagesController#index 7% | `url = URI.join(request.base_url, url)` |
| 2 | `app/controllers/concerns/inline_script_hashes.rb:41` | `script_locations` | 471.22 | 0.0 | 0.0 | `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 25%, `RAILS/actionpack/lib/action_dispatch/http/url.rb:342` 24%, `GEM/rack/lib/rack/request.rb:693` 24% | SessionsController#create 56%, RoomsController#show 16%, MessagesController#index 7% | `origin = url.origin == request.base_url ? request.host_with_port : url` |
| 3 | `app/models/message/pagination.rb:23` | `preload_associations` | 445.62 | 64.76 | 0.0 | `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:28` 3%, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:49` 2%, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:77` 2% | RoomsController#show 53%, MessagesController#index 37%, Messages::ByBotsController#index 7% | `@relation.preload_associations(records)` |
| 4 | `app/models/session.rb:11` | `start!` | 163.79 | 74.2 | 0.36 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 5%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:171` 4%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:166` 3% | SessionsController#create 97%, Users::ProfilesController#update 3%, Sessions::TransfersController#update 0% | `create! user_agent: user_agent, ip_address: ip_address` |
| 5 | `app/helpers/messages_helper.rb:107` | `text_message_presentation` | 121.0 | 19.93 | 0.59 | `GEM/nokogiri/lib/nokogiri/html5/node.rb:66` 5%, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1429` 3%, `GEM/nokogiri/lib/nokogiri/xml/document.rb:416` 3% | MessagesController#index 53%, RoomsController#show 36%, MessagesController#create 6% | `render = -> { auto_link_text h(ContentFilters::TextMessagePresentation` |
| 6 | `app/views/layouts/application.html.erb:23` |  | 91.41 | 9.84 | 0.31 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 11%, `RAILS/actionview/lib/action_view/helpers/asset_tag_helper.rb:683` 11%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:243` 7% | RoomsController#show 70%, Users::SidebarsController#show 7%, SessionsController#new 4% | `<%= stylesheet_link_tag :all, "data-turbo-track": "reload" %>` |
| 7 | `app/views/layouts/application.html.erb:26` |  | 88.59 | 396.28 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:159` 21%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 21%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:243` 11% | RoomsController#show 72%, Users::SidebarsController#show 6%, Users::ProfilesController#show 5% | `<%= javascript_importmap_tags %>` |
| 8 | `app/helpers/messages_helper.rb:94` | `message_fragment_cache_key` | 70.18 | 0.0 | 0.0 | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:238` 5%, `GEM/nokogiri/lib/nokogiri/css/selector_cache.rb:33` 5%, `GEM/nokogiri/lib/nokogiri/css/xpath_visitor.rb:94` 5% | RoomsController#show 62%, MessagesController#index 37%, Rooms::RefreshesController#show 2% | `body = message.body.body` |
| 9 | `app/controllers/sessions_controller.rb:11` | `create` | 66.99 | 19.32 | 0.7 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 6%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 4%, `GEM/bcrypt/lib/bcrypt/password.rb:102` 3% | SessionsController#create 100% | `if user = User.active.authenticate_by(email_address: params[:email_add` |
| 10 | `app/controllers/concerns/inline_script_hashes.rb:39` | `script_locations` | 66.05 | 0.0 | 1.94 | `GEM/json/lib/json/common.rb:364` 100% | SessionsController#create 58%, RoomsController#show 16%, MessagesController#index 7% | `JSON.parse(importmap)["imports"].values.map do \|url\|` |
| 11 | `app/models/current.rb:15` | `account` | 62.42 | 24.3 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 7%, `RAILS/activerecord/lib/active_record/relation/finder_methods.rb:673` 3%, `RAILS/activerecord/lib/arel.rb:60` 3% | RoomsController#show 72%, Users::SidebarsController#show 6%, SessionsController#new 5% | `Account.first` |
| 12 | `app/views/messages/_actions.html.erb:18` |  | 62.27 | 0.0 | 3.89 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 25%, `RAILS/actionview/lib/action_view/helpers/form_tag_helper.rb:308` 12%, `RAILS/actionview/lib/action_view/helpers/form_tag_helper.rb:1084` 12% | MessagesController#index 55%, RoomsController#show 38%, MessagesController#create 4% | `<%= hidden_field_tag "boost[content]", character %>` |
| 13 | `app/helpers/messages_helper.rb:123` | `auto_link_text` | 55.77 | 0.0 | 0.47 | `GEM/nokogiri/lib/nokogiri/html5/node.rb:66` 10%, `GEM/nokogiri/lib/nokogiri/xml/document.rb:416` 10%, `GEM/nokogiri/lib/nokogiri/html5/document_fragment.rb:166` 7% | MessagesController#index 54%, RoomsController#show 37%, MessagesController#create 5% | `fragment = Nokogiri::HTML5.fragment(sanitize(html, tags: AUTO_LINK_ALL` |
| 14 | `app/models/message.rb:26` | `plain_text_body` | 54.05 | 0.35 | 0.0 | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:270` 5%, `GEM/nokogiri/lib/nokogiri/xml/document_fragment.rb:175` 5%, `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:238` 5% | MessagesController#index 41%, RoomsController#show 35%, Messages::ByBotsController#index 14% | `content = body.body` |
| 15 | `app/helpers/messages_helper.rb:100` | `message_fragment_cache_key` | 49.68 | 0.0 | 4.04 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 42%, `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 23%, `RAILS/activemodel/lib/active_model/attribute.rb:9` 10% | RoomsController#show 60%, MessagesController#index 38%, Rooms::RefreshesController#show 2% | `dependencies = [ message.attributes, room.attributes.slice("id", "type` |
| 16 | `app/models/message/attachment.rb:20` | `create_with_attachment!` | 45.33 | 9.51 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:171` 3%, `GEM/tzinfo/lib/tzinfo/timestamp.rb:208` 2%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:166` 2% | MessagesController#create 77%, Messages::ByBotsController#create 23% | `create!(attributes).tap(&:process_attachment)` |
| 17 | `app/controllers/concerns/authentication.rb:94` | `set_authentication_cookie` | 44.02 | 0.0 | 0.6 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:171` 8%, `RAILS/activesupport/lib/active_support/core_ext/hash/keys.rb:40` 8%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:166` 5% | SessionsController#create 65%, RoomsController#show 15%, MessagesController#index 6% | `cookies.signed.permanent[:session_token] = { value: session.token, htt` |
| 18 | `app/models/message/pagination.rb:10` | `load` | 42.1 | 6.71 | 0.13 | `RAILS/activerecord/lib/active_record/key.rb:87` 14%, `RAILS/activerecord/lib/active_record/key.rb:14` 14%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 7% | RoomsController#show 52%, MessagesController#index 38%, Messages::ByBotsController#index 8% | `new(relation.skip_preloading!.public_send(direction, size), relation)` |
| 19 | `config/routes.rb:59` |  | 41.86 | 0.0 | 1.79 | `RAILS/activesupport/lib/active_support/core_ext/object/to_query.rb:16` 6%, `RAILS/actionpack/lib/action_dispatch/journey/formatter.rb:134` 4%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 4% | RoomsController#show 47%, MessagesController#index 37%, Users::SidebarsController#show 4% | `route_for :user_avatar, user.avatar_token, v: user.updated_at.to_fs(:n` |
| 20 | `app/models/ban.rb:7` | `banned?` | 41.07 | 22.14 | 0.0 | `RAILS/activerecord/lib/active_record/relation/finder_methods.rb:439` 4%, `GEM/sqlite3/lib/sqlite3/statement.rb:54` 3%, `RAILS/activerecord/lib/arel/nodes/select_statement.rb:11` 2% | SessionsController#create 84%, MessagesController#create 5%, Users::ProfilesController#update 3% | `exists?(ip_address: ip_address)` |
| 21 | `app/helpers/messages_helper.rb:36` | `message_tag` | 39.9 | 0.0 | 0.6 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1591` 33%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 19%, `RAILS/activesupport/lib/active_support/inflector/methods.rb:259` 16% | RoomsController#show 48%, MessagesController#index 46%, MessagesController#create 3% | `tag.div id: dom_id(message),` |
| 22 | `app/views/messages/_message.html.erb:4` |  | 38.4 | 8.07 | 1.19 | `RAILS/activesupport/lib/active_support/core_ext/object/to_query.rb:50` 30%, `RAILS/activesupport/lib/active_support/core_ext/object/to_query.rb:10` 7%, `RAILS/activesupport/lib/active_support/cache.rb:1045` 5% | RoomsController#show 55%, MessagesController#index 43%, Rooms::RefreshesController#show 3% | `<% cache [ message_fragment_cache_key(message), "presentation-v8" ] do` |
| 23 | `app/helpers/content_filters/sanitize_attributes.rb:11` | `apply` | 38.19 | 0.0 | 0.47 | `GEM/nokogiri/lib/nokogiri/html5/node.rb:66` 15%, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1429` 10%, `GEM/nokogiri/lib/nokogiri/xml/document.rb:416` 8% | MessagesController#index 55%, RoomsController#show 37%, MessagesController#create 5% | `sanitizer.sanitize fragment.to_html, tags: allowed_tags, attributes: a` |
| 24 | `app/views/messages/_message.html.erb:26` |  | 34.27 | 31.66 | 1.79 | `RAILS/activerecord/lib/active_record/integration.rb:59` 10%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 3%, `RAILS/actionpack/lib/action_dispatch/journey/router/utils.rb:70` 3% | RoomsController#show 47%, MessagesController#index 46%, MessagesController#create 3% | `<%= render "messages/actions", message: message, url: room_at_message_` |
| 25 | `app/helpers/users/avatars_helper.rb:14` | `avatar_tag` | 33.79 | 0.0 | 4.09 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 10%, `RAILS/activerecord/lib/active_record/integration.rb:59` 7%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 5% | RoomsController#show 52%, MessagesController#index 42%, MessagesController#create 3% | `link_to user_path(user), title: user.title, class: "btn avatar", data:` |
| 26 | `app/views/messages/boosts/_boosts.html.erb:5` |  | 32.05 | 22.37 | 2.36 | `RAILS/actionview/lib/action_view/renderer/collection_renderer.rb:150` 6%, `RAILS/actionview/lib/action_view/renderer/abstract_renderer.rb:44` 4%, `RAILS/actionview/lib/action_view/renderer/collection_renderer.rb:121` 4% | RoomsController#show 37%, MessagesController#index 36%, MessagesController#create 13% | `<%= render partial: "messages/boosts/boost", collection: message.boost` |
| 27 | `app/helpers/content_filters/remove_solo_unfurled_link_text.rb:6` | `applicable?` | 30.98 | 0.0 | 0.0 | `RAILS/actiontext/lib/action_text/bottom_up_reducer.rb:12` 9%, `RAILS/actiontext/lib/action_text/plain_text_conversion.rb:25` 8%, `RAILS/actiontext/lib/action_text/bottom_up_reducer.rb:25` 6% | MessagesController#index 55%, RoomsController#show 36%, MessagesController#create 6% | `normalize_tweet_url(solo_unfurled_url) == normalize_tweet_url(content.` |
| 28 | `app/views/rooms/show.html.erb:17` |  | 30.4 | 9.37 | 0.29 | `RAILS/activesupport/lib/active_support/core_ext/object/to_query.rb:50` 30%, `RAILS/activesupport/lib/active_support/core_ext/object/to_query.rb:10` 12%, `RAILS/activesupport/lib/active_support/cache.rb:1045` 12% | RoomsController#show 100% | `<%= render partial: "messages/message", collection: @messages, cached:` |
| 29 | `app/helpers/users/avatars_helper.rb:15` | `avatar_tag` | 29.65 | 0.0 | 3.27 | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:704` 22%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 11%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:159` 8% | RoomsController#show 52%, MessagesController#index 41%, MessagesController#create 3% | `image_tag fresh_user_avatar_path(user), aria: { hidden: "true" }, size` |
| 30 | `app/models/message.rb:27` | `plain_text_body` | 29.19 | 0.0 | 0.0 | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:270` 9%, `GEM/nokogiri/lib/nokogiri/xml/document_fragment.rb:175` 9%, `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:238` 9% | RoomsController#show 45%, MessagesController#index 43%, Messages::ByBotsController#index 5% | `text = if content && content.fragment.find_all(ActionText::Attachment.` |

App middleware that hands the request on (the stack below it, not its own work): `config/initializers/uploaded_script_guard.rb:24` 149.28 warm objects per request.

271.42 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | MessagesController#index | 38 / 38 | 28035.3 / 28037.0 | 1.7 | 26696.4 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 769.6, `GEM/uri/lib/uri/generic.rb:1007` 550.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1591` 466.8 | `app/models/message/pagination.rb:23` 3671.3, `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/helpers/messages_helper.rb:107` 1435.2 |
| 2 | RoomsController#show | 78 / 78 | 24558.0 / 24560.6 | 2.6 | 29768.5 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 599.2, `GEM/uri/lib/uri/generic.rb:1007` 488.4, `GEM/rack/lib/rack/request.rb:693` 375.1 | `app/controllers/concerns/inline_script_hashes.rb:40` 3263.2, `app/models/message/pagination.rb:23` 2245.1, `app/controllers/concerns/inline_script_hashes.rb:41` 726.4 |
| 3 | WelcomeController#show | 14 / 14 | 24245.9 / 24237.4 | -8.5 | 20035.9 | `GEM/rack/lib/rack/request.rb:693` 372.0, `GEM/uri/lib/uri/rfc3986_parser.rb:85` 296.5, `GEM/uri/lib/uri/common.rb:108` 296.5 | `app/controllers/concerns/inline_script_hashes.rb:40` 2987.3, `app/controllers/concerns/inline_script_hashes.rb:16` 1091.3, `app/controllers/concerns/inline_script_hashes.rb:41` 652.5 |
| 4 | Rooms::RefreshesController#show | 3 / 3 | 21317.0 / 21323.0 | 6.0 | 19707.0 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 378.0, `RAILS/actionview/lib/action_view/render_parser.rb:16` 303.0 | `app/models/message/pagination.rb:23` 4638.5, `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/views/rooms/refreshes/show.turbo_stream.erb:2` 1032.0 |
| 5 | Users::ProfilesController#show | 10 / 10 | 19359.8 / 19385.3 | 25.5 | 20469.2 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 552.5, `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 371.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `app/views/layouts/application.html.erb:26` 694.0 |
| 6 | SessionsController#create | 251 / 251 | 18643.3 / 18645.3 | 2.0 | 19408.1 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 367.2, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 274.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3341.9, `app/controllers/concerns/inline_script_hashes.rb:41` 717.8, `app/models/session.rb:11` 437.2 |
| 7 | AccountsController#edit | 5 / 5 | 15808.0 / 15805.0 | -3.0 | 71080.6 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 635.0, `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/models/current.rb:15` 1052.0, `app/views/layouts/application.html.erb:23` 872.0 |
| 8 | Messages::ByBotsController#create | 13 / 13 | 15658.8 / 15659.8 | 1.0 | 15381.0 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/nokogiri/lib/nokogiri/css/node.rb:21` 400.8, `GEM/rack/lib/rack/request.rb:693` 364.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/models/message/attachment.rb:20` 1383.4, `app/helpers/content_filters/sanitize_tags.rb:11` 1288.0 |
| 9 | Messages::ByBotsController#index | 12 / 12 | 15131.3 / 15143.1 | 11.9 | 16147.8 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 365.7, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 361.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3408.7, `app/models/message/pagination.rb:23` 2783.4, `app/views/messages/_message.json.jbuilder:8` 1457.7 |
| 10 | RoomsController#destroy | 5 / 5 | 14839.0 / 14843.0 | 4.0 | 73285.0 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 274.0 | `app/models/room.rb:72` 4063.0, `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0 |
| 11 | MessagesController#show | 5 / 5 | 14368.0 / 14366.0 | -2.0 | 19285.6 | `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 843.0, `GEM/uri/lib/uri/generic.rb:1007` 550.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 428.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3494.3, `app/controllers/concerns/inline_script_hashes.rb:41` 1140.0, `app/views/layouts/application.html.erb:23` 872.0 |
| 12 | MessagesController#create | 21 / 21 | 13653.6 / 13655.8 | 2.2 | 13803.9 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 401.7, `GEM/rack/lib/rack/request.rb:693` 318.6 | `app/controllers/concerns/inline_script_hashes.rb:40` 3376.2, `app/models/message/attachment.rb:20` 1662.2, `app/controllers/concerns/inline_script_hashes.rb:41` 810.0 |
| 13 | Messages::ByBotsController#update | 5 / 5 | 12142.0 / 12142.0 | 0.0 | 8410.2 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 364.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 274.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/messages_controller.rb:46` 2429.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0 |
| 14 | Messages::BoostsController#index | 4 / 4 | 11807.5 / 11806.5 | -1.0 | 11907.8 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 380.0, `GEM/rack/lib/rack/request.rb:693` 372.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/views/layouts/application.html.erb:23` 872.0, `app/views/layouts/application.html.erb:26` 748.0 |
| 15 | SessionsController#new | 8 / 8 | 11350.3 / 11321.0 | -29.3 | 11245.9 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 389.0, `GEM/rack/lib/rack/request.rb:693` 364.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/views/layouts/application.html.erb:23` 872.0, `app/views/layouts/application.html.erb:26` 748.0 |
| 16 | Users::SidebarsController#show | 17 / 17 | 11184.9 / 11191.4 | 6.6 | 18091.9 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 373.1, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 278.7 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `app/views/users/sidebars/show.html.erb:23` 515.4 |
| 17 | Rooms::InvolvementsController#update | 5 / 5 | 10332.0 / 10330.0 | -2.0 | 8482.4 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/psych/lib/psych/parser.rb:62` 422.0, `GEM/psych/lib/psych/tree_builder.rb:97` 394.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/rooms/involvements_controller.rb:23` 2480.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0 |
| 18 | SearchesController#index | 9 / 9 | 10267.0 / 10266.0 | -1.0 | 28377.3 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 373.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` 287.3 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `app/views/layouts/application.html.erb:23` 654.0 |
| 19 | Rooms::DirectsController#create | 3 / 3 | 8643.0 / 8641.0 | -2.0 | 10987.0 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 380.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 280.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `app/controllers/rooms/directs_controller.rb:28` 614.0 |
| 20 | Users::ProfilesController#update | 16 / 16 | 7804.3 / 7807.6 | 3.4 | 7528.7 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 273.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `app/controllers/users/profiles_controller.rb:14` 482.5 |
| 21 | Users::PushSubscriptionsController#create | 11 / 11 | 7011.0 / 7012.0 | 1.0 | 7254.5 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 272.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `config/initializers/uploaded_script_guard.rb:24` 322.0 |
| 22 | SessionsController#destroy | 4 / 4 | 6293.0 / 6297.0 | 4.0 | 6477.5 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 274.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `config/initializers/uploaded_script_guard.rb:24` 207.0 |
| 23 | UnfurlLinksController#create | 12 / 12 | 6263.5 / 6264.3 | 0.8 | 7897.8 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 372.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 272.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `config/initializers/uploaded_script_guard.rb:24` 250.0 |
| 24 | Messages::Boosts::ByBotsController#create | 9 / 9 | 6233.7 / 6234.3 | 0.7 | 9068.3 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 364.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 272.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `app/controllers/messages/boosts/by_bots_controller.rb:17` 464.7 |
| 25 | FirstRunsController#create | 6 / 6 | 6662.5 / 5680.3 | -982.3 | 6784.2 | `GEM/uri/lib/uri/generic.rb:1007` 550.0, `GEM/rack/lib/rack/request.rb:693` 364.0, `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` 274.0 | `app/controllers/concerns/inline_script_hashes.rb:40` 3344.0, `app/controllers/concerns/inline_script_hashes.rb:41` 720.0, `config/initializers/uploaded_script_guard.rb:24` 347.3 |
| 26 | Sessions::TransfersController#show | 1 / 1 | – / – |  | 99078.0 |  |  |
| 27 | Sessions::TransfersController#update | 2 / 2 | – / – |  | 61166.0 |  |  |
| 28 | Rooms::ClosedsController#new | 1 / 1 | – / – |  | 49644.0 |  |  |
| 29 | Rooms::InvolvementsController#show | 1 / 1 | – / – |  | 49461.0 |  |  |
| 30 | UsersController#show | 1 / 1 | – / – |  | 17852.0 |  |  |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/uri/lib/uri/generic.rb:1007` | `split_path` | 526.35 / 526.37 | 0.02 | 532.97 | 97% | String, Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100% | `path.split("/", -1)` |
| 2 | `GEM/rack/lib/rack/request.rb:693` | `split_header` | 360.52 / 360.52 | 0.0 | 364.96 | 99% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 49%, `app/controllers/concerns/inline_script_hashes.rb:41` 48% | `value ? value.strip.split(/[, \t]+/) : []` |
| 3 | `RAILS/actionpack/lib/action_dispatch/http/url.rb:326` | `host` | 285.22 / 285.22 | -0.0 | 289.91 | 100% | String, MatchData |  | `app/controllers/concerns/inline_script_hashes.rb:41` 63%, `app/controllers/concerns/inline_script_hashes.rb:40` 32% | `raw_host_with_port.sub(/:\d+$/, "")` |
| 4 | `RAILS/actionpack/lib/action_dispatch/http/url.rb:342` | `host_with_port` | 263.59 / 263.59 | 0.0 | 266.84 | 99% | String |  | `app/controllers/concerns/inline_script_hashes.rb:41` 66%, `app/controllers/concerns/inline_script_hashes.rb:40` 33% | `"#{host}#{port_string}"` |
| 5 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1587` | `tag_option` | 200.77 / 200.77 | 0.0 | 202.59 | 32% | String |  | `app/views/layouts/application.html.erb:26` 16%, `app/views/messages/_actions.html.erb:18` 10% | `%(#{key}="#{value}")` |
| 6 | `GEM/uri/lib/uri/rfc3986_parser.rb:85` | `split` | 181.79 / 181.79 | 0.0 | 183.99 | 99% | MatchData, String |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 1% | `if m = RFC3986_URI.match(uri)` |
| 7 | `GEM/uri/lib/uri/common.rb:108` | `escape` | 181.72 / 181.72 | 0.0 | 183.93 | 99% | String, Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 1% | `name.upcase.tr(ReservedChars, EscapedChars)` |
| 8 | `GEM/uri/lib/uri/generic.rb:543` | `split_userinfo` | 178.43 / 178.44 | 0.01 | 180.61 | 100% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 0% | `return nil, nil unless ui` |
| 9 | `GEM/uri/lib/uri/generic.rb:516` | `set_userinfo` | 178.43 / 178.43 | 0.0 | 180.61 | 100% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 0% | `[@user, @password]` |
| 10 | `GEM/uri/lib/uri/common.rb:194` | `for` | 177.22 / 177.22 | 0.0 | 179.4 | 99% | Object |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 0% | `return uri_class.new(scheme, *arguments)` |
| 11 | `GEM/uri/lib/uri/rfc3986_parser.rb:135` | `parse` | 177.22 / 177.22 | 0.0 | 179.4 | 99% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 0% | `URI.for(*self.split(uri), self)` |
| 12 | `GEM/rack/lib/rack/request.rb:595` | `base_url` | 176.51 / 176.51 | 0.0 | 178.67 | 99% | String |  | `app/controllers/concerns/inline_script_hashes.rb:41` 50%, `app/controllers/concerns/inline_script_hashes.rb:40` 50% | `"#{scheme}://#{host_with_port}"` |
| 13 | `GEM/uri/lib/uri/rfc3986_parser.rb:115` | `split` | 172.71 / 172.71 | 0.0 | 174.87 | 97% | String, MatchData |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100%, `app/models/opengraph/fetch.rb:34` 0% | `elsif m = RFC3986_relative_ref.match(uri)` |
| 14 | `GEM/json/lib/json/common.rb:364` | `parse` | 108.77 / 110.2 | 1.43 | 121.78 | 100% | String, Hash |  | `app/controllers/concerns/inline_script_hashes.rb:39` 82%, `app/controllers/concerns/inline_script_hashes.rb:16` 9% | `Parser.parse(source, opts)` |
| 15 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:243` | `html_safe` | 106.05 / 106.05 | 0.0 | 107.07 | 36% | String |  | `app/views/layouts/application.html.erb:26` 16%, `app/views/layouts/application.html.erb:23` 10% | `ActiveSupport::SafeBuffer.new(self)` |
| 16 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:159` | `xml_name_escape` | 93.28 / 93.28 | 0.0 | 94.39 | 32% | String |  | `app/views/layouts/application.html.erb:26` 34%, `app/helpers/users/avatars_helper.rb:15` 7% | `name = name.to_s` |
| 17 | `GEM/uri/lib/uri/generic.rb:335` | `set_scheme` | 91.46 / 91.46 | 0.0 | 92.56 | 100% | String |  | `app/controllers/concerns/inline_script_hashes.rb:40` 98%, `app/controllers/sessions_controller.rb:13` 1% | `@scheme = v&.downcase` |
| 18 | `GEM/uri/lib/uri/rfc3986_parser.rb:87` | `split` | 90.89 / 90.89 | 0.0 | 91.99 | 99% | String |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 1% | `scheme = m["scheme"]` |
| 19 | `GEM/uri/lib/uri/rfc3986_parser.rb:104` | `split` | 90.86 / 90.86 | 0.0 | 91.97 | 99% | String, Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 1% | `m["host"],` |
| 20 | `GEM/uri/lib/uri/rfc3986_parser.rb:102` | `split` | 90.86 / 90.86 | 0.0 | 91.96 | 99% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 1% | `[ scheme,` |
| 21 | `GEM/uri/lib/uri/rfc3986_parser.rb:107` | `split` | 90.86 / 90.86 | 0.0 | 91.96 | 99% | String |  | `app/controllers/concerns/inline_script_hashes.rb:40` 99%, `app/controllers/sessions_controller.rb:13` 1% | `(m["path-abempty"] \|\|` |
| 22 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` | `initialize` | 90.28 / 90.28 | 0.0 | 91.27 | 35% | String |  | `app/views/layouts/application.html.erb:26` 18%, `app/views/layouts/application.html.erb:23` 12% | `super` |
| 23 | `GEM/uri/lib/uri/http.rb:132` | `origin` | 89.86 / 89.86 | 0.0 | 90.95 | 99% | String |  | `app/controllers/concerns/inline_script_hashes.rb:41` 100% | `"#{scheme}://#{authority}"` |
| 24 | `GEM/uri/lib/uri/common.rb:274` | `join` | 87.97 / 87.97 | 0.0 | 89.05 | 99% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100% | `DEFAULT_PARSER.join(*str)` |
| 25 | `GEM/uri/lib/uri/rfc3986_parser.rb:116` | `split` | 86.36 / 86.36 | 0.0 | 87.44 | 97% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100%, `app/models/opengraph/fetch.rb:34` 0% | `[ nil, # scheme` |
| 26 | `GEM/uri/lib/uri/generic.rb:1137` | `merge` | 86.35 / 86.35 | 0.0 | 87.43 | 97% | Object |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100% | `base = self.dup` |
| 27 | `GEM/uri/lib/uri/generic.rb:1039` | `merge_path` | 86.08 / 86.08 | 0.0 | 87.16 | 97% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100% | `tmp = []` |
| 28 | `GEM/uri/lib/uri/generic.rb:1051` | `merge_path` | 86.08 / 86.08 | 0.0 | 87.16 | 97% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100% | `base_path = [''] # keep '/' for root directory` |
| 29 | `GEM/uri/lib/uri/generic.rb:1074` | `merge_path` | 86.08 / 86.08 | 0.0 | 87.16 | 97% | String |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100% | `return base_path.join('/')` |
| 30 | `GEM/uri/lib/uri/rfc3986_parser.rb:122` | `split` | 86.08 / 86.08 | 0.0 | 87.16 | 97% | String |  | `app/controllers/concerns/inline_script_hashes.rb:40` 100% | `m["path-absolute"] \|\|` |

## Dev/test-mode work

5664.0 of 15498.0 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | error page | `RUBY/error_highlight/base.rb:94` | 1542.23 | 2% | `no app frame` 100% | `Prism.parse_file(absolute_path).value.breadth_first_search { \|node\| no` |
| 2 | asset lookup | `GEM/importmap-rails/lib/importmap/map.rb:279` † | 841.43 | 5% | `app/controllers/concerns/inline_script_hashes.rb:16` 51%, `app/views/layouts/application.html.erb:26` 49% | `module_filename = filename.relative_path_from(absolute_path)` |
| 3 | error page | `GEM/prism/lib/prism/parse_result.rb:70` | 610.8 | 2% | `no app frame` 100% | `source.lines` |
| 4 | template compile | `GEM/herb/lib/herb.rb:72` | 402.48 | 14% | `no app frame` 14%, `app/views/rooms/involvements/_bell.html.erb:23` 14% | `Backend.parse(...)` |
| 5 | error page | `GEM/prism/lib/prism/node.rb:2797` | 109.52 | 3% | `no app frame` 98%, `app/views/rooms/show.html.erb:17` 1% | `compact = [] #: Array[Prism::node]` |
| 6 | template compile | `GEM/herb/lib/herb/engine/compiler.rb:713` | 90.65 | 11% | `no app frame` 19%, `app/views/rooms/involvements/_bell.html.erb:23` 14% | `count += 1 while count < text.length && HORIZONTAL_SPACE.include?(text` |
| 7 | template compile | `GEM/herb/lib/herb/engine/compiler.rb:559` | 84.47 | 14% | `app/views/rooms/involvements/_bell.html.erb:23` 16%, `no app frame` 14% | `@tokens << [:text, text, current_context]` |
| 8 | error page | `GEM/prism/lib/prism/node.rb:18058` | 78.92 | 3% | `no app frame` 100%, `app/views/rooms/show.html.erb:17` 0% | `[*body]` |
| 9 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:40` | 78.48 | 95% | `app/models/message/pagination.rb:23` 31%, `app/models/session.rb:11` 14% | `binds = binds.inspect` |
| 10 | error page | `RAILS/actionpack/lib/action_dispatch/middleware/exception_wrapper.rb:336` | 67.41 | 2% | `no app frame` 100% | `lines = source_lines.drop(start).take(6)` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| ruby default gem: uri | 2965.9 | 3003.8 | `generic.rb:1007` 526.4, `rfc3986_parser.rb:85` 181.8, `common.rb:108` 181.7 |
| rails: activesupport | 1773.2 | 1915.2 | `output_safety.rb:243` 106.0, `util.rb:159` 93.3, `output_safety.rb:72` 90.3 |
| ruby stdlib | 1641.2 | 2693.3 | `base.rb:94` 1542.2, `ipaddr.rb:725` 10.3, `digest.rb:56` 7.9 |
| rails: activerecord | 1562.0 | 1629.9 | `log_subscriber.rb:40` 78.5, `where_clause.rb:29` 39.5, `integration.rb:59` 38.7 |
| rails: actionpack | 1418.3 | 1636.5 | `url.rb:326` 285.2, `url.rb:342` 263.6, `exception_wrapper.rb:336` 67.4 |
| rails: actionview | 1152.5 | 1231.0 | `tag_helper.rb:1587` 200.8, `tag_helper.rb:1591` 83.8, `tag_helper.rb:1511` 60.8 |
| ruby default gem: prism | 1139.9 | 1674.6 | `parse_result.rb:70` 610.8, `node.rb:2797` 109.5, `node.rb:18058` 78.9 |
| gem: importmap-rails | 1030.1 | 1347.3 | `map.rb:279` 841.4, `map.rb:305` 31.0, `importmap_tags_helper.rb:30` 29.5 |
| gem: herb | 836.6 | 987.3 | `herb.rb:72` 402.5, `compiler.rb:713` 90.6, `compiler.rb:559` 84.5 |
| gem: rack | 604.3 | 621.2 | `request.rb:693` 360.5, `request.rb:595` 176.5, `utils.rb:408` 7.3 |
| app | 573.6 | 648.4 | `inline_script_hashes.rb:43` 88.0, `inline_script_hashes.rb:40` 88.0, `inline_script_hashes.rb:42` 88.0 |
| gem: nokogiri | 479.1 | 528.5 | `node.rb:66` 39.8, `node.rb:1429` 26.6, `searchable.rb:270` 21.5 |
| rails: activemodel | 179.7 | 195.6 | `attribute.rb:9` 22.3, `builder.rb:37` 18.8, `string.rb:39` 11.7 |
| gem: sqlite3 | 118.9 | 120.9 | `statement.rb:125` 36.6, `statement.rb:186` 20.5, `statement.rb:54` 20.2 |
| gem: json | 118.7 | 131.2 | `common.rb:364` 109.5, `common.rb:1089` 7.1, `common.rb:967` 2.1 |
| rails: actiontext | 102.0 | 110.6 | `bottom_up_reducer.rb:12` 8.8, `html_conversion.rb:23` 7.9, `plain_text_conversion.rb:25` 7.5 |
| gem: logger | 59.6 | 60.0 | `logger.rb:692` 19.9, `log_device.rb:165` 19.9, `log_device.rb:33` 19.9 |
| gem: tzinfo | 53.3 | 53.8 | `timestamp.rb:208` 24.0, `constant_offset_data_timezone_info.rb:52` 13.2, `timestamp.rb:193` 13.2 |
| gem: propshaft | 45.6 | 74.8 | `static.rb:18` 39.2, `helper.rb:85` 5.1, `server.rb:62` 1.0 |
| gem: loofah | 30.5 | 32.9 | `scrubber.rb:132` 8.7, `concerns.rb:172` 8.2, `concerns.rb:43` 6.8 |
| gem: useragent | 25.5 | 30.4 | `base.rb:120` 19.1, `version.rb:27` 1.4, `user_agent.rb:25` 0.7 |
| gem: concurrent-ruby | 22.6 | 23.3 | `safe_initialization.rb:30` 5.9, `non_concurrent_map_backend.rb:131` 2.8, `mutex_lockable_object.rb:33` 2.0 |
| gem: debug | 17.7 | 30.8 | `thread_client.rb:903` 5.1, `thread_client.rb:223` 2.5, `session.rb:140` 2.5 |
| gem: rails-html-sanitizer | 16.8 | 18.1 | `sanitizer.rb:191` 2.0, `sanitizer.rb:33` 2.0, `sanitizer.rb:56` 2.0 |
| rails: activestorage | 15.6 | 19.9 | `one.rb:34` 3.5, `model.rb:141` 2.3, `model.rb:309` 1.6 |
| gem: turbo-rails | 14.2 | 15.9 | `frames_helper.rb:42` 8.8, `request_id_tracking.rb:10` 1.0, `stream_name.rb:28` 0.8 |
| gem: base64 | 10.9 | 11.1 | `base64.rb:283` 7.7, `base64.rb:310` 3.1, `base64.rb:373` 0.0 |
| ruby default gem: openssl | 10.8 | 12.0 | `hmac.rb:55` 3.7, `hmac.rb:57` 3.7, `digest.rb:38` 2.5 |
| gem: globalid | 10.6 | 12.0 | `gid.rb:95` 2.7, `gid.rb:159` 2.3, `gid.rb:166` 1.1 |
| rails: railties | 8.9 | 9.7 | `logger.rb:57` 2.0, `logger.rb:65` 1.0, `logger.rb:21` 1.0 |
| gem: bcrypt | 7.6 | 7.9 | `password.rb:102` 2.4, `password.rb:103` 1.2, `engine.rb:70` 1.2 |
| gem: i18n | 5.7 | 8.0 | `fallbacks.rb:98` 0.9, `ruby.rb:33` 0.6, `utils.rb:8` 0.6 |
| ruby default gem: securerandom | 4.8 | 4.9 | `securerandom.rb:71` 4.8 |
| gem: rack-session | 4.0 | 4.0 | `id.rb:275` 1.0, `id.rb:277` 1.0, `id.rb:401` 0.9 |
| rails: activejob | 3.2 | 4.3 | `log_subscriber.rb:202` 0.5, `enqueuing.rb:62` 0.2, `queue_adapter.rb:11` 0.2 |
| rails: actioncable | 1.6 | 3.4 | `broadcasting.rb:57` 0.3, `test.rb:24` 0.2, `subscriber_map.rb:9` 0.2 |
| gem: jbuilder | 1.3 | 3.6 | `jbuilder_template.rb:140` 0.5, `jbuilder.rb:342` 0.2, `jbuilder_template.rb:72` 0.1 |
| gem: ruby-vips | 1.2 | 6.1 | `operation.rb:238` 0.2, `operation.rb:81` 0.2, `object.rb:201` 0.1 |
| gem: mocha | 1.0 | 1.4 | `expectation_list.rb:55` 0.2, `parameters_matcher.rb:37` 0.1, `invocation.rb:45` 0.1 |
| gem: ffi | 0.8 | 3.8 | `struct_by_reference.rb:69` 0.3, `managedstruct.rb:80` 0.2, `autopointer.rb:88` 0.1 |
| gem: erubi | 0.6 | 0.8 | `erubi.rb:134` 0.4, `erubi.rb:137` 0.1, `erubi.rb:139` 0.1 |
| ruby default gem: prettyprint | 0.4 | 0.7 | `prettyprint.rb:403` 0.1, `prettyprint.rb:263` 0.1, `prettyprint.rb:458` 0.1 |
| gem: surfguard | 0.3 | 3.2 | `surfguard.rb:344` 0.1, `surfguard.rb:337` 0.0, `surfguard.rb:322` 0.0 |
| gem: marcel | 0.3 | 1.0 | `magic.rb:18` 0.1, `magic.rb:188` 0.0, `magic.rb:189` 0.0 |
| ruby default gem: pp | 0.2 | 0.3 | `pp.rb:542` 0.1, `pp.rb:271` 0.0, `pp.rb:550` 0.0 |
| gem: image_processing | 0.1 | 0.6 | `vips.rb:221` 0.0, `pipeline.rb:14` 0.0, `pipeline.rb:62` 0.0 |
| gem: geared_pagination | 0.1 | 0.3 | `recordset.rb:35` 0.0, `ratios.rb:6` 0.0, `portion_at_offset.rb:8` 0.0 |
| gem: lexxy | 0.1 | 0.1 | `lexxy_editor.rb:6` 0.1, `remote_video.rb:8` 0.0, `lexxy_editor.rb:14` 0.0 |
| ruby default gem: timeout | 0.0 | 0.3 | `timeout.rb:292` 0.0, `timeout.rb:35` 0.0, `timeout.rb:152` 0.0 |
| ruby default gem: net-protocol | 0.0 | 0.0 | `protocol.rb:283` 0.0, `protocol.rb:341` 0.0, `protocol.rb:158` 0.0 |
| ruby default gem: erb | 0.0 | 0.0 | `util.rb:65` 0.0 |
| gem: rqrcode | 0.0 | 3.1 | `qrcode.rb:15` 0.0, `svg.rb:269` 0.0, `svg.rb:254` 0.0 |
| gem: rqrcode_core | 0.0 | 28.9 | `qr_segment.rb:36` 0.0, `qr_alphanumeric.rb:20` 0.0, `qr_util.rb:151` 0.0 |
| gem: racc | 0.0 | 3.2 | `parser.rb:263` 0.0 |
| gem: lowrail-profile | 0.0 | 0.0 | `profile.rb:55` 0.0, `profile.rb:65` 0.0 |
| test harness: webmock | 0.0 | 5.9 | `net_http.rb:272` 0.0, `request_signature.rb:18` 0.0, `uri.rb:34` 0.0 |
| gem: zeitwerk | 0.0 | 0.4 | `cref.rb:57` 0.0, `loader.rb:511` 0.0, `inflector.rb:16` 0.0 |
| ruby default gem: psych | 0.0 | 11.7 | `to_ruby.rb:20` 0.0, `psych.rb:696` 0.0, `to_ruby.rb:173` 0.0 |
| ruby default gem: bundler | 0.0 | 0.3 | `rubygems_integration.rb:212` 0.0, `rubygems_integration.rb:206` 0.0, `shared_helpers.rb:22` 0.0 |
| gem: rails_autolink | 0.0 | 1.5 | `helpers.rb:6` 0.0, `helpers.rb:0` 0.0, `helpers.rb:84` 0.0 |
| gem: addressable | 0.0 | 4.5 | `uri.rb:1242` 0.0, `pure.rb:68` 0.0, `uri.rb:165` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Jobs

| # | Job | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | Room::PushMessageJob#perform | 10 / 10 | 3968.0 / 3968.0 | 0.0 | 3785.2 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 66.0, `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 58.0, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 57.0 | `lib/web_push/pool.rb:13` 589.0, `app/models/room.rb:91` 513.0, `app/models/message/mentionee.rb:11` 390.0 |
| 2 | Room::DestroyJob#perform | 2 / 2 | – / – |  | 4684.0 |  |  |
| 3 | Bot::WebhookJob#perform | 1 / 1 | – / – |  | 2284.0 |  |  |
| 4 | Message::BroadcastUnreadRoomJob#perform | 3 / 3 | – / – |  | 1078.7 |  |  |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `RAILS/activerecord/lib/active_record/log_subscriber.rb:40` (debug logging) | 45.44 / 45.44 | 100% | `app/models/room/message_pusher.rb:10` 20%, `no app frame` 13% | `binds = binds.inspect` |
| 2 | `RAILS/activesupport/lib/active_support/colorize_logging.rb:64` (debug logging) | 33.38 / 33.38 | 100% | `no app frame` 21%, `app/models/room.rb:72` 19% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 3 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | 29.0 / 29.0 | 100% | `app/models/room.rb:72` 18%, `app/models/message/mentionee.rb:11` 15% | `WhereClause.new(predicates \| other.predicates)` |
| 4 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` | 26.13 / 26.13 | 100% | `app/models/room.rb:72` 11%, `app/models/room/message_pusher.rb:54` 10% | `WhereClause.new(predicates + other.predicates)` |
| 5 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` | 23.69 / 23.69 | 100% | `app/models/room.rb:91` 20%, `app/models/room/message_pusher.rb:35` 13% | `to_h { \|elem\| [elem, yield(elem)] } # rubocop:disable Rails/IndexWith` |
| 6 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` | 22.31 / 22.31 | 100% | `app/models/room.rb:91` 16%, `lib/web_push/pool.rb:13` 15% | `val = step` |
| 7 | `RAILS/activesupport/lib/active_support/colorize_logging.rb:62` (debug logging) | 22.25 / 22.25 | 100% | `no app frame` 21%, `app/models/room.rb:72` 19% | `modes = MODES.values_at(*options.compact_blank.keys)` |
| 8 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:118` | 21.13 / 21.13 | 100% | `app/models/room/message_pusher.rb:54` 19%, `app/models/room.rb:72` 11% | `attributes.flat_map do \|key, value\|` |
| 9 | `RAILS/activerecord/lib/arel/table.rb:92` | 20.63 / 20.63 | 100% | `lib/web_push/pool.rb:13` 17%, `app/models/room.rb:72` 11% | `Attribute.new(table, name)` |
| 10 | `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:28` | 19.88 / 19.88 | 100% | `app/models/room/message_pusher.rb:54` 14%, `app/models/room.rb:72` 12% | `attributes.each_with_object([]) do \|(key, value), result\|` |

### Action Cable

| # | Channel action | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | RoomMessagesChannel#subscribed | 7 / 7 | 584.0 / 584.0 | 0.0 | 505.7 | `RAILS/activesupport/lib/active_support/callbacks.rb:180` 16.0, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 12.0, `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/synchronization/safe_initialization.rb:30` 12.0 | `app/channels/room_messages_channel.rb:36` 184.0, `app/channels/room_messages_channel.rb:30` 147.0, `app/channels/room_messages_channel.rb:52` 16.0 |
| 2 | PresenceChannel#subscribed | 7 / 7 | – / – |  | 878.7 |  |  |
| 3 | Turbo::StreamsChannel#subscribed | 2 / 2 | – / – |  | 129.5 |  |  |
| 4 | UnreadRoomsChannel#subscribed | 3 / 3 | – / – |  | 93.0 |  |  |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `RAILS/activerecord/lib/active_record/log_subscriber.rb:40` (debug logging) | 7.84 / 7.84 | 63% | `app/channels/presence_channel.rb:21` 26%, `app/channels/room_channel.rb:12` 23% | `binds = binds.inspect` |
| 2 | `RAILS/activesupport/lib/active_support/callbacks.rb:180` | 6.74 / 6.74 | 100% | `no app frame` 100% | `result_lambda = -> { user_callback.call target, value }` |
| 3 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | 5.05 / 5.05 | 63% | `app/channels/room_channel.rb:12` 40%, `app/channels/presence_channel.rb:21` 31% | `WhereClause.new(predicates \| other.predicates)` |
| 4 | `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/synchronization/safe_initialization.rb:30` | 5.05 / 5.05 | 100% | `no app frame` 100% | `super(*args, &block)` |
| 5 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` | 5.0 / 5.0 | 47% | `app/channels/presence_channel.rb:21` 47%, `app/channels/room_messages_channel.rb:36` 23% | `to_h { \|elem\| [elem, yield(elem)] } # rubocop:disable Rails/IndexWith` |
| 6 | `RAILS/activesupport/lib/active_support/colorize_logging.rb:64` (debug logging) | 4.42 / 4.42 | 63% | `app/channels/presence_channel.rb:21` 28%, `app/channels/room_channel.rb:12` 24% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 7 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` | 3.05 / 3.05 | 63% | `app/channels/presence_channel.rb:21` 38%, `app/channels/room_messages_channel.rb:36` 26% | `val = step` |
| 8 | `RAILS/activesupport/lib/active_support/colorize_logging.rb:62` (debug logging) | 2.95 / 2.95 | 63% | `app/channels/presence_channel.rb:21` 28%, `app/channels/room_channel.rb:12` 24% | `modes = MODES.values_at(*options.compact_blank.keys)` |
| 9 | `RAILS/activerecord/lib/active_record/key.rb:14` | 2.95 / 2.95 | 58% | `app/channels/presence_channel.rb:21` 62%, `app/channels/room_channel.rb:12` 23% | `Single.new(name)` |
| 10 | `RAILS/activerecord/lib/active_record/key.rb:87` | 2.95 / 2.95 | 58% | `app/channels/presence_channel.rb:21` 62%, `app/channels/room_channel.rb:12` 23% | `@columns = [@name].freeze` |
