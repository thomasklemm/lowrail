# lowrail-profile report

Objects allocated (exact counts, not time, not retained memory) per request, job, mail and Action Cable action, by source line. A line with many objects is a place to look, not a measured cost in milliseconds.

* Command: `bin/rails test -v`
* Ruby: ruby 4.0.7 (2026-09-15 revision 229531a6cf) +PRISM [x86_64-linux]
* Rails: 8.1.4.1, test environment
* Counted in run 1: 7 requests, 5 jobs, 6 mail windows, 4 Cable actions; 2 runs
* Ledger: upstream pull requests as of 2026-11-25
* lowrail-profile 0.1.0.rc1

| Run | Processes | Requests | Objects per request | Jobs | Mails | Cable actions | Dropped |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| run1 | 1 | 7 | 5233.4 | 5 | 6 | 4 | 0 |
| run2 | 1 | 7 | 5233.7 | 5 | 6 | 4 | 0 |

Noise floor (last run minus first, warm, top 30 lines): median |Δ| 0.0, max |Δ| 0.0 objects per request; 0 lines moved by 1 or more.

## Your code

The app lines whose calls lead to the most objects allocated in Rails, Ruby and gems, per request (repeat run): the nearest app line on the stack of each allocation, the app's tests and vendored gems left out. Warm: leaving out each line's first request per process. Dev/test: debug logging, error pages, template compilation, route building and asset lookup below the line, which production mostly does not do. Own: objects the line itself allocates.

| # | App line | Method | Warm/req | Dev/test/req | Own/req | Lines it reaches (share of warm) | Actions (share) | Source |
| ---: | --- | --- | ---: | ---: | ---: | --- | --- | --- |
| 1 | `app/jobs/tally_job.rb:3` | `perform` | 23.43 | 12.43 | 0.14 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 4%, `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:235` 4%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 4% | Outsider::ProbeController#index 100%, WidgetsController#create 0% | `Tally.create!(source: source)` |
| 2 | `engines/outsider/app/controllers/outsider/probe_controller.rb:4` | `index` | 21.43 | 5.86 | 0.14 | `RUBY/random/formatter.rb:174` 9%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 7%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:208` 4% | Outsider::ProbeController#index 100% | `TallyJob.perform_later(params[:tag] \|\| "engine")` |
| 3 | `engines/outsider/app/controllers/outsider/probe_controller.rb:5` | `index` | 21.0 | 7.29 | 5.14 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 4%, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 3%, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:208` 3% | Outsider::ProbeController#index 100% | `render plain: "widgets #{Widget.count} #{Array.new(20) { \|i\| "w#{i}" }` |
| 4 | `engines/outsider/app/controllers/outsider/probe_controller.rb:9` | `show` | 11.86 | 5.43 | 0.71 | `GEM/sqlite3/lib/sqlite3/statement.rb:76` 4%, `RAILS/actionpack/lib/action_controller/metal/rendering.rb:228` 4%, `RAILS/activerecord/lib/active_record/core.rb:288` 2% | Outsider::ProbeController#show 100% | `render json: { id: params[:id], name: Widget.find_by(id: params[:id])&` |

108.86 warm objects per request outside the app have no app line on the stack (middleware, routing, rendering setup).

## Actions

Objects per request by controller action and run, counting everything the request allocates (app, Rails, gems, dev/test work). Warm leaves out the action's first request in each process; – when it ran once per process (those come last, ranked by all objects, which include one-time work). Top lines: warm objects per request of the action outside the app (repeat run, dev/test work left out).

| # | Action | Count | Warm/req | Δ | All/req | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | Outsider::ProbeController#index | 2 / 2 | 1118.0 / 1118.0 | 0.0 | 8146.0 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 28.0, `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0, `RAILS/activesupport/lib/active_support/inflector/methods.rb:78` 24.0 | `app/jobs/tally_job.rb:3` 164.0, `engines/outsider/app/controllers/outsider/probe_controller.rb:4` 150.0, `engines/outsider/app/controllers/outsider/probe_controller.rb:5` 147.0 |
| 2 | Outsider::ProbeController#show | 2 / 2 | 586.0 / 586.0 | 0.0 | 633.0 | `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` 27.0, `RAILS/activesupport/lib/active_support/inflector/methods.rb:78` 24.0, `RAILS/activesupport/lib/active_support/inflector/methods.rb:80` 20.0 | `engines/outsider/app/controllers/outsider/probe_controller.rb:9` 83.0 |
| 3 | WidgetsController#index | 1 / 1 | – / – |  | 2064.0 |  |  |
| 4 | WidgetsController#create | 1 / 1 | – / – |  | 2043.0 |  |  |
| 5 | WidgetsController#show | 1 / 1 | – / – |  | 522.0 |  |  |

