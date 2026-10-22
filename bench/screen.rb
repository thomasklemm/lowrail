# frozen_string_literal: true

require_relative "pass"

# A request-level screen over the existing fixed-heap counter, not another
# estimator or a native timing gate. All failures retain the complete cohort.
module ScreenPlatform
  ROOT = File.expand_path("..", __dir__)
  ARMS = %w[off_a off_b on].freeze
  METRICS = %w[instructions_total instructions_no_gc allocations].freeze
  CONTROLS = METRICS.first(2).freeze
  module_function

  def clock = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  # Reuse the native screen's corpus adapters, not its YJIT/wall acceptance.
  def environment(config, state)
    app = config.fetch("app")
    specific = case config.fetch("workload")
    when "campfire"
      raise "acknowledge dedicated disposable Redis with CAMPFIRE_DISPOSABLE_REDIS=1" unless ENV["CAMPFIRE_DISPOSABLE_REDIS"] == "1"
      require_relative "experiments/campfire_scenario"
      CampfireScenario.environment(app, state)
    when "fizzy"
      require_relative "experiments/fizzy_link_fixture"
      FizzyLinkFixture.environment(app, state)
    when "generic"
      {} # Keep the app's own database configuration.
    when "blog"
      {"SECRET_KEY_BASE_DUMMY" => config["fixture_secret_key_base"] ? nil : "1",
        "SECRET_KEY_BASE" => config["fixture_secret_key_base"], "RAILS_LOG_LEVEL" => "fatal"}
    else raise "unknown workload"
    end
    # Both off arms preload the same runtime; only activation differs.
    clean = ENV.keys.grep(/\A(?:LOWRAIL|RUBYOPT|RUBY_|BUNDLE_|RAILS_|RACK_ENV|DATABASE_URL|.*_DATABASE_URL)/).to_h { [_1, nil] }
    clean.merge(specific).merge("RAILS_ENV" => "production", "RACK_ENV" => "production",
      "BUNDLE_GEMFILE" => config.fetch("gemfile", File.join(app, "Gemfile")), "BUNDLE_FROZEN" => "true",
      "RUBY_YJIT_ENABLE" => nil, "RUBY_ZJIT_ENABLE" => nil, "LOWRAIL_SEALED" => "1",
      "LOWRAIL_ROOT" => app, "LOWRAIL_DIR" => config.fetch("artifact"),
      "RUBYOPT" => "-rbundler/setup -I#{ROOT}/gem/lib -rlowrail/setup")
  end

  def routes(config)
    state = config.fetch("seed", "")
    case config.fetch("workload")
    when "blog", "generic"
      require "rack/mock"
      rack = Rack::MockRequest.new(Rails.application)
      headers = {"HTTP_HOST" => "localhost", "HTTPS" => "on"}.merge(config.fetch("headers", {}))
      config.fetch("paths").to_h do |path|
        ["GET #{path}", -> { rack.get(path, headers) }]
      end
    when "campfire"
      require_relative "experiments/campfire_scenario"
      driver = CampfireScenario::Driver.new(state, record: false, validate: false)
      driver.login
      driver.prepare_post
      vector = JSON.parse(File.read(File.join(state, "scenario.json"))).fetch("vector")
      config.fetch("paths").to_h do |path|
        route = vector.find { _1.fetch("id") == path || _1.fetch("path") == path } or raise "unknown Campfire route #{path}"
        id = route.fetch("id")
        [id, -> { driver.run(id) }]
      end
    when "fizzy"
      require_relative "experiments/fizzy_link_vector"
      driver = FizzyLinkVector::Driver.new(state, record: false)
      driver.login
      config.fetch("paths").to_h do |path|
        ["GET #{path}", -> { driver.request("GET", path) }]
      end
    end
  end

  def counts
    if defined?(Exploration) && Exploration.respond_to?(:counts)
      JSON.parse(JSON.generate(Exploration.counts))
    elsif defined?(BlockLinkSpecimen) && BlockLinkSpecimen.counts
      JSON.parse(JSON.generate(BlockLinkSpecimen.counts))
    elsif defined?(Lowrail::Stats) && Lowrail::Stats.enabled?
      {"hits" => Lowrail::Stats.unit_hits.dup, "fallbacks" => Lowrail::Stats.unit_fallbacks.dup}
    end
  end

  def response_digest(response)
    {"status" => response.status, "body_sha256" => Digest::SHA256.hexdigest(response.body),
      "headers_sha256" => Digest::SHA256.hexdigest(JSON.generate(response.headers.to_h.sort.to_h))}
  end

  def summarize(rows)
    result = RequestPairs.summarize(rows, seed: 41231, tolerance: 0.1,
      zero_containment: false, metrics: METRICS, controls: CONTROLS)
    result.fetch(:layers).each do |arm, metrics|
      metrics.each do |metric, estimates|
        estimates[:delta] = RequestPairs.estimate(rows.map { _1.fetch(arm).fetch(metric) - _1.fetch("off_a").fetch(metric) }, seed: 41231)
      end
    end
    result
  end

  def exact_report(workers)
    records = workers.flat_map do |label, worker|
      round, arm = label.split("-", 2)
      %w[exact exact_after].map { worker.merge("round" => "#{round}/#{_1}", "arm" => arm,
        "coverage" => false, "exact" => worker.fetch(_1)) }
    end
    exact = records.first.fetch("exact").keys.to_h do |route|
      [route, [0, 1].to_h do |seed|
        rows = records.map { _1.fetch("exact").fetch(route).fetch(seed.to_s) }
        fields = %w[status body_sha256 headers_sha256]
        controls_pass = rows.all? { _1.fetch("evidence").fetch("passed") == true }
        pairs = records.group_by { _1.fetch("round") }.values.map do |round|
          arms = round.to_h { [_1.fetch("arm"), _1.fetch("exact").fetch(route).fetch(seed.to_s)] }
          %w[off_b on].to_h { |arm| [arm, fields.to_h { |field| [field, arms.fetch("off_a").fetch(field) == arms.fetch(arm).fetch(field)] }] }
        end
        [seed.to_s, {"passed" => controls_pass && pairs.all? { _1.values.all? { |checks| checks.values.all? } },
          "controls_pass" => controls_pass, "round_checks" => pairs}]
      end]
    end
    fields = ->(record) { record.transform_values { |seeds| seeds.transform_values { _1.slice("status", "body_sha256", "headers_sha256") } } }
    passed = exact.values.all? { _1.values.all? { |seed| seed.fetch("passed") } } &&
      workers.values.all? { fields.call(_1.fetch("exact")) == fields.call(_1.fetch("exact_after")) }
    {passed: passed, responses: exact}
  end

  def background(workers)
    groups = workers.flat_map do |label, worker|
      round, arm = label.split("-", 2)
      worker.fetch("windows").map do |window|
        [[round, window.fetch("unit"), window.fetch("mode"), window.fetch("requests")],
          [arm, window.fetch("background")]]
      end
    end.group_by(&:first)
    comparisons = groups.map do |key, entries|
      arms = entries.to_h { |_, pair| pair }
      snapshots = arms.values.flat_map { [_1.fetch("cache_before"), _1.fetch("cache_after")] }
      signature = ->(row) { row.slice("events", "lazy_loads", "gc") }
      changed = arms.values.any? { _1.fetch("cache_before") != _1.fetch("cache_after") }
      loads = arms.values.any? { !_1.fetch("lazy_loads").empty? }
      regeneration = arms.values.any? { _1.fetch("events").keys.any? { |event| event.match?(/cache_(?:generate|write|delete|clear)|connection_pool\./) } }
      {window: key, comparable: arms.size == 3 && arms.values.map(&signature).uniq.size == 1 &&
        snapshots.uniq.size == 1 && snapshots.none? { _1.key?("unavailable") } && !changed && !loads && !regeneration,
        cache_changed: changed, lazy_loads: loads, regeneration_or_reaper: regeneration,
        byte_state_available: snapshots.all? { !_1.key?("unavailable") }, arms: arms}
    end
    {pass: comparisons.all? { _1.fetch(:comparable) }, comparisons: comparisons}
  end

  # Native signatures from the actual counted windows, not traced companions.
  # Inclusive call counts are diagnostics, never subtracted from the price.
  def dump_signatures(path)
    functions, callee, counts = {}, nil, Hash.new(0)
    File.foreach(path) do |line|
      if (match = line.match(/\A(?:c?fn)=\((\d+)\)(?: (.*))?/))
        id, name = match.captures
        functions[id] = name if name
        callee = functions[id] if line.start_with?("cfn=")
      elsif line.start_with?("calls=") && callee&.match?(/marshal_dump|rb_deflate_s_deflate|io_binwrite|rb_file_s_rename|rb_require_string|rb_f_load/)
        counts[callee] += Integer(line.delete_prefix("calls=").split.first)
      end
    end
    counts
  end

  def run(config, output, budget: false)
    raise "new output required; no retries" if File.exist?(output) || File.symlink?(output)
    # Resolve existing parents even when several output components are new.
    parent, suffix = File.expand_path(output), []
    until File.exist?(parent) || File.symlink?(parent)
      suffix.unshift(File.basename(parent))
      parent = File.dirname(parent)
    end
    output = File.join(File.realpath(parent), *suffix)
    app = config["app"] = File.realpath(config.fetch("app"))
    raise "dedicated disposable corpus copy required" unless app.start_with?(File.join(ROOT, ".corpus/"))
    raise "output must be outside app" if output.start_with?(app + "/")
    raise "interpreter-only serial screen" unless JitStability.mode == "interpreter" && Integer(ENV.fetch("BENCH_JOBS", "1")) == 1
    raise "positive warmup/requests required" unless config.fetch("warmup").positive? && config.fetch("requests").positive?
    %w[artifact lib seed storage_seed gemfile exploration_setup entropy_policy].each do |key|
      config[key] = File.realpath(config.fetch(key)) if config[key]
    end
    if (seed = config["storage_seed"])
      storage = File.join(app, "storage")
      storage = File.realpath(storage) if File.exist?(storage)
      raise "storage seed directory required" unless File.directory?(seed)
      if seed == storage || seed.start_with?(storage + "/") || storage.start_with?(seed + "/")
        raise "storage seed must not overlap disposable storage"
      end
    end
    %w[seed storage_seed].each do |key|
      seed = config[key]
      raise "output must be outside seed directories" if seed && (output == seed || output.start_with?(seed + "/"))
    end
    raise "integer epoch required" if config["epoch"] && !config.fetch("epoch").is_a?(Integer)
    if config["epoch"] && config["entropy_policy"]
      companion_clock = JSON.parse(File.read(config.fetch("entropy_policy")))["wall_clock"]
      raise "fixed epoch differs from entropy companion epoch" if companion_clock && config.fetch("epoch") != companion_clock.fetch("epoch")
    end
    ENV["BENCH_JOBS"] = "1"
    ENV["RAILS_ENV"] = "production"
    ENV["LOWRAIL_SEALED"] = "1"
    lib = config.fetch("lib", File.join(ROOT, "gem/lib"))
    PassBench.preflight(config.fetch("artifact"), lib, root: app)
    manifest = JSON.parse(File.read(File.join(config.fetch("artifact"), "manifest.json")))
    raise "interpreter artifact required" unless manifest.fetch("certification_jit") == "interpreter"
    FileUtils.mkdir_p(output, mode: 0o700)
    config_file = File.join(output, "config.json")
    File.write(config_file, JSON.pretty_generate(config), perm: 0o600)
    files = Dir[File.join(ROOT, "{bench,gem/lib,fixtures}/**/*.{rb,so,json}"), File.join(app, "{app,config,db,lib}/**/*")]
    files += Dir[File.join(config.fetch("artifact"), "**/*")]
    files += Dir[File.join(config["storage_seed"], "**/*")] if config["storage_seed"]
    files += Dir[File.join(config["seed"], "**/*")] if config["seed"]
    files += [__FILE__, File.join(ROOT, "script/screen"), config_file, RbConfig.ruby]
    files += %w[gemfile exploration_setup entropy_policy].filter_map { config[_1] }
    files += [config.fetch("gemfile", File.join(app, "Gemfile")) + ".lock"]
    pins = files.select { File.file?(_1) }.uniq.sort.to_h { [_1, Digest::SHA256.file(_1).hexdigest] }
    File.write(File.join(output, "protocol.json"), JSON.pretty_generate(schema: 1, config: config,
      revision: IO.popen(["git", "-C", ROOT, "rev-parse", "HEAD"], &:read).strip,
      pins: pins, aa: "both 95% intervals wholly within ±0.1%; zero containment not required",
      rounds: 6, seed: 41231, retry: false, excluded: [], budget_only: budget))
    env = environment(config, config.fetch("seed", "")).merge(
      "RUBYOPT" => "-rbundler/setup -I#{lib} -rlowrail/setup", "BENCH_JIT" => "0",
      "BENCH_WARMUP" => config.fetch("warmup").to_s, "SCREEN_CONFIG" => config_file,
      "LOWRAIL_STATS" => nil, "BENCH_YJIT_LOG" => nil, "LOWRAIL_JIT_DIAGNOSTICS" => nil)
    arms = ARMS.to_h do |arm|
      [arm, env.merge("LOWRAIL" => arm == "on" ? "1" : "0", "SCREEN_ARM" => arm)]
    end
    worker = File.join(__dir__, "screen_worker.rb")
    if budget
      extension = RequestPairs.compile_counter_extension(output)
      floors = HeapWindows.floors.each_with_index.to_h { |n, i| ["RUBY_GC_HEAP_#{i}_INIT_SLOTS", n.to_s] }
      workers = {}
      arms.each do |arm, settings|
        ok = system(settings.merge(floors).merge("BENCH_CALLGRIND_EXTENSION" => extension,
          "SCREEN_COVERAGE" => "1", "LOWRAIL_STATS" => "1",
          "BENCH_REQUESTS" => config.fetch("requests").to_s), "valgrind", "--tool=none", RbConfig.ruby,
          *JitStability.flags("0"), worker, chdir: app, out: File.join(output, "#{arm}.log"), err: [:child, :out])
        raise "untimed budget failed: #{arm}" unless ok
        line = File.foreach(File.join(output, "#{arm}.log")).find { _1.start_with?("LOWRAIL_BENCH ") }
        workers["budget-#{arm}"] = JSON.parse(line.delete_prefix("LOWRAIL_BENCH "))
      end
      exact = exact_report(workers)
      audit = background(workers)
      report = {kind: "untimed tool=none, not instruction counts", exact: exact, background: audit, workers: workers,
        elapsed_s: clock - config.fetch("screen_started")}
      File.write(File.join(output, "budget.json"), JSON.pretty_generate(report), perm: 0o600)
      puts "BUDGET exact=#{exact.fetch(:passed)} background=#{audit.fetch(:pass)}; coverage retained in budget.json"
      return exact.fetch(:passed) && audit.fetch(:pass)
    end
    metadata = {seed: 41231, rounds: 6, workers: {}}
    counter_pass = RequestPairs.heap_instructions(arms, app, output, config.fetch("paths").join(","), metadata,
      worker: worker, requests: config.fetch("requests"), aa_tolerance: 0.1, aa_zero_containment: false)
    data = JSON.parse(File.read(File.join(output, "samples.json")))
    workers = data.fetch("workers")
    exact = exact_report(workers)
    exact_pass = exact.fetch(:passed)
    per_route = workers.values.first.fetch("windows").map { _1.fetch("unit") }.uniq.to_h do |route|
      rows = data.fetch("samples").map do |round|
        round.to_h do |arm, metrics|
          full, empty = metrics.fetch("windows").select { _1.fetch("unit") == route && _1.fetch("mode") == "total" }.sort_by { -_1.fetch("requests") }
          allocated = ->(window) { window.fetch("after").fetch("total_allocated_objects") - window.fetch("before").fetch("total_allocated_objects") }
          [arm, metrics.fetch("operations").fetch(route).merge("allocations" => (allocated.call(full) - allocated.call(empty)).fdiv(config.fetch("requests")))]
        end
      end
      [route, summarize(rows).merge(samples: rows)]
    end
    workers.each do |label, record|
      record.fetch("windows").each_with_index do |window, index|
        window["native_signatures"] = dump_signatures(File.join(output, "#{label}.callgrind.#{index + 1}"))
      end
    end
    background_report = background(workers)
    controls = JSON.parse(File.read(File.join(output, "summary.json")))
    unchanged = pins.all? { |path, sha| Digest::SHA256.file(path).hexdigest == sha }
    accepted = counter_pass && exact_pass && background_report.fetch(:pass) && unchanged &&
      per_route.values.all? { _1.fetch(:aa).fetch(:pass) } &&
      workers.values.all? { _1.fetch("refusal").nil? }
    result = {schema: 1, accepted: accepted, exact_pass: exact_pass, exact: exact, per_route: per_route,
      background: background_report, source_unchanged: unchanged, controls: controls, counter_pass: counter_pass,
      retry: false, excluded: [], workers: workers, elapsed_s: clock - config.fetch("screen_started"),
      elapsed_scope: "interpreter work, not latency or app admission"}
    File.write(File.join(output, "result.json"), JSON.pretty_generate(result), perm: 0o600)
    per_route.each do |route, summary|
      puts "#{route}: #{JSON.generate(summary.reject { |key, _| key == :samples })}"
    end
    puts "SCREEN #{accepted ? 'ACCEPTED' : 'REJECTED; retained'}; exact=#{exact_pass}; background=#{background_report.fetch(:pass)}"
    accepted
  end
end
