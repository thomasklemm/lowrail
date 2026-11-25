# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails test -v`
* Ruby: ruby 3.3.14 (2026-11-19 revision f4c37f481b) +YJIT [x86_64-linux]
* Rails: 7.2.4, test environment
* Counted in run 1: 12 requests; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 12 | 5986.9 | 0 | 0 | 0 | 0 |
| run2 | 1 | 12 | 5990.3 | 0 | 0 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 4.0 objects per request; 1 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/views/articles/_form.html.erb:21` |  | 163.5 | 0.0 | 0.67 | `GEM/i18n/lib/i18n.rb:397` 13%, `GEM/i18n/lib/i18n/backend/base.rb:155` 9%, `GEM/i18n/lib/i18n/backend/base.rb:157` 9% | ArticlesController#create 50%, ArticlesController#update 50%, ArticlesController#new 0% | `<%= form.text_area :body, rows: 4, class: ["block shadow-sm rounded-md` |
| 2 | `app/views/articles/_form.html.erb:8` |  | 115.25 | 0.0 | 0.0 | `GEM/i18n/lib/i18n.rb:397` 12%, `GEM/i18n/lib/i18n/backend/base.rb:157` 7%, `GEM/i18n/lib/i18n/backend/base.rb:155` 7% | ArticlesController#create 54%, ArticlesController#update 46% | `<li><%= error.full_message %></li>` |
| 3 | `app/views/articles/_form.html.erb:16` |  | 85.83 | 0.0 | 0.67 | `GEM/i18n/lib/i18n.rb:397` 13%, `GEM/i18n/lib/i18n/backend/base.rb:157` 8%, `GEM/i18n/lib/i18n/backend/base.rb:155` 8% | ArticlesController#update 50%, ArticlesController#create 50%, ArticlesController#edit 0% | `<%= form.text_field :title, class: ["block shadow-sm rounded-md border` |
| 4 | `app/views/articles/_form.html.erb:20` |  | 68.17 | 0.0 | 0.0 | `GEM/i18n/lib/i18n.rb:397` 13%, `GEM/i18n/lib/i18n/backend/base.rb:155` 8%, `GEM/i18n/lib/i18n/backend/base.rb:157` 8% | ArticlesController#create 50%, ArticlesController#update 50%, ArticlesController#new 0% | `<%= form.label :body %>` |
| 5 | `app/views/articles/_form.html.erb:15` |  | 42.5 | 0.0 | 0.0 | `GEM/i18n/lib/i18n.rb:397` 12%, `GEM/i18n/lib/i18n/backend/base.rb:155` 7%, `GEM/i18n/lib/i18n/backend/base.rb:157` 7% | ArticlesController#create 50%, ArticlesController#update 50%, ArticlesController#new 0% | `<%= form.label :title %>` |
| 6 | `app/controllers/articles_controller.rb:40` | `update` | 15.92 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:621` 56%, `RAILS/activemodel/lib/active_model/errors.rb:344` 5%, `RAILS/activemodel/lib/active_model/error.rb:205` 3% | ArticlesController#update 100% | `if @article.update(article_params)` |
| 7 | `app/controllers/articles_controller.rb:27` | `create` | 15.17 | 0.0 | 0.08 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:621` 62%, `RAILS/activemodel/lib/active_model/errors.rb:344` 5%, `RAILS/activemodel/lib/active_model/error.rb:205` 3% | ArticlesController#create 100% | `if @article.save` |
| 8 | `app/views/layouts/application.html.erb:18` |  | 14.0 | 9.83 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` 20%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 20%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` 15% | ArticlesController#create 50%, ArticlesController#update 50%, ArticlesController#show 0% | `<%= javascript_importmap_tags %>` |
| 9 | `app/controllers/comments_controller.rb:6` | `create` | 13.67 | 0.0 | 0.08 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:621` 68%, `RAILS/activemodel/lib/active_model/errors.rb:344` 4%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 2% | CommentsController#create 100% | `if @comment.save` |
| 10 | `app/controllers/articles_controller.rb:31` | `create` | 13.17 | 6.0 | 0.25 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 8%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:208` 5%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:206` 5% | ArticlesController#create 100% | `format.html { render :new, status: :unprocessable_content }` |
| 11 | `app/controllers/articles_controller.rb:44` | `update` | 13.17 | 6.0 | 0.25 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 8%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:206` 5%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:208` 5% | ArticlesController#update 100% | `format.html { render :edit, status: :unprocessable_content }` |
| 12 | `app/controllers/comments_controller.rb:9` | `create` | 12.67 | 0.67 | 0.25 | `RUBY/uri/rfc3986_parser.rb:135` 5%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:50` 5%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:7` 4% | CommentsController#create 100% | `redirect_to @article, alert: "Could not create comment."` |
| 13 | `app/controllers/comments_controller.rb:5` | `create` | 12.67 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:129` 8%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `RAILS/activerecord/lib/active_record/core.rb:420` 4% | CommentsController#create 100% | `@comment = @article.comments.build(comment_params)` |
| 14 | `app/views/articles/_form.html.erb:25` |  | 12.5 | 0.0 | 0.33 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:146` 8%, `GEM/i18n/lib/i18n.rb:397` 8%, `GEM/i18n/lib/i18n/interpolate/ruby.rb:33` 8% | ArticlesController#update 50%, ArticlesController#create 50%, ArticlesController#new 0% | `<%= form.submit class: "w-full sm:w-auto rounded-md px-3.5 py-2.5 bg-b` |
| 15 | `app/views/articles/_form.html.erb:1` |  | 9.58 | 0.0 | 0.5 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 10%, `GEM/rack/lib/rack/request.rb:696` 7%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` 4% | ArticlesController#update 58%, ArticlesController#create 42%, ArticlesController#edit 0% | `<%= form_with(model: article, class: "contents") do \|form\| %>` |
| 16 | `app/views/layouts/application.html.erb:17` |  | 9.08 | 41.0 | 0.67 | `RUBY/uri/rfc2396_parser.rb:292` 20%, `RUBY/set.rb:244` 9%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` 6% | ArticlesController#create 52%, ArticlesController#update 48%, ArticlesController#index 0% | `<%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>` |
| 17 | `app/views/layouts/application.html.erb:16` |  | 7.33 | 27.67 | 0.67 | `RUBY/uri/rfc2396_parser.rb:292` 11%, `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` 7%, `RAILS/actionview/lib/action_view/helpers/asset_tag_helper.rb:660` 7% | ArticlesController#create 50%, ArticlesController#update 50%, ArticlesController#index 0% | `<%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>` |
| 18 | `app/controllers/articles_controller.rb:63` | `set_article` | 5.83 | 3.08 | 0.08 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` 7%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 4%, `GEM/sqlite3/lib/sqlite3/statement.rb:76` 4% | ArticlesController#update 100%, ArticlesController#show 0%, ArticlesController#destroy 0% | `@article = Article.find(params[:id])` |
| 19 | `app/controllers/comments_controller.rb:22` | `set_article` | 5.83 | 3.08 | 0.08 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` 7%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:236` 4%, `GEM/sqlite3/lib/sqlite3/statement.rb:76` 4% | CommentsController#create 100%, CommentsController#destroy 0% | `@article = Article.find(params.require(:article_id))` |
| 20 | `app/controllers/articles_controller.rb:68` | `article_params` | 5.0 | 0.0 | 0.17 | `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:1118` 13%, `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:73` 8%, `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:1160` 7% | ArticlesController#create 53%, ArticlesController#update 47% | `params.require(:article).permit(:title, :body)` |
| 21 | `app/views/articles/edit.html.erb:6` |  | 2.75 | 1.67 | 0.17 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 9%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:208` 6%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:206` 6% | ArticlesController#update 100%, ArticlesController#edit 0% | `<%= render "form", article: @article %>` |
| 22 | `app/views/articles/new.html.erb:6` |  | 2.75 | 1.67 | 0.17 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 9%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:206` 6%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:212` 6% | ArticlesController#create 100%, ArticlesController#new 0% | `<%= render "form", article: @article %>` |
| 23 | `app/controllers/comments_controller.rb:26` | `comment_params` | 2.33 | 0.0 | 0.08 | `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:1118` 14%, `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:406` 7%, `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:288` 7% | CommentsController#create 100% | `params.require(:comment).permit(:commenter, :body)` |
| 24 | `app/views/articles/edit.html.erb:8` |  | 1.83 | 0.0 | 0.25 | `RAILS/activerecord/lib/active_record/integration.rb:59` 14%, `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 9%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 9% | ArticlesController#update 100%, ArticlesController#edit 0% | `<%= link_to "Show this article", @article, class: "w-full sm:w-auto te` |
| 25 | `app/controllers/articles_controller.rb:24` | `create` | 1.58 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 26%, `RAILS/activemodel/lib/active_model/attribute_assignment.rb:47` 11%, `RAILS/activemodel/lib/active_model/attribute.rb:13` 11% | ArticlesController#create 100% | `@article = Article.new(article_params)` |
| 26 | `app/controllers/articles_controller.rb:39` | `update` | 1.5 | 0.0 | 0.08 | `RAILS/actionpack/lib/action_dispatch/http/response.rb:473` 22%, `RAILS/actionpack/lib/action_dispatch/http/mime_type.rb:299` 11%, `RAILS/actionpack/lib/action_dispatch/http/mime_type.rb:300` 11% | ArticlesController#update 100% | `respond_to do \|format\|` |
| 27 | `app/controllers/articles_controller.rb:26` | `create` | 1.25 | 0.0 | 0.08 | `RAILS/actionpack/lib/action_dispatch/http/response.rb:473` 20%, `RAILS/actionpack/lib/action_dispatch/http/mime_type.rb:299` 13%, `RAILS/actionpack/lib/action_dispatch/http/response.rb:459` 13% | ArticlesController#create 100% | `respond_to do \|format\|` |
| 28 | `app/views/articles/edit.html.erb:9` |  | 1.17 | 0.0 | 0.33 | `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 14%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 14%, `RAILS/actionpack/lib/action_controller/metal/url_for.rb:49` 7% | ArticlesController#update 100%, ArticlesController#edit 0% | `<%= link_to "Back to articles", articles_path, class: "w-full sm:w-aut` |
| 29 | `app/views/articles/new.html.erb:8` |  | 1.17 | 0.0 | 0.33 | `RAILS/actionpack/lib/action_dispatch/journey/visitors.rb:40` 14%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` 14%, `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:258` 7% | ArticlesController#create 100%, ArticlesController#new 0% | `<%= link_to "Back to articles", articles_path, class: "w-full sm:w-aut` |
| 30 | `app/views/articles/_form.html.erb:4` |  | 1.0 | 0.0 | 0.33 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:382` 33%, `RAILS/actionview/lib/action_view/helpers/text_helper.rb:304` 17%, `RAILS/activesupport/lib/active_support/inflector/methods.rb:377` 17% | ArticlesController#update 50%, ArticlesController#create 50% | `<h2><%= pluralize(article.errors.count, "error") %> prohibited this ar` |

86.92 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | ArticlesController#update | 2 / 2 | 4699.0 / 4700.0 | 1.0 | 3294.5 | `GEM/i18n/lib/i18n.rb:397` 370.0, `GEM/i18n/lib/i18n/backend/base.rb:155` 226.0, `GEM/i18n/lib/i18n/backend/base.rb:157` 226.0 | `app/views/articles/_form.html.erb:21` 981.0, `app/views/articles/_form.html.erb:8` 637.0, `app/views/articles/_form.html.erb:16` 515.0 |
| 2 | ArticlesController#create | 2 / 2 | 4668.0 / 4668.0 | 0.0 | 3051.5 | `GEM/i18n/lib/i18n.rb:397` 370.0, `GEM/i18n/lib/i18n/backend/base.rb:155` 226.0, `GEM/i18n/lib/i18n/backend/base.rb:157` 226.0 | `app/views/articles/_form.html.erb:21` 981.0, `app/views/articles/_form.html.erb:8` 746.0, `app/views/articles/_form.html.erb:16` 515.0 |
| 3 | CommentsController#create | 2 / 2 | 1114.0 / 1120.0 | 6.0 | 4623.0 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:621` 111.0, `RUBY/uri/common.rb:394` 45.0, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 18.0 | `app/controllers/comments_controller.rb:6` 164.0, `app/controllers/comments_controller.rb:5` 152.0, `app/controllers/comments_controller.rb:9` 152.0 |
| 4 | ArticlesController#edit | 1 / 1 | – / – |  | 18950.0 |  |  |
| 5 | ArticlesController#index | 1 / 1 | – / – |  | 3536.0 |  |  |
| 6 | ArticlesController#show | 1 / 1 | – / – |  | 3409.0 |  |  |
| 7 | ArticlesController#new | 1 / 1 | – / – |  | 2050.0 |  |  |
| 8 | CommentsController#destroy | 1 / 1 | – / – |  | 2036.0 |  |  |
| 9 | ArticlesController#destroy | 1 / 1 | – / – |  | 2014.0 |  |  |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/i18n/lib/i18n.rb:397` | `normalize_keys` | 64.83 / 64.83 | 0.0 | 66.67 | 42% | Array |  | `app/views/articles/_form.html.erb:21` 33%, `app/views/articles/_form.html.erb:8` 21% | `*normalize_key(locale, separator),` |
| 2 | `GEM/i18n/lib/i18n/backend/base.rb:155` | `resolve` | 39.17 / 39.17 | 0.0 | 40.0 | 42% | Hash |  | `app/views/articles/_form.html.erb:21` 35%, `app/views/articles/_form.html.erb:8` 20% | `I18n.translate(` |
| 3 | `GEM/i18n/lib/i18n/backend/base.rb:157` | `resolve` | 39.17 / 39.17 | 0.0 | 40.0 | 42% | Hash |  | `app/views/articles/_form.html.erb:21` 35%, `app/views/articles/_form.html.erb:8` 20% | `**options.merge(` |
| 4 | `GEM/i18n/lib/i18n.rb:396` | `normalize_keys` | 32.42 / 32.42 | 0.0 | 33.33 | 42% | Array |  | `app/views/articles/_form.html.erb:21` 33%, `app/views/articles/_form.html.erb:8` 21% | `[` |
| 5 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` | `tag_option` | 31.17 / 31.17 | 0.0 | 32.67 | 75% | String |  | `app/views/layouts/application.html.erb:18` 26%, `app/views/articles/_article.html.erb:14` 13% | `%(#{key}="#{value}")` |
| 6 | `GEM/i18n/lib/i18n/backend/simple.rb:100` | `lookup` | 29.17 / 29.17 | 0.0 | 30.0 | 42% | String |  | `app/views/articles/_form.html.erb:21` 33%, `app/views/articles/_form.html.erb:8` 20% | `_key = _key.to_s.to_sym` |
| 7 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | `#{method}` | 28.75 / 28.75 | 0.0 | 32.25 | 100% | Array, Hash |  | `no app frame` 48%, `app/controllers/articles_controller.rb:52` 5% | `dispatch(:#{method}, ...)` |
| 8 | `RUBY/set.rb:244` | `initialize` | 26.08 / 26.08 | 0.0 | 26.5 | 100% | Hash |  | `app/views/layouts/application.html.erb:18` 77%, `app/views/layouts/application.html.erb:17` 10% | `@hash \|\|= Hash.new(false)` |
| 9 | `GEM/i18n/lib/i18n/utils.rb:8` | `except` | 25.42 / 25.42 | 0.0 | 26.5 | 42% | Hash |  | `app/views/articles/_form.html.erb:21` 30%, `app/views/articles/_form.html.erb:8` 21% | `hash.except(*keys)` |
| 10 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:146` | `humanize` | 23.5 / 23.5 | 0.0 | 25.0 | 42% | String, MatchData |  | `app/views/articles/_form.html.erb:8` 24%, `app/views/articles/_form.html.erb:21` 24% | `result.gsub!(/([[[:alpha:]]\d]+)/i) do \|match\|` |
| 11 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` | `html_safe` | 21.58 / 21.58 | 0.0 | 22.5 | 75% | String |  | `app/views/layouts/application.html.erb:18` 29%, `app/views/layouts/application.html.erb:17` 7% | `ActiveSupport::SafeBuffer.new(self)` |
| 12 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` | `initialize` | 19.83 / 19.83 | 0.0 | 20.58 | 75% | String |  | `app/views/layouts/application.html.erb:18` 30%, `app/views/layouts/application.html.erb:16` 7% | `super` |
| 13 | `RUBY/uri/common.rb:394` | `_encode_uri_component` | 17.5 / 21.5 | 4.0 | 23.75 | 50% | String, MatchData |  | `no app frame` 100% | `str.gsub!(regexp, table)` |
| 14 | `GEM/i18n/lib/i18n/exceptions.rb:53` | `initialize` | 19.33 / 19.33 | 0.0 | 19.75 | 42% | Hash |  | `app/views/articles/_form.html.erb:21` 35%, `app/views/articles/_form.html.erb:8` 20% | `@key, @locale, @options = key, locale, options.slice(*PERMITTED_KEYS)` |
| 15 | `GEM/i18n/lib/i18n/backend/base.rb:45` | `translate` | 19.33 / 19.33 | 0.0 | 19.67 | 42% | Object |  | `app/views/articles/_form.html.erb:21` 36%, `app/views/articles/_form.html.erb:8` 20% | `throw(:exception, I18n::MissingTranslation.new(locale, key, options))` |
| 16 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:621` | `within_new_transaction` | 18.33 / 18.33 | 0.0 | 27.58 | 25% | String, Array |  | `app/controllers/articles_controller.rb:27` 34%, `app/controllers/comments_controller.rb:6` 34% | `raise` |
| 17 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` | `xml_name_escape` | 14.83 / 14.83 | 0.0 | 15.58 | 75% | String |  | `app/views/layouts/application.html.erb:18` 55%, `app/views/articles/_article.html.erb:14` 19% | `name = name.to_s` |
| 18 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:206` | `groups_for` | 14.67 / 14.67 | 0.0 | 16.33 | 100% | Array |  | `no app frame` 41%, `app/controllers/articles_controller.rb:52` 5% | `groups[group_class] = (groups[group_class] \|\| []) + active_subscriptio` |
| 19 | `GEM/i18n/lib/i18n/interpolate/ruby.rb:33` | `interpolate_hash` | 14.0 / 14.0 | 0.0 | 14.5 | 33% | String, MatchData |  | `app/views/articles/_form.html.erb:8` 45%, `app/views/articles/_form.html.erb:21` 28% | `interpolated_string = string.gsub(pattern) do \|match\|` |
| 20 | `GEM/i18n/lib/i18n/backend/base.rb:58` | `translate` | 13.08 / 13.08 | 0.0 | 13.67 | 42% | Array |  | `app/views/articles/_form.html.erb:21` 29%, `app/views/articles/_form.html.erb:8` 22% | `values = Utils.except(options, *RESERVED_KEYS) unless options.empty?` |
| 21 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:263` | `tag_options` | 12.83 / 12.83 | 0.0 | 13.42 | 75% | String |  | `app/views/layouts/application.html.erb:18` 34%, `app/views/articles/_article.html.erb:14` 9% | `output = +""` |
| 22 | `GEM/i18n/lib/i18n/backend/base.rb:132` | `default` | 12.33 / 12.33 | 0.0 | 12.83 | 42% | Array |  | `app/views/articles/_form.html.erb:21` 31%, `app/views/articles/_form.html.erb:8` 19% | `options = Utils.except(options, :default)` |
| 23 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:236` | `initialize` | 11.83 / 11.83 | 0.0 | 13.5 | 100% | Object |  | `no app frame` 25%, `app/controllers/articles_controller.rb:63` 9% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 24 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:152` | `humanize` | 11.75 / 11.75 | 0.0 | 12.5 | 42% | String, MatchData |  | `app/views/articles/_form.html.erb:21` 24%, `app/views/articles/_form.html.erb:8` 24% | `result.sub!(/\A[[:alpha:]]/) do \|match\|` |
| 25 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:208` | `dispatch` | 11.0 / 11.0 | 0.0 | 12.0 | 100% | Data |  | `no app frame` 56%, `app/controllers/articles_controller.rb:31` 6% | `block = proc { \|*args, **kwargs\|` |
| 26 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:212` | `dispatch` | 11.0 / 11.0 | 0.0 | 12.0 | 100% | Array, Hash |  | `no app frame` 56%, `app/models/comment.rb:14` 6% | `result = yield(*args, **kwargs)` |
| 27 | `GEM/i18n/lib/i18n.rb:476` | `normalize_key` | 10.5 / 10.5 | 0.0 | 15.58 | 33% | String, Array |  | `app/views/articles/_form.html.erb:8` 45%, `app/views/articles/_form.html.erb:25` 17% | `keys = key.to_s.split(separator)` |
| 28 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:218` | `dispatch` | 9.75 / 9.75 | 0.0 | 11.0 | 100% | Array, Hash |  | `no app frame` 47%, `app/controllers/articles_controller.rb:52` 5% | `logger.send(method, *args, **kwargs, &block)` |
| 29 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:217` | `dispatch` | 9.58 / 9.58 | 0.0 | 10.75 | 100% | Array |  | `no app frame` 48%, `app/controllers/articles_controller.rb:52` 5% | `@broadcasts.map { \|logger\|` |
| 30 | `RAILS/activesupport/lib/active_support/core_ext/hash/keys.rb:11` | `stringify_keys` | 9.25 / 9.25 | 0.0 | 9.92 | 100% | Hash |  | `app/views/layouts/application.html.erb:17` 10%, `app/views/layouts/application.html.erb:16` 10% | `transform_keys { \|k\| Symbol === k ? k.name : k.to_s }` |

## Dev/test-mode work

481.2 of 2217.6 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | template compile | `RAILS/actionview/lib/action_view/template.rb:503` | 37.58 | 33% | `no app frame` 67%, `app/views/articles/edit.html.erb:6` 17% | `mod.module_eval(compiled_source, identifier, offset)` |
| 2 | template compile | `GEM/erubi/lib/erubi.rb:134` | 20.33 | 33% | `no app frame` 68%, `app/views/articles/edit.html.erb:6` 16% | `input.scan(regexp) do \|indicator, code, tailch, rspace\|` |
| 3 | asset lookup | `GEM/sprockets/lib/sprockets/http_utils.rb:17` | 17.5 | 50% | `app/views/layouts/application.html.erb:18` 82%, `app/views/layouts/application.html.erb:16` 9% | `v1, v2 = value.split('/'.freeze, 2)` |
| 4 | asset lookup | `GEM/sprockets/lib/sprockets/http_utils.rb:18` | 17.5 | 50% | `app/views/layouts/application.html.erb:18` 82%, `app/views/layouts/application.html.erb:17` 9% | `m1, m2 = matcher.split('/'.freeze, 2)` |
| 5 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:183` | 13.5 | 83% | `app/controllers/articles_controller.rb:52` 16%, `app/controllers/articles_controller.rb:63` 16% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 6 | debug logging | `RAILS/actionview/lib/action_view/log_subscriber.rb:64` | 11.67 | 75% | `no app frame` 50%, `app/controllers/articles_controller.rb:44` 13% | `string = string.sub(rails_root, "")` |
| 7 | debug logging | `GEM/logger/lib/logger.rb:685` | 11.0 | 100% | `no app frame` 56%, `app/controllers/articles_controller.rb:44` 6% | `message = yield` |
| 8 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` | 9.75 | 83% | `app/controllers/articles_controller.rb:63` 24%, `app/controllers/comments_controller.rb:22` 15% | `binds = binds.inspect` |
| 9 | debug logging | `GEM/logger/lib/logger.rb:692` † | 9.42 | 100% | `no app frame` 49%, `app/controllers/articles_controller.rb:52` 6% | `format_message(format_severity(severity), Time.now, progname, message)` |
| 10 | debug logging | `GEM/logger/lib/logger/log_device.rb:33` | 9.42 | 100% | `no app frame` 49%, `app/controllers/articles_controller.rb:52` 6% | `handle_write_errors("writing") {@dev.write(message)}` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activesupport | 451.2 | 542.3 | `broadcast_logger.rb:129` 28.8, `methods.rb:146` 23.5, `output_safety.rb:228` 21.6 |
| gem: i18n | 327.6 | 345.7 | `i18n.rb:397` 64.8, `base.rb:155` 39.2, `base.rb:157` 39.2 |
| rails: actionview | 314.6 | 420.5 | `template.rb:503` 37.6, `tag_helper.rb:324` 31.2, `tag_helper.rb:263` 12.8 |
| rails: actionpack | 255.8 | 542.5 | `base.rb:100` 6.8, `static.rb:145` 6.8, `pattern.rb:77` 6.4 |
| rails: activerecord | 212.9 | 321.0 | `transaction.rb:621` 18.3, `log_subscriber.rb:49` 9.8, `delegation.rb:129` 6.8 |
| gem: sprockets | 161.1 | 1191.9 | `http_utils.rb:17` 17.5, `http_utils.rb:18` 17.5, `resolve.rb:218` 8.3 |
| ruby stdlib | 142.3 | 353.6 | `set.rb:244` 26.1, `common.rb:394` 19.5, `ipaddr.rb:659` 9.2 |
| rails: activemodel | 94.8 | 140.2 | `translation.rb:76` 7.3, `error.rb:86` 6.3, `naming.rb:204` 5.5 |
| gem: rack | 42.1 | 128.2 | `request.rb:696` 6.0, `body_proxy.rb:12` 3.7, `request.rb:607` 3.0 |
| ruby default gem: logger | 39.2 | 43.5 | `logger.rb:685` 11.0, `log_device.rb:33` 9.4, `log_device.rb:165` 9.4 |
| gem: erubi | 34.0 | 51.1 | `erubi.rb:134` 20.3, `erubi.rb:137` 4.3, `erubi.rb:139` 3.1 |
| gem: importmap-rails | 24.6 | 48.4 | `importmap_tags_helper.rb:44` 8.8, `importmap_tags_helper.rb:30` 5.8, `importmap_tags_helper.rb:42` 3.8 |
| gem: sqlite3 | 20.9 | 24.9 | `statement.rb:76` 6.8, `statement.rb:159` 6.1, `database.rb:215` 1.5 |
| app | 17.9 | 34.8 | `application.html.erb:16` 1.7, `application.html.erb:17` 1.7, `_article.html.erb:14` 1.7 |
| gem: turbo-rails | 16.6 | 24.2 | `stream_name.rb:26` 2.3, `broadcastable.rb:521` 1.8, `broadcasts.rb:41` 1.7 |
| rails: activejob | 14.7 | 22.0 | `log_subscriber.rb:148` 3.2, `arguments.rb:92` 2.2, `arguments.rb:142` 1.7 |
| gem: concurrent-ruby | 10.6 | 87.8 | `non_concurrent_map_backend.rb:26` 7.6, `non_concurrent_map_backend.rb:131` 1.5, `non_concurrent_map_backend.rb:120` 0.6 |
| gem: sprockets-rails | 10.4 | 22.0 | `helper.rb:81` 1.7, `helper.rb:357` 1.7, `helper.rb:186` 1.7 |
| gem: bootsnap | 10.2 | 34.6 | `iseq.rb:103` 4.0, `cache.rb:218` 1.8, `iseq.rb:159` 1.0 |
| rails: railties | 10.1 | 14.2 | `logger.rb:57` 2.8, `logger.rb:40` 0.9, `logger.rb:65` 0.9 |
| gem: globalid | 6.3 | 9.5 | `gid.rb:95` 1.7, `gid.rb:159` 1.3, `gid.rb:166` 0.7 |
| rails: actioncable | 4.9 | 6.3 | `broadcasting.rb:51` 1.7, `broadcasting.rb:39` 1.3, `broadcasting.rb:53` 0.4 |
| ruby default gem: base64 | 3.7 | 4.3 | `base64.rb:283` 3.7 |
| gem: json | 2.7 | 3.5 | `common.rb:378` 1.7, `common.rb:902` 0.4, `common.rb:896` 0.4 |
| gem: rack-session | 2.7 | 3.0 | `id.rb:277` 0.9, `id.rb:275` 0.9, `id.rb:401` 0.4 |
| gem: tzinfo | 2.3 | 3.8 | `timestamp.rb:208` 1.0, `timestamp.rb:193` 0.5, `constant_offset_data_timezone_info.rb:52` 0.5 |
| ruby default gem: securerandom | 1.5 | 1.8 | `securerandom.rb:71` 1.5 |
| rails: actiontext | 0.0 | 6.6 | `serialization.rb:6` 0.0, `rendering.rb:10` 0.0, `content.rb:30` 0.0 |
| gem: useragent | 0.0 | 60.1 | `user_agent.rb:3` 0.0, `webkit.rb:50` 0.0, `gecko.rb:12` 0.0 |
| gem: lowrail-profile | 0.0 | 0.1 | `profile.rb:64` 0.0 |
