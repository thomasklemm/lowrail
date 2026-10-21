# frozen_string_literal: true

# Native direction finding, NOT the lowrail bench/Callgrind acceptance gate.
# micro: real Inertia resolver; requests: guard-tax ablation on real blog GETs.
require_relative "../request_pairs"
require_relative "method_seal"
$LOAD_PATH.unshift(File.expand_path("../../gem/lib", __dir__))
require "lowrail"
require "lowrail/freeze_audit"

module MethodSealNative
  ACTIVE = [true]
  ARMS = %w[off_a off_b guarded flag tripwire].freeze
  SINGLETON = Kernel.instance_method(:singleton_class)
  METHOD = Module.instance_method(:instance_method)
  PUBLIC = Module.instance_method(:public_method_defined?)

  def self.guarded?(view)
    holder = SINGLETON.bind_call(view)
    PUBLIC.bind_call(holder, :link_to) && METHOD.bind_call(holder, :link_to) == @helper
  end

  def self.flag?(view)
    ACTIVE[0] && Lowrail::Native.exact_class?(view, @view_class)
  end

  def self.loop_work(n)
    n.times { @operation.call }
  end

  def self.setup(kind, arm, route)
    raise "native predicate unavailable" unless defined?(Lowrail::Native)
    if kind == "micro"
      require_relative "props_variant"
      factory = File.expand_path("yjit_regression.rb", __dir__)
      prefix, tail = File.read(factory).split("\nif ARGV.first == \"--census\"\n", 2)
      raise "factory entrypoint changed" unless tail
      eval(prefix, TOPLEVEL_BINDING, factory)
      if %w[flag tripwire].include?(arm)
        PropsVariant.singleton_class.prepend(Module.new do
          def source(original, **kwargs)
            super.sub("::Lowrail::Passes::InertiaProps.valid?(0, props)",
              "(::MethodSealNative::ACTIVE[0] && ::Ractor.current.equal?(::Ractor.main) && ::Lowrail::Native.exact_class?(props, ::Hash))")
          end
        end)
      end
      runner, metadata = YjitRegression.setup("props_variant", arm.start_with?("off_") ? "original" : "split")
      @operation = -> { runner.operation }
      raise "wrong resolver result" unless @operation.call.first == {left: 11, right: {name: "asymmetric", age: 37}, list: [2, 5], empty: {}, flag: false}
      @holders = [Hash, Enumerable]
    else
      require File.expand_path("config/environment", Dir.pwd)
      require "rack/mock"
      Rails.application.eager_load!
      Rails.logger.level = :warn
      ActiveRecord::Base.logger = nil
      # Same wrapper in all arms. It adds admission work only, never replaces
      # Rails' helper body. Contrasts price guard tax, NOT a specialization win.
      @view_class = ArticlesController.view_context_class
      check = case arm
      when "guarded" then "raise 'guard refused' unless ::MethodSealNative.guarded?(self)"
      when "flag", "tripwire" then "raise 'receiver refused' unless ::MethodSealNative.flag?(self)"
      else ""
      end
      wrapper = Module.new
      wrapper.module_eval("def link_to(...); #{check}; super; end", __FILE__, __LINE__)
      @view_class.prepend(wrapper)
      @helper = @view_class.instance_method(:link_to)
      session = Rack::MockRequest.new(Rails.application)
      @operation = lambda do
        response = session.get(route, "HTTP_HOST" => "localhost", "HTTPS" => "on")
        raise "HTTP #{response.status}" unless response.status == 200
        response
      end
      @holders = [ActionView::Helpers::UrlHelper, ActionView::Helpers::TagHelper]
      metadata = {"scope" => "helper admission cost ablation only", "path" => route}
    end
    loop_work(2000)
    if arm == "tripwire"
      @seal = MethodSeal::Session.new(holders: @holders).start!
      remove_const(:ACTIVE)
      const_set(:ACTIVE, @seal.active)
    else
      ENV["LOWRAIL_FREEZE"] = "1"
      @freeze = Lowrail::FreezeAudit::Session.new(profile: "holders", holders: @holders).start!(audit: false)
    end
    metadata
  end

  def self.worker(kind, arm, route)
    metadata = setup(kind, arm, route)
    count = kind == "micro" ? 10_000 : 200
    loop_work(200) # exercise the post-seal loop too; fixed, no retry-to-green
    GC.start
    jit_before = JitStability.snapshot
    allocated = GC.stat(:total_allocated_objects)
    cpu = Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID)
    wall = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    loop_work(count)
    wall = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - wall) * 1e6 / count
    cpu = (Process.clock_gettime(Process::CLOCK_PROCESS_CPUTIME_ID) - cpu) * 1e6 / count
    allocations = (GC.stat(:total_allocated_objects) - allocated).fdiv(count)
    jit_after = JitStability.snapshot
    raise "tripwire deoptimized: not an active-observer price" if @seal && !@seal.active[0]
    {wall_us: wall, cpu_us: cpu, allocations: allocations, n: count,
      jit_before: jit_before, jit_after: jit_after, yjit: RubyVM::YJIT.enabled?,
      metadata: metadata, contract: @seal ? @seal.finish! : @freeze.finish!}
  end

  def self.controller(kind, app, out, route)
    raise "new output required" if File.exist?(out)
    FileUtils.mkdir_p(out, mode: 0o700)
    rounds = []
    rng = Random.new(41231)
    6.times do |round|
      samples = {}
      ARMS.shuffle(random: rng).each do |arm|
        environment = {"RAILS_ENV" => "production", "SECRET_KEY_BASE_DUMMY" => "1", "LOWRAIL" => "0",
          "RUBYOPT" => nil, "LOWRAIL_OUTCOMES" => nil, "LOWRAIL_STATS" => nil, "BENCH_JIT" => "1"}
        stdout, stderr, status = Open3.capture3(environment, RbConfig.ruby, "--yjit", "--yjit-stats=quiet",
          File.expand_path(__FILE__), "worker", kind, arm, route, chdir: app)
        File.write(File.join(out, "#{round}-#{arm}.log"), stderr)
        File.write(File.join(out, "#{round}-#{arm}.stdout"), stdout)
        raise "worker failed: #{round}/#{arm}" unless status.success?
        samples[arm] = JSON.parse(stdout.lines.last)
      end
      rounds << samples
      File.write(File.join(out, "rounds.json"), JSON.pretty_generate(rounds))
      puts "round #{round + 1}/6"
      $stdout.flush
    end
    result = RequestPairs.summarize(rounds, seed: 41231, tolerance: 5.0)
    result[:scope] = kind == "micro" ? "real resolver, experimental specialization" : "request guard-tax ablation, NOT speedup versus stock Rails"
    result[:direction_finding_only] = true
    result[:sources] = [__FILE__, File.join(__dir__, "method_seal.rb"), File.join(__dir__, "props_variant.rb"),
      File.join(__dir__, "yjit_regression.rb")].to_h { [_1, Digest::SHA256.file(_1).hexdigest] }
    File.write(File.join(out, "summary.json"), JSON.pretty_generate(result))
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV.first == "worker"
    _, kind, arm, route = ARGV
    puts JSON.generate(MethodSealNative.worker(kind, arm, route))
  else
    kind, app, out, route = ARGV
    abort "usage: method_seal_native.rb micro|requests APP NEW_OUTPUT [PATH]" unless %w[micro requests].include?(kind) && app && out
    MethodSealNative.controller(kind, File.expand_path(app), File.expand_path(out), route || "/articles/1")
  end
end
