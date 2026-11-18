# Lowrail profile

Command: `bin/rails test -v --exclude /test_unpublishing_a_book_revokes_the_disk_URL/`, test environment, ruby 4.0.7 (2026-09-15 revision 229531a6cf) +YJIT +PRISM [x86_64-linux].

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 2 | 337 | 13791.8 | 2 | 0 | 0 | 0 |
| run2 | 2 | 337 | 13790.9 | 2 | 0 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.42 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/controllers/concerns/inline_script_hashes.rb:27` | `script_origins` | 985.36 | 0.0 | 26.07 | `GEM/uri/lib/uri/generic.rb:1007` 15%, `GEM/rack/lib/rack/request.rb:693` 6%, `GEM/uri/lib/uri/common.rb:108` 5% | SessionsController#create 53%, Books::SearchesController#create 9%, LeafablesController#show 8% | `origin = URI.join(request.base_url, url).origin` |
| 2 | `app/models/session.rb:11` | `start!` | 162.01 | 77.7 | 0.38 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 5%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:171` 4%, `GEM/tzinfo/lib/tzinfo/timestamp.rb:208` 3% | SessionsController#create 100%, Sessions::TransfersController#update 0%, FirstRunsController#create 0% | `create! user_agent: user_agent, ip_address: ip_address` |
| 3 | `app/controllers/concerns/inline_script_hashes.rb:28` | `script_origins` | 104.26 | 0.0 | 0.0 | `GEM/rack/lib/rack/request.rb:693` 50%, `RAILS/actionpack/lib/action_dispatch/http/url.rb:348` 25%, `GEM/rack/lib/rack/request.rb:595` 25% | SessionsController#create 53%, Books::SearchesController#create 9%, LeafablesController#show 8% | `origin unless origin == request.base_url` |
| 4 | `app/models/embed_provider.rb:148` | `resolution` | 103.05 | 40.91 | 1.89 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 7%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 4%, `RAILS/activerecord/lib/active_record/relation/finder_methods.rb:686` 3% | SessionsController#create 45%, BooksController#show 16%, SessionsController#new 8% | `source = [ ENV["WRITEBOOK_EMBED_PROVIDERS"].presence, Account.first&.e` |
| 5 | `app/models/book/accessable.rb:32` | `access_for` | 76.83 | 34.46 | 1.28 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 7%, `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 4%, `RAILS/activerecord/lib/active_record/relation/predicate_builder.rb:144` 4% | BooksController#show 44%, LeafablesController#show 34%, PagesController#show 14% | `accesses.find_by(user: user)` |
| 6 | `app/views/layouts/application.html.erb:28` |  | 65.29 | 72.48 | 0.61 | `RAILS/actionview/lib/action_view/helpers/asset_url_helper.rb:248` 17%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` 9%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:243` 9% | Books::SearchesController#create 29%, LeafablesController#show 23%, SessionsController#new 22% | `<%= stylesheet_link_tag :all, "data-turbo-track": "reload" %>` |
| 7 | `app/controllers/sessions_controller.rb:11` | `create` | 57.28 | 20.83 | 0.77 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 6%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 5%, `GEM/bcrypt/lib/bcrypt/password.rb:102` 4% | SessionsController#create 100% | `if user = User.active.authenticate_by(email_address: params[:email_add` |
| 8 | `app/views/layouts/application.html.erb:31` |  | 42.34 | 199.5 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:243` 20%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` 20%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:1542` 18% | SessionsController#new 36%, Books::SearchesController#create 23%, LeafablesController#show 19% | `<%= javascript_importmap_tags %>` |
| 9 | `app/views/leaves/_sidebar.html.erb:8` |  | 40.67 | 12.11 | 0.0 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` 4%, `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 4%, `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:21` 3% | LeafablesController#show 74%, PagesController#show 26%, PicturesController#edit 0% | `<% book.leaves.active.with_leafables.positioned.each do \|leaf\| %>` |
| 10 | `app/controllers/concerns/authentication.rb:76` | `set_authentication_cookie` | 39.46 | 0.0 | 0.64 | `RAILS/activesupport/lib/active_support/core_ext/hash/keys.rb:40` 10%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:171` 10%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:166` 6% | SessionsController#create 64%, Books::SearchesController#create 9%, SessionsController#destroy 5% | `cookies.signed.permanent[:session_token] = { value: session.token, htt` |
| 11 | `app/controllers/concerns/authentication/session_lookup.rb:3` | `find_session_by_cookie` | 35.37 | 0.0 | 0.0 | `GEM/uri/lib/uri/common.rb:465` 13%, `GEM/rack/lib/rack/utils.rb:331` 9%, `RAILS/actionpack/lib/action_dispatch/middleware/cookies.rb:634` 7% | SessionsController#create 25%, Books::SearchesController#create 15%, LeafablesController#show 9% | `if token = cookies.signed[:session_token]` |
| 12 | `app/models/current.rb:8` | `session=` | 30.93 | 12.93 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 8%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 7%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 5% | Books::SearchesController#create 21%, SessionsController#destroy 13%, SessionsController#create 11% | `self.user = session.user` |
| 13 | `app/controllers/concerns/inline_script_hashes.rb:26` | `script_origins` | 29.0 | 0.0 | 2.17 | `GEM/json/lib/json/common.rb:364` 100% | SessionsController#create 54%, Books::SearchesController#create 8%, LeafablesController#show 7% | `JSON.parse(importmap)["imports"].values.filter_map do \|url\|` |
| 14 | `app/controllers/concerns/authentication.rb:49` | `start_new_session_for` | 24.49 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 13%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:114` 6%, `RAILS/activerecord/lib/active_record/relation.rb:78` 6% | SessionsController#create 100%, FirstRunsController#create 0%, Sessions::TransfersController#update 0% | `user.sessions.start!(user_agent: request.user_agent, ip_address: reque` |
| 15 | `lib/rails_ext/action_text_has_markdown.rb:9` | `#{name}` | 24.02 | 7.44 | 0.01 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 7%, `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 4%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:114` 3% | LeafablesController#show 33%, BooksController#show 32%, Pages::EditsController#show 19% | `markdown_#{name} \|\| build_markdown_#{name}` |
| 16 | `app/controllers/concerns/authentication.rb:72` | `post_authenticating_url` | 22.73 | 0.0 | 0.38 | `RAILS/activesupport/lib/active_support/key_generator.rb:78` 8%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:56` 7%, `RAILS/actionpack/lib/action_dispatch/middleware/cookies.rb:665` 5% | SessionsController#create 100%, Sessions::TransfersController#update 0% | `session.delete(:return_to_after_authenticating) \|\| root_url` |
| 17 | `app/models/book/accessable.rb:19` | `accessable_or_published_books` | 21.66 | 0.0 | 0.3 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 8%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:19` 8%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:114` 4% | Books::SearchesController#create 38%, BooksController#show 16%, LeafablesController#show 12% | `user.books.or(published).distinct` |
| 18 | `app/models/current.rb:13` | `account` | 21.6 | 9.76 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 8%, `RAILS/activerecord/lib/active_record/relation/finder_methods.rb:684` 4%, `RAILS/activerecord/lib/active_record/relation/finder_methods.rb:686` 4% | Books::SearchesController#create 29%, LeafablesController#show 23%, SessionsController#new 20% | `Account.first` |
| 19 | `config/routes.rb:47` |  | 19.64 | 0.0 | 0.64 | `RAILS/actionpack/lib/action_dispatch/http/url.rb:205` 6%, `RAILS/actionpack/lib/action_dispatch/routing/url_for.rb:223` 6%, `RAILS/actionpack/lib/action_dispatch/http/url.rb:239` 6% | LeafablesController#show 57%, BooksController#show 20%, PagesController#show 16% | `route_for :slugged_leafable, leaf.book, leaf.book.slug, leaf, leaf.slu` |
| 20 | `app/controllers/concerns/authentication/session_lookup.rb:4` | `find_session_by_cookie` | 18.28 | 13.67 | 0.55 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 13%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 9%, `GEM/sqlite3/lib/sqlite3/statement.rb:54` 4% | Books::SearchesController#create 20%, SessionsController#destroy 12%, SessionsController#create 10% | `Session.find_by(token: token)` |
| 21 | `app/controllers/sessions_controller.rb:13` | `create` | 16.08 | 6.12 | 0.38 | `GEM/uri/lib/uri/rfc3986_parser.rb:85` 10%, `GEM/uri/lib/uri/common.rb:108` 10%, `RAILS/actionpack/lib/action_controller/metal/redirecting.rb:223` 5% | SessionsController#create 100% | `redirect_to post_authenticating_url` |
| 22 | `app/controllers/concerns/inline_script_hashes.rb:15` |  | 15.71 | 181.85 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/string/filters.rb:56` 17%, `RAILS/activesupport/lib/active_support/core_ext/string/filters.rb:44` 16%, `RAILS/actionpack/lib/abstract_controller/rendering.rb:63` 9% | SessionsController#new 57%, SessionsController#create 25%, Books::SearchesController#create 4% | `importmap = Rails.application.importmap.to_json(resolver: helpers)` |
| 23 | `app/helpers/pages_helper.rb:12` | `sanitize_content` | 14.46 | 0.0 | 0.3 | `GEM/nokogiri/lib/nokogiri/xml/document.rb:416` 15%, `GEM/loofah/lib/loofah/scrubber.rb:132` 15%, `GEM/nokogiri/lib/nokogiri/html5/node.rb:66` 12% | LeafablesController#show 54%, BooksController#show 17%, Pages::EditsController#show 15% | `sanitize content, scrubber: HtmlScrubber.new` |
| 24 | `app/controllers/concerns/set_book_leaf.rb:15` | `set_leaf` | 13.41 | 4.16 | 0.07 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 5%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 4%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:15` 3% | LeafablesController#show 75%, PagesController#show 22%, PicturesController#update 4% | `@leaf = @book.leaves.active.find(params[:id])` |
| 25 | `app/helpers/searches_helper.rb:10` | `sanitize_search_result` | 11.39 | 0.0 | 0.52 | `GEM/nokogiri/lib/nokogiri/html5/node.rb:66` 13%, `GEM/nokogiri/lib/nokogiri/xml/document.rb:416` 11%, `GEM/nokogiri/lib/nokogiri/xml/node.rb:1429` 9% | Books::SearchesController#create 100% | `sanitize(html, tags: %w[mark], attributes: [])` |
| 26 | `config/routes.rb:68` |  | 10.53 | 0.0 | 0.64 | `RAILS/actionpack/lib/action_dispatch/journey/formatter.rb:134` 6%, `RAILS/activerecord/lib/active_record/integration.rb:71` 6%, `RAILS/actionpack/lib/action_dispatch/http/url.rb:239` 6% | BooksController#show 36%, PagesController#show 26%, LeafablesController#show 18% | `route_for "edit_book_#{leaf.leafable_name}", leaf.book, leaf, options` |
| 27 | `app/controllers/concerns/set_book_leaf.rb:11` | `set_book` | 9.43 | 4.69 | 0.08 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 9%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 4%, `RAILS/activerecord/lib/arel/nodes/select_statement.rb:11` 2% | LeafablesController#show 66%, PagesController#show 19%, PagesController#create 12% | `@book = Book.accessable_or_published.find(params[:book_id])` |
| 28 | `app/views/books/show.html.erb:116` |  | 9.34 | 3.3 | 0.09 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 4%, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 3%, `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:21` 3% | BooksController#show 100% | `<%= turbo_frame_tag :leaves, data: { arrangement_target: "list" } do -` |
| 29 | `app/models/leafable.rb:11` |  | 8.36 | 3.39 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 7%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 6%, `RAILS/activerecord/lib/active_record/associations/association_scope.rb:160` 4% | LeafablesController#show 75%, PagesController#show 25%, PicturesController#edit 0% | `delegate :title, to: :leaf` |
| 30 | `app/controllers/concerns/set_book_leaf.rb:19` | `set_leafable` | 7.84 | 3.59 | 0.07 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 7%, `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 4%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:114` 4% | LeafablesController#show 74%, PagesController#show 22%, PicturesController#update 4% | `instance_variable_set "@#{instance_name}", @leaf.leafable` |

App middleware that hands the request on (the stack below it, not its own work): `config/initializers/uploaded_script_guard.rb:23` 121.89 warm objects per request.

234.26 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | Pages::EditsController#show | 9 / 9 | 87953.0 / 87956.1 | 3.1 | 101859.3 | `RAILS/actionview/lib/action_view/buffers.rb:47` 374.6, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:243` 230.6, `GEM/uri/lib/uri/generic.rb:1007` 210.0 | `app/controllers/concerns/inline_script_hashes.rb:27` 1366.0, `app/controllers/concerns/page_leaf_scoped.rb:11` 308.1, `config/initializers/uploaded_script_guard.rb:23` 246.9 |
| 2 | BooksController#show | 10 / 10 | 47772.0 / 47770.1 | -1.9 | 42619.8 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:243` 226.1, `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 224.9, `GEM/uri/lib/uri/generic.rb:1007` 210.0 | `app/models/book/accessable.rb:32` 1428.8, `app/controllers/concerns/inline_script_hashes.rb:27` 1366.0, `app/models/embed_provider.rb:148` 673.0 |
| 3 | LeafablesController#show | 21 / 21 | 23592.4 / 23592.6 | 0.2 | 21802.3 | `GEM/uri/lib/uri/generic.rb:1007` 210.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:243` 152.2, `GEM/rack/lib/rack/request.rb:693` 149.3 | `app/controllers/concerns/inline_script_hashes.rb:27` 1366.5, `app/views/leaves/_sidebar.html.erb:8` 537.1, `app/models/book/accessable.rb:32` 461.5 |
| 4 | Books::SearchesController#create | 23 / 23 | 18918.8 / 18917.8 | -1.0 | 17859.7 | `GEM/uri/lib/uri/generic.rb:1007` 210.0, `GEM/rack/lib/rack/request.rb:693` 151.6, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:243` 118.9 | `app/controllers/concerns/inline_script_hashes.rb:27` 1366.0, `app/views/layouts/application.html.erb:28` 299.0, `config/initializers/uploaded_script_guard.rb:23` 218.0 |
| 5 | SessionsController#new | 18 / 18 | 12010.9 / 12012.7 | 1.8 | 11108.9 | `GEM/rack/lib/rack/request.rb:693` 139.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:243` 121.6, `GEM/uri/lib/uri/generic.rb:1007` 118.1 | `app/controllers/concerns/inline_script_hashes.rb:27` 1199.4, `app/views/layouts/application.html.erb:31` 321.3, `app/views/layouts/application.html.erb:28` 300.0 |
| 6 | PagesController#show | 7 / 7 | 10146.8 / 10141.4 | -5.4 | 10293.1 | `GEM/uri/lib/uri/generic.rb:1007` 210.0, `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 159.4, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:243` 154.2 | `app/controllers/concerns/inline_script_hashes.rb:27` 1366.0, `app/models/book/accessable.rb:32` 734.4, `app/views/leaves/_sidebar.html.erb:8` 700.0 |
| 7 | PicturesController#update | 3 / 3 | 7258.0 / 7261.0 | 3.0 | 7948.3 | `GEM/uri/lib/uri/generic.rb:1007` 210.0, `GEM/rack/lib/rack/request.rb:693` 152.0, `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 113.0 | `app/controllers/concerns/inline_script_hashes.rb:27` 1366.0, `app/models/leaf/editable.rb:47` 1057.0, `app/models/leaf/editable.rb:45` 378.0 |
| 8 | PagesController#create | 5 / 5 | 6062.7 / 6064.3 | 1.7 | 6784.6 | `GEM/uri/lib/uri/generic.rb:1007` 210.0, `GEM/rack/lib/rack/request.rb:693` 152.0, `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 74.3 | `app/controllers/concerns/inline_script_hashes.rb:27` 1366.0, `app/models/book.rb:13` 483.0, `app/models/page.rb:31` 287.3 |
| 9 | Users::ProfilesController#show | 2 / 2 | 4877.0 / 4878.0 | 1.0 | 30741.0 | `GEM/uri/lib/uri/generic.rb:1007` 210.0, `GEM/rack/lib/rack/request.rb:693` 152.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:243` 131.0 | `app/controllers/concerns/inline_script_hashes.rb:27` 1366.0, `app/views/layouts/application.html.erb:28` 312.0, `config/initializers/uploaded_script_guard.rb:23` 210.0 |
| 10 | Books::BookmarksController#show | 3 / 3 | 4703.0 / 4704.0 | 1.0 | 5310.3 | `GEM/uri/lib/uri/generic.rb:1007` 210.0, `GEM/rack/lib/rack/request.rb:693` 152.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:243` 87.0 | `app/controllers/concerns/inline_script_hashes.rb:27` 1366.0, `app/views/layouts/application.html.erb:28` 314.0, `config/initializers/uploaded_script_guard.rb:23` 214.0 |
| 11 | BooksController#index | 4 / 4 | 4628.5 / 4629.5 | 1.0 | 4465.3 | `GEM/uri/lib/uri/generic.rb:1007` 210.0, `GEM/rack/lib/rack/request.rb:693` 150.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:243` 94.5 | `app/controllers/concerns/inline_script_hashes.rb:27` 1366.0, `app/views/layouts/application.html.erb:28` 312.0, `config/initializers/uploaded_script_guard.rb:23` 204.0 |
| 12 | BooksController#update | 2 / 2 | 4028.0 / 4022.0 | -6.0 | 6114.0 | `GEM/uri/lib/uri/generic.rb:1007` 210.0, `GEM/rack/lib/rack/request.rb:693` 152.0, `GEM/uri/lib/uri/common.rb:108` 76.0 | `app/controllers/concerns/inline_script_hashes.rb:27` 1366.0, `app/models/book/accessable.rb:44` 203.0, `app/models/book/accessable.rb:32` 169.0 |
| 13 | BooksController#create | 4 / 4 | 3727.7 / 3727.0 | -0.7 | 4625.8 | `GEM/uri/lib/uri/generic.rb:1007` 210.0, `GEM/rack/lib/rack/request.rb:693` 152.0, `GEM/uri/lib/uri/rfc3986_parser.rb:85` 76.0 | `app/controllers/concerns/inline_script_hashes.rb:27` 1366.0, `app/controllers/books_controller.rb:18` 278.3, `app/models/book/accessable.rb:44` 194.7 |
| 14 | ActionText::Markdown::UploadsController#create | 7 / 7 | 3663.4 / 3661.2 | -2.2 | 5221.1 | `GEM/uri/lib/uri/generic.rb:1007` 210.0, `GEM/rack/lib/rack/request.rb:693` 152.0, `GEM/uri/lib/uri/generic.rb:543` 73.2 | `app/controllers/concerns/inline_script_hashes.rb:27` 1366.0, `app/controllers/action_text/markdown/uploads_controller.rb:32` 174.2, `app/models/book/accessable.rb:19` 146.0 |
| 15 | ActionText::Markdown::UploadsController#show | 10 / 10 | 3521.1 / 3513.6 | -7.5 | 3604.6 | `GEM/uri/lib/uri/generic.rb:1007` 210.0, `GEM/rack/lib/rack/request.rb:693` 150.0, `GEM/uri/lib/uri/rfc3986_parser.rb:85` 72.0 | `app/controllers/concerns/inline_script_hashes.rb:27` 1367.9, `app/controllers/action_text/markdown/uploads_controller.rb:49` 239.0, `app/controllers/action_text/markdown/uploads_controller.rb:67` 204.9 |
| 16 | SessionsController#create | 132 / 132 | 3374.4 / 3373.2 | -1.1 | 4617.8 | `GEM/uri/lib/uri/generic.rb:1007` 210.0, `GEM/rack/lib/rack/request.rb:693` 156.0, `GEM/uri/lib/uri/common.rb:108` 76.0 | `app/controllers/concerns/inline_script_hashes.rb:27` 1366.3, `app/models/session.rb:11` 420.0, `app/controllers/sessions_controller.rb:11` 148.5 |
| 17 | UsersController#update | 2 / 2 | 3254.0 / 3257.0 | 3.0 | 3234.0 | `GEM/uri/lib/uri/generic.rb:1007` 210.0, `GEM/rack/lib/rack/request.rb:693` 152.0, `GEM/uri/lib/uri/rfc3986_parser.rb:85` 76.0 | `app/controllers/concerns/inline_script_hashes.rb:27` 1366.0, `app/controllers/users_controller.rb:26` 233.0, `config/initializers/uploaded_script_guard.rb:23` 145.0 |
| 18 | SessionsController#destroy | 13 / 13 | 3057.6 / 3056.5 | -1.1 | 3056.7 | `GEM/uri/lib/uri/generic.rb:1007` 210.0, `GEM/rack/lib/rack/request.rb:693` 156.0, `GEM/uri/lib/uri/rfc3986_parser.rb:85` 76.0 | `app/controllers/concerns/inline_script_hashes.rb:27` 1366.0, `app/controllers/concerns/inline_script_hashes.rb:28` 144.0, `app/controllers/concerns/authentication.rb:60` 125.0 |
| 19 | Users::ProfilesController#edit | 2 / 2 | 2781.0 / 2781.0 | 0.0 | 30380.5 | `GEM/uri/lib/uri/generic.rb:1007` 210.0, `GEM/rack/lib/rack/request.rb:693` 152.0, `GEM/uri/lib/uri/common.rb:194` 72.0 | `app/controllers/concerns/inline_script_hashes.rb:27` 1366.0, `app/controllers/concerns/inline_script_hashes.rb:28` 144.0, `config/initializers/uploaded_script_guard.rb:23` 123.0 |
| 20 | UsersController#new | 3 / 3 | 2334.0 / 2334.0 | 0.0 | 3397.3 | `GEM/uri/lib/uri/generic.rb:1007` 210.0, `GEM/rack/lib/rack/request.rb:693` 148.0, `GEM/uri/lib/uri/rfc3986_parser.rb:135` 72.0 | `app/controllers/concerns/inline_script_hashes.rb:27` 1366.0, `app/controllers/concerns/inline_script_hashes.rb:28` 144.0, `app/models/embed_provider.rb:148` 120.0 |
| 21 | ActiveStorage::DiskController#show | 14 / 14 | 1241.3 / 1241.3 | -0.1 | 1415.3 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 34.2, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 22.7, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 19.0 | `config/initializers/uploaded_script_guard.rb:23` 139.3, `app/controllers/concerns/active_storage_authorization.rb:25` 129.3, `config/initializers/active_storage_authentication.rb:29` 125.5 |
| 22 | ActiveStorage::Blobs::RedirectController#show | 3 / 3 | 1101.0 / 1101.0 | 0.0 | 1109.0 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 29.0, `GEM/sqlite3/lib/sqlite3/statement.rb:125` 23.0, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 16.0 | `config/initializers/uploaded_script_guard.rb:23` 205.0, `app/models/book/accessable.rb:24` 149.0, `app/controllers/concerns/active_storage_authorization.rb:25` 126.0 |
| 23 | ActiveStorage::DirectUploadsController#create | 4 / 4 | 902.5 / 899.0 | -3.5 | 1218.8 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` 15.5, `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:89` 12.0, `GEM/json/lib/json/common.rb:364` 10.0 | `config/initializers/uploaded_script_guard.rb:23` 459.0, `app/controllers/concerns/authentication/session_lookup.rb:3` 53.5, `app/controllers/concerns/authentication/session_lookup.rb:4` 34.5 |
| 24 | ActiveStorage::DiskController#update | 2 / 2 | 730.0 / 725.0 | -5.0 | 566.0 | `GEM/json/lib/json/common.rb:364` 19.0, `GEM/uri/lib/uri/common.rb:465` 11.0, `RUBY/ipaddr.rb:725` 10.0 | `config/initializers/uploaded_script_guard.rb:23` 272.0, `app/controllers/concerns/authentication/session_lookup.rb:3` 89.0, `app/controllers/concerns/authentication/session_lookup.rb:4` 69.0 |
| 25 | FirstRunsController#create | 2 / 2 | – / – |  | 326405.5 |  |  |
| 26 | PagesController#edit | 1 / 1 | – / – |  | 14221.0 |  |  |
| 27 | PicturesController#edit | 2 / 2 | – / – |  | 11358.0 |  |  |
| 28 | PicturesController#create | 2 / 2 | – / – |  | 8058.5 |  |  |
| 29 | PagesController#update | 1 / 1 | – / – |  | 7310.0 |  |  |
| 30 | Books::Leaves::MovesController#create | 2 / 2 | – / – |  | 7191.0 |  |  |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: pull requests from Lowrail's contributions ledger that change this line, and whether the app's version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/uri/lib/uri/generic.rb:1007` | `split_path` | 187.57 / 187.57 | 0.0 | 188.81 | 90% | String, Array |  | `app/controllers/concerns/inline_script_hashes.rb:27` 100% | `path.split("/", -1)` |
| 2 | `GEM/rack/lib/rack/request.rb:693` | `split_header` | 139.99 / 139.99 | 0.0 | 140.91 | 99% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:27` 49%, `app/controllers/concerns/inline_script_hashes.rb:28` 47% | `value ? value.strip.split(/[, \t]+/) : []` |
| 3 | `RAILS/actiontext/lib/action_text/bottom_up_reducer.rb:24` | `traverse_bottom_up` | 131.97 / 131.97 | 0.0 | 132.17 | 3% | Data, Array |  | `app/models/page.rb:31` 100% | `children = node.children.to_a` |
| 4 | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:270` | `xpath_impl` | 116.39 / 116.39 | 0.0 | 116.61 | 3% | Data, Array |  | `app/models/page.rb:31` 99%, `app/models/leaf/searchable.rb:72` 1% | `context.evaluate(path, handler)` |
| 5 | `RAILS/actiontext/lib/action_text/plain_text_conversion.rb:26` | `plain_text_method_for_node` | 95.67 / 95.63 | -0.04 | 95.8 | 3% | String, Symbol |  | `app/models/page.rb:31` 100% | `:"plain_text_for_#{node.name}_node"` |
| 6 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:88` | `index_with` | 74.24 / 74.26 | 0.03 | 74.67 | 99% | Array, Hash |  | `app/models/embed_provider.rb:148` 13%, `app/models/session.rb:11` 10% | `to_h { \|elem\| [elem, yield(elem)] } # rubocop:disable Rails/IndexWith` |
| 7 | `GEM/uri/lib/uri/rfc3986_parser.rb:85` | `split` | 68.68 / 68.68 | 0.0 | 69.13 | 92% | MatchData, String |  | `app/controllers/concerns/inline_script_hashes.rb:27` 97%, `app/controllers/sessions_controller.rb:13` 2% | `if m = RFC3986_URI.match(uri)` |
| 8 | `GEM/uri/lib/uri/common.rb:108` | `escape` | 68.65 / 68.65 | 0.0 | 69.1 | 92% | String |  | `app/controllers/concerns/inline_script_hashes.rb:27` 97%, `app/controllers/sessions_controller.rb:13` 2% | `name.upcase.tr(ReservedChars, EscapedChars)` |
| 9 | `GEM/uri/lib/uri/generic.rb:543` | `split_userinfo` | 66.88 / 66.85 | -0.03 | 67.3 | 93% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:27` 98%, `app/controllers/sessions_controller.rb:13` 1% | `return nil, nil unless ui` |
| 10 | `GEM/uri/lib/uri/generic.rb:516` | `set_userinfo` | 66.85 / 66.85 | 0.0 | 67.29 | 93% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:27` 98%, `app/controllers/sessions_controller.rb:13` 1% | `[@user, @password]` |
| 11 | `GEM/uri/lib/uri/common.rb:194` | `for` | 66.59 / 66.59 | 0.0 | 67.03 | 92% | Object |  | `app/controllers/concerns/inline_script_hashes.rb:27` 98%, `app/controllers/sessions_controller.rb:13` 1% | `return uri_class.new(scheme, *arguments)` |
| 12 | `GEM/uri/lib/uri/rfc3986_parser.rb:135` | `parse` | 66.59 / 66.59 | 0.0 | 67.03 | 92% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:27` 98%, `app/controllers/sessions_controller.rb:13` 1% | `URI.for(*self.split(uri), self)` |
| 13 | `RAILS/actionpack/lib/action_dispatch/http/url.rb:348` | `host_with_port` | 65.64 / 65.64 | 0.0 | 66.06 | 92% | String |  | `app/controllers/concerns/inline_script_hashes.rb:28` 50%, `app/controllers/concerns/inline_script_hashes.rb:27` 50% | `"#{host}#{port_string}"` |
| 14 | `GEM/rack/lib/rack/request.rb:595` | `base_url` | 65.63 / 65.63 | 0.0 | 66.06 | 92% | String |  | `app/controllers/concerns/inline_script_hashes.rb:28` 50%, `app/controllers/concerns/inline_script_hashes.rb:27` 50% | `"#{scheme}://#{host_with_port}"` |
| 15 | `GEM/uri/lib/uri/rfc3986_parser.rb:115` | `split` | 64.52 / 64.52 | 0.0 | 64.95 | 90% | MatchData, String |  | `app/controllers/concerns/inline_script_hashes.rb:27` 100% | `elsif m = RFC3986_relative_ref.match(uri)` |
| 16 | `GEM/nokogiri/lib/nokogiri/xml/searchable.rb:264` | `xpath_impl` | 58.01 / 58.01 | 0.0 | 58.11 | 3% | Data |  | `app/models/page.rb:31` 99%, `app/models/leaf/searchable.rb:72` 1% | `context = XPathContext.new(node)` |
| 17 | `GEM/nokogiri/lib/nokogiri/xml/node.rb:145` | `dup` | 57.63 / 57.63 | 0.0 | 57.72 | 2% | Data |  | `app/models/page.rb:31` 100% | `super().initialize_copy_with_args(self, level, new_parent_doc)` |
| 18 | `GEM/nokogiri/lib/nokogiri/xml/node_set.rb:90` | `css` | 57.63 / 57.63 | 0.0 | 57.72 | 2% | Data |  | `app/models/page.rb:31` 100% | `set + xpath_internal(node, paths, handler, ns, nil)` |
| 19 | `RAILS/actiontext/lib/action_text/plain_text_conversion.rb:92` | `remove_trailing_newlines` | 55.63 / 55.63 | 0.0 | 55.73 | 3% | String |  | `app/models/page.rb:31` 100% | `text.chomp("")` |
| 20 | `RAILS/actiontext/lib/action_text/bottom_up_reducer.rb:13` † | `reduce` | 48.06 / 48.09 | 0.03 | 48.16 | 3% | Array |  | `app/models/page.rb:31` 100% | `@values[n] = block.call(n, children.map { \|child\| @values[child] })` |
| 21 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:243` | `html_safe` | 47.34 / 47.34 | 0.0 | 48.36 | 34% | String |  | `app/views/layouts/application.html.erb:31` 23%, `no app frame` 22% | `ActiveSupport::SafeBuffer.new(self)` |
| 22 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | `merge` | 45.83 / 45.83 | 0.0 | 45.97 | 88% | Array, Object |  | `app/models/book/accessable.rb:32` 15%, `lib/rails_ext/action_text_has_markdown.rb:9` 11% | `WhereClause.new(predicates \| other.predicates)` |
| 23 | `GEM/json/lib/json/common.rb:364` | `parse` | 45.71 / 45.29 | -0.42 | 45.76 | 99% | String, Hash |  | `app/controllers/concerns/inline_script_hashes.rb:26` 81%, `app/controllers/concerns/authentication/session_lookup.rb:3` 8% | `Parser.parse(source, opts)` |
| 24 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:171` | `change` | 38.46 / 38.41 | -0.05 | 38.58 | 80% | Rational, Data |  | `no app frame` 23%, `app/models/session.rb:11` 19% | `::Time.utc(new_year, new_month, new_day, new_hour, new_min, new_sec)` |
| 25 | `GEM/sqlite3/lib/sqlite3/statement.rb:125` | `each` | 37.37 / 37.35 | -0.03 | 37.95 | 95% | String, Array |  | `app/models/embed_provider.rb:148` 13%, `no app frame` 13% | `val = step` |
| 26 | `GEM/uri/lib/uri/generic.rb:335` | `set_scheme` | 34.46 / 34.46 | 0.0 | 34.71 | 93% | String, Array |  | `app/controllers/concerns/inline_script_hashes.rb:27` 97%, `app/controllers/sessions_controller.rb:13` 2% | `@scheme = v&.downcase` |
| 27 | `GEM/uri/lib/uri/rfc3986_parser.rb:87` | `split` | 34.34 / 34.34 | 0.0 | 34.57 | 92% | String |  | `app/controllers/concerns/inline_script_hashes.rb:27` 97%, `app/controllers/sessions_controller.rb:13` 2% | `scheme = m["scheme"]` |
| 28 | `GEM/uri/lib/uri/rfc3986_parser.rb:102` | `split` | 34.34 / 34.34 | 0.0 | 34.57 | 92% | Array |  | `app/controllers/concerns/inline_script_hashes.rb:27` 97%, `app/controllers/sessions_controller.rb:13` 2% | `[ scheme,` |
| 29 | `GEM/uri/lib/uri/rfc3986_parser.rb:104` | `split` | 34.34 / 34.34 | 0.0 | 34.57 | 92% | String |  | `app/controllers/concerns/inline_script_hashes.rb:27` 97%, `app/controllers/sessions_controller.rb:13` 2% | `m["host"],` |
| 30 | `GEM/uri/lib/uri/rfc3986_parser.rb:107` | `split` | 34.34 / 34.34 | 0.0 | 34.57 | 92% | String |  | `app/controllers/concerns/inline_script_hashes.rb:27` 97%, `app/controllers/sessions_controller.rb:13` 2% | `(m["path-abempty"] \|\|` |

## Dev/test-mode work

4851.8 of 10042.0 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | error page | `RUBY/error_highlight/base.rb:94` | 1884.85 | 2% | `no app frame` 100% | `Prism.parse_file(absolute_path).value.breadth_first_search { \|node\| no` |
| 2 | error page | `GEM/prism/lib/prism/parse_result.rb:70` | 750.97 | 2% | `no app frame` 100% | `source.lines` |
| 3 | asset lookup | `GEM/importmap-rails/lib/importmap/map.rb:133` † | 344.69 | 3% | `app/views/layouts/application.html.erb:31` 50%, `app/controllers/concerns/inline_script_hashes.rb:15` 50% | `module_filename = filename.relative_path_from(absolute_path)` |
| 4 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:40` | 93.2 | 99% | `no app frame` 18%, `app/models/session.rb:11` 12% | `binds = binds.inspect` |
| 5 | asset lookup | `GEM/propshaft/lib/propshaft/asset.rb:40` † | 90.78 | 30% | `app/views/layouts/application.html.erb:28` 63%, `app/views/layouts/application.html.erb:31` 8% | `logical_path.sub(/\.(\w+(\.map)?)$/) { \|ext\| "-#{digest}#{ext}" }` |
| 6 | error page | `RAILS/actionpack/lib/action_dispatch/middleware/exception_wrapper.rb:336` | 83.32 | 2% | `no app frame` 100% | `lines = source_lines.drop(start).take(6)` |
| 7 | debug logging | `RAILS/activesupport/lib/active_support/colorize_logging.rb:64` | 81.65 | 99% | `no app frame` 15%, `app/models/session.rb:11` 12% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 8 | error page | `GEM/prism/lib/prism/node.rb:2797` | 79.5 | 2% | `no app frame` 100% | `compact = [] #: Array[Prism::node]` |
| 9 | error page | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:205` | 62.98 | 2% | `no app frame` 100% | `add_filter(&Ractors.shareable_proc  { \|line\| line.sub(gems_regexp, gem` |
| 10 | error page | `GEM/prism/lib/prism/node.rb:18058` | 59.13 | 2% | `no app frame` 100% | `[*body]` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| ruby stdlib | 1981.6 | 2933.4 | `base.rb:94` 1884.9, `ipaddr.rb:725` 9.9, `digest.rb:56` 7.3 |
| rails: activerecord | 1406.9 | 1429.2 | `log_subscriber.rb:40` 93.2, `where_clause.rb:29` 45.8, `table.rb:91` 28.3 |
| ruby default gem: prism | 1223.9 | 1834.7 | `parse_result.rb:70` 751.0, `node.rb:2797` 79.5, `node.rb:18058` 59.1 |
| rails: activesupport | 1206.1 | 1436.1 | `colorize_logging.rb:64` 81.6, `enumerable.rb:88` 74.3, `backtrace_cleaner.rb:205` 63.0 |
| ruby default gem: uri | 1141.7 | 1150.2 | `generic.rb:1007` 187.6, `rfc3986_parser.rb:85` 68.7, `common.rb:108` 68.7 |
| rails: actionpack | 462.4 | 594.2 | `exception_wrapper.rb:336` 83.3, `url.rb:348` 65.6, `route_set.rb:90` 16.0 |
| gem: nokogiri | 434.5 | 486.9 | `searchable.rb:270` 116.4, `searchable.rb:264` 58.0, `node_set.rb:90` 57.6 |
| gem: importmap-rails | 416.5 | 466.1 | `map.rb:133` 344.7, `importmap_tags_helper.rb:34` 19.0, `map.rb:152` 13.7 |
| rails: actiontext | 412.8 | 497.6 | `bottom_up_reducer.rb:24` 132.0, `plain_text_conversion.rb:26` 95.6, `plain_text_conversion.rb:92` 55.6 |
| rails: actionview | 341.9 | 376.7 | `template.rb:590` 29.0, `tag_helper.rb:1542` 25.0, `buffers.rb:47` 15.6 |
| gem: rack | 267.9 | 275.1 | `request.rb:693` 140.0, `request.rb:595` 65.6, `utils.rb:408` 4.9 |
| gem: propshaft | 159.5 | 502.0 | `asset.rb:40` 90.8, `dynamic.rb:11` 45.4, `asset.rb:58` 11.3 |
| rails: activemodel | 152.3 | 158.9 | `attribute.rb:11` 26.4, `attribute_set.rb:226` 21.6, `builder.rb:21` 15.3 |
| app | 119.9 | 140.1 | `inline_script_hashes.rb:27` 32.8, `uploaded_script_guard.rb:25` 4.6, `inline_script_hashes.rb:33` 4.6 |
| gem: sqlite3 | 94.8 | 95.9 | `statement.rb:125` 37.4, `statement.rb:54` 25.3, `statement.rb:58` 12.9 |
| gem: logger | 62.7 | 62.9 | `log_device.rb:33` 20.9, `log_device.rb:165` 20.9, `logger.rb:692` 20.9 |
| gem: tzinfo | 57.6 | 57.9 | `timestamp.rb:208` 25.6, `constant_offset_data_timezone_info.rb:52` 12.8, `timestamp.rb:193` 12.8 |
| gem: json | 49.5 | 49.9 | `common.rb:364` 45.5, `common.rb:1089` 4.0, `common.rb:536` 0.0 |
| gem: erubi | 35.7 | 38.6 | `erubi.rb:134` 20.5, `erubi.rb:137` 4.5, `erubi.rb:139` 2.5 |
| rails: activestorage | 20.5 | 24.2 | `filename.rb:61` 2.7, `disk_service.rb:196` 1.2, `disk_service.rb:131` 1.2 |
| gem: concurrent-ruby | 19.2 | 19.5 | `safe_initialization.rb:30` 6.0, `mutex_lockable_object.rb:33` 2.0, `mutex_lockable_object.rb:32` 2.0 |
| gem: ruby-vips | 14.5 | 15.6 | `object.rb:202` 1.5, `object.rb:201` 1.5, `object.rb:200` 1.5 |
| gem: debug | 10.8 | 13.8 | `thread_client.rb:234` 2.7, `thread_client.rb:903` 2.7, `session.rb:140` 1.4 |
| gem: loofah | 10.8 | 11.0 | `scrubber.rb:132` 4.1, `concerns.rb:172` 2.9, `concerns.rb:43` 2.1 |
| gem: ffi | 10.2 | 10.8 | `managedstruct.rb:80` 3.6, `autopointer.rb:88` 3.1, `autopointer.rb:79` 1.5 |
| rails: railties | 9.0 | 9.2 | `logger.rb:57` 2.0, `engine.rb:851` 1.0, `logger.rb:37` 1.0 |
| gem: bcrypt | 7.5 | 7.7 | `password.rb:102` 2.4, `password.rb:103` 1.2, `engine.rb:70` 1.2 |
| ruby default gem: securerandom | 6.0 | 6.0 | `securerandom.rb:71` 6.0, `securerandom.rb:79` 0.0 |
| gem: rails-html-sanitizer | 5.0 | 5.2 | `sanitizer.rb:191` 0.7, `sanitizer.rb:33` 0.7, `scrubbers.rb:63` 0.5 |
| gem: base64 | 4.8 | 4.9 | `base64.rb:283` 3.5, `base64.rb:310` 1.3, `base64.rb:377` 0.0 |
| gem: turbo-rails | 4.0 | 4.9 | `frames_helper.rb:42` 1.2, `request_id_tracking.rb:10` 1.0, `frame_request.rb:36` 0.7 |
| gem: rack-session | 2.9 | 3.0 | `id.rb:277` 1.0, `id.rb:275` 1.0, `id.rb:368` 0.5 |
| gem: marcel | 2.8 | 3.0 | `magic.rb:18` 0.7, `mime_type.rb:136` 0.4, `magic.rb:146` 0.2 |
| gem: globalid | 2.3 | 3.6 | `gid.rb:95` 0.5, `gid.rb:159` 0.5, `gid.rb:166` 0.2 |
| gem: i18n | 1.0 | 2.3 | `i18n.rb:476` 0.2, `utils.rb:8` 0.2, `i18n.rb:396` 0.2 |
| ruby default gem: psych | 0.9 | 8.8 | `parser.rb:62` 0.2, `node.rb:33` 0.1, `tree_builder.rb:97` 0.1 |
| rails: activejob | 0.8 | 1.2 | `log_subscriber.rb:203` 0.2, `arguments.rb:164` 0.1, `enqueuing.rb:68` 0.1 |
| ruby default gem: prettyprint | 0.6 | 0.9 | `prettyprint.rb:404` 0.2, `prettyprint.rb:264` 0.1, `prettyprint.rb:459` 0.1 |
| ruby default gem: pp | 0.3 | 0.5 | `pp.rb:542` 0.1, `pp.rb:271` 0.1, `pp.rb:550` 0.1 |
| gem: bigdecimal | 0.0 | 0.0 | `util.rb:24` 0.0 |
| ruby default gem: erb | 0.0 | 0.0 | `util.rb:65` 0.0 |
| gem: herb | 0.0 | 52.4 | `herb.rb:31` 0.0, `errors.rb:1010` 0.0, `nodes.rb:653` 0.0 |
| gem: zeitwerk | 0.0 | 0.7 | `helpers.rb:41` 0.0, `cref.rb:47` 0.0, `inflector.rb:16` 0.0 |
| lowrail-profile | 0.0 | 0.0 | `profile.rb:55` 0.0, `profile.rb:65` 0.0 |
| rails: actioncable | 0.0 | 2.4 | `callbacks.rb:46` 0.0, `broadcasting.rb:12` 0.0, `broadcasting.rb:10` 0.0 |
| gem: front_matter_parser | 0.0 | 1.3 | `parser.rb:23` 0.0, `multi_line_comment.rb:19` 0.0, `multi_line_comment.rb:32` 0.0 |
| gem: crass | 0.0 | 0.5 | `scanner.rb:41` 0.0, `tokenizer.rb:303` 0.0, `crass.rb:30` 0.0 |
| gem: jbuilder | 0.0 | 0.1 | `jbuilder_template.rb:16` 0.0, `jbuilder_template.rb:287` 0.0, `jbuilder.rb:314` 0.0 |
| gem: useragent | 0.0 | 1.4 | `user_agent.rb:24` 0.0, `podcast_addict.rb:10` 0.0, `browsers.rb:50` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Jobs

| # | Job | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | ActiveStorage::PurgeJob#perform | 2 / 2 | 1366.0 / 1366.0 | 0.0 | 1399.5 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 28.0, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:379` 18.0, `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:258` 18.0 |  |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `RAILS/activesupport/lib/active_support/colorize_logging.rb:64` (debug logging) | 21.0 / 21.0 | 100% | `no app frame` 100% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 2 | `RAILS/activesupport/lib/active_support/colorize_logging.rb:57` (debug logging) | 18.0 / 18.0 | 100% | `no app frame` 100% | `clear = "\e[#{MODES[:clear]}m"` |
| 3 | `RAILS/activesupport/lib/active_support/colorize_logging.rb:62` (debug logging) | 18.0 / 18.0 | 100% | `no app frame` 100% | `modes = MODES.values_at(*options.compact_blank.keys)` |
| 4 | `RAILS/activesupport/lib/active_support/event_reporter.rb:460` (debug logging) | 16.5 / 16.5 | 100% | `no app frame` 100% | `caller_location = caller_locations(caller_depth, 1)&.first` |
| 5 | `RAILS/activerecord/lib/active_record/log_subscriber.rb:40` (debug logging) | 16.0 / 16.0 | 100% | `no app frame` 100% | `binds = binds.inspect` |
| 6 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` | 14.0 / 14.0 | 100% | `no app frame` 100% | `WhereClause.new(predicates \| other.predicates)` |
| 7 | `RAILS/activesupport/lib/active_support/colorize_logging.rb:58` (debug logging) | 9.0 / 9.0 | 100% | `no app frame` 100% | `"#{mode}#{color}#{text}#{clear}"` |
| 8 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:258` | 9.0 / 9.0 | 100% | `no app frame` 100% | `reject { \|_k, v\| v.blank? }` |
| 9 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:379` | 9.0 / 9.0 | 100% | `no app frame` 100% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 10 | `GEM/sqlite3/lib/sqlite3/statement.rb:54` | 7.5 / 7.5 | 100% | `no app frame` 100% | `bind_vars.flatten.each do \|var\|` |
