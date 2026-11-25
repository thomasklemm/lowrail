# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails runner /home/user/.local/share/mise/installs/ruby/3.3.14/lib/ruby/gems/3.3.0/gems/lowrail-profile-0.1.0.rc1/lib/lowrail/profile_workloads.rb /home/user/workspace/repo/bench/upstream/profile_release/2026-11-25-confirm-opus/rc-blog-floor-probes/w/post.rb /home/user/workspace/repo/bench/upstream/profile_release/2026-11-25-confirm-opus/rc-blog-floor-probes/w/post-allow/workloads.json`
* Ruby: ruby 3.3.14 (2026-11-19 revision f4c37f481b) +YJIT [x86_64-linux]
* Rails: 7.2.4, development environment
* Counted in run 1: 40 requests, 21 jobs; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 40 | 8849.5 | 21 | 0 | 0 | 0 |
| run2 | 1 | 40 | 13021.9 | 21 | 0 | 0 | 0 |

run1 left windows unfinished (1 job), which no line or action counts; compare refuses it.

run2 left windows unfinished (1 job), which no line or action counts; compare refuses it.

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 57.0, max |Δ| 285.0 objects per request; 27 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/views/articles/_article.html.erb:14` |  | 2694.2 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 13%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 10%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:263` 4% | ArticlesController#index 100% | `<%= button_to "Destroy", article, method: :delete, class: "w-full sm:w` |
| 2 | `app/views/articles/index.html.erb:26` |  | 985.03 | 569.05 | 0.0 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` 14%, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:102` 5%, `RAILS/activerecord/lib/active_record/associations/preloader/association.rb:172` 5% | ArticlesController#index 100% | `<%= render @articles %>` |
| 3 | `app/views/articles/_article.html.erb:4` |  | 579.03 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/integration.rb:59` 13%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 9%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 9% | ArticlesController#index 100% | `<%= link_to article.title, article, class: "text-blue-600 hover:underl` |
| 4 | `app/views/articles/_article.html.erb:12` |  | 553.85 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/integration.rb:59` 14%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 9%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 9% | ArticlesController#index 100% | `<%= link_to "Show", article, class: "w-full sm:w-auto text-center roun` |
| 5 | `app/views/articles/_article.html.erb:6` |  | 526.78 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:129` 24%, `RAILS/activerecord/lib/active_record/relation.rb:77` 10%, `RAILS/activerecord/lib/active_record/core.rb:420` 10% | ArticlesController#index 100% | `(<%= pluralize(article.comments.size, "comment") %>)` |
| 6 | `app/views/articles/_article.html.erb:13` |  | 453.15 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/integration.rb:59` 17%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 11%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 11% | ArticlesController#index 100% | `<%= link_to "Edit", edit_article_path(article), class: "w-full sm:w-au` |
| 7 | `app/controllers/articles_controller.rb:27` | `create` | 267.22 | 919.13 | 0.45 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 5%, `RUBY/random/formatter.rb:174` 2%, `RAILS/activejob/lib/active_job/arguments.rb:92` 2% | ArticlesController#create 100% | `if @article.save` |
| 8 | `app/views/articles/_article.html.erb:5` |  | 176.23 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/record_identifier.rb:80` 29%, `RAILS/actionview/lib/action_view/record_identifier.rb:115` 29%, `RAILS/actionview/lib/action_view/buffers.rb:48` 14% | ArticlesController#index 100% | `<span id="<%= dom_id(article, :comments_count) %>" class="text-gray-50` |
| 9 | `app/views/articles/_article.html.erb:1` |  | 125.88 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/record_identifier.rb:115` 40%, `RAILS/actionview/lib/action_view/record_identifier.rb:98` 20%, `RAILS/actionview/lib/action_view/buffers.rb:48` 20% | ArticlesController#index 100% | `<div id="<%= dom_id(article) %>" class="flex flex-col sm:flex-row just` |
| 10 | `app/views/articles/index.html.erb:15` |  | 86.8 | 0.0 | 0.43 | `RUBY/uri/common.rb:401` 33%, `GEM/json/lib/json/common.rb:298` 8%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:50` 4% | ArticlesController#index 100% | `<% if notice.present? %>` |
| 11 | `app/views/articles/_article.html.erb:9` |  | 78.38 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` 32%, `RAILS/activemodel/lib/active_model/type/string.rb:35` 32%, `RAILS/activesupport/lib/active_support/core_ext/string/filters.rb:71` 30% | ArticlesController#index 100% | `<p class="text-gray-700 mt-2"><%= truncate(article.body, length: 100) ` |
| 12 | `app/views/articles/index.html.erb:25` |  | 46.55 | 152.0 | 0.43 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 6%, `GEM/sqlite3/lib/sqlite3/statement.rb:76` 3%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:236` 3% | ArticlesController#index 100% | `<% if @articles.any? %>` |
| 13 | `app/views/layouts/application.html.erb:16` |  | 46.38 | 220.2 | 1.7 | `RUBY/uri/rfc2396_parser.rb:321` 8%, `RUBY/uri/rfc2396_parser.rb:292` 5%, `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/collection/map/non_concurrent_map_backend.rb:120` 5% | ArticlesController#index 100% | `<%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>` |
| 14 | `app/views/layouts/application.html.erb:17` |  | 46.13 | 218.1 | 1.7 | `RUBY/uri/rfc2396_parser.rb:292` 11%, `RUBY/set.rb:244` 8%, `RUBY/uri/rfc3986_parser.rb:85` 6% | ArticlesController#index 100% | `<%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>` |
| 15 | `app/controllers/articles_controller.rb:28` | `create` | 44.65 | 3.8 | 1.8 | `RUBY/uri/rfc3986_parser.rb:135` 9%, `RUBY/uri/rfc3986_parser.rb:85` 4%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 3% | ArticlesController#create 100% | `format.html { redirect_to @article, notice: "Article was successfully ` |
| 16 | `app/views/layouts/application.html.erb:18` |  | 39.9 | 28.03 | 0.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 20%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 20%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` 15% | ArticlesController#index 100% | `<%= javascript_importmap_tags %>` |
| 17 | `app/views/layouts/application.html.erb:7` |  | 19.95 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 10%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 10%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` 7% | ArticlesController#index 100% | `<%= csrf_meta_tags %>` |
| 18 | `app/views/articles/index.html.erb:1` |  | 15.2 | 0.0 | 2.13 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:345` 16%, `GEM/turbo-rails/app/helpers/turbo/streams_helper.rb:61` 9%, `GEM/turbo-rails/app/channels/turbo/streams/stream_name.rb:26` 9% | ArticlesController#index 100% | `<%= turbo_stream_from "articles" %>` |
| 19 | `app/controllers/articles_controller.rb:6` | `index` | 14.72 | 0.0 | 1.28 | `RAILS/activerecord/lib/active_record/relation/query_methods.rb:2031` 16%, `RAILS/activerecord/lib/active_record/relation/query_methods.rb:2068` 10%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:129` 6% | ArticlesController#index 100% | `@articles = Article.includes(:comments).order(created_at: :desc)` |
| 20 | `app/controllers/articles_controller.rb:68` | `article_params` | 13.3 | 0.0 | 0.45 | `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:1118` 14%, `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:1166` 7%, `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:406` 7% | ArticlesController#create 100% | `params.require(:article).permit(:title, :body)` |
| 21 | `app/controllers/articles_controller.rb:24` | `create` | 9.02 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 26%, `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:73` 11%, `RAILS/activemodel/lib/active_model/attribute.rb:13` 11% | ArticlesController#create 100% | `@article = Article.new(article_params)` |
| 22 | `app/controllers/articles_controller.rb:26` | `create` | 7.65 | 0.0 | 0.45 | `RAILS/actionpack/lib/action_dispatch/http/response.rb:473` 19%, `RAILS/actionpack/lib/action_dispatch/http/mime_type.rb:299` 12%, `RAILS/actionpack/lib/action_dispatch/http/response.rb:459` 12% | ArticlesController#create 100% | `respond_to do \|format\|` |
| 23 | `app/views/articles/index.html.erb:21` |  | 7.6 | 0.0 | 1.7 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 13%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 13%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` 6% | ArticlesController#index 100% | `<%= link_to "New article", new_article_path, class: "rounded-md px-3.5` |
| 24 | `app/views/articles/index.html.erb:12` |  | 5.7 | 0.0 | 0.0 | `GEM/turbo-rails/app/helpers/turbo/drive_helper.rb:27` 25%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 17%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 17% | ArticlesController#index 100% | `<% turbo_exempts_page_from_cache %>` |
| 25 | `app/controllers/articles_controller.rb:29` | `create` | 1.42 | 0.0 | 0.45 | `RAILS/actionpack/lib/abstract_controller/collector.rb:13` 33%, `RAILS/actionpack/lib/action_controller/metal/mime_responds.rb:274` 33%, `RAILS/actionpack/lib/action_dispatch/http/mime_type.rb:176` 33% | ArticlesController#create 100% | `format.json { render :show, status: :created, location: @article }` |
| 26 | `app/views/articles/index.html.erb:3` |  | 1.42 | 0.0 | 0.43 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:203` 33%, `RAILS/actionview/lib/action_view/helpers/capture_helper.rb:172` 33%, `RAILS/actionview/lib/action_view/flows.rb:10` 33% | ArticlesController#index 100% | `<% content_for :title, "Articles" %>` |
| 27 | `app/views/articles/index.html.erb:16` |  | 1.42 | 0.0 | 0.43 | `RAILS/actionpack/lib/action_controller/metal/flash.rb:41` 33%, `RAILS/actionview/lib/action_view/buffers.rb:48` 33%, `RAILS/actionpack/lib/action_dispatch/middleware/flash.rb:170` 33% | ArticlesController#index 100% | `<p class="py-2 px-3 bg-green-50 mb-5 text-green-500 font-medium rounde` |
| 28 | `app/views/layouts/application.html.erb:10` |  | 1.42 | 0.0 | 0.43 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` 33%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` 33%, `RAILS/actionview/lib/action_view/renderer/template_renderer.rb:77` 33% | ArticlesController#index 100% | `<%= yield :head %>` |
| 29 | `app/views/layouts/application.html.erb:8` |  | 0.95 | 0.0 | 0.43 | `RAILS/actionpack/lib/action_controller/metal/content_security_policy.rb:13` 50%, `RAILS/actionview/lib/action_view/helpers/csp_helper.rb:18` 50% | ArticlesController#index 100% | `<%= csp_meta_tag %>` |
| 30 | `app/views/layouts/application.html.erb:23` |  | 0.95 | 0.0 | 0.43 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` 50%, `RAILS/actionview/lib/action_view/renderer/template_renderer.rb:77` 50% | ArticlesController#index 100% | `<%= yield %>` |

1559.53 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | ArticlesController#index | 20 / 20 | 11627.3 / 19433.9 | 7806.6 | 19302.8 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 1093.0, `RAILS/activerecord/lib/active_record/integration.rb:59` 636.0, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 608.0 | `app/views/articles/_article.html.erb:14` 5672.0, `app/views/articles/index.html.erb:26` 2073.7, `app/views/articles/_article.html.erb:4` 1219.0 |
| 2 | ArticlesController#create | 20 / 20 | 4849.8 / 4849.8 | 0.1 | 4849.9 | `RUBY/ipaddr.rb:692` 578.0, `RUBY/uri/common.rb:401` 87.4, `GEM/useragent/lib/user_agent/browsers/base.rb:120` 78.0 | `app/controllers/articles_controller.rb:27` 562.6, `app/controllers/articles_controller.rb:28` 94.0, `app/controllers/articles_controller.rb:68` 28.0 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `RUBY/ipaddr.rb:692` | `in6_addr` | 563.55 / 563.55 | 0.0 | 578.03 | 100% | Data, Array |  | `no app frame` 100% | `raise InvalidAddressError, "invalid address: #{@addr}"` |
| 2 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` | `tag_option` | 234.18 / 519.18 | 285.0 | 391.5 | 50% | String |  | `app/views/articles/_article.html.erb:14` 68%, `app/views/articles/_article.html.erb:12` 10% | `%(#{key}="#{value}")` |
| 3 | `RAILS/activerecord/lib/active_record/integration.rb:59` | `to_param` | 132.6 / 303.6 | 171.0 | 226.5 | 100% | String, Array |  | `app/views/articles/_article.html.erb:14` 25%, `app/views/articles/_article.html.erb:4` 25% | `Array(id).join(self.class.param_delimiter)` |
| 4 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` | `xml_name_escape` | 132.05 / 288.8 | 156.75 | 218.75 | 50% | String |  | `app/views/articles/_article.html.erb:14` 96%, `app/views/layouts/application.html.erb:18` 3% | `name = name.to_s` |
| 5 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` | `html_safe` | 112.58 / 240.83 | 128.25 | 183.75 | 50% | String |  | `app/views/articles/_article.html.erb:14` 42%, `app/views/articles/index.html.erb:26` 11% | `ActiveSupport::SafeBuffer.new(self)` |
| 6 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` | `initialize` | 102.13 / 216.13 | 114.0 | 165.5 | 50% | String |  | `app/views/articles/_article.html.erb:14` 47%, `app/views/articles/index.html.erb:26` 12% | `super` |
| 7 | `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` | `evaluate` | 89.35 / 203.35 | 114.0 | 152.0 | 100% | Array |  | `app/views/articles/_article.html.erb:14` 25%, `app/views/articles/_article.html.erb:4` 25% | `parts = @parts.dup` |
| 8 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:263` | `tag_options` | 84.08 / 183.83 | 99.75 | 139.25 | 50% | String |  | `app/views/articles/_article.html.erb:14` 55%, `app/views/articles/_article.html.erb:13` 14% | `output = +""` |
| 9 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` | `each` | 62.72 / 133.98 | 71.25 | 102.25 | 100% | String, Array |  | `app/views/articles/index.html.erb:26` 99%, `app/controllers/articles_controller.rb:27` 0% | `val = step` |
| 10 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:129` | `create` | 61.28 / 132.52 | 71.25 | 100.75 | 50% | Hash, Object |  | `app/views/articles/_article.html.erb:6` 95%, `app/views/articles/index.html.erb:26` 4% | `relation_class_for(klass).new(klass, *args, **kwargs)` |
| 11 | `RAILS/activesupport/lib/active_support/core_ext/hash/keys.rb:11` | `stringify_keys` | 59.93 / 131.18 | 71.25 | 99.25 | 100% | Hash |  | `app/views/articles/_article.html.erb:14` 38%, `app/views/articles/_article.html.erb:13` 19% | `transform_keys { \|k\| Symbol === k ? k.name : k.to_s }` |
| 12 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:258` | `content_tag_string` | 56.53 / 127.78 | 71.25 | 95.75 | 50% | String |  | `app/views/articles/_article.html.erb:14` 39%, `app/views/articles/_article.html.erb:4` 20% | `"<#{name}#{tag_options}>#{PRE_CONTENT_STRINGS[name]}#{content}</#{name` |
| 13 | `RUBY/uri/rfc3986_parser.rb:135` | `parse` | 47.7 / 104.7 | 57.0 | 79.0 | 100% | Array |  | `app/views/articles/_article.html.erb:14` 96%, `app/controllers/articles_controller.rb:28` 4% | `URI.for(*self.split(uri), self)` |
| 14 | `GEM/useragent/lib/user_agent/browsers/base.rb:120` | `detect_product` | 76.05 / 76.05 | 0.0 | 78.0 | 100% | String |  | `no app frame` 100% | `detect { \|useragent\| useragent.product.to_s.downcase == product.to_s.d` |
| 15 | `RAILS/actionpack/lib/action_controller/metal/url_for.rb:49` | `url_options` | 44.68 / 101.68 | 57.0 | 76.0 | 100% | Hash |  | `app/views/articles/_article.html.erb:13` 25%, `app/views/articles/_article.html.erb:14` 25% | `options = @_url_options.dup` |
| 16 | `RAILS/actionpack/lib/action_dispatch/http/url.rb:73` | `path_for` | 44.68 / 101.68 | 57.0 | 76.0 | 100% | String |  | `app/views/articles/_article.html.erb:4` 25%, `app/views/articles/_article.html.erb:13` 25% | `path = options[:script_name].to_s.chomp("/")` |
| 17 | `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:51` | `evaluate` | 44.68 / 101.68 | 57.0 | 76.0 | 100% | String |  | `app/views/articles/_article.html.erb:14` 25%, `app/views/articles/_article.html.erb:12` 25% | `parts.join` |
| 18 | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:216` | `call` | 44.68 / 101.68 | 57.0 | 76.0 | 100% | Hash |  | `app/views/articles/_article.html.erb:4` 25%, `app/views/articles/_article.html.erb:13` 25% | `options = t.url_options.merge @options` |
| 19 | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:250` | `parameterize_args` | 44.68 / 101.68 | 57.0 | 76.0 | 100% | Hash |  | `app/views/articles/_article.html.erb:13` 25%, `app/views/articles/_article.html.erb:14` 25% | `params = {}` |
| 20 | `RAILS/actionpack/lib/action_dispatch/journey/router/utils.rb:71` | `escape` | 44.2 / 101.2 | 57.0 | 75.5 | 100% | String |  | `app/views/articles/_article.html.erb:4` 25%, `app/views/articles/_article.html.erb:12` 25% | `component.gsub(pattern) { \|unsafe\| percent_encode(unsafe) }.force_enco` |
| 21 | `RAILS/actionview/lib/action_view/helpers/url_helper.rb:752` | `token_tag` | 43.7 / 100.7 | 57.0 | 75.0 | 50% | Hash, Array |  | `app/views/articles/_article.html.erb:14` 100% | `form_authenticity_token(form_options: form_options.merge(authenticity_` |
| 22 | `RAILS/actionview/lib/action_view/record_identifier.rb:115` | `record_key_for_dom_id` | 43.7 / 100.7 | 57.0 | 75.0 | 50% | String |  | `app/views/articles/_article.html.erb:1` 50%, `app/views/articles/_article.html.erb:5` 50% | `key && key.all? ? key.join(JOIN) : nil` |
| 23 | `RUBY/uri/common.rb:401` | `_decode_uri_component` | 71.93 / 71.85 | -0.08 | 73.56 | 100% | String, MatchData |  | `no app frame` 59%, `app/views/articles/index.html.erb:15` 41% | `str.b.gsub(regexp, TBLDECWWWCOMP_).force_encoding(enc)` |
| 24 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:500` | `tag` | 35.63 / 78.38 | 42.75 | 59.25 | 50% | String | #59804 open upstream work | `app/views/articles/_article.html.erb:14` 96%, `app/views/layouts/application.html.erb:16` 1% | `"<#{name}#{tag_builder.tag_options(options, escape) if options}#{open ` |
| 25 | `RAILS/actionpack/lib/action_dispatch/routing/polymorphic_routes.rb:271` | `handle_model` | 33.28 / 76.03 | 42.75 | 56.75 | 100% | Array |  | `app/views/articles/_article.html.erb:4` 33%, `app/views/articles/_article.html.erb:12` 33% | `args  = []` |
| 26 | `RAILS/actionpack/lib/action_dispatch/routing/polymorphic_routes.rb:281` | `handle_model` | 33.28 / 76.03 | 42.75 | 56.75 | 100% | Array |  | `app/views/articles/_article.html.erb:4` 33%, `app/views/articles/_article.html.erb:14` 33% | `[named_route, args]` |
| 27 | `RAILS/actionpack/lib/action_dispatch/routing/polymorphic_routes.rb:289` | `handle_model_call` | 33.28 / 76.03 | 42.75 | 56.75 | 100% | Array |  | `app/views/articles/_article.html.erb:14` 33%, `app/views/articles/_article.html.erb:4` 33% | `target.public_send(method, *args)` |
| 28 | `RAILS/actionpack/lib/action_dispatch/routing/polymorphic_routes.rb:353` | `get_method_for_string` | 33.28 / 76.03 | 42.75 | 56.75 | 100% | String |  | `app/views/articles/_article.html.erb:12` 33%, `app/views/articles/_article.html.erb:14` 33% | `"#{prefix}#{str}_#{suffix}"` |
| 29 | `RAILS/actionpack/lib/action_controller/metal/request_forgery_protection.rb:102` | `` | 33.25 / 76.0 | 42.75 | 56.75 | 50% | Array, Hash |  | `app/views/articles/_article.html.erb:14` 99%, `app/views/layouts/application.html.erb:7` 1% | `helper_method :form_authenticity_token` |
| 30 | `RAILS/actionview/lib/action_view/buffers.rb:48` | `<<` | 33.25 / 76.0 | 42.75 | 56.75 | 50% | String |  | `app/views/articles/_article.html.erb:6` 33%, `app/views/articles/_article.html.erb:5` 33% | `CGI.escapeHTML(value)` |

## Dev/test-mode work

2638.0 of 9421.1 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | error page | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:124` | 950.1 | 100% | `app/controllers/articles_controller.rb:27` 61%, `app/views/articles/index.html.erb:26` 29% | `add_filter { \|line\| line.sub(gems_regexp, gems_result) }` |
| 2 | reload check | `RAILS/activesupport/lib/active_support/file_update_checker.rb:132` | 264.23 | 100% | `no app frame` 100% | `mtime = File.mtime(path)` |
| 3 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:131` | 164.1 | 100% | `app/controllers/articles_controller.rb:27` 54%, `app/views/articles/index.html.erb:26` 34% | `Thread.each_caller_location do \|location\|` |
| 4 | error page | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:62` | 161.18 | 100% | `app/controllers/articles_controller.rb:27` 54%, `app/views/articles/index.html.erb:26` 34% | `frame = frame.to_s` |
| 5 | reload check | `RAILS/activesupport/lib/active_support/file_update_checker.rb:106` † | 136.5 | 100% | `no app frame` 100% | `all.concat(Dir[@glob]) if @glob` |
| 6 | debug logging | `RAILS/activejob/lib/active_job/log_subscriber.rb:192` | 78.85 | 50% | `app/controllers/articles_controller.rb:27` 100% | `source = extract_enqueue_source_location(caller)` |
| 7 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` | 84.4 | 100% | `app/views/articles/index.html.erb:26` 90%, `app/controllers/articles_controller.rb:27` 7% | `binds = binds.inspect` |
| 8 | asset lookup | `GEM/sprockets/lib/sprockets/path_utils.rb:166` | 21.85 | 50% | `app/views/layouts/application.html.erb:16` 78%, `app/views/layouts/application.html.erb:17` 22% | `path = File.join(path, ''.freeze)` |
| 9 | reload check | `RAILS/activesupport/lib/active_support/file_update_checker.rb:105` | 21.45 | 100% | `no app frame` 100% | `all = @files.select { \|f\| File.exist?(f) }` |
| 10 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:77` | 27.65 | 100% | `app/views/articles/index.html.erb:26` 91%, `app/controllers/articles_controller.rb:27` 7% | `[attr&.name, value]` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activesupport | 2776.3 | 2853.5 | `backtrace_cleaner.rb:124` 950.1, `file_update_checker.rb:132` 264.2, `util.rb:143` 210.4 |
| rails: actionview | 1384.3 | 1439.8 | `tag_helper.rb:324` 376.7, `tag_helper.rb:263` 134.0, `tag_helper.rb:258` 92.2 |
| rails: actionpack | 1337.3 | 1387.3 | `visitors.rb:40` 146.4, `visitors.rb:51` 73.2, `url.rb:73` 73.2 |
| rails: activerecord | 1312.7 | 1363.4 | `integration.rb:59` 218.1, `log_subscriber.rb:131` 164.1, `delegation.rb:129` 96.9 |
| ruby stdlib | 1216.8 | 1252.3 | `ipaddr.rb:692` 563.6, `rfc3986_parser.rb:135` 76.2, `common.rb:401` 71.9 |
| gem: sprockets | 425.8 | 448.2 | `path_utils.rb:166` 21.9, `http_utils.rb:18` 20.0, `http_utils.rb:17` 20.0 |
| app | 362.0 | 376.3 | `_article.html.erb:14` 90.3, `_article.html.erb:13` 72.2, `_article.html.erb:12` 54.2 |
| gem: useragent | 203.5 | 208.8 | `base.rb:120` 76.1, `version.rb:27` 39.0, `user_agent.rb:25` 11.7 |
| rails: activemodel | 133.7 | 139.0 | `string.rb:35` 37.6, `builder.rb:22` 19.5, `builder.rb:28` 19.5 |
| rails: activejob | 125.4 | 132.0 | `log_subscriber.rb:192` 78.9, `log_subscriber.rb:148` 9.0, `arguments.rb:92` 6.2 |
| gem: sqlite3 | 122.6 | 127.4 | `statement.rb:159` 98.4, `statement.rb:76` 8.8, `statement.rb:80` 2.9 |
| ruby default gem: base64 | 88.8 | 92.0 | `base64.rb:283` 45.8, `base64.rb:310` 23.4, `base64.rb:374` 19.5 |
| gem: rack | 60.3 | 62.5 | `body_proxy.rb:12` 4.9, `query_parser.rb:259` 4.8, `utils.rb:331` 3.9 |
| ruby default gem: logger | 55.0 | 56.5 | `logger.rb:692` 14.1, `log_device.rb:165` 14.1, `log_device.rb:33` 14.1 |
| gem: importmap-rails | 28.0 | 29.5 | `importmap_tags_helper.rb:44` 10.0, `importmap_tags_helper.rb:30` 6.7, `importmap_tags_helper.rb:42` 4.3 |
| gem: web-console | 26.3 | 27.0 | `permissions.rb:39` 13.7, `permissions.rb:21` 3.9, `request.rb:32` 2.0 |
| ruby default gem: securerandom | 20.5 | 21.3 | `securerandom.rb:71` 20.5 |
| gem: globalid | 18.0 | 19.0 | `gid.rb:95` 4.8, `gid.rb:159` 3.8, `gid.rb:166` 1.9 |
| rails: railties | 17.9 | 18.5 | `backtrace_cleaner.rb:21` 4.3, `finisher.rb:195` 2.9, `logger.rb:57` 2.9 |
| gem: turbo-rails | 16.8 | 17.5 | `stream_name.rb:26` 2.9, `broadcastable.rb:184` 2.4, `broadcastable.rb:456` 1.9 |
| gem: json | 15.6 | 16.1 | `common.rb:298` 12.7, `common.rb:378` 2.0, `common.rb:775` 0.5 |
| gem: sprockets-rails | 12.3 | 13.0 | `helper.rb:81` 1.9, `helper.rb:357` 1.9, `helper.rb:186` 1.9 |
| gem: concurrent-ruby | 11.6 | 12.3 | `non_concurrent_map_backend.rb:26` 3.4, `non_concurrent_map_backend.rb:120` 2.4, `mri_map_backend.rb:14` 2.4 |
| gem: tzinfo | 8.5 | 9.0 | `timestamp.rb:208` 3.8, `constant_offset_data_timezone_info.rb:52` 1.9, `timestamp.rb:193` 1.9 |
| gem: rack-session | 2.9 | 3.0 | `id.rb:275` 1.0, `id.rb:401` 1.0, `id.rb:277` 1.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Jobs

| # | Job | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | Turbo::Streams::ActionBroadcastJob#perform | 20 / 20 | 3408.3 / 3408.4 | 0.2 | 3383.6 | `RAILS/activesupport/lib/active_support/json/encoding.rb:65` 33.0, `RAILS/activesupport/lib/active_support/json/encoding.rb:66` 32.0, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 24.0 | `app/views/articles/_article.html.erb:6` 226.5, `app/views/articles/_article.html.erb:14` 64.0, `app/views/articles/_article.html.erb:4` 31.0 |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:124` (error page) | 1138.19 / 1138.19 | 95% | `no app frame` 84%, `app/views/articles/_article.html.erb:6` 16% | `add_filter { \|line\| line.sub(gems_regexp, gems_result) }` |
| 2 | `RAILS/activesupport/lib/active_support/file_update_checker.rb:132` (reload check) | 222.0 / 222.0 | 91% | `no app frame` 100% | `mtime = File.mtime(path)` |
| 3 | `RAILS/activerecord/lib/active_record/log_subscriber.rb:131` (debug logging) | 138.43 / 138.43 | 95% | `no app frame` 72%, `app/views/articles/_article.html.erb:6` 28% | `Thread.each_caller_location do \|location\|` |
| 4 | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:62` (error page) | 136.62 / 136.62 | 95% | `no app frame` 72%, `app/views/articles/_article.html.erb:6` 28% | `frame = frame.to_s` |
| 5 | `RAILS/activesupport/lib/active_support/file_update_checker.rb:106` † (reload check) | 111.43 / 111.43 | 91% | `no app frame` 100% | `all.concat(Dir[@glob]) if @glob` |
| 6 | `RAILS/activejob/lib/active_job/log_subscriber.rb:192` (debug logging) | 99.52 / 99.52 | 95% | `no app frame` 100% | `source = extract_enqueue_source_location(caller)` |
| 7 | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:149` (error page) | 65.14 / 65.14 | 95% | `no app frame` 100% | `backtrace = backtrace.reject { \|line\| s.call(line.to_s) }` |
| 8 | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:141` (error page) | 48.86 / 48.86 | 95% | `no app frame` 100% | `backtrace = backtrace.map { \|line\| f.call(line.to_s) }` |
| 9 | `RAILS/activesupport/lib/active_support/json/encoding.rb:65` | 29.86 / 29.86 | 95% | `no app frame` 100% | `json.gsub!(">", '\u003e')` |
| 10 | `RAILS/activesupport/lib/active_support/json/encoding.rb:66` | 28.95 / 28.95 | 95% | `no app frame` 100% | `json.gsub!("<", '\u003c')` |
