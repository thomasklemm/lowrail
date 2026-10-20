# frozen_string_literal: true

# Sequential short blocks in separate warm Ruby/YJIT processes. No app edits,
# no shared Ruby heap, and no boot/profiler/counter time in the measurements.
# ruby bench/request_pairs.rb APP OUTDIR GET:/path
require "json"
require "fileutils"
require "tmpdir"
require "open3"
require "rbconfig"
require "digest"

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

  def self.summarize(rounds, seed:, tolerance:)
    layers = rounds.first.keys
    result = layers.to_h do |layer|
      metrics = METRICS.to_h do |metric|
        absolute = rounds.map { _1.fetch(layer).fetch(metric) }
        delta = rounds.map { 100 * (_1.fetch(layer).fetch(metric) / _1.fetch("off_a").fetch(metric) - 1) }
        [metric, { value: estimate(absolute, seed: seed), delta_pct: estimate(delta, seed: seed) }]
      end
      [layer, metrics]
    end
    controls = %w[cpu_us wall_us].to_h do |metric|
      low, high = result.fetch("off_b").fetch(metric).fetch(:delta_pct).fetch(:ci95)
      [metric, low <= 0 && high >= 0 && low >= -tolerance && high <= tolerance]
    end
    { layers: result, aa: { pass: controls.values.all?, metrics: controls, tolerance_pct: tolerance } }
  end

  def self.run(app, out, route)
    app, out = [app, out].map { File.expand_path(_1) }
    raise "output directory must be new" if File.exist?(out)
    FileUtils.mkdir_p(out, mode: 0o700)
    seed = Integer(ENV.fetch("BENCH_SEED", "41231"))
    rounds = Integer(ENV.fetch("BENCH_ROUNDS", "24"))
    raise "at least 8 rounds required" if rounds < 8
    workers = {}
    samples = []
    Dir.mktmpdir("lowrail-request-pairs") do |tmp|
      # Snapshot complete builds: lowered paths are absolute, ISeq paths are
      # relative to the manifest directory. Never hide/rename the app's build.
      normal = File.join(tmp, "normal")
      FileUtils.mkdir_p(normal)
      FileUtils.cp_r(File.join(app, ".lowrail"), normal)
      source = File.join(normal, ".lowrail/manifest.json")
      data = JSON.parse(File.read(source))
      raise "production build required" unless data.fetch("rails_env") == "production"
      empty = File.join(tmp, "empty")
      FileUtils.mkdir_p(File.join(empty, ".lowrail"))
      File.write(File.join(empty, ".lowrail/manifest.json"), JSON.generate(data.merge("files" => {}, "templates" => {}, "units" => [])))
      missing = File.join(tmp, "missing")
      FileUtils.mkdir_p(missing)
      layers = { "off_a" => nil, "off_b" => nil, "missing" => missing, "empty" => empty,
                 "disabled" => normal, "default" => normal }
      if (extra = ENV["BENCH_INSTANTIATE_DIR"])
        extra = File.expand_path(extra)
        extra_data = JSON.parse(File.read(File.join(extra, "manifest.json")))
        raise "production --ar-instantiate build required" unless extra_data["rails_env"] == "production" &&
          extra_data.fetch("units").any? { _1["pass"] == "active_record/instantiate" }
        layers["instantiate"] = File.join(tmp, "instantiate")
        FileUtils.mkdir_p(layers["instantiate"])
        FileUtils.cp_r(extra, File.join(layers["instantiate"], ".lowrail"))
      end
      root = File.expand_path("..", __dir__)
      metadata = { seed: seed, rounds: rounds, route: route, app: File.basename(app),
        manifest_sha256: Digest::SHA256.file(source).hexdigest,
        cache_mb: ENV["CAMPFIRE_RESPONSE_CACHE_MB"], workers: {} }
      layers.each do |layer, build_root|
        env = { "RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "RAILS_LOG_LEVEL" => "error",
          "LOWRAIL" => build_root ? "1" : "0", "LOWRAIL_ROOT" => build_root,
          "LOWRAIL_UNITS" => layer == "disabled" ? "" : nil,
          "LOWRAIL_STATS" => nil, "LOWRAIL_OUTCOMES" => nil, "LOWRAIL_DEBUG" => nil,
          "RUBYOPT" => build_root ? "-I#{root}/gem/lib -rlowrail/setup" : nil,
          "BENCH_PIPE" => "1", "BENCH_WARMUP" => ENV.fetch("BENCH_WARMUP", "400"),
          "BENCH_JSON" => nil, "BENCH_PROFILE" => nil, "BENCH_DUMP" => nil }
        stdin, stdout, wait = Open3.popen2e(env, RbConfig.ruby, "--yjit", File.join(__dir__, "requests.rb"), route, chdir: app)
        workers[layer] = { stdin: stdin, stdout: stdout, wait: wait, log: File.open(File.join(out, "#{layer}.log"), "w") }
        metadata[:workers][layer] = receive(workers.fetch(layer))
        warn "warm #{File.basename(app)} #{layer}"
      end
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
  exit(RequestPairs.run(*ARGV) ? 0 : 2)
end
