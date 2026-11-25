# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails runner /home/user/.local/share/mise/installs/ruby/4.0.7/lib/ruby/gems/4.0.0/gems/lowrail-profile-0.1.0.rc1/lib/lowrail/profile_workloads.rb /home/user/workspace/repo/bench/upstream/profile_release/2026-11-25-confirm-opus/rc-blog-81-probes/w/probe.rb /home/user/workspace/repo/bench/upstream/profile_release/2026-11-25-confirm-opus/rc-blog-81-probes/w/probe-allow/workloads.json`
* Ruby: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux]
* Rails: 8.1.4, development environment
* Counted in run 1: 40 requests; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 40 | 142847.3 | 0 | 0 | 0 | 0 |
| run2 | 1 | 40 | 142848.5 | 0 | 0 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.57 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/views/articles/index.html.erb:27` |  | 259.35 | 441.75 | 0.0 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` 5%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 2%, `RAILS/activerecord/lib/active_record/result.rb:244` 1% | ArticlesController#index 100% | `<% else %>` |
| 2 | `app/views/articles/_article.html.erb:15` |  | 134.9 | 0.0 | 7.13 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 13%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 10%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 4% | ArticlesController#index 100% | `</div>` |
| 3 | `app/views/articles/index.html.erb:16` |  | 55.73 | 0.0 | 0.0 | `GEM/uri/lib/uri/common.rb:465` 15%, `GEM/json/lib/json/common.rb:298` 9%, `RAILS/activesupport/lib/active_support/key_generator.rb:63` 4% | ArticlesController#index 100% | `<p class="py-2 px-3 bg-green-50 mb-5 text-green-500 font-medium rounde` |
| 4 | `app/views/articles/index.html.erb:26` |  | 41.33 | 159.6 | 0.48 | `RAILS/activerecord/lib/active_record/relation/finder_methods.rb:445` 5%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 5%, `RAILS/activerecord/lib/active_record/query_logs_formatter.rb:21` 3% | ArticlesController#index 100% | `<%= render @articles %>` |
| 5 | `app/views/layouts/application.html.erb:24` |  | 40.38 | 24.7 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 20%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 20%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 15% | ArticlesController#index 100% | `</head>` |
| 6 | `app/views/articles/_article.html.erb:5` |  | 32.78 | 0.0 | 2.85 | `RAILS/activerecord/lib/active_record/integration.rb:59` 13%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 9%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 9% | ArticlesController#index 100% | `<span id="<%= dom_id(article, :comments_count) %>" class="text-gray-50` |
| 7 | `app/views/articles/_article.html.erb:13` |  | 31.35 | 0.0 | 4.28 | `RAILS/activerecord/lib/active_record/integration.rb:59` 14%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 9%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 9% | ArticlesController#index 100% | `<%= link_to "Edit", edit_article_path(article), class: "w-full sm:w-au` |
| 8 | `app/views/layouts/application.html.erb:23` |  | 30.4 | 34.68 | 1.43 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 9%, `RAILS/actionview/lib/action_view/helpers/asset_tag_helper.rb:679` 9%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 8% | ArticlesController#index 100% | `<%= javascript_importmap_tags %>` |
| 9 | `app/views/articles/_article.html.erb:14` |  | 25.65 | 0.0 | 5.7 | `RAILS/activerecord/lib/active_record/integration.rb:59` 17%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 11%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 11% | ArticlesController#index 100% | `<%= button_to "Destroy", article, method: :delete, class: "w-full sm:w` |
| 10 | `app/views/layouts/application.html.erb:10` |  | 18.05 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 11%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 11%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 8% | ArticlesController#index 100% | `<%= csp_meta_tag %>` |
| 11 | `app/views/articles/_article.html.erb:7` |  | 15.2 | 0.0 | 1.43 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 19%, `RAILS/activerecord/lib/active_record/relation.rb:77` 19%, `RAILS/activesupport/lib/active_support/inflector/methods.rb:382` 12% | ArticlesController#index 100% | `</span>` |
| 12 | `app/views/articles/index.html.erb:2` |  | 13.77 | 0.0 | 1.43 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:329` 14%, `GEM/turbo-rails/app/channels/turbo/streams/stream_name.rb:26` 10%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 7% | ArticlesController#index 100% | `` |
| 13 | `app/controllers/articles_controller.rb:6` | `index` | 12.82 | 0.0 | 0.95 | `RAILS/activerecord/lib/active_record/relation/query_methods.rb:2117` 19%, `RAILS/activerecord/lib/active_record/relation/query_methods.rb:2154` 11%, `RAILS/activerecord/lib/active_record/relation.rb:98` 7% | ArticlesController#index 100% | `@articles = Article.includes(:comments).order(created_at: :desc)` |
| 14 | `app/views/articles/index.html.erb:22` |  | 7.6 | 0.0 | 1.9 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 13%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 13%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:51` 6% | ArticlesController#index 100% | `</div>` |
| 15 | `app/views/articles/_article.html.erb:6` |  | 7.13 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/record_identifier.rb:136` 40%, `RAILS/actionview/lib/action_view/record_identifier.rb:80` 20%, `RAILS/activerecord/lib/active_record/attribute_methods/primary_key.rb:13` 20% | ArticlesController#index 100% | `(<%= pluralize(article.comments.size, "comment") %>)` |
| 16 | `app/views/articles/_article.html.erb:10` |  | 7.13 | 0.0 | 1.43 | `RAILS/activesupport/lib/active_support/core_ext/string/filters.rb:84` 40%, `RAILS/activemodel/lib/active_model/type/string.rb:39` 20%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 20% | ArticlesController#index 100% | `</div>` |
| 17 | `app/views/articles/_article.html.erb:2` |  | 5.7 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/record_identifier.rb:136` 50%, `RAILS/actionview/lib/action_view/record_identifier.rb:98` 25%, `RAILS/activerecord/lib/active_record/attribute_methods/primary_key.rb:13` 25% | ArticlesController#index 100% | `<div class="p-4 border rounded mb-4 flex-grow">` |
| 18 | `app/views/articles/index.html.erb:13` |  | 5.7 | 0.0 | 0.0 | `GEM/turbo-rails/app/helpers/turbo/drive_helper.rb:27` 25%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 17%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 17% | ArticlesController#index 100% | `` |
| 19 | `app/views/layouts/application.html.erb:13` |  | 1.42 | 0.0 | 0.48 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 33%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 33%, `RAILS/actionview/lib/action_view/renderer/template_renderer.rb:77` 33% | ArticlesController#index 100% | `` |
| 20 | `app/views/articles/index.html.erb:4` |  | 0.95 | 0.0 | 0.48 | `RAILS/actionview/lib/action_view/helpers/capture_helper.rb:172` 50%, `RAILS/actionview/lib/action_view/flows.rb:10` 50% | ArticlesController#index 100% | `` |
| 21 | `app/views/layouts/application.html.erb:29` |  | 0.95 | 0.0 | 0.48 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 50%, `RAILS/actionview/lib/action_view/renderer/template_renderer.rb:77` 50% | ArticlesController#index 100% | `</main>` |
| 22 | `app/views/layouts/application.html.erb:5` |  | 0.48 | 0.0 | 0.0 | `RAILS/actionview/lib/action_view/helpers/capture_helper.rb:172` 100% | ArticlesController#index 100% | `<meta name="viewport" content="width=device-width,initial-scale=1">` |
| 23 | `app/views/articles/_article.html.erb:1` |  | 0.0 | 0.0 | 2.85 |  |  | `<div id="<%= dom_id(article) %>" class="flex flex-col sm:flex-row just` |
| 24 | `app/views/articles/_article.html.erb:19` |  | 0.0 | 0.0 | 1.43 |  |  | `` |
| 25 | `app/views/articles/index.html.erb:1` |  | 0.0 | 0.0 | 0.95 |  |  | `<%= turbo_stream_from "articles" %>` |
| 26 | `app/views/articles/index.html.erb:34` |  | 0.0 | 0.0 | 0.48 |  |  | `` |
| 27 | `app/views/layouts/application.html.erb:1` |  | 0.0 | 0.0 | 0.95 |  |  | `<!DOCTYPE html>` |
| 28 | `app/views/layouts/application.html.erb:11` |  | 0.0 | 0.0 | 0.48 |  |  | `` |
| 29 | `app/views/layouts/application.html.erb:34` |  | 0.0 | 0.0 | 0.48 |  |  | `` |

