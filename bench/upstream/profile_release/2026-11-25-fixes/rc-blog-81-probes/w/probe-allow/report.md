# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails runner /home/user/.local/share/mise/installs/ruby/4.0.7/lib/ruby/gems/4.0.0/gems/lowrail-profile-0.1.0.rc1/lib/lowrail/profile_workloads.rb /home/user/workspace/repo/bench/upstream/profile_release/2026-11-25-fixes/rc-blog-81-probes/w/probe.rb /home/user/workspace/repo/bench/upstream/profile_release/2026-11-25-fixes/rc-blog-81-probes/w/probe-allow/workloads.json`
* Ruby: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux]
* Rails: 8.1.4, development environment
* Counted in run 1: 40 requests; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 40 | 150139.7 | 0 | 0 | 0 | 0 |
| run2 | 1 | 40 | 150139.7 | 0 | 0 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.0 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/views/articles/_article.html.erb:15` |  | 2813.9 | 0.0 | 149.63 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 13%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 10%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 4% | ArticlesController#index 100% | `</div>` |
| 2 | `app/views/articles/index.html.erb:27` |  | 1057.83 | 499.22 | 0.0 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` 15%, `RAILS/activerecord/lib/active_record/associations/preloader/association.rb:172` 6%, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:102` 6% | ArticlesController#index 100% | `<% else %>` |
| 3 | `app/views/articles/_article.html.erb:5` |  | 688.27 | 0.0 | 59.85 | `RAILS/activerecord/lib/active_record/integration.rb:59` 13%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 9%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 9% | ArticlesController#index 100% | `<span id="<%= dom_id(article, :comments_count) %>" class="text-gray-50` |
| 4 | `app/views/articles/_article.html.erb:13` |  | 658.35 | 0.0 | 89.78 | `RAILS/activerecord/lib/active_record/integration.rb:59` 14%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 9%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 9% | ArticlesController#index 100% | `<%= link_to "Edit", edit_article_path(article), class: "w-full sm:w-au` |
| 5 | `app/views/articles/_article.html.erb:14` |  | 538.65 | 0.0 | 119.7 | `RAILS/activerecord/lib/active_record/integration.rb:59` 17%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 11%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 11% | ArticlesController#index 100% | `<%= button_to "Destroy", article, method: :delete, class: "w-full sm:w` |
| 6 | `app/views/articles/_article.html.erb:7` |  | 357.2 | 0.0 | 29.93 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 17%, `RAILS/activerecord/lib/active_record/relation.rb:77` 17%, `RAILS/activesupport/lib/active_support/inflector/methods.rb:382` 16% | ArticlesController#index 100% | `</span>` |
| 7 | `app/views/articles/_article.html.erb:6` |  | 149.63 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/record_identifier.rb:136` 40%, `RAILS/actionview/lib/action_view/record_identifier.rb:80` 20%, `RAILS/activerecord/lib/active_record/attribute_methods/primary_key.rb:13` 20% | ArticlesController#index 100% | `(<%= pluralize(article.comments.size, "comment") %>)` |
| 8 | `app/views/articles/_article.html.erb:2` |  | 119.7 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/record_identifier.rb:136` 50%, `RAILS/actionview/lib/action_view/record_identifier.rb:98` 25%, `RAILS/activerecord/lib/active_record/attribute_methods/primary_key.rb:13` 25% | ArticlesController#index 100% | `<div class="p-4 border rounded mb-4 flex-grow">` |
| 9 | `app/views/articles/_article.html.erb:10` |  | 92.63 | 0.0 | 29.93 | `RAILS/activemodel/lib/active_model/type/string.rb:39` 32%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 32%, `RAILS/activesupport/lib/active_support/core_ext/string/filters.rb:71` 31% | ArticlesController#index 100% | `</div>` |
| 10 | `app/views/articles/index.html.erb:16` |  | 55.85 | 0.0 | 0.0 | `GEM/uri/lib/uri/common.rb:465` 15%, `GEM/json/lib/json/common.rb:298` 9%, `RAILS/activesupport/lib/active_support/key_generator.rb:63` 4% | ArticlesController#index 100% | `<p class="py-2 px-3 bg-green-50 mb-5 text-green-500 font-medium rounde` |
| 11 | `app/views/articles/index.html.erb:26` |  | 41.33 | 159.6 | 0.48 | `RAILS/activerecord/lib/active_record/relation/finder_methods.rb:445` 5%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 5%, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 3% | ArticlesController#index 100% | `<%= render @articles %>` |
| 12 | `app/views/layouts/application.html.erb:24` |  | 40.38 | 24.7 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 20%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 20%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 15% | ArticlesController#index 100% | `</head>` |
| 13 | `app/views/layouts/application.html.erb:23` |  | 30.4 | 34.68 | 1.43 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 9%, `RAILS/actionview/lib/action_view/helpers/asset_tag_helper.rb:679` 9%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 8% | ArticlesController#index 100% | `<%= javascript_importmap_tags %>` |
| 14 | `app/views/layouts/application.html.erb:10` |  | 18.05 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 11%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 11%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 8% | ArticlesController#index 100% | `<%= csp_meta_tag %>` |
| 15 | `app/views/articles/index.html.erb:2` |  | 13.77 | 0.0 | 1.43 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:329` 14%, `GEM/turbo-rails/app/channels/turbo/streams/stream_name.rb:26` 10%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 7% | ArticlesController#index 100% | `` |
| 16 | `app/controllers/articles_controller.rb:6` | `index` | 12.82 | 0.0 | 0.95 | `RAILS/activerecord/lib/active_record/relation/query_methods.rb:2117` 19%, `RAILS/activerecord/lib/active_record/relation/query_methods.rb:2154` 11%, `RAILS/activerecord/lib/active_record/relation.rb:98` 7% | ArticlesController#index 100% | `@articles = Article.includes(:comments).order(created_at: :desc)` |
| 17 | `app/views/articles/index.html.erb:22` |  | 7.6 | 0.0 | 1.9 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 13%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 13%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:51` 6% | ArticlesController#index 100% | `</div>` |
| 18 | `app/views/articles/index.html.erb:13` |  | 5.7 | 0.0 | 0.0 | `GEM/turbo-rails/app/helpers/turbo/drive_helper.rb:27` 25%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 17%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 17% | ArticlesController#index 100% | `` |
| 19 | `app/views/layouts/application.html.erb:13` |  | 1.42 | 0.0 | 0.48 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 33%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 33%, `RAILS/actionview/lib/action_view/renderer/template_renderer.rb:77` 33% | ArticlesController#index 100% | `` |
| 20 | `app/views/articles/index.html.erb:4` |  | 0.95 | 0.0 | 0.48 | `RAILS/actionview/lib/action_view/helpers/capture_helper.rb:172` 50%, `RAILS/actionview/lib/action_view/flows.rb:10` 50% | ArticlesController#index 100% | `` |
| 21 | `app/views/layouts/application.html.erb:29` |  | 0.95 | 0.0 | 0.48 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 50%, `RAILS/actionview/lib/action_view/renderer/template_renderer.rb:77` 50% | ArticlesController#index 100% | `</main>` |
| 22 | `app/views/layouts/application.html.erb:5` |  | 0.48 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/helpers/capture_helper.rb:172` 100% | ArticlesController#index 100% | `<meta name="viewport" content="width=device-width,initial-scale=1">` |
| 23 | `app/views/articles/_article.html.erb:1` |  | 0.0 | 0.0 | 59.85 |  |  | `<div id="<%= dom_id(article) %>" class="flex flex-col sm:flex-row just` |
| 24 | `app/views/articles/_article.html.erb:19` |  | 0.0 | 0.0 | 29.93 |  |  | `` |
| 25 | `app/views/articles/index.html.erb:1` |  | 0.0 | 0.0 | 0.95 |  |  | `<%= turbo_stream_from "articles" %>` |
| 26 | `app/views/articles/index.html.erb:34` |  | 0.0 | 0.0 | 0.48 |  |  | `` |
| 27 | `app/views/layouts/application.html.erb:1` |  | 0.0 | 0.0 | 0.95 |  |  | `<!DOCTYPE html>` |
| 28 | `app/views/layouts/application.html.erb:11` |  | 0.0 | 0.0 | 0.48 |  |  | `` |
| 29 | `app/views/layouts/application.html.erb:34` |  | 0.0 | 0.0 | 0.48 |  |  | `` |

