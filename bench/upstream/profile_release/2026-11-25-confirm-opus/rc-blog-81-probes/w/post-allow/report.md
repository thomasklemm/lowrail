# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails runner /home/user/.local/share/mise/installs/ruby/4.0.7/lib/ruby/gems/4.0.0/gems/lowrail-profile-0.1.0.rc1/lib/lowrail/profile_workloads.rb /home/user/workspace/repo/bench/upstream/profile_release/2026-11-25-confirm-opus/rc-blog-81-probes/w/post.rb /home/user/workspace/repo/bench/upstream/profile_release/2026-11-25-confirm-opus/rc-blog-81-probes/w/post-allow/workloads.json`
* Ruby: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux]
* Rails: 8.1.4, development environment
* Counted in run 1: 40 requests, 21 jobs; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 40 | 7565.9 | 21 | 0 | 0 | 0 |
| run2 | 1 | 40 | 11208.3 | 21 | 0 | 0 | 0 |

run1 left windows unfinished (1 job), which no line or action counts; compare refuses it.

run2 left windows unfinished (1 job), which no line or action counts; compare refuses it.

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 57.0, max |Δ| 256.5 objects per request; 26 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/views/articles/_article.html.erb:15` |  | 2367.4 | 0.0 | 125.88 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 13%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 10%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:237` 4% | ArticlesController#index 100% | `</div>` |
| 2 | `app/views/articles/index.html.erb:27` |  | 924.83 | 489.73 | 0.0 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` 14%, `RAILS/activerecord/lib/active_record/associations/preloader/branch.rb:102` 5%, `RAILS/activerecord/lib/active_record/associations/preloader/association.rb:172` 5% | ArticlesController#index 100% | `<% else %>` |
| 3 | `app/views/articles/_article.html.erb:5` |  | 579.03 | 0.0 | 50.35 | `RAILS/activerecord/lib/active_record/integration.rb:59` 13%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 9%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 9% | ArticlesController#index 100% | `<span id="<%= dom_id(article, :comments_count) %>" class="text-gray-50` |
| 4 | `app/views/articles/_article.html.erb:13` |  | 553.85 | 0.0 | 75.53 | `RAILS/activerecord/lib/active_record/integration.rb:59` 14%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 9%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 9% | ArticlesController#index 100% | `<%= link_to "Edit", edit_article_path(article), class: "w-full sm:w-au` |
| 5 | `app/views/articles/_article.html.erb:14` |  | 453.15 | 0.0 | 100.7 | `RAILS/activerecord/lib/active_record/integration.rb:59` 17%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 11%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 11% | ArticlesController#index 100% | `<%= button_to "Destroy", article, method: :delete, class: "w-full sm:w` |
| 6 | `app/views/articles/_article.html.erb:7` |  | 300.2 | 0.0 | 25.18 | `RAILS/activerecord/lib/active_record/relation.rb:77` 17%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 17%, `RAILS/activesupport/lib/active_support/inflector/methods.rb:382` 16% | ArticlesController#index 100% | `</span>` |
| 7 | `app/controllers/articles_controller.rb:27` | `create` | 225.07 | 943.75 | 0.0 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 4%, `RUBY/random/formatter.rb:174` 3%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:149` 3% | ArticlesController#create 100% | `if @article.save` |
| 8 | `app/views/articles/_article.html.erb:6` |  | 125.88 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/record_identifier.rb:136` 40%, `RAILS/activerecord/lib/active_record/attribute_methods/primary_key.rb:13` 20%, `RAILS/actionview/lib/action_view/record_identifier.rb:80` 20% | ArticlesController#index 100% | `(<%= pluralize(article.comments.size, "comment") %>)` |
| 9 | `app/views/articles/_article.html.erb:2` |  | 100.7 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/record_identifier.rb:136` 50%, `RAILS/actionview/lib/action_view/record_identifier.rb:98` 25%, `RAILS/activerecord/lib/active_record/attribute_methods/primary_key.rb:13` 25% | ArticlesController#index 100% | `<div class="p-4 border rounded mb-4 flex-grow">` |
| 10 | `app/views/articles/_article.html.erb:10` |  | 78.38 | 0.0 | 25.18 | `RAILS/activemodel/lib/active_model/type/string.rb:39` 32%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 32%, `RAILS/activesupport/lib/active_support/core_ext/string/filters.rb:71` 30% | ArticlesController#index 100% | `</div>` |
| 11 | `app/views/articles/index.html.erb:16` |  | 60.0 | 0.0 | 0.0 | `GEM/uri/lib/uri/common.rb:465` 18%, `GEM/json/lib/json/common.rb:298` 12%, `RAILS/activesupport/lib/active_support/key_generator.rb:63` 4% | ArticlesController#index 100% | `<p class="py-2 px-3 bg-green-50 mb-5 text-green-500 font-medium rounde` |
| 12 | `app/controllers/articles_controller.rb:28` | `create` | 41.8 | 72.68 | 1.43 | `GEM/uri/lib/uri/rfc3986_parser.rb:85` 5%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:208` 5%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 5% | ArticlesController#create 100% | `format.html { redirect_to @article, notice: "Article was successfully ` |
| 13 | `app/views/articles/index.html.erb:26` |  | 41.33 | 159.22 | 0.48 | `RAILS/activerecord/lib/active_record/relation/finder_methods.rb:445` 5%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 5%, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 3% | ArticlesController#index 100% | `<%= render @articles %>` |
| 14 | `app/views/layouts/application.html.erb:24` |  | 40.37 | 24.7 | 0.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 20%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 20%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 15% | ArticlesController#index 100% | `</head>` |
| 15 | `app/views/layouts/application.html.erb:23` |  | 30.4 | 34.68 | 1.43 | `RAILS/actionview/lib/action_view/helpers/asset_tag_helper.rb:679` 9%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 9%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 8% | ArticlesController#index 100% | `<%= javascript_importmap_tags %>` |
| 16 | `app/controllers/articles_controller.rb:68` | `article_params` | 23.28 | 0.0 | 1.43 | `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:75` 12%, `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:405` 12%, `RAILS/activesupport/lib/active_support/core_ext/array/wrap.rb:45` 10% | ArticlesController#create 100% | `params.expect(article: [ :title, :body ])` |
| 17 | `app/views/layouts/application.html.erb:10` |  | 18.05 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 11%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 11%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 8% | ArticlesController#index 100% | `<%= csp_meta_tag %>` |
| 18 | `app/views/articles/index.html.erb:2` |  | 13.77 | 0.0 | 1.43 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:329` 14%, `GEM/turbo-rails/app/channels/turbo/streams/stream_name.rb:26` 10%, `GEM/turbo-rails/app/helpers/turbo/streams_helper.rb:61` 7% | ArticlesController#index 100% | `` |
| 19 | `app/controllers/articles_controller.rb:6` | `index` | 12.82 | 0.0 | 0.95 | `RAILS/activerecord/lib/active_record/relation/query_methods.rb:2117` 19%, `RAILS/activerecord/lib/active_record/relation/query_methods.rb:2154` 11%, `RAILS/activerecord/lib/active_record/relation.rb:98` 7% | ArticlesController#index 100% | `@articles = Article.includes(:comments).order(created_at: :desc)` |
| 20 | `app/controllers/articles_controller.rb:24` | `create` | 7.6 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:101` 25%, `RAILS/activemodel/lib/active_model/attribute.rb:13` 12%, `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:281` 12% | ArticlesController#create 100% | `@article = Article.new(article_params)` |
| 21 | `app/views/articles/index.html.erb:22` |  | 7.6 | 0.0 | 1.9 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 13%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 13%, `RAILS/actionpack/lib/action_controller/metal/url_for.rb:38` 6% | ArticlesController#index 100% | `</div>` |
| 22 | `app/controllers/articles_controller.rb:26` | `create` | 6.33 | 0.0 | 0.48 | `RAILS/actionpack/lib/action_dispatch/http/mime_type.rb:299` 15%, `RAILS/actionpack/lib/action_dispatch/http/response.rb:510` 15%, `RAILS/actionpack/lib/action_dispatch/http/response.rb:496` 15% | ArticlesController#create 100% | `respond_to do \|format\|` |
| 23 | `app/views/articles/index.html.erb:13` |  | 5.7 | 0.0 | 0.0 | `GEM/turbo-rails/app/helpers/turbo/drive_helper.rb:27` 25%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 17%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 17% | ArticlesController#index 100% | `` |
| 24 | `app/views/layouts/application.html.erb:13` |  | 1.42 | 0.0 | 0.48 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 33%, `RAILS/actionview/lib/action_view/renderer/template_renderer.rb:77` 33%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 33% | ArticlesController#index 100% | `` |
| 25 | `app/controllers/articles_controller.rb:29` | `create` | 0.95 | 0.0 | 0.0 | `RAILS/actionpack/lib/action_controller/metal/mime_responds.rb:274` 50%, `RAILS/actionpack/lib/action_dispatch/http/mime_type.rb:176` 50% | ArticlesController#create 100% | `format.json { render :show, status: :created, location: @article }` |
| 26 | `app/views/articles/index.html.erb:4` |  | 0.95 | 0.0 | 0.48 | `RAILS/actionview/lib/action_view/helpers/capture_helper.rb:172` 50%, `RAILS/actionview/lib/action_view/flows.rb:10` 50% | ArticlesController#index 100% | `` |
| 27 | `app/views/layouts/application.html.erb:29` |  | 0.95 | 0.0 | 0.48 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 50%, `RAILS/actionview/lib/action_view/renderer/template_renderer.rb:77` 50% | ArticlesController#index 100% | `</main>` |
| 28 | `app/views/articles/index.html.erb:17` |  | 0.48 | 0.0 | 0.0 | `RAILS/actionpack/lib/action_dispatch/middleware/flash.rb:170` 100% | ArticlesController#index 100% | `<% end %>` |
| 29 | `app/views/layouts/application.html.erb:5` |  | 0.48 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/helpers/capture_helper.rb:172` 100% | ArticlesController#index 100% | `<meta name="viewport" content="width=device-width,initial-scale=1">` |
| 30 | `app/models/article.rb:6` |  | 0.0 | 0.0 | 0.48 |  |  | `broadcasts_to ->(_article) { "articles" }, inserts_by: :prepend` |

1531.03 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | ArticlesController#index | 20 / 20 | 9669.9 / 16563.3 | 6893.4 | 16448.5 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 987.0, `RAILS/activerecord/lib/active_record/integration.rb:59` 636.0, `RUBY/ipaddr.rb:758` 581.0 | `app/views/articles/_article.html.erb:15` 4984.0, `app/views/articles/index.html.erb:27` 1947.0, `app/views/articles/_article.html.erb:5` 1219.0 |
| 2 | ArticlesController#create | 20 / 20 | 4699.9 / 4702.3 | 2.4 | 4702.4 | `RUBY/ipaddr.rb:758` 581.0, `GEM/useragent/lib/user_agent/browsers/base.rb:120` 78.0, `RUBY/ipaddr.rb:802` 76.0 | `app/controllers/articles_controller.rb:27` 473.8, `app/controllers/articles_controller.rb:28` 88.0, `app/controllers/articles_controller.rb:68` 49.0 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `RUBY/ipaddr.rb:758` | `in6_addr` | 566.47 / 566.47 | 0.0 | 581.03 | 100% | Data, Array |  | `no app frame` 100% | `raise InvalidAddressError, "invalid address: #{@addr}"` |
| 2 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` | `tag_option` | 212.33 / 468.83 | 256.5 | 354.0 | 50% | String |  | `app/views/articles/_article.html.erb:15` 64%, `app/views/articles/_article.html.erb:5` 11% | `%(#{key}="#{value}")` |
| 3 | `RAILS/activerecord/lib/active_record/integration.rb:59` | `to_param` | 132.6 / 303.6 | 171.0 | 226.5 | 100% | String, Array |  | `app/views/articles/_article.html.erb:5` 25%, `app/views/articles/_article.html.erb:13` 25% | `Array(id).join(self.class.param_delimiter)` |
| 4 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` | `html_safe` | 112.1 / 240.35 | 128.25 | 183.25 | 50% | String |  | `app/views/articles/_article.html.erb:15` 42%, `app/views/articles/index.html.erb:27` 11% | `ActiveSupport::SafeBuffer.new(self)` |
| 5 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` | `xml_name_escape` | 110.2 / 238.45 | 128.25 | 181.25 | 50% | String |  | `app/views/articles/_article.html.erb:15` 95%, `app/views/layouts/application.html.erb:24` 3% | `name = name.to_s` |
| 6 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` | `initialize` | 102.13 / 216.13 | 114.0 | 165.5 | 50% | String |  | `app/views/articles/_article.html.erb:15` 47%, `app/views/articles/index.html.erb:27` 12% | `super` |
| 7 | `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` | `evaluate` | 89.35 / 203.35 | 114.0 | 152.0 | 100% | Array |  | `app/views/articles/_article.html.erb:15` 25%, `app/views/articles/_article.html.erb:14` 25% | `parts = @parts.dup` |
| 8 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:237` | `tag_options` | 84.08 / 183.83 | 99.75 | 139.25 | 50% | String |  | `app/views/articles/_article.html.erb:15` 55%, `app/views/articles/_article.html.erb:13` 14% | `output = +""` |
| 9 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` | `each` | 62.72 / 133.98 | 71.25 | 102.25 | 100% | String, Array |  | `app/views/articles/index.html.erb:27` 99%, `app/views/articles/index.html.erb:26` 0% | `val = step` |
| 10 | `RAILS/activesupport/lib/active_support/core_ext/hash/keys.rb:11` | `stringify_keys` | 59.48 / 130.7 | 71.23 | 98.76 | 100% | Hash |  | `app/views/articles/_article.html.erb:15` 39%, `app/views/articles/_article.html.erb:14` 19% | `transform_keys { \|k\| Symbol === k ? k.name : k.to_s }` |
| 11 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:232` | `content_tag_string` | 56.53 / 127.78 | 71.25 | 95.75 | 50% | String |  | `app/views/articles/_article.html.erb:15` 39%, `app/views/articles/_article.html.erb:14` 20% | `"<#{name}#{tag_options}>#{PRE_CONTENT_STRINGS[name]}#{content}</#{name` |
| 12 | `GEM/useragent/lib/user_agent/browsers/base.rb:120` | `detect_product` | 76.05 / 76.05 | 0.0 | 78.0 | 100% | String |  | `no app frame` 100% | `detect { \|useragent\| useragent.product.to_s.downcase == product.to_s.d` |
| 13 | `RUBY/ipaddr.rb:802` | `_to_string` | 74.1 / 74.1 | 0.0 | 76.0 | 100% | String, MatchData |  | `no app frame` 100% | `return (("%.32x" % addr).gsub!(/.{4}(?!$)/, '\&:'))` |
| 14 | `RAILS/actionpack/lib/action_controller/metal/url_for.rb:49` | `url_options` | 44.68 / 101.68 | 57.0 | 76.0 | 100% | Hash |  | `app/views/articles/_article.html.erb:5` 25%, `app/views/articles/_article.html.erb:14` 25% | `options = @_url_options.dup` |
| 15 | `RAILS/actionpack/lib/action_dispatch/http/url.rb:170` | `path_for` | 44.68 / 101.68 | 57.0 | 76.0 | 100% | String |  | `app/views/articles/_article.html.erb:14` 25%, `app/views/articles/_article.html.erb:15` 25% | `path = options[:script_name].to_s.chomp("/")` |
| 16 | `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:51` | `evaluate` | 44.68 / 101.68 | 57.0 | 76.0 | 100% | String |  | `app/views/articles/_article.html.erb:13` 25%, `app/views/articles/_article.html.erb:5` 25% | `parts.join` |
| 17 | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:214` | `call` | 44.68 / 101.68 | 57.0 | 76.0 | 100% | Hash |  | `app/views/articles/_article.html.erb:5` 25%, `app/views/articles/_article.html.erb:13` 25% | `options = t.url_options.merge @options` |
| 18 | `RAILS/actionpack/lib/action_dispatch/routing/route_set.rb:248` | `parameterize_args` | 44.68 / 101.68 | 57.0 | 76.0 | 100% | Hash |  | `app/views/articles/_article.html.erb:14` 25%, `app/views/articles/_article.html.erb:5` 25% | `params = {}` |
| 19 | `RAILS/actionpack/lib/action_dispatch/journey/router/utils.rb:73` | `escape` | 44.2 / 101.2 | 57.0 | 75.5 | 100% | String |  | `app/views/articles/_article.html.erb:15` 25%, `app/views/articles/_article.html.erb:14` 25% | `component.gsub(pattern) { \|unsafe\| percent_encode(unsafe) }.force_enco` |
| 20 | `RAILS/actionview/lib/action_view/record_identifier.rb:136` | `record_key_for_dom_id` | 43.7 / 100.7 | 57.0 | 75.0 | 50% | String |  | `app/views/articles/_article.html.erb:2` 50%, `app/views/articles/_article.html.erb:6` 50% | `key && key.all? ? key.join(JOIN) : nil` |
| 21 | `RUBY/ipaddr.rb:209` | `to_s` | 64.35 / 64.35 | 0.0 | 66.0 | 100% | String, MatchData |  | `no app frame` 100% | `str.gsub!(/\b0{1,3}([\da-f]+)\b/i, '\1')` |
| 22 | `RAILS/actionpack/lib/action_dispatch/routing/polymorphic_routes.rb:271` | `handle_model` | 33.28 / 76.03 | 42.75 | 56.75 | 100% | Array |  | `app/views/articles/_article.html.erb:13` 33%, `app/views/articles/_article.html.erb:5` 33% | `args  = []` |
| 23 | `RAILS/actionpack/lib/action_dispatch/routing/polymorphic_routes.rb:281` | `handle_model` | 33.28 / 76.03 | 42.75 | 56.75 | 100% | Array |  | `app/views/articles/_article.html.erb:5` 33%, `app/views/articles/_article.html.erb:15` 33% | `[named_route, args]` |
| 24 | `RAILS/actionpack/lib/action_dispatch/routing/polymorphic_routes.rb:289` | `handle_model_call` | 33.28 / 76.03 | 42.75 | 56.75 | 100% | Array |  | `app/views/articles/_article.html.erb:15` 33%, `app/views/articles/_article.html.erb:5` 33% | `target.public_send(method, *args)` |
| 25 | `RAILS/actionpack/lib/action_dispatch/routing/polymorphic_routes.rb:353` | `get_method_for_string` | 33.28 / 76.03 | 42.75 | 56.75 | 100% | String |  | `app/views/articles/_article.html.erb:15` 33%, `app/views/articles/_article.html.erb:13` 33% | `"#{prefix}#{str}_#{suffix}"` |
| 26 | `RAILS/actionpack/lib/action_controller/metal/request_forgery_protection.rb:584` | `per_form_csrf_token` | 32.78 / 75.53 | 42.75 | 56.25 | 50% | String, Array |  | `app/views/articles/_article.html.erb:15` 100% | `csrf_token_hmac(session, [action_path, method.downcase].join("#"))` |
| 27 | `RAILS/activerecord/lib/active_record/relation.rb:77` | `initialize` | 25.18 / 53.68 | 28.5 | 41.0 | 50% | Hash |  | `app/views/articles/_article.html.erb:7` 94%, `app/views/articles/index.html.erb:27` 5% | `def initialize(model, table: nil, predicate_builder: nil, values: {})` |
| 28 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` | `create` | 25.18 / 53.68 | 28.5 | 41.0 | 50% | Object |  | `app/views/articles/_article.html.erb:7` 94%, `app/views/articles/index.html.erb:27` 5% | `relation_class_for(model).new(model, ...)` |
| 29 | `RUBY/openssl/hmac.rb:36` | `digest` | 23.8 / 52.3 | 28.5 | 39.5 | 100% | Data |  | `app/views/articles/_article.html.erb:15` 96%, `no app frame` 2% | `hmac = new(key, digest)` |
| 30 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:484` | `tag` | 23.75 / 52.25 | 28.5 | 39.5 | 50% | String | #59804 open upstream work | `app/views/articles/_article.html.erb:15` 96%, `app/views/layouts/application.html.erb:10` 2% | `"<#{name}#{tag_builder.tag_options(options, escape) if options}#{open ` |

## Dev/test-mode work

2100.0 of 8210.5 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | error page | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:195` | 847.7 | 100% | `app/controllers/articles_controller.rb:27` 59%, `app/views/articles/index.html.erb:27` 27% | `add_filter { \|line\| line.sub(gems_regexp, gems_result) }` |
| 2 | error page | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:74` | 471.83 | 100% | `app/controllers/articles_controller.rb:27` 60%, `app/views/articles/index.html.erb:27` 27% | `frame = frame.to_s` |
| 3 | error page | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:130` | 217.45 | 100% | `app/controllers/articles_controller.rb:27` 59%, `app/views/articles/index.html.erb:27` 27% | `Thread.each_caller_location(2) do \|location\|` |
| 4 | reload check | `RAILS/activesupport/lib/active_support/file_update_checker.rb:135` † | 102.38 | 100% | `no app frame` 100% | `mtime = File.mtime(path)` |
| 5 | reload check | `RAILS/activesupport/lib/active_support/file_update_checker.rb:109` † | 82.88 | 100% | `no app frame` 100% | `all.concat(Dir[*@globs]) if @globs` |
| 6 | debug logging | `RAILS/actionpack/lib/abstract_controller/logger.rb:12` | 20.13 | 100% | `no app frame` 78%, `app/controllers/articles_controller.rb:28` 22% | `singleton_class.delegate :logger, :logger=, to: :config` |
| 7 | asset lookup | `GEM/propshaft/lib/propshaft/helper.rb:113` † | 19.0 | 50% | `app/views/layouts/application.html.erb:23` 100% | `Rails.application.assets.load_path.asset_paths_by_glob("#{Rails.root.j` |
| 8 | template compile | `RAILS/actionview/lib/action_view/template.rb:284` | 26.13 | 50% | `app/views/articles/index.html.erb:27` 96%, `no app frame` 4% | `result = view._run(method_name, self, locals, OutputBuffer.new, add_to` |
| 9 | template compile | `RAILS/actionview/lib/action_view/template.rb:594` | 26.13 | 50% | `app/views/articles/index.html.erb:27` 96%, `no app frame` 4% | `{ virtual_path: @virtual_path, identifier: @identifier }` |
| 10 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:177` | 17.55 | 100% | `app/controllers/articles_controller.rb:27` 50%, `app/views/articles/index.html.erb:27` 33% | `"\e[#{modes.join(";")}m" if modes.any?` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activesupport | 2849.5 | 2922.0 | `backtrace_cleaner.rb:195` 847.7, `backtrace_cleaner.rb:74` 471.8, `backtrace_cleaner.rb:130` 217.5 |
| rails: actionpack | 1304.6 | 1353.3 | `visitors.rb:40` 146.4, `url_for.rb:49` 73.2, `route_set.rb:214` 73.2 |
| rails: actionview | 1196.8 | 1245.0 | `tag_helper.rb:309` 340.6, `tag_helper.rb:237` 134.0, `tag_helper.rb:232` 92.2 |
| rails: activerecord | 930.9 | 969.1 | `integration.rb:59` 218.1, `delegation.rb:139` 39.4, `relation.rb:77` 39.4 |
| ruby stdlib | 859.6 | 882.3 | `ipaddr.rb:758` 566.5, `ipaddr.rb:802` 74.1, `ipaddr.rb:209` 64.4 |
| app | 357.7 | 371.8 | `_article.html.erb:15` 90.3, `_article.html.erb:14` 72.2, `_article.html.erb:13` 54.2 |
| ruby default gem: uri | 227.0 | 234.8 | `rfc3986_parser.rb:115` 36.1, `common.rb:465` 32.3, `generic.rb:543` 21.1 |
| gem: useragent | 188.3 | 193.3 | `base.rb:120` 76.1, `version.rb:27` 27.3, `user_agent.rb:25` 11.7 |
| rails: activemodel | 112.8 | 117.3 | `string.rb:39` 37.6, `builder.rb:16` 19.5, `builder.rb:22` 19.5 |
| gem: sqlite3 | 109.2 | 114.4 | `statement.rb:159` 98.4, `statement.rb:36` 3.0, `database.rb:215` 3.0 |
| gem: base64 | 65.9 | 68.3 | `base64.rb:310` 23.4, `base64.rb:283` 22.9, `base64.rb:374` 19.5 |
| gem: rack | 59.8 | 62.0 | `body_proxy.rb:12` 4.9, `query_parser.rb:259` 4.8, `utils.rb:331` 3.9 |
| gem: logger | 57.5 | 59.0 | `logger.rb:692` 14.6, `log_device.rb:33` 14.6, `log_device.rb:165` 14.6 |
| gem: propshaft | 40.1 | 42.0 | `helper.rb:113` 19.0, `asset.rb:73` 7.6, `dynamic.rb:11` 3.8 |
| gem: web-console | 35.1 | 36.0 | `permissions.rb:39` 21.5, `permissions.rb:21` 3.9, `request.rb:12` 2.0 |
| rails: activejob | 26.6 | 28.0 | `log_subscriber.rb:207` 5.7, `arguments.rb:141` 4.8, `log_subscriber.rb:216` 1.4 |
| gem: importmap-rails | 24.7 | 26.0 | `importmap_tags_helper.rb:30` 6.7, `importmap_tags_helper.rb:44` 6.7, `importmap_tags_helper.rb:42` 4.3 |
| ruby default gem: securerandom | 20.5 | 21.3 | `securerandom.rb:71` 20.5 |
| gem: concurrent-ruby | 19.5 | 20.2 | `safe_initialization.rb:30` 5.9, `mutex_lockable_object.rb:33` 2.0, `mutex_lockable_object.rb:32` 2.0 |
| gem: globalid | 18.0 | 19.0 | `gid.rb:95` 4.8, `gid.rb:159` 3.8, `gid.rb:166` 1.9 |
| gem: json | 15.6 | 16.1 | `common.rb:298` 12.7, `common.rb:861` 2.0, `common.rb:775` 0.5 |
| gem: turbo-rails | 14.4 | 15.0 | `stream_name.rb:26` 2.9, `broadcastable.rb:184` 1.9, `broadcastable.rb:521` 1.4 |
| rails: railties | 12.6 | 13.0 | `backtrace_cleaner.rb:21` 2.9, `logger.rb:57` 2.0, `finisher.rb:194` 1.0 |
| ruby default gem: erb | 8.8 | 9.0 | `util.rb:65` 8.8 |
| gem: tzinfo | 8.6 | 9.0 | `timestamp.rb:208` 3.8, `constant_offset_data_timezone_info.rb:52` 1.9, `timestamp.rb:193` 1.9 |
| gem: rack-session | 2.9 | 3.0 | `id.rb:275` 1.0, `id.rb:277` 1.0, `id.rb:401` 1.0 |
| gem: solid_queue | 1.4 | 1.5 | `batch_id.rb:20` 1.0, `batch_id.rb:24` 0.5 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Jobs

| # | Job | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | Turbo::Streams::ActionBroadcastJob#perform | 20 / 20 | 3083.1 / 3084.4 | 1.3 | 3084.3 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 17.0, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 16.0, `RAILS/activerecord/lib/active_record/integration.rb:59` 12.0 | `app/views/articles/_article.html.erb:7` 172.1, `app/views/articles/_article.html.erb:15` 58.0, `app/views/articles/_article.html.erb:5` 31.0 |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:195` (error page) | 995.24 / 995.19 | 95% | `no app frame` 84%, `app/views/articles/_article.html.erb:7` 16% | `add_filter { \|line\| line.sub(gems_regexp, gems_result) }` |
| 2 | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:74` (error page) | 562.76 / 562.76 | 95% | `no app frame` 85%, `app/views/articles/_article.html.erb:7` 15% | `frame = frame.to_s` |
| 3 | `RAILS/activesupport/lib/active_support/backtrace_cleaner.rb:130` (error page) | 253.33 / 253.33 | 95% | `no app frame` 84%, `app/views/articles/_article.html.erb:7` 16% | `Thread.each_caller_location(2) do \|location\|` |
| 4 | `RAILS/activesupport/lib/active_support/file_update_checker.rb:135` † (reload check) | 59.14 / 62.43 | 95% | `no app frame` 100% | `mtime = File.mtime(path)` |
| 5 | `RAILS/activesupport/lib/active_support/file_update_checker.rb:109` † (reload check) | 40.29 / 42.52 | 95% | `no app frame` 100% | `all.concat(Dir[*@globs]) if @globs` |
| 6 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` | 15.38 / 15.38 | 95% | `app/views/articles/_article.html.erb:15` 53%, `no app frame` 12% | `%(#{key}="#{value}")` |
| 7 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | 14.48 / 14.48 | 95% | `no app frame` 75%, `app/views/articles/_article.html.erb:7` 25% | `dispatch(:#{method}, ...)` |
| 8 | `RAILS/activejob/lib/active_job/log_subscriber.rb:207` (debug logging) | 10.86 / 10.86 | 95% | `no app frame` 100% | `job.arguments.map { \|arg\| format(arg).inspect }.join(", ")` |
| 9 | `RAILS/activesupport/lib/active_support/log_subscriber.rb:177` (debug logging) | 10.86 / 10.86 | 95% | `app/views/articles/_article.html.erb:7` 50%, `no app frame` 50% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 10 | `RAILS/activerecord/lib/active_record/integration.rb:59` | 10.86 / 10.86 | 95% | `app/views/articles/_article.html.erb:5` 25%, `app/views/articles/_article.html.erb:14` 25% | `Array(id).join(self.class.param_delimiter)` |
