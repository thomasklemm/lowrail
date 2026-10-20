# frozen_string_literal: true

require "optparse"
require_relative "request_pairs"
require_relative "stack_budget"
require_relative "instruction_budget"
require_relative "../gem/lib/lowrail"
require_relative "../gem/lib/lowrail/manifest"

# One report contract over the existing request/GC harness and method micros.
module PassBench
  def self.preflight(dir, lib)
    path = File.join(dir, "manifest.json")
    data = JSON.parse(File.read(path))
    manifest = Lowrail::Manifest.new(data, dir)
    raise "stale build: incompatible Ruby/format" unless manifest.compatible?
    raise "production build required" unless manifest.rails_env == "production"
    root_lib = File.expand_path("../gem/lib", __dir__) + "/"
    check = ->(path, expected) {
      actual = path.start_with?(root_lib) ? File.join(lib, path.delete_prefix(root_lib)) : path
      [path, actual].uniq.each do |file|
        raise "stale build: #{file}; rebuild before measuring" unless File.file?(file) && Digest::SHA256.file(file).hexdigest == expected
      end
    }
    [data.fetch("files"), data.fetch("templates", {})].each do |entries|
      entries.each do |file, entry|
        check.call(file, entry.fetch("source_sha256"))
        next unless entry["iseq"]
        raise "stale build: missing loader contract" unless entry["original_iseq_sha256"] && entry["compile_option"]
        RubyVM::InstructionSequence.load_from_binary(File.binread(File.join(dir, entry.fetch("iseq"))))
      end
    end
    visit = ->(value) {
      case value
      when Hash
        value.each do |key, child|
          if key == "sources"
            child.each do |file, fingerprint|
              check.call(file, fingerprint.is_a?(Hash) ? fingerprint.fetch("sha256") : fingerprint)
              if fingerprint.is_a?(Hash)
                raise "stale build: source metadata changed" unless File.size(file) == fingerprint.fetch("size") && File.mtime(file).to_r.to_s == fingerprint.fetch("mtime")
              end
            end
          else
            visit.call(child)
          end
        end
      when Array then value.each { visit.call(_1) }
      end
    }
    visit.call(data.fetch("units"))
    data
  end

  def self.probe(app, out, env, route, label)
    log = File.join(out, "#{label}.log")
    ok = system(env, RbConfig.ruby, env.fetch("BENCH_JIT") == "1" ? "--yjit" : "--disable-yjit",
      File.join(__dir__, "pass_probe.rb"), route, chdir: app, out: log, err: [:child, :out])
    raise "activation/JIT probe failed; inspect #{log}" unless ok
    line = File.readlines(log).find { _1.start_with?("LOWRAIL_BENCH ") }
    JSON.parse(line.to_s.delete_prefix("LOWRAIL_BENCH "))
  end

  def self.canonical(value)
    case value
    when Hash then value.to_h { |key, child| [key.to_s, canonical(child)] }.sort.to_h
    when Array then value.map { canonical(_1) }
    else value
    end
  end

  def self.runtime_fingerprint(lib)
    Dir.glob(File.join(lib, "**/*.rb")).sort.to_h do |file|
      [file.delete_prefix(lib + "/"), Digest::SHA256.file(file).hexdigest]
    end
  end

  def self.harness_fingerprint
    Dir.glob(File.join(__dir__, "*.{rb,c}")).reject { _1.end_with?("_test.rb") }.sort.to_h do |file|
      [File.basename(file), Digest::SHA256.file(file).hexdigest]
    end
  end

  # Existing micros own the operation and fallback. This driver owns fresh
  # processes, off/off controls, subtraction, and the request-effect budget.
  def self.micro(app, out, env, pass, name, model, coverage)
    script = { "active_record/instantiate" => "ar_instantiate.rb",
      "active_record/preload_plans" => "preload_paths.rb", "active_record/ar_plans" => "ar_cached_reader.rb" }.fetch(pass) {
      raise "no guarded micro adapter for #{pass}; omit --micro-case and see docs/bench.md"
    }
    raise "instantiate micro needs --model" if pass == "active_record/instantiate" && !model
    micro_env = env.merge("BENCH_JIT" => "1", "BENCH_MICRO_SCRIPT" => File.join(__dir__, script),
      "BENCH_MODEL" => model, "BENCH_CASES" => name, "BENCH_ROUNDS" => "1", "LOWRAIL_STATS" => nil,
      "BENCH_SECONDS" => ENV.fetch("BENCH_MICRO_SECONDS", "0.5"), "BENCH_PROFILE" => nil)
    rows = []
    read = ->(file) {
      data = JSON.parse(File.read(file))
      data = data.fetch("samples") if data.is_a?(Hash)
      row = data.find { (_1["case"] || _1["route"]) == name }
      raise "micro case not produced: #{name}" unless row
      row
    }
    count = Integer(ENV.fetch("BENCH_MICRO_ROUNDS", "6"))
    raise "micro needs at least six independent rounds" if count < 6
    count.times do |round|
      row = {}
      %w[off_a off_b on].shuffle(random: Random.new(41231 + round)).each do |layer|
        file = File.join(out, "micro-#{round}-#{layer}.json")
        probe(app, out, micro_env.merge("LOWRAIL" => layer == "on" ? "1" : "0", "BENCH_JSON" => file),
          "", "micro-#{round}-#{layer}")
        sample = read.call(file)
        row[layer] = { "wall_us" => sample["us"] || sample.fetch("us_per_req") }
      end
      rows << row
    end
    summary = RequestPairs.summarize(rows, seed: 41231, tolerance: 2, metrics: ["wall_us"], controls: ["wall_us"])
    # Separate counted worker: counters never contaminate timing windows.
    file = File.join(out, "micro-counted.json")
    probe(app, out, micro_env.merge("LOWRAIL_STATS" => "", "LOWRAIL" => "1", "BENCH_JSON" => file,
      "BENCH_SECONDS" => "0.05"), "", "micro-counted")
    counted = read.call(file)
    hits = counted.fetch("unit_hits").select { |_, n| n.positive? }
    raise "micro must complete exactly one selected unit; choose a narrower operation" unless hits.size == 1
    id, total = hits.first
    per_iteration = total.fdiv(counted.fetch("iterations"))
    saved = rows.map { (_1.fetch("off_a").fetch("wall_us") - _1.fetch("on").fetch("wall_us")) / per_iteration }
    saved = RequestPairs.estimate(saved, seed: 41231)
    frequency = coverage.fetch("units").find { _1.fetch("id").to_s == id }.fetch("hits_per_request")
    unmodeled = coverage.fetch("units").select { _1.fetch("id").to_s != id && _1.fetch("hits_per_request").positive? }
    { case: name, metric: "wall_us", yjit: true, guard_included: true, aa: summary.fetch(:aa),
      unit_id: Integer(id), hits_per_iteration: per_iteration, saved_per_hit: saved,
      hits_per_request: frequency, expected_us_per_request: saved.transform_values { |v| v.is_a?(Array) ? v.map { _1 * frequency } : v * frequency },
      unmodeled_unit_ids: unmodeled.map { _1.fetch("id") }, samples: rows, summary: summary }
  end

  def self.table(result)
    native = result[:counter] == "native"
    selection = result[:passes] ? "Pass set: `#{result.fetch(:passes).join(',')}`. Stacked and default use separate builds." :
      "Pass: `#{result.fetch(:pass)}`. The default layer enables the selected units."
    lines = ["#{selection} Counter: `#{result.fetch(:counter)}`.", "",
      native ? "| Layer | CPU µs/request | Δ% [95% CI] | Wall µs/request | Δ% [95% CI] |" :
      "| Layer | Instructions/request | Δ% [95% CI] | GC-excluded Ir/request | Δ% [95% CI] |",
      "|---|---:|---:|---:|---:|"]
    result.fetch(:request, {}).fetch("layers", {}).sort.each do |layer, metrics|
      cells = (native ? %w[cpu_us wall_us] : %w[instructions_total instructions_no_gc]).map do |key|
        metric = metrics.fetch(key)
        delta = metric.fetch("delta_pct")
        format("%.3f | %+.3f [%+.3f, %+.3f]", metric.fetch("value").fetch("median"), delta.fetch("median"), *delta.fetch("ci95"))
      end
      lines << "| #{layer} | #{cells.join(' | ')} |"
    end
    lines << "\nVerdict: **#{result.fetch(:status)}**. #{result[:error]}"
    lines << "\nDeltas compare with no setup; off_b is the independent A/A control."
    if result[:coverage]
      lines << "\nCompleted routes/request: #{result.fetch(:coverage).fetch('route_completions_per_request')}; other per-unit counts in JSON. Source guard counts are not completion counts."
    end
    if (stack = result[:stack])
      lines << "\n| Reference / metric | Measured saving/request [95% CI] | Sum individual expected [95% CI] | Measured − expected [95% CI] |"
      lines << "|---|---:|---:|---:|"
      stack.fetch(:comparisons).each do |reference, metrics|
        metrics.each do |metric, comparison|
          cells = %i[measured_saved_per_request sum_individual_expected_saved_per_request measured_minus_expected].map do |key|
            value = comparison[key]
            value ? format("%+.3f [%+.3f, %+.3f]", value.fetch(:median), *value.fetch(:ci95)) : "unmodeled"
          end
          lines << "| #{reference} / #{metric} | #{cells.join(' | ')} |"
        end
      end
      lines << "\nPositive savings are better. Default comparison predicts opt-in budgets only; no-setup predicts all supplied budgets. Residuals also include setup cost and unmodeled work, not just interactions."
      lines << "\nBudget: #{stack.fetch(:budget_status)}. Unmodeled hit units: #{stack.fetch(:unmodeled_unit_ids).join(',')}. No promotion claim from partial budgets."
      lines << "\nUnpriced fallback units: #{stack.fetch(:unmodeled_fallback_unit_ids).join(',')}." unless stack.fetch(:unmodeled_fallback_unit_ids).empty?
      lines << "\nRemoved default passes (unmodeled reference work): #{stack.fetch(:removed_default_passes).join(',')}." unless stack.fetch(:removed_default_passes).empty?
      unless stack.fetch(:units).empty?
        lines << "\n| Unit / model / count basis (#{stack.fetch(:metric)}) | Guard-included saved/count [95% CI] | Count/request | Completed/request | Expected saving/request [95% CI] |"
        lines << "|---|---:|---:|---:|---:|"
        stack.fetch(:units).each do |unit|
          cost, expected = unit[:saved_per_hit] || unit.fetch(:saved_per_invocation), unit.fetch(:expected_saved_per_request)
          frequency = unit[:hits_per_request] || unit.fetch(:invocations_per_request)
          frequency = RequestPairs.median(frequency) if frequency.is_a?(Array)
          completions = unit[:completed_hits_per_request] || unit[:hits_per_request] || 0
          completions = RequestPairs.median(completions) if completions.is_a?(Array)
          lines << format("| %d / %s / %s | %+.3f [%+.3f, %+.3f] | %.3f | %.3f | %+.3f [%+.3f, %+.3f] |",
            unit.fetch(:id), unit[:model] || unit.fetch(:pass), unit.fetch(:count_kind), cost.fetch(:median), *cost.fetch(:ci95), frequency, completions,
            expected.fetch(:median), *expected.fetch(:ci95))
        end
      end
    elsif (micro = result[:micro])
      lines << format("\nUnit %d guard-included micro: %.4f µs/hit × %.3f hits/request = %.4f expected µs/request (native YJIT; not interpreter instructions). Unmodeled hit units: %s.",
        micro.fetch(:unit_id), micro.fetch(:saved_per_hit).fetch(:median), micro.fetch(:hits_per_request), micro.fetch(:expected_us_per_request).fetch(:median), micro.fetch(:unmodeled_unit_ids).join(","))
      if (measured = result[:measured_us_saved_per_request])
        lines << format("\nMeasured native saving: %+.4f µs/request [%+.4f, %+.4f]; request A/A: %s; micro A/A: %s.",
          measured.fetch(:median), *measured.fetch(:ci95), result.fetch(:request).fetch("aa").fetch("pass"), micro.fetch(:aa).fetch(:pass))
      end
    else
      lines << "\nPer-hit budget: not measured; no pass-promotion claim. See docs/bench.md for remaining micro adapters."
    end
    lines.join("\n") + "\n"
  end

  def self.run(app, options)
    app = File.expand_path(app)
    out = File.expand_path(options.fetch(:out, File.join(app, "tmp/lowrail-bench")))
    raise "output directory must be new: #{out}" if File.exist?(out)
    FileUtils.mkdir_p(out, mode: 0o700)
    result = { schema_version: 1, pass: options[:pass], counter: options.fetch(:counter, "callgrind"), status: "rejected" }
    result[:passes] = options.fetch(:passes).split(",") if options[:passes]
    begin
      stacked = !!options[:passes]
      raise "choose --pass or --passes" if !!options[:pass] == stacked
      if stacked
        raise "stacked mode needs --default-build DIR" unless options[:default_build]
        raise "stacked mode uses --budgets, not --micro-case/--model" if options[:micro_case] || options[:model]
        raise "choose --budgets or --measure-budgets" if options[:budgets] && options[:measure_budgets]
        raise "stacked mode cannot combine other comparison layers" if
          %w[BENCH_BASELINE_LIB BENCH_INSTANTIATE_DIR BENCH_VARIANT_APP].any? { ENV[_1] }
      elsif options[:default_build] || options[:budgets] || options[:measure_budgets]
        raise "--default-build, --budgets and --measure-budgets require --passes"
      end
      counter = result.fetch(:counter)
      raise "counter must be callgrind or native" unless %w[callgrind native].include?(counter)
      raise "BENCH_JIT must be 0 or 1" unless %w[0 1].include?(ENV.fetch("BENCH_JIT", "0"))
      raise "legacy heap mode is diagnostic only" if ENV["BENCH_HEAP_MODE"] == "legacy"
      raise "A/A tolerance is fixed; do not widen controls" if ENV["BENCH_AA_TOLERANCE"]
      raise "native needs at least five independent cohorts" if counter == "native" && Integer(ENV.fetch("BENCH_COHORTS", "5")) < 5
      baseline = File.expand_path(ENV["BENCH_BASELINE_LIB"]) if ENV["BENCH_BASELINE_LIB"]
      raise "runtime comparison requires --pass default" if baseline && options[:pass] != "default"
      lib = File.expand_path(ENV.fetch("BENCH_LOWRAIL_LIB", File.join(__dir__, "../gem/lib")))
      data = preflight(File.join(app, ".lowrail"), lib)
      result[:manifest_sha256] = Digest::SHA256.file(File.join(app, ".lowrail/manifest.json")).hexdigest
      result[:runtime_files_sha256] = runtime_fingerprint(lib)
      result[:runtime_fingerprint_sha256] = Digest::SHA256.hexdigest(JSON.generate(canonical(result.fetch(:runtime_files_sha256))))
      result[:harness_files_sha256] = harness_fingerprint
      result[:harness_fingerprint_sha256] = Digest::SHA256.hexdigest(JSON.generate(canonical(result.fetch(:harness_files_sha256))))
      result[:app] = File.basename(app)
      result[:lockfile_sha256] = Digest::SHA256.file(File.join(app, "Gemfile.lock")).hexdigest if File.file?(File.join(app, "Gemfile.lock"))
      result[:corpus_source] = File.read(File.join(app, ".lowrail-corpus-source")).strip if File.file?(File.join(app, ".lowrail-corpus-source"))
      selected = data.fetch("units").select do |unit|
        stacked ? result.fetch(:passes).include?(unit.fetch("pass")) : options.fetch(:pass) == "default" || unit.fetch("pass") == options.fetch(:pass)
      end
      raise "no units for selection; build production with that pass first" if selected.empty?
      if stacked
        raise "stack build contains unselected passes; rebuild with exactly --passes SET" unless selected == data.fetch("units")
        reference = File.expand_path(options.fetch(:default_build))
        reference_data = preflight(reference, lib)
        default_passes = options.fetch(:default_passes).split(",")
        raise "default reference contains opt-in passes" unless reference_data.fetch("units").all? { default_passes.include?(_1.fetch("pass")) }
        raise "default reference belongs to another app" unless reference_data.fetch("units").all? do |unit|
          !unit["file"] || unit.fetch("file").start_with?(app + "/")
        end
        result[:default_manifest_sha256] = Digest::SHA256.file(File.join(reference, "manifest.json")).hexdigest
      end
      route = options.fetch(:path, "/")
      route = "GET:#{route}" unless route.match?(/\A[A-Z]+:/)
      raise "--path must be a local request path" unless route.match?(/\A[A-Z]+:\//)
      result[:route] = route
      # Tie externally counted completion frequencies to the same request,
      # without writing private authentication headers into the report.
      result[:request_context_sha256] = Digest::SHA256.hexdigest(JSON.generate(canonical(
        route: route, headers: JSON.parse(ENV.fetch("BENCH_HEADERS", "{}")), cache_mb: ENV["CAMPFIRE_RESPONSE_CACHE_MB"])))
      ids = selected.map { _1.fetch("id") }.join(",")
      env = { "RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "RAILS_LOG_LEVEL" => "error",
        "LOWRAIL" => "1", "LOWRAIL_ROOT" => app, "LOWRAIL_UNITS" => ids, "BENCH_UNITS" => ids,
        "LOWRAIL_STATS" => "", "LOWRAIL_OUTCOMES" => nil, "LOWRAIL_DEBUG" => nil, "LOWRAIL_SHADOW" => nil,
        "BENCH_JIT" => counter == "native" ? "1" : ENV.fetch("BENCH_JIT", "0"),
        "BENCH_WARMUP" => ENV.fetch("BENCH_WARMUP", counter == "native" ? "400" : "50"),
        "RUBYOPT" => "-I#{lib} -rlowrail/setup" }
      result[:coverage] = probe(app, out, env, route, "coverage")
      if stacked
        Dir.mktmpdir("lowrail-bench-default") do |tmp|
          FileUtils.ln_s(reference, File.join(tmp, ".lowrail"))
          default_ids = reference_data.fetch("units").map { _1.fetch("id") }.join(",")
          result[:default_coverage] = probe(app, out, env.merge("LOWRAIL_ROOT" => tmp, "LOWRAIL_UNITS" => default_ids.empty? ? nil : default_ids,
            "BENCH_UNITS" => default_ids), route, "default-coverage")
        end
        if options[:measure_budgets]
          result[:budget_input] = InstructionBudget.run(app, File.join(out, "budgets"), env, route, result, selected)
          StackBudget.validate!(result.fetch(:budget_input), result, selected)
        elsif options[:budgets]
          result[:budget_input] = JSON.parse(File.read(options.fetch(:budgets)))
          StackBudget.validate!(result.fetch(:budget_input), result, selected)
        end
      end
      if baseline
        preflight(File.join(app, ".lowrail"), baseline)
        result[:baseline_runtime_files_sha256] = runtime_fingerprint(baseline)
        result[:baseline_coverage] = probe(app, out, env.merge("RUBYOPT" => "-I#{baseline} -rlowrail/setup"), route, "baseline-coverage")
      end
      extra = ENV["BENCH_INSTANTIATE_DIR"]
      if extra
        raise "extra build is only supported with --pass default" unless options[:pass] == "default"
        extra_data = preflight(File.expand_path(extra), lib)
        Dir.mktmpdir("lowrail-bench-extra") do |tmp|
          FileUtils.ln_s(File.expand_path(extra), File.join(tmp, ".lowrail"))
          extra_ids = extra_data.fetch("units").map { _1.fetch("id") }.join(",")
          result[:extra_coverage] = probe(app, out, env.merge("LOWRAIL_ROOT" => tmp, "LOWRAIL_UNITS" => extra_ids,
            "BENCH_UNITS" => extra_ids), route, "extra-coverage")
        end
      end
      # The request driver, not this parent, assigns each worker's setup layer.
      run_env = env.merge("RUBYOPT" => nil, "LOWRAIL_STATS" => nil, "BENCH_COUNTER" => counter == "callgrind" ? "callgrind" : nil,
        "BENCH_HEAP_MODE" => "fixed", "BENCH_UNITS" => options[:pass] == "default" ? nil : ids,
        "BENCH_DEFAULT_DIR" => reference)
      ok = system(run_env, RbConfig.ruby, File.join(__dir__, "request_pairs.rb"), app, File.join(out, "requests"), route,
        out: File.join(out, "requests.log"), err: [:child, :out])
      result[:request] = JSON.parse(File.read(File.join(out, "requests/summary.json"))) if File.file?(File.join(out, "requests/summary.json"))
      result[:provenance] = JSON.parse(File.read(File.join(out, "requests/samples.json"))).reject { |key, _| %w[samples workers cohorts].include?(key) } if counter == "callgrind" && result[:request]
      raise "request A/A, heap, activation or JIT checks failed; inspect requests.log" unless ok
      raw = JSON.parse(File.read(File.join(out, "requests/samples.json")))
      workers = raw["cohorts"] ? raw.fetch("cohorts").flat_map { _1.fetch("workers").values } : raw.fetch("workers").values
      raise "unexpected JIT mode in request workers" unless workers.all? { _1.fetch("yjit") == (env.fetch("BENCH_JIT") == "1") }
      result[:actual_yjit] = workers.map { _1.fetch("yjit") }.uniq
      if stacked
        result[:stack] = StackBudget.report(raw, result, result[:budget_input], default_passes,
          seed: Integer(ENV.fetch("BENCH_SEED", "41231")))
      end
      # Keep time and instruction budgets separate: a YJIT micro cannot
      # predict an interpreter instruction count by changing its unit label.
      if options[:micro_case]
        native_coverage = probe(app, out, env.merge("BENCH_JIT" => "1",
          "BENCH_WARMUP" => ENV.fetch("BENCH_WARMUP", "400")), route, "native-coverage")
        result[:micro] = micro(app, out, env, options.fetch(:pass), options.fetch(:micro_case), options[:model], native_coverage)
        raise "micro A/A failed; no accepted effect budget" unless result.fetch(:micro).fetch(:aa).fetch(:pass)
        if counter == "native"
          cohorts = raw["cohorts"] ? raw.fetch("cohorts").map { _1.fetch("samples") } : [raw.fetch("samples")]
          savings = cohorts.map { |rows| RequestPairs.median(rows.map { _1.fetch("off_a").fetch("wall_us") - _1.fetch("default").fetch("wall_us") }) }
          result[:measured_us_saved_per_request] = RequestPairs.estimate(savings, seed: Integer(ENV.fetch("BENCH_SEED", "41231")))
        end
      end
      if options[:diagnostics]
        # Archived-runtime comparisons are instruction-only, not GC diagnostics.
        ok = system(run_env.merge("BENCH_COUNTER" => "gc", "BENCH_BASELINE_LIB" => nil), RbConfig.ruby, File.join(__dir__, "request_pairs.rb"),
          app, File.join(out, "diagnostics"), route, out: File.join(out, "diagnostics.log"), err: [:child, :out])
        raise "GC diagnostic failed" unless ok
      end
      # Detect a concurrent rebuild/edit rather than publish mixed provenance.
      raise "build changed during measurement" unless data == preflight(File.join(app, ".lowrail"), lib)
      raise "default build changed during measurement" if stacked && reference_data != preflight(reference, lib)
      raise "extra build changed during measurement" if extra && extra_data != preflight(File.expand_path(extra), lib)
      raise "runtime changed during measurement" unless result.fetch(:runtime_files_sha256) == runtime_fingerprint(lib)
      raise "benchmark harness changed during measurement" unless result.fetch(:harness_files_sha256) == harness_fingerprint
      if baseline
        preflight(File.join(app, ".lowrail"), baseline)
        raise "baseline runtime changed during measurement" unless result.fetch(:baseline_runtime_files_sha256) == runtime_fingerprint(baseline)
      end
      result[:status] = "accepted"
    rescue StandardError => error
      result[:error] = error.message
    ensure
      generated = File.join(out, "budgets/budget.json")
      result[:budget_input] ||= JSON.parse(File.read(generated)) if File.file?(generated)
      result[:measurement_complete] = !!(result[:status] == "accepted" && result[:counter] == "native" &&
        result[:micro] && result[:micro].fetch(:unmodeled_unit_ids).empty?)
      if result[:stack]
        result[:measurement_complete] = !!(result[:status] == "accepted" && result[:budget_input] &&
          result.fetch(:stack).fetch(:unmodeled_unit_ids).empty? && result.fetch(:stack).fetch(:removed_default_passes).empty? &&
          result.fetch(:stack).fetch(:unmodeled_fallback_unit_ids).empty?)
      end
      File.write(File.join(out, "result.json"), JSON.pretty_generate(canonical(result)) + "\n")
      File.write(File.join(out, "table.md"), table(result))
      puts table(result)
      warn "JSON: #{File.join(out, 'result.json')}"
    end
    result[:status] == "accepted"
  end
end

if $PROGRAM_NAME == __FILE__
  options = {}
  parser = OptionParser.new do |p|
    %w[pass passes default-passes default-build budgets path out counter micro-case model].each { |name| p.on("--#{name} VALUE") { options[name.tr('-', '_').to_sym] = _1 } }
    p.on("--measure-budgets") { options[:measure_budgets] = true }
    p.on("--diagnostics") { options[:diagnostics] = true }
  end
  parser.parse!
  abort "usage: pass.rb APP --pass NAME [--path /path] [--out NEW_DIR] (pass sets: use lowrail bench)" unless ARGV.one? && (options[:pass] || options[:passes])
  exit(PassBench.run(ARGV.first, options) ? 0 : 2)
end
