# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bundle exec rspec spec/requests spec/controllers --seed 1234 --format documentation`
* Ruby: ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +PRISM [x86_64-linux]
* Rails: 8.2.0.alpha, test environment
* Counted in run 1: 1900 requests, 6 jobs; 2 runs
* Not counted in run 1: 340 requests made by controller tests (`ActionController::TestCase`, rspec-rails controller specs), which call the controller directly, without the app's middleware and routing
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 1900 | 358.1 | 6 | 0 | 0 | 0 |
| run2 | 1 | 1900 | 358.1 | 6 | 0 | 0 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.01 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `lib/action_dispatch/remote_ip_extensions.rb:20` | `calculate_ip` | 11.99 | 0.0 | 0.0 | `GEM/ipaddr/lib/ipaddr.rb:769` 42%, `RAILS/actionpack/lib/action_dispatch/middleware/remote_ip.rb:183` 25%, `GEM/ipaddr/lib/ipaddr.rb:716` 17% | - 100% | `remote_addr = sanitize_ips(ips_from(@req.remote_addr)).last` |
| 2 | `lib/action_dispatch/remote_ip_extensions.rb:23` | `calculate_ip` | 1.0 | 0.0 | 0.0 | `RAILS/actionpack/lib/action_dispatch/middleware/remote_ip.rb:181` 100% | - 100% | `client_ips    = sanitize_ips(ips_from(@req.client_ip)).reverse!` |
| 3 | `lib/action_dispatch/remote_ip_extensions.rb:24` | `calculate_ip` | 0.0 | 0.0 | 1.0 |  |  | `forwarded_ips = sanitize_ips(@req.forwarded_for \|\| []).reverse!` |
| 4 | `lib/action_dispatch/remote_ip_extensions.rb:59` | `calculate_ip` | 0.0 | 0.0 | 1.0 |  |  | `ips = forwarded_ips + client_ips` |
| 5 | `lib/action_dispatch/remote_ip_extensions.rb:64` | `calculate_ip` | 0.0 | 0.0 | 6.0 |  |  | `filter_proxies([remote_addr] + ips).first \|\| ips.last \|\| remote_addr` |

