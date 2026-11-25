# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails runner /home/user/.local/share/mise/installs/ruby/3.3.14/lib/ruby/gems/3.3.0/gems/lowrail-profile-0.1.0.rc1/lib/lowrail/profile_workloads.rb /home/user/workspace/repo/bench/upstream/profile_release/2026-11-25-confirm-opus/rc-blog-floor-probes/w/probe.rb /home/user/workspace/repo/bench/upstream/profile_release/2026-11-25-confirm-opus/rc-blog-floor-probes/w/probe-allow/workloads.json`
* Ruby: ruby 3.3.14 (2026-11-19 revision f4c37f481b) +YJIT [x86_64-linux]
* Rails: 7.2.4, development environment
* Counted in run 1: 40 requests; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 40 | 183700.0 | 0 | 0 | 0 | 0 |
| run2 | 1 | 40 | 183702.4 | 0 | 0 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 1.27 objects per request; 2 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/views/articles/index.html.erb:26` |  | 295.48 | 426.1 | 0.0 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` 5%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 2%, `RAILS/activerecord/lib/active_record/core.rb:420` 2% | ArticlesController#index 100% | `<%= render @articles %>` |
| 2 | `app/views/articles/_article.html.erb:14` |  | 152.95 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 13%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 10%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:263` 4% | ArticlesController#index 100% | `<%= button_to "Destroy", article, method: :delete, class: "w-full sm:w` |
| 3 | `app/views/articles/index.html.erb:15` |  | 75.98 | 0.0 | 0.45 | `RUBY/uri/common.rb:401` 26%, `GEM/json/lib/json/common.rb:298` 7%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:50` 5% | ArticlesController#index 100% | `<% if notice.present? %>` |
| 4 | `app/views/layouts/application.html.erb:17` |  | 48.93 | 218.5 | 1.8 | `RUBY/uri/rfc2396_parser.rb:292` 11%, `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/collection/map/non_concurrent_map_backend.rb:26` 9%, `RUBY/set.rb:244` 8% | ArticlesController#index 100% | `<%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>` |
| 5 | `app/views/layouts/application.html.erb:16` |  | 47.98 | 220.4 | 1.8 | `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/collection/map/non_concurrent_map_backend.rb:26` 8%, `RUBY/uri/rfc2396_parser.rb:321` 8%, `RUBY/uri/rfc2396_parser.rb:292` 5% | ArticlesController#index 100% | `<%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>` |
| 6 | `app/views/articles/index.html.erb:25` |  | 46.55 | 152.0 | 0.45 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 6%, `GEM/sqlite3/lib/sqlite3/statement.rb:76` 3%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:236` 3% | ArticlesController#index 100% | `<% if @articles.any? %>` |
| 7 | `app/views/layouts/application.html.erb:18` |  | 39.9 | 28.03 | 0.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 20%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 20%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` 15% | ArticlesController#index 100% | `<%= javascript_importmap_tags %>` |
| 8 | `app/views/articles/_article.html.erb:4` |  | 32.78 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/integration.rb:59` 13%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 9%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 9% | ArticlesController#index 100% | `<%= link_to article.title, article, class: "text-blue-600 hover:underl` |
| 9 | `app/views/articles/_article.html.erb:12` |  | 31.35 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/integration.rb:59` 14%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 9%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 9% | ArticlesController#index 100% | `<%= link_to "Show", article, class: "w-full sm:w-auto text-center roun` |
| 10 | `app/views/articles/_article.html.erb:6` |  | 28.03 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:129` 25%, `RAILS/activerecord/lib/active_record/relation.rb:77` 10%, `RAILS/activerecord/lib/active_record/core.rb:420` 10% | ArticlesController#index 100% | `(<%= pluralize(article.comments.size, "comment") %>)` |
| 11 | `app/views/articles/_article.html.erb:13` |  | 25.65 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/integration.rb:59` 17%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 11%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 11% | ArticlesController#index 100% | `<%= link_to "Edit", edit_article_path(article), class: "w-full sm:w-au` |
| 12 | `app/views/layouts/application.html.erb:7` |  | 19.95 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 10%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 10%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` 7% | ArticlesController#index 100% | `<%= csrf_meta_tags %>` |
| 13 | `app/views/articles/index.html.erb:1` |  | 15.2 | 0.0 | 2.25 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:345` 16%, `GEM/turbo-rails/app/helpers/turbo/streams_helper.rb:61` 9%, `GEM/turbo-rails/app/channels/turbo/streams/stream_name.rb:26` 9% | ArticlesController#index 100% | `<%= turbo_stream_from "articles" %>` |
| 14 | `app/controllers/articles_controller.rb:6` | `index` | 14.72 | 0.0 | 1.35 | `RAILS/activerecord/lib/active_record/relation/query_methods.rb:2031` 16%, `RAILS/activerecord/lib/active_record/relation/query_methods.rb:2068` 10%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:129` 6% | ArticlesController#index 100% | `@articles = Article.includes(:comments).order(created_at: :desc)` |
| 15 | `app/views/articles/_article.html.erb:5` |  | 9.98 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/record_identifier.rb:80` 29%, `RAILS/actionview/lib/action_view/record_identifier.rb:115` 29%, `RAILS/actionview/lib/action_view/buffers.rb:48` 14% | ArticlesController#index 100% | `<span id="<%= dom_id(article, :comments_count) %>" class="text-gray-50` |
| 16 | `app/views/articles/index.html.erb:21` |  | 7.6 | 0.0 | 1.8 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 13%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 13%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` 6% | ArticlesController#index 100% | `<%= link_to "New article", new_article_path, class: "rounded-md px-3.5` |
| 17 | `app/views/articles/_article.html.erb:1` |  | 7.13 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/record_identifier.rb:115` 40%, `RAILS/actionview/lib/action_view/record_identifier.rb:98` 20%, `RAILS/actionview/lib/action_view/buffers.rb:48` 20% | ArticlesController#index 100% | `<div id="<%= dom_id(article) %>" class="flex flex-col sm:flex-row just` |
| 18 | `app/views/articles/_article.html.erb:9` |  | 7.13 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/string/filters.rb:82` 40%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` 20%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` 20% | ArticlesController#index 100% | `<p class="text-gray-700 mt-2"><%= truncate(article.body, length: 100) ` |
| 19 | `app/views/articles/index.html.erb:12` |  | 5.7 | 0.0 | 0.0 | `GEM/turbo-rails/app/helpers/turbo/drive_helper.rb:27` 25%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 17%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 17% | ArticlesController#index 100% | `<% turbo_exempts_page_from_cache %>` |
| 20 | `app/views/articles/index.html.erb:3` |  | 1.42 | 0.0 | 0.45 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:203` 33%, `RAILS/actionview/lib/action_view/helpers/capture_helper.rb:172` 33%, `RAILS/actionview/lib/action_view/flows.rb:10` 33% | ArticlesController#index 100% | `<% content_for :title, "Articles" %>` |
| 21 | `app/views/layouts/application.html.erb:10` |  | 1.42 | 0.0 | 0.45 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` 33%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` 33%, `RAILS/actionview/lib/action_view/renderer/template_renderer.rb:77` 33% | ArticlesController#index 100% | `<%= yield :head %>` |
| 22 | `app/views/layouts/application.html.erb:8` |  | 0.95 | 0.0 | 0.45 | `RAILS/actionpack/lib/action_controller/metal/content_security_policy.rb:13` 50%, `RAILS/actionview/lib/action_view/helpers/csp_helper.rb:18` 50% | ArticlesController#index 100% | `<%= csp_meta_tag %>` |
| 23 | `app/views/layouts/application.html.erb:23` |  | 0.95 | 0.0 | 0.45 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` 50%, `RAILS/actionview/lib/action_view/renderer/template_renderer.rb:77` 50% | ArticlesController#index 100% | `<%= yield %>` |
| 24 | `app/views/layouts/application.html.erb:4` |  | 0.48 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/helpers/capture_helper.rb:172` 100% | ArticlesController#index 100% | `<title><%= content_for(:title) \|\| "Rc Blog Floor" %></title>` |
| 25 | `app/views/articles/index.html.erb:33` |  | 0.0 | 0.0 | 0.45 |  |  | `` |
| 26 | `app/views/layouts/application.html.erb:1` |  | 0.0 | 0.0 | 0.9 |  |  | `<!DOCTYPE html>` |
| 27 | `app/views/layouts/application.html.erb:28` |  | 0.0 | 0.0 | 0.45 |  |  | `` |