4106.93 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | ArticlesController#create | 20 / 20 | 278761.5 / 278761.4 | -0.1 | 278761.3 | `RAILS/actionview/lib/action_view/buffers.rb:44` 1314.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 603.0, `RAILS/actionview/lib/action_view/helpers/url_helper.rb:438` 588.0 |  |
| 2 | ArticlesController#index | 20 / 20 | 18855.9 / 18856.3 | 0.4 | 18856.1 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 1167.0, `RAILS/activerecord/lib/active_record/integration.rb:59` 756.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 596.0 | `app/views/articles/_article.html.erb:15` 5924.0, `app/views/articles/index.html.erb:27` 2227.0, `app/views/articles/_article.html.erb:5` 1449.0 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `RAILS/actionview/lib/action_view/buffers.rb:44` † | `<<` | 624.15 / 624.15 | 0.0 | 657.0 | 50% | String |  | `no app frame` 100% | `value = value.to_s` |
| 2 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` | `html_safe` | 584.6 / 584.6 | 0.0 | 599.5 | 100% | String |  | `no app frame` 50%, `app/views/articles/_article.html.erb:15` 21% | `ActiveSupport::SafeBuffer.new(self)` |
| 3 | `RUBY/ipaddr.rb:758` | `in6_addr` | 566.47 / 566.47 | 0.0 | 581.03 | 100% | Data, Array |  | `no app frame` 100% | `raise InvalidAddressError, "invalid address: #{@addr}"` |
| 4 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` | `tag_option` | 554.83 / 554.83 | 0.0 | 584.0 | 100% | String |  | `app/views/articles/_article.html.erb:15` 65%, `app/views/articles/_article.html.erb:14` 11% | `%(#{key}="#{value}")` |
| 5 | `RAILS/activerecord/lib/active_record/integration.rb:59` | `to_param` | 359.1 / 359.1 | 0.0 | 378.0 | 50% | String, Array |  | `app/views/articles/_article.html.erb:5` 25%, `app/views/articles/_article.html.erb:13` 25% | `Array(id).join(self.class.param_delimiter)` |
| 6 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:11` | `html_escape` | 294.48 / 294.48 | 0.0 | 294.5 | 100% | String |  | `no app frame` 100%, `app/views/layouts/application.html.erb:10` 0% | `s = s.to_s` |
| 7 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` | `xml_name_escape` | 281.7 / 281.7 | 0.0 | 296.5 | 100% | String |  | `app/views/articles/_article.html.erb:15` 96%, `app/views/layouts/application.html.erb:24` 3% | `name = name.to_s` |
| 8 | `RAILS/actionview/lib/action_view/helpers/url_helper.rb:438` | `link_to_if` | 279.3 / 279.3 | 0.0 | 294.0 | 50% | Hash |  | `no app frame` 100% | `def link_to_if(condition, name, options = {}, html_options = {}, &bloc` |
| 9 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` | `initialize` | 260.63 / 260.63 | 0.0 | 274.0 | 100% | String |  | `app/views/articles/_article.html.erb:15` 46%, `app/views/articles/index.html.erb:27` 12% | `super` |
| 10 | `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` | `evaluate` | 240.35 / 240.35 | 0.0 | 253.0 | 50% | Array |  | `app/views/articles/_article.html.erb:5` 25%, `app/views/articles/_article.html.erb:14` 25% | `parts = @parts.dup` |
| 11 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:237` | `tag_options` | 217.58 / 217.58 | 0.0 | 229.0 | 100% | String |  | `app/views/articles/_article.html.erb:15` 55%, `app/views/articles/_article.html.erb:14` 14% | `output = +""` |
| 12 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` | `each` | 157.23 / 157.23 | 0.0 | 165.5 | 50% | String, Array |  | `app/views/articles/index.html.erb:27` 100%, `app/views/articles/index.html.erb:26` 0% | `val = step` |
| 13 | `RAILS/activesupport/lib/active_support/core_ext/hash/keys.rb:11` | `stringify_keys` | 153.95 / 153.95 | 0.0 | 162.0 | 100% | Hash |  | `app/views/articles/_article.html.erb:15` 39%, `app/views/articles/_article.html.erb:5` 19% | `transform_keys { \|k\| Symbol === k ? k.name : k.to_s }` |
| 14 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:232` | `content_tag_string` | 152.03 / 152.03 | 0.0 | 160.0 | 100% | String |  | `app/views/articles/_article.html.erb:15` 39%, `app/views/articles/_article.html.erb:5` 20% | `"<#{name}#{tag_options}>#{PRE_CONTENT_STRINGS[name]}#{content}</#{name` |
| 15 | `RAILS/actionpack/lib/action_controller/metal/request_forgery_protection.rb:321` | `handle_unverified_request` | 142.98 / 142.98 | 0.0 | 150.5 | 50% | Data, Array |  | `no app frame` 100% | `raise ActionController::InvalidAuthenticityToken, warning_message` |
| 16 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:15` | `html_escape` | 127.78 / 127.78 | 0.0 | 134.5 | 50% | String |  | `no app frame` 100% | `super(s)` |
| 17 | `RAILS/actionpack/lib/action_controller/metal/url_for.rb:49` | `url_options` | 120.18 / 120.18 | 0.0 | 126.5 | 50% | Hash |  | `app/views/articles/_article.html.erb:13` 25%, `app/views/articles/_article.html.erb:14` 25% | `options = @_url_options.dup` |
| 18 | `RAILS/actionpack/lib/action_dispatch/http/url.rb:170` | `path_for` | 120.18 / 120.18 | 0.0 | 126.5 | 50% | String |  | `app/views/articles/_article.html.erb:5` 25%, `app/views/articles/_article.html.erb:13` 25% | `path = options[:script_name].to_s.chomp("/")` |
| 19 | `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:51` | `evaluate` | 120.18 / 120.18 | 0.0 | 126.5 | 50% | String |  | `app/views/articles/_article.html.erb:14` 25%, `app/views/articles/_article.html.erb:5` 25% | `parts.join` |
| 20 | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:214` | `call` | 120.18 / 120.18 | 0.0 | 126.5 | 50% | Hash |  | `app/views/articles/_article.html.erb:5` 25%, `app/views/articles/_article.html.erb:14` 25% | `options = t.url_options.merge @options` |
| 21 | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:248` | `parameterize_args` | 120.18 / 120.18 | 0.0 | 126.5 | 50% | Hash |  | `app/views/articles/_article.html.erb:13` 25%, `app/views/articles/_article.html.erb:15` 25% | `params = {}` |
| 22 | `RAILS/actionpack/lib/action_dispatch/journey/router/utils.rb:73` | `escape` | 119.7 / 119.7 | 0.0 | 126.0 | 50% | String |  | `app/views/articles/_article.html.erb:14` 25%, `app/views/articles/_article.html.erb:5` 25% | `component.gsub(pattern) { \|unsafe\| percent_encode(unsafe) }.force_enco` |
| 23 | `RAILS/actionview/lib/action_view/record_identifier.rb:136` | `record_key_for_dom_id` | 119.7 / 119.7 | 0.0 | 126.0 | 50% | String |  | `app/views/articles/_article.html.erb:6` 50%, `app/views/articles/_article.html.erb:2` 50% | `key && key.all? ? key.join(JOIN) : nil` |
| 24 | `RAILS/actionpack/lib/action_controller/metal/rescue.rb:39` | `process_action` | 99.75 / 99.75 | 0.0 | 105.0 | 50% | String, Array |  | `no app frame` 100% | `rescue_with_handler(exception) \|\| raise` |
| 25 | `RAILS/actionpack/lib/action_controller/metal/request_forgery_protection.rb:584` | `per_form_csrf_token` | 89.78 / 89.78 | 0.0 | 94.5 | 50% | String, Array |  | `app/views/articles/_article.html.erb:15` 100% | `csrf_token_hmac(session, [action_path, method.downcase].join("#"))` |
| 26 | `RAILS/actionpack/lib/action_dispatch/routing/polymorphic_routes.rb:271` | `handle_model` | 89.78 / 89.78 | 0.0 | 94.5 | 50% | Array |  | `app/views/articles/_article.html.erb:15` 33%, `app/views/articles/_article.html.erb:5` 33% | `args  = []` |
| 27 | `RAILS/actionpack/lib/action_dispatch/routing/polymorphic_routes.rb:281` | `handle_model` | 89.78 / 89.78 | 0.0 | 94.5 | 50% | Array |  | `app/views/articles/_article.html.erb:5` 33%, `app/views/articles/_article.html.erb:15` 33% | `[named_route, args]` |
| 28 | `RAILS/actionpack/lib/action_dispatch/routing/polymorphic_routes.rb:289` | `handle_model_call` | 89.78 / 89.78 | 0.0 | 94.5 | 50% | Array |  | `app/views/articles/_article.html.erb:5` 33%, `app/views/articles/_article.html.erb:15` 33% | `target.public_send(method, *args)` |
| 29 | `RAILS/actionpack/lib/action_dispatch/routing/polymorphic_routes.rb:353` | `get_method_for_string` | 89.78 / 89.78 | 0.0 | 94.5 | 50% | String |  | `app/views/articles/_article.html.erb:5` 33%, `app/views/articles/_article.html.erb:13` 33% | `"#{prefix}#{str}_#{suffix}"` |
| 30 | `RUBY/ipaddr.rb:802` | `_to_string` | 74.1 / 74.1 | 0.0 | 76.0 | 100% | String, MatchData |  | `no app frame` 100% | `return (("%.32x" % addr).gsub!(/.{4}(?!$)/, '\&:'))` |

## Dev/test-mode work

130179.1 of 141060.6 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | error page | `RUBY/error_highlight/base.rb:94` | 70066.3 | 50% | `no app frame` 100% | `Prism.parse_file(absolute_path).value.breadth_first_search { \|node\| no` |
| 2 | error page | `GEM/prism/lib/prism/parse_result.rb:162` | 25263.35 | 50% | `no app frame` 100% | `source.lines` |
| 3 | error page | `RUBY/error_highlight/base.rb:59` † | 8699.63 | 50% | `no app frame` 100% | `RubyVM::AbstractSyntaxTree.of(loc, keep_script_lines: true)` |
| 4 | error page | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:195` | 3356.68 | 100% | `no app frame` 91%, `app/views/articles/index.html.erb:27` 7% | `add_filter { \|line\| line.sub(gems_regexp, gems_result) }` |
| 5 | error page | `GEM/prism/lib/prism/node.rb:4628` | 2397.8 | 50% | `no app frame` 100% | `compact = [] #: Array[Prism::node]` |
| 6 | error page | `RAILS/actionpack/lib/action_dispatch/middleware/exception_wrapper.rb:332` | 2039.18 | 50% | `no app frame` 100% | `lines = source_lines.drop(start).take(6)` |
| 7 | error page | `GEM/prism/lib/prism/node.rb:30908` | 1930.4 | 50% | `no app frame` 100% | `[*body]` |
| 8 | error page | `GEM/prism/lib/prism/node.rb:10815` | 1084.43 | 50% | `no app frame` 100% | `compact = [] #: Array[Prism::node]` |
| 9 | error page | `GEM/prism/lib/prism/node.rb:1312` | 1072.08 | 50% | `no app frame` 100% | `[*arguments]` |
| 10 | error page | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:74` | 1000.83 | 100% | `no app frame` 83%, `app/views/articles/index.html.erb:27` 13% | `frame = frame.to_s` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| ruby stdlib | 80245.9 | 84448.0 | `base.rb:94` 70066.3, `base.rb:59` 8699.6, `ipaddr.rb:758` 566.5 |
| ruby default gem: prism | 41011.0 | 43169.5 | `parse_result.rb:162` 25263.4, `node.rb:4628` 2397.8, `node.rb:30908` 1930.4 |
| rails: activesupport | 7703.5 | 7859.5 | `backtrace_cleaner.rb:195` 3356.7, `backtrace_cleaner.rb:74` 1000.8, `backtrace_cleaner.rb:212` 805.6 |
| rails: actionpack | 5734.1 | 6031.5 | `exception_wrapper.rb:332` 2039.2, `exception_wrapper.rb:333` 608.5, `visitors.rb:40` 240.4 |
| rails: actionview | 3505.5 | 3684.5 | `buffers.rb:44` 624.2, `tag_helper.rb:309` 554.8, `url_helper.rb:438` 279.3 |
| rails: activerecord | 1288.9 | 1356.5 | `integration.rb:59` 359.1, `delegation.rb:139` 63.2, `relation.rb:77` 63.2 |
| app | 579.5 | 610.0 | `_article.html.erb:15` 149.6, `_article.html.erb:14` 119.7, `_article.html.erb:13` 89.8 |
| gem: erubi | 368.1 | 387.5 | `erubi.rb:134` 206.2, `erubi.rb:137` 46.6, `erubi.rb:139` 24.7 |
| ruby default gem: uri | 276.8 | 290.3 | `rfc3986_parser.rb:115` 59.9, `rfc3986_parser.rb:135` 29.9, `generic.rb:516` 29.9 |
| gem: sqlite3 | 162.9 | 171.5 | `statement.rb:159` 157.2, `database.rb:215` 1.4, `statement.rb:217` 1.4 |
| rails: activemodel | 155.8 | 164.0 | `string.rb:39` 59.9, `builder.rb:28` 31.4, `builder.rb:16` 31.4 |
| gem: base64 | 97.5 | 102.5 | `base64.rb:310` 34.3, `base64.rb:283` 32.8, `base64.rb:374` 30.4 |
| gem: useragent | 93.6 | 98.5 | `base.rb:120` 37.1, `version.rb:27` 13.3, `user_agent.rb:25` 5.7 |
| gem: concurrent-ruby | 48.4 | 50.0 | `non_concurrent_map_backend.rb:131` 10.0, `map.rb:245` 8.6, `non_concurrent_map_backend.rb:120` 6.7 |
| gem: bootsnap | 47.0 | 49.5 | `kernel_require.rb:11` 47.0 |
| gem: logger | 42.5 | 44.0 | `logger.rb:692` 10.6, `log_device.rb:33` 10.6, `log_device.rb:165` 10.6 |
| gem: propshaft | 40.1 | 42.0 | `helper.rb:113` 19.0, `asset.rb:73` 7.6, `dynamic.rb:11` 3.8 |
| gem: rack | 38.0 | 39.5 | `utils.rb:331` 3.9, `body_proxy.rb:12` 3.9, `request.rb:607` 3.4 |
| gem: web-console | 35.6 | 36.5 | `permissions.rb:39` 21.5, `permissions.rb:21` 3.9, `request.rb:12` 2.0 |
| ruby default gem: securerandom | 31.4 | 33.0 | `securerandom.rb:71` 31.4 |
| ruby default gem: prettyprint | 28.5 | 30.0 | `prettyprint.rb:404` 7.6, `prettyprint.rb:264` 7.1, `prettyprint.rb:459` 4.8 |
| gem: importmap-rails | 24.7 | 26.0 | `importmap_tags_helper.rb:30` 6.7, `importmap_tags_helper.rb:44` 6.7, `importmap_tags_helper.rb:42` 4.3 |
| gem: nokogiri | 19.5 | 20.5 | `document.rb:416` 2.9, `node.rb:66` 2.8, `document_fragment.rb:169` 1.9 |
| ruby default gem: pp | 13.8 | 14.5 | `pp.rb:542` 5.7, `pp.rb:271` 2.9, `pp.rb:550` 2.4 |
| gem: json | 13.0 | 13.4 | `common.rb:298` 11.1, `common.rb:861` 1.0, `common.rb:769` 0.5 |
| rails: railties | 12.6 | 13.0 | `backtrace_cleaner.rb:21` 2.9, `logger.rb:57` 2.0, `finisher.rb:194` 1.0 |
| gem: turbo-rails | 6.7 | 7.0 | `drive_helper.rb:27` 1.4, `stream_name.rb:26` 1.4, `streams_helper.rb:61` 1.0 |
| gem: loofah | 5.2 | 5.5 | `concerns.rb:172` 1.9, `concerns.rb:43` 1.4, `scrubber.rb:132` 1.0 |
| ruby default gem: erb | 4.3 | 4.5 | `util.rb:65` 4.3 |
| gem: rails-html-sanitizer | 3.3 | 3.5 | `sanitizer.rb:33` 0.5, `sanitizer.rb:56` 0.5, `scrubbers.rb:55` 0.5 |
| gem: rack-session | 1.4 | 1.5 | `id.rb:401` 0.5, `id.rb:277` 0.5, `id.rb:275` 0.5 |
| gem: i18n | 1.0 | 1.0 | `simple.rb:51` 1.0 |
