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
| run1 | 1 | 12 | 6602.8 | 0 | 0 | 0 | 0 |
| run2 | 1 | 12 | 6590.1 | 0 | 0 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 1.17 objects per request; 1 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/controllers/articles_controller.rb:40` | `update` | 36.25 | 10.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute_set/builder.rb:37` 3%, `GEM/uri/lib/uri/common.rb:90` 2%, `RAILS/activejob/lib/active_job/arguments.rb:141` 2% | ArticlesController#update 100% | `if @article.update(article_params)` |
| 2 | `app/controllers/articles_controller.rb:27` | `create` | 34.5 | 10.42 | 0.0 | `RAILS/activesupport/lib/active_support/core_ext/time/calculations.rb:149` 3%, `RAILS/activejob/lib/active_job/arguments.rb:141` 2%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 2% | ArticlesController#create 100% | `if @article.save` |
| 3 | `app/controllers/comments_controller.rb:6` | `create` | 24.25 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 85%, `RAILS/activemodel/lib/active_model/errors.rb:342` 2%, `RAILS/activesupport/lib/active_support/callbacks.rb:179` 1% | CommentsController#create 100% | `if @comment.save` |
| 4 | `app/controllers/articles_controller.rb:28` | `create` | 10.83 | 1.17 | 0.25 | `RAILS/activesupport/lib/active_support/key_generator.rb:63` 4%, `GEM/uri/lib/uri/common.rb:108` 3%, `GEM/uri/lib/uri/rfc3986_parser.rb:85` 3% | ArticlesController#create 100% | `format.html { redirect_to @article, notice: "Article was successfully ` |
| 5 | `app/controllers/articles_controller.rb:41` | `update` | 10.83 | 1.17 | 0.25 | `RAILS/activesupport/lib/active_support/key_generator.rb:63` 4%, `RAILS/activesupport/lib/active_support/messages/rotator.rb:55` 3%, `GEM/uri/lib/uri/common.rb:108` 3% | ArticlesController#update 100% | `format.html { redirect_to @article, notice: "Article was successfully ` |
| 6 | `app/controllers/comments_controller.rb:9` | `create` | 10.67 | 1.17 | 0.25 | `RAILS/activesupport/lib/active_support/key_generator.rb:63` 4%, `GEM/rack/lib/rack/request.rb:696` 3%, `GEM/uri/lib/uri/common.rb:108` 3% | CommentsController#create 100% | `redirect_to @article, alert: "Could not create comment."` |
| 7 | `app/controllers/comments_controller.rb:5` | `create` | 9.67 | 0.0 | 0.0 | `RAILS/activerecord/lib/active_record/relation/where_clause.rb:29` 7%, `RAILS/activerecord/lib/active_record/relation.rb:77` 4%, `RAILS/activerecord/lib/active_record/relation/delegation.rb:139` 4% | CommentsController#create 100% | `@comment = @article.comments.build(comment_params)` |
| 8 | `app/controllers/articles_controller.rb:68` | `article_params` | 8.5 | 0.0 | 0.5 | `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:75` 13%, `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:405` 12%, `RAILS/activesupport/lib/active_support/core_ext/array/wrap.rb:45` 10% | ArticlesController#create 52%, ArticlesController#update 48% | `params.expect(article: [ :title, :body ])` |
| 9 | `app/controllers/articles_controller.rb:63` | `set_article` | 5.92 | 3.0 | 0.17 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` 7%, `GEM/sqlite3/lib/sqlite3/statement.rb:76` 4%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 3% | ArticlesController#update 100%, ArticlesController#destroy 0%, ArticlesController#show 0% | `@article = Article.find(params.expect(:id))` |
| 10 | `app/controllers/comments_controller.rb:22` | `set_article` | 5.92 | 3.0 | 0.17 | `GEM/sqlite3/lib/sqlite3/statement.rb:159` 7%, `GEM/sqlite3/lib/sqlite3/statement.rb:76` 4%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 3% | CommentsController#create 100%, CommentsController#destroy 0% | `@article = Article.find(params.expect(:article_id))` |
| 11 | `app/controllers/comments_controller.rb:26` | `comment_params` | 4.08 | 0.0 | 0.25 | `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:405` 12%, `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:75` 12%, `RAILS/actionpack/lib/action_controller/metal/strong_parameters.rb:463` 10% | CommentsController#create 100% | `params.expect(comment: [ :commenter, :body ])` |
| 12 | `app/controllers/articles_controller.rb:24` | `create` | 1.33 | 0.0 | 0.0 | `RAILS/activemodel/lib/active_model/attribute.rb:101` 25%, `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:75` 13%, `RAILS/activemodel/lib/active_model/attribute.rb:13` 13% | ArticlesController#create 100% | `@article = Article.new(article_params)` |
| 13 | `app/controllers/articles_controller.rb:26` | `create` | 1.08 | 0.0 | 0.08 | `RAILS/actionpack/lib/action_dispatch/http/response.rb:510` 15%, `RAILS/actionpack/lib/action_dispatch/http/response.rb:496` 15%, `RAILS/actionpack/lib/action_dispatch/http/mime_type.rb:299` 15% | ArticlesController#create 100% | `respond_to do \|format\|` |
| 14 | `app/controllers/articles_controller.rb:39` | `update` | 1.08 | 0.0 | 0.08 | `RAILS/actionpack/lib/action_dispatch/http/response.rb:496` 15%, `RAILS/actionpack/lib/action_dispatch/http/response.rb:510` 15%, `RAILS/actionpack/lib/action_dispatch/http/mime_type.rb:299` 15% | ArticlesController#update 100% | `respond_to do \|format\|` |
| 15 | `app/controllers/articles_controller.rb:29` | `create` | 0.17 | 0.0 | 0.0 | `RAILS/actionpack/lib/action_dispatch/http/mime_type.rb:176` 50%, `RAILS/actionpack/lib/action_controller/metal/mime_responds.rb:274` 50% | ArticlesController#create 100% | `format.json { render :show, status: :created, location: @article }` |
| 16 | `app/controllers/articles_controller.rb:42` | `update` | 0.17 | 0.0 | 0.0 | `RAILS/actionpack/lib/action_controller/metal/mime_responds.rb:274` 50%, `RAILS/actionpack/lib/action_dispatch/http/mime_type.rb:176` 50% | ArticlesController#update 100% | `format.json { render :show, status: :ok, location: @article }` |
| 17 | `app/models/article.rb:6` |  | 0.0 | 0.0 | 0.17 |  |  | `broadcasts_to ->(_article) { "articles" }, inserts_by: :prepend` |

93.0 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | ArticlesController#update | 2 / 2 | 1343.0 / 1336.0 | -7.0 | 2574.5 | `GEM/uri/lib/uri/common.rb:465` 24.0, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 22.0, `GEM/uri/lib/uri/common.rb:456` 15.0 | `app/controllers/articles_controller.rb:40` 435.0, `app/controllers/articles_controller.rb:41` 130.0, `app/controllers/articles_controller.rb:63` 71.0 |
| 2 | ArticlesController#create | 2 / 2 | 1227.0 / 1225.0 | -2.0 | 2512.0 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 20.0, `GEM/uri/lib/uri/common.rb:456` 20.0, `GEM/uri/lib/uri/common.rb:465` 18.0 | `app/controllers/articles_controller.rb:27` 414.0, `app/controllers/articles_controller.rb:28` 130.0, `app/controllers/articles_controller.rb:68` 53.0 |
| 3 | CommentsController#create | 2 / 2 | 1156.0 / 1155.0 | -1.0 | 10407.5 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` 248.0, `GEM/uri/lib/uri/common.rb:456` 16.0, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 12.0 | `app/controllers/comments_controller.rb:6` 291.0, `app/controllers/comments_controller.rb:9` 128.0, `app/controllers/comments_controller.rb:5` 116.0 |
| 4 | ArticlesController#new | 1 / 1 | – / – |  | 15713.0 |  |  |
| 5 | ArticlesController#index | 1 / 1 | – / – |  | 2811.0 |  |  |
| 6 | ArticlesController#show | 1 / 1 | – / – |  | 2748.0 |  |  |
| 7 | CommentsController#destroy | 1 / 1 | – / – |  | 1714.0 |  |  |
| 8 | ArticlesController#edit | 1 / 1 | – / – |  | 1709.0 |  |  |
| 9 | ArticlesController#destroy | 1 / 1 | – / – |  | 1644.0 |  |  |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/transaction.rb:653` | `within_new_transaction` | 41.17 / 41.17 | 0.0 | 61.83 | 25% | String, Array |  | `app/controllers/articles_controller.rb:27` 34%, `app/controllers/comments_controller.rb:6` 33% | `raise` |
| 2 | `GEM/i18n/lib/i18n/backend/base.rb:157` | `resolve` | 39.17 / 39.17 | 0.0 | 40.0 | 42% | Hash |  | `app/views/articles/_form.html.erb:21` 35%, `app/views/articles/_form.html.erb:8` 20% | `**options.merge(` |
| 3 | `GEM/i18n/lib/i18n.rb:396` | `normalize_keys` | 32.42 / 32.42 | 0.0 | 33.33 | 42% | Array |  | `app/views/articles/_form.html.erb:21` 33%, `app/views/articles/_form.html.erb:8` 21% | `[` |
| 4 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:309` | `tag_option` | 30.5 / 30.5 | 0.0 | 31.92 | 75% | String |  | `app/views/layouts/application.html.erb:23` 27%, `app/views/articles/_article.html.erb:14` 12% | `%(#{key}="#{value}")` |
| 5 | `GEM/i18n/lib/i18n/backend/simple.rb:100` | `lookup` | 29.17 / 29.17 | 0.0 | 30.0 | 42% | String |  | `app/views/articles/_form.html.erb:21` 33%, `app/views/articles/_form.html.erb:8` 20% | `_key = _key.to_s.to_sym` |
| 6 | `GEM/i18n/lib/i18n/utils.rb:8` | `except` | 25.42 / 25.42 | 0.0 | 26.5 | 42% | Hash |  | `app/views/articles/_form.html.erb:21` 30%, `app/views/articles/_form.html.erb:8` 21% | `hash.except(*keys)` |
| 7 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:146` | `humanize` | 25.0 / 25.0 | 0.0 | 27.67 | 50% | String, MatchData |  | `app/views/articles/_form.html.erb:8` 22%, `app/views/articles/_form.html.erb:21` 22% | `result.gsub!(/([[[:alpha:]]\d]+)/i) do \|match\|` |
| 8 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:242` | `html_safe` | 21.5 / 21.5 | 0.0 | 22.42 | 75% | String |  | `app/views/layouts/application.html.erb:23` 29%, `app/views/layouts/application.html.erb:22` 11% | `ActiveSupport::SafeBuffer.new(self)` |
| 9 | `RAILS/activesupport/lib/active_support/core_ext/string/output_safety.rb:71` | `initialize` | 20.17 / 20.17 | 0.0 | 20.92 | 75% | String |  | `app/views/layouts/application.html.erb:23` 31%, `app/views/layouts/application.html.erb:22` 12% | `super` |
| 10 | `GEM/i18n/lib/i18n/backend/base.rb:155` | `resolve` | 19.58 / 19.58 | 0.0 | 20.0 | 42% | Hash |  | `app/views/articles/_form.html.erb:21` 35%, `app/views/articles/_form.html.erb:8` 20% | `I18n.translate(` |
| 11 | `GEM/i18n/lib/i18n/backend/base.rb:45` | `translate` | 19.33 / 19.33 | 0.0 | 19.75 | 42% | Object, Data |  | `app/views/articles/_form.html.erb:21` 35%, `app/views/articles/_form.html.erb:8` 20% | `throw(:exception, I18n::MissingTranslation.new(locale, key, options))` |
| 12 | `GEM/i18n/lib/i18n/exceptions.rb:53` | `initialize` | 19.33 / 19.33 | 0.0 | 19.67 | 42% | Hash |  | `app/views/articles/_form.html.erb:21` 36%, `app/views/articles/_form.html.erb:8` 20% | `@key, @locale, @options = key, locale, options.slice(*PERMITTED_KEYS)` |
| 13 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | `#{method}` | 19.17 / 19.17 | 0.0 | 21.5 | 100% | Hash, Array |  | `no app frame` 48%, `app/controllers/articles_controller.rb:52` 5% | `dispatch(:#{method}, ...)` |
| 14 | `RAILS/activesupport/lib/active_support/core_ext/erb/util.rb:143` | `xml_name_escape` | 14.17 / 14.17 | 0.0 | 14.83 | 75% | String |  | `app/views/layouts/application.html.erb:23` 57%, `app/views/articles/_article.html.erb:14` 17% | `name = name.to_s` |
| 15 | `GEM/i18n/lib/i18n/interpolate/ruby.rb:33` | `interpolate_hash` | 13.5 / 13.5 | 0.0 | 14.0 | 33% | String, MatchData |  | `app/views/articles/_form.html.erb:8` 43%, `app/views/articles/_form.html.erb:21` 29% | `interpolated_string = string.gsub(pattern) do \|match\|` |
| 16 | `GEM/i18n/lib/i18n/backend/base.rb:58` | `translate` | 13.08 / 13.08 | 0.0 | 13.67 | 42% | Array |  | `app/views/articles/_form.html.erb:21` 29%, `app/views/articles/_form.html.erb:8` 22% | `values = Utils.except(options, *RESERVED_KEYS) unless options.empty?` |
| 17 | `RAILS/actionview/lib/action_view/helpers/tag_helper.rb:237` | `tag_options` | 12.83 / 12.83 | 0.0 | 13.42 | 75% | String |  | `app/views/layouts/application.html.erb:23` 34%, `app/views/articles/_article.html.erb:14` 9% | `output = +""` |
| 18 | `GEM/i18n/lib/i18n/backend/base.rb:132` | `default` | 12.33 / 12.33 | 0.0 | 12.83 | 42% | Array |  | `app/views/articles/_form.html.erb:21` 31%, `app/views/articles/_form.html.erb:8` 19% | `options = Utils.except(options, :default)` |
| 19 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:208` | `dispatch` | 11.0 / 11.0 | 0.0 | 12.0 | 100% | Data |  | `no app frame` 56%, `app/controllers/articles_controller.rb:44` 6% | `block = proc { \|*args, **kwargs\|` |
| 20 | `GEM/i18n/lib/i18n.rb:476` | `normalize_key` | 10.5 / 10.5 | 0.0 | 15.58 | 33% | String, Array |  | `app/views/articles/_form.html.erb:8` 45%, `app/views/articles/_form.html.erb:25` 17% | `keys = key.to_s.split(separator)` |
| 21 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` | `build_handle` | 9.58 / 9.58 | 0.0 | 10.92 | 100% | Object, Data | #59613 merged 2026-11-04, after this app's version, not released yet, #59235 merged 2026-10-21, after this app's version, not released yet | `no app frame` 31%, `app/controllers/articles_controller.rb:52` 8% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 22 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:217` | `dispatch` | 9.58 / 9.58 | 0.0 | 10.75 | 100% | Array |  | `no app frame` 48%, `app/controllers/articles_controller.rb:52` 5% | `@broadcasts.map { \|logger\|` |
| 23 | `RUBY/ipaddr.rb:725` | `in_addr` | 9.17 / 9.17 | 0.0 | 10.0 | 100% | String, Array |  | `no app frame` 100% | `octets = addr.split('.')` |
| 24 | `RAILS/activesupport/lib/active_support/core_ext/hash/keys.rb:11` | `stringify_keys` | 8.75 / 8.75 | 0.0 | 9.42 | 100% | Hash |  | `app/views/layouts/application.html.erb:22` 16%, `app/views/articles/_article.html.erb:14` 9% | `transform_keys { \|k\| Symbol === k ? k.name : k.to_s }` |
| 25 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:287` | `build_handle` | 8.58 / 8.58 | 0.0 | 9.67 | 100% | Array | #59235 merged 2026-10-21, after this app's version, not released yet | `no app frame` 38%, `app/controllers/articles_controller.rb:63` 9% | `groups = groups_for(name).map do \|group_klass, grouped_listeners\|` |
| 26 | `RAILS/actionpack/lib/action_dispatch/http/request.rb:66` | `initialize` | 8.42 / 8.42 | 0.0 | 9.25 | 100% | Object |  | `no app frame` 97%, `app/models/comment.rb:14` 2% | `@rack_request = Rack::Request.new(env)` |
| 27 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:152` | `humanize` | 8.33 / 8.33 | 0.0 | 9.0 | 50% | String |  | `app/views/articles/_form.html.erb:8` 22%, `app/views/articles/_form.html.erb:21` 22% | `result.sub!(/\A[[:alpha:]]/) do \|match\|` |
| 28 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` | `call` | 8.17 / 8.17 | 0.0 | 9.17 | 100% | Data |  | `no app frame` 73%, `app/controllers/articles_controller.rb:27` 9% | `result_lambda = -> { user_callback.call target, value }` |
| 29 | `GEM/uri/lib/uri/common.rb:456` | `_encode_uri_component` | 8.42 / 7.25 | -1.17 | 9.42 | 50% | String, MatchData |  | `no app frame` 100% | `str.gsub!(regexp, table)` |
| 30 | `RUBY/random/formatter.rb:174` † | `uuid` | 7.58 / 7.58 | 0.0 | 8.75 | 100% | String, Array |  | `no app frame` 80%, `app/controllers/articles_controller.rb:27` 7% | `ary.unpack("H8H4H4H4H12").join(?-)` |

## Dev/test-mode work

351.0 of 1835.3 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | template compile | `GEM/erubi/lib/erubi.rb:134` | 31.5 | 42% | `no app frame` 62%, `app/views/articles/new.html.erb:6` 14% | `input.scan(regexp) do \|indicator, code, tailch, rspace\|` |
| 2 | debug logging | `RAILS/actionpack/lib/abstract_controller/logger.rb:12` | 18.17 | 100% | `no app frame` 82%, `app/controllers/comments_controller.rb:9` 3% | `singleton_class.delegate :logger, :logger=, to: :config` |
| 3 | asset lookup | `GEM/propshaft/lib/propshaft/helper.rb:113` † | 16.67 | 50% | `app/views/layouts/application.html.erb:22` 100% | `Rails.application.assets.load_path.asset_paths_by_glob("#{Rails.root.j` |
| 4 | template compile | `RAILS/actionview/lib/action_view/template.rb:509` | 14.33 | 42% | `no app frame` 55%, `app/views/articles/new.html.erb:6` 18% | `mod.module_eval(compiled_source, identifier, offset)` |
| 5 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:177` | 13.5 | 83% | `app/controllers/articles_controller.rb:52` 16%, `app/controllers/articles_controller.rb:63` 16% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 6 | debug logging | `RAILS/actionview/lib/action_view/log_subscriber.rb:61` | 11.67 | 75% | `no app frame` 50%, `app/controllers/articles_controller.rb:31` 13% | `string = string.sub(rails_root, "")` |
| 7 | debug logging | `GEM/logger/lib/logger.rb:685` | 11.0 | 100% | `no app frame` 56%, `app/controllers/articles_controller.rb:44` 6% | `message = yield` |
| 8 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` | 9.75 | 83% | `app/controllers/articles_controller.rb:63` 24%, `app/controllers/comments_controller.rb:22` 15% | `binds = binds.inspect` |
| 9 | debug logging | `GEM/logger/lib/logger.rb:692` † | 9.42 | 100% | `no app frame` 49%, `app/controllers/articles_controller.rb:52` 6% | `format_message(format_severity(severity), Time.now, progname, message)` |
| 10 | debug logging | `GEM/logger/lib/logger/log_device.rb:33` | 9.42 | 100% | `no app frame` 49%, `app/controllers/articles_controller.rb:52` 6% | `handle_write_errors("writing") {@dev.write(message)}` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activesupport | 373.2 | 788.8 | `methods.rb:146` 25.0, `output_safety.rb:242` 21.5, `output_safety.rb:71` 20.2 |
| rails: actionview | 301.0 | 451.6 | `tag_helper.rb:309` 30.5, `template.rb:509` 14.3, `tag_helper.rb:237` 12.8 |
| rails: actionpack | 256.5 | 702.5 | `logger.rb:12` 18.2, `request.rb:66` 8.4, `static.rb:145` 6.8 |
| gem: i18n | 242.8 | 277.1 | `base.rb:157` 39.2, `i18n.rb:396` 32.4, `simple.rb:100` 29.2 |
| rails: activerecord | 215.2 | 358.8 | `transaction.rb:653` 41.2, `log_subscriber.rb:49` 9.8, `integration.rb:59` 6.5 |
| rails: activemodel | 83.7 | 123.6 | `errors.rb:443` 4.7, `translation.rb:70` 4.0, `translation.rb:76` 3.8 |
| gem: erubi | 50.3 | 58.1 | `erubi.rb:134` 31.5, `erubi.rb:137` 6.5, `erubi.rb:139` 4.8 |
| ruby stdlib | 45.9 | 204.8 | `ipaddr.rb:725` 9.2, `formatter.rb:174` 7.6, `bundled_gems.rb:111` 5.4 |
| gem: rack | 41.4 | 126.8 | `request.rb:696` 6.0, `body_proxy.rb:12` 3.7, `request.rb:607` 3.0 |
| gem: logger | 39.3 | 43.5 | `logger.rb:685` 11.0, `logger.rb:692` 9.4, `log_device.rb:33` 9.4 |
| gem: propshaft | 34.7 | 959.8 | `helper.rb:113` 16.7, `asset.rb:73` 6.7, `dynamic.rb:11` 3.3 |
| ruby default gem: uri | 31.4 | 40.7 | `common.rb:456` 7.8, `common.rb:465` 5.5, `rfc3986_parser.rb:85` 1.7 |
| gem: importmap-rails | 21.7 | 181.5 | `importmap_tags_helper.rb:30` 5.8, `importmap_tags_helper.rb:44` 5.8, `importmap_tags_helper.rb:42` 3.8 |
| gem: concurrent-ruby | 19.9 | 23.8 | `safe_initialization.rb:30` 5.5, `mutex_lockable_object.rb:32` 1.8, `mutex_lockable_object.rb:33` 1.8 |
| app | 16.4 | 37.5 | `_article.html.erb:14` 1.7, `_article.html.erb:13` 1.3, `application.html.erb:22` 1.3 |
| gem: sqlite3 | 15.7 | 18.5 | `statement.rb:159` 6.1, `statement.rb:76` 4.5, `statement.rb:36` 1.6 |
| gem: turbo-rails | 13.7 | 38.4 | `stream_name.rb:26` 2.3, `broadcastable.rb:521` 1.8, `request_id_tracking.rb:10` 0.9 |
| gem: bootsnap | 11.1 | 149.3 | `iseq.rb:103` 4.3, `cache.rb:218` 2.0, `iseq.rb:159` 1.1 |
| rails: activejob | 9.2 | 42.8 | `log_subscriber.rb:207` 2.0, `arguments.rb:141` 1.7, `enqueuing.rb:62` 0.5 |
| rails: railties | 8.3 | 12.7 | `logger.rb:57` 1.8, `engine.rb:748` 0.9, `logger.rb:61` 0.9 |
| gem: globalid | 6.3 | 9.6 | `gid.rb:95` 1.7, `gid.rb:159` 1.3, `gid.rb:166` 0.7 |
| rails: actioncable | 3.3 | 13.1 | `broadcasting.rb:53` 0.8, `broadcasting.rb:49` 0.4, `broadcasting.rb:55` 0.4 |
| gem: tzinfo | 2.9 | 4.7 | `timestamp.rb:208` 1.3, `constant_offset_data_timezone_info.rb:52` 0.7, `timestamp.rb:193` 0.7 |
| gem: rack-session | 2.7 | 3.1 | `id.rb:275` 0.9, `id.rb:277` 0.9, `id.rb:401` 0.4 |
| gem: base64 | 1.8 | 2.2 | `base64.rb:283` 1.8 |
| ruby default gem: securerandom | 1.5 | 1.8 | `securerandom.rb:71` 1.5 |
| gem: json | 1.4 | 1.9 | `common.rb:861` 1.3, `common.rb:775` 0.1, `common.rb:769` 0.1 |
| gem: solid_queue | 0.5 | 0.8 | `batch_id.rb:20` 0.3, `batch_id.rb:24` 0.2 |
| gem: zeitwerk | 0.0 | 26.9 | `file_system.rb:158` 0.0, `constant_path_validator.rb:14` 0.0, `file_system.rb:199` 0.0 |
| gem: nio4r | 0.0 | 5.0 | `nio4r_ext.so:0` 0.0, `nio.rb:21` 0.0, `nio.rb:0` 0.0 |
| gem: lowrail-profile | 0.0 | 0.2 | `profile.rb:55` 0.0, `profile.rb:65` 0.0 |
| rails: activestorage | 0.0 | 0.2 | `engine.rb:215` 0.0 |
| gem: jbuilder | 0.0 | 3.0 | `jbuilder_dependency_tracker.rb:0` 0.0, `jbuilder_dependency_tracker.rb:3` 0.0, `railtie.rb:10` 0.0 |
| rails: actiontext | 0.0 | 7.3 | `content.rb:27` 0.0, `content.rb:0` 0.0, `rendering.rb:12` 0.0 |
| gem: useragent | 0.0 | 61.7 | `itunes.rb:0` 0.0, `opera.rb:0` 0.0, `playstation.rb:8` 0.0 |
