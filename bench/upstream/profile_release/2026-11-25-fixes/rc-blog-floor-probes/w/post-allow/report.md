# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails runner /home/user/.local/share/mise/installs/ruby/3.3.14/lib/ruby/gems/3.3.0/gems/lowrail-profile-0.1.0.rc1/lib/lowrail/profile_workloads.rb /home/user/workspace/repo/bench/upstream/profile_release/2026-11-25-fixes/rc-blog-floor-probes/w/post.rb /home/user/workspace/repo/bench/upstream/profile_release/2026-11-25-fixes/rc-blog-floor-probes/w/post-allow/workloads.json`
* Ruby: ruby 3.3.14 (2026-11-19 revision f4c37f481b) +YJIT [x86_64-linux]
* Rails: 7.2.4, development environment
* Counted in run 1: 40 requests, 21 jobs; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 40 | 17192.0 | 21 | 0 | 0 | 0 |
| run2 | 1 | 40 | 21363.3 | 21 | 0 | 0 | 0 |

run1 left windows unfinished (1 job), which no line or action counts; compare refuses it.

run2 left windows unfinished (1 job), which no line or action counts; compare refuses it.

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 57.0, max |Δ| 285.0 objects per request; 29 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/views/articles/_article.html.erb:14` |  | 5743.7 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 13%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 10%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:263` 4% | ArticlesController#index 100% | `<%= button_to "Destroy", article, method: :delete, class: "w-full sm:w` |
| 2 | `app/views/articles/index.html.erb:26` |  | 1811.42 | 740.05 | 0.0 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` 15%, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:102` 6%, `RAILS/activerecord/lib/active_record/associations/preloader/association.rb:172` 6% | ArticlesController#index 100% | `<%= render @articles %>` |
| 3 | `app/views/articles/_article.html.erb:4` |  | 1234.52 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/integration.rb:59` 13%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 9%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 9% | ArticlesController#index 100% | `<%= link_to article.title, article, class: "text-blue-600 hover:underl` |
| 4 | `app/views/articles/_article.html.erb:12` |  | 1180.85 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/integration.rb:59` 14%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 9%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 9% | ArticlesController#index 100% | `<%= link_to "Show", article, class: "w-full sm:w-auto text-center roun` |
| 5 | `app/views/articles/_article.html.erb:6` |  | 1125.28 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:129` 24%, `RAILS/activerecord/lib/active_record/relation.rb:77` 10%, `RAILS/activerecord/lib/active_record/core.rb:420` 10% | ArticlesController#index 100% | `(<%= pluralize(article.comments.size, "comment") %>)` |
| 6 | `app/views/articles/_article.html.erb:13` |  | 966.15 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/integration.rb:59` 17%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 11%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 11% | ArticlesController#index 100% | `<%= link_to "Edit", edit_article_path(article), class: "w-full sm:w-au` |
| 7 | `app/views/articles/_article.html.erb:5` |  | 375.73 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/record_identifier.rb:80` 29%, `RAILS/actionview/lib/action_view/record_identifier.rb:115` 29%, `RAILS/actionview/lib/action_view/buffers.rb:48` 14% | ArticlesController#index 100% | `<span id="<%= dom_id(article, :comments_count) %>" class="text-gray-50` |
| 8 | `app/views/articles/_article.html.erb:1` |  | 268.38 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/record_identifier.rb:115` 40%, `RAILS/actionview/lib/action_view/record_identifier.rb:98` 20%, `RAILS/actionview/lib/action_view/buffers.rb:48` 20% | ArticlesController#index 100% | `<div id="<%= dom_id(article) %>" class="flex flex-col sm:flex-row just` |
| 9 | `app/controllers/articles_controller.rb:27` | `create` | 267.22 | 919.13 | 0.45 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 5%, `RUBY/random/formatter.rb:174` 2%, `RAILS/activejob/lib/active_job/arguments.rb:92` 2% | ArticlesController#create 100% | `if @article.save` |
| 10 | `app/views/articles/_article.html.erb:9` |  | 163.88 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` 33%, `RAILS/activemodel/lib/active_model/type/string.rb:35` 33%, `RAILS/activesupport/lib/active_support/core_ext/string/filters.rb:71` 32% | ArticlesController#index 100% | `<p class="text-gray-700 mt-2"><%= truncate(article.body, length: 100) ` |
| 11 | `app/views/articles/index.html.erb:15` |  | 84.55 | 0.0 | 0.43 | `RUBY/uri/common.rb:401` 31%, `GEM/json/lib/json/common.rb:298` 8%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:50` 4% | ArticlesController#index 100% | `<% if notice.present? %>` |
| 12 | `app/views/layouts/application.html.erb:17` |  | 48.93 | 218.5 | 1.7 | `RUBY/uri/rfc2396_parser.rb:292` 11%, `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/collection/map/non_concurrent_map_backend.rb:26` 9%, `RUBY/set.rb:244` 8% | ArticlesController#index 100% | `<%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>` |
| 13 | `app/views/layouts/application.html.erb:16` |  | 47.98 | 220.4 | 1.7 | `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/collection/map/non_concurrent_map_backend.rb:26` 8%, `RUBY/uri/rfc2396_parser.rb:321` 8%, `RUBY/uri/rfc2396_parser.rb:292` 5% | ArticlesController#index 100% | `<%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>` |
| 14 | `app/views/articles/index.html.erb:25` |  | 46.55 | 152.0 | 0.43 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 6%, `GEM/sqlite3/lib/sqlite3/statement.rb:76` 3%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:236` 3% | ArticlesController#index 100% | `<% if @articles.any? %>` |
| 15 | `app/controllers/articles_controller.rb:28` | `create` | 44.65 | 3.8 | 1.8 | `RUBY/uri/rfc3986_parser.rb:135` 9%, `RUBY/uri/rfc3986_parser.rb:85` 4%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 3% | ArticlesController#create 100% | `format.html { redirect_to @article, notice: "Article was successfully ` |
| 16 | `app/views/layouts/application.html.erb:18` |  | 39.9 | 28.03 | 0.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 20%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 20%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` 15% | ArticlesController#index 100% | `<%= javascript_importmap_tags %>` |
| 17 | `app/views/layouts/application.html.erb:7` |  | 19.95 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 10%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 10%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` 7% | ArticlesController#index 100% | `<%= csrf_meta_tags %>` |
| 18 | `app/views/articles/index.html.erb:1` |  | 15.2 | 0.0 | 2.13 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:345` 16%, `GEM/turbo-rails/app/helpers/turbo/streams_helper.rb:61` 9%, `GEM/turbo-rails/app/channels/turbo/streams/stream_name.rb:26` 9% | ArticlesController#index 100% | `<%= turbo_stream_from "articles" %>` |
| 19 | `app/controllers/articles_controller.rb:6` | `index` | 14.72 | 0.0 | 1.28 | `RAILS/activerecord/lib/active_record/relation/query_methods.rb:2031` 16%, `RAILS/activerecord/lib/active_record/relation/query_methods.rb:2068` 10%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:129` 6% | ArticlesController#index 100% | `@articles = Article.includes(:comments).order(created_at: :desc)` |
| 20 | `app/controllers/articles_controller.rb:68` | `article_params` | 13.3 | 0.0 | 0.45 | `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:1118` 14%, `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:1166` 7%, `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:406` 7% | ArticlesController#create 100% | `params.require(:article).permit(:title, :body)` |
| 21 | `app/controllers/articles_controller.rb:24` | `create` | 9.02 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 26%, `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:73` 11%, `RAILS/activemodel/lib/active_model/attribute.rb:13` 11% | ArticlesController#create 100% | `@article = Article.new(article_params)` |
| 22 | `app/controllers/articles_controller.rb:26` | `create` | 8.02 | 0.0 | 0.45 | `RAILS/actionpack/lib/action_dispatch/http/response.rb:473` 18%, `RAILS/actionpack/lib/action_dispatch/http/mime_type.rb:299` 12%, `RAILS/actionpack/lib/action_dispatch/http/response.rb:459` 12% | ArticlesController#create 100% | `respond_to do \|format\|` |
| 23 | `app/views/articles/index.html.erb:21` |  | 7.6 | 0.0 | 1.7 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 13%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 13%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` 6% | ArticlesController#index 100% | `<%= link_to "New article", new_article_path, class: "rounded-md px-3.5` |
| 24 | `app/views/articles/index.html.erb:12` |  | 5.7 | 0.0 | 0.0 | `GEM/turbo-rails/app/helpers/turbo/drive_helper.rb:27` 25%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 17%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 17% | ArticlesController#index 100% | `<% turbo_exempts_page_from_cache %>` |
| 25 | `app/controllers/articles_controller.rb:29` | `create` | 1.42 | 0.0 | 0.45 | `RAILS/actionpack/lib/abstract_controller/collector.rb:13` 33%, `RAILS/actionpack/lib/action_controller/metal/mime_responds.rb:274` 33%, `RAILS/actionpack/lib/action_dispatch/http/mime_type.rb:176` 33% | ArticlesController#create 100% | `format.json { render :show, status: :created, location: @article }` |
| 26 | `app/views/articles/index.html.erb:3` |  | 1.42 | 0.0 | 0.43 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:203` 33%, `RAILS/actionview/lib/action_view/helpers/capture_helper.rb:172` 33%, `RAILS/actionview/lib/action_view/flows.rb:10` 33% | ArticlesController#index 100% | `<% content_for :title, "Articles" %>` |
| 27 | `app/views/articles/index.html.erb:16` |  | 1.42 | 0.0 | 0.43 | `RAILS/actionpack/lib/action_controller/metal/flash.rb:41` 33%, `RAILS/actionview/lib/action_view/buffers.rb:48` 33%, `RAILS/actionpack/lib/action_dispatch/middleware/flash.rb:170` 33% | ArticlesController#index 100% | `<p class="py-2 px-3 bg-green-50 mb-5 text-green-500 font-medium rounde` |
| 28 | `app/views/layouts/application.html.erb:10` |  | 1.42 | 0.0 | 0.43 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` 33%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` 33%, `RAILS/actionview/lib/action_view/renderer/template_renderer.rb:77` 33% | ArticlesController#index 100% | `<%= yield :head %>` |
| 29 | `app/views/layouts/application.html.erb:8` |  | 0.95 | 0.0 | 0.43 | `RAILS/actionpack/lib/action_controller/metal/content_security_policy.rb:13` 50%, `RAILS/actionview/lib/action_view/helpers/csp_helper.rb:18` 50% | ArticlesController#index 100% | `<%= csp_meta_tag %>` |
| 30 | `app/views/layouts/application.html.erb:23` |  | 0.95 | 0.0 | 0.43 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` 50%, `RAILS/actionview/lib/action_view/renderer/template_renderer.rb:77` 50% | ArticlesController#index 100% | `<%= yield %>` |

1557.65 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | ArticlesController#index | 20 / 20 | 27237.3 / 35038.5 | 7801.2 | 34908.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 2293.0, `RAILS/activerecord/lib/active_record/integration.rb:59` 1356.0, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 1268.0 | `app/views/articles/_article.html.erb:14` 12092.0, `app/views/articles/index.html.erb:26` 3813.5, `app/views/articles/_article.html.erb:4` 2599.0 |
| 2 | ArticlesController#create | 20 / 20 | 4848.7 / 4847.8 | -0.9 | 4847.5 | `RUBY/ipaddr.rb:692` 578.0, `RUBY/uri/common.rb:401` 86.1, `GEM/useragent/lib/user_agent/browsers/base.rb:120` 78.0 | `app/controllers/articles_controller.rb:27` 562.6, `app/controllers/articles_controller.rb:28` 94.0, `app/controllers/articles_controller.rb:68` 28.0 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` | `tag_option` | 804.18 / 1089.18 | 285.0 | 991.5 | 50% | String |  | `app/views/articles/_article.html.erb:14` 69%, `app/views/articles/_article.html.erb:12` 10% | `%(#{key}="#{value}")` |
| 2 | `RUBY/ipaddr.rb:692` | `in6_addr` | 563.55 / 563.55 | 0.0 | 578.03 | 100% | Data, Array |  | `no app frame` 100% | `raise InvalidAddressError, "invalid address: #{@addr}"` |
| 3 | `RAILS/activerecord/lib/active_record/integration.rb:59` | `to_param` | 474.6 / 645.6 | 171.0 | 586.5 | 100% | String, Array |  | `app/views/articles/_article.html.erb:14` 25%, `app/views/articles/_article.html.erb:4` 25% | `Array(id).join(self.class.param_delimiter)` |
| 4 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` | `xml_name_escape` | 445.55 / 602.3 | 156.75 | 548.75 | 50% | String |  | `app/views/articles/_article.html.erb:14` 98%, `app/views/layouts/application.html.erb:18` 1% | `name = name.to_s` |
| 5 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` | `html_safe` | 369.08 / 497.33 | 128.25 | 453.75 | 50% | String |  | `app/views/articles/_article.html.erb:14` 43%, `app/views/articles/index.html.erb:26` 11% | `ActiveSupport::SafeBuffer.new(self)` |
| 6 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` | `initialize` | 330.13 / 444.13 | 114.0 | 405.5 | 50% | String |  | `app/views/articles/_article.html.erb:14` 48%, `app/views/articles/index.html.erb:26` 12% | `super` |
| 7 | `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` | `evaluate` | 317.35 / 431.35 | 114.0 | 392.0 | 100% | Array |  | `app/views/articles/_article.html.erb:14` 25%, `app/views/articles/_article.html.erb:4` 25% | `parts = @parts.dup` |
| 8 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:263` | `tag_options` | 283.58 / 383.33 | 99.75 | 349.25 | 50% | String |  | `app/views/articles/_article.html.erb:14` 56%, `app/views/articles/_article.html.erb:13` 14% | `output = +""` |
| 9 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` | `each` | 205.23 / 276.48 | 71.25 | 252.25 | 100% | String, Array |  | `app/views/articles/index.html.erb:26` 100%, `app/controllers/articles_controller.rb:27` 0% | `val = step` |
| 10 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:129` | `create` | 203.77 / 275.03 | 71.25 | 250.75 | 50% | Hash, Object |  | `app/views/articles/_article.html.erb:6` 98%, `app/views/articles/index.html.erb:26` 2% | `relation_class_for(klass).new(klass, *args, **kwargs)` |
| 11 | `RAILS/activesupport/lib/active_support/core_ext/hash/keys.rb:11` | `stringify_keys` | 202.43 / 273.68 | 71.25 | 249.25 | 100% | Hash |  | `app/views/articles/_article.html.erb:14` 39%, `app/views/articles/_article.html.erb:13` 20% | `transform_keys { \|k\| Symbol === k ? k.name : k.to_s }` |
| 12 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:258` | `content_tag_string` | 199.03 / 270.28 | 71.25 | 245.75 | 50% | String |  | `app/views/articles/_article.html.erb:14` 40%, `app/views/articles/_article.html.erb:4` 20% | `"<#{name}#{tag_options}>#{PRE_CONTENT_STRINGS[name]}#{content}</#{name` |
| 13 | `RUBY/uri/rfc3986_parser.rb:135` | `parse` | 161.7 / 218.7 | 57.0 | 199.0 | 100% | Array |  | `app/views/articles/_article.html.erb:14` 98%, `app/controllers/articles_controller.rb:28` 2% | `URI.for(*self.split(uri), self)` |
| 14 | `RAILS/actionpack/lib/action_controller/metal/url_for.rb:49` | `url_options` | 158.68 / 215.68 | 57.0 | 196.0 | 100% | Hash |  | `app/views/articles/_article.html.erb:13` 25%, `app/views/articles/_article.html.erb:14` 25% | `options = @_url_options.dup` |
| 15 | `RAILS/actionpack/lib/action_dispatch/http/url.rb:73` | `path_for` | 158.68 / 215.68 | 57.0 | 196.0 | 100% | String |  | `app/views/articles/_article.html.erb:4` 25%, `app/views/articles/_article.html.erb:13` 25% | `path = options[:script_name].to_s.chomp("/")` |
| 16 | `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:51` | `evaluate` | 158.68 / 215.68 | 57.0 | 196.0 | 100% | String |  | `app/views/articles/_article.html.erb:14` 25%, `app/views/articles/_article.html.erb:12` 25% | `parts.join` |
| 17 | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:216` | `call` | 158.68 / 215.68 | 57.0 | 196.0 | 100% | Hash |  | `app/views/articles/_article.html.erb:4` 25%, `app/views/articles/_article.html.erb:13` 25% | `options = t.url_options.merge @options` |
| 18 | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:250` | `parameterize_args` | 158.68 / 215.68 | 57.0 | 196.0 | 100% | Hash |  | `app/views/articles/_article.html.erb:13` 25%, `app/views/articles/_article.html.erb:14` 25% | `params = {}` |
| 19 | `RAILS/actionpack/lib/action_dispatch/journey/router/utils.rb:71` | `escape` | 158.2 / 215.2 | 57.0 | 195.5 | 100% | String |  | `app/views/articles/_article.html.erb:4` 25%, `app/views/articles/_article.html.erb:12` 25% | `component.gsub(pattern) { \|unsafe\| percent_encode(unsafe) }.force_enco` |
| 20 | `RAILS/actionview/lib/action_view/helpers/url_helper.rb:752` | `token_tag` | 157.7 / 214.7 | 57.0 | 195.0 | 50% | Hash, Array |  | `app/views/articles/_article.html.erb:14` 100% | `form_authenticity_token(form_options: form_options.merge(authenticity_` |
| 21 | `RAILS/actionview/lib/action_view/record_identifier.rb:115` | `record_key_for_dom_id` | 157.7 / 214.7 | 57.0 | 195.0 | 50% | String |  | `app/views/articles/_article.html.erb:1` 50%, `app/views/articles/_article.html.erb:5` 50% | `key && key.all? ? key.join(JOIN) : nil` |
| 22 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:500` | `tag` | 121.1 / 163.88 | 42.78 | 149.24 | 50% | String | #59804 open upstream work | `app/views/articles/_article.html.erb:14` 98%, `app/views/layouts/application.html.erb:16` 1% | `"<#{name}#{tag_builder.tag_options(options, escape) if options}#{open ` |
| 23 | `RAILS/actionpack/lib/action_dispatch/routing/polymorphic_routes.rb:271` | `handle_model` | 118.78 / 161.53 | 42.75 | 146.75 | 100% | Array |  | `app/views/articles/_article.html.erb:4` 33%, `app/views/articles/_article.html.erb:12` 33% | `args  = []` |
| 24 | `RAILS/actionpack/lib/action_dispatch/routing/polymorphic_routes.rb:281` | `handle_model` | 118.78 / 161.53 | 42.75 | 146.75 | 100% | Array |  | `app/views/articles/_article.html.erb:4` 33%, `app/views/articles/_article.html.erb:14` 33% | `[named_route, args]` |
| 25 | `RAILS/actionpack/lib/action_dispatch/routing/polymorphic_routes.rb:289` | `handle_model_call` | 118.78 / 161.53 | 42.75 | 146.75 | 100% | Array |  | `app/views/articles/_article.html.erb:14` 33%, `app/views/articles/_article.html.erb:4` 33% | `target.public_send(method, *args)` |
| 26 | `RAILS/actionpack/lib/action_dispatch/routing/polymorphic_routes.rb:353` | `get_method_for_string` | 118.78 / 161.53 | 42.75 | 146.75 | 100% | String |  | `app/views/articles/_article.html.erb:12` 33%, `app/views/articles/_article.html.erb:14` 33% | `"#{prefix}#{str}_#{suffix}"` |
| 27 | `RAILS/actionpack/lib/action_controller/metal/request_forgery_protection.rb:102` | `` | 118.75 / 161.5 | 42.75 | 146.75 | 50% | Array, Hash |  | `app/views/articles/_article.html.erb:14` 100%, `app/views/layouts/application.html.erb:7` 0% | `helper_method :form_authenticity_token` |
| 28 | `RAILS/actionview/lib/action_view/buffers.rb:48` | `<<` | 118.75 / 161.5 | 42.75 | 146.75 | 50% | String |  | `app/views/articles/_article.html.erb:6` 33%, `app/views/articles/_article.html.erb:5` 33% | `CGI.escapeHTML(value)` |
| 29 | `RAILS/actionpack/lib/action_controller/metal/request_forgery_protection.rb:577` | `per_form_csrf_token` | 118.28 / 161.02 | 42.75 | 146.25 | 50% | String, Array |  | `app/views/articles/_article.html.erb:14` 100% | `csrf_token_hmac(session, [action_path, method.downcase].join("#"))` |
| 30 | `RAILS/actionview/lib/action_view/helpers/url_helper.rb:756` | `token_tag` | 118.28 / 161.02 | 42.75 | 146.25 | 50% | Array, Hash |  | `app/views/articles/_article.html.erb:14` 100% | `tag(:input, type: "hidden", name: request_forgery_protection_token.to_` |

## Dev/test-mode work

2809.7 of 16292.0 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | error page | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:124` | 950.1 | 100% | `app/controllers/articles_controller.rb:27` 61%, `app/views/articles/index.html.erb:26` 29% | `add_filter { \|line\| line.sub(gems_regexp, gems_result) }` |
| 2 | reload check | `RAILS/activesupport/lib/active_support/file_update_checker.rb:132` | 264.23 | 100% | `no app frame` 100% | `mtime = File.mtime(path)` |
| 3 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:131` | 164.1 | 100% | `app/controllers/articles_controller.rb:27` 54%, `app/views/articles/index.html.erb:26` 34% | `Thread.each_caller_location do \|location\|` |
| 4 | error page | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:62` | 161.18 | 100% | `app/controllers/articles_controller.rb:27` 54%, `app/views/articles/index.html.erb:26` 34% | `frame = frame.to_s` |
| 5 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` | 169.9 | 100% | `app/views/articles/index.html.erb:26` 95%, `app/controllers/articles_controller.rb:27` 4% | `binds = binds.inspect` |
| 6 | reload check | `RAILS/activesupport/lib/active_support/file_update_checker.rb:106` † | 136.5 | 100% | `no app frame` 100% | `all.concat(Dir[@glob]) if @glob` |
| 7 | debug logging | `RAILS/activejob/lib/active_job/log_subscriber.rb:192` | 78.85 | 50% | `app/controllers/articles_controller.rb:27` 100% | `source = extract_enqueue_source_location(caller)` |
| 8 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:77` | 56.15 | 100% | `app/views/articles/index.html.erb:26` 96%, `app/controllers/articles_controller.rb:27` 3% | `[attr&.name, value]` |
| 9 | template compile | `RAILS/actionview/lib/action_view/template.rb:285` | 54.63 | 50% | `app/views/articles/index.html.erb:26` 98%, `no app frame` 2% | `result = view._run(method_name, self, locals, OutputBuffer.new, add_to` |
| 10 | template compile | `RAILS/actionview/lib/action_view/template.rb:588` | 54.63 | 50% | `app/views/articles/index.html.erb:26` 98%, `no app frame` 2% | `{ virtual_path: @virtual_path, identifier: @identifier }` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activesupport | 3859.3 | 3993.5 | `backtrace_cleaner.rb:124` 950.1, `util.rb:143` 523.9, `output_safety.rb:228` 433.2 |
| rails: actionview | 3322.3 | 3479.8 | `tag_helper.rb:324` 946.7, `tag_helper.rb:263` 333.5, `tag_helper.rb:258` 234.7 |
| rails: actionpack | 2990.9 | 3127.9 | `visitors.rb:40` 374.4, `visitors.rb:51` 187.2, `url.rb:73` 187.2 |
| rails: activerecord | 2623.5 | 2743.2 | `integration.rb:59` 560.1, `delegation.rb:129` 239.4, `log_subscriber.rb:131` 164.1 |
| ruby stdlib | 1641.8 | 1699.3 | `ipaddr.rb:692` 563.6, `rfc3986_parser.rb:135` 190.2, `rfc3986_parser.rb:115` 93.1 |
| app | 903.5 | 946.3 | `_article.html.erb:14` 232.8, `_article.html.erb:13` 186.2, `_article.html.erb:12` 139.6 |
| gem: sprockets | 426.4 | 448.8 | `path_utils.rb:166` 21.9, `http_utils.rb:18` 20.0, `http_utils.rb:17` 20.0 |
| rails: activemodel | 304.7 | 319.0 | `string.rb:35` 94.6, `builder.rb:22` 48.0, `builder.rb:28` 48.0 |
| gem: sqlite3 | 265.0 | 277.3 | `statement.rb:159` 240.9, `statement.rb:76` 8.8, `statement.rb:80` 2.9 |
| gem: useragent | 204.1 | 209.4 | `base.rb:120` 76.1, `version.rb:27` 39.0, `user_agent.rb:25` 11.7 |
| ruby default gem: base64 | 202.8 | 212.0 | `base64.rb:283` 102.8, `base64.rb:310` 51.9, `base64.rb:374` 48.0 |
| rails: activejob | 125.4 | 132.0 | `log_subscriber.rb:192` 78.9, `log_subscriber.rb:148` 9.0, `arguments.rb:92` 6.2 |
| gem: rack | 60.3 | 62.5 | `body_proxy.rb:12` 4.9, `query_parser.rb:259` 4.8, `utils.rb:331` 3.9 |
| ruby default gem: logger | 55.0 | 56.5 | `logger.rb:692` 14.1, `log_device.rb:165` 14.1, `log_device.rb:33` 14.1 |
| ruby default gem: securerandom | 49.0 | 51.3 | `securerandom.rb:71` 49.0 |
| gem: importmap-rails | 28.0 | 29.5 | `importmap_tags_helper.rb:44` 10.0, `importmap_tags_helper.rb:30` 6.7, `importmap_tags_helper.rb:42` 4.3 |
| gem: web-console | 26.3 | 27.0 | `permissions.rb:39` 13.7, `permissions.rb:21` 3.9, `request.rb:32` 2.0 |
| gem: globalid | 18.0 | 19.0 | `gid.rb:95` 4.8, `gid.rb:159` 3.8, `gid.rb:166` 1.9 |
| rails: railties | 17.9 | 18.5 | `backtrace_cleaner.rb:21` 4.3, `finisher.rb:195` 2.9, `logger.rb:57` 2.9 |
| gem: turbo-rails | 16.8 | 17.5 | `stream_name.rb:26` 2.9, `broadcastable.rb:184` 2.4, `broadcastable.rb:456` 1.9 |
| gem: json | 15.5 | 16.0 | `common.rb:298` 12.6, `common.rb:378` 2.0, `common.rb:775` 0.5 |
| gem: concurrent-ruby | 15.2 | 15.9 | `non_concurrent_map_backend.rb:26` 7.0, `non_concurrent_map_backend.rb:120` 2.4, `mri_map_backend.rb:14` 2.4 |
| gem: sprockets-rails | 12.3 | 13.0 | `helper.rb:81` 1.9, `helper.rb:357` 1.9, `helper.rb:186` 1.9 |
| gem: tzinfo | 8.6 | 9.0 | `timestamp.rb:208` 3.8, `constant_offset_data_timezone_info.rb:52` 1.9, `timestamp.rb:193` 1.9 |
| gem: rack-session | 2.9 | 3.0 | `id.rb:275` 1.0, `id.rb:401` 1.0, `id.rb:277` 1.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Jobs

| # | Job | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | Turbo::Streams::ActionBroadcastJob#perform | 20 / 20 | 3401.1 / 3401.4 | 0.3 | 3376.9 | `RAILS/activesupport/lib/active_support/json/encoding.rb:65` 33.0, `RAILS/activesupport/lib/active_support/json/encoding.rb:66` 32.0, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 24.0 | `app/views/articles/_article.html.erb:6` 227.0, `app/views/articles/_article.html.erb:14` 64.0, `app/views/articles/_article.html.erb:4` 31.0 |

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
