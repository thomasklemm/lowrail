# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails test -v`
* Ruby: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux]
* Rails: 8.1.4, test environment
* Counted in run 1: 12 requests; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 12 | 4728.8 | 0 | 0 | 0 | 0 |
| run2 | 1 | 12 | 4728.7 | 0 | 0 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.42 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/views/articles/_form.html.erb:21` |  | 127.17 | 0.0 | 0.67 | `GEM/i18n/lib/i18n/backend/base.rb:157` 11%, `GEM/i18n/lib/i18n.rb:396` 9%, `GEM/i18n/lib/i18n/backend/simple.rb:100` 8% | ArticlesController#update 50%, ArticlesController#create 50%, ArticlesController#edit 0% | `<%= form.textarea :body, rows: 4, class: ["block shadow-sm rounded-md ` |
| 2 | `app/views/articles/_form.html.erb:8` |  | 92.08 | 0.0 | 0.0 | `GEM/i18n/lib/i18n/backend/base.rb:157` 9%, `GEM/i18n/lib/i18n.rb:476` 8%, `GEM/i18n/lib/i18n.rb:396` 8% | ArticlesController#create 55%, ArticlesController#update 45% | `<li><%= error.full_message %></li>` |
| 3 | `app/views/articles/_form.html.erb:16` |  | 67.5 | 0.0 | 0.67 | `GEM/i18n/lib/i18n/backend/base.rb:157` 10%, `GEM/i18n/lib/i18n.rb:396` 8%, `GEM/i18n/lib/i18n/backend/simple.rb:100` 7% | ArticlesController#create 50%, ArticlesController#update 50%, ArticlesController#new 0% | `<%= form.text_field :title, class: ["block shadow-sm rounded-md border` |
| 4 | `app/views/articles/_form.html.erb:20` |  | 53.33 | 0.0 | 0.0 | `GEM/i18n/lib/i18n/backend/base.rb:157` 10%, `GEM/i18n/lib/i18n.rb:396` 8%, `GEM/i18n/lib/i18n/backend/simple.rb:100` 8% | ArticlesController#create 50%, ArticlesController#update 50%, ArticlesController#edit 0% | `<%= form.label :body %>` |
| 5 | `app/views/articles/_form.html.erb:15` |  | 33.67 | 0.0 | 0.0 | `GEM/i18n/lib/i18n/backend/base.rb:157` 9%, `GEM/i18n/lib/i18n.rb:396` 7%, `GEM/i18n/lib/i18n/backend/simple.rb:100` 7% | ArticlesController#update 50%, ArticlesController#create 50%, ArticlesController#edit 0% | `<%= form.label :title %>` |
| 6 | `app/controllers/articles_controller.rb:27` | `create` | 25.67 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 82%, `RAILS/activemodel/lib/active_model/errors.rb:342` 2%, `RAILS/activemodel/lib/active_model/error.rb:204` 2% | ArticlesController#create 100% | `if @article.save` |
| 7 | `app/controllers/articles_controller.rb:40` | `update` | 25.58 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 79%, `RAILS/activemodel/lib/active_model/error.rb:204` 2%, `RAILS/activemodel/lib/active_model/errors.rb:342` 2% | ArticlesController#update 100% | `if @article.update(article_params)` |
| 8 | `app/controllers/comments_controller.rb:6` | `create` | 24.0 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 86%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 1%, `RAILS/activemodel/lib/active_model/errors.rb:342` 1% | CommentsController#create 100% | `if @comment.save` |
| 9 | `app/views/layouts/application.html.erb:23` |  | 14.17 | 8.67 | 0.0 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 20%, `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 20%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 15% | ArticlesController#update 50%, ArticlesController#create 50%, ArticlesController#index 0% | `<%= javascript_importmap_tags %>` |
| 10 | `app/views/articles/_form.html.erb:25` |  | 11.0 | 0.0 | 0.33 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:146` 9%, `GEM/i18n/lib/i18n/interpolate/ruby.rb:33` 9%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 8% | ArticlesController#create 50%, ArticlesController#update 50%, ArticlesController#edit 0% | `<%= form.submit class: "w-full sm:w-auto rounded-md px-3.5 py-2.5 bg-b` |
| 11 | `app/controllers/articles_controller.rb:31` | `create` | 10.92 | 7.08 | 0.17 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:208` 6%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 6%, `RAILS/actionview/lib/action_view/template_path.rb:23` 5% | ArticlesController#create 100% | `format.html { render :new, status: :unprocessable_content }` |
| 12 | `app/controllers/articles_controller.rb:44` | `update` | 10.92 | 7.08 | 0.17 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:208` 6%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 6%, `RAILS/actionview/lib/action_view/template_path.rb:23` 5% | ArticlesController#update 100% | `format.html { render :edit, status: :unprocessable_content }` |
| 13 | `app/controllers/comments_controller.rb:9` | `create` | 10.67 | 1.17 | 0.25 | `RAILS/activesupport/lib/active_support/key_generator.rb:63` 4%, `GEM/rack/lib/rack/request.rb:696` 3%, `GEM/uri/lib/uri/common.rb:108` 3% | CommentsController#create 100% | `redirect_to @article, alert: "Could not create comment."` |
| 14 | `app/views/layouts/application.html.erb:22` |  | 10.67 | 12.17 | 0.5 | `RAILS/actionview/lib/action_view/helpers/asset_tag_helper.rb:679` 9%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 9%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 8% | ArticlesController#create 50%, ArticlesController#update 50%, ArticlesController#index 0% | `<%= stylesheet_link_tag :app, "data-turbo-track": "reload" %>` |
| 15 | `app/controllers/comments_controller.rb:5` | `create` | 9.67 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 7%, `RAILS/activerecord/lib/active_record/relation.rb:77` 4%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 4% | CommentsController#create 100% | `@comment = @article.comments.build(comment_params)` |
| 16 | `app/views/articles/_form.html.erb:1` |  | 9.67 | 0.0 | 0.5 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 9%, `GEM/rack/lib/rack/request.rb:696` 7%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` 6% | ArticlesController#update 58%, ArticlesController#create 42%, ArticlesController#new 0% | `<%= form_with(model: article, class: "contents") do \|form\| %>` |
| 17 | `app/controllers/articles_controller.rb:68` | `article_params` | 8.5 | 0.0 | 0.5 | `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:75` 13%, `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:405` 12%, `RAILS/activesupport/lib/active_support/core_ext/array/wrap.rb:45` 10% | ArticlesController#create 52%, ArticlesController#update 48% | `params.expect(article: [ :title, :body ])` |
| 18 | `app/controllers/comments_controller.rb:22` | `set_article` | 5.92 | 3.0 | 0.17 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` 7%, `GEM/sqlite3/lib/sqlite3/statement.rb:76` 4%, `RAILS/activerecord/lib/active_record/connection_adapters/abstract/database_statements.rb:49` 3% | CommentsController#create 100%, CommentsController#destroy 0% | `@article = Article.find(params.expect(:article_id))` |
| 19 | `app/controllers/articles_controller.rb:63` | `set_article` | 5.92 | 3.0 | 0.17 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` 7%, `GEM/sqlite3/lib/sqlite3/statement.rb:76` 4%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 3% | ArticlesController#update 100%, ArticlesController#destroy 0%, ArticlesController#edit 0% | `@article = Article.find(params.expect(:id))` |
| 20 | `app/controllers/comments_controller.rb:26` | `comment_params` | 4.08 | 0.0 | 0.25 | `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:75` 12%, `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:405` 12%, `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:463` 10% | CommentsController#create 100% | `params.expect(comment: [ :commenter, :body ])` |
| 21 | `app/views/articles/edit.html.erb:6` |  | 2.25 | 1.5 | 0.17 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:208` 7%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 7%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:204` 4% | ArticlesController#update 100%, ArticlesController#edit 0% | `<%= render "form", article: @article %>` |
| 22 | `app/views/articles/new.html.erb:6` |  | 2.25 | 1.5 | 0.17 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 7%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:208` 7%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:294` 4% | ArticlesController#create 100%, ArticlesController#new 0% | `<%= render "form", article: @article %>` |
| 23 | `app/views/articles/edit.html.erb:8` |  | 1.83 | 0.0 | 0.25 | `RAILS/activerecord/lib/active_record/integration.rb:59` 14%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 9%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 9% | ArticlesController#update 100%, ArticlesController#edit 0% | `<%= link_to "Show this article", @article, class: "w-full sm:w-auto te` |
| 24 | `app/controllers/articles_controller.rb:24` | `create` | 1.33 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:101` 25%, `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:281` 13%, `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:75` 13% | ArticlesController#create 100% | `@article = Article.new(article_params)` |
| 25 | `app/views/articles/edit.html.erb:9` |  | 1.17 | 0.0 | 0.33 | `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 14%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 14%, `RAILS/actionpack/lib/action_controller/metal/url_for.rb:49` 7% | ArticlesController#update 100%, ArticlesController#edit 0% | `<%= link_to "Back to articles", articles_path, class: "w-full sm:w-aut` |
| 26 | `app/views/articles/new.html.erb:8` |  | 1.17 | 0.0 | 0.33 | `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 14%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` 14%, `RAILS/actionpack/lib/action_dispatch/http/url.rb:170` 7% | ArticlesController#create 100%, ArticlesController#new 0% | `<%= link_to "Back to articles", articles_path, class: "w-full sm:w-aut` |
| 27 | `app/controllers/articles_controller.rb:26` | `create` | 1.08 | 0.0 | 0.08 | `RAILS/actionpack/lib/action_dispatch/http/response.rb:496` 15%, `RAILS/actionpack/lib/action_dispatch/http/mime_type.rb:299` 15%, `RAILS/actionpack/lib/action_dispatch/http/response.rb:510` 15% | ArticlesController#create 100% | `respond_to do \|format\|` |
| 28 | `app/controllers/articles_controller.rb:39` | `update` | 1.08 | 0.0 | 0.08 | `RAILS/actionpack/lib/action_dispatch/http/mime_type.rb:299` 15%, `RAILS/actionpack/lib/action_dispatch/http/response.rb:510` 15%, `RAILS/actionpack/lib/action_dispatch/http/response.rb:496` 15% | ArticlesController#update 100% | `respond_to do \|format\|` |
| 29 | `app/views/articles/_form.html.erb:4` |  | 0.83 | 0.0 | 0.17 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:382` 40%, `RAILS/activesupport/lib/active_support/inflector/methods.rb:377` 20%, `RAILS/actionview/lib/action_view/helpers/text_helper.rb:298` 20% | ArticlesController#create 50%, ArticlesController#update 50% | `<h2><%= pluralize(article.errors.count, "error") %> prohibited this ar` |
| 30 | `app/views/layouts/application.html.erb:12` |  | 0.5 | 0.0 | 0.17 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` 33%, `RAILS/actionview/lib/action_view/renderer/template_renderer.rb:77` 33%, `RAILS/actionview/lib/action_view/flows.rb:10` 33% | ArticlesController#update 50%, ArticlesController#create 50%, ArticlesController#new 0% | `<%= yield :head %>` |

78.42 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | ArticlesController#update | 2 / 2 | 3791.0 / 3792.0 | 1.0 | 5594.0 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 241.0, `GEM/i18n/lib/i18n/backend/base.rb:157` 226.0, `GEM/i18n/lib/i18n.rb:396` 185.0 | `app/views/articles/_form.html.erb:21` 763.0, `app/views/articles/_form.html.erb:8` 498.0, `app/views/articles/_form.html.erb:16` 405.0 |
| 2 | ArticlesController#create | 2 / 2 | 3769.0 / 3770.0 | 1.0 | 2506.0 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 253.0, `GEM/i18n/lib/i18n/backend/base.rb:157` 226.0, `GEM/i18n/lib/i18n.rb:396` 185.0 | `app/views/articles/_form.html.erb:21` 763.0, `app/views/articles/_form.html.erb:8` 607.0, `app/views/articles/_form.html.erb:16` 405.0 |
| 3 | CommentsController#create | 2 / 2 | 1157.0 / 1149.0 | -8.0 | 1633.0 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 248.0, `GEM/uri/lib/uri/common.rb:456` 13.0, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 12.0 | `app/controllers/comments_controller.rb:6` 288.0, `app/controllers/comments_controller.rb:9` 128.0, `app/controllers/comments_controller.rb:5` 116.0 |
| 4 | ArticlesController#edit | 1 / 1 | – / – |  | 15666.0 |  |  |
| 5 | ArticlesController#index | 1 / 1 | – / – |  | 2812.0 |  |  |
| 6 | ArticlesController#show | 1 / 1 | – / – |  | 2634.0 |  |  |
| 7 | ArticlesController#destroy | 1 / 1 | – / – |  | 1767.0 |  |  |
| 8 | CommentsController#destroy | 1 / 1 | – / – |  | 1702.0 |  |  |
| 9 | ArticlesController#new | 1 / 1 | – / – |  | 1528.0 |  |  |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` | `within_new_transaction` | 40.75 / 40.75 | 0.0 | 61.83 | 25% | String, Array |  | `app/controllers/articles_controller.rb:27` 34%, `app/controllers/comments_controller.rb:6` 33% | `raise` |
| 2 | `GEM/i18n/lib/i18n/backend/base.rb:157` | `resolve` | 39.17 / 39.17 | 0.0 | 40.0 | 42% | Hash |  | `app/views/articles/_form.html.erb:21` 35%, `app/views/articles/_form.html.erb:8` 20% | `**options.merge(` |
| 3 | `GEM/i18n/lib/i18n.rb:396` | `normalize_keys` | 32.42 / 32.42 | 0.0 | 33.33 | 42% | Array |  | `app/views/articles/_form.html.erb:21` 33%, `app/views/articles/_form.html.erb:8` 21% | `[` |
| 4 | `GEM/i18n/lib/i18n/backend/simple.rb:100` | `lookup` | 29.17 / 29.17 | 0.0 | 30.0 | 42% | String |  | `app/views/articles/_form.html.erb:21` 33%, `app/views/articles/_form.html.erb:8` 20% | `_key = _key.to_s.to_sym` |
| 5 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` | `tag_option` | 27.75 / 27.75 | 0.0 | 31.92 | 75% | String |  | `app/views/layouts/application.html.erb:23` 27%, `app/views/articles/_article.html.erb:14` 12% | `%(#{key}="#{value}")` |
| 6 | `GEM/i18n/lib/i18n/utils.rb:8` | `except` | 25.42 / 25.42 | 0.0 | 26.5 | 42% | Hash |  | `app/views/articles/_form.html.erb:21` 30%, `app/views/articles/_form.html.erb:8` 21% | `hash.except(*keys)` |
| 7 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:146` | `humanize` | 23.5 / 23.5 | 0.0 | 25.0 | 42% | String, MatchData |  | `app/views/articles/_form.html.erb:8` 24%, `app/views/articles/_form.html.erb:21` 24% | `result.gsub!(/([[[:alpha:]]\d]+)/i) do \|match\|` |
| 8 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | `#{method}` | 19.67 / 19.67 | 0.0 | 21.5 | 100% | Hash, Array |  | `no app frame` 48%, `app/controllers/articles_controller.rb:52` 5% | `dispatch(:#{method}, ...)` |
| 9 | `GEM/i18n/lib/i18n/backend/base.rb:155` | `resolve` | 19.58 / 19.58 | 0.0 | 20.0 | 42% | Hash |  | `app/views/articles/_form.html.erb:21` 35%, `app/views/articles/_form.html.erb:8` 20% | `I18n.translate(` |
| 10 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` | `html_safe` | 19.42 / 19.42 | 0.0 | 22.42 | 75% | String |  | `app/views/layouts/application.html.erb:23` 29%, `app/views/layouts/application.html.erb:22` 11% | `ActiveSupport::SafeBuffer.new(self)` |
| 11 | `GEM/i18n/lib/i18n/backend/base.rb:45` | `translate` | 19.33 / 19.33 | 0.0 | 19.75 | 42% | Object, Data |  | `app/views/articles/_form.html.erb:21` 35%, `app/views/articles/_form.html.erb:8` 20% | `throw(:exception, I18n::MissingTranslation.new(locale, key, options))` |
| 12 | `GEM/i18n/lib/i18n/exceptions.rb:53` | `initialize` | 19.33 / 19.33 | 0.0 | 19.67 | 42% | Hash |  | `app/views/articles/_form.html.erb:21` 36%, `app/views/articles/_form.html.erb:8` 20% | `@key, @locale, @options = key, locale, options.slice(*PERMITTED_KEYS)` |
| 13 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` | `initialize` | 18.08 / 18.08 | 0.0 | 20.92 | 75% | String |  | `app/views/layouts/application.html.erb:23` 31%, `app/views/layouts/application.html.erb:22` 12% | `super` |
| 14 | `GEM/i18n/lib/i18n/interpolate/ruby.rb:33` | `interpolate_hash` | 13.5 / 13.5 | 0.0 | 14.0 | 33% | String, MatchData |  | `app/views/articles/_form.html.erb:8` 43%, `app/views/articles/_form.html.erb:21` 29% | `interpolated_string = string.gsub(pattern) do \|match\|` |
| 15 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` | `xml_name_escape` | 13.17 / 13.17 | 0.0 | 14.83 | 75% | String |  | `app/views/layouts/application.html.erb:23` 57%, `app/views/articles/_article.html.erb:14` 17% | `name = name.to_s` |
| 16 | `GEM/i18n/lib/i18n/backend/base.rb:58` | `translate` | 13.08 / 13.08 | 0.0 | 13.67 | 42% | Array |  | `app/views/articles/_form.html.erb:21` 29%, `app/views/articles/_form.html.erb:8` 22% | `values = Utils.except(options, *RESERVED_KEYS) unless options.empty?` |
| 17 | `GEM/i18n/lib/i18n/backend/base.rb:132` | `default` | 12.33 / 12.33 | 0.0 | 12.83 | 42% | Array |  | `app/views/articles/_form.html.erb:21` 31%, `app/views/articles/_form.html.erb:8` 19% | `options = Utils.except(options, :default)` |
| 18 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:237` | `tag_options` | 11.75 / 11.75 | 0.0 | 13.42 | 75% | String |  | `app/views/layouts/application.html.erb:23` 34%, `app/views/articles/_article.html.erb:14` 9% | `output = +""` |
| 19 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:208` | `dispatch` | 11.33 / 11.33 | 0.0 | 12.0 | 100% | Data |  | `no app frame` 56%, `app/models/comment.rb:14` 6% | `block = proc { \|*args, **kwargs\|` |
| 20 | `GEM/i18n/lib/i18n.rb:476` | `normalize_key` | 10.5 / 10.5 | 0.0 | 15.58 | 33% | String, Array |  | `app/views/articles/_form.html.erb:8` 45%, `app/views/articles/_form.html.erb:25` 17% | `keys = key.to_s.split(separator)` |
| 21 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` | `build_handle` | 9.83 / 9.83 | 0.0 | 10.92 | 100% | Object, Data | #59613 merged 2026-11-04, after this app's version, not released yet, #59235 merged 2026-10-21, after this app's version, not released yet | `no app frame` 31%, `app/controllers/articles_controller.rb:52` 8% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 22 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:217` | `dispatch` | 9.83 / 9.83 | 0.0 | 10.75 | 100% | Array |  | `no app frame` 48%, `app/controllers/articles_controller.rb:52` 5% | `@broadcasts.map { \|logger\|` |
| 23 | `RUBY/ipaddr.rb:725` | `in_addr` | 9.17 / 9.17 | 0.0 | 10.0 | 100% | String, Array |  | `no app frame` 100% | `octets = addr.split('.')` |
| 24 | `RAILS/activesupport/lib/active_support/core_ext/hash/keys.rb:11` | `stringify_keys` | 9.17 / 9.17 | 0.0 | 9.42 | 100% | Hash |  | `app/views/layouts/application.html.erb:22` 16%, `app/views/articles/_article.html.erb:14` 9% | `transform_keys { \|k\| Symbol === k ? k.name : k.to_s }` |
| 25 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:287` | `build_handle` | 8.75 / 8.75 | 0.0 | 9.67 | 100% | Array | #59235 merged 2026-10-21, after this app's version, not released yet | `no app frame` 38%, `app/controllers/articles_controller.rb:63` 9% | `groups = groups_for(name).map do \|group_klass, grouped_listeners\|` |
| 26 | `RAILS/actionpack/lib/action_dispatch/http/request.rb:66` | `initialize` | 8.5 / 8.5 | 0.0 | 9.25 | 100% | Object |  | `no app frame` 97%, `app/models/comment.rb:14` 2% | `@rack_request = Rack::Request.new(env)` |
| 27 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` | `call` | 8.17 / 8.17 | 0.0 | 9.17 | 100% | Data |  | `no app frame` 73%, `app/controllers/articles_controller.rb:40` 9% | `result_lambda = -> { user_callback.call target, value }` |
| 28 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:152` | `humanize` | 7.83 / 7.83 | 0.0 | 8.33 | 42% | String |  | `app/views/articles/_form.html.erb:21` 24%, `app/views/articles/_form.html.erb:8` 24% | `result.sub!(/\A[[:alpha:]]/) do \|match\|` |
| 29 | `GEM/uri/lib/uri/common.rb:456` | `_encode_uri_component` | 8.0 / 7.58 | -0.42 | 9.08 | 50% | String, MatchData |  | `no app frame` 100% | `str.gsub!(regexp, table)` |
| 30 | `RUBY/random/formatter.rb:174` † | `uuid` | 7.58 / 7.58 | 0.0 | 8.75 | 100% | String, Array |  | `no app frame` 80%, `app/controllers/articles_controller.rb:27` 7% | `ary.unpack("H8H4H4H4H12").join(?-)` |

## Dev/test-mode work

320.8 of 1777.9 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | template compile | `GEM/erubi/lib/erubi.rb:134` | 20.33 | 33% | `no app frame` 69%, `app/views/articles/edit.html.erb:6` 16% | `input.scan(regexp) do \|indicator, code, tailch, rspace\|` |
| 2 | debug logging | `RAILS/actionpack/lib/abstract_controller/logger.rb:12` | 18.17 | 100% | `no app frame` 83%, `app/controllers/comments_controller.rb:9` 3% | `singleton_class.delegate :logger, :logger=, to: :config` |
| 3 | asset lookup | `GEM/propshaft/lib/propshaft/helper.rb:113` † | 16.67 | 50% | `app/views/layouts/application.html.erb:22` 100% | `Rails.application.assets.load_path.asset_paths_by_glob("#{Rails.root.j` |
| 4 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:177` | 14.0 | 83% | `app/controllers/articles_controller.rb:63` 16%, `app/controllers/articles_controller.rb:52` 16% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 5 | debug logging | `GEM/logger/lib/logger.rb:685` | 11.33 | 100% | `no app frame` 56%, `app/controllers/articles_controller.rb:31` 6% | `message = yield` |
| 6 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` | 10.58 | 83% | `app/controllers/articles_controller.rb:63` 24%, `app/controllers/comments_controller.rb:22` 15% | `binds = binds.inspect` |
| 7 | debug logging | `RAILS/actionview/lib/action_view/log_subscriber.rb:61` | 10.17 | 75% | `no app frame` 50%, `app/controllers/articles_controller.rb:31` 13% | `string = string.sub(rails_root, "")` |
| 8 | debug logging | `GEM/logger/lib/logger.rb:692` † | 9.67 | 100% | `no app frame` 49%, `app/controllers/articles_controller.rb:52` 6% | `format_message(format_severity(severity), Time.now, progname, message)` |
| 9 | debug logging | `GEM/logger/lib/logger/log_device.rb:33` | 9.67 | 100% | `no app frame` 49%, `app/controllers/articles_controller.rb:52` 6% | `handle_write_errors("writing") {@dev.write(message)}` |
| 10 | debug logging | `GEM/logger/lib/logger/log_device.rb:165` | 9.67 | 100% | `no app frame` 49%, `app/controllers/articles_controller.rb:52` 6% | `if @filename && (@shift_age > 0) && (@dev.stat.size > @shift_size)` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activesupport | 365.0 | 453.0 | `methods.rb:146` 23.5, `broadcast_logger.rb:129` 19.7, `output_safety.rb:242` 19.4 |
| rails: actionview | 261.5 | 360.2 | `tag_helper.rb:309` 27.8, `tag_helper.rb:237` 11.8, `log_subscriber.rb:61` 10.2 |
| rails: actionpack | 261.0 | 545.0 | `logger.rb:12` 18.2, `request.rb:66` 8.5, `visitors.rb:40` 6.8 |
| gem: i18n | 242.7 | 258.5 | `base.rb:157` 39.2, `i18n.rb:396` 32.4, `simple.rb:100` 29.2 |
| rails: activerecord | 219.6 | 322.1 | `transaction.rb:653` 40.8, `log_subscriber.rb:49` 10.6, `integration.rb:59` 7.5 |
| rails: activemodel | 82.8 | 122.3 | `errors.rb:443` 4.7, `translation.rb:70` 4.0, `translation.rb:76` 3.8 |
| ruby stdlib | 46.2 | 83.3 | `ipaddr.rb:725` 9.2, `formatter.rb:174` 7.6, `bundled_gems.rb:111` 5.4 |
| gem: rack | 41.8 | 126.7 | `request.rb:696` 6.3, `body_proxy.rb:12` 3.7, `request.rb:607` 3.1 |
| gem: logger | 40.3 | 43.5 | `logger.rb:685` 11.3, `logger.rb:692` 9.7, `log_device.rb:165` 9.7 |
| gem: propshaft | 34.7 | 959.8 | `helper.rb:113` 16.7, `asset.rb:73` 6.7, `dynamic.rb:11` 3.3 |
| gem: erubi | 34.2 | 53.3 | `erubi.rb:134` 20.3, `erubi.rb:137` 4.3, `erubi.rb:139` 3.1 |
| ruby default gem: uri | 30.4 | 39.3 | `common.rb:456` 7.8, `common.rb:465` 4.5, `rfc3986_parser.rb:85` 1.7 |
| gem: importmap-rails | 21.7 | 178.7 | `importmap_tags_helper.rb:44` 5.8, `importmap_tags_helper.rb:30` 5.8, `importmap_tags_helper.rb:42` 3.8 |
| gem: concurrent-ruby | 18.9 | 21.7 | `safe_initialization.rb:30` 5.5, `mutex_lockable_object.rb:32` 1.8, `mutex_lockable_object.rb:33` 1.8 |
| gem: sqlite3 | 16.7 | 18.5 | `statement.rb:159` 6.3, `statement.rb:76` 4.8, `statement.rb:36` 1.7 |
| app | 16.4 | 32.5 | `_article.html.erb:14` 1.7, `_article.html.erb:13` 1.3, `application.html.erb:22` 1.3 |
| gem: turbo-rails | 12.4 | 19.6 | `stream_name.rb:26` 2.5, `broadcastable.rb:521` 2.0, `request_id_tracking.rb:10` 0.9 |
| gem: bootsnap | 11.1 | 37.5 | `iseq.rb:103` 4.3, `cache.rb:218` 2.0, `iseq.rb:159` 1.1 |
| rails: activejob | 9.2 | 13.8 | `log_subscriber.rb:207` 2.0, `arguments.rb:141` 1.7, `arguments.rb:61` 0.5 |
| rails: railties | 8.3 | 12.2 | `logger.rb:57` 1.8, `engine.rb:748` 0.9, `logger.rb:61` 0.9 |
| gem: globalid | 6.3 | 9.5 | `gid.rb:95` 1.7, `gid.rb:159` 1.3, `gid.rb:166` 0.7 |
| gem: tzinfo | 3.0 | 4.4 | `timestamp.rb:208` 1.3, `timestamp.rb:193` 0.7, `constant_offset_data_timezone_info.rb:52` 0.7 |
| gem: rack-session | 2.7 | 3.1 | `id.rb:277` 0.9, `id.rb:275` 0.9, `id.rb:401` 0.4 |
| rails: actioncable | 2.3 | 4.3 | `broadcasting.rb:53` 0.5, `subscriber_map.rb:9` 0.3, `broadcasting.rb:55` 0.3 |
| gem: base64 | 1.8 | 2.2 | `base64.rb:283` 1.8 |
| ruby default gem: securerandom | 1.5 | 1.8 | `securerandom.rb:71` 1.5 |
| gem: json | 1.5 | 1.9 | `common.rb:861` 1.3, `common.rb:775` 0.1, `common.rb:769` 0.1 |
| gem: solid_queue | 0.5 | 0.8 | `batch_id.rb:20` 0.3, `batch_id.rb:24` 0.2 |
| gem: useragent | 0.0 | 61.7 | `itunes.rb:11` 0.0, `playstation.rb:8` 0.0, `browsers.rb:12` 0.0 |
| rails: actiontext | 0.0 | 7.1 | `content.rb:29` 0.0, `rendering.rb:9` 0.0, `content.rb:0` 0.0 |
| gem: lowrail-profile | 0.0 | 0.2 | `profile.rb:55` 0.0, `profile.rb:65` 0.0 |
