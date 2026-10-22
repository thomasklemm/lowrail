# frozen_string_literal: true

# Bet Y: finite, untimed guard census. No production or RPS admission here.
require File.expand_path("config/boot", Dir.pwd) if ARGV.first == "worker"
require "json"
require "fileutils"
require "digest"
require "rbconfig"

module JitGuards
  ROOT = File.expand_path("../..", __dir__)
  module_function

  def delta(before, after)
    after.to_h { |key, value| [key, value - before.fetch(key, 0)] }
  end

  def worker(config, state, treatment, phase, destination)
    load config.fetch("harness")
    require File.join(ROOT, "fixtures/corpus/blog_production")
    require File.join(config.fetch("app"), "config/environment")
    raise "actual Ruby/Rails/JIT mismatch" unless RUBY_VERSION == "4.0.7" && Rails.version == "8.1.4" &&
      Rails.env.production? && RubyVM::YJIT.enabled? && !(defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?)
    settings = config.fetch("treatments").fetch(treatment)
    if config["workload"] == "fizzy"
      require settings.fetch("overlay")
      NativeBench::Exploration.install(config: config, state: state, arm: settings.fetch("enabled") ? "on" : "off_a")
    end
    invoke = -> {
      response = @request.call
      raise "HTTP #{response.status}" unless response.status == 200
      response
    }
    @request = NativeBench.routes(config, state, treatment).values.fetch(0)
    config.fetch("warmup").times { invoke.call }
    if phase == "coverage"
      if config.fetch("workload") == "blog"
        policy = JSON.parse(File.read(config.fetch("entropy_policy")))
        control = BlogProduction::Entropy.validate(config.fetch("app"), policy: policy)
        raise control.fetch("reason") unless control.fetch("active")
        BlogProduction::Entropy.install(policy)
      end
      exact = [0, 1].to_h do |seed|
        response, evidence = if config.fetch("workload") == "fizzy"
          NativeBench::Exploration.validation_request(route: "GET /buckets", seed: seed, request: invoke)
        else
          BlogProduction::Entropy.with(seed, "GET /articles/1", wall_clock: true, &invoke)
        end
        raise "entropy companion rejected" unless evidence.fetch("errors", []).empty? && evidence.fetch("passed", true)
        [seed, NativeBench.response_digest(response).merge("evidence" => evidence)]
      end
      counts_before = NativeBench.counts
    end
    stats = -> { RubyVM::YJIT.runtime_stats.select { |_, value| Numeric === value } }
    before = stats.call if phase == "stats"
    n = phase == "coverage" ? 10 : config.fetch("samples")
    allocated = GC.stat(:total_allocated_objects)
    n.times { invoke.call }
    allocated = GC.stat(:total_allocated_objects) - allocated
    after = stats.call if phase == "stats"
    record = {treatment: treatment, phase: phase, ruby: RUBY_DESCRIPTION,
      yjit: RubyVM::YJIT.enabled?, zjit: defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?,
      ruby_sha256: Digest::SHA256.file("/proc/self/exe").hexdigest,
      requests: n, warmup: config.fetch("warmup"), allocations_per_request: allocated.fdiv(n),
      exact: exact, counts_before: counts_before, counts_after: phase == "coverage" ? NativeBench.counts : nil,
      jit_before: before, jit_delta: before && delta(before, after), refusal: Lowrail.refusal_reason}
    if phase == "stats"
      change = record.fetch(:jit_delta)
      retired = change.fetch(:yjit_insns_count) - change.fetch(:side_exit_count)
      raise "no executed JIT instructions" unless retired.positive?
      record[:window_ratio_in_yjit] = 100.0 * retired / (retired + change.fetch(:vm_insns_count))
    end
    File.write(destination, JSON.pretty_generate(record))
  end

  def run(config, output)
    raise "new output directory required" if File.exist?(output)
    FileUtils.mkdir_p(output, mode: 0o700)
    load config.fetch("harness")
    require File.join(ROOT, "fixtures/corpus/blog_production")
    config_file = File.join(output, "config.json")
    File.write(config_file, JSON.pretty_generate(config))
    paths = [__FILE__, config.fetch("harness"), config.fetch("entropy_policy"),
      File.join(config.fetch("app"), "Gemfile.lock"), *config.fetch("sources")]
    paths.concat(Dir[File.join(ROOT, "gem/lib/**/*.{rb,so}")])
    config.fetch("treatments").each_value do |settings|
      paths << settings["overlay"] if settings["overlay"]
      %w[artifact stats_artifact].each { paths.concat(Dir[File.join(settings.fetch(_1), "**/*")].select { |path| File.file?(path) }) }
    end
    pins = paths.uniq.to_h { [_1, Digest::SHA256.file(_1).hexdigest] }
    source = BlogProduction::Entropy.source_pin(config.fetch("app"))
    File.write(File.join(output, "protocol.json"), JSON.pretty_generate(config: config, pins: pins, app_source: source))
    workers = []
    %w[coverage allocations stats].each do |phase|
      config.fetch("treatments").each do |treatment, settings|
        label = "#{phase}-#{treatment}"
        state = File.join(output, label + "-state")
        FileUtils.cp_r(config.fetch("seed"), state)
        if config.fetch("workload") == "blog"
          FileUtils.rm_rf(File.join(config.fetch("app"), "storage"))
          FileUtils.cp_r(state, File.join(config.fetch("app"), "storage"))
        end
        FileUtils.rm_rf(File.join(config.fetch("app"), "tmp"))
        env = NativeBench.environment(config.merge("artifact" => settings.fetch("artifact")), state).merge(
          "BUNDLER_VERSION" => "4.0.20", "LOWRAIL" => settings.fetch("enabled") ? "1" : "0",
          "LOWRAIL_STATS" => phase == "coverage" ? "" : nil,
          "LOWRAIL_DIR" => settings.fetch(phase == "stats" ? "stats_artifact" : "artifact"),
          "RUBYOPT" => "-rbundler/setup -I#{ROOT}/gem/lib -rlowrail/setup")
        binary = phase == "stats" ? config.fetch("stats_ruby") : RbConfig.ruby
        flags = ["--yjit", "--disable-zjit"]
        flags << "--yjit-stats=quiet" if phase == "stats"
        destination = File.join(output, label + ".json")
        ok = system(env, "taskset", "-c", config.fetch("cpu").to_s, binary, *flags, File.expand_path(__FILE__),
          "worker", config_file, state, treatment, phase, destination, chdir: config.fetch("app"),
          out: File.join(output, label + ".log"), err: [:child, :out])
        raise "worker failed: #{label}" unless ok
        raise "input changed" unless pins.all? { |path, sha| Digest::SHA256.file(path).hexdigest == sha } &&
          BlogProduction::Entropy.source_pin(config.fetch("app")) == source
        workers << JSON.parse(File.read(destination))
        File.write(File.join(output, "workers.json"), JSON.pretty_generate(workers))
        FileUtils.remove_entry(state)
        warn "jit-guards #{label}: complete"
      end
      next unless phase == "coverage"
      responses = workers.map { _1.fetch("exact").transform_values { |row| row.slice("status", "body_sha256", "headers_sha256") } }
      raise "two-seed responses differ" unless responses.uniq.size == 1
      workers.each do |row|
        settings = config.fetch("treatments").fetch(row.fetch("treatment"))
        next unless settings.fetch("enabled")
        before, after = row.values_at("counts_before", "counts_after")
        if config.fetch("workload") == "fizzy"
          change = delta(before.fetch("direct_sites"), after.fetch("direct_sites"))
          raise "hit/shadow/fallback gate" unless change.fetch("bucket:hit") == 20 && change.fetch("bucket:shadow") == 20 &&
            after.fetch("direct_sites").fetch("bucket:fallback", 0).zero?
        else
          change = delta(before.fetch("hits"), after.fetch("hits"))
          raise "blog hit/fallback gate" unless change.values.sort == settings.fetch("expected_hits").sort && after.fetch("fallbacks").values.sum.zero?
        end
      end
    end
    File.write(File.join(output, "result.json"), JSON.pretty_generate(workers: workers, pins: pins, app_source: source))
  end
end

command, config, *arguments = ARGV
if command == "worker"
  JitGuards.worker(JSON.parse(File.read(config)), *arguments)
elsif command == "run"
  JitGuards.run(JSON.parse(File.read(config)), File.expand_path(arguments.fetch(0)))
else
  abort "usage: jit_guards.rb run CONFIG NEW_OUTPUT"
end