4106.78 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | ArticlesController#create | 20 / 20 | 278761.1 / 278761.4 | 0.3 | 278761.4 | `RAILS/actionview/lib/action_view/buffers.rb:44` 1314.0, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 603.0, `RAILS/actionview/lib/action_view/helpers/url_helper.rb:438` 588.0 |  |
| 2 | ArticlesController#index | 20 / 20 | 5051.5 / 5053.7 | 2.3 | 5053.6 | `RUBY/ipaddr.rb:758` 581.0, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 87.0, `GEM/useragent/lib/user_agent/browsers/base.rb:120` 78.0 | `app/views/articles/index.html.erb:27` 546.0, `app/views/articles/_article.html.erb:15` 284.0, `app/views/articles/index.html.erb:16` 117.3 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `RAILS/actionview/lib/action_view/buffers.rb:44` † | `<<` | 624.15 / 624.15 | 0.0 | 657.0 | 50% | String |  | `no app frame` 100% | `value = value.to_s` |
| 2 | `RUBY/ipaddr.rb:758` | `in6_addr` | 566.47 / 566.47 | 0.0 | 581.03 | 100% | Data, Array |  | `no app frame` 100% | `raise InvalidAddressError, "invalid address: #{@addr}"` |
| 3 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` | `html_safe` | 328.1 / 328.1 | 0.0 | 329.5 | 100% | String |  | `no app frame` 92%, `app/views/layouts/application.html.erb:24` 2% | `ActiveSupport::SafeBuffer.new(self)` |
| 4 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:11` | `html_escape` | 294.48 / 294.48 | 0.0 | 294.5 | 100% | String |  | `no app frame` 100%, `app/views/layouts/application.html.erb:10` 0% | `s = s.to_s` |
| 5 | `RAILS/actionview/lib/action_view/helpers/url_helper.rb:438` | `link_to_if` | 279.3 / 279.3 | 0.0 | 294.0 | 50% | Hash |  | `no app frame` 100% | `def link_to_if(condition, name, options = {}, html_options = {}, &bloc` |
| 6 | `RAILS/actionpack/lib/action_controller/metal/request_forgery_protection.rb:321` | `handle_unverified_request` | 142.98 / 142.98 | 0.0 | 150.5 | 50% | Data, Array |  | `no app frame` 100% | `raise ActionController::InvalidAuthenticityToken, warning_message` |
| 7 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:15` | `html_escape` | 127.78 / 127.78 | 0.0 | 134.5 | 50% | String |  | `no app frame` 100% | `super(s)` |
| 8 | `RAILS/actionpack/lib/action_controller/metal/rescue.rb:39` | `process_action` | 99.75 / 99.75 | 0.0 | 105.0 | 50% | String, Array |  | `no app frame` 100% | `rescue_with_handler(exception) \|\| raise` |
| 9 | `RUBY/ipaddr.rb:802` | `_to_string` | 74.1 / 74.1 | 0.0 | 76.0 | 100% | String, MatchData |  | `no app frame` 100% | `return (("%.32x" % addr).gsub!(/.{4}(?!$)/, '\&:'))` |
| 10 | `RUBY/ipaddr.rb:209` | `to_s` | 64.35 / 64.35 | 0.0 | 66.0 | 100% | String, MatchData |  | `no app frame` 100% | `str.gsub!(/\b0{1,3}([\da-f]+)\b/i, '\1')` |
| 11 | `GEM/bootsnap/lib/bootsnap/load_path_cache/core_ext/kernel_require.rb:11` | `require` | 47.03 / 47.03 | 0.0 | 49.5 | 50% | String |  | `no app frame` 100% | `string_path = Bootsnap.rb_get_path(path)` |
| 12 | `RAILS/actionpack/lib/action_dispatch/middleware/templates/rescues/_source.html.erb:24` | `` | 47.03 / 47.03 | 0.0 | 49.5 | 50% | String |  | `no app frame` 100% | `<% else -%>` |
| 13 | `RAILS/activesupport/lib/active_support/core_ext/thread/backtrace/location.rb:5` | `spot` | 47.03 / 47.03 | 0.0 | 49.5 | 50% | Hash |  | `no app frame` 100% | `ErrorHighlight.spot(ex, backtrace_location: self)` |
| 14 | `RAILS/actionpack/lib/action_dispatch/middleware/templates/rescues/_source.html.erb:6` | `` | 46.55 / 46.55 | 0.0 | 49.0 | 50% | String |  | `no app frame` 100% | `<div class="info">` |
| 15 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` | `tag_option` | 41.83 / 41.83 | 0.0 | 44.0 | 100% | String |  | `app/views/articles/_article.html.erb:15` 41%, `app/views/layouts/application.html.erb:24` 19% | `%(#{key}="#{value}")` |
| 16 | `RAILS/actionview/lib/action_view/template/resolver.rb:17` † | `build_path_regex` | 38.95 / 38.95 | 0.0 | 41.0 | 50% | String, Array |  | `no app frame` 100% | `formats = Regexp.union(Template::Types.symbols.map(&:to_s))` |
| 17 | `GEM/useragent/lib/user_agent/browsers/base.rb:120` | `detect_product` | 37.05 / 37.05 | 0.0 | 39.0 | 50% | String |  | `no app frame` 100% | `detect { \|useragent\| useragent.product.to_s.downcase == product.to_s.d` |
| 18 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` | `initialize` | 32.63 / 32.63 | 0.0 | 34.0 | 100% | String |  | `no app frame` 22%, `app/views/layouts/application.html.erb:24` 19% | `super` |
| 19 | `RAILS/actionview/lib/action_view/template/sources/file.rb:12` | `to_s` | 29.92 / 29.92 | 0.0 | 31.5 | 50% | String, File |  | `no app frame` 100% | `::File.binread @filename` |
| 20 | `GEM/uri/lib/uri/common.rb:465` | `_decode_uri_component` | 27.83 / 28.4 | 0.57 | 28.5 | 100% | String, MatchData |  | `no app frame` 70%, `app/views/articles/index.html.erb:16` 30% | `str.b.gsub(regexp, TBLDECWWWCOMP_).force_encoding(enc)` |
| 21 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` | `xml_name_escape` | 25.2 / 25.2 | 0.0 | 26.5 | 100% | String |  | `app/views/articles/_article.html.erb:15` 51%, `app/views/layouts/application.html.erb:24` 32% | `name = name.to_s` |
| 22 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | `#{method}` | 24.25 / 24.25 | 0.0 | 25.0 | 100% | Array, Hash |  | `no app frame` 72%, `app/views/articles/index.html.erb:27` 20% | `dispatch(:#{method}, ...)` |
| 23 | `GEM/web-console/lib/web_console/permissions.rb:39` | `human_readable_ipaddr` | 21.45 / 21.45 | 0.0 | 22.0 | 100% | String, Array |  | `no app frame` 100% | `ipaddr.to_range.to_s.split("..").uniq.join("/")` |
| 24 | `RAILS/activesupport/lib/active_support/core_ext/string/access.rb:47` | `from` | 19.9 / 19.9 | 0.0 | 20.0 | 100% | String |  | `no app frame` 90%, `app/views/articles/index.html.erb:27` 8% | `self[position, length]` |
| 25 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:237` | `tag_options` | 18.08 / 18.08 | 0.0 | 19.0 | 100% | String |  | `app/views/articles/_article.html.erb:15` 32%, `app/views/layouts/application.html.erb:24` 24% | `output = +""` |
| 26 | `RAILS/actionview/lib/action_view/template/resolver.rb:39` | `parse` | 17.1 / 17.1 | 0.0 | 18.0 | 50% | String |  | `no app frame` 100% | `path = TemplatePath.build(match[:action], match[:prefix] \|\| "", !!matc` |
| 27 | `RAILS/activerecord/lib/active_record/integration.rb:59` | `to_param` | 17.1 / 17.1 | 0.0 | 18.0 | 50% | String, Array |  | `app/views/articles/_article.html.erb:5` 25%, `app/views/articles/_article.html.erb:13` 25% | `Array(id).join(self.class.param_delimiter)` |
| 28 | `RAILS/actionview/lib/action_view/unbound_template.rb:59` † | `build_template` | 15.68 / 15.68 | 0.0 | 16.5 | 50% | String, Array |  | `no app frame` 100% | `locals: locals.map(&:to_s)` |
| 29 | `RAILS/actionview/lib/action_view/template/resolver.rb:127` | `built_templates` | 15.2 / 15.2 | 0.0 | 16.0 | 50% | Array, Hash |  | `no app frame` 100% | `@unbound_templates.values.flatten.flat_map(&:built_templates)` |
| 30 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` | `each` | 14.73 / 14.73 | 0.0 | 15.5 | 50% | String, Array |  | `app/views/articles/index.html.erb:27` 97%, `app/views/articles/index.html.erb:26` 3% | `val = step` |

## Dev/test-mode work

130121.4 of 135045.3 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

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
| ruby stdlib | 80160.4 | 84358.0 | `base.rb:94` 70066.3, `base.rb:59` 8699.6, `ipaddr.rb:758` 566.5 |
| ruby default gem: prism | 41011.0 | 43169.5 | `parse_result.rb:162` 25263.4, `node.rb:4628` 2397.8, `node.rb:30908` 1930.4 |
| rails: activesupport | 6677.5 | 6779.5 | `backtrace_cleaner.rb:195` 3356.7, `backtrace_cleaner.rb:74` 1000.8, `backtrace_cleaner.rb:212` 805.6 |
| rails: actionpack | 4138.0 | 4351.4 | `exception_wrapper.rb:332` 2039.2, `exception_wrapper.rb:333` 608.5, `exception_wrapper.rb:158` 188.1 |
| rails: actionview | 1852.0 | 1944.0 | `buffers.rb:44` 624.2, `url_helper.rb:438` 279.3, `template.rb:509` 64.1 |
| gem: erubi | 368.1 | 387.5 | `erubi.rb:134` 206.2, `erubi.rb:137` 46.6, `erubi.rb:139` 24.7 |
| rails: activerecord | 262.4 | 276.0 | `integration.rb:59` 17.1, `delegation.rb:139` 6.2, `relation.rb:77` 6.2 |
| gem: useragent | 93.6 | 98.5 | `base.rb:120` 37.1, `version.rb:27` 13.3, `user_agent.rb:25` 5.7 |
| gem: concurrent-ruby | 48.4 | 50.0 | `non_concurrent_map_backend.rb:131` 10.0, `map.rb:245` 8.6, `non_concurrent_map_backend.rb:120` 6.7 |
| ruby default gem: uri | 48.1 | 49.5 | `common.rb:465` 28.1, `common.rb:456` 7.6, `rfc3986_parser.rb:115` 2.9 |
| gem: bootsnap | 47.0 | 49.5 | `kernel_require.rb:11` 47.0 |
| gem: logger | 42.5 | 44.0 | `logger.rb:692` 10.6, `log_device.rb:33` 10.6, `log_device.rb:165` 10.6 |
| gem: propshaft | 40.1 | 42.0 | `helper.rb:113` 19.0, `asset.rb:73` 7.6, `dynamic.rb:11` 3.8 |
| gem: rack | 38.0 | 39.5 | `utils.rb:331` 3.9, `body_proxy.rb:12` 3.9, `request.rb:607` 3.4 |
| app | 38.0 | 40.0 | `_article.html.erb:15` 7.1, `_article.html.erb:14` 5.7, `_article.html.erb:13` 4.3 |
| gem: web-console | 35.6 | 36.5 | `permissions.rb:39` 21.5, `permissions.rb:21` 3.9, `request.rb:12` 2.0 |
| ruby default gem: prettyprint | 28.5 | 30.0 | `prettyprint.rb:404` 7.6, `prettyprint.rb:264` 7.1, `prettyprint.rb:459` 4.8 |
| gem: importmap-rails | 24.7 | 26.0 | `importmap_tags_helper.rb:30` 6.7, `importmap_tags_helper.rb:44` 6.7, `importmap_tags_helper.rb:42` 4.3 |
| gem: sqlite3 | 20.4 | 21.5 | `statement.rb:159` 14.7, `database.rb:215` 1.4, `statement.rb:217` 1.4 |
| gem: nokogiri | 19.5 | 20.5 | `document.rb:416` 2.9, `node.rb:66` 2.8, `document_fragment.rb:169` 1.9 |
| ruby default gem: pp | 13.8 | 14.5 | `pp.rb:542` 5.7, `pp.rb:271` 2.9, `pp.rb:550` 2.4 |
| rails: activemodel | 13.3 | 14.0 | `builder.rb:28` 2.9, `builder.rb:16` 2.9, `builder.rb:22` 2.9 |
| gem: json | 13.1 | 13.5 | `common.rb:298` 11.2, `common.rb:861` 1.0, `common.rb:769` 0.5 |
| rails: railties | 12.6 | 13.0 | `backtrace_cleaner.rb:21` 2.9, `logger.rb:57` 2.0, `finisher.rb:194` 1.0 |
| gem: base64 | 12.0 | 12.5 | `base64.rb:310` 5.8, `base64.rb:283` 4.3, `base64.rb:374` 1.9 |
| gem: turbo-rails | 6.7 | 7.0 | `drive_helper.rb:27` 1.4, `stream_name.rb:26` 1.4, `streams_helper.rb:61` 1.0 |
| gem: loofah | 5.2 | 5.5 | `concerns.rb:172` 1.9, `concerns.rb:43` 1.4, `scrubber.rb:132` 1.0 |
| ruby default gem: erb | 4.3 | 4.5 | `util.rb:65` 4.3 |
| gem: rails-html-sanitizer | 3.3 | 3.5 | `sanitizer.rb:33` 0.5, `sanitizer.rb:56` 0.5, `scrubbers.rb:55` 0.5 |
| ruby default gem: securerandom | 2.9 | 3.0 | `securerandom.rb:71` 2.9 |
| gem: rack-session | 1.4 | 1.5 | `id.rb:401` 0.5, `id.rb:277` 0.5, `id.rb:275` 0.5 |
| gem: i18n | 1.0 | 1.0 | `simple.rb:51` 1.0 |