70.14 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | (no action name) | 1900 / 1900 | 336.7 / 336.7 | 0.0 | 336.8 | `GEM/rack/lib/rack/utils.rb:693` 10.5, `RUBY/random/formatter.rb:174` 7.0, `GEM/ipaddr/lib/ipaddr.rb:769` 5.0 | `lib/action_dispatch/remote_ip_extensions.rb:20` 12.0, `lib/action_dispatch/remote_ip_extensions.rb:23` 1.0 |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `GEM/rack/lib/rack/utils.rb:693` | `clean_path_info` | 10.52 / 10.52 | -0.0 | 10.52 | 100% | String, Array |  | `no app frame` 100% | `parts = path_info.split PATH_SEPS` |
| 2 | `RUBY/random/formatter.rb:174` † | `uuid` | 7.0 / 7.0 | 0.0 | 7.0 | 100% | String, Array |  | `no app frame` 100% | `ary.unpack("H8H4H4H4H12").join(?-)` |
| 3 | `GEM/ipaddr/lib/ipaddr.rb:769` | `in_addr` | 5.0 / 5.0 | 0.0 | 5.0 | 100% | String, Array |  | `lib/action_dispatch/remote_ip_extensions.rb:20` 100% | `octets = addr.split('.')` |
| 4 | `GEM/uri/lib/uri/common.rb:465` | `_decode_uri_component` | 4.93 / 4.94 | 0.01 | 4.94 | 29% | String, MatchData |  | `no app frame` 100% | `str.b.gsub(regexp, TBLDECWWWCOMP_).force_encoding(enc)` |
| 5 | `RAILS/actionpack/lib/action_dispatch/middleware/remote_ip.rb:183` | `ips_from` | 3.0 / 3.0 | 0.0 | 3.0 | 100% | String, Array |  | `lib/action_dispatch/remote_ip_extensions.rb:20` 100% | `header.strip.split(/[,\s]+/)` |
| 6 | `GEM/rack/lib/rack/query_parser.rb:245` | `each_query_pair` | 2.03 / 2.03 | 0.0 | 2.03 | 14% | String, Array |  | `no app frame` 100% | `k, v = p.split('=', 2).map! { \|s\| unescape(s) }` |
| 7 | `GEM/ipaddr/lib/ipaddr.rb:716` | `initialize` | 2.0 / 2.0 | 0.0 | 2.0 | 100% | Array, String |  | `lib/action_dispatch/remote_ip_extensions.rb:20` 100% | `prefix, prefixlen = addr.split('/', 2)` |
| 8 | `GEM/rack/lib/rack/request.rb:607` | `path` | 2.0 / 2.0 | 0.0 | 2.0 | 100% | String |  | `no app frame` 100% | `script_name + path_info` |
| 9 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:299` | `method_missing` | 2.0 / 2.0 | 0.0 | 2.0 | 100% | Array |  | `no app frame` 100% | `loggers = @broadcasts.select { \|logger\| logger.respond_to?(name) }` |
| 10 | `RAILS/activesupport/lib/active_support/callbacks.rb:105` | `run_callbacks` | 2.0 / 2.0 | 0.0 | 2.0 | 100% | Struct |  | `no app frame` 100% | `env = Filters::Environment.new(self, false, nil)` |
| 11 | `RAILS/railties/lib/rails/application/bootstrap.rb:74` | `` | 2.0 / 2.0 | 0.0 | 2.0 | 100% | Hash |  | `no app frame` 100% | `context.reverse_merge(rails: {` |
| 12 | `GEM/rack-cors/lib/rack/cors/resource.rb:40` | `matches_path?` | 1.35 / 1.35 | 0.0 | 1.35 | 67% | String, MatchData |  | `no app frame` 100% | `pattern =~ path` |
| 13 | `GEM/rack/lib/rack/media_type.rb:18` | `type` | 1.27 / 1.27 | 0.0 | 1.27 | 31% | String, Array |  | `no app frame` 100% | `type = content_type.split(SPLIT_PATTERN, 2).first` |
| 14 | `GEM/uri/lib/uri/rfc2396_parser.rb:320` | `unescape` | 1.07 / 1.07 | 0.0 | 1.07 | 100% | String, MatchData |  | `no app frame` 100% | `str.gsub(escaped) { [$&[1, 2]].pack('H2').force_encoding(enc) }` |
| 15 | `GEM/rack-cors/lib/rack/cors/result.rb:38` | `miss` | 1.0 / 1.0 | 0.0 | 1.0 | 100% | Object, Data |  | `no app frame` 100% | `r = Result.new` |
| 16 | `RAILS/actionpack/lib/action_dispatch/middleware/executor.rb:45` | `call` | 1.0 / 1.0 | 0.0 | 1.0 | 100% | Object, Data |  | `no app frame` 100% | `wrapper = ExceptionWrapper.new(backtrace_cleaner, error)` |
| 17 | `RAILS/actionpack/lib/action_dispatch/middleware/remote_ip.rb:96` | `call` | 1.0 / 1.0 | 0.0 | 1.0 | 100% | Object, Data |  | `no app frame` 100% | `req.remote_ip = GetIp.new(req, check_ip, proxies)` |
| 18 | `RAILS/activesupport/lib/active_support/cache/strategy/local_cache.rb:80` | `new_local_cache` | 1.0 / 1.0 | 0.0 | 1.0 | 100% | Object, Data |  | `no app frame` 100% | `LocalCacheRegistry.set_cache_for(local_cache_key, LocalStore.new)` |
| 19 | `GEM/rack/lib/rack/utils.rb:695` | `clean_path_info` | 1.0 / 1.0 | 0.0 | 1.0 | 100% | Array |  | `no app frame` 100% | `clean = []` |
| 20 | `GEM/rack/lib/rack/utils.rb:702` | `clean_path_info` | 1.0 / 1.0 | 0.0 | 1.0 | 100% | String |  | `no app frame` 100% | `clean_path = clean.join(::File::SEPARATOR)` |
| 21 | `GEM/securerandom/lib/securerandom.rb:71` | `gen_random_urandom` | 1.0 / 1.0 | 0.0 | 1.0 | 100% | String |  | `no app frame` 100% | `ret = Random.urandom(n)` |
| 22 | `RAILS/actionpack/lib/action_dispatch/http/request.rb:289` | `engine_script_name=` | 1.0 / 1.0 | 0.0 | 1.0 | 100% | String |  | `no app frame` 100% | `set_header(routes.env_key, name.dup)` |
| 23 | `RAILS/actionpack/lib/action_dispatch/middleware/executor.rb:15` | `call` | 1.0 / 1.0 | 0.0 | 1.0 | 100% | Data |  | `no app frame` 100% | `finalize = -> {` |
| 24 | `RAILS/actionpack/lib/action_dispatch/middleware/executor.rb:43` | `call` | 1.0 / 1.0 | 0.0 | 1.0 | 100% | Object |  | `no app frame` 100% | `request = ActionDispatch::Request.new env` |
| 25 | `RAILS/actionpack/lib/action_dispatch/middleware/remote_ip.rb:95` | `call` | 1.0 / 1.0 | 0.0 | 1.0 | 100% | Object |  | `no app frame` 100% | `req = ActionDispatch::Request.new env` |
| 26 | `RAILS/actionpack/lib/action_dispatch/middleware/remote_ip.rb:181` | `ips_from` | 1.0 / 1.0 | 0.0 | 1.0 | 100% | Array |  | `lib/action_dispatch/remote_ip_extensions.rb:23` 100% | `return [] unless header` |
| 27 | `RAILS/actionpack/lib/action_dispatch/middleware/remote_ip.rb:218` | `sanitize_ips` | 1.0 / 1.0 | 0.0 | 1.0 | 100% | Object |  | `lib/action_dispatch/remote_ip_extensions.rb:20` 100% | `addr = IPAddr.new(ip)` |
| 28 | `RAILS/actionpack/lib/action_dispatch/middleware/remote_ip.rb:227` | `sanitize_ips` | 1.0 / 1.0 | 0.0 | 1.0 | 100% | Hash |  | `lib/action_dispatch/remote_ip_extensions.rb:20` 100% | `(@parsed_ips \|\|= {}.compare_by_identity)[ip] = addr` |
| 29 | `RAILS/actionpack/lib/action_dispatch/middleware/request_id.rb:30` | `call` | 1.0 / 1.0 | 0.0 | 1.0 | 100% | Object |  | `no app frame` 100% | `req = ActionDispatch::Request.new env` |
| 30 | `RAILS/activerecord/lib/active_record/connection_adapters/abstract/connection_pool.rb:168` | `initialize_copy` | 1.0 / 1.0 | 0.0 | 1.0 | 100% | Data |  | `no app frame` 100% | `@pools = @pools.dup` |

## Dev/test-mode work

245.4 of 328.4 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | debug logging | `RAILS/railties/lib/rails/rack/logger.rb:52` | 235.0 | 100% | `no app frame` 100% | `raise` |
| 2 | error page | `RAILS/actionpack/lib/action_dispatch/middleware/exception_wrapper.rb:317` | 2.0 | 100% | `no app frame` 100% | `return enum_for(__method__, exception) unless block_given?` |
| 3 | asset lookup | `GEM/propshaft/lib/propshaft/server.rb:16` | 1.41 | 100% | `no app frame` 100% | `if (method == "GET" \|\| method == "HEAD") && path.start_with?(@assembly` |
| 4 | asset lookup | `GEM/propshaft/lib/propshaft/server.rb:13` | 1.0 | 100% | `no app frame` 100% | `path = env["PATH_INFO"]` |
| 5 | asset lookup | `GEM/propshaft/lib/propshaft/server.rb:14` | 1.0 | 100% | `no app frame` 100% | `method = env["REQUEST_METHOD"]` |
| 6 | error page | `RAILS/actionpack/lib/action_dispatch/middleware/exception_wrapper.rb:323` | 1.0 | 100% | `no app frame` 100% | `causes_for(exception).map do \|cause\|` |
| 7 | debug logging | `RAILS/railties/lib/rails/rack/logger.rb:21` | 1.0 | 100% | `no app frame` 100% | `request = ActionDispatch::Request.new(env)` |
| 8 | debug logging | `RAILS/railties/lib/rails/rack/logger.rb:24` | 1.0 | 100% | `no app frame` 100% | `logger.push_tags(*compute_tags(request)).size` |
| 9 | debug logging | `RAILS/railties/lib/rails/rack/logger.rb:37` | 1.0 | 100% | `no app frame` 100% | `handle = instrumenter.build_handle("request.action_dispatch", { reques` |
| 10 | debug logging | `RAILS/railties/lib/rails/rack/logger.rb:65` | 1.0 | 100% | `no app frame` 100% | `@taggers.collect do \|tag\|` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: railties | 243.0 | 243.2 | `logger.rb:52` 235.0, `bootstrap.rb:74` 2.0, `logger.rb:65` 1.0 |
| gem: rack | 22.7 | 22.8 | `utils.rb:693` 10.5, `query_parser.rb:245` 2.0, `request.rb:607` 2.0 |
| rails: actionpack | 17.8 | 17.8 | `remote_ip.rb:183` 3.0, `exception_wrapper.rb:317` 2.0, `executor.rb:15` 1.0 |
| rails: activesupport | 15.0 | 15.1 | `callbacks.rb:105` 2.0, `broadcast_logger.rb:299` 2.0, `execution_wrapper.rb:83` 1.0 |
| app | 8.0 | 8.0 | `remote_ip_extensions.rb:64` 6.0, `remote_ip_extensions.rb:59` 1.0, `remote_ip_extensions.rb:24` 1.0 |
| ruby stdlib | 7.1 | 7.2 | `formatter.rb:174` 7.0, `tempfile.rb:227` 0.0, `tmpdir.rb:176` 0.0 |
| ruby default gem: ipaddr | 7.0 | 7.0 | `ipaddr.rb:769` 5.0, `ipaddr.rb:716` 2.0 |
| ruby default gem: uri | 6.0 | 6.0 | `common.rb:465` 4.9, `rfc2396_parser.rb:320` 1.1 |
| gem: propshaft | 3.4 | 3.4 | `server.rb:16` 1.4, `server.rb:13` 1.0, `server.rb:14` 1.0 |
| rails: activerecord | 3.0 | 3.0 | `connection_pool.rb:237` 1.0, `query_cache.rb:63` 1.0, `connection_pool.rb:168` 1.0 |
| gem: rack-cors | 2.4 | 2.4 | `resource.rb:40` 1.4, `result.rb:38` 1.0 |
| ruby default gem: securerandom | 1.0 | 1.0 | `securerandom.rb:71` 1.0 |
| lowrail-profile | 0.0 | 0.0 | `profile.rb:56` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Jobs

| # | Job | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | ActionMailer::MailDeliveryJob#perform | 6 / 6 | 30274.8 / 30302.4 | 27.6 | 38403.8 | `GEM/css_parser/lib/css_parser/rule_set.rb:116` 1387.4, `GEM/css_parser/lib/css_parser/parser.rb:407` 1119.0, `GEM/css_parser/lib/css_parser.rb:112` 1063.0 | `app/services/notify_service.rb:302` 12073.6, `app/controllers/auth/sessions_controller.rb:167` 3888.0, `app/controllers/auth/sessions_controller.rb:186` 3875.0 |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/css_parser/lib/css_parser/rule_set.rb:116` | 1156.17 / 1156.17 | 100% | `app/services/notify_service.rb:302` 53%, `no app frame` 23% | `value = Value.new(value)` |
| 2 | `GEM/css_parser/lib/css_parser/parser.rb:407` | 932.5 / 932.5 | 100% | `app/services/notify_service.rb:302` 67%, `app/controllers/auth/sessions_controller.rb:167` 17% | `token = scanner.scan(RULESET_TOKENIZER_RX)` |
| 3 | `GEM/css_parser/lib/css_parser.rb:112` | 885.83 / 885.83 | 100% | `app/services/notify_service.rb:302` 67%, `app/controllers/auth/sessions_controller.rb:167` 17% | `c = selector.scan(NON_ID_ATTRIBUTES_AND_PSEUDO_CLASSES_RX_NC).length` |
| 4 | `GEM/premailer/lib/premailer/adapter/nokogiri.rb:228` | 883.33 / 883.33 | 100% | `app/services/notify_service.rb:302` 67%, `app/controllers/auth/sessions_controller.rb:167` 17% | `selector.scan(CLASS_IN_SELECTOR).any? { \|(name)\| !classes_in_doc.inclu` |
| 5 | `GEM/css_parser/lib/css_parser/rule_set.rb:671` | 774.5 / 774.5 | 100% | `app/services/notify_service.rb:302` 55%, `no app frame` 18% | `block.split(SEMICOLON) do \|decs\|` |
| 6 | `GEM/css_parser/lib/css_parser/rule_set.rb:683` | 719.17 / 719.17 | 100% | `app/services/notify_service.rb:302` 49%, `no app frame` 25% | `value = decs[colon + 1, decs.length]` |
| 7 | `GEM/css_parser/lib/css_parser/rule_set.rb:682` | 678.67 / 678.67 | 100% | `app/services/notify_service.rb:302` 50%, `no app frame` 24% | `property = decs[0, colon]` |
| 8 | `GEM/premailer/lib/premailer/adapter/nokogiri.rb:49` | 546.67 / 546.67 | 100% | `app/services/notify_service.rb:302` 67%, `app/controllers/auth/sessions_controller.rb:186` 17% | `selector.gsub!(/([\s]\|^)([\w]+)/) { \|_m\| $1.to_s + $2.to_s.downcase }` |
| 9 | `GEM/mail/lib/mail/utilities.rb:215` | 518.5 / 518.5 | 100% | `app/services/notify_service.rb:302` 49%, `app/mailers/notification_mailer.rb:27` 18% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 10 | `GEM/css_parser/lib/css_parser/rule_set.rb:702` | 489.17 / 489.17 | 100% | `app/services/notify_service.rb:302` 67%, `app/controllers/auth/sessions_controller.rb:167` 17% | `@selectors = selectors.split(',').map! do \|s\|` |
