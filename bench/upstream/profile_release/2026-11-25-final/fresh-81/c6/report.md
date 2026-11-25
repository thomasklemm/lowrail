# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails test -v`
* Ruby: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux]
* Rails: 8.1.4.1, test environment
* Counted in run 1: 7 requests, 5 jobs, 6 mail windows, 4 Cable actions in 2 processes; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 2 | 7 | 9393.7 | 5 | 6 | 4 | 0 |
| run2 | 2 | 7 | 9315.0 | 5 | 6 | 4 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 1.57 objects per request; 1 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `engines/outsider/app/controllers/outsider/probe_controller.rb:9` | `show` | 14.43 | 5.43 | 0.71 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:199` 4%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:191` 4%, `GEM/sqlite3/lib/sqlite3/statement.rb:76` 3% | Outsider::ProbeController#show 100% | `render json: { id: params[:id], name: Widget.find_by(id: params[:id])&` |

54.71 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | Outsider::ProbeController#show | 2 / 2 | – / 604.0 |  | 642.0 | `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0, `RAILS/activesupport/lib/active_support/inflector/methods.rb:78` 24.0, `RAILS/activesupport/lib/active_support/inflector/methods.rb:80` 20.0 | `engines/outsider/app/controllers/outsider/probe_controller.rb:9` 101.0 |
| 2 | Outsider::ProbeController#index | 2 / 2 | – / – |  | 15098.5 |  |  |
| 3 | WidgetsController#create | 1 / 1 | – / – |  | 2043.0 |  |  |
| 4 | WidgetsController#index | 1 / 1 | – / – |  | 2064.0 |  |  |
| 5 | WidgetsController#show | 1 / 1 | – / – |  | 2053.0 |  |  |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `RUBY/bundled_gems.rb:111` | `warning?` | 35.71 / 35.0 | -0.71 | 171.07 | 71% | String, Array |  | `no app frame` 82%, `engines/outsider/app/controllers/outsider/probe_controller.rb:5` 12% | `segments = feature.split("/", 3)` |
| 2 | `GEM/bootsnap/lib/bootsnap/compile_cache/iseq.rb:103` | `storage_to_output` | 30.29 / 29.71 | -0.57 | 139.14 | 71% | Data, String |  | `no app frame` 84%, `engines/outsider/app/controllers/outsider/probe_controller.rb:5` 12% | `iseq = RubyVM::InstructionSequence.load_from_binary(binary)` |
| 3 | `RUBY/bundled_gems.rb:60` | `replace_require` | 28.57 / 28.0 | -0.57 | 134.86 | 71% | Data, String |  | `no app frame` 83%, `engines/outsider/app/controllers/outsider/probe_controller.rb:5` 12% | `kernel_class.send(:no_warning_require, name)` |
| 4 | `RUBY/bundled_gems.rb:98` | `warning?` | 21.43 / 21.0 | -0.43 | 102.64 | 71% | String, MatchData |  | `no app frame` 82%, `engines/outsider/app/controllers/outsider/probe_controller.rb:5` 12% | `feature = File.path(name).sub(LIBEXT, "")` |
| 5 | `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` | `file_readable?` | 15.43 / 15.43 | 0.0 | 23.14 | 86% | String, Array |  | `no app frame` 100% | `file_path = File.join(@root, path.b)` |
| 6 | `GEM/bootsnap/lib/bootsnap/load_path_cache/cache.rb:218` | `try_index` | 12.57 / 12.29 | -0.29 | 57.0 | 71% | String, Array |  | `no app frame` 84%, `engines/outsider/app/controllers/outsider/probe_controller.rb:5` 14% | `-File.join(path, feature).freeze` |
| 7 | `RAILS/activesupport/lib/active_support/class_attribute.rb:28` | `redefine_method` | 11.43 / 11.43 | 0.0 | 65.43 | 57% | Data, String |  | `no app frame` 63%, `app/controllers/widgets_controller.rb:1` 7% | `owner.define_method(name, &block)` |
| 8 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | `#{method}` | 9.71 / 9.71 | 0.0 | 18.0 | 100% | Array, Hash |  | `no app frame` 41%, `engines/outsider/app/controllers/outsider/probe_controller.rb:4` 16% | `dispatch(:#{method}, ...)` |
| 9 | `GEM/bootsnap/lib/bootsnap/compile_cache/iseq.rb:159` | `fetch` | 7.57 / 7.43 | -0.14 | 34.64 | 71% | String |  | `no app frame` 83%, `engines/outsider/app/controllers/outsider/probe_controller.rb:5` 12% | `Bootsnap::CompileCache::Native.fetch(` |
| 10 | `RUBY/ipaddr.rb:725` | `in_addr` | 7.14 / 7.14 | 0.0 | 10.0 | 100% | String, Array |  | `no app frame` 100% | `octets = addr.split('.')` |
| 11 | `RUBY/bundled_gems.rb:115` | `warning?` | 7.14 / 7.0 | -0.14 | 34.21 | 71% | String |  | `no app frame` 82%, `engines/outsider/app/controllers/outsider/probe_controller.rb:5` 12% | `name = "#{name}-#{segments.shift}"` |
| 12 | `RUBY/random/formatter.rb:174` † | `uuid` | 7.0 / 7.0 | 0.0 | 13.0 | 100% | String, Array |  | `no app frame` 54%, `engines/outsider/app/controllers/outsider/probe_controller.rb:4` 31% | `ary.unpack("H8H4H4H4H12").join(?-)` |
| 13 | `RAILS/actionpack/lib/action_dispatch/http/request.rb:66` | `initialize` | 7.0 / 7.0 | 0.0 | 10.14 | 100% | Object |  | `no app frame` 100% | `@rack_request = Rack::Request.new(env)` |
| 14 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:78` | `camelize` | 6.86 / 6.86 | 0.0 | 13.71 | 57% | String, Data |  | `no app frame` 100% | `string = string.sub(/^[a-z\d]*/) { \|match\| inflections.acronyms[match]` |
| 15 | `GEM/bootsnap/lib/bootsnap/load_path_cache/cache.rb:205` | `search_index` | 6.57 / 6.43 | -0.14 | 28.79 | 71% | String |  | `no app frame` 84%, `engines/outsider/app/controllers/outsider/probe_controller.rb:5` 14% | `try_index(feature + DOT_RB) \|\| try_index(feature + DLEXT) \|\| try_index` |
| 16 | `RAILS/actionpack/lib/action_dispatch/journey/path/pattern.rb:77` | `accept` | 7.14 / 5.57 | -1.57 | 9.21 | 86% | String, Regexp |  | `no app frame` 100% | `%r{\A#{visit node}\Z}` |
| 17 | `GEM/bootsnap/lib/bootsnap/load_path_cache/loaded_features_index.rb:115` | `register` | 6.29 / 6.14 | -0.14 | 28.5 | 71% | String |  | `no app frame` 84%, `engines/outsider/app/controllers/outsider/probe_controller.rb:5` 14% | `elsif long && (ext = File.extname(long.freeze))` |
| 18 | `GEM/bootsnap/lib/bootsnap/load_path_cache/loaded_features_index.rb:118` | `register` | 6.29 / 6.14 | -0.14 | 28.5 | 71% | String |  | `no app frame` 84%, `engines/outsider/app/controllers/outsider/probe_controller.rb:5` 14% | `short + ext` |
| 19 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:80` | `camelize` | 5.71 / 5.71 | 0.0 | 11.43 | 57% | String, MatchData |  | `no app frame` 100% | `string.gsub!(/(?:_\|(\/))([a-z\d]*)/i) do` |
| 20 | `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:146` | `file_readable?` | 5.14 / 5.14 | 0.0 | 7.71 | 86% | String |  | `no app frame` 100% | `File.file?(file_path) && File.readable?(file_path)` |
| 21 | `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:156` | `each_precompressed_filepath` | 5.14 / 5.14 | 0.0 | 7.71 | 86% | String |  | `no app frame` 100% | `yield content_encoding, "#{filepath}#{precompressed_ext}"` |
| 22 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:217` | `dispatch` | 4.86 / 4.86 | 0.0 | 9.0 | 100% | Array |  | `no app frame` 41%, `engines/outsider/app/controllers/outsider/probe_controller.rb:4` 16% | `@broadcasts.map { \|logger\|` |
| 23 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` | `build_handle` | 4.71 / 4.71 | 0.0 | 11.57 | 100% | Object, Data | #59613 merged 2026-11-04, after this app's version, not released yet, #59235 merged 2026-10-21, after this app's version, not released yet | `app/jobs/tally_job.rb:3` 42%, `no app frame` 17% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 24 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:287` | `build_handle` | 4.71 / 4.71 | 0.0 | 9.29 | 100% | Array | #59235 merged 2026-10-21, after this app's version, not released yet | `no app frame` 32%, `app/jobs/tally_job.rb:3` 31% | `groups = groups_for(name).map do \|group_klass, grouped_listeners\|` |
| 25 | `GEM/rack/lib/rack/utils.rb:693` | `clean_path_info` | 4.29 / 4.29 | 0.0 | 6.29 | 86% | String, Array |  | `no app frame` 100% | `parts = path_info.split PATH_SEPS` |
| 26 | `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/synchronization/safe_initialization.rb:30` | `new` | 4.29 / 4.29 | 0.0 | 6.0 | 100% | Object |  | `no app frame` 100% | `super(*args, &block)` |
| 27 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` | `call` | 4.0 / 4.0 | 0.0 | 5.71 | 100% | Data |  | `no app frame` 88%, `app/jobs/tally_job.rb:3` 8% | `result_lambda = -> { user_callback.call target, value }` |
| 28 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:208` | `dispatch` | 3.71 / 3.71 | 0.0 | 7.71 | 100% | Data |  | `no app frame` 52%, `engines/outsider/app/controllers/outsider/probe_controller.rb:4` 22% | `block = proc { \|*args, **kwargs\|` |
| 29 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:204` | `groups_for` | 3.29 / 3.29 | 0.0 | 7.57 | 100% | Array |  | `app/jobs/tally_job.rb:3` 32%, `no app frame` 26% | `active_subscriptions = subscriptions.reject { \|s\| s.silenced?(name) }` |
| 30 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:186` | `build_event` | 3.29 / 3.29 | 0.0 | 7.29 | 100% | Object |  | `app/jobs/tally_job.rb:3` 33%, `no app frame` 27% | `ActiveSupport::Notifications::Event.new name, nil, nil, id, payload` |

## Dev/test-mode work

99.2 of 679.6 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | debug logging | `RAILS/actionpack/lib/abstract_controller/logger.rb:12` | 11.86 | 100% | `no app frame` 100% | `singleton_class.delegate :logger, :logger=, to: :config` |
| 2 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:177` | 8.57 | 100% | `app/jobs/tally_job.rb:3` 50%, `app/controllers/widgets_controller.rb:13` 17% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 3 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:175` | 5.71 | 100% | `app/jobs/tally_job.rb:3` 50%, `app/controllers/widgets_controller.rb:13` 17% | `modes = MODES.values_at(*options.compact_blank.keys)` |
| 4 | debug logging | `GEM/logger/lib/logger.rb:692` † | 4.57 | 100% | `no app frame` 46%, `app/jobs/tally_job.rb:3` 16% | `format_message(format_severity(severity), Time.now, progname, message)` |
| 5 | debug logging | `GEM/logger/lib/logger/log_device.rb:33` | 4.57 | 100% | `no app frame` 46%, `app/jobs/tally_job.rb:3` 16% | `handle_write_errors("writing") {@dev.write(message)}` |
| 6 | debug logging | `GEM/logger/lib/logger/log_device.rb:165` | 4.57 | 100% | `no app frame` 46%, `app/jobs/tally_job.rb:3` 16% | `if @filename && (@shift_age > 0) && (@dev.stat.size > @shift_size)` |
| 7 | debug logging | `RAILS/activesupport/lib/active_support/logger.rb:42` | 4.57 | 100% | `no app frame` 46%, `app/jobs/tally_job.rb:3` 16% | `"#{String === msg ? msg : msg.inspect}\n"` |
| 8 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` | 4.14 | 86% | `engines/outsider/app/controllers/outsider/probe_controller.rb:9` 38%, `app/jobs/tally_job.rb:3` 32% | `binds = binds.inspect` |
| 9 | debug logging | `GEM/logger/lib/logger.rb:685` | 3.71 | 100% | `no app frame` 52%, `engines/outsider/app/controllers/outsider/probe_controller.rb:4` 22% | `message = yield` |
| 10 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:26` | 2.86 | 100% | `app/jobs/tally_job.rb:3` 50%, `app/controllers/widgets_controller.rb:13` 17% | `"#{payload[:name]} (#{event.duration.round(1)}ms)"` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: actionpack | 167.4 | 1164.2 | `static.rb:145` 15.4, `logger.rb:12` 11.9, `request.rb:66` 7.0 |
| rails: activesupport | 156.1 | 1672.5 | `class_attribute.rb:28` 11.4, `broadcast_logger.rb:129` 9.7, `log_subscriber.rb:177` 8.6 |
| ruby stdlib | 119.1 | 505.6 | `bundled_gems.rb:111` 35.4, `bundled_gems.rb:60` 28.3, `bundled_gems.rb:98` 21.2 |
| rails: activerecord | 70.6 | 289.9 | `log_subscriber.rb:49` 4.1, `log_subscriber.rb:90` 2.9, `log_subscriber.rb:26` 2.9 |
| gem: bootsnap | 68.9 | 448.4 | `iseq.rb:103` 30.0, `cache.rb:218` 12.4, `iseq.rb:159` 7.5 |
| gem: rack | 21.3 | 167.9 | `utils.rb:693` 4.3, `body_proxy.rb:12` 2.9, `etag.rb:68` 2.9 |
| gem: logger | 17.4 | 32.1 | `logger.rb:692` 4.6, `log_device.rb:165` 4.6, `log_device.rb:33` 4.6 |
| gem: concurrent-ruby | 13.1 | 26.6 | `safe_initialization.rb:30` 4.3, `mutex_lockable_object.rb:33` 1.4, `mutex_lockable_object.rb:32` 1.4 |
| rails: actionview | 13.0 | 221.6 | `layouts.rb:326` 2.9, `layouts.rb:287` 1.7, `lookup_context.rb:47` 1.0 |
| rails: activejob | 7.7 | 124.0 | `queue_adapter.rb:11` 0.9, `log_subscriber.rb:201` 0.9, `log_subscriber.rb:207` 0.9 |
| gem: sqlite3 | 7.3 | 22.4 | `statement.rb:76` 2.1, `statement.rb:36` 1.2, `database.rb:215` 1.2 |
| rails: railties | 6.7 | 31.6 | `logger.rb:57` 1.4, `engine.rb:748` 1.0, `logger.rb:24` 0.7 |
| rails: activemodel | 6.5 | 172.9 | `string.rb:39` 1.0, `attribute_set.rb:47` 0.6, `attribute.rb:9` 0.6 |
| gem: rack-session | 2.1 | 3.3 | `id.rb:368` 0.7, `id.rb:277` 0.7, `id.rb:275` 0.7 |
| ruby default gem: securerandom | 1.0 | 1.9 | `securerandom.rb:71` 1.0 |
| ruby default gem: uri | 0.9 | 4.2 | `rfc2396_parser.rb:320` 0.6, `common.rb:465` 0.3, `rfc2396_parser.rb:291` 0.0 |
| app | 0.5 | 34.7 | `probe_controller.rb:9` 0.4, `tally_job.rb:3` 0.1, `widgets_controller.rb:9` 0.0 |
| gem: json | 0.4 | 0.7 | `common.rb:861` 0.4 |
| rails: actioncable | 0.0 | 140.0 | `base.rb:110` 0.0, `active_record_connection_management.rb:13` 0.0, `engine.rb:50` 0.0 |
| gem: zeitwerk | 0.0 | 48.6 | `helpers.rb:41` 0.0, `file_system.rb:203` 0.0, `file_system.rb:199` 0.0 |
| gem: lowrail-profile | 0.0 | 1.1 | `profile.rb:73` 0.0, `profile.rb:55` 0.0, `profile.rb:83` 0.0 |
| gem: useragent | 0.0 | 213.7 | `browsers.rb:6` 0.0, `comparable.rb:0` 0.0, `webkit.rb:32` 0.0 |
| gem: i18n | 0.0 | 65.1 | `fallbacks.rb:96` 0.0, `base.rb:255` 0.0, `locale.rb:6` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Jobs

| # | Job | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | TallyJob#perform | 5 / 5 | 329.3 / 329.0 | -0.3 | 329.4 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 12.0, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 8.0, `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:235` 6.0 | `app/jobs/tally_job.rb:3` 164.0 |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `RAILS/activesupport/lib/active_support/log_subscriber.rb:177` (debug logging) | 14.4 / 10.8 | 100% | `app/jobs/tally_job.rb:3` 100% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 2 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | 9.6 / 7.2 | 100% | `app/jobs/tally_job.rb:3` 50%, `no app frame` 50% | `dispatch(:#{method}, ...)` |
| 3 | `RAILS/activesupport/lib/active_support/log_subscriber.rb:175` (debug logging) | 9.6 / 7.2 | 100% | `app/jobs/tally_job.rb:3` 100% | `modes = MODES.values_at(*options.compact_blank.keys)` |
| 4 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` | 6.4 / 4.8 | 100% | `app/jobs/tally_job.rb:3` 75%, `no app frame` 25% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 5 | `RAILS/activerecord/lib/active_record/log_subscriber.rb:26` (debug logging) | 4.8 / 3.6 | 100% | `app/jobs/tally_job.rb:3` 100% | `"#{payload[:name]} (#{event.duration.round(1)}ms)"` |
| 6 | `RAILS/activerecord/lib/active_record/log_subscriber.rb:89` (debug logging) | 4.8 / 3.6 | 100% | `app/jobs/tally_job.rb:3` 100% | `color = if (match = sql.match(/\A\s*(\w+)(?:\s\|\Z)/))` |
| 7 | `RAILS/activerecord/lib/active_record/log_subscriber.rb:90` (debug logging) | 4.8 / 3.6 | 100% | `app/jobs/tally_job.rb:3` 100% | `case match[1].downcase` |
| 8 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:217` | 4.8 / 3.6 | 100% | `no app frame` 50%, `app/jobs/tally_job.rb:3` 50% | `@broadcasts.map { \|logger\|` |
| 9 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:235` | 4.8 / 3.6 | 100% | `app/jobs/tally_job.rb:3` 100% | `reject { \|_k, v\| v.blank? }` |
| 10 | `RAILS/activesupport/lib/active_support/log_subscriber.rb:170` (debug logging) | 4.8 / 3.6 | 100% | `app/jobs/tally_job.rb:3` 100% | `clear = "\e[#{MODES[:clear]}m"` |

### Mails

| # | Mailer action | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | ProbeMailer.deliver_mail | 3 / 3 | 812.0 / 812.0 | 0.0 | 1095.7 | `GEM/mail/lib/mail/utilities.rb:215` 78.0, `GEM/mail/lib/mail/parsers/message_ids_parser.rb:4870` 45.0, `GEM/mail/lib/mail/utilities.rb:291` 38.0 |  |
| 2 | ProbeMailer#hello | 3 / 3 | 380.0 / 380.0 | 0.0 | 606.3 | `GEM/mail/lib/mail/utilities.rb:215` 36.0, `GEM/mail/lib/mail/parsers/address_lists_parser.rb:32009` 26.0, `GEM/mail/lib/mail/utilities.rb:291` 24.0 | `app/mailers/probe_mailer.rb:2` 336.0 |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `GEM/mail/lib/mail/utilities.rb:215` | 51.0 / 51.0 | 100% | `no app frame` 68%, `app/mailers/probe_mailer.rb:2` 32% | `str.to_s.tr(Constants::UNDERSCORE, Constants::HYPHEN)` |
| 2 | `GEM/mail/lib/mail/utilities.rb:291` | 27.0 / 27.0 | 100% | `no app frame` 61%, `app/mailers/probe_mailer.rb:2` 39% | `value !~ /\S/` |
| 3 | `GEM/mail/lib/mail/field_list.rb:71` | 23.5 / 23.5 | 100% | `no app frame` 71%, `app/mailers/probe_mailer.rb:2` 29% | `fields = select { \|f\| f.responsible_for? field_name }` |
| 4 | `GEM/mail/lib/mail/parsers/message_ids_parser.rb:4870` | 15.0 / 15.0 | 50% | `no app frame` 100% | `_wide = data[p].ord` |
| 5 | `GEM/mail/lib/mail/parser_tools.rb:7` | 13.5 / 13.5 | 100% | `app/mailers/probe_mailer.rb:2` 69%, `no app frame` 31% | `data.slice(from_bytes..to_bytes).force_encoding(Encoding::UTF_8)` |
| 6 | `GEM/mail/lib/mail/parsers/date_time_parser.rb:713` | 10.33 / 10.33 | 50% | `no app frame` 100% | `_wide = data[p].ord` |
| 7 | `GEM/mail/lib/mail/elements/address.rb:110` | 9.33 / 9.33 | 50% | `no app frame` 100% | `Encodings.decode_encode("#{@data.obs_domain_list}#{get_local.strip}", ` |
| 8 | `RUBY/bundled_gems.rb:111` | 9.17 / 9.17 | 33% | `no app frame` 55%, `app/mailers/probe_mailer.rb:2` 45% | `segments = feature.split("/", 3)` |
| 9 | `GEM/mail/lib/mail/fields/common_date_field.rb:34` | 9.0 / 9.0 | 50% | `no app frame` 100% | `::DateTime.parse("#{element.date_string} #{element.time_string}")` |
| 10 | `GEM/mail/lib/mail/parsers/address_lists_parser.rb:32009` | 8.67 / 8.67 | 50% | `app/mailers/probe_mailer.rb:2` 100% | `_wide = data[p].ord` |

### Action Cable

| # | Channel action | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | ProbeChannel#ping | 3 / 3 | 27.0 / 27.0 | 0.0 | 34.0 | `RAILS/actioncable/lib/action_cable/channel/base.rb:313` 4.0, `RAILS/actioncable/lib/action_cable/channel/base.rb:242` 3.0, `RAILS/activesupport/lib/active_support/core_ext/hash/indifferent_access.rb:10` 2.0 | `app/channels/probe_channel.rb:3` 11.0 |
| 2 | ProbeChannel#subscribed | 1 / 1 | – / – |  | 69.0 |  |  |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `RAILS/actioncable/lib/action_cable/channel/base.rb:313` | 2.0 / 2.0 | 75% | `no app frame` 100% | `signature << "(#{arguments.inspect})"` |
| 2 | `RAILS/actioncable/lib/action_cable/channel/base.rb:242` | 1.5 / 1.5 | 75% | `app/channels/probe_channel.rb:3` 100% | `status = "#{self.class.name} transmitting #{data.inspect.truncate(300)` |
| 3 | `GEM/logger/lib/logger.rb:692` † (debug logging) | 1.5 / 1.5 | 100% | `no app frame` 57%, `app/channels/probe_channel.rb:3` 43% | `format_message(format_severity(severity), Time.now, progname, message)` |
| 4 | `RAILS/activesupport/lib/active_support/core_ext/hash/indifferent_access.rb:10` | 1.5 / 1.5 | 100% | `app/channels/probe_channel.rb:3` 86%, `no app frame` 14% | `ActiveSupport::HashWithIndifferentAccess.new(self)` |
| 5 | `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:75` | 1.5 / 1.5 | 100% | `app/channels/probe_channel.rb:3` 86%, `no app frame` 14% | `update(constructor)` |
| 6 | `RAILS/activesupport/lib/active_support/logger.rb:42` (debug logging) | 1.5 / 1.5 | 100% | `no app frame` 57%, `app/channels/probe_channel.rb:3` 43% | `"#{String === msg ? msg : msg.inspect}\n"` |
| 7 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:324` | 1.0 / 1.0 | 50% | `no app frame` 67%, `app/channels/probe_channel.rb:3` 33% | `@string_subscribers[name] + @other_subscribers.select { \|s\| s.subscrib` |
| 8 | `RAILS/actioncable/lib/action_cable/channel/base.rb:189` | 0.5 / 0.5 | 75% | `no app frame` 100% | `payload = { channel_class: self.class.name, action: action, data: data` |
| 9 | `RAILS/actioncable/lib/action_cable/channel/base.rb:247` | 0.5 / 0.5 | 75% | `app/channels/probe_channel.rb:3` 100% | `payload = { channel_class: self.class.name, data: data, via: via }` |
| 10 | `RAILS/actioncable/lib/action_cable/channel/base.rb:249` | 0.5 / 0.5 | 75% | `app/channels/probe_channel.rb:3` 100% | `connection.transmit identifier: @identifier, message: data` |
