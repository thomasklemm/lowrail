# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails runner /home/user/.local/share/mise/installs/ruby/3.3.14/lib/ruby/gems/3.3.0/gems/lowrail-profile-0.1.0.rc1/lib/lowrail/profile_workloads.rb /home/user/workspace/repo/bench/upstream/profile_release/2026-11-25-fixes/rc-blog-floor-probes/w/probe.rb /home/user/workspace/repo/bench/upstream/profile_release/2026-11-25-fixes/rc-blog-floor-probes/w/probe-allow/workloads.json`
* Ruby: ruby 3.3.14 (2026-11-19 revision f4c37f481b) +YJIT [x86_64-linux]
* Rails: 7.2.4, development environment
* Counted in run 1: 40 requests; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 40 | 192045.9 | 0 | 0 | 0 | 0 |
| run2 | 1 | 40 | 192046.0 | 0 | 0 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.03 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/views/articles/_article.html.erb:14` |  | 3202.45 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 13%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 10%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:263` 4% | ArticlesController#index 100% | `<%= button_to "Destroy", article, method: :delete, class: "w-full sm:w` |
| 2 | `app/views/articles/index.html.erb:26` |  | 1122.45 | 597.55 | 0.0 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` 14%, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:102` 5%, `RAILS/activerecord/lib/active_record/associations/preloader/association.rb:172` 5% | ArticlesController#index 100% | `<%= render @articles %>` |
| 3 | `app/views/articles/_article.html.erb:4` |  | 688.27 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/integration.rb:59` 13%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 9%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 9% | ArticlesController#index 100% | `<%= link_to article.title, article, class: "text-blue-600 hover:underl` |
| 4 | `app/views/articles/_article.html.erb:12` |  | 658.35 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/integration.rb:59` 14%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 9%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 9% | ArticlesController#index 100% | `<%= link_to "Show", article, class: "w-full sm:w-auto text-center roun` |
| 5 | `app/views/articles/_article.html.erb:6` |  | 626.53 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:129` 24%, `RAILS/activerecord/lib/active_record/relation.rb:77` 10%, `RAILS/activerecord/lib/active_record/core.rb:420` 10% | ArticlesController#index 100% | `(<%= pluralize(article.comments.size, "comment") %>)` |
| 6 | `app/views/articles/_article.html.erb:13` |  | 538.65 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/integration.rb:59` 17%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 11%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 11% | ArticlesController#index 100% | `<%= link_to "Edit", edit_article_path(article), class: "w-full sm:w-au` |
| 7 | `app/views/articles/_article.html.erb:5` |  | 209.48 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/record_identifier.rb:80` 29%, `RAILS/actionview/lib/action_view/record_identifier.rb:115` 29%, `RAILS/actionview/lib/action_view/buffers.rb:48` 14% | ArticlesController#index 100% | `<span id="<%= dom_id(article, :comments_count) %>" class="text-gray-50` |
| 8 | `app/views/articles/_article.html.erb:1` |  | 149.63 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/record_identifier.rb:115` 40%, `RAILS/actionview/lib/action_view/record_identifier.rb:98` 20%, `RAILS/actionview/lib/action_view/buffers.rb:48` 20% | ArticlesController#index 100% | `<div id="<%= dom_id(article) %>" class="flex flex-col sm:flex-row just` |
| 9 | `app/views/articles/_article.html.erb:9` |  | 92.63 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` 32%, `RAILS/activemodel/lib/active_model/type/string.rb:35` 32%, `RAILS/activesupport/lib/active_support/core_ext/string/filters.rb:71` 31% | ArticlesController#index 100% | `<p class="text-gray-700 mt-2"><%= truncate(article.body, length: 100) ` |
| 10 | `app/views/articles/index.html.erb:15` |  | 77.02 | 0.0 | 0.45 | `RUBY/uri/common.rb:401` 27%, `GEM/json/lib/json/common.rb:298` 7%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:50` 5% | ArticlesController#index 100% | `<% if notice.present? %>` |
| 11 | `app/views/layouts/application.html.erb:17` |  | 48.93 | 218.5 | 1.8 | `RUBY/uri/rfc2396_parser.rb:292` 11%, `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/collection/map/non_concurrent_map_backend.rb:26` 9%, `RUBY/set.rb:244` 8% | ArticlesController#index 100% | `<%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>` |
| 12 | `app/views/layouts/application.html.erb:16` |  | 47.98 | 220.4 | 1.8 | `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/collection/map/non_concurrent_map_backend.rb:26` 8%, `RUBY/uri/rfc2396_parser.rb:321` 8%, `RUBY/uri/rfc2396_parser.rb:292` 5% | ArticlesController#index 100% | `<%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>` |
| 13 | `app/views/articles/index.html.erb:25` |  | 46.55 | 152.0 | 0.45 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 6%, `GEM/sqlite3/lib/sqlite3/statement.rb:76` 3%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:236` 3% | ArticlesController#index 100% | `<% if @articles.any? %>` |
| 14 | `app/views/layouts/application.html.erb:18` |  | 39.9 | 28.03 | 0.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 20%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 20%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` 15% | ArticlesController#index 100% | `<%= javascript_importmap_tags %>` |
| 15 | `app/views/layouts/application.html.erb:7` |  | 19.95 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 10%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 10%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` 7% | ArticlesController#index 100% | `<%= csrf_meta_tags %>` |
| 16 | `app/views/articles/index.html.erb:1` |  | 15.2 | 0.0 | 2.25 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:345` 16%, `GEM/turbo-rails/app/helpers/turbo/streams_helper.rb:61` 9%, `GEM/turbo-rails/app/channels/turbo/streams/stream_name.rb:26` 9% | ArticlesController#index 100% | `<%= turbo_stream_from "articles" %>` |
| 17 | `app/controllers/articles_controller.rb:6` | `index` | 14.72 | 0.0 | 1.35 | `RAILS/activerecord/lib/active_record/relation/query_methods.rb:2031` 16%, `RAILS/activerecord/lib/active_record/relation/query_methods.rb:2068` 10%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:129` 6% | ArticlesController#index 100% | `@articles = Article.includes(:comments).order(created_at: :desc)` |
| 18 | `app/views/articles/index.html.erb:21` |  | 7.6 | 0.0 | 1.8 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 13%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 13%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` 6% | ArticlesController#index 100% | `<%= link_to "New article", new_article_path, class: "rounded-md px-3.5` |
| 19 | `app/views/articles/index.html.erb:12` |  | 5.7 | 0.0 | 0.0 | `GEM/turbo-rails/app/helpers/turbo/drive_helper.rb:27` 25%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 17%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 17% | ArticlesController#index 100% | `<% turbo_exempts_page_from_cache %>` |
| 20 | `app/views/articles/index.html.erb:3` |  | 1.42 | 0.0 | 0.45 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:203` 33%, `RAILS/actionview/lib/action_view/helpers/capture_helper.rb:172` 33%, `RAILS/actionview/lib/action_view/flows.rb:10` 33% | ArticlesController#index 100% | `<% content_for :title, "Articles" %>` |
| 21 | `app/views/layouts/application.html.erb:10` |  | 1.42 | 0.0 | 0.45 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` 33%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` 33%, `RAILS/actionview/lib/action_view/renderer/template_renderer.rb:77` 33% | ArticlesController#index 100% | `<%= yield :head %>` |
| 22 | `app/views/layouts/application.html.erb:8` |  | 0.95 | 0.0 | 0.45 | `RAILS/actionpack/lib/action_controller/metal/content_security_policy.rb:13` 50%, `RAILS/actionview/lib/action_view/helpers/csp_helper.rb:18` 50% | ArticlesController#index 100% | `<%= csp_meta_tag %>` |
| 23 | `app/views/layouts/application.html.erb:23` |  | 0.95 | 0.0 | 0.45 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` 50%, `RAILS/actionview/lib/action_view/renderer/template_renderer.rb:77` 50% | ArticlesController#index 100% | `<%= yield %>` |
| 24 | `app/views/layouts/application.html.erb:4` |  | 0.48 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/helpers/capture_helper.rb:172` 100% | ArticlesController#index 100% | `<title><%= content_for(:title) \|\| "Rc Blog Floor" %></title>` |
| 25 | `app/views/articles/index.html.erb:33` |  | 0.0 | 0.0 | 0.45 |  |  | `` |
| 26 | `app/views/layouts/application.html.erb:1` |  | 0.0 | 0.0 | 0.9 |  |  | `<!DOCTYPE html>` |
| 27 | `app/views/layouts/application.html.erb:28` |  | 0.0 | 0.0 | 0.45 |  |  | `` |

4806.1 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | ArticlesController#create | 20 / 20 | 359318.1 / 359318.4 | 0.4 | 359318.0 | `RAILS/actionview/lib/action_view/buffers.rb:48` 2911.0, `RAILS/actionview/lib/action_view/buffers.rb:44` 1460.0, `RUBY/ipaddr.rb:692` 578.0 |  |
| 2 | ArticlesController#index | 20 / 20 | 22020.7 / 22020.6 | -0.2 | 22020.5 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 1293.0, `RAILS/activerecord/lib/active_record/integration.rb:59` 756.0, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 718.0 | `app/views/articles/_article.html.erb:14` 6742.0, `app/views/articles/index.html.erb:26` 2363.1, `app/views/articles/_article.html.erb:4` 1449.0 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `RAILS/actionview/lib/action_view/buffers.rb:48` | `<<` | 1545.28 / 1545.28 | 0.0 | 1550.0 | 100% | String |  | `no app frame` 94%, `app/views/articles/_article.html.erb:6` 2% | `CGI.escapeHTML(value)` |
| 2 | `RAILS/actionview/lib/action_view/buffers.rb:44` | `<<` | 693.5 / 693.5 | 0.0 | 730.0 | 50% | String |  | `no app frame` 100% | `value = value.to_s` |
| 3 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` | `tag_option` | 614.68 / 614.68 | 0.0 | 647.0 | 100% | String |  | `app/views/articles/_article.html.erb:14` 68%, `app/views/articles/_article.html.erb:12` 10% | `%(#{key}="#{value}")` |
| 4 | `RUBY/ipaddr.rb:692` | `in6_addr` | 563.55 / 563.55 | 0.0 | 578.03 | 100% | Data, Array |  | `no app frame` 100% | `raise InvalidAddressError, "invalid address: #{@addr}"` |
| 5 | `RAILS/activerecord/lib/active_record/integration.rb:59` | `to_param` | 359.1 / 359.1 | 0.0 | 378.0 | 50% | String, Array |  | `app/views/articles/_article.html.erb:14` 25%, `app/views/articles/_article.html.erb:4` 25% | `Array(id).join(self.class.param_delimiter)` |
| 6 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` | `xml_name_escape` | 341.55 / 341.55 | 0.0 | 359.5 | 100% | String |  | `app/views/articles/_article.html.erb:14` 96%, `app/views/layouts/application.html.erb:18` 2% | `name = name.to_s` |
| 7 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` | `html_safe` | 290.58 / 290.58 | 0.0 | 305.5 | 100% | String |  | `app/views/articles/_article.html.erb:14` 41%, `app/views/articles/index.html.erb:26` 10% | `ActiveSupport::SafeBuffer.new(self)` |
| 8 | `RAILS/activesupport/lib/active_support/core_ext/range/each.rb:9` | `each` | 273.6 / 273.6 | 0.0 | 288.0 | 50% | Array |  | `no app frame` 100% | `super` |
| 9 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` | `initialize` | 260.13 / 260.13 | 0.0 | 273.5 | 100% | String |  | `app/views/articles/_article.html.erb:14` 46%, `app/views/articles/index.html.erb:26` 12% | `super` |
| 10 | `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` | `evaluate` | 240.35 / 240.35 | 0.0 | 253.0 | 50% | Array |  | `app/views/articles/_article.html.erb:14` 25%, `app/views/articles/_article.html.erb:4` 25% | `parts = @parts.dup` |
| 11 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:263` | `tag_options` | 217.58 / 217.58 | 0.0 | 229.0 | 100% | String |  | `app/views/articles/_article.html.erb:14` 55%, `app/views/articles/_article.html.erb:13` 14% | `output = +""` |
| 12 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` | `each` | 157.23 / 157.23 | 0.0 | 165.5 | 50% | String, Array |  | `app/views/articles/index.html.erb:26` 100%, `app/views/articles/index.html.erb:25` 0% | `val = step` |
| 13 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:129` | `create` | 156.27 / 156.27 | 0.0 | 164.5 | 50% | Hash, Object |  | `app/views/articles/_article.html.erb:6` 96%, `app/views/articles/index.html.erb:26` 4% | `relation_class_for(klass).new(klass, *args, **kwargs)` |
| 14 | `RAILS/activesupport/lib/active_support/core_ext/hash/keys.rb:11` | `stringify_keys` | 154.43 / 154.43 | 0.0 | 162.5 | 100% | Hash |  | `app/views/articles/_article.html.erb:14` 39%, `app/views/articles/_article.html.erb:13` 19% | `transform_keys { \|k\| Symbol === k ? k.name : k.to_s }` |
| 15 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:258` | `content_tag_string` | 152.03 / 152.03 | 0.0 | 160.0 | 100% | String |  | `app/views/articles/_article.html.erb:14` 39%, `app/views/articles/_article.html.erb:4` 20% | `"<#{name}#{tag_options}>#{PRE_CONTENT_STRINGS[name]}#{content}</#{name` |
| 16 | `RAILS/actionpack/lib/action_controller/metal/request_forgery_protection.rb:314` | `handle_unverified_request` | 141.55 / 141.55 | 0.0 | 149.0 | 50% | Data, Array |  | `no app frame` 100% | `raise ActionController::InvalidAuthenticityToken, warning_message` |
| 17 | `RAILS/actionpack/lib/action_controller/metal/url_for.rb:49` | `url_options` | 120.18 / 120.18 | 0.0 | 126.5 | 50% | Hash |  | `app/views/articles/_article.html.erb:13` 25%, `app/views/articles/_article.html.erb:14` 25% | `options = @_url_options.dup` |
| 18 | `RAILS/actionpack/lib/action_dispatch/http/url.rb:73` | `path_for` | 120.18 / 120.18 | 0.0 | 126.5 | 50% | String |  | `app/views/articles/_article.html.erb:4` 25%, `app/views/articles/_article.html.erb:13` 25% | `path = options[:script_name].to_s.chomp("/")` |
| 19 | `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:51` | `evaluate` | 120.18 / 120.18 | 0.0 | 126.5 | 50% | String |  | `app/views/articles/_article.html.erb:14` 25%, `app/views/articles/_article.html.erb:12` 25% | `parts.join` |
| 20 | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:216` | `call` | 120.18 / 120.18 | 0.0 | 126.5 | 50% | Hash |  | `app/views/articles/_article.html.erb:4` 25%, `app/views/articles/_article.html.erb:13` 25% | `options = t.url_options.merge @options` |
| 21 | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:250` | `parameterize_args` | 120.18 / 120.18 | 0.0 | 126.5 | 50% | Hash |  | `app/views/articles/_article.html.erb:13` 25%, `app/views/articles/_article.html.erb:14` 25% | `params = {}` |
| 22 | `RAILS/actionpack/lib/action_dispatch/journey/router/utils.rb:71` | `escape` | 119.7 / 119.7 | 0.0 | 126.0 | 50% | String |  | `app/views/articles/_article.html.erb:4` 25%, `app/views/articles/_article.html.erb:12` 25% | `component.gsub(pattern) { \|unsafe\| percent_encode(unsafe) }.force_enco` |
| 23 | `RAILS/actionview/lib/action_view/helpers/url_helper.rb:752` | `token_tag` | 119.7 / 119.7 | 0.0 | 126.0 | 50% | Hash, Array |  | `app/views/articles/_article.html.erb:14` 100% | `form_authenticity_token(form_options: form_options.merge(authenticity_` |
| 24 | `RAILS/actionview/lib/action_view/record_identifier.rb:115` | `record_key_for_dom_id` | 119.7 / 119.7 | 0.0 | 126.0 | 50% | String |  | `app/views/articles/_article.html.erb:1` 50%, `app/views/articles/_article.html.erb:5` 50% | `key && key.all? ? key.join(JOIN) : nil` |
| 25 | `RUBY/uri/rfc3986_parser.rb:135` | `parse` | 119.7 / 119.7 | 0.0 | 126.0 | 50% | Array |  | `app/views/articles/_article.html.erb:14` 100% | `URI.for(*self.split(uri), self)` |
| 26 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:500` | `tag` | 92.6 / 92.63 | 0.03 | 97.49 | 50% | String | #59804 open upstream work | `app/views/articles/_article.html.erb:14` 97%, `app/views/layouts/application.html.erb:16` 1% | `"<#{name}#{tag_builder.tag_options(options, escape) if options}#{open ` |
| 27 | `RAILS/actionpack/lib/action_controller/metal/request_forgery_protection.rb:102` | `` | 90.25 / 90.25 | 0.0 | 95.0 | 50% | Array, Hash |  | `app/views/articles/_article.html.erb:14` 99%, `app/views/layouts/application.html.erb:7` 1% | `helper_method :form_authenticity_token` |
| 28 | `RAILS/actionpack/lib/action_controller/metal/request_forgery_protection.rb:577` | `per_form_csrf_token` | 89.78 / 89.78 | 0.0 | 94.5 | 50% | String, Array |  | `app/views/articles/_article.html.erb:14` 100% | `csrf_token_hmac(session, [action_path, method.downcase].join("#"))` |
| 29 | `RAILS/actionpack/lib/action_dispatch/routing/polymorphic_routes.rb:271` | `handle_model` | 89.78 / 89.78 | 0.0 | 94.5 | 50% | Array |  | `app/views/articles/_article.html.erb:4` 33%, `app/views/articles/_article.html.erb:12` 33% | `args  = []` |
| 30 | `RAILS/actionpack/lib/action_dispatch/routing/polymorphic_routes.rb:281` | `handle_model` | 89.78 / 89.78 | 0.0 | 94.5 | 50% | Array |  | `app/views/articles/_article.html.erb:4` 33%, `app/views/articles/_article.html.erb:14` 33% | `[named_route, args]` |

