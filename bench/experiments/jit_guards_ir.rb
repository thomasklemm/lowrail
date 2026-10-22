# frozen_string_literal: true

# Incremental old-F / new-F interpreter screen, not a new Lowrail/off price.
require File.expand_path("config/boot", Dir.pwd) if ARGV == ["GET:/buckets"]
require_relative "../request_pairs"

module JitGuardsIR
  ROOT = File.expand_path("../..", __dir__)
  FLOORS = [3_350_000, 300_000, 460_000, 30_000, 20_000].freeze
  module_function

  def source_pin
    sha = IO.popen(["git", "-C", ROOT, "rev-parse", "HEAD"], &:read).strip
    dirty = IO.popen(["git", "-C", ROOT, "status", "--porcelain"], &:read)
    raise "clean committed source required" unless dirty.empty?
    sha
  end

  def worker
    config = JSON.parse(File.read(ENV.fetch("JIT_GUARDS_CONFIG")))
    raise "changed source revision" unless source_pin == ENV.fetch("JIT_GUARDS_SHA")
    require File.expand_path("../bench/experiments/fizzy_link_vector", File.dirname(config.fetch("harness")))
    require File.join(ROOT, "gem/lib/lowrail")
    state = File.join(ENV.fetch("BENCH_STATE_ROOT"), "worker-#{Process.pid}")
    raise "new state required" if File.exist?(state)
    FileUtils.cp_r(config.fetch("seed"), state)
    app = config.fetch("app")
    FizzyLinkFixture.environment(app, state).each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
    FizzyLinkFixture.boot(app)
    JitStability.assert_mode!
    raise "actual interpreter required" if RubyVM::YJIT.enabled? || RubyVM::ZJIT.enabled?
    treatment = ENV.fetch("JIT_GUARDS_TREATMENT")
    overlay = config.fetch("treatments").fetch(treatment).fetch("overlay")
    require overlay
    NativeBench::Exploration.install(config: config, state: state, arm: "on")
    ARRequestSites.counting = true
    driver = FizzyLinkVector::Driver.new(state, record: false)
    driver.login
    request = -> { raise "buckets GET failed" unless driver.request("GET", "/buckets").status == 200 }
    ARCallsite.shadow = true
    2.times { request.call }
    ARCallsite.shadow = false
    require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
    ledgers = []
    windows = HeapWindows.windows(Integer(ENV.fetch("BENCH_REQUESTS")))
    anchors = HeapWindows.run(windows, settle: request) do |count, _|
      before = ARRequestSites.counts.dup
      count.times { request.call }
      hits = ARRequestSites.counts.fetch("bucket:hit", 0) - before.fetch("bucket:hit", 0)
      fallbacks = ARRequestSites.counts.fetch("bucket:fallback", 0) - before.fetch("bucket:fallback", 0)
      raise "wrong completed site mix" unless hits == 2 * count && fallbacks.zero?
      ledgers << {requests: count, hits: hits, fallbacks: fallbacks}
    end
    puts "LOWRAIL_BENCH #{JSON.generate(**JitStability.state, ruby: RUBY_DESCRIPTION, treatment: treatment,
      windows: windows, heap_anchors: anchors, heap_page_targets: HeapWindows.page_targets,
      site_ledgers: ledgers, shadow_during_windows: ARCallsite.shadow, source_sha: source_pin,
      overlay_sha256: Digest::SHA256.file(overlay).hexdigest)}"
  end

  def launch(mode, config_file, output)
    raise "new output required" if File.exist?(output)
    sha = source_pin
    config = JSON.parse(File.read(config_file))
    load config.fetch("harness")
    FileUtils.mkdir_p(output, mode: 0o700)
    ENV["BENCH_JIT"], ENV["BENCH_JOBS"], ENV["BENCH_HEAP_SLOTS"] = "0", "1", FLOORS.join(",")
    envs = %w[off_a off_b on].to_h do |arm|
      env = NativeBench.environment(config, config.fetch("seed")).merge(
        "BUNDLER_VERSION" => "4.0.20", "LOWRAIL" => "0", "LOWRAIL_STATS" => nil,
        "RUBYOPT" => "-rbundler/setup", "BENCH_JIT" => "0", "BENCH_JOBS" => "1",
        "BENCH_HEAP_SLOTS" => FLOORS.join(","), "BENCH_STATE_ROOT" => output,
        "JIT_GUARDS_CONFIG" => config_file, "JIT_GUARDS_SHA" => sha,
        "JIT_GUARDS_TREATMENT" => arm == "on" ? "new" : "old")
      [arm, env]
    end
    pins = Dir[File.join(ROOT, "{gem/lib,bench}/**/*.{rb,so,c}")] +
      Dir[File.join(config.fetch("seed"), "**/*")].select { File.file?(_1) } + config.fetch("sources") +
      config.fetch("treatments").values.map { _1.fetch("overlay") } + [config_file]
    pins = pins.uniq.to_h { [_1, Digest::SHA256.file(_1).hexdigest] }
    protocol = {source_sha: sha, pins: pins, rounds: 6, requests: 10, seed: 41231,
      comparison: "old-on A / new-on / old-on B; not versus Lowrail off",
      rule: "both A/A CIs wholly within ±0.1%; new/old upper CI <= 0 for total and no-GC; all heap/mode/tool/pin gates pass; no retries or exclusions"}
    File.write(File.join(output, "protocol.json"), JSON.pretty_generate(protocol))
    if mode == "none"
      extension = RequestPairs.compile_counter_extension(output)
      rows = %w[off_a on].product(%w[0 1]).map do |arm, phase|
        label = "#{arm}-#{phase}"
        floors = FLOORS.each_with_index.to_h { |slots, pool| ["RUBY_GC_HEAP_#{pool}_INIT_SLOTS", slots.to_s] }
        env = envs.fetch(arm).merge(floors).merge("BENCH_REQUESTS" => "10", "BENCH_PHASE_ORDER" => phase,
          "BENCH_CALLGRIND_EXTENSION" => extension)
        log = File.join(output, label + ".log")
        ok = system(env, "valgrind", "--tool=none", "--log-file=#{output}/#{label}.valgrind.log", RbConfig.ruby,
          *JitStability.flags("0"), File.expand_path(__FILE__), "GET:/buckets", chdir: config.fetch("app"), out: log, err: [:child, :out])
        raise "untimed worker failed #{label}" unless ok
        RequestPairs.check_valgrind_log!(output, label)
        row = JSON.parse(File.readlines(log).find { _1.start_with?("LOWRAIL_BENCH ") }.delete_prefix("LOWRAIL_BENCH "))
        raise "heap/mode gate #{label}" unless !row.fetch("yjit") && !row.fetch("zjit") && row.fetch("windows").all? do |window|
          row.fetch("heap_page_targets").all? do |pool, target|
            first, last = window.fetch("pools_before").fetch(pool), window.fetch("pools_after").fetch(pool)
            first.fetch("heap_eden_pages") == target && last.fetch("heap_eden_pages") == target &&
              first.fetch("total_allocated_pages") == last.fetch("total_allocated_pages")
          end
        end
        row.merge("label" => label)
      end
      File.write(File.join(output, "result.json"), JSON.pretty_generate(workers: rows, passed: true, counters_started: false))
    else
      metadata = {seed: 41231, rounds: 6, workers: {}, protocol: protocol}
      legacy = RequestPairs.heap_instructions(envs, config.fetch("app"), output, "GET:/buckets", metadata,
        worker: File.expand_path(__FILE__), requests: 10)
      summary = JSON.parse(File.read(File.join(output, "summary.json")))
      metrics = %w[instructions_total instructions_no_gc]
      aa = metrics.all? do |metric|
        lo, hi = summary.fetch("layers").fetch("off_b").fetch(metric).fetch("delta_pct").fetch("ci95")
        lo >= -0.1 && hi <= 0.1
      end
      no_growth = metadata.fetch(:workers).values.all? do |row|
        row.fetch("windows").all? { |window| window.fetch("pools_before").all? { |pool, before|
          before.fetch("total_allocated_pages") == window.fetch("pools_after").fetch(pool).fetch("total_allocated_pages") } }
      end
      no_regression = metrics.all? { summary.fetch("layers").fetch("on").fetch(_1).fetch("delta_pct").fetch("ci95").last <= 0 }
      gates = {aa: aa, no_growth: no_growth, no_regression: no_regression, heap: summary.fetch("heap_matched"),
        jit: summary.fetch("jit").fetch("pass"), tool: metadata.fetch(:valgrind).fetch(:pass),
        pins: pins.all? { |path, digest| Digest::SHA256.file(path).hexdigest == digest } && source_pin == sha}
      File.write(File.join(output, "decision.json"), JSON.pretty_generate(passed: gates.values.all?, gates: gates, legacy_contains_zero_gate: legacy))
      raise "incremental interpreter screen rejected" unless gates.values.all?
    end
  end
end

if ARGV == ["GET:/buckets"]
  JitGuardsIR.worker
else
  mode, config, output = ARGV
  abort "usage: jit_guards_ir.rb none|cohort CONFIG NEW_OUTPUT" unless %w[none cohort].include?(mode) && output
  JitGuardsIR.launch(mode, File.realpath(config), File.expand_path(output))
end
