# frozen_string_literal: true

# Bet F's single authorized Fizzy /buckets interpreter cohort. No default
# benchmark is changed. `none` verifies the exact heap without Ir counters.
require File.expand_path("config/boot", Dir.pwd) if ARGV == ["GET:/buckets"]
require "json"
require "fileutils"
require "digest"
require "rbconfig"
require_relative "../request_pairs"
require_relative "fizzy_link_vector"

module ARRequestIR
  ROOT = File.expand_path("../..", __dir__)
  FLOORS = [3_350_000, 300_000, 460_000, 30_000, 20_000].freeze
  RULE = {
    "scope" => "one Fizzy buckets fixture, interpreter Ir, not latency or production admission",
    "rounds" => 6, "seed" => 41231, "requests" => 10, "jobs" => 1,
    "aa" => "both total/no-GC 95% intervals lie wholly within ±0.1%; containing zero is not required",
    "win" => "both on/off upper 95% bounds below -max(0.5%, 3 × largest absolute A/A bound)",
    "gates" => "all source/tool/interpreter/exact-page/no-new-page/brk/hit gates pass; any violation rejects the whole cohort",
    "accepted_rejection" => "separate cold correctness companion: SolidCache created_at differs off/off; no whole-DB certificate",
    "retry" => "none; retain every worker and failed gate"
  }.freeze
  module_function

  def config(path)
    JSON.parse(File.read(path)).merge("exploration_setup" => File.join(__dir__, "ar_request_sites.rb"))
  end

  def environment(config, state_root, arm, sha, config_path)
    seed = File.realpath(config.fetch("seed"))
    FizzyLinkFixture.environment(config.fetch("app"), seed).merge(
      "BUNDLE_GEMFILE" => config.fetch("gemfile", File.join(config.fetch("app"), "Gemfile")),
      "BUNDLE_FROZEN" => "true", "LOWRAIL" => "0", "LOWRAIL_STATS" => nil,
      "RUBYOPT" => nil, "BENCH_JIT" => "0", "BENCH_JOBS" => "1", "BENCH_AA_TOLERANCE" => "0.1",
      "BENCH_HEAP_SLOTS" => FLOORS.join(","), "BENCH_HARNESS_SHA" => sha,
      "BENCH_AR_IR_CONFIG" => File.realpath(config_path), "BENCH_AR_IR_APPROVED" => sha,
      "BENCH_AR_IR_ARM" => arm, "BENCH_STATE_ROOT" => state_root)
  end

  def worker
    sha = ENV.fetch("BENCH_HARNESS_SHA")
    raise "exact cohort pin not approved" unless ENV.fetch("BENCH_AR_IR_APPROVED") == sha
    settings = config(ENV.fetch("BENCH_AR_IR_CONFIG"))
    app, artifact = %w[app artifact].map { File.realpath(settings.fetch(_1)) }
    pin = FizzyLinkVector.pin!(app: app, artifact: artifact, contexts: RULE)
    pin["ar_sources"] = %w[ar_callsite.rb ar_request_sites.rb ar_request_ir.rb].to_h {
      [_1, Digest::SHA256.file(File.join(__dir__, _1)).hexdigest]
    }
    pin["seed"] = Dir[File.join(settings.fetch("seed"), "**/*")].select { File.file?(_1) }.sort.to_h {
      [_1.delete_prefix(settings.fetch("seed") + "/"), Digest::SHA256.file(_1).hexdigest]
    }
    state = File.join(ENV.fetch("BENCH_STATE_ROOT"), "worker-#{Process.pid}")
    raise "new state required" if File.exist?(state)
    FileUtils.cp_r(settings.fetch("seed"), state)
    FizzyLinkFixture.environment(app, state).each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
    require File.join(app, "config/boot")
    # Same interpreter-only boot as the existing fixed-heap Fizzy workflow.
    FizzyLinkFixture.boot(app)
    JitStability.assert_mode!
    require settings.fetch("exploration_setup")
    arm = ENV.fetch("BENCH_AR_IR_ARM")
    NativeBench::Exploration.install(config: settings, state: state, arm: arm)
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
      raise "wrong completed site mix" unless hits == (arm == "on" ? 2 * count : 0) && fallbacks.zero?
      ledgers << {requests: count, hits: hits, fallbacks: fallbacks}
    end
    raise "app source changed" unless BlogProduction::Entropy.source_pin(app) == pin.fetch("app_source_sha256")
    puts "LOWRAIL_BENCH #{JSON.generate(**JitStability.state, ruby: RUBY_DESCRIPTION,
      windows: windows, heap_anchors: anchors, heap_page_targets: HeapWindows.page_targets,
      ar_installed: 0, pins: pin, site_ledgers: ledgers, shadow_during_windows: ARCallsite.shadow)}"
  end

  def launch(mode, config_path, output)
    raise "new output required" if File.exist?(output)
    FileUtils.mkdir_p(output, mode: 0o700)
    settings = config(config_path)
    sha = IO.popen(["git", "-C", ROOT, "rev-parse", "HEAD"], &:read).strip
    # Check clean detached ownership before creating even an untimed worker.
    FizzyLinkVector.pin!(app: settings.fetch("app"), artifact: settings.fetch("artifact"), contexts: RULE)
    ENV["BENCH_JOBS"] = "1"
    ENV["BENCH_JIT"], ENV["BENCH_HEAP_SLOTS"], ENV["BENCH_AA_TOLERANCE"] = "0", FLOORS.join(","), "0.1"
    envs = %w[off_a off_b on].to_h { [_1, environment(settings, output, _1, sha, config_path)] }
    File.write(File.join(output, "protocol.json"), JSON.pretty_generate(RULE.merge("harness_sha" => sha,
      "config_sha256" => Digest::SHA256.file(config_path).hexdigest, "mode" => mode)))
    if mode == "none"
      extension = RequestPairs.compile_counter_extension(output)
      rows = %w[off_a on].product(%w[0 1]).map do |arm, phase|
        label = "#{arm}-#{phase}"
        floors = FLOORS.each_with_index.to_h { |slots, pool| ["RUBY_GC_HEAP_#{pool}_INIT_SLOTS", slots.to_s] }
        env = envs.fetch(arm).merge(floors).merge("BENCH_REQUESTS" => "10", "BENCH_PHASE_ORDER" => phase,
          "BENCH_CALLGRIND_EXTENSION" => extension)
        log = File.join(output, "#{label}.log")
        vg = File.join(output, "#{label}.valgrind.log")
        ok = system(env, "valgrind", "--tool=none", "--log-file=#{vg}", RbConfig.ruby,
          *JitStability.flags("0"), File.expand_path(__FILE__), "GET:/buckets", chdir: settings.fetch("app"), out: log, err: [:child, :out])
        raise "untimed worker failed #{label}" unless ok
        RequestPairs.check_valgrind_log!(output, label)
        row = JSON.parse(File.readlines(log).find { _1.start_with?("LOWRAIL_BENCH ") }.delete_prefix("LOWRAIL_BENCH "))
        exact = row.fetch("windows").all? { |window|
          row.fetch("heap_page_targets").all? { |pool, target|
            before, after = %w[pools_before pools_after].map { window.fetch(_1).fetch(pool) }
            before.fetch("heap_eden_pages") == target && after.fetch("heap_eden_pages") == target &&
              before.fetch("total_allocated_pages") == after.fetch("total_allocated_pages")
          }
        }
        raise "untimed exact-page gate #{label}" unless exact && row.fetch("yjit") == false && row.fetch("zjit") == false
        row.merge("label" => label, "exact_pages" => exact)
      end
      File.write(File.join(output, "result.json"), JSON.pretty_generate("counters_started" => false, "workers" => rows, "passed" => true))
      puts "untimed: interpreter, hits, exact pages and no page growth PASS (4 workers / 16 windows)"
    else
      metadata = {seed: 41231, rounds: 6, workers: {}, protocol: RULE, harness_sha: sha}
      legacy_pass = RequestPairs.heap_instructions(envs, settings.fetch("app"), output, "GET:/buckets", metadata,
        worker: File.expand_path(__FILE__), requests: 10)
      summary = JSON.parse(File.read(File.join(output, "summary.json")))
      # Keep the shared helper's unchanged contains-zero result in summary.json.
      # The project rule was changed before this cohort, not after seeing it.
      aa = %w[instructions_total instructions_no_gc].to_h do |metric|
        interval = summary.fetch("layers").fetch("off_b").fetch(metric).fetch("delta_pct").fetch("ci95")
        [metric, {"ci95" => interval, "pass" => interval.first >= -0.1 && interval.last <= 0.1}]
      end
      no_new_pages = metadata.fetch(:workers).transform_values do |worker|
        worker.fetch("windows").all? do |window|
          window.fetch("pools_before").all? do |pool, before|
            before.fetch("total_allocated_pages") == window.fetch("pools_after").fetch(pool).fetch("total_allocated_pages")
          end
        end
      end
      gates = {"project_aa" => aa.values.all? { _1.fetch("pass") }, "no_new_pages" => no_new_pages.values.all?,
        "heap_matched" => summary.fetch("heap_matched"), "jit" => summary.fetch("jit").fetch("pass"),
        "valgrind" => metadata.fetch(:valgrind).fetch(:pass),
        "idle_boundary" => !summary.key?("idle_boundary") || summary.fetch("idle_boundary").fetch("pass")}
      pass = gates.values.all?
      effects = %w[instructions_total instructions_no_gc].to_h do |metric|
        aa = summary.fetch("layers").fetch("off_b").fetch(metric).fetch("delta_pct").fetch("ci95")
        bound = [0.5, 3 * aa.map(&:abs).max].max
        effect = summary.fetch("layers").fetch("on").fetch(metric).fetch("delta_pct")
        [metric, {"effect" => effect, "required_upper_bound_pct" => -bound, "clear_win" => effect.fetch("ci95").last < -bound}]
      end
      decision = {"gates_pass" => pass, "gates" => gates, "project_aa" => aa, "no_new_pages" => no_new_pages,
        "legacy_helper_gates_pass" => legacy_pass, "legacy_helper_rule" => "also requires containing zero; retained diagnostic, not project admission",
        "effects" => effects, "accepted_ir_win" => pass && effects.values.all? { _1.fetch("clear_win") }}
      File.write(File.join(output, "decision.json"), JSON.pretty_generate(decision))
      puts JSON.pretty_generate(decision)
    end
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV == ["GET:/buckets"]
    ARRequestIR.worker
  else
    mode, config, output = ARGV
    abort "usage: ar_request_ir.rb none|cohort CONFIG NEW_OUTPUT (clean detached harness)" unless %w[none cohort].include?(mode) && output
    ARRequestIR.launch(mode, File.realpath(config), File.expand_path(output))
  end
end