4805.15 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | ArticlesController#create | 20 / 20 | 359315.4 / 359318.7 | 3.3 | 359317.7 | `RAILS/actionview/lib/action_view/buffers.rb:48` 2911.0, `RAILS/actionview/lib/action_view/buffers.rb:44` 1460.0, `RUBY/ipaddr.rb:692` 578.0 |  |
| 2 | ArticlesController#index | 20 / 20 | 6411.0 / 6414.5 | 3.5 | 6413.6 | `RUBY/ipaddr.rb:692` 578.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 93.0, `GEM/useragent/lib/user_agent/browsers/base.rb:120` 78.0 | `app/views/articles/index.html.erb:26` 622.1, `app/views/articles/_article.html.erb:14` 322.0, `app/views/articles/index.html.erb:15` 159.9 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `RAILS/actionview/lib/action_view/buffers.rb:48` | `<<` | 1459.78 / 1459.78 | 0.0 | 1460.0 | 100% | String |  | `no app frame` 100%, `app/views/articles/_article.html.erb:6` 0% | `CGI.escapeHTML(value)` |
| 2 | `RAILS/actionview/lib/action_view/buffers.rb:44` | `<<` | 693.5 / 693.5 | 0.0 | 730.0 | 50% | String |  | `no app frame` 100% | `value = value.to_s` |
| 3 | `RUBY/ipaddr.rb:692` | `in6_addr` | 563.55 / 563.55 | 0.0 | 578.03 | 100% | Data, Array |  | `no app frame` 100% | `raise InvalidAddressError, "invalid address: #{@addr}"` |
| 4 | `RAILS/activesupport/lib/active_support/core_ext/range/each.rb:9` | `each` | 273.6 / 273.6 | 0.0 | 288.0 | 50% | Array |  | `no app frame` 100% | `super` |
| 5 | `RAILS/actionpack/lib/action_controller/metal/request_forgery_protection.rb:314` | `handle_unverified_request` | 141.55 / 141.55 | 0.0 | 149.0 | 50% | Data, Array |  | `no app frame` 100% | `raise ActionController::InvalidAuthenticityToken, warning_message` |
| 6 | `RUBY/uri/common.rb:401` | `_decode_uri_component` | 59.88 / 61.15 | 1.27 | 61.55 | 100% | String, MatchData |  | `no app frame` 67%, `app/views/articles/index.html.erb:15` 33% | `str.b.gsub(regexp, TBLDECWWWCOMP_).force_encoding(enc)` |
| 7 | `RUBY/ipaddr.rb:193` | `to_s` | 52.65 / 52.65 | 0.0 | 54.0 | 100% | String, MatchData |  | `no app frame` 100% | `str.gsub!(/\b0{1,3}([\da-f]+)\b/i, '\1')` |
| 8 | `RUBY/ipaddr.rb:736` | `_to_string` | 50.7 / 50.7 | 0.0 | 52.0 | 100% | String, MatchData |  | `no app frame` 100% | `return (("%.32x" % addr).gsub!(/.{4}(?!$)/, '\&:'))` |
| 9 | `RAILS/actionpack/lib/action_controller/metal/rescue.rb:30` | `process_action` | 47.03 / 47.03 | 0.0 | 49.5 | 50% | String, Array |  | `no app frame` 100% | `rescue_with_handler(exception) \|\| raise` |
| 10 | `RAILS/activesupport/lib/active_support/core_ext/thread/backtrace/location.rb:6` | `spot` | 46.55 / 46.55 | 0.0 | 49.0 | 50% | Hash |  | `no app frame` 100% | `ErrorHighlight.spot(ex, backtrace_location: self)` |
| 11 | `RAILS/actionpack/lib/action_dispatch/middleware/templates/rescues/_source.html.erb:22` | `` | 46.08 / 46.08 | 0.0 | 48.5 | 50% | String |  | `no app frame` 100% | `<div class="line<%= " active" if line == source_extract[:line_number] ` |
| 12 | `RAILS/actionpack/lib/action_dispatch/middleware/templates/rescues/_source.html.erb:5` | `` | 45.6 / 45.6 | 0.0 | 48.0 | 50% | String |  | `no app frame` 100% | `<div class="source <%= "hidden" if show_source_idx != index %>" id="fr` |
| 13 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` | `tag_option` | 44.68 / 44.68 | 0.0 | 47.0 | 100% | String |  | `app/views/articles/_article.html.erb:14` 45%, `app/views/layouts/application.html.erb:18` 18% | `%(#{key}="#{value}")` |
| 14 | `RAILS/actionview/lib/action_view/template/resolver.rb:18` | `build_path_regex` | 38.0 / 38.0 | 0.0 | 40.0 | 50% | String, Array |  | `no app frame` 100% | `formats = Regexp.union(Template::Types.symbols.map(&:to_s))` |
| 15 | `GEM/useragent/lib/user_agent/browsers/base.rb:120` | `detect_product` | 37.05 / 37.05 | 0.0 | 39.0 | 50% | String |  | `no app frame` 100% | `detect { \|useragent\| useragent.product.to_s.downcase == product.to_s.d` |
| 16 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | `#{method}` | 36.38 / 36.38 | 0.0 | 37.5 | 100% | Array, Hash |  | `no app frame` 72%, `app/views/articles/index.html.erb:26` 20% | `dispatch(:#{method}, ...)` |
| 17 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` | `html_safe` | 34.08 / 34.08 | 0.0 | 35.5 | 100% | String |  | `no app frame` 23%, `app/views/layouts/application.html.erb:18` 18% | `ActiveSupport::SafeBuffer.new(self)` |
| 18 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` | `initialize` | 32.13 / 32.13 | 0.0 | 33.5 | 100% | String |  | `no app frame` 21%, `app/views/articles/_article.html.erb:14` 18% | `super` |
| 19 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` | `xml_name_escape` | 28.05 / 28.05 | 0.0 | 29.5 | 100% | String |  | `app/views/articles/_article.html.erb:14` 56%, `app/views/layouts/application.html.erb:18` 29% | `name = name.to_s` |
| 20 | `RAILS/actionview/lib/action_view/template/sources/file.rb:12` | `to_s` | 27.08 / 27.08 | 0.0 | 28.5 | 50% | String, File |  | `no app frame` 100% | `::File.binread @filename` |
| 21 | `RUBY/uri/common.rb:394` | `_encode_uri_component` | 18.83 / 20.1 | 1.27 | 20.25 | 50% | String, MatchData |  | `no app frame` 100% | `str.gsub!(regexp, table)` |
| 22 | `GEM/useragent/lib/user_agent/version.rb:27` | `initialize` | 19.0 / 19.0 | 0.0 | 20.0 | 50% | String, MatchData |  | `no app frame` 100% | `@sequences  = str.scan(/\d+\|[A-Za-z][0-9A-Za-z-]*$/).map { \|s\| s =~ /^` |
| 23 | `RAILS/actionpack/lib/action_dispatch/middleware/templates/rescues/_trace.html.erb:10` | `` | 18.53 / 18.53 | 0.0 | 19.5 | 50% | String, MatchData |  | `no app frame` 100% | `hide = (names - [name]).collect {\|hide_name\| "hide('#{hide_name.gsub(/` |
| 24 | `RAILS/activesupport/lib/active_support/core_ext/string/access.rb:47` | `from` | 18.4 / 18.4 | 0.0 | 18.5 | 100% | String |  | `no app frame` 89%, `app/views/articles/index.html.erb:26` 8% | `self[position, length]` |
| 25 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:263` | `tag_options` | 18.08 / 18.08 | 0.0 | 19.0 | 100% | String |  | `app/views/articles/_article.html.erb:14` 32%, `app/views/layouts/application.html.erb:18` 24% | `output = +""` |
| 26 | `RAILS/actionview/lib/action_view/template/resolver.rb:156` | `build_unbound_template` | 17.1 / 17.1 | 0.0 | 18.0 | 50% | Hash, Object |  | `no app frame` 100% | `UnboundTemplate.new(` |
| 27 | `RAILS/actionview/lib/action_view/unbound_template.rb:16` | `initialize` | 17.1 / 17.1 | 0.0 | 18.0 | 50% | Hash, Object |  | `no app frame` 100% | `@templates = Concurrent::Map.new(initial_capacity: 2)` |
| 28 | `RAILS/actionview/lib/action_view/unbound_template.rb:50` | `build_template` | 17.1 / 17.1 | 0.0 | 18.0 | 50% | Hash, Object |  | `no app frame` 100% | `Template.new(` |
| 29 | `RAILS/activerecord/lib/active_record/integration.rb:59` | `to_param` | 17.1 / 17.1 | 0.0 | 18.0 | 50% | String, Array |  | `app/views/articles/_article.html.erb:14` 25%, `app/views/articles/_article.html.erb:4` 25% | `Array(id).join(self.class.param_delimiter)` |
| 30 | `RUBY/pathname.rb:419` | `join` | 16.15 / 16.15 | 0.0 | 17.0 | 50% | Object, String |  | `no app frame` 100% | `result = Pathname.new(result) unless Pathname === result` |

## Dev/test-mode work

172498.1 of 178332.8 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | error page | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:124` | 90904.1 | 100% | `no app frame` 100%, `app/views/articles/index.html.erb:26` 0% | `add_filter { \|line\| line.sub(gems_regexp, gems_result) }` |
| 2 | error page | `RUBY/error_highlight/base.rb:57` † | 55125.17 | 50% | `no app frame` 100% | `node = RubyVM::AbstractSyntaxTree.of(loc, keep_script_lines: true)` |
| 3 | error page | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:141` | 19094.05 | 50% | `no app frame` 100% | `backtrace = backtrace.map { \|line\| f.call(line.to_s) }` |
| 4 | error page | `RAILS/actionpack/lib/action_dispatch/middleware/exception_wrapper.rb:332` | 1960.8 | 50% | `no app frame` 100% | `lines = source_lines.drop(start).take(6)` |
| 5 | error page | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:149` | 746.7 | 50% | `no app frame` 100% | `backtrace = backtrace.reject { \|line\| s.call(line.to_s) }` |
| 6 | template compile | `RAILS/actionview/lib/action_view/template.rb:503` | 473.6 | 50% | `no app frame` 100% | `mod.module_eval(compiled_source, identifier, offset)` |
| 7 | error page | `RUBY/error_highlight/base.rb:248` | 374.15 | 50% | `no app frame` 100% | `elsif lines.match(/\G[\s)]*?(\&?\.)(\s*?)(#{ Regexp.quote(mid) }).*\n/` |
| 8 | error page | `RAILS/actionpack/lib/action_dispatch/middleware/exception_wrapper.rb:333` | 322.53 | 50% | `no app frame` 100% | `Hash[*(start + 1..(lines.count + start)).zip(lines).flatten]` |
| 9 | reload check | `RAILS/activesupport/lib/active_support/file_update_checker.rb:132` | 260.23 | 100% | `no app frame` 100% | `mtime = File.mtime(path)` |
| 10 | template compile | `GEM/erubi/lib/erubi.rb:134` | 201.4 | 50% | `no app frame` 100% | `input.scan(regexp) do \|indicator, code, tailch, rspace\|` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activesupport | 112066.6 | 113179.0 | `backtrace_cleaner.rb:124` 90904.1, `backtrace_cleaner.rb:141` 19094.1, `backtrace_cleaner.rb:149` 746.7 |
| ruby stdlib | 57315.9 | 60310.5 | `base.rb:57` 55125.2, `ipaddr.rb:692` 563.6, `base.rb:248` 374.0 |
| rails: actionpack | 3787.0 | 3982.0 | `exception_wrapper.rb:332` 1960.8, `exception_wrapper.rb:333` 322.5, `exception_wrapper.rb:136` 186.7 |
| rails: actionview | 3523.0 | 3627.1 | `buffers.rb:48` 1459.8, `buffers.rb:44` 693.5, `template.rb:503` 473.6 |
| gem: sprockets | 425.8 | 448.3 | `path_utils.rb:166` 21.9, `http_utils.rb:18` 20.0, `http_utils.rb:17` 20.0 |
| rails: activerecord | 380.7 | 400.5 | `log_subscriber.rb:131` 74.1, `integration.rb:59` 17.1, `delegation.rb:129` 13.8 |
| gem: erubi | 361.5 | 380.5 | `erubi.rb:134` 201.4, `erubi.rb:137` 45.1, `erubi.rb:139` 24.2 |
| gem: useragent | 100.7 | 106.0 | `base.rb:120` 37.1, `version.rb:27` 19.0, `user_agent.rb:25` 5.7 |
| gem: rack | 48.6 | 50.5 | `utils.rb:331` 3.9, `body_proxy.rb:12` 3.9, `request.rb:607` 3.4 |
| gem: concurrent-ruby | 44.3 | 45.5 | `non_concurrent_map_backend.rb:131` 10.0, `non_concurrent_map_backend.rb:120` 8.9, `mri_map_backend.rb:14` 8.9 |
| ruby default gem: logger | 42.5 | 44.0 | `logger.rb:692` 10.6, `log_device.rb:165` 10.6, `log_device.rb:33` 10.6 |
| app | 41.3 | 43.5 | `_article.html.erb:14` 7.1, `_article.html.erb:13` 5.7, `_article.html.erb:12` 4.3 |
| ruby default gem: prettyprint | 28.5 | 30.0 | `prettyprint.rb:404` 7.6, `prettyprint.rb:264` 7.1, `prettyprint.rb:459` 4.8 |
| gem: importmap-rails | 28.0 | 29.5 | `importmap_tags_helper.rb:44` 10.0, `importmap_tags_helper.rb:30` 6.7, `importmap_tags_helper.rb:42` 4.3 |
| gem: web-console | 26.8 | 27.5 | `permissions.rb:39` 13.7, `permissions.rb:21` 3.9, `request.rb:32` 2.0 |
| gem: sqlite3 | 22.8 | 24.0 | `statement.rb:159` 14.7, `statement.rb:76` 4.3, `statement.rb:217` 1.0 |
| gem: nokogiri | 18.1 | 19.0 | `document.rb:416` 2.9, `node.rb:66` 2.8, `node.rb:1431` 1.9 |
| rails: railties | 17.9 | 18.5 | `backtrace_cleaner.rb:21` 4.3, `finisher.rb:195` 2.9, `logger.rb:57` 2.9 |
| ruby default gem: pp | 16.6 | 17.5 | `pp.rb:542` 5.7, `pp.rb:277` 2.9, `pp.rb:271` 2.9 |
| ruby default gem: base64 | 16.3 | 17.0 | `base64.rb:283` 8.6, `base64.rb:310` 5.8, `base64.rb:374` 1.9 |
| rails: activemodel | 14.7 | 15.5 | `builder.rb:28` 2.9, `string.rb:35` 2.9, `builder.rb:16` 2.9 |
| gem: json | 12.7 | 13.1 | `common.rb:298` 10.8, `common.rb:378` 1.0, `common.rb:775` 0.5 |
| gem: sprockets-rails | 12.3 | 13.0 | `helper.rb:81` 1.9, `helper.rb:357` 1.9, `helper.rb:186` 1.9 |
| gem: turbo-rails | 7.1 | 7.5 | `stream_name.rb:26` 1.4, `streams_helper.rb:61` 1.4, `drive_helper.rb:27` 1.4 |
| gem: loofah | 4.8 | 5.0 | `concerns.rb:172` 1.9, `concerns.rb:43` 1.0, `concerns.rb:127` 0.5 |
| gem: rails-html-sanitizer | 4.3 | 4.5 | `sanitizer.rb:165` 1.4, `sanitizer.rb:33` 0.5, `sanitizer.rb:192` 0.5 |
| ruby default gem: securerandom | 2.9 | 3.0 | `securerandom.rb:71` 2.9 |
| gem: rack-session | 1.4 | 1.5 | `id.rb:275` 0.5, `id.rb:401` 0.5, `id.rb:277` 0.5 |
| gem: i18n | 1.0 | 1.0 | `simple.rb:51` 1.0 |
