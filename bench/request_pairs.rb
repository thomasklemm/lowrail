# frozen_string_literal: true

# Sequential short blocks in separate warm Ruby/YJIT processes. No app edits,
# no shared Ruby heap, and no boot/profiler/counter time in the measurements.
# ruby bench/request_pairs.rb APP OUTDIR GET:/path
require "json"
require "fileutils"
require "tmpdir"
require_relative "jit_stability"
require_relative "heap_windows"
require "open3"
require "rbconfig"
require "digest"
require "shellwords"

module RequestPairs
  METRICS = %w[cpu_us wall_us allocations].freeze

  def self.median(values)
    sorted = values.sort
    middle = sorted.size / 2
    sorted.size.odd? ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2.0
  end

  # Resample whole rounds, not requests: all measurements in a round share
  # environmental noise. Percent changes are medians of paired round ratios.
  def self.estimate(values, seed:, bootstrap: 5000)
    rng = Random.new(seed)
    draws = Array.new(bootstrap) { median(Array.new(values.size) { values[rng.rand(values.size)] }) }.sort
    { median: median(values), ci95: [draws[(bootstrap * 0.025).floor], draws[(bootstrap * 0.975).floor]] }
  end

  def self.summarize(rounds, seed:, tolerance:, cohorts: nil, metrics: METRICS, controls: %w[cpu_us wall_us])
    layers = rounds.first.keys
    result = layers.to_h do |layer|
      estimates = metrics.to_h do |metric|
        absolute = rounds.map { _1.fetch(layer).fetch(metric) }
        # Zero-allocation operations have an absolute count but no defined
        # percentage change. Keep JSON finite instead of emitting 0/0.
        relative = rounds.all? { _1.fetch("off_a").fetch(metric).positive? }
        delta = rounds.map { 100 * (_1.fetch(layer).fetch(metric).fdiv(_1.fetch("off_a").fetch(metric)) - 1) } if relative
        if cohorts
          absolute = cohorts.map { |rows| median(rows.map { _1.fetch(layer).fetch(metric) }) }
          delta = cohorts.map do |rows|
            median(rows.map { 100 * (_1.fetch(layer).fetch(metric).fdiv(_1.fetch("off_a").fetch(metric)) - 1) })
          end if relative
        end
        [metric, { value: estimate(absolute, seed: seed), delta_pct: delta && estimate(delta, seed: seed) }]
      end
      [layer, estimates]
    end
    controls = controls.to_h do |metric|
      interval = result.fetch("off_b").fetch(metric).fetch(:delta_pct)&.fetch(:ci95)
      low, high = interval
      [metric, !!(interval && low <= 0 && high >= 0 && low >= -tolerance && high <= tolerance)]
    end
    { layers: result, aa: { pass: controls.values.all?, metrics: controls, tolerance_pct: tolerance } }
  end

  # Independently booted cohorts account for process-specific JIT/heap state.
  # Do not bootstrap hundreds of blocks from one process as if they were
  # hundreds of independent boots. Keep failed controls, never retry to green.
  def self.experiment(app, out, route)
    return run(app, out, route) if %w[callgrind gc].include?(ENV["BENCH_COUNTER"])
    count = Integer(ENV.fetch("BENCH_COHORTS", "5"))
    return run(app, out, route) if count == 1
    raise "at least 5 independent cohorts required" if count < 5
    out = File.expand_path(out)
    raise "output directory must be new" if File.exist?(out)
    FileUtils.mkdir_p(out, mode: 0o700)
    seed = Integer(ENV.fetch("BENCH_SEED", "41231"))
    cohorts = count.times.map do |i|
      dir = File.join(out, "cohort-#{i}")
      env = { "BENCH_COHORTS" => "1", "BENCH_SEED" => (seed + i).to_s,
        "BENCH_PROFILES" => i.zero? ? ENV["BENCH_PROFILES"] : nil }
      system(env, RbConfig.ruby, __FILE__, app, dir, route, out: File.join(out, "cohort-#{i}.log"), err: [:child, :out])
      raise "cohort #{i} failed; inspect logs" unless [0, 2].include?($?.exitstatus)
      warn "cohort #{i + 1}/#{count} (control exit=#{$?.exitstatus})"
      JSON.parse(File.read(File.join(dir, "samples.json")))
    end
    rows = cohorts.map { _1.fetch("samples") }
    summary = summarize(rows.flatten, seed: seed, tolerance: Float(ENV.fetch("BENCH_AA_TOLERANCE", "2")), cohorts: rows)
    File.write(File.join(out, "samples.json"), JSON.pretty_generate(cohorts: cohorts))
    File.write(File.join(out, "summary.json"), JSON.pretty_generate(summary))
    puts JSON.pretty_generate(summary)
    summary.fetch(:aa).fetch(:pass)
  end

  def self.run(app, out, route)
    app, out = [app, out].map { File.expand_path(_1) }
    raise "output directory must be new" if File.exist?(out)
    FileUtils.mkdir_p(out, mode: 0o700)
    seed = Integer(ENV.fetch("BENCH_SEED", "41231"))
    counter = ENV["BENCH_COUNTER"] == "callgrind"
    diagnostic = ENV["BENCH_COUNTER"] == "gc"
    fixed_heap = counter && ENV["BENCH_HEAP_MODE"] != "legacy"
    raise "ZJIT diagnostics require fixed-heap Callgrind" if JitStability.mode == "zjit" && !fixed_heap
    minimum = fixed_heap ? 6 : (counter || diagnostic ? 3 : 8)
    rounds = Integer(ENV.fetch("BENCH_ROUNDS", minimum.to_s))
    raise "too few rounds" if rounds < minimum
    root = File.expand_path("..", __dir__)
    lib = File.expand_path(ENV.fetch("BENCH_LOWRAIL_LIB", File.join(root, "gem/lib")))
    workers = {}
    environments = {}
    samples = []
    Dir.mktmpdir("lowrail-request-pairs") do |tmp|
      # Snapshot complete artifacts, not the app root: format-2 certificates
      # still resolve against the real app. Never hide/rename the app's build.
      normal = File.join(tmp, "normal")
      FileUtils.mkdir_p(normal)
      FileUtils.cp_r(File.join(app, ".lowrail"), normal)
      source = File.join(normal, ".lowrail/manifest.json")
      data = JSON.parse(File.read(source))
      raise "production build required" unless data.fetch("rails_env") == "production"
      empty = File.join(tmp, "empty")
      FileUtils.mkdir_p(File.join(empty, ".lowrail"))
      # Removed units/files also remove their relocation-pointer targets.
      File.write(File.join(empty, ".lowrail/manifest.json"), JSON.generate(data.merge(
        "files" => {}, "templates" => {}, "units" => [], "app_paths" => {"values" => [], "keys" => []})))
      missing = File.join(tmp, "missing")
      FileUtils.mkdir_p(missing)
      layers = { "off_a" => nil, "off_b" => nil, "missing" => missing, "empty" => empty,
                 "disabled" => normal, "default" => normal }
      # A stack needs an actual default-only build, not a guard mask over
      # optional emitted sites or installed method variants.
      if (reference = ENV["BENCH_DEFAULT_DIR"])
        raise "stacked reference cannot combine with other comparison layers" if
          %w[BENCH_BASELINE_LIB BENCH_INSTANTIATE_DIR BENCH_VARIANT_APP].any? { ENV[_1] }
        layers["default"] = File.join(tmp, "default")
        FileUtils.mkdir_p(layers["default"])
        FileUtils.cp_r(File.expand_path(reference), File.join(layers["default"], ".lowrail"))
        layers["stacked"] = normal
      end
      if (speculative = ENV["BENCH_SPECULATIVE_DIR"])
        raise "unsafe comparison requires fixed-heap Callgrind and no other comparison layers" unless fixed_heap &&
          !reference && %w[BENCH_BASELINE_LIB BENCH_INSTANTIATE_DIR BENCH_VARIANT_APP].none? { ENV[_1] }
        layers["unguarded"] = File.join(tmp, "unguarded")
        FileUtils.mkdir_p(layers["unguarded"])
        FileUtils.cp_r(File.expand_path(speculative), File.join(layers["unguarded"], ".lowrail"))
      end
      # A runtime-only refactor uses the exact same build in a same-round
      # before worker, rather than comparing two unrelated off baselines.
      if (baseline = ENV["BENCH_BASELINE_LIB"])
        raise "runtime comparison requires fixed-heap Callgrind" unless fixed_heap
        raise "runtime comparison needs a source-only build" if data.fetch("units").any? { _1["kind"] == "runtime" || _1["kind"] == "method" }
        baseline = File.expand_path(baseline)
        layers["before"] = normal
      end
      # Compare an upstream app fix with the same independent A/A workers and
      # measurement seam. This layer never loads Lowrail or the original build.
      variant = File.expand_path(ENV["BENCH_VARIANT_APP"]) if ENV["BENCH_VARIANT_APP"]
      layers["app_fix"] = nil if variant
      if (extra = ENV["BENCH_INSTANTIATE_DIR"])
        extra = File.expand_path(extra)
        extra_data = JSON.parse(File.read(File.join(extra, "manifest.json")))
        raise "production +ar_instantiate build required" unless extra_data["rails_env"] == "production" &&
          extra_data.fetch("units").any? { _1["pass"] == "active_record/instantiate" }
        certificates = extra_data.fetch("units").select { _1["pass"] == "active_record/instantiate" }
        raise "AR build sources changed; rebuild before measuring" unless certificates.all? do |unit|
          unit.fetch("ar_instantiate").fetch("sources").all? do |path, sha|
            # A library override must match the certificate too, not merely
            # the checkout whose absolute paths the builder recorded.
            path = File.expand_path(path, app)
            actual = path.start_with?("#{root}/gem/lib/") ? File.join(lib, path.delete_prefix("#{root}/gem/lib/")) : path
            [path, actual].uniq.all? { File.file?(_1) && Digest::SHA256.file(_1).hexdigest == sha }
          end
        end
        layers["instantiate"] = File.join(tmp, "instantiate")
        FileUtils.mkdir_p(layers["instantiate"])
        FileUtils.cp_r(extra, File.join(layers["instantiate"], ".lowrail"))
      end
      metadata = { seed: seed, rounds: rounds, route: route, app: File.basename(app),
        manifest_sha256: Digest::SHA256.file(source).hexdigest,
        cache_mb: ENV["CAMPFIRE_RESPONSE_CACHE_MB"], variant_app: variant, workers: {} }
      if reference
        metadata[:default_manifest_sha256] = Digest::SHA256.file(File.join(layers.fetch("default"), ".lowrail/manifest.json")).hexdigest
      end
      metadata[:unsafe_manifest_sha256] = Digest::SHA256.file(File.join(speculative, "manifest.json")).hexdigest if speculative
      metadata[:runtime_sha256] = Digest::SHA256.file(File.join(lib, "lowrail.rb")).hexdigest
      metadata[:runtime_files_sha256] = Dir.glob(File.join(lib, "**/*.rb")).sort.to_h do |path|
        [path.delete_prefix(lib + "/"), Digest::SHA256.file(path).hexdigest]
      end
      if baseline
        metadata[:baseline_runtime_files_sha256] = Dir.glob(File.join(baseline, "**/*.rb")).sort.to_h do |path|
          [path.delete_prefix(baseline + "/"), Digest::SHA256.file(path).hexdigest]
        end
      end
      layers.each do |layer, build_root|
        runtime_lib = layer == "before" ? baseline : lib
        env = { "RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "RAILS_LOG_LEVEL" => "error",
          "LOWRAIL" => build_root ? "1" : "0", "LOWRAIL_ROOT" => app,
          "LOWRAIL_DIR" => build_root && File.join(build_root, ".lowrail"),
          "LOWRAIL_UNITS" => layer == "disabled" ? "" :
            ((%w[stacked unguarded].include?(layer) || (layer == "default" && !reference)) ? ENV["BENCH_UNITS"] : nil),
          "LOWRAIL_STATS" => nil, "LOWRAIL_OUTCOMES" => nil, "LOWRAIL_DEBUG" => nil,
          "LOWRAIL_SHADOW" => nil,
          "LOWRAIL_SPECULATE" => layer == "unguarded" ? "unguarded" : nil, "LOWRAIL_SPECULATE_KEEP" => nil,
          "RUBYOPT" => build_root ? "-I#{runtime_lib} -rlowrail/setup" : nil,
          "BENCH_PIPE" => counter || diagnostic ? nil : "1",
          "BENCH_WARMUP" => ENV.fetch("BENCH_WARMUP", counter || diagnostic ? "50" : "400"),
          "BENCH_JSON" => nil, "BENCH_PROFILE" => nil, "BENCH_DUMP" => nil }
        env["BENCH_WORKDIR"] = layer == "app_fix" ? variant : app
        environments[layer] = env
        next if counter || diagnostic
        stdin, stdout, wait = Open3.popen2e(env, RbConfig.ruby, "--yjit", File.join(__dir__, "requests.rb"), route, chdir: env.fetch("BENCH_WORKDIR"))
        workers[layer] = { stdin: stdin, stdout: stdout, wait: wait, log: File.open(File.join(out, "#{layer}.log"), "w") }
        metadata[:workers][layer] = receive(workers.fetch(layer))
        raise "AR build did not activate" if layer == "instantiate" && metadata[:workers][layer].fetch("ar_installed").zero?
        warn "warm #{File.basename(app)} #{layer}"
      end
      return heap_instructions(environments, app, out, route, metadata) if fixed_heap
      return instructions(environments, app, out, route, metadata) if counter
      return diagnostics(environments, app, out, route, metadata) if diagnostic
      # One fixed request count for every layer, calibrated to baseline CPU
      # time. CPU time is primary; wall time exposes scheduling/IO delays.
      calibration = command(workers.fetch("off_a"), requests: 100)
      n = [(Float(ENV.fetch("BENCH_SECONDS", "0.5")) * 1e6 / calibration.fetch("cpu_us")).ceil, 10].max
      metadata[:requests_per_block] = n
      # Extra untimed blocks heat the same code in every process.
      workers.each_value { |worker| 2.times { command(worker, requests: n) } }
      rng = Random.new(seed)
      order = workers.keys.shuffle(random: rng)
      rounds.times do |round|
        rotated = order.rotate(round % order.size)
        rotated = rotated.reverse if (round / order.size).odd?
        row = {}
        rotated.each { |layer| row[layer] = command(workers.fetch(layer), requests: n) }
        samples << row
        File.write(File.join(out, "samples.json"), JSON.pretty_generate(metadata.merge(samples: samples)))
        warn "round #{round + 1}/#{rounds}"
      end
      summary = summarize(samples, seed: seed, tolerance: Float(ENV.fetch("BENCH_AA_TOLERANCE", "2")))
      File.write(File.join(out, "summary.json"), JSON.pretty_generate(summary))
      if ENV["BENCH_PROFILES"] == "1"
        workers.each do |layer, worker|
          %w[cpu object].each do |mode|
            command(worker, requests: mode == "cpu" ? n * 8 : 100, profile: mode,
              output: File.join(out, "#{layer}-#{mode}.json"))
          end
          trace = command(worker, requests: 100, trace: true)
          File.write(File.join(out, "#{layer}-trace.json"), JSON.pretty_generate(trace))
        end
      end
      puts JSON.pretty_generate(summary)
      return summary.fetch(:aa).fetch(:pass)
    end
  ensure
    workers&.each_value do |worker|
      worker[:stdin].close
      worker[:stdout].each_line { worker[:log].write(_1) }
      worker[:stdout].close
      worker[:log].close
      raise "benchmark worker failed" unless worker[:wait].value.success?
    end
  end

  def self.compile_counter_extension(out)
    extension = File.join(out, "lowrail_callgrind.#{RbConfig::CONFIG.fetch("DLEXT")}")
    cc = RbConfig::CONFIG.fetch("LDSHARED").shellsplit
    raise "could not compile Callgrind client requests" unless system(*cc, "-fPIC", "-O2",
      "-I#{RbConfig::CONFIG.fetch("rubyhdrdir")}", "-I#{RbConfig::CONFIG.fetch("rubyarchhdrdir")}",
      File.join(__dir__, "callgrind.c"), "-o", extension)
    extension
  end

  def self.instruction_total(path)
    # Valgrind 3.19 can wrap the summary after ZERO_STATS/multiple dumps.
    # The trailing totals still agree with the sum of all self-cost rows.
    line = File.foreach(path).find { _1.start_with?("totals: ") }
    raise "missing Callgrind totals: #{path}" unless line
    Integer(line.split.fetch(1))
  end

  def self.check_valgrind_log!(out, label)
    path = File.join(out, "#{label}.valgrind.log")
    return unless File.read(path).match?(/brk segment overflow|Cannot map memory to grow brk segment/)
    File.write(File.join(out, "valgrind-rejected.json"), JSON.pretty_generate(
      accepted: false, reason: "Valgrind brk reservation exhausted", worker: label,
      log_sha256: Digest::SHA256.file(path).hexdigest))
    raise "Valgrind brk reservation exhausted: #{label}; cohort rejected, inspect #{path}; use script/bench-valgrind"
  end

  def self.valgrind_preflight(out, floors, app:, env:)
    floors = HeapWindows.floors.each_with_index.to_h { |n, pool| ["RUBY_GC_HEAP_#{pool}_INIT_SLOTS", n.to_s] }.merge(floors)
    executable = ENV.fetch("PATH").split(File::PATH_SEPARATOR).map { File.join(_1, "valgrind") }.find { File.executable?(_1) }
    raise "Valgrind not found; use script/bench-valgrind" unless executable
    executable = File.realpath(executable)
    prefix = File.expand_path("..", File.dirname(executable))
    manifest = File.join(prefix, "share/lowrail/valgrind.json")
    build = JSON.parse(File.read(manifest)) if File.file?(manifest)
    if build
      tool = File.join(prefix, build.fetch("tool"))
      raise "pinned Valgrind binary changed" unless Digest::SHA256.file(tool).hexdigest == build.fetch("tool_sha256")
    end
    version, status = Open3.capture2(executable, "--version")
    raise "Valgrind version check failed" unless status.success?
    rails_boot = File.file?(File.join(app, "config/application.rb"))
    program = <<~'RUBY'
      if ARGV.first == "rails"
        require File.expand_path("config/application", Dir.pwd)
        Rails.application.config.yjit = false
        require File.expand_path("config/environment", Dir.pwd)
        Rails.application.eager_load!
      end
      require ARGV.fetch(1)
      puts HeapWindows.prepare_heap.size
    RUBY
    log = File.join(out, "preflight.valgrind.log")
    ok = system(env.merge(floors).merge("RUBYOPT" => nil, "LOWRAIL" => "0"), executable, "--verbose", "--tool=none",
      "--log-file=#{log}", RbConfig.ruby, *JitStability.flags("0"), "-e", program,
      rails_boot ? "rails" : "heap", File.expand_path("heap_windows.rb", __dir__),
      chdir: app,
      out: File.join(out, "preflight.log"), err: [:child, :out])
    result = { pass: !!ok && !File.read(log).match?(/brk segment overflow|Cannot map memory to grow brk segment/),
      version: version.strip, rails_boot: rails_boot, driver_sha256: Digest::SHA256.file(executable).hexdigest,
      build: build, log_sha256: Digest::SHA256.file(log).hexdigest }
    File.write(File.join(out, "valgrind-preflight.json"), JSON.pretty_generate(result))
    check_valgrind_log!(out, "preflight")
    raise "Valgrind allocation preflight failed; inspect #{log}" unless ok
    result
  end

  def self.idle_control(workers)
    observations = workers.to_h do |name, worker|
      companion = worker["idle_companion"]
      counts = companion&.dig("idle_census", "counts")
      windows = worker.fetch("windows").map.with_index do |window, index|
        first, last, start, finish = window.values_at("last_request_start_ns", "last_request_end_ns", "wall_start_ns", "wall_end_ns")
        ordered = [first, last, start, finish].all? { Integer === _1 } && first <= last && last <= start && start <= finish
        gap = (start - first).fdiv(1e9) if ordered
        duration = (finish - start).fdiv(1e9) if ordered
        connections = window.fetch("idle_connections").map do |connection|
          timeout, activity = connection.values_at("verify_timeout", "last_activity")
          age = start.fdiv(1e9) - activity if ordered && Numeric === activity
          pre = !!(age && age >= 0 && Numeric === timeout && timeout.positive? && gap < timeout && age < timeout)
          { verify_timeout: timeout, age_at_start_seconds: age, pre_window_safe: pre,
            whole_window_bounded: pre && age + duration < timeout }
        end
        pre = ordered && connections.all? { _1.fetch(:pre_window_safe) }
        bounded = pre && connections.all? { _1.fetch(:whole_window_bounded) }
        corresponding = companion && companion.fetch("windows")[index]
        count = counts && counts[index]
        census_ok = corresponding && corresponding.values_at("mode", "requests") == window.values_at("mode", "requests") &&
          Integer === count && count >= 0
        { mode: window.fetch("mode"), requests: window.fetch("requests"), pre_request_gap_seconds: gap,
          timestamps_ns: { last_request_start: first, last_request_end: last, window_start: start, window_end: finish },
          wall_duration_seconds: duration, connections: connections, pre_window_safe: pre,
          whole_window_bounded: bounded, companion_required: !bounded,
          companion_verify_path_executions: count, companion_valid: !!census_ok }
      end
      exercised = companion && (worker.fetch("windows").all? { _1.fetch("idle_connections").empty? } ||
        companion.dig("idle_census", "idle_exercise").to_i.positive?)
      [name, { windows: windows, boundary_exercised_in_companion: !!exercised,
        pass: !!exercised && windows.all? { _1.fetch(:pre_window_safe) && _1.fetch(:companion_valid) } }]
    end
    symmetry = observations.group_by { |name, _| name.split("-", 2).first }.to_h do |round, entries|
      signatures = entries.map do |_, observation|
        observation.fetch(:windows).map { [_1.fetch(:mode), _1.fetch(:requests), _1.fetch(:companion_verify_path_executions)] }.sort
      end
      [round, signatures.uniq.size == 1]
    end
    { pass: !observations.empty? && observations.values.all? { _1.fetch(:pass) } && symmetry.values.all?,
      counts_kind: "untimed_companion_not_measured_counts", companion_symmetry: symmetry, workers: observations }
  end

  def self.heap_instructions(environments, app, out, route, metadata, worker: "heap_requests.rb",
    requests: Integer(ENV.fetch("BENCH_REQUESTS", "50")))
    jobs = Integer(ENV.fetch("BENCH_JOBS", "4"))
    slots = HeapWindows.floors
    raise "positive requests/jobs required" unless requests.positive? && jobs.positive?
    floors = slots.each_with_index.to_h { |count, pool| ["RUBY_GC_HEAP_#{pool}_INIT_SLOTS", count.to_s] }
    metadata[:valgrind] = valgrind_preflight(out, floors, app: app, env: environments.fetch("off_a"))
    jit = JitStability.mode
    jit_flags = JitStability.flags(jit)
    if ENV["BENCH_JIT_CALL_THRESHOLD"]
      threshold = Integer(ENV.fetch("BENCH_JIT_CALL_THRESHOLD"))
      raise "positive JIT call threshold requires BENCH_JIT=1/yjit" unless jit == "yjit" && threshold.positive?
      jit_flags << "--yjit-call-threshold=#{threshold}"
      metadata[:jit_call_threshold] = threshold
    end
    extension = compile_counter_extension(out)
    metadata.merge!(counter: "callgrind", heap_mode: "fixed", heap_slots: slots,
      region: "after warmup and three full GCs", requests: requests, requested_yjit: jit == "yjit", requested_jit: jit)
    samples = []
    rng = Random.new(metadata.fetch(:seed))
    metadata.fetch(:rounds).times do |round|
      queue = Queue.new
      environments.keys.shuffle(random: rng).each { queue << _1 }
      row = {}
      lock = Mutex.new
      Array.new([jobs, environments.size].min) do
        Thread.new do
          loop do
            layer = queue.pop(true)
            label = "#{round}-#{layer}"
            data = File.join(out, "#{label}.callgrind")
            log = File.join(out, "#{label}.log")
            env = environments.fetch(layer).merge(floors).merge("BENCH_REQUESTS" => requests.to_s,
              "BENCH_PHASE_ORDER" => (round % 2).to_s, "BENCH_CALLGRIND_EXTENSION" => extension,
              "BENCH_IDLE_CENSUS" => nil)
            ok = system(env, "valgrind", "--verbose", "--tool=callgrind", "--instr-atstart=no", "--smc-check=all-non-file",
              "--callgrind-out-file=#{data}", "--log-file=#{File.join(out, "#{label}.valgrind.log")}",
              RbConfig.ruby, *jit_flags, File.expand_path(worker, __dir__), route,
              chdir: env.fetch("BENCH_WORKDIR", app), out: log, err: [:child, :out])
            check_valgrind_log!(out, label)
            raise "Callgrind failed: #{label}; inspect logs" unless ok
            result = File.readlines(log).find { _1.start_with?("LOWRAIL_BENCH ") }
            result = JSON.parse(result.to_s.delete_prefix("LOWRAIL_BENCH "))
            raise "AR build did not activate" if layer == "instantiate" && result.fetch("ar_installed").zero?
            windows = result.fetch("windows")
            windows.each_with_index do |window, index|
              window["instructions"] = instruction_total("#{data}.#{index + 1}")
            end
            operations = windows.group_by { _1["unit"] }.transform_values do |group|
              %w[total no_gc].to_h do |mode|
                empty, full = group.select { _1.fetch("mode") == mode }.sort_by { _1.fetch("requests") }
                count = full.fetch("instructions") - empty.fetch("instructions")
                raise "nonpositive count for #{label}/#{mode}" unless count.positive?
                ["instructions_#{mode}", count.fdiv(requests)]
              end
            end
            metrics = %w[instructions_total instructions_no_gc].to_h { |metric| [metric, operations.values.sum { _1.fetch(metric) }] }
            metrics["operations"] = operations if result["operations"]
            delta = windows.select { _1["mode"] == "total" && _1["requests"] == requests }.map do |full|
              full.fetch("after").to_h { |key, value| [key, value - full.fetch("before").fetch(key)] }
            end.reduce { |sum, values| sum.merge(values) { |_, a, b| a + b } }
            allocations = delta.fetch("total_allocated_objects")
            collections = delta.fetch("minor_gc_count") + delta.fetch("major_gc_count")
            metrics.merge!("allocations" => allocations.fdiv(requests),
              "minor_gc_per_request" => delta.fetch("minor_gc_count").fdiv(requests),
              "major_gc_per_request" => delta.fetch("major_gc_count").fdiv(requests),
              "gc_per_1k_allocations" => allocations.positive? ? 1000.0 * collections / allocations : nil, "windows" => windows)
            lock.synchronize { row[layer] = metrics; metadata.fetch(:workers)[label] = result }
          rescue ThreadError
            break
          end
        rescue StandardError => error
          error
        end
      end.map(&:value).each { raise _1 if _1.is_a?(Exception) }
      samples << row
      metadata[:actual_yjit] = metadata.fetch(:workers).values.map { _1.fetch("yjit") }.uniq
      metadata[:actual_jit] = metadata.fetch(:workers).values.map { JitStability.actual(_1) }.uniq
      File.write(File.join(out, "samples.json"), JSON.pretty_generate(metadata.merge(samples: samples)))
      warn "fixed-heap Callgrind round #{round + 1}/#{metadata.fetch(:rounds)}"
    end
    # Only after every Ir worker finishes: traced companion processes must
    # neither perturb a measured YJIT process nor contend with its workload.
    idle_observed = metadata.fetch(:workers).values.any? { _1.fetch("windows").any? { |window| window.key?("idle_connections") } }
    if idle_observed
      metadata.fetch(:workers).each do |name, result|
        round, layer = name.split("-", 2)
        log = File.join(out, "#{name}-idle-census.log")
        env = environments.fetch(layer).merge(floors).merge("BENCH_REQUESTS" => requests.to_s,
          "BENCH_PHASE_ORDER" => (round.to_i % 2).to_s, "BENCH_CALLGRIND_EXTENSION" => extension,
          "BENCH_IDLE_CENSUS" => "1")
        ok = system(env, RbConfig.ruby, *jit_flags, File.expand_path(worker, __dir__), route,
          chdir: env.fetch("BENCH_WORKDIR", app), out: log, err: [:child, :out])
        raise "Idle companion failed: #{name}; inspect #{log}" unless ok
        line = File.readlines(log).find { _1.start_with?("LOWRAIL_BENCH ") }
        companion = JSON.parse(line.to_s.delete_prefix("LOWRAIL_BENCH "))
        result["idle_companion"] = companion.slice("windows", "idle_census", "jit_warmup")
      end
      File.write(File.join(out, "samples.json"), JSON.pretty_generate(metadata.merge(samples: samples)))
    end
    summary = summarize(samples, seed: metadata.fetch(:seed), tolerance: Float(ENV.fetch("BENCH_AA_TOLERANCE", "0.5")),
      metrics: %w[instructions_total instructions_no_gc allocations], controls: %w[instructions_total instructions_no_gc])
    if environments.key?("before")
      summary[:runtime_change_pct] = %w[instructions_total instructions_no_gc].to_h do |metric|
        values = samples.map { 100 * (_1.fetch("default").fetch(metric) / _1.fetch("before").fetch(metric) - 1) }
        [metric, estimate(values, seed: metadata.fetch(:seed))]
      end
    end
    if environments.key?("unguarded")
      summary[:guard_tax] = %w[instructions_total instructions_no_gc].to_h do |metric|
        savings = samples.map { _1.fetch("default").fetch(metric) - _1.fetch("unguarded").fetch(metric) }
        percentages = samples.zip(savings).map { |row, saved| 100 * saved / row.fetch("default").fetch(metric) }
        [metric, { saved_per_request: estimate(savings, seed: metadata.fetch(:seed)),
          pct_of_guarded: estimate(percentages, seed: metadata.fetch(:seed)) }]
      end
    end
    summary[:gc] = environments.keys.to_h do |layer|
      [layer, %w[minor_gc_per_request major_gc_per_request gc_per_1k_allocations].to_h do |metric|
        values = samples.map { _1.fetch(layer).fetch(metric) }
        [metric, values.include?(nil) ? nil : estimate(values, seed: metadata.fetch(:seed))]
      end]
    end
    # Init slots are floors, not hard limits. Check actual capacities across
    # every measured layer/window; allow one page's rounding per size pool.
    summary[:heap_capacity] = slots.each_index.to_h do |pool|
      stats = samples.flat_map { |round| round.values.flat_map { _1.fetch("windows") } }
        .select { _1.fetch("requests").positive? }.map { _1.fetch("pools_before").fetch(pool.to_s) }
      capacities = stats.map { _1.fetch("heap_eden_slots") }
      page_slots = GC::INTERNAL_CONSTANTS.fetch(:HEAP_PAGE_SIZE).fdiv(stats.first.fetch("slot_size")).ceil
      [pool, { min: capacities.min, max: capacities.max,
        matched: capacities.min >= slots.fetch(pool) && capacities.max - capacities.min <= page_slots }]
    end
    summary[:heap_matched] = summary[:heap_capacity].values.all? { _1.fetch(:matched) }
    summary[:jit] = JitStability.control(metadata.fetch(:workers), requested: jit)
    summary[:idle_boundary] = idle_control(metadata.fetch(:workers)) if idle_observed
    File.write(File.join(out, "summary.json"), JSON.pretty_generate(summary))
    puts JSON.pretty_generate(summary)
    summary.fetch(:aa).fetch(:pass) && summary.fetch(:heap_matched) && summary.fetch(:jit).fetch(:pass) &&
      (!idle_observed || summary.fetch(:idle_boundary).fetch(:pass))
  end

  # Legacy short-window diagnostic: includes boot-dependent GC phase.
  def self.instructions(environments, app, out, route, metadata)
    requests = Integer(ENV.fetch("BENCH_REQUESTS", "200"))
    jobs = Integer(ENV.fetch("BENCH_JOBS", "4"))
    raise "positive requests/jobs required" unless requests.positive? && jobs.positive?
    jit = ENV.fetch("BENCH_JIT", "0") == "1"
    metadata[:valgrind] = valgrind_preflight(out, {}, app: app, env: environments.fetch("off_a"))
    extension = compile_counter_extension(out)
    metadata.merge!(counter: "callgrind", region: "after warmup and GC", requests: requests, yjit: jit)
    samples = []
    rng = Random.new(metadata.fetch(:seed))
    metadata.fetch(:rounds).times do |round|
      tasks = environments.keys.product([0, requests]).shuffle(random: rng)
      queue = Queue.new
      tasks.each { queue << _1 }
      totals = {}
      lock = Mutex.new
      Array.new([jobs, tasks.size].min) do
        Thread.new do
          loop do
            layer, n = queue.pop(true)
            label = "#{round}-#{layer}-#{n}"
            data = File.join(out, "#{label}.callgrind")
            env = environments.fetch(layer).merge("BENCH_COUNT_REQUESTS" => n.to_s, "BENCH_CALLGRIND_EXTENSION" => extension)
            ok = system(env, "valgrind", "--verbose", "--tool=callgrind", "--instr-atstart=no", "--smc-check=all-non-file",
              "--callgrind-out-file=#{data}", "--log-file=#{File.join(out, "#{label}.valgrind.log")}",
              RbConfig.ruby, jit ? "--yjit" : "--disable-yjit", File.join(__dir__, "requests.rb"), route,
              chdir: env.fetch("BENCH_WORKDIR", app), out: File.join(out, "#{label}.log"), err: [:child, :out])
            check_valgrind_log!(out, label)
            raise "Callgrind failed: #{label}; inspect logs" unless ok
            result = File.readlines(File.join(out, "#{label}.log")).find { _1.start_with?("LOWRAIL_BENCH ") }
            result = JSON.parse(result.to_s.delete_prefix("LOWRAIL_BENCH "))
            raise "unexpected JIT mode" unless result.fetch("yjit") == jit
            total = instruction_total("#{data}.1")
            lock.synchronize do
              (totals[layer] ||= {})[n] = total
              metadata.fetch(:workers)[label] = result
            end
          rescue ThreadError
            break # queue drained
          end
        rescue StandardError => error
          error # join every worker before temporary builds are removed
        end
      end.map(&:value).each { raise _1 if _1.is_a?(Exception) }
      row = totals.to_h do |layer, counts|
        delta = counts.fetch(requests) - counts.fetch(0)
        raise "nonpositive count for #{layer}" unless delta.positive?
        [layer, { "instructions" => delta.fdiv(requests), "totals" => counts }]
      end
      samples << row
      File.write(File.join(out, "samples.json"), JSON.pretty_generate(metadata.merge(samples: samples)))
      warn "Callgrind round #{round + 1}/#{metadata.fetch(:rounds)}"
    end
    summary = summarize(samples, seed: metadata.fetch(:seed), tolerance: Float(ENV.fetch("BENCH_AA_TOLERANCE", "0.5")),
      metrics: ["instructions"], controls: ["instructions"])
    File.write(File.join(out, "summary.json"), JSON.pretty_generate(summary))
    puts JSON.pretty_generate(summary)
    summary.fetch(:aa).fetch(:pass)
  end

  def self.diagnostics(environments, app, out, route, metadata)
    jit = ENV.fetch("BENCH_JIT", "0") == "1"
    metadata.merge!(counter: "gc", yjit: jit, samples: [])
    rng = Random.new(metadata.fetch(:seed))
    metadata.fetch(:rounds).times do |round|
      row = {}
      environments.keys.product(%w[window memory]).shuffle(random: rng).each do |layer, mode|
        label = "#{round}-#{layer}-#{mode}"
        env = environments.fetch(layer).merge("BENCH_GC_MODE" => mode, "BENCH_HEAP_DUMP" => nil)
        if ENV["BENCH_HEAP_DUMPS"] == "1" && round.zero? && mode == "memory" && %w[off_a default].include?(layer)
          env["BENCH_HEAP_DUMP"] = File.join(out, "#{label}.heap.jsonl")
        end
        log = File.join(out, "#{label}.log")
        ok = system(env, RbConfig.ruby, jit ? "--yjit" : "--disable-yjit", File.join(__dir__, "gc_requests.rb"),
          route, chdir: env.fetch("BENCH_WORKDIR", app), out: log, err: [:child, :out])
        raise "GC diagnostic failed: #{label}; inspect logs" unless ok
        lines = File.readlines(log)
        worker = JSON.parse(lines.find { _1.start_with?("LOWRAIL_BENCH ") }.to_s.delete_prefix("LOWRAIL_BENCH "))
        raise "unexpected JIT mode" unless worker.fetch("yjit") == jit
        metadata.fetch(:workers)[label] = worker
        (row[layer] ||= {})[mode] = lines.filter_map do |line|
          JSON.parse(line.delete_prefix("LOWRAIL_MEMORY ")) if line.start_with?("LOWRAIL_MEMORY ")
        end
      end
      metadata.fetch(:samples) << row
      File.write(File.join(out, "samples.json"), JSON.pretty_generate(metadata))
      warn "GC/memory diagnostic round #{round + 1}/#{metadata.fetch(:rounds)}"
    end
    # Diagnosis, not an instruction or latency comparison/control verdict.
    true
  end

  def self.receive(worker)
    while (line = worker.fetch(:stdout).gets)
      return JSON.parse(line.delete_prefix("LOWRAIL_BENCH ")) if line.start_with?("LOWRAIL_BENCH ")
      worker.fetch(:log).write(line)
    end
    raise "worker exited; inspect benchmark logs"
  end

  def self.command(worker, **data)
    worker.fetch(:stdin).puts(JSON.generate(data))
    receive(worker)
  end
end

if $PROGRAM_NAME == __FILE__
  abort "usage: request_pairs.rb APP NEW_OUTDIR GET:/path" unless ARGV.size == 3
  exit(RequestPairs.experiment(*ARGV) ? 0 : 2)
end