## Top lines outside the app

Warm: objects per request by run, without each line's first request per process (one-time work). All: including it, mean of the runs. Reach: share of requests in which the line allocated (last run). † charged from Ruby's `<internal:…>` code to this caller. Ledger: upstream pull requests that reduce allocations and change this line, and whether the app's locked version has them. From the app: the nearest app line on the stack (repeat run). Dev/test-only work is listed separately below.

| # | Line | Method | Warm/req | Δ | All/req | Reach | Types | Ledger | From the app | Source |
| ---: | --- | --- | ---: | ---: | ---: | ---: | --- | --- | --- | --- |
| 1 | `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:145` | `file_readable?` | 19.29 / 19.29 | 0.0 | 23.14 | 86% | String, Array |  | `no app frame` 100% | `file_path = File.join(@root, path.b)` |
| 2 | `RUBY/bundled_gems.rb:111` | `warning?` | 17.86 / 17.86 | 0.0 | 85.71 | 43% | String, Array |  | `no app frame` 83%, `engines/outsider/app/controllers/outsider/probe_controller.rb:5` 12% | `segments = feature.split("/", 3)` |
| 3 | `GEM/bootsnap/lib/bootsnap/compile_cache/iseq.rb:103` | `storage_to_output` | 16.0 / 16.0 | 0.0 | 70.57 | 43% | Data, String |  | `no app frame` 84%, `engines/outsider/app/controllers/outsider/probe_controller.rb:5` 11% | `iseq = RubyVM::InstructionSequence.load_from_binary(binary)` |
| 4 | `RUBY/bundled_gems.rb:60` | `replace_require` | 14.29 / 14.29 | 0.0 | 67.57 | 43% | Data, String |  | `no app frame` 83%, `engines/outsider/app/controllers/outsider/probe_controller.rb:5` 12% | `kernel_class.send(:no_warning_require, name)` |
| 5 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | `#{method}` | 13.71 / 13.71 | 0.0 | 18.0 | 100% | Array, Hash |  | `no app frame` 41%, `engines/outsider/app/controllers/outsider/probe_controller.rb:4` 16% | `dispatch(:#{method}, ...)` |
| 6 | `RUBY/bundled_gems.rb:98` | `warning?` | 10.71 / 10.71 | 0.0 | 51.43 | 43% | String, MatchData |  | `no app frame` 83%, `engines/outsider/app/controllers/outsider/probe_controller.rb:5` 12% | `feature = File.path(name).sub(LIBEXT, "")` |
| 7 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:78` | `camelize` | 10.29 / 10.29 | 0.0 | 13.71 | 57% | String, Data |  | `no app frame` 100% | `string = string.sub(/^[a-z\d]*/) { \|match\| inflections.acronyms[match]` |
| 8 | `RUBY/random/formatter.rb:174` † | `uuid` | 10.0 / 10.0 | 0.0 | 13.0 | 100% | String, Array |  | `no app frame` 54%, `engines/outsider/app/controllers/outsider/probe_controller.rb:4` 31% | `ary.unpack("H8H4H4H4H12").join(?-)` |
| 9 | `RAILS/activesupport/lib/active_support/inflector/methods.rb:80` | `camelize` | 8.57 / 8.57 | 0.0 | 11.43 | 57% | String, MatchData |  | `no app frame` 100% | `string.gsub!(/(?:_\|(\/))([a-z\d]*)/i) do` |
| 10 | `RAILS/actionpack/lib/action_dispatch/http/request.rb:66` | `initialize` | 8.57 / 8.57 | 0.0 | 10.14 | 100% | Object |  | `no app frame` 100% | `@rack_request = Rack::Request.new(env)` |
| 11 | `RUBY/ipaddr.rb:725` | `in_addr` | 8.57 / 8.57 | 0.0 | 10.0 | 100% | String, Array |  | `no app frame` 100% | `octets = addr.split('.')` |
| 12 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` | `build_handle` | 6.86 / 6.86 | 0.0 | 10.29 | 100% | Object, Data | #59613 merged 2026-11-04, after this app's version, not released yet, #59235 merged 2026-10-21, after this app's version, not released yet | `app/jobs/tally_job.rb:3` 36%, `no app frame` 19% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 13 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:217` | `dispatch` | 6.86 / 6.86 | 0.0 | 9.0 | 100% | Array |  | `no app frame` 41%, `engines/outsider/app/controllers/outsider/probe_controller.rb:4` 16% | `@broadcasts.map { \|logger\|` |
| 14 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:287` | `build_handle` | 6.43 / 6.43 | 0.0 | 8.71 | 100% | Array | #59235 merged 2026-10-21, after this app's version, not released yet | `no app frame` 34%, `app/jobs/tally_job.rb:3` 26% | `groups = groups_for(name).map do \|group_klass, grouped_listeners\|` |
| 15 | `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:146` | `file_readable?` | 6.43 / 6.43 | 0.0 | 7.71 | 86% | String |  | `no app frame` 100% | `File.file?(file_path) && File.readable?(file_path)` |
| 16 | `RAILS/actionpack/lib/action_dispatch/middleware/static.rb:156` | `each_precompressed_filepath` | 6.43 / 6.43 | 0.0 | 7.71 | 86% | String |  | `no app frame` 100% | `yield content_encoding, "#{filepath}#{precompressed_ext}"` |
| 17 | `GEM/bootsnap/lib/bootsnap/load_path_cache/cache.rb:218` | `try_index` | 6.29 / 6.29 | 0.0 | 28.57 | 43% | String, Array |  | `no app frame` 84%, `engines/outsider/app/controllers/outsider/probe_controller.rb:5` 14% | `-File.join(path, feature).freeze` |
| 18 | `RAILS/activesupport/lib/active_support/class_attribute.rb:28` | `redefine_method` | 5.71 / 5.71 | 0.0 | 32.71 | 29% | Data, String |  | `no app frame` 63%, `engines/outsider/app/controllers/outsider/probe_controller.rb:2` 7% | `owner.define_method(name, &block)` |
| 19 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:208` | `dispatch` | 5.71 / 5.71 | 0.0 | 7.71 | 100% | Data |  | `no app frame` 52%, `engines/outsider/app/controllers/outsider/probe_controller.rb:4` 22% | `block = proc { \|*args, **kwargs\|` |
| 20 | `RAILS/actionpack/lib/action_dispatch/journey/path/pattern.rb:77` | `accept` | 5.57 / 5.57 | 0.0 | 7.0 | 71% | String, Regexp |  | `no app frame` 100% | `%r{\A#{visit node}\Z}` |
| 21 | `GEM/rack/lib/rack/utils.rb:693` | `clean_path_info` | 5.29 / 5.29 | 0.0 | 6.29 | 86% | String, Array |  | `no app frame` 100% | `parts = path_info.split PATH_SEPS` |
| 22 | `GEM/concurrent-ruby/lib/concurrent-ruby/concurrent/synchronization/safe_initialization.rb:30` | `new` | 5.14 / 5.14 | 0.0 | 6.0 | 100% | Object |  | `no app frame` 100% | `super(*args, &block)` |
| 23 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:204` | `groups_for` | 4.86 / 4.86 | 0.0 | 7.0 | 100% | Array |  | `no app frame` 29%, `app/jobs/tally_job.rb:3` 27% | `active_subscriptions = subscriptions.reject { \|s\| s.silenced?(name) }` |
| 24 | `RAILS/activesupport/lib/active_support/callbacks.rb:179` | `call` | 4.86 / 4.86 | 0.0 | 5.71 | 100% | Data |  | `no app frame` 88%, `app/jobs/tally_job.rb:3` 8% | `result_lambda = -> { user_callback.call target, value }` |
| 25 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:186` | `build_event` | 4.71 / 4.71 | 0.0 | 6.71 | 100% | Object |  | `no app frame` 30%, `app/jobs/tally_job.rb:3` 28% | `ActiveSupport::Notifications::Event.new name, nil, nil, id, payload` |
| 26 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:206` | `groups_for` | 4.71 / 4.71 | 0.0 | 6.71 | 100% | Hash |  | `no app frame` 30%, `app/jobs/tally_job.rb:3` 28% | `groups = groups.dup if groups.frozen?` |
| 27 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:294` | `build_handle` | 4.71 / 4.71 | 0.0 | 6.71 | 100% | Object |  | `no app frame` 30%, `app/jobs/tally_job.rb:3` 28% | `Handle.new(self, name, id, groups, payload)` |
| 28 | `RAILS/activesupport/lib/active_support/notifications/instrumenter.rb:112` | `initialize` | 4.71 / 4.71 | 0.0 | 6.71 | 100% | Hash |  | `no app frame` 30%, `app/jobs/tally_job.rb:3` 28% | `@payload        = payload.dup` |
| 29 | `RAILS/activesupport/lib/active_support/subscriber.rb:137` | `call` | 4.71 / 4.71 | 0.0 | 6.71 | 100% | String | #59562 merged 2026-11-03, after this app's version, not released yet | `no app frame` 30%, `app/jobs/tally_job.rb:3` 28% | `method = event.name[0, event.name.index(".")]` |
| 30 | `RAILS/actionpack/lib/action_dispatch/http/response.rb:496` | `parse_content_type` | 4.14 / 4.14 | 0.0 | 5.29 | 100% | String, Struct |  | `no app frame` 89%, `engines/outsider/app/controllers/outsider/probe_controller.rb:5` 11% | `ContentTypeHeader.new(match[:mime_type], match[:charset])` |

## Dev/test-mode work

134.0 of 727.3 warm objects per request outside the app are work that test and development mode do and production mostly does not: debug logging, error pages, template compilation, route building, asset lookup, code reload checks.

| # | Kind | Line | Warm/req | Reach | From the app | Source |
| ---: | --- | --- | ---: | ---: | --- | --- |
| 1 | debug logging | `RAILS/actionpack/lib/abstract_controller/logger.rb:12` | 14.0 | 100% | `no app frame` 100% | `singleton_class.delegate :logger, :logger=, to: :config` |
| 2 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:177` | 12.0 | 100% | `app/jobs/tally_job.rb:3` 50%, `app/controllers/widgets_controller.rb:13` 17% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 3 | debug logging | `RAILS/activesupport/lib/active_support/log_subscriber.rb:175` | 8.0 | 100% | `app/jobs/tally_job.rb:3` 50%, `app/controllers/widgets_controller.rb:13` 17% | `modes = MODES.values_at(*options.compact_blank.keys)` |
| 4 | debug logging | `GEM/logger/lib/logger.rb:692` † | 6.29 | 100% | `no app frame` 46%, `app/jobs/tally_job.rb:3` 16% | `format_message(format_severity(severity), Time.now, progname, message)` |
| 5 | debug logging | `GEM/logger/lib/logger/log_device.rb:33` | 6.29 | 100% | `no app frame` 46%, `app/jobs/tally_job.rb:3` 16% | `handle_write_errors("writing") {@dev.write(message)}` |
| 6 | debug logging | `GEM/logger/lib/logger/log_device.rb:165` | 6.29 | 100% | `no app frame` 46%, `app/jobs/tally_job.rb:3` 16% | `if @filename && (@shift_age > 0) && (@dev.stat.size > @shift_size)` |
| 7 | debug logging | `RAILS/activesupport/lib/active_support/logger.rb:42` | 6.29 | 100% | `no app frame` 46%, `app/jobs/tally_job.rb:3` 16% | `"#{String === msg ? msg : msg.inspect}\n"` |
| 8 | debug logging | `GEM/logger/lib/logger.rb:685` | 5.71 | 100% | `no app frame` 52%, `engines/outsider/app/controllers/outsider/probe_controller.rb:4` 22% | `message = yield` |
| 9 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:49` | 4.71 | 86% | `engines/outsider/app/controllers/outsider/probe_controller.rb:9` 38%, `app/jobs/tally_job.rb:3` 32% | `binds = binds.inspect` |
| 10 | debug logging | `RAILS/activerecord/lib/active_record/log_subscriber.rb:26` | 4.0 | 100% | `app/jobs/tally_job.rb:3` 50%, `app/controllers/widgets_controller.rb:13` 17% | `"#{payload[:name]} (#{event.duration.round(1)}ms)"` |

## By gem

| Group | Warm/req | All/req | Top lines (warm) |
| --- | ---: | ---: | --- |
| rails: activesupport | 192.6 | 951.6 | `broadcast_logger.rb:129` 13.7, `log_subscriber.rb:177` 12.0, `methods.rb:78` 10.3 |
| rails: actionpack | 188.0 | 689.1 | `static.rb:145` 19.3, `logger.rb:12` 14.0, `request.rb:66` 8.6 |
| rails: activerecord | 96.6 | 206.0 | `log_subscriber.rb:49` 4.7, `log_subscriber.rb:26` 4.0, `log_subscriber.rb:90` 4.0 |
| ruby stdlib | 82.6 | 275.9 | `bundled_gems.rb:111` 17.9, `bundled_gems.rb:60` 14.3, `bundled_gems.rb:98` 10.7 |
| gem: bootsnap | 36.0 | 225.7 | `iseq.rb:103` 16.0, `cache.rb:218` 6.3, `iseq.rb:159` 4.0 |
| gem: rack | 25.9 | 167.0 | `utils.rb:693` 5.3, `etag.rb:68` 3.4, `body_proxy.rb:12` 3.4 |
| gem: logger | 24.6 | 32.1 | `logger.rb:692` 6.3, `log_device.rb:165` 6.3, `log_device.rb:33` 6.3 |
| rails: actionview | 17.0 | 122.1 | `lookup_context.rb:47` 1.4, `lookup_context.rb:44` 1.4, `layouts.rb:326` 1.4 |
| gem: concurrent-ruby | 15.9 | 22.6 | `safe_initialization.rb:30` 5.1, `mutex_lockable_object.rb:33` 1.7, `mutex_lockable_object.rb:32` 1.7 |
| rails: activejob | 15.4 | 73.6 | `log_subscriber.rb:207` 1.7, `log_subscriber.rb:201` 1.7, `queue_adapter.rb:11` 1.7 |
| gem: sqlite3 | 9.6 | 17.4 | `statement.rb:76` 2.6, `database.rb:215` 1.7, `statement.rb:36` 1.7 |
| rails: activemodel | 9.3 | 98.4 | `string.rb:39` 1.1, `attribute.rb:9` 0.9, `attribute_set.rb:47` 0.9 |
| rails: railties | 8.1 | 20.6 | `logger.rb:57` 1.7, `engine.rb:748` 1.3, `logger.rb:24` 0.9 |
| app | 6.1 | 24.4 | `probe_controller.rb:5` 5.1, `probe_controller.rb:9` 0.7, `tally_job.rb:3` 0.3 |
| gem: rack-session | 2.6 | 3.1 | `id.rb:275` 0.9, `id.rb:368` 0.9, `id.rb:277` 0.9 |
| ruby default gem: securerandom | 1.4 | 1.9 | `securerandom.rb:71` 1.4 |
| ruby default gem: uri | 1.3 | 3.1 | `rfc2396_parser.rb:320` 0.7, `common.rb:465` 0.6, `rfc2396_parser.rb:291` 0.0 |
| gem: json | 0.6 | 0.7 | `common.rb:861` 0.6 |
| rails: actioncable | 0.0 | 69.7 | `worker.rb:17` 0.0, `base.rb:20` 0.0, `base.rb:155` 0.0 |
| gem: useragent | 0.0 | 106.9 | `apple_core_media.rb:0` 0.0, `user_agent.rb:0` 0.0, `chrome.rb:0` 0.0 |
| gem: zeitwerk | 0.0 | 24.3 | `loader.rb:514` 0.0, `file_system.rb:199` 0.0, `file_system.rb:137` 0.0 |
| gem: i18n | 0.0 | 32.6 | `fallbacks.rb:96` 0.0, `locale.rb:6` 0.0, `base.rb:264` 0.0 |
| lowrail-profile | 0.0 | 0.6 | `profile.rb:73` 0.0, `profile.rb:55` 0.0, `profile.rb:83` 0.0 |

## Outside requests

Jobs (`perform_now`), mails (each build and each delivery) and Action Cable channel actions run outside a request, counted the same way and per window. A job, mail or broadcast inside a request counts as part of that request.

### Jobs

| # | Job | Count | Warm/window | Δ | All/window | Top lines outside the app (warm) | Top app lines (warm) |
| ---: | --- | ---: | ---: | ---: | ---: | --- | --- |
| 1 | TallyJob#perform | 5 / 5 | 329.3 / 329.3 | 0.0 | 329.4 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` 12.0, `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` 8.0, `RAILS/activesupport/lib/active_support/broadcast_logger.rb:217` 6.0 | `app/jobs/tally_job.rb:3` 164.3 |

| # | Line | Warm/window | Reach | From the app | Source |
| ---: | --- | ---: | ---: | --- | --- |
| 1 | `RAILS/activesupport/lib/active_support/log_subscriber.rb:177` (debug logging) | 14.4 / 14.4 | 100% | `app/jobs/tally_job.rb:3` 100% | `"\e[#{modes.join(";")}m" if modes.any?` |
| 2 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:129` | 9.6 / 9.6 | 100% | `app/jobs/tally_job.rb:3` 50%, `no app frame` 50% | `dispatch(:#{method}, ...)` |
| 3 | `RAILS/activesupport/lib/active_support/log_subscriber.rb:175` (debug logging) | 9.6 / 9.6 | 100% | `app/jobs/tally_job.rb:3` 100% | `modes = MODES.values_at(*options.compact_blank.keys)` |
| 4 | `RAILS/activesupport/lib/active_support/notifications/fanout.rb:288` | 6.4 / 6.4 | 100% | `app/jobs/tally_job.rb:3` 75%, `no app frame` 25% | `group_klass.new(grouped_listeners, name, id, payload)` |
| 5 | `RAILS/activerecord/lib/active_record/log_subscriber.rb:26` (debug logging) | 4.8 / 4.8 | 100% | `app/jobs/tally_job.rb:3` 100% | `"#{payload[:name]} (#{event.duration.round(1)}ms)"` |
| 6 | `RAILS/activerecord/lib/active_record/log_subscriber.rb:89` (debug logging) | 4.8 / 4.8 | 100% | `app/jobs/tally_job.rb:3` 100% | `color = if (match = sql.match(/\A\s*(\w+)(?:\s\|\Z)/))` |
| 7 | `RAILS/activerecord/lib/active_record/log_subscriber.rb:90` (debug logging) | 4.8 / 4.8 | 100% | `app/jobs/tally_job.rb:3` 100% | `case match[1].downcase` |
| 8 | `RAILS/activesupport/lib/active_support/broadcast_logger.rb:217` | 4.8 / 4.8 | 100% | `no app frame` 50%, `app/jobs/tally_job.rb:3` 50% | `@broadcasts.map { \|logger\|` |
| 9 | `RAILS/activesupport/lib/active_support/core_ext/enumerable.rb:235` | 4.8 / 4.8 | 100% | `app/jobs/tally_job.rb:3` 100% | `reject { \|_k, v\| v.blank? }` |
| 10 | `RAILS/activesupport/lib/active_support/log_subscriber.rb:170` (debug logging) | 4.8 / 4.8 | 100% | `app/jobs/tally_job.rb:3` 100% | `clear = "\e[#{MODES[:clear]}m"` |

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
| 1 | ProbeChannel#ping | 3 / 3 | 27.0 / 27.0 | 0.0 | 34.0 | `RAILS/actioncable/lib/action_cable/channel/base.rb:313` 4.0, `RAILS/actioncable/lib/action_cable/channel/base.rb:242` 3.0, `RAILS/activesupport/lib/active_support/hash_with_indifferent_access.rb:75` 2.0 | `app/channels/probe_channel.rb:3` 11.0 |
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
