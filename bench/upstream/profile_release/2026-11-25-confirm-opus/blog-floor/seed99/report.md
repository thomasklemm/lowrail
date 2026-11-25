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
| run1 | 1 | 12 | 6007.8 | 0 | 0 | 0 | 0 |
| run2 | 1 | 12 | 5984.8 | 0 | 0 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 2.25 objects per request; 1 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/controllers/articles_controller.rb:40` | `update` | 45.25 | 10.75 | 0.0 | `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 3%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 3%, `RAILS/activejob/lib/active_job/arguments.rb:92` 2% | ArticlesController#update 100% | `if @article.update(article_params)` |
| 2 | `app/controllers/articles_controller.rb:27` | `create` | 44.08 | 11.17 | 0.08 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 3%, `RAILS/activejob/lib/active_job/arguments.rb:92` 2%, `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:146` 2% | ArticlesController#create 100% | `if @article.save` |
| 3 | `app/controllers/articles_controller.rb:28` | `create` | 14.25 | 0.67 | 0.33 | `RAILS/activesupport/lib/active_support/messages/rotator.rb:50` 5%, `RUBY/uri/rfc3986_parser.rb:135` 5%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:7` 4% | ArticlesController#create 100% | `format.html { redirect_to @article, notice: "Article was successfully ` |
| 4 | `app/controllers/comments_controller.rb:6` | `create` | 13.67 | 0.0 | 0.08 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:621` 68%, `RAILS/activemodel/lib/active_model/errors.rb:344` 4%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 2% | CommentsController#create 100% | `if @comment.save` |
| 5 | `app/controllers/articles_controller.rb:41` | `update` | 12.92 | 0.67 | 0.33 | `RUBY/uri/rfc3986_parser.rb:135` 5%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:50` 5%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:7` 4% | ArticlesController#update 100% | `format.html { redirect_to @article, notice: "Article was successfully ` |
| 6 | `app/controllers/comments_controller.rb:9` | `create` | 12.67 | 0.67 | 0.25 | `RAILS/activesupport/lib/active_support/messages/rotator.rb:50` 5%, `RUBY/uri/rfc3986_parser.rb:135` 5%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:7` 4% | CommentsController#create 100% | `redirect_to @article, alert: "Could not create comment."` |
| 7 | `app/controllers/comments_controller.rb:5` | `create` | 12.67 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/relation/delegation.rb:129` 8%, `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 5%, `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 4% | CommentsController#create 100% | `@comment = @article.comments.build(comment_params)` |
| 8 | `app/controllers/articles_controller.rb:63` | `set_article` | 5.83 | 3.08 | 0.08 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` 7%, `GEM/sqlite3/lib/sqlite3/statement.rb:76` 4%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:236` 4% | ArticlesController#update 100%, ArticlesController#show 0%, ArticlesController#edit 0% | `@article = Article.find(params[:id])` |
| 9 | `app/controllers/comments_controller.rb:22` | `set_article` | 5.83 | 3.08 | 0.08 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` 7%, `GEM/sqlite3/lib/sqlite3/statement.rb:76` 4%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:236` 4% | CommentsController#create 100%, CommentsController#destroy 0% | `@article = Article.find(params.require(:article_id))` |
| 10 | `app/controllers/articles_controller.rb:68` | `article_params` | 5.0 | 0.0 | 0.17 | `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:1118` 13%, `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:73` 8%, `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:288` 7% | ArticlesController#create 53%, ArticlesController#update 47% | `params.require(:article).permit(:title, :body)` |
| 11 | `app/controllers/comments_controller.rb:26` | `comment_params` | 2.33 | 0.0 | 0.08 | `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:1118` 14%, `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:237` 7%, `RAILS/activesupport/lib/active_support/core_ext/array/wrap.rb:45` 7% | CommentsController#create 100% | `params.require(:comment).permit(:commenter, :body)` |
| 12 | `app/controllers/articles_controller.rb:24` | `create` | 1.58 | 0.0 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/object/deep_dup.rb:16` 26%, `RAILS/activemodel/lib/active_model/attribute_assignment.rb:47` 11%, `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:265` 11% | ArticlesController#create 100% | `@article = Article.new(article_params)` |
| 13 | `app/controllers/articles_controller.rb:26` | `create` | 1.25 | 0.0 | 0.08 | `RAILS/actionpack/lib/action_dispatch/http/response.rb:473` 20%, `RAILS/actionpack/lib/action_dispatch/http/response.rb:459` 13%, `RAILS/actionpack/lib/action_dispatch/http/mime_type.rb:299` 13% | ArticlesController#create 100% | `respond_to do \|format\|` |
| 14 | `app/controllers/articles_controller.rb:39` | `update` | 1.25 | 0.0 | 0.08 | `RAILS/actionpack/lib/action_dispatch/http/response.rb:473` 20%, `RAILS/actionpack/lib/action_dispatch/http/mime_type.rb:299` 13%, `RAILS/actionpack/lib/action_dispatch/http/response.rb:459` 13% | ArticlesController#update 100% | `respond_to do \|format\|` |
| 15 | `app/controllers/articles_controller.rb:29` | `create` | 0.25 | 0.0 | 0.08 | `RAILS/actionpack/lib/action_dispatch/http/mime_type.rb:176` 33%, `RAILS/actionpack/lib/action_controller/metal/mime_responds.rb:274` 33%, `RAILS/actionpack/lib/abstract_controller/collector.rb:13` 33% | ArticlesController#create 100% | `format.json { render :show, status: :created, location: @article }` |
| 16 | `app/controllers/articles_controller.rb:42` | `update` | 0.25 | 0.0 | 0.08 | `RAILS/actionpack/lib/action_controller/metal/mime_responds.rb:274` 33%, `RAILS/actionpack/lib/abstract_controller/collector.rb:13` 33%, `RAILS/actionpack/lib/action_dispatch/http/mime_type.rb:176` 33% | ArticlesController#update 100% | `format.json { render :show, status: :ok, location: @article }` |
| 17 | `app/models/article.rb:6` |  | 0.0 | 0.0 | 0.17 |  |  | `broadcasts_to ->(_article) { "articles" }, inserts_by: :prepend` |

110.25 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | ArticlesController#update | 2 / 2 | 1527.0 / 1518.0 | -9.0 | 3119.5 | `RUBY/uri/common.rb:401` 48.0, `RUBY/uri/common.rb:394` 33.0, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 33.0 | `app/controllers/articles_controller.rb:40` 543.0, `app/controllers/articles_controller.rb:41` 155.0, `app/controllers/articles_controller.rb:63` 70.0 |
| 2 | ArticlesController#create | 2 / 2 | 1423.0 / 1423.0 | 0.0 | 3617.0 | `RUBY/uri/common.rb:394` 39.0, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 30.0, `RUBY/uri/common.rb:401` 30.0 | `app/controllers/articles_controller.rb:27` 529.0, `app/controllers/articles_controller.rb:28` 171.0, `app/controllers/articles_controller.rb:68` 32.0 |
| 3 | CommentsController#create | 2 / 2 | 1109.0 / 1124.0 | 15.0 | 1836.5 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:621` 111.0, `RUBY/uri/common.rb:394` 48.0, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 18.0 | `app/controllers/comments_controller.rb:6` 164.0, `app/controllers/comments_controller.rb:5` 152.0, `app/controllers/comments_controller.rb:9` 152.0 |
| 4 | ArticlesController#new | 1 / 1 | – / – |  | 23398.0 |  |  |
| 5 | ArticlesController#index | 1 / 1 | – / – |  | 3536.0 |  |  |
| 6 | ArticlesController#show | 1 / 1 | – / – |  | 3513.0 |  |  |
| 7 | ArticlesController#edit | 1 / 1 | – / – |  | 2241.0 |  |  |
| 8 | CommentsController#destroy | 1 / 1 | – / – |  | 2025.0 |  |  |
| 9 | ArticlesController#destroy | 1 / 1 | – / – |  | 2001.0 |  |  |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/i18n/lib/i18n.rb:397` | `normalize_keys` | 64.83 / 64.83 | 0.0 | 66.67 | 42% | Array |  | `app/views/articles/_form.html.erb:21` 33%, `app/views/articles/_form.html.erb:8` 21% | `*normalize_key(locale, separator),` |
| 2 | `GEM/i18n/lib/i18n/backend/base.rb:155` | `resolve` | 39.17 / 39.17 | 0.0 | 40.0 | 42% | Hash |  | `app/views/articles/_form.html.erb:21` 35%, `app/views/articles/_form.html.erb:8` 20% | `I18n.translate(` |
| 3 | `GEM/i18n/lib/i18n/backend/base.rb:157` | `resolve` | 39.17 / 39.17 | 0.0 | 40.0 | 42% | Hash |  | `app/views/articles/_form.html.erb:21` 35%, `app/views/articles/_form.html.erb:8` 20% | `**options.merge(` |
| 4 | `GEM/i18n/lib/i18n.rb:396` | `normalize_keys` | 32.42 / 32.42 | 0.0 | 33.33 | 42% | Array |  | `app/views/articles/_form.html.erb:21` 33%, `app/views/articles/_form.html.erb:8` 21% | `[` |
| 5 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | `#{method}` | 30.25 / 30.25 | 0.0 | 32.25 | 100% | Array, Hash |  | `no app frame` 48%, `app/controllers/articles_controller.rb:52` 5% | `dispatch(:#{method}, ...)` |
| 6 | `GEM/i18n/lib/i18n/backend/simple.rb:100` | `lookup` | 29.17 / 29.17 | 0.0 | 30.0 | 42% | String |  | `app/views/articles/_form.html.erb:21` 33%, `app/views/articles/_form.html.erb:8` 20% | `_key = _key.to_s.to_sym` |
| 7 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:324` | `tag_option` | 29.0 / 29.0 | 0.0 | 32.67 | 75% | String |  | `app/views/layouts/application.html.erb:18` 26%, `app/views/articles/_article.html.erb:14` 13% | `%(#{key}="#{value}")` |
| 8 | `GEM/i18n/lib/i18n/utils.rb:8` | `except` | 25.42 / 25.42 | 0.0 | 26.5 | 42% | Hash |  | `app/views/articles/_form.html.erb:21` 30%, `app/views/articles/_form.html.erb:8` 21% | `hash.except(*keys)` |
| 9 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:146` | `humanize` | 23.5 / 23.5 | 0.0 | 25.0 | 42% | String, MatchData |  | `app/views/articles/_form.html.erb:8` 24%, `app/views/articles/_form.html.erb:21` 24% | `result.gsub!(/([[[:alpha:]]\d]+)/i) do \|match\|` |
| 10 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:228` | `html_safe` | 19.67 / 19.67 | 0.0 | 22.5 | 75% | String |  | `app/views/layouts/application.html.erb:18` 29%, `app/views/layouts/application.html.erb:17` 7% | `ActiveSupport::SafeBuffer.new(self)` |
| 11 | `GEM/i18n/lib/i18n/exceptions.rb:53` | `initialize` | 19.33 / 19.33 | 0.0 | 19.75 | 42% | Hash |  | `app/views/articles/_form.html.erb:21` 35%, `app/views/articles/_form.html.erb:8` 20% | `@key, @locale, @options = key, locale, options.slice(*PERMITTED_KEYS)` |
| 12 | `GEM/i18n/lib/i18n/backend/base.rb:45` | `translate` | 19.33 / 19.33 | 0.0 | 19.67 | 42% | Object |  | `app/views/articles/_form.html.erb:21` 36%, `app/views/articles/_form.html.erb:8` 20% | `throw(:exception, I18n::MissingTranslation.new(locale, key, options))` |
| 13 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:621` | `within_new_transaction` | 18.17 / 18.17 | 0.0 | 27.58 | 25% | String, Array |  | `app/controllers/articles_controller.rb:27` 34%, `app/controllers/comments_controller.rb:6` 34% | `raise` |
| 14 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:72` | `initialize` | 17.92 / 17.92 | 0.0 | 20.58 | 75% | String |  | `app/views/layouts/application.html.erb:18` 30%, `app/views/layouts/application.html.erb:17` 7% | `super` |
| 15 | `RUBY/uri/common.rb:394` | `_encode_uri_component` | 18.5 / 16.25 | -2.25 | 20.63 | 50% | String, MatchData |  | `no app frame` 100% | `str.gsub!(regexp, table)` |
| 16 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:206` | `groups_for` | 15.17 / 15.17 | 0.0 | 16.33 | 100% | Array |  | `no app frame` 41%, `app/controllers/articles_controller.rb:63` 5% | `groups[group_class] = (groups[group_class] \|\| []) + active_subscriptio` |
| 17 | `RUBY/set.rb:512` | `add` | 14.17 / 14.17 | 0.0 | 20.42 | 17% | String |  | `no app frame` 67%, `app/views/layouts/application.html.erb:18` 27% | `@hash[o] = true` |
| 18 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` | `xml_name_escape` | 14.17 / 14.17 | 0.0 | 15.58 | 75% | String |  | `app/views/layouts/application.html.erb:18` 55%, `app/views/articles/_article.html.erb:14` 19% | `name = name.to_s` |
| 19 | `GEM/i18n/lib/i18n/interpolate/ruby.rb:33` | `interpolate_hash` | 14.0 / 14.0 | 0.0 | 14.5 | 33% | String, MatchData |  | `app/views/articles/_form.html.erb:8` 45%, `app/views/articles/_form.html.erb:21` 28% | `interpolated_string = string.gsub(pattern) do \|match\|` |
| 20 | `GEM/i18n/lib/i18n/backend/base.rb:58` | `translate` | 13.08 / 13.08 | 0.0 | 13.67 | 42% | Array |  | `app/views/articles/_form.html.erb:21` 29%, `app/views/articles/_form.html.erb:8` 22% | `values = Utils.except(options, *RESERVED_KEYS) unless options.empty?` |
| 21 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:236` | `initialize` | 12.92 / 12.92 | 0.0 | 13.5 | 100% | Object |  | `no app frame` 25%, `app/controllers/articles_controller.rb:63` 9% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 22 | `GEM/i18n/lib/i18n/backend/base.rb:132` | `default` | 12.33 / 12.33 | 0.0 | 12.83 | 42% | Array |  | `app/views/articles/_form.html.erb:21` 31%, `app/views/articles/_form.html.erb:8` 19% | `options = Utils.except(options, :default)` |
| 23 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:263` | `tag_options` | 11.92 / 11.92 | 0.0 | 13.42 | 75% | String |  | `app/views/layouts/application.html.erb:18` 34%, `app/views/articles/_article.html.erb:14` 9% | `output = +""` |
| 24 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:152` | `humanize` | 11.75 / 11.75 | 0.0 | 12.5 | 42% | String, MatchData |  | `app/views/articles/_form.html.erb:8` 24%, `app/views/articles/_form.html.erb:21` 24% | `result.sub!(/\A[[:alpha:]]/) do \|match\|` |
| 25 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:208` | `dispatch` | 10.83 / 10.83 | 0.0 | 12.0 | 100% | Data |  | `no app frame` 56%, `app/controllers/articles_controller.rb:31` 6% | `block = proc { \|*args, **kwargs\|` |
| 26 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:212` | `dispatch` | 10.83 / 10.83 | 0.0 | 12.0 | 100% | Array, Hash |  | `no app frame` 56%, `app/controllers/articles_controller.rb:44` 6% | `result = yield(*args, **kwargs)` |
| 27 | `GEM/i18n/lib/i18n.rb:476` | `normalize_key` | 10.5 / 10.5 | 0.0 | 15.58 | 33% | String, Array |  | `app/views/articles/_form.html.erb:8` 45%, `app/views/articles/_form.html.erb:25` 17% | `keys = key.to_s.split(separator)` |
| 28 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:218` | `dispatch` | 10.25 / 10.25 | 0.0 | 11.0 | 100% | Array, Hash |  | `no app frame` 47%, `app/controllers/articles_controller.rb:52` 5% | `logger.send(method, *args, **kwargs, &block)` |
| 29 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:217` | `dispatch` | 10.08 / 10.08 | 0.0 | 10.75 | 100% | Array |  | `no app frame` 48%, `app/controllers/articles_controller.rb:52` 5% | `@broadcasts.map { \|logger\|` |
| 30 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` | `call` | 9.58 / 9.58 | 0.0 | 10.17 | 100% | Data |  | `no app frame` 75%, `app/controllers/articles_controller.rb:27` 8% | `result_lambda = -> { user_callback.call target, value }` |

## Dev/test-mode work

490.0 of 2198.0 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | template compile | `RAILS/actionview/lib/action_view/template.rb:503` | 38.25 | 33% | `no app frame` 67%, `app/views/articles/new.html.erb:6` 17% | `mod.module_eval(compiled_source, identifier, offset)` |
| 2 | template compile | `GEM/erubi/lib/erubi.rb:134` | 20.83 | 33% | `no app frame` 68%, `app/views/articles/new.html.erb:6` 16% | `input.scan(regexp) do \|indicator, code, tailch, rspace\|` |
| 3 | asset lookup | `GEM/sprockets/lib/sprockets/http_utils.rb:17` | 17.5 | 50% | `app/views/layouts/application.html.erb:18` 82%, `app/views/layouts/application.html.erb:16` 9% | `v1, v2 = value.split('/'.freeze, 2)` |
| 4 | asset lookup | `GEM/sprockets/lib/sprockets/http_utils.rb:18` | 17.5 | 50% | `app/views/layouts/application.html.erb:18` 82%, `app/views/layouts/application.html.erb:17` 9% | `m1, m2 = matcher.split('/'.freeze, 2)` |
| 5 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:183` | 15.0 | 83% | `app/controllers/articles_controller.rb:63` 16%, `app/controllers/articles_controller.rb:52` 16% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 6 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` | 11.08 | 83% | `app/controllers/articles_controller.rb:63` 24%, `app/controllers/comments_controller.rb:22` 15% | `binds = binds.inspect` |
| 7 | debug logging | `GEM/logger/lib/logger.rb:685` | 10.83 | 100% | `no app frame` 56%, `app/models/comment.rb:14` 6% | `message = yield` |
| 8 | debug logging | `RAILS/actionview/lib/action_view/log_subscriber.rb:64` | 10.17 | 75% | `no app frame` 50%, `app/controllers/articles_controller.rb:44` 13% | `string = string.sub(rails_root, "")` |
| 9 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:176` | 10.0 | 83% | `app/controllers/articles_controller.rb:63` 16%, `app/controllers/articles_controller.rb:52` 16% | `clear = "\e[#{MODES[:clear]}m"` |
| 10 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:181` | 10.0 | 83% | `app/controllers/articles_controller.rb:63` 16%, `app/controllers/articles_controller.rb:52` 16% | `modes = MODES.values_at(*options.compact_blank.keys)` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activesupport | 457.8 | 542.3 | `broadcast_logger.rb:129` 30.3, `methods.rb:146` 23.5, `output_safety.rb:228` 19.7 |
| gem: i18n | 327.6 | 345.7 | `i18n.rb:397` 64.8, `base.rb:155` 39.2, `base.rb:157` 39.2 |
| rails: actionview | 307.6 | 420.4 | `template.rb:503` 38.3, `tag_helper.rb:324` 29.0, `tag_helper.rb:263` 11.9 |
| rails: actionpack | 259.5 | 542.5 | `static.rb:145` 6.8, `visitors.rb:40` 6.7, `pattern.rb:77` 6.4 |
| rails: activerecord | 220.1 | 321.2 | `transaction.rb:621` 18.2, `log_subscriber.rb:49` 11.1, `delegation.rb:129` 6.8 |
| gem: sprockets | 161.1 | 1191.9 | `http_utils.rb:17` 17.5, `http_utils.rb:18` 17.5, `resolve.rb:218` 8.3 |
| ruby stdlib | 121.4 | 350.5 | `common.rb:394` 17.4, `set.rb:512` 14.2, `ipaddr.rb:659` 9.2 |
| rails: activemodel | 94.8 | 140.2 | `translation.rb:76` 7.3, `error.rb:86` 6.3, `naming.rb:204` 5.5 |
| gem: rack | 43.1 | 128.2 | `request.rb:696` 6.7, `body_proxy.rb:12` 3.7, `request.rb:607` 3.1 |
| ruby default gem: logger | 40.3 | 43.5 | `logger.rb:685` 10.8, `log_device.rb:165` 9.8, `log_device.rb:33` 9.8 |
| gem: erubi | 34.7 | 51.1 | `erubi.rb:134` 20.8, `erubi.rb:137` 4.3, `erubi.rb:139` 3.2 |
| gem: importmap-rails | 24.6 | 48.4 | `importmap_tags_helper.rb:44` 8.8, `importmap_tags_helper.rb:30` 5.8, `importmap_tags_helper.rb:42` 3.8 |
| gem: sqlite3 | 21.8 | 24.9 | `statement.rb:76` 7.5, `statement.rb:159` 5.8, `database.rb:215` 1.6 |
| app | 16.5 | 43.4 | `application.html.erb:17` 1.7, `application.html.erb:16` 1.7, `_article.html.erb:14` 1.3 |
| rails: activejob | 14.7 | 22.0 | `log_subscriber.rb:148` 3.2, `arguments.rb:92` 2.2, `arguments.rb:142` 1.7 |
| gem: turbo-rails | 14.6 | 24.2 | `stream_name.rb:26` 2.5, `broadcastable.rb:521` 2.0, `broadcasts.rb:41` 1.0 |
| gem: sprockets-rails | 10.4 | 22.0 | `helper.rb:186` 1.7, `helper.rb:357` 1.7, `helper.rb:81` 1.7 |
| rails: railties | 10.1 | 14.2 | `logger.rb:57` 2.8, `engine.rb:745` 0.9, `logger.rb:42` 0.9 |
| gem: bootsnap | 7.7 | 35.0 | `iseq.rb:103` 3.7, `cache.rb:218` 1.2, `iseq.rb:159` 0.9 |
| gem: globalid | 6.3 | 9.5 | `gid.rb:95` 1.7, `gid.rb:159` 1.3, `gid.rb:166` 0.7 |
| ruby default gem: base64 | 4.2 | 4.3 | `base64.rb:283` 4.2 |
| gem: concurrent-ruby | 3.7 | 87.8 | `non_concurrent_map_backend.rb:131` 1.7, `non_concurrent_map_backend.rb:120` 0.6, `mri_map_backend.rb:14` 0.6 |
| rails: actioncable | 3.3 | 6.3 | `broadcasting.rb:51` 1.0, `broadcasting.rb:39` 0.8, `subscriber_map.rb:9` 0.3 |
| gem: rack-session | 2.7 | 3.0 | `id.rb:275` 0.9, `id.rb:277` 0.9, `id.rb:368` 0.4 |
| gem: tzinfo | 2.3 | 3.8 | `timestamp.rb:208` 1.0, `timestamp.rb:193` 0.5, `constant_offset_data_timezone_info.rb:52` 0.5 |
| gem: json | 2.3 | 3.5 | `common.rb:378` 1.6, `common.rb:896` 0.3, `common.rb:902` 0.3 |
| ruby default gem: securerandom | 1.7 | 1.8 | `securerandom.rb:71` 1.7 |
| gem: useragent | 0.0 | 60.0 | `edge.rb:3` 0.0, `version.rb:2` 0.0, `base.rb:3` 0.0 |
| rails: actiontext | 0.0 | 6.7 | `serialization.rb:6` 0.0, `rendering.rb:14` 0.0, `content.rb:27` 0.0 |
| gem: lowrail-profile | 0.0 | 0.1 | `profile.rb:64` 0.0 |
