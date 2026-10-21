# frozen_string_literal: true

# Native YJIT direction-finding only. No Lowrail setup, application patches,
# cache-policy overrides, GC tuning, Callgrind or optimization claims.
require "json"
require "digest"
require "fileutils"
require "cgi"
require "rbconfig"
require_relative "fizzy_link_fixture"
require_relative "campfire_scenario"

module LargeAppProfile
  ROOT = File.expand_path("../..", __dir__)
  module_function

  class Client
    def initialize(host)
      require "rack/mock"
      @rack, @cookies, @host = Rack::MockRequest.new(Rails.application), {}, host
    end

    def request(method, path, params = nil)
      options = {"HTTP_HOST" => @host, "HTTPS" => "on", "HTTP_ORIGIN" => "https://#{@host}",
        "HTTP_ACCEPT" => "text/html", "HTTP_USER_AGENT" => "Mozilla/5.0 Firefox/140.0",
        "HTTP_COOKIE" => @cookies.map { |k, v| "#{k}=#{v}" }.join("; ")}
      options[:params] = params if params
      response = @rack.request(method, path, options)
      Array(response.headers["set-cookie"]).each do |cookie|
        key, value = cookie.split(";", 2).first.split("=", 2)
        @cookies[key] = value
      end
      response
    end

    def login(state)
      page = request("GET", "/session/new")
      raise "login page #{page.status}" unless page.status == 200
      token = page.body[/name="csrf-token" content="([^"]+)"/, 1] or raise "no CSRF"
      response = request("POST", "/session", JSON.parse(File.read(File.join(state, "login.json"))).merge(
        "authenticity_token" => CGI.unescapeHTML(token)))
      raise "natural login failed" unless response.status == 302 && @cookies.key?("session_token")
    end
  end

  def environment(name, app, state)
    settings = case name
    when "fizzy" then FizzyLinkFixture.environment(app, state)
    when "campfire-r81" then CampfireScenario.environment(app, state)
    when "lobsters"
      {"RAILS_ENV" => "production", "RACK_ENV" => "production",
        "DATABASE_URL" => "sqlite3:#{state}/primary.sqlite3", "RAILS_LOG_LEVEL" => "error"}
    else raise "unknown app"
    end
    settings.merge("LOWRAIL" => "0", "RUBYOPT" => nil, "RUBY_YJIT_ENABLE" => "1",
      "RUBY_ZJIT_ENABLE" => "0").each { |k, v| v ? ENV[k] = v : ENV.delete(k) }
  end

  def source_pin(app)
    git_root = IO.popen(["git", "-C", app, "rev-parse", "--show-toplevel"], &:read).strip
    files = IO.popen(["git", "-C", app, "ls-files", "--full-name", "-z"], &:read).split("\0")
    # ruby-bench is a monorepo; constrain the pin to this application's files.
    files = files.filter_map do |file|
      absolute = File.expand_path(file, git_root)
      absolute if absolute.start_with?(app + "/") && File.file?(absolute)
    end
    raise "empty source pin" if files.empty?
    Digest::SHA256.hexdigest(files.sort.map { [_1.delete_prefix(app + "/"), Digest::SHA256.file(_1).hexdigest] }.to_json)
  end

  def prepare_lobsters(app, state)
    raise "new state required" if File.exist?(state)
    FileUtils.mkdir_p(state, mode: 0o700)
    # ruby-bench ships its 41 MB benchmark database. Reuse that exact input,
    # not the historical MySQL schema (which SQLite correctly rejects).
    FileUtils.cp(File.join(app, "db/production.sqlite3"), File.join(state, "primary.sqlite3"))
    environment("lobsters", app, state)
    require File.join(app, "config/environment")
    puts JSON.generate(users: User.count, stories: Story.count, comments: Comment.count, tags: Tag.count)
  end

  def routes(name, state)
    case name
    when "fizzy"
      client = Client.new("fizzy.example.invalid")
      client.login(state)
      JSON.parse(File.read(File.join(state, "vector.json"))).to_h do |path|
        ["GET #{path}", -> { client.request("GET", path) }]
      end
    when "campfire-r81"
      driver = CampfireScenario::Driver.new(state, record: false, validate: false)
      driver.login
      %w[room pagination sidebar search post].to_h do |id|
        # Exercise the independent DOM/persistence/FTS oracle outside profiles.
        driver.run(id, validate: true)
        [id, -> { driver.run(id, validate: false) }]
      end
    when "lobsters"
      client = Client.new("localhost")
      story = Story.not_deleted.where(merged_story_id: nil).order(:id).first!
      ["/", "/newest", "/comments", "/u", "/s/#{story.short_id}", "/hottest"].to_h do |path|
        ["GET #{path}", -> { client.request("GET", path) }]
      end
    end
  end

  def jit
    RubyVM::YJIT.runtime_stats&.slice(:compiled_iseq_count, :compiled_block_count, :invalidation_count)
  end

  def gc
    GC.stat.slice(:total_allocated_objects, :minor_gc_count, :major_gc_count, :time,
      :heap_live_slots, :heap_allocated_pages)
  end

  # Charge native/internal leaves to their
  # nearest real Ruby caller at the sampled line, retaining the leaf name.
  # Aggregate before retaining the next route: interval-1 allocation stacks
  # are otherwise several GB. Original frame/edge/line counts remain intact.
  def compact(profile)
    frames, raw, lines = profile.values_at(:frames, :raw, :raw_lines)
    sites, index = Hash.new(0), 0
    while index < raw.size
      depth = raw.fetch(index)
      ids = raw.slice(index + 1, depth)
      stack = ids.map { frames.fetch(_1) }
      leaf = stack.last
      owner = (depth - 1).downto(0).find { |i| stack[i][:file].to_s.start_with?("/") } || depth - 1
      caller_frame = stack.fetch(owner)
      background = !stack.any? { _1[:name] == "LargeAppProfile.capture" }
      sites[[leaf[:name], caller_frame[:name], caller_frame[:file], lines.fetch(index + owner + 1), background]] += raw.fetch(index + depth + 1)
      index += depth + 2
    end
    raw_samples = sites.values.sum
    residual = profile.fetch(:samples) - raw_samples
    # StackProf can report a sample without a matching raw stack. Never
    # redistribute or discard that discrepancy (including its sign).
    sites[["<sampler residual>", "<sampler residual>", "", 0, nil]] = residual unless residual.zero?
    profile.except(:raw, :raw_lines, :raw_sample_timestamps, :raw_timestamp_deltas).merge(
      raw_samples: raw_samples, raw_report_residual: residual,
      self_sites: sites.map { |(leaf, owner, file, line, background), count|
        {leaf: leaf, owner: owner, file: file, line: line, background: background, samples: count} })
  end

  def capture(name, mode, app, state, output)
    raise "new output required" if File.exist?(output)
    raise "startup YJIT required" unless RubyVM::YJIT.enabled?
    environment(name, app, state)
    $LOAD_PATH.unshift(*ENV.fetch("LARGE_APP_STACKPROF_LOAD_PATH").split(File::PATH_SEPARATOR))
    require "stackprof"
    before_pin = source_pin(app)
    require File.join(app, "config/environment")
    raise "wrong stack" unless Rails.env.production? && Rails.version == "8.1.4" && RUBY_VERSION == "4.0.7" && RubyVM::YJIT.enabled?
    raise "Lowrail loaded" if defined?(Lowrail)
    report = {app: name, mode: mode, ruby: RUBY_DESCRIPTION, rails: Rails.version,
      app_sha: IO.popen(["git", "-C", app, "rev-parse", "HEAD"], &:read).strip,
      harness_sha: IO.popen(["git", "-C", ROOT, "rev-parse", "HEAD"], &:read).strip,
      harness_sha256: Digest::SHA256.file(File.join(ROOT, "bench/experiments/large_app_profile.rb")).hexdigest,
      app_source_sha256: before_pin,
      lock_sha256: Digest::SHA256.file(ENV.fetch("BUNDLE_GEMFILE") + ".lock").hexdigest,
      profiler: StackProf::VERSION, gc_measure_total_time: GC.measure_total_time,
      startup_yjit: true, lowrail_loaded: false, warmup_per_route: 100, routes: {}}
    routes(name, state).each do |id, request|
      checked = -> do
        response = request.call
        raise "#{id}: HTTP #{response.status}" unless response.status == 200
        response
      end
      100.times { checked.call }
      sample = checked.call
      raise "empty response #{id}" if sample.body.empty?
      entry = {status: sample.status, bytes: sample.body.bytesize, content_type: sample.media_type,
        yjit_before: jit, gc_before: gc}
      sample = nil
      if mode == "native"
        entry[:blocks] = 3.times.map do
          before = gc
          wall = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
          100.times { checked.call }
          cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - cpu
          wall = Process.clock_gettime(Process::CLOCK_MONOTONIC) - wall
          after = gc
          {requests: 100, wall_seconds: wall, cpu_seconds: cpu,
            gc_delta: before.to_h { |k, v| [k, after.fetch(k) - v] }}
        end
      else
        n = mode == "object" ? 30 : 200
        interval = mode == "object" ? 1 : 1000
        entry[:requests], entry[:interval] = n, interval
        entry[:profile] = compact(StackProf.run(mode: mode.to_sym, interval: interval, raw: true) { n.times { checked.call } })
        raise "empty profile #{id}" unless entry[:profile].fetch(:samples).positive?
      end
      entry[:gc_after], entry[:yjit_after] = gc, jit
      report[:routes][id] = entry
      puts JSON.generate(app: name, mode: mode, route: id, samples: entry.dig(:profile, :samples), bytes: entry[:bytes])
      $stdout.flush
    end
    report[:threads] = Thread.list.map { {name: _1.name, status: _1.status} }
    report[:source_unchanged] = before_pin == source_pin(app)
    raise "application source changed" unless report[:source_unchanged]
    File.write(output, JSON.generate(report) + "\n", perm: 0o600)
  end
end

if $PROGRAM_NAME == __FILE__
  name, mode, app, state, output = ARGV
  abort "usage: large_app_profile.rb APP_NAME native|cpu|wall|object|prepare APP STATE [NEW_JSON]" unless name && mode && app && state
  app, state = [app, state].map { File.expand_path(_1) }
  Dir.chdir(app) do
    mode == "prepare" ? LargeAppProfile.prepare_lobsters(app, state) : LargeAppProfile.capture(name, mode, app, state, output)
  end
end
