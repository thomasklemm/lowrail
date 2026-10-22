# frozen_string_literal: true

# Bet Z: finite, diagnostic Rack screen. No production install or admission.
# Reuses NativeBench's paired estimator/digests and the declared entropy sites.
require "json"
require "fileutils"
require "digest"
require "rbconfig"
require "open3"

module JitHooks
  ROOT = File.expand_path("../..", __dir__)
  SCRIPT = File.expand_path(__FILE__)
  module_function

  def snapshot
    stats = if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?
      RubyVM::ZJIT.stats
    elsif RubyVM::YJIT.enabled?
      RubyVM::YJIT.runtime_stats
    end
    (stats || {}).select { |_, value| value.is_a?(Numeric) }
  end

  def worker(config, phase, destination)
    require File.join(config.fetch("app"), "config/boot")
    require "bundler/setup"
    require File.join(ROOT, "fixtures/corpus/blog_entropy")
    load config.fetch("harness")
    require "lowrail/setup" if config["artifact"]
    require File.join(config.fetch("app"), "config/environment")
    require "rack/mock"
    Rails.logger.level = :fatal
    ActiveRecord::Base.logger = nil
    Rails.application.eager_load!
    if config["direct_site"]
      raise "historical DirectSite requires Ruby 4.0.7" unless RUBY_VERSION == "4.0.7"
      load config.fetch("direct_site")
      ARRequestSites.install(config, config["direct_on"] ? "on" : "off")
      ARRequestSites.counting = phase == "calls"
    end
    mode = if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?
      "zjit"
    elsif RubyVM::YJIT.enabled?
      "yjit"
    else
      "interpreter"
    end
    raise "wrong JIT: #{mode}" unless mode == config.fetch("jit")
    path = config.fetch("workload") == "blog" ? "/articles/1" : "/buckets"
    headers = {"HTTP_HOST" => "localhost", "HTTPS" => "on", "HTTP_X_REQUEST_ID" => "bet-z",
      "HTTP_USER_AGENT" => "Mozilla/5.0 Firefox/140.0"}
    if config.fetch("workload") == "fizzy"
      require "action_dispatch/testing/test_request"
      session = Session.joins(:user).find_by!(users: {email_address: "epoch@example.invalid"})
      request = ActionDispatch::TestRequest.create
      request.env.merge!(Rails.application.env_config)
      request.cookie_jar.signed[:session_token] = session.signed_id
      headers["HTTP_COOKIE"] = request.cookie_jar.to_header
    end
    rack = Rack::MockRequest.new(Rails.application)
    invoke = -> { rack.get(path, headers).tap { raise "HTTP #{_1.status}" unless _1.status == 200 } }
    config.fetch("warmup", 1000).times { invoke.call }
    exact = nil
    if phase == "exact"
      policy = JSON.parse(File.read(config.fetch("policy")))
      control = BlogProduction::Entropy.validate(config.fetch("app"), policy: policy)
      raise control.fetch("reason") unless control.fetch("active")
      BlogProduction::Entropy.install(policy)
      exact = [0, 1].to_h do |seed|
        response, evidence = BlogProduction::Entropy.with(seed, "GET #{path}", wall_clock: true, &invoke)
        raise "entropy errors: #{evidence.fetch('errors')}" unless evidence.fetch("errors").empty?
        [seed, NativeBench.response_digest(response)]
      end
    end
    tables = if config.fetch("workload") == "blog"
      {"PRE_CONTENT_STRINGS" => ActionView::Helpers::TagHelper::PRE_CONTENT_STRINGS,
        "TAG_TYPES" => ActionView::Helpers::TagHelper::TAG_TYPES}
    else
      {}
    end
    calls = Hash.new(0)
    trace = if phase == "calls"
      TracePoint.new(:call, :c_call) do |event|
        if event.event == :c_call && event.method_id == :[]
          tables.each { |name, table| calls["DATA##{name}#[]"] += 1 if event.self.equal?(table) }
        end
        owner = event.defined_class.to_s
        next unless owner.start_with?("ActionView", "ActionController", "ActiveRecord", "ActiveModel", "ARRequestSites")
        parameters = event.event == :call ? event.parameters : []
        key = [owner, event.method_id, parameters.any? { _1.first == :keyrest } ? "kwrest" : "other"].join("#")
        calls[key] += 1
      end
    end
    n = %w[exact calls].include?(phase) ? 10 : config.fetch("samples", 300)
    jit_before = snapshot if phase == "stats"
    alloc_before, gc_before = GC.stat(:total_allocated_objects), GC.count
    started = NativeBench.clock
    trace&.enable
    n.times { invoke.call }
    trace&.disable
    elapsed = NativeBench.clock - started
    allocated = GC.stat(:total_allocated_objects) - alloc_before
    jit_after = snapshot if phase == "stats"
    data = {ruby: RUBY_DESCRIPTION, jit: mode, binary_sha256: Digest::SHA256.file("/proc/self/exe").hexdigest,
      workload: config.fetch("workload"), phase: phase, requests: n, warmup: config.fetch("warmup", 1000),
      allocations_per_request: allocated.fdiv(n), collections: GC.count - gc_before,
      wall_us_per_request: phase == "wall" ? elapsed * 1_000_000 / n : nil,
      exact: exact, calls_per_request: calls.transform_values { _1.fdiv(n) }, jit_before: jit_before,
      jit_delta: jit_before && jit_after.to_h { |key, value| [key, value - jit_before.fetch(key, 0)] },
      direct_site_counts: config["direct_site"] && ARRequestSites.counts,
      lowrail: defined?(Lowrail) && Lowrail.respond_to?(:refusal_reason) && {refusal: Lowrail.refusal_reason, units: Lowrail.manifest&.units&.map { _1.slice("id", "pass") },
        admissions: %w[FormScaffold TokenTag CollectionRender].to_h { |name|
          runtime = Lowrail.const_get(name, false)
          [name, {admitted: runtime.admitted?, refusal: runtime.refusal}]
        }}}
    File.write(destination, JSON.pretty_generate(data))
  end

  def run(config, output)
    raise "new output required" if File.exist?(output)
    FileUtils.mkdir_p(output, mode: 0o700)
    load config.fetch("harness")
    rows = []
    config.fetch("phases", %w[exact stats wall]).each do |phase|
      (phase == "wall" ? 3 : 1).times do |round|
        config.fetch("arms").keys.rotate(round).each do |arm|
          candidate = config.merge(config.fetch("arms").fetch(arm))
          label = "#{phase}-#{round}-#{arm}"
          state = File.join(output, label + "-state")
          FileUtils.cp_r(config.fetch("seed"), state)
          env = {"RAILS_ENV" => "production", "RACK_ENV" => "production", "SKIP_TELEMETRY" => "1",
            "RAILS_LOG_LEVEL" => "fatal", "LOWRAIL" => candidate["lowrail"] ? "1" : "0",
            "LOWRAIL_SEALED" => candidate["artifact"] ? "1" : nil, "LOWRAIL_STATS" => nil,
            "LOWRAIL_UNITS" => candidate["units"], "RUBYOPT" => nil, "RUBY_YJIT_ENABLE" => nil,
            "RUBY_ZJIT_ENABLE" => nil, "SECRET_KEY_BASE_DUMMY" => nil,
            "SECRET_KEY_BASE" => "lowrail-disposable-blog-companion-only-" * 4,
            # Bundler autoswitch re-execs without Ruby CLI flags. Pin before setup.
            "BUNDLER_VERSION" => config.fetch("bundler_version", "4.0.20"),
            "BUNDLE_GEMFILE" => config.fetch("gemfile"), "BUNDLE_PATH" => config["bundle_path"],
            "LOWRAIL_ROOT" => config.fetch("app"), "LOWRAIL_DIR" => config["artifact"]}
          %w[primary cache queue cable].each do |database|
            env[database == "primary" ? "DATABASE_URL" : "#{database.upcase}_DATABASE_URL"] = "sqlite3:#{state}/#{database}.sqlite3"
          end
          file = File.join(output, label + "-config.json")
          File.write(file, JSON.pretty_generate(candidate))
          flags = candidate.fetch("flags") + (phase == "stats" ? candidate.fetch("stats_flags", []) : [])
          destination = File.join(output, label + ".json")
          command = ["taskset", "-c", config.fetch("cpu", 2).to_s, candidate.fetch("ruby"), *flags,
            "-rbundler/setup", "-I#{ROOT}/gem/lib", SCRIPT, "worker", file, phase, destination]
          raise "worker failed #{label}" unless system(env, *command, chdir: config.fetch("app"),
            out: File.join(output, label + ".log"), err: [:child, :out])
          rows << JSON.parse(File.read(destination)).merge("arm" => arm, "round" => round)
          FileUtils.remove_entry(state)
          File.write(File.join(output, "workers.json"), JSON.pretty_generate(rows))
          warn "jit-hooks #{label}: complete"
        end
      end
      if phase == "exact"
        raise "exact response mismatch" unless rows.select { _1.fetch("phase") == "exact" }.map { _1.fetch("exact") }.uniq.size == 1
      end
    end
    walls = config.fetch("arms").keys.to_h { |arm|
      [arm, rows.select { _1.fetch("phase") == "wall" && _1.fetch("arm") == arm }.map { _1.fetch("wall_us_per_request") }]
    }
    summary = walls.values.all?(&:empty?) ? {} : walls.except("off_a").transform_values { NativeBench.comparison(walls.fetch("off_a"), _1) }
    File.write(File.join(output, "result.json"), JSON.pretty_generate(config: config, workers: rows, summary: summary))
    puts JSON.pretty_generate(summary)
  end

  def micro(config, destination)
    load config.fetch("harness")
    code = <<~'RUBY'
      require "json"
      require "digest"
      abort "wrong JIT" unless RubyVM::ZJIT.enabled? == (ARGV.fetch(0) == "zjit")
      def empty_keywords(**kwargs) = kwargs.empty?
      def hot_loop(n)
        i = 0
        matches = 0
        while i < n
          matches += 1 if empty_keywords
          i += 1
        end
        matches
      end
      # Heat the caller too: one long loop compiles the callee, not hot_loop.
      100.times { abort "wrong warmup" unless hot_loop(2_000) == 2_000 }
      GC.start
      objects = GC.stat(:total_allocated_objects)
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      result = hot_loop(2_000_000)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      objects = GC.stat(:total_allocated_objects) - objects
      abort "wrong result" unless result == 2_000_000
      puts JSON.generate(wall_seconds: elapsed, objects: objects, result: result,
        jit: RubyVM::ZJIT.enabled?, binary_sha256: Digest::SHA256.file("/proc/self/exe").hexdigest,
        ruby: RUBY_DESCRIPTION)
    RUBY
    rows = []
    10.times do |round|
      %w[interpreter zjit].rotate(round).each do |mode|
        %w[off_a off_b on].rotate(round).each do |arm|
          ruby = config.fetch(arm == "on" ? "patched" : "base")
          out, err, status = Open3.capture3({"RUBYOPT" => nil, "RUBY_YJIT_ENABLE" => nil, "RUBY_ZJIT_ENABLE" => nil},
            "taskset", "-c", config.fetch("cpu", 2).to_s, ruby,
            *(mode == "zjit" ? ["--zjit"] : ["--disable-yjit", "--disable-zjit"]), "-e", code, mode)
          raise "micro worker failed: #{err}" unless status.success?
          rows << JSON.parse(out).merge("arm" => arm, "mode" => mode, "round" => round)
        end
      end
    end
    summary = %w[interpreter zjit].to_h do |mode|
      walls = %w[off_a off_b on].to_h { |arm|
        [arm, rows.select { _1.fetch("mode") == mode && _1.fetch("arm") == arm }.map { _1.fetch("wall_seconds") }]
      }
      [mode, walls.except("off_a").transform_values { NativeBench.comparison(walls.fetch("off_a"), _1) }]
    end
    File.write(destination, JSON.pretty_generate(config: config, code: code, workers: rows, summary: summary))
    puts JSON.pretty_generate(summary)
  end
end

if $PROGRAM_NAME == __FILE__
  command, file, *args = ARGV
  config = JSON.parse(File.read(file))
  case command
  when "worker" then JitHooks.worker(config, *args)
  when "run" then JitHooks.run(config, File.expand_path(args.fetch(0)))
  when "micro" then JitHooks.micro(config, File.expand_path(args.fetch(0)))
  else abort "usage: jit_hooks.rb {run|micro} CONFIG OUTPUT"
  end
end
