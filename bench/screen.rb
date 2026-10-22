# frozen_string_literal: true

require_relative "pass"

# A request-level screen over the existing fixed-heap counter, not another
# estimator or a native timing gate. All failures retain the complete cohort.
module ScreenPlatform
  ROOT = File.expand_path("..", __dir__)
  METRICS = %w[instructions_total instructions_no_gc allocations].freeze
  CONTROLS = METRICS.first(2).freeze
  module_function

  def summarize(rows)
    RequestPairs.summarize(rows, seed: 41231, tolerance: 0.1,
      zero_containment: false, metrics: METRICS, controls: CONTROLS)
  end

  def exact_report(workers)
    records = workers.flat_map do |label, worker|
      round, arm = label.split("-", 2)
      %w[exact exact_after].map { worker.merge("round" => "#{round}/#{_1}", "arm" => arm,
        "coverage" => false, "exact" => worker.fetch(_1)) }
    end
    exact = NativeScreen.exact_checks(records)
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
    raise "new output required; no retries" if File.exist?(output)
    app = config.fetch("app")
    raise "dedicated disposable corpus copy required" unless app.start_with?(File.join(ROOT, ".corpus/"))
    raise "output must be outside app" if output.start_with?(app + "/")
    raise "interpreter-only serial screen" unless JitStability.mode == "interpreter" && Integer(ENV.fetch("BENCH_JOBS", "1")) == 1
    raise "positive warmup/requests required" unless config.fetch("warmup").positive? && config.fetch("requests").positive?
    raise "storage seed must be outside disposable storage" if config["storage_seed"]&.start_with?(File.join(app, "storage"))
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
    files += [__FILE__, File.join(ROOT, "script/screen"), File.join(ROOT, "script/native-bench"), config_file, RbConfig.ruby]
    files += %w[gemfile exploration_setup entropy_policy].filter_map { config[_1] }
    files += [config.fetch("gemfile", File.join(app, "Gemfile")) + ".lock"]
    pins = files.select { File.file?(_1) }.uniq.sort.to_h { [_1, Digest::SHA256.file(_1).hexdigest] }
    File.write(File.join(output, "protocol.json"), JSON.pretty_generate(schema: 1, config: config,
      revision: IO.popen(["git", "-C", ROOT, "rev-parse", "HEAD"], &:read).strip,
      pins: pins, aa: "both 95% intervals wholly within ±0.1%; zero containment not required",
      rounds: 6, seed: 41231, retry: false, excluded: [], budget_only: budget))
    env = NativeBench.environment(config, config.fetch("seed", "")).merge(
      "RUBYOPT" => "-rbundler/setup -I#{lib} -rlowrail/setup", "BENCH_JIT" => "0",
      "BENCH_WARMUP" => config.fetch("warmup").to_s, "SCREEN_CONFIG" => config_file,
      "LOWRAIL_STATS" => nil, "BENCH_YJIT_LOG" => nil, "LOWRAIL_JIT_DIAGNOSTICS" => nil)
    arms = NativeBench::ARMS.to_h do |arm|
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
        elapsed_s: NativeBench.clock - config.fetch("screen_started")}
      File.write(File.join(output, "budget.json"), JSON.pretty_generate(report), perm: 0o600)
      puts "BUDGET exact=#{exact.fetch(:passed)} background=#{audit.fetch(:pass)}; coverage retained in budget.json"
      return exact.fetch(:passed) && audit.fetch(:pass)
    end
    metadata = {seed: 41231, rounds: 6, workers: {}}
    RequestPairs.heap_instructions(arms, app, output, config.fetch("paths").join(","), metadata,
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
    accepted = exact_pass && background_report.fetch(:pass) && unchanged &&
      per_route.values.all? { _1.fetch(:aa).fetch(:pass) } && controls.fetch("aa").fetch("pass") &&
      controls.fetch("heap_matched") && controls.fetch("jit").fetch("pass") &&
      workers.values.all? { _1.fetch("refusal").nil? }
    result = {schema: 1, accepted: accepted, exact_pass: exact_pass, exact: exact, per_route: per_route,
      background: background_report, source_unchanged: unchanged, controls: controls,
      retry: false, excluded: [], workers: workers, elapsed_s: NativeBench.clock - config.fetch("screen_started"),
      elapsed_scope: "interpreter work, not latency or app admission"}
    File.write(File.join(output, "result.json"), JSON.pretty_generate(result), perm: 0o600)
    per_route.each do |route, summary|
      puts "#{route}: #{JSON.generate(summary.reject { |key, _| key == :samples })}"
    end
    puts "SCREEN #{accepted ? 'ACCEPTED' : 'REJECTED; retained'}; exact=#{exact_pass}; background=#{background_report.fetch(:pass)}"
    accepted
  end
end
