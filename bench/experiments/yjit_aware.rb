# frozen_string_literal: true

# Bet K: finite diagnostic screen, not an instruction/RPS price or admission.
# Reuses bet A's Rack clients and bet F's external query-program overlay.
require File.expand_path("config/boot", Dir.pwd) if ARGV.first == "worker"
require "json"
require "fileutils"
require "digest"
require "rbconfig"

module YjitAware
  ROOT = File.expand_path("../..", __dir__)
  SCRIPT = File.expand_path(__FILE__)
  module_function

  def snapshot
    RubyVM::YJIT.runtime_stats.select { |_, value| value.is_a?(Numeric) }
  end

  def difference(before, after)
    after.to_h { |key, value| [key, before.key?(key) ? value - before.fetch(key) : nil] }
  end

  def compiled_methods
    names = %w[Lowrail::FormScaffold Lowrail::TokenTag Lowrail::CollectionRender
      Lowrail::FormScaffold::Variant Lowrail::TokenTag::Variant Lowrail::CollectionRender::Variant
      ARRequestSites ARRequestSites::Site ARRequestSites::DirectQuery]
    names.flat_map do |name|
      holder = Lowrail.loaded_constant(name)
      next [] unless holder
      [holder, holder.singleton_class].flat_map do |type|
        (type.instance_methods(false) + type.private_instance_methods(false)).uniq.filter_map do |method|
          body = type.instance_method(method)
          iseq = RubyVM::InstructionSequence.of(body)
          next unless iseq
          {name: "#{name}#{type == holder ? '#' : '.'}#{method}", path: iseq.path,
            line: iseq.first_lineno, compiled: RubyVM::YJIT.insns_compiled(iseq)}
        end
      end
    end
  end

  def worker(config, state, arm, phase, destination)
    load config.fetch("harness")
    require File.join(ROOT, "fixtures/corpus/blog_production")
    require File.join(config.fetch("app"), "config/environment")
    raise "wrong execution mode" unless RUBY_VERSION == "4.0.7" && Rails.version == "8.1.4" &&
      Rails.env.production? && RubyVM::YJIT.enabled? && !(defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?)
    require config.fetch("exploration_setup") if config["exploration_setup"]
    NativeBench::Exploration.install(config: config, state: state, arm: arm) if config["exploration_setup"]
    workload = NativeBench.routes(config, state, arm).values.fetch(0)
    invoke = -> { workload.call.tap { raise "HTTP #{_1.status}" unless _1.status == 200 } }
    config.fetch("warmup").times { invoke.call }
    if arm == "on" && config.fetch("workload") == "blog"
      %w[Lowrail::FormScaffold Lowrail::TokenTag Lowrail::CollectionRender].each do |name|
        runtime = Lowrail.loaded_constant(name)
        raise "inactive #{name}: #{runtime&.refusal}" unless runtime&.admitted?
      end
    end
    if phase == "coverage"
      unless config["exploration_setup"]
        policy = JSON.parse(File.read(config.fetch("entropy_policy")))
        control = BlogProduction::Entropy.validate(config.fetch("app"), policy: policy)
        raise control.fetch("reason") unless control.fetch("active")
        BlogProduction::Entropy.install(policy)
      end
      exact = [0, 1].to_h do |seed|
        response, evidence = if config["exploration_setup"]
          NativeBench::Exploration.validation_request(route: "GET /buckets", seed: seed, request: invoke)
        else
          BlogProduction::Entropy.with(seed, "GET /articles/1", wall_clock: true, &invoke)
        end
        raise "entropy companion rejected" unless evidence.fetch("errors", []).empty? && evidence.fetch("passed", true)
        [seed, NativeBench.response_digest(response).merge(evidence: evidence)]
      end
    end
    count_before = NativeBench.counts if phase == "coverage"
    n = phase == "coverage" ? 10 : config.fetch("samples")
    jit_before = snapshot if phase == "stats"
    alloc_before, gc_before = GC.stat(:total_allocated_objects), GC.count
    started = NativeBench.clock
    n.times { invoke.call }
    seconds = NativeBench.clock - started
    allocated, collections = GC.stat(:total_allocated_objects) - alloc_before, GC.count - gc_before
    jit_after = snapshot if phase == "stats"
    result = {arm: arm, phase: phase, ruby: RUBY_DESCRIPTION, ruby_sha256: Digest::SHA256.file("/proc/self/exe").hexdigest,
      requests: n, warmup: config.fetch("warmup"), allocations_per_request: allocated.fdiv(n), collections: collections,
      wall_us_per_request: phase == "wall" ? seconds * 1_000_000 / n : nil,
      exact: exact, counts_before: count_before, counts_after: phase == "coverage" ? NativeBench.counts : nil,
      jit_before: jit_before, jit_after: jit_after, jit_delta: phase == "stats" ? difference(jit_before, jit_after) : nil,
      refusal: Lowrail.refusal_reason}
    if phase == "stats"
      delta = result.fetch(:jit_delta)
      retired = delta.fetch(:yjit_insns_count) - delta.fetch(:side_exit_count)
      result[:window_ratio_in_yjit] = 100.0 * retired / (retired + delta.fetch(:vm_insns_count))
      result[:compiled_methods] = compiled_methods
      # Trace samples include boot/warmup: explanatory locations, not window counts.
      RubyVM::YJIT.dump_exit_locations(destination + ".exits") if config["trace"]
    end
    File.write(destination, JSON.pretty_generate(result))
  end

  def run(config, output)
    raise "new output directory required" if File.exist?(output)
    FileUtils.mkdir_p(output, mode: 0o700)
    load config.fetch("harness")
    require File.join(ROOT, "fixtures/corpus/blog_production")
    paths = [SCRIPT, config.fetch("harness"), config.fetch("entropy_policy"),
      File.join(config.fetch("app"), "Gemfile.lock"), *config.fetch("extra_sources", []),
      *Dir[File.join(ROOT, "gem/lib/**/*.{rb,so}")], *Dir[File.join(config.fetch("artifact"), "**/*")],
      *Dir[File.join(config.fetch("stats_artifact"), "**/*")]].select { File.file?(_1) }
    pins = paths.to_h { [_1, Digest::SHA256.file(_1).hexdigest] }
    source = BlogProduction::Entropy.source_pin(config.fetch("app"))
    File.write(File.join(output, "protocol.json"), JSON.pretty_generate(config: config, pins: pins, app_source: source))
    config_path = File.join(output, "config.json")
    File.write(config_path, JSON.generate(config))
    workers = []
    # A/A and treatment, retained in full. Wall-time is stock Ruby, stats OFF.
    config.fetch("phases", %w[coverage stats wall]).each do |phase|
      rounds = phase == "wall" ? 3 : 1
      rounds.times do |round|
        %w[off_a on off_b].rotate(round).each do |arm|
          label = "#{phase}-#{round}-#{arm}"
          state = File.join(output, label + "-state")
          FileUtils.cp_r(config.fetch("seed"), state)
          if config.fetch("workload") == "blog"
            FileUtils.rm_rf(File.join(config.fetch("app"), "storage"))
            FileUtils.cp_r(state, File.join(config.fetch("app"), "storage"))
          end
          FileUtils.rm_rf(File.join(config.fetch("app"), "tmp"))
          env = NativeBench.environment(config, state).merge("LOWRAIL" => arm == "on" ? "1" : "0",
            "LOWRAIL_STATS" => phase == "coverage" ? "" : nil,
            "LOWRAIL_DIR" => phase == "stats" ? config.fetch("stats_artifact") : config.fetch("artifact"),
            "RUBYOPT" => "-rbundler/setup -I#{ROOT}/gem/lib -rlowrail/setup")
          binary = phase == "stats" ? config.fetch("stats_ruby") : RbConfig.ruby
          flags = ["--yjit", "--disable-zjit"]
          flags << "--yjit-stats=quiet" if phase == "stats"
          flags << "--yjit-trace-exits-sample-rate=101" if phase == "stats" && config["trace"]
          destination = File.join(output, label + ".json")
          command = ["taskset", "-c", config.fetch("cpu", 2).to_s, binary, *flags, SCRIPT, "worker", config_path, state, arm, phase, destination]
          ok = system(env, *command, chdir: config.fetch("app"), out: File.join(output, label + ".log"), err: [:child, :out])
          raise "worker failed: #{label}" unless ok
          raise "changed input" unless pins.all? { |path, sha| Digest::SHA256.file(path).hexdigest == sha } &&
            BlogProduction::Entropy.source_pin(config.fetch("app")) == source
          workers << JSON.parse(File.read(destination)).merge("round" => round)
          File.write(File.join(output, "workers.json"), JSON.pretty_generate(workers))
          FileUtils.remove_entry(state)
          warn "yjit-aware #{label}: complete"
        end
      end
      if phase == "coverage"
        coverage = workers.select { _1.fetch("phase") == "coverage" }
        identities = coverage.map do |row|
          row.fetch("exact").transform_values { _1.slice("status", "body_sha256", "headers_sha256") }
        end
        raise "response companions differ" unless identities.uniq.size == 1
        on = coverage.find { _1.fetch("arm") == "on" }
        before, after = on.fetch("counts_before"), on.fetch("counts_after")
        if config.fetch("workload") == "blog"
          hits = difference(before.fetch("hits"), after.fetch("hits"))
          raise "blog hit/fallback gate" unless hits.values.sort == [10, 10, 40] && after.fetch("fallbacks").values.sum.zero?
        else
          delta = difference(before.fetch("direct_sites"), after.fetch("direct_sites"))
          raise "Fizzy hit/shadow/fallback gate" unless delta.fetch("bucket:hit") == 20 &&
            delta.fetch("bucket:shadow") == 20 && after.fetch("direct_sites").fetch("bucket:fallback", 0).zero?
        end
      end
    end
    wall = workers.select { _1.fetch("phase") == "wall" }
    values = %w[off_a on off_b].to_h { |arm| [arm, wall.select { _1.fetch("arm") == arm }.map { _1.fetch("wall_us_per_request") }] }
    summary = wall.empty? ? {} : {aa: NativeBench.comparison(values.fetch("off_a"), values.fetch("off_b")),
      on_off: NativeBench.comparison(values.fetch("off_a"), values.fetch("on"))}
    File.write(File.join(output, "result.json"), JSON.pretty_generate(workers: workers, summary: summary, pins: pins, app_source: source))
    puts JSON.pretty_generate(summary)
  end
end

command = ARGV.shift
if command == "worker"
  file, state, arm, phase, destination = ARGV
  YjitAware.worker(JSON.parse(File.read(file)), state, arm, phase, destination)
else
  config, output = ARGV
  abort "usage: yjit_aware.rb run CONFIG NEW_OUTPUT" unless command == "run" && config && output
  YjitAware.run(JSON.parse(File.read(config)), File.expand_path(output))
end