## Dev/test-mode work

172670.1 of 185205.8 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

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
| rails: activesupport | 113149.6 | 114319.0 | `backtrace_cleaner.rb:124` 90904.1, `backtrace_cleaner.rb:141` 19094.1, `backtrace_cleaner.rb:149` 746.7 |
| ruby stdlib | 57745.6 | 60762.8 | `base.rb:57` 55125.2, `ipaddr.rb:692` 563.6, `base.rb:248` 374.0 |
| rails: actionview | 5461.5 | 5667.5 | `buffers.rb:48` 1545.3, `buffers.rb:44` 693.5, `tag_helper.rb:324` 614.7 |
| rails: actionpack | 5440.7 | 5722.8 | `exception_wrapper.rb:332` 1960.8, `exception_wrapper.rb:333` 322.5, `visitors.rb:40` 240.4 |
| rails: activerecord | 1692.2 | 1781.0 | `integration.rb:59` 359.1, `delegation.rb:129` 156.3, `log_subscriber.rb:49` 92.2 |
| app | 582.8 | 613.5 | `_article.html.erb:14` 149.6, `_article.html.erb:13` 119.7, `_article.html.erb:12` 89.8 |
| gem: sprockets | 426.5 | 449.0 | `path_utils.rb:166` 21.9, `http_utils.rb:18` 20.0, `http_utils.rb:17` 20.0 |
| gem: erubi | 361.5 | 380.5 | `erubi.rb:134` 201.4, `erubi.rb:137` 45.1, `erubi.rb:139` 24.2 |
| rails: activemodel | 185.7 | 195.5 | `string.rb:35` 59.9, `builder.rb:28` 31.4, `builder.rb:16` 31.4 |
| gem: sqlite3 | 165.3 | 174.0 | `statement.rb:159` 157.2, `statement.rb:76` 4.3, `statement.rb:217` 1.0 |
| ruby default gem: base64 | 130.3 | 137.0 | `base64.rb:283` 65.6, `base64.rb:310` 34.3, `base64.rb:374` 30.4 |
| gem: useragent | 100.7 | 106.0 | `base.rb:120` 37.1, `version.rb:27` 19.0, `user_agent.rb:25` 5.7 |
| gem: rack | 48.6 | 50.5 | `utils.rb:331` 3.9, `body_proxy.rb:12` 3.9, `request.rb:607` 3.4 |
| gem: concurrent-ruby | 44.3 | 45.5 | `non_concurrent_map_backend.rb:131` 10.0, `non_concurrent_map_backend.rb:120` 8.9, `mri_map_backend.rb:14` 8.9 |
| ruby default gem: logger | 42.5 | 44.0 | `logger.rb:692` 10.6, `log_device.rb:165` 10.6, `log_device.rb:33` 10.6 |
| ruby default gem: securerandom | 31.4 | 33.0 | `securerandom.rb:71` 31.4 |
| ruby default gem: prettyprint | 28.5 | 30.0 | `prettyprint.rb:404` 7.6, `prettyprint.rb:264` 7.1, `prettyprint.rb:459` 4.8 |
| gem: importmap-rails | 28.0 | 29.5 | `importmap_tags_helper.rb:44` 10.0, `importmap_tags_helper.rb:30` 6.7, `importmap_tags_helper.rb:42` 4.3 |
| gem: web-console | 26.8 | 27.5 | `permissions.rb:39` 13.7, `permissions.rb:21` 3.9, `request.rb:32` 2.0 |
| gem: nokogiri | 18.0 | 19.0 | `document.rb:416` 2.9, `node.rb:66` 2.8, `document_fragment.rb:169` 1.9 |
| rails: railties | 17.9 | 18.5 | `backtrace_cleaner.rb:21` 4.3, `finisher.rb:195` 2.9, `logger.rb:57` 2.9 |
| ruby default gem: pp | 16.6 | 17.5 | `pp.rb:542` 5.7, `pp.rb:277` 2.9, `pp.rb:271` 2.9 |
| gem: json | 12.7 | 13.0 | `common.rb:298` 10.8, `common.rb:378` 1.0, `common.rb:775` 0.5 |
| gem: sprockets-rails | 12.3 | 13.0 | `helper.rb:81` 1.9, `helper.rb:357` 1.9, `helper.rb:186` 1.9 |
| gem: turbo-rails | 7.1 | 7.5 | `stream_name.rb:26` 1.4, `streams_helper.rb:61` 1.4, `drive_helper.rb:27` 1.4 |
| gem: loofah | 4.8 | 5.0 | `concerns.rb:172` 1.9, `concerns.rb:43` 1.0, `concerns.rb:127` 0.5 |
| gem: rails-html-sanitizer | 4.3 | 4.5 | `sanitizer.rb:165` 1.4, `scrubbers.rb:55` 0.5, `scrubbers.rb:59` 0.5 |
| gem: rack-session | 1.4 | 1.5 | `id.rb:275` 0.5, `id.rb:401` 0.5, `id.rb:277` 0.5 |
| gem: i18n | 1.0 | 1.0 | `simple.rb:51` 1.0 |
