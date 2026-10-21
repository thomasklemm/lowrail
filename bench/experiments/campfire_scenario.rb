# frozen_string_literal: true

# Untimed production discovery only. No clocks, Ir counters or cohort launcher.
# Run through the selected app's frozen bundle; all state is disposable/private.
require "json"
require "fileutils"
require "digest"
require "cgi"
require "rbconfig"

module CampfireScenario
  ROOT = File.expand_path("../..", __dir__)
  PIN = "02023b0f0cafc4d66e06e43be072cf4d6ca328fa"
  METHODS = %i[link_to form_with form_tag token_tag collection_with_template
    collection_without_template render_collection_with_cache instantiate_instance_of
    preload_associations script_locations broadcast broadcast_append_to].freeze
  module_function

  def environment(app, state)
    raise "isolated corpus required" unless File.realpath(app).start_with?(File.join(ROOT, ".corpus/"))
    {"RAILS_ENV" => "production", "RACK_ENV" => "production", "SKIP_TELEMETRY" => "1",
      "SECRET_KEY_BASE" => File.read(File.join(state, "secret_key_base")), "SECRET_KEY_BASE_DUMMY" => nil,
      # Upstream Cable and Resque hard-code localhost:6379/0 at this pin.
      # Use a dedicated disposable server there, without an app overlay.
      "DATABASE_URL" => "sqlite3:#{state}/primary.sqlite3", "REDIS_URL" => "redis://127.0.0.1:6379/0",
      "RAILS_LOG_LEVEL" => "fatal", "RUBY_YJIT_ENABLE" => "0", "RUBY_ZJIT_ENABLE" => "0",
      "BUNDLE_GEMFILE" => File.join(app, "Gemfile"), "BUNDLE_FROZEN" => "true",
      "APP_VERSION" => "lowrail-campfire-fixture", "GIT_REVISION" => PIN}
  end

  def boot(app)
    require File.join(app, "config/application")
    Rails.application.config.yjit = false
    require File.join(app, "config/environment")
    raise "production interpreter required" unless Rails.env.production? && !RubyVM::YJIT.enabled? &&
      !(defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?)
  end

  def prepare(app, state)
    raise "new state required" if File.exist?(state)
    raise "wrong fixture pin" unless IO.popen(["git", "-C", app, "rev-parse", "HEAD"], &:read).strip == PIN
    require "securerandom"
    FileUtils.mkdir_p(state, mode: 0o700)
    File.write(File.join(state, "secret_key_base"), SecureRandom.hex(64), perm: 0o600)
    environment(app, state).each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
    boot(app)
    ActiveRecord::Schema.verbose = false
    load File.join(app, "db/schema.rb")
    require "active_record/fixtures"
    require "active_support/testing/time_helpers"
    clock = Object.new.extend(ActiveSupport::Testing::TimeHelpers)
    clock.travel_to(Time.utc(2026, 3, 2, 12)) do
      path = File.join(app, "test/fixtures")
      names = Dir[File.join(path, "**/*.yml")].sort.map { _1.delete_prefix(path + "/").delete_suffix(".yml") }
      ActiveRecord::FixtureSet.create_fixtures(path, names)
    end
    id = ->(label) { ActiveRecord::FixtureSet.identify(label) }
    room, writer = id.call("watercooler"), id.call("hq")
    messages, texts = [], []
    1.upto(120) do |i|
      time = Time.utc(2026, 2, 28, 8) + i * 420
      message = 2_000_000 + i
      body = "<p>#{format('%03d', i)}. #{i % 10 == 1 ? 'Coffee machine is fixed!' : 'Campfire fixture conversation.'}</p>"
      messages << {id: message, room_id: room, creator_id: id.call(i.odd? ? "david" : "jason"),
        client_message_id: "lowrail-busy-#{i}", created_at: time, updated_at: time}
      texts << {id: message, record_type: "Message", record_id: message, name: "body", body: body,
        created_at: time, updated_at: time}
    end
    Message.insert_all!(messages)
    ActionText::RichText.insert_all!(texts)
    # Fixture SQL bypasses callbacks: populate FTS explicitly, without jobs.
    Message.connection.execute("DELETE FROM message_search_index")
    Message.find_each { _1.send(:create_in_index) }
    vector = [
      {id: "room", method: "GET", path: "/rooms/#{room}"},
      {id: "pagination", method: "GET", path: "/rooms/#{room}/messages?before=2000060"},
      {id: "sidebar", method: "GET", path: "/users/me/sidebar"},
      {id: "search", method: "GET", path: "/searches?q=coffee"},
      {id: "post", method: "POST", path: "/rooms/#{writer}/messages"},
      {id: "rooms_index", method: "GET", path: "/rooms"},
      {id: "refresh", method: "GET", path: "/rooms/#{room}/refresh.turbo_stream?since=0"}
    ]
    expected = {
      # Derive the oracle from fixture inputs, not the app's pagination/search.
      # Ten upstream messages are newer than the 120 inserted conversations.
      "room" => (2_000_091..2_000_120).to_a +
        %w[fourth fifth sixth seventh eighth ninth tenth eleventh twelfth thirteenth].map { id.call(_1) },
      "pagination" => (2_000_020..2_000_059).to_a,
      "search" => (1..120).select { _1 % 10 == 1 }.map { 2_000_000 + _1 }
    }
    File.write(File.join(state, "scenario.json"), JSON.pretty_generate(vector: vector, expected: expected,
      login: {email_address: "david@37signals.com", password: "secret123456"}), perm: 0o600)
    ActiveRecord::Base.connection_pool.disconnect!
    puts JSON.generate(prepared: true, messages: 133, room_messages: 130, expected_counts: expected.transform_values(&:size))
  end

  class Driver
    attr_reader :steps

    def initialize(state, record: true, validate: true)
      require "rack/mock"
      @scenario = JSON.parse(File.read(File.join(state, "scenario.json")))
      @rack, @cookies, @steps = Rack::MockRequest.new(Rails.application), {}, []
      @record, @validate = record, validate
    end

    def request(verb, path, params = nil, accept = "text/html")
      headers = {"HTTP_HOST" => "campfire.example.invalid", "HTTPS" => "on",
        "HTTP_ORIGIN" => "https://campfire.example.invalid", "HTTP_SEC_FETCH_SITE" => "same-origin",
        "HTTP_ACCEPT" => accept, "HTTP_ACCEPT_ENCODING" => "identity",
        "HTTP_USER_AGENT" => "Mozilla/5.0 Firefox/140.0", "HTTP_X_REQUEST_ID" => "campfire-fixture",
        "HTTP_COOKIE" => @cookies.map { |name, value| "#{name}=#{value}" }.join("; ")}
      headers[:params] = params if params
      response = @rack.request(verb, path, headers)
      Array(response.headers["set-cookie"]).each do |cookie|
        name, value = cookie.split(";", 2).first.split("=", 2)
        @cookies[name] = value
      end
      @steps << {"method" => verb, "path" => path, "status" => response.status,
        "headers" => response.headers.to_h, "body" => response.body} if @record
      response
    end

    def login
      page = request("GET", "/session/new")
      raise "sign-in page" unless page.status == 200
      token = page.body[/name="csrf-token" content="([^"]+)"/, 1] or raise "CSRF absent"
      response = request("POST", "/session", @scenario.fetch("login").merge("authenticity_token" => CGI.unescapeHTML(token)))
      raise "sign-in failed" unless response.status == 302 && @cookies.key?("session_token")
    end

    def prepare_post
      return if @post_token
      path = @scenario.fetch("vector").find { _1.fetch("id") == "post" }.fetch("path")
      room = request("GET", path.delete_suffix("/messages"))
      token = room.body[/name="csrf-token" content="([^"]+)"/, 1] or raise "post CSRF absent"
      @post_token = CGI.unescapeHTML(token)
    end

    def run(id, validate: @validate)
      route = @scenario.fetch("vector").find { _1.fetch("id") == id } or raise "unknown route"
      params, accept = nil, "text/html"
      if id == "post"
        prepare_post
        @posts = (@posts || 0) + 1
        params = {"authenticity_token" => @post_token, "message" => {
          "body" => "<p>Lowrail exact post #{@posts}</p>", "client_message_id" => "lowrail-post-#{@posts}"}}
        accept = "text/vnd.turbo-stream.html"
      end
      response = request(route.fetch("method"), route.fetch("path"), params, accept)
      raise "#{id}: #{response.status}" unless response.status == (id == "rooms_index" ? 302 : 200)
      validate_response(id, response) if validate
      response
    end

    def validate_response(id, response)
      route = @scenario.fetch("vector").find { _1.fetch("id") == id } or raise "unknown route"
      if (expected = @scenario.fetch("expected")[id])
        # Model-independent expected windows were frozen by preparation SQL.
        actual = response.body.scan(/data-message-id="(\d+)"/).flatten.map(&:to_i)
        raise "#{id}: wrong message order/window" unless actual == expected
      end
      raise "sidebar missing shared rooms" if id == "sidebar" && !response.body.include?('id="shared_rooms"')
      if id == "post"
        row = Message.find_by!(client_message_id: "lowrail-post-#{@posts}")
        raise "wrong persisted post" unless row.body.to_plain_text == "Lowrail exact post #{@posts}" &&
          row.room_id == route.fetch("path").split("/")[2].to_i &&
          Message.connection.select_value("SELECT body FROM message_search_index WHERE rowid = #{row.id}") == "Lowrail exact post #{@posts}"
        raise "wrong stream response" unless response.media_type == "text/vnd.turbo-stream.html" && response.body.include?('action="append"')
      end
    end
  end

  # Counts entry/reachability, not specialization completions. No binding
  # reads, probes, fallback replays or changes to application method bodies.
  def census(driver, id)
    driver.prepare_post if id == "post"
    calls, sites, sql, events = Hash.new(0), Hash.new(0), [], []
    stats = defined?(Lowrail::Stats) && Lowrail::Stats.enabled?
    before = stats ? [Lowrail::Stats.unit_hits, Lowrail::Stats.unit_fallbacks] : [{}, {}]
    thread = Thread.current
    trace = TracePoint.new(:call) do |event|
      next unless Thread.current.equal?(thread) && METHODS.include?(event.method_id)
      calls["#{event.defined_class}##{event.method_id}"] += 1
      if %i[link_to form_with form_tag token_tag].include?(event.method_id)
        site = caller_locations.find { _1.path.include?("/app/views/") }
        sites["#{event.method_id} #{site.path.split('/app/views/').last}:#{site.lineno}"] += 1 if site
      end
    end
    subscription = ActiveSupport::Notifications.subscribe(/\.(?:active_record|action_view|action_controller)\z/) do |name, *rest|
      payload = rest.last
      if name == "sql.active_record"
        sql << {"sql" => payload[:sql], "cached" => !!payload[:cached], "other_thread" => !Thread.current.equal?(thread)}
      else
        events << {"name" => name, "identifier" => payload[:identifier]&.to_s&.sub(Rails.root.to_s + "/", ""),
          "count" => payload[:count], "cache_hits" => payload[:cache_hits]}
      end
    end
    response = trace.enable { driver.run(id, validate: false) }
    after = stats ? [Lowrail::Stats.unit_hits, Lowrail::Stats.unit_fallbacks] : [{}, {}]
    counts = before.zip(after).map { |a, b| (a.keys | b.keys).to_h { [_1, b.fetch(_1, 0) - a.fetch(_1, 0)] } }
    ActiveSupport::Notifications.unsubscribe(subscription)
    subscription = nil
    # Persistence/FTS oracle queries must not become application SQL or AR
    # opportunities. Validate the same response after observation ends.
    driver.validate_response(id, response)
    {"entries" => calls, "sites" => sites, "sql" => sql, "events" => events,
      "response_bytes" => driver.steps.last.fetch("body").bytesize,
      "unit_hits" => counts.first, "unit_fallbacks" => counts.last}
  ensure
    trace&.disable
    ActiveSupport::Notifications.unsubscribe(subscription) if subscription
  end

  def pins(app)
    {"app_sha" => IO.popen(["git", "-C", app, "rev-parse", "HEAD"], &:read).strip,
      "harness_sha" => IO.popen(["git", "-C", ROOT, "rev-parse", "HEAD"], &:read).strip,
      "ruby" => RUBY_DESCRIPTION, "rails" => Rails.version,
      "lock_sha256" => Digest::SHA256.file(File.join(app, "Gemfile.lock")).hexdigest,
      "harness_sha256" => Digest::SHA256.file(__FILE__).hexdigest,
      "interpreter" => !RubyVM::YJIT.enabled? && !(defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?)}
  end

  def worker(mode, app, state, output)
    if mode == "profile"
      # Diagnostic dependency lives outside the app's unchanged bundle, as in
      # bench/requests.rb; activate before Bundler hides unrelated gem specs.
      $LOAD_PATH.unshift(*ENV.fetch("CAMPFIRE_STACKPROF_LOAD_PATH").split(File::PATH_SEPARATOR))
      require "stackprof"
    end
    boot(app)
    recorded = %w[cold census room_cold room_census].include?(mode)
    driver = Driver.new(state, record: recorded, validate: recorded)
    driver.login
    report = {"pins" => pins(app), "mode" => mode}
    case mode
    when "cold", "room_cold"
      routes = mode == "room_cold" ? %w[room] : %w[room pagination sidebar search post rooms_index refresh]
      routes.each { driver.run(_1) }
      report["steps"] = driver.steps
    when "census", "room_census"
      routes = mode == "room_census" ? %w[room] : %w[room pagination sidebar search rooms_index refresh post]
      report["routes"] = routes.to_h do |id|
        [id, %w[cold warm repeat].to_h { |phase| [phase, census(driver, id)] }]
      end
      report["lowrail_stats"] = defined?(Lowrail::Stats) && Lowrail::Stats.enabled? ? Lowrail::Stats.snapshot : nil
    when "profile"
      require "stackprof"
      report["routes"] = %w[room pagination sidebar search refresh post].to_h do |id|
        5.times { driver.run(id) }
        profile = StackProf.run(mode: :cpu, interval: 1000, raw: true) { 40.times { driver.run(id) } }
        frames = profile.fetch(:frames)
        bands = {"views" => %r{/(actionview-[^/]+/|app/views/)},
          "helpers" => %r{/(?:app/helpers|action_view/helpers)/},
          "active_record" => %r{/activerecord-[^/]+/},
          "action_cable" => %r{/actioncable-[^/]+/}, "turbo" => %r{/turbo-rails-[^/]+/}}
        samples = Hash.new(0)
        raw, index = profile.fetch(:raw), 0
        while index < raw.size
          depth = raw.fetch(index)
          files = raw.slice(index + 1, depth).map { frames.fetch(_1)[:file].to_s }
          count = raw.fetch(index + depth + 1)
          bands.each { |name, pattern| samples[name] += count if files.any? { pattern.match?(_1) } }
          index += depth + 2
        end
        top = frames.values.sort_by { -_1.fetch(:total_samples) }.first(30).map do |frame|
          frame.slice(:name, :file, :line, :samples, :total_samples)
        end
        self_samples = bands.transform_values do |pattern|
          frames.values.sum { pattern.match?(_1[:file].to_s) ? _1.fetch(:samples) : 0 }
        end
        top_self = frames.values.sort_by { -_1.fetch(:samples) }.first(20).map do |frame|
          frame.slice(:name, :file, :line, :samples, :total_samples)
        end
        [id, {"samples" => profile[:samples], "missed_samples" => profile[:missed_samples],
          "overlapping_inclusive_bands" => samples, "self_bands" => self_samples,
          "top_inclusive" => top, "top_self" => top_self}]
      end
    when "heap"
      # Deliberately tool=none, not Callgrind; no start/finish client seam.
      # Floors are derived off-only and frozen by campfire_heap.rb before on.
      require_relative "../heap_windows"
      count = Integer(ENV.fetch("CAMPFIRE_HEAP_REQUESTS", "50"))
      raise "positive request count required" unless count.positive?
      phases = %w[total no_gc]
      phases.reverse! if ENV.fetch("BENCH_PHASE_ORDER", "0") == "1"
      50.times { driver.run("room") }
      anchors = HeapWindows.prepare_heap
      report["targets"] = HeapWindows.page_targets
      report["anchors"] = anchors.size
      report["windows"] = phases.product([0, count]).map do |phase, requests|
        HeapWindows.collect
        driver.run("room")
        hits = defined?(Lowrail::Stats) ? Lowrail::Stats.unit_hits : {}
        before = GC.stat_heap
        begin
          GC.disable if phase == "no_gc"
          requests.times { driver.run("room") }
        ensure
          GC.enable
        end
        after = GC.stat_heap
        completed = defined?(Lowrail::Stats) ? Lowrail::Stats.unit_hits : {}
        {"mode" => phase, "requests" => requests, "before" => before, "after" => after,
          "completed_hits" => (hits.keys | completed.keys).to_h { [_1, completed.fetch(_1, 0) - hits.fetch(_1, 0)] },
          "pages_equal" => before.all? { |pool, stats| stats[:heap_eden_pages] == after.fetch(pool)[:heap_eden_pages] }}
      end
      report["stable"] = report.fetch("windows").all? { _1.fetch("pages_equal") }
    else
      raise "unknown untimed mode"
    end
    report["threads"] = Thread.list.map { {"name" => _1.name, "status" => _1.status} }
    require "resque"
    report["queued_jobs"] = Resque.queues.to_h { [_1, Resque.size(_1)] }
    File.write(output, JSON.pretty_generate(report), perm: 0o600)
  end
end

if $PROGRAM_NAME == __FILE__
  mode, app, state, output = ARGV
  abort "usage: campfire_scenario.rb prepare|cold|census|room_cold|room_census|profile|heap APP STATE [PRIVATE_JSON]" unless mode && app && state
  app, state = [app, state].map { File.expand_path(_1) }
  mode == "prepare" ? CampfireScenario.prepare(app, state) : CampfireScenario.worker(mode, app, state, output)
end
