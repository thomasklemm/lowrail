# frozen_string_literal: true

# Diagnosis only. Ablations deliberately omit certificates and are NOT passes.
# ruby .../yjit_regression.rb GROUP NEW_OUTDIR
# ruby --yjit-stats=quiet .../yjit_regression.rb --stats GROUP ARM
require_relative "../request_pairs"
$LOAD_PATH.unshift(File.expand_path("../../gem/lib", __dir__))

module YjitRegression
  GROUPS = {
    "config" => %w[original guarded residue checks direct_checks direct_ivars selected],
    "global" => %w[original installed activated warmed singleton_hash],
    "shapes" => %w[original inline separate bmethod direct splat kw_literal kwargs g k v writes check mono poly lines],
    "props" => %w[original guarded each checks cached_guard],
    "props_variant" => %w[original guarded split checks_original each],
    "props_native" => %w[original split native_split checks_original native_checks_original each]
  }.freeze

  def self.install(build, runtime)
    built = build.build
    raise built[:ledger].inspect unless built[:units].size == 1
    built[:units][0]["id"] = 0
    manifest = Lowrail::Manifest.new({"format" => Lowrail::FORMAT, "ruby_description" => RUBY_DESCRIPTION,
      "certification_jit" => Lowrail.jit_mode,
      "compile_option" => Lowrail::Manifest.compile_option_fingerprint,
      "files" => {}, "units" => built[:units]}, Dir.pwd, root: Dir.pwd)
    raise "micro artifact refused: #{manifest.refusal_reason}" if manifest.refusal_reason
    raise "incompatible micro artifact" unless manifest.compatible?
    Lowrail::Guard.install(manifest)
    raise "micro unit 0 certificate declined" unless Lowrail::Guard.validate(0)
    runtime.install(manifest.units)
    [built, runtime]
  end

  def self.setup(group, arm, out = nil)
    raise "unknown arm #{group}/#{arm}" unless GROUPS.fetch(group).include?(arm)
    require "active_support/all"
    gem "inertia_rails", "3.22.0"
    require "inertia_rails/configuration"
    require "lowrail"
    require "lowrail/manifest"
    require "lowrail/guard"
    require "lowrail/inertia_config_build"
    before = RubyVM::YJIT.runtime_stats if RubyVM::YJIT.enabled?
    config = InertiaRails::Configuration.default
    controller = Object.new
    specimen = Class.new
    Object.const_set(:YjitSpecimen, specimen)
    specimen.class_eval do
      attr_accessor :config, :controller, :options
      def run(n)
        n.times { operation }
      end
    end
    runner = specimen.new
    runner.config, runner.controller = config, controller
    runner.options = config.instance_variable_get(:@options)
    guard_valid = nil
    body = case group
    when "config"
      # Both sides dispatch through the public binder with the same signature.
      unless %w[original selected].include?(arm)
        _, runtime = install(Lowrail::InertiaConfigBuild, Lowrail::Passes::InertiaConfig)
        runtime.activate
        raise "variant declined" unless runtime.valid?(config, runner.options)
      end
      residue = <<~RUBY
        bound = ::InertiaRails::Configuration.allocate
        bound.instance_variable_set(:@controller, @controller)
        bound.instance_variable_set(:@options, {**@options})
        bound
      RUBY
      case arm
      when "original", "guarded" then "@config.bind_controller(@controller)"
      when "residue" then residue
      when "selected"
        eval("module InertiaRails; class Configuration; def bind_controller(controller); #{residue.sub('(:@controller, @controller)', '(:@controller, controller)')}; end; end; end", TOPLEVEL_BINDING, __FILE__)
        "@config.bind_controller(@controller)"
      when "checks" then "::Lowrail::Passes::InertiaConfig.valid?(@config, @options)"
      when "direct_checks"
        # Same predicates, direct dispatch instead of captured native methods.
        # NOT equally safe in an app with singleton overrides.
        source = File.read(File.expand_path("../../gem/lib/lowrail/inertia_config.rb", __dir__))
        source = source.sub("DEFAULT.bind_call(options)", "options.default")
          .sub("DEFAULT_PROC.bind_call(options)", "options.default_proc")
          .sub("IDENTITY.bind_call(options)", "options.compare_by_identity?")
          .sub("KEYS.bind_call(options)", "options.keys")
        method = source[/        def valid\?.*?^        end/m]
        eval("module Lowrail; module Passes; module InertiaConfig; class << self; #{method}; end; end; end; end", TOPLEVEL_BINDING, __FILE__)
        "::Lowrail::Passes::InertiaConfig.valid?(@config, @options)"
      when "direct_ivars"
        InertiaRails::Configuration.class_eval <<~RUBY
          def self.yjit_bind(options, controller)
            bound = allocate
            bound.send(:yjit_initialize, options, controller)
            bound
          end
          private
          def yjit_initialize(options, controller)
            @controller = controller
            @options = {**options}
          end
        RUBY
        "::InertiaRails::Configuration.yjit_bind(@options, @controller)"
      end
    when "global"
      if arm != "original"
        _, runtime = install(Lowrail::InertiaConfigBuild, Lowrail::Passes::InertiaConfig)
        runtime.activate unless arm == "installed"
        200.times { config.bind_controller(controller) } if arm == "warmed"
        {}.singleton_class if arm == "singleton_hash"
      end
      # No binder calls at all in this measured operation.
      <<~RUBY
        h = {left: 11, right: 29}; a = [3, 7, 13]
        h[:left] = h[:left] + a[1]
        h[:right] + a.length + "stable".length
      RUBY
    when "shapes"
      Lowrail::G[17] = true
      Lowrail::K[17] = specimen
      Lowrail::V[17] = {specimen => true}
      specimen.class_eval do
        def target(value) = value + 7
        def keyword(value:) = value + 7
      end
      residue = "@value + 7"
      runner.instance_variable_set(:@value, 19)
      runner.instance_variable_set(:@args, [19])
      runner.instance_variable_set(:@kw, {value: 19})
      case arm
      when "original", "separate" then residue
      when "inline" then "if ::Lowrail::G[17]; #{residue}; else; @value - 31; end"
      when "bmethod" then residue
      when "direct" then "target(@value)"
      when "splat" then "target(*@args)"
      when "kw_literal" then "keyword(value: @value)"
      when "kwargs" then "keyword(**@kw)"
      when "g" then "(::Lowrail::G[17] || ::Lowrail.check(17)) && (#{residue})"
      when "k" then "(self.class.equal?(::Lowrail::K[17]) || ::Lowrail.ok?(17, self.class)) && (#{residue})"
      when "v" then "::Lowrail::V[17][self.class] && (#{residue})"
      when "writes" then "::Lowrail::G[17] = true; ::Lowrail::K[17] = self.class; ::Lowrail::V[17][self.class] = true; #{residue}"
      when "check"
        # The real check, with a prevalidated state, not a dummy method.
        _, runtime = install(Lowrail::InertiaConfigBuild, Lowrail::Passes::InertiaConfig)
        runtime.activate
        Lowrail::G[0] = true
        "::Lowrail.check(0) && (#{residue})"
      when "mono", "poly"
        types = Array.new(arm == "mono" ? 1 : 8) { Class.new { def target(value) = value + 7 } }
        types *= 8 if arm == "mono"
        runner.instance_variable_set(:@receivers, types.map(&:new))
        runner.instance_variable_set(:@index, 0)
        "@index = (@index + 1) & 7; @receivers[@index].target(@value)"
      when "lines" then "\n\n#{residue}\n\n"
      end
    when "props", "props_variant", "props_native"
      # Load the real resolver and dependencies without booting an application.
      %w[prop_cacheable prop_onceable prop_mergeable base_prop ignore_on_first_load_prop always_prop
        lazy_prop optional_prop cached_prop defer_prop merge_prop once_prop scroll_metadata scroll_prop
        props_resolver].each { require "inertia_rails/#{_1}" }
      require "lowrail/inertia_props_build"
      built, runtime = install(Lowrail::InertiaPropsBuild, Lowrail::Passes::InertiaProps)
      runtime.activate
      file = built.fetch(:files).first
      original = file.fetch(:original)
      lowered = file.fetch(:parts).map(&:to_s).join
      resolver_body = original[/    def deep_transform_props.*?^    def transform_array/m].sub(/    def transform_array\z/, "")
      if arm == "guarded"
        eval(lowered, TOPLEVEL_BINDING, file.fetch(:path))
      elsif %w[split checks_original native_split native_checks_original].include?(arm)
        require_relative "props_variant"
        lowered = PropsVariant.source(original, shape: arm)
        eval(lowered, TOPLEVEL_BINDING, file.fetch(:path))
      elsif arm == "cached_guard"
        eval(lowered.sub("::Lowrail::Passes::InertiaProps.valid?(0, props)", "::Lowrail::G[0]"), TOPLEVEL_BINDING, file.fetch(:path))
        Lowrail::G[0] = true
      elsif arm == "each"
        fast = resolver_body.sub("props.each_with_object({}) do |(key, prop), transformed_props|",
          "transformed_props = {}; props.each do |key, prop|")
        fast = fast.sub(/      end\n    end\n\n\z/, "      end; transformed_props\n    end\n\n")
        eval(original.sub(resolver_body, fast), TOPLEVEL_BINDING, file.fetch(:path))
      end
      File.write(File.join(out, "props-lowered.rb"), lowered) if out
      props = {left: 11, right: {name: "asymmetric", age: 37}, list: [2, 5], empty: {}, flag: false}
      # Recheck admission in each uncounted worker, without manufacturing Hash
      # eigenclasses in original/unchecked controls. Only positive per-entry
      # counts in the companion below prove actual receiver reflection.
      guard_valid = !!(runtime.active?(0) && Lowrail::Guard.validate(0))
      raise "props admission guard declined" unless guard_valid
      runner.instance_variable_set(:@props, props)
      runner.instance_variable_set(:@resolver, InertiaRails::PropsResolver.new(props, evaluator: ->(x) { x }))
      if arm == "checks"
        "::Lowrail::Passes::InertiaProps.valid?(0, @props)"
      elsif %w[props_variant props_native].include?(group)
        runner.instance_variable_set(:@evaluator, ->(x) { x })
        "::InertiaRails::PropsResolver.new(#{props.inspect}, evaluator: @evaluator).resolve"
      else
        "@resolver.resolve"
      end
    else
      raise "unknown group"
    end
    if arm == "bmethod" && group == "shapes"
      specimen.define_method(:operation) { @value + 7 }
    else
      specimen.class_eval("def operation\n#{body}\nend", __FILE__)
    end
    value = runner.operation
    if group == "config" && !%w[checks direct_checks].include?(arm)
      raise "wrong options" unless value.instance_variable_get(:@options) == runner.options &&
        !value.instance_variable_get(:@options).equal?(runner.options) && value.instance_variable_get(:@controller).equal?(controller)
    elsif %w[props props_variant props_native].include?(group) && arm != "checks"
      raise "wrong props" unless value.first == runner.instance_variable_get(:@props)
    elsif group == "shapes"
      raise "wrong arithmetic" unless value == 26
    elsif group == "global"
      raise "wrong unrelated operation" unless value == 38
    end
    after = RubyVM::YJIT.runtime_stats if before
    activation = before && after.select { |_, v| v.is_a?(Numeric) }.to_h { |k, v| [k, v - before.fetch(k, 0)] }
    [runner, {group: group, arm: arm, guard_valid: guard_valid, operation_source: body, activation_delta: activation}]
  end

  def self.liveness(group, arm)
    runner, metadata = setup(group, arm)
    # This is a separate native companion, NEVER an instrumented phase of a
    # measured process: Stats replaces methods and cannot simply be disabled.
    require "lowrail/stats"
    Lowrail::Stats.enable!
    Lowrail::Stats.reset_counts!
    runner.run(10)
    hits, fallbacks = Lowrail::Stats.unit_hits, Lowrail::Stats.unit_fallbacks
    expected = %w[props props_variant props_native].include?(group) &&
      %w[guarded split checks checks_original native_split native_checks_original].include?(arm)
    pass = fallbacks.empty? && (expected ? metadata.fetch(:guard_valid) && hits.fetch("0", 0).positive? : hits.empty?)
    metadata.merge(ruby: RUBY_DESCRIPTION, actual_jit: JitStability.actual, manifest_format: Lowrail::Guard.manifest&.format,
      certification_jit: Lowrail::Guard.manifest&.certification_jit, operations: 10,
      fast_authorization_expected: expected, hits: hits, fallbacks: fallbacks, pass: pass)
  end

  def self.census(group, arm)
    raise "census requires a props_native check arm" unless group == "props_native" &&
      %w[checks_original native_checks_original].include?(arm)
    runner, metadata = setup(group, arm)
    guard = arm == "checks_original" ? Lowrail::Passes::InertiaProps.method(:valid?) : PropsVariant.method(:valid_native?)
    inside = false
    entries = authorizations = 0
    events = Hash.new(0)
    # Disposable untimed process. No global return/class/end observer and no
    # observer in a measured worker: only the guard's own ISeq is targeted.
    scope = TracePoint.new(:call, :return) do |event|
      if event.event == :call
        entries += 1
        inside = true
      else
        authorizations += 1 if event.return_value
        inside = false
      end
    end
    calls = TracePoint.new(:c_call) do |event|
      events["#{event.defined_class}##{event.method_id}"] += 1 if inside
    end
    scope.enable(target: guard) { calls.enable { runner.run(1) } }
    raise "census did not fully authorize" unless metadata.fetch(:guard_valid) && entries == 2 && authorizations == entries
    metadata.merge(ruby: RUBY_DESCRIPTION, operations: 1, entries: entries,
      authorizations: authorizations, c_calls: events, measured: false)
  end
end

if ARGV.first == "--census"
  JitStability.assert_mode!
  puts JSON.pretty_generate(YjitRegression.census(*ARGV.drop(1)))
  exit
end

if ARGV.first == "--liveness"
  JitStability.assert_mode!
  result = YjitRegression.liveness(*ARGV.drop(1))
  puts JSON.generate(result)
  abort "untimed liveness failed; no measured window permitted" unless result.fetch(:pass)
  exit
end

if %w[--worker --stats].include?(ARGV.first)
  stats = ARGV.shift == "--stats"
  group, arm = ARGV
  JitStability.assert_mode! unless stats
  unless stats
    proof = JSON.parse(File.read(ENV.fetch("YJIT_DIAG_LIVENESS")))
    claim = proof.fetch("arms").fetch(arm)
    raise "missing or stale untimed liveness proof" unless claim.fetch("pass") && claim.fetch("group") == group &&
      claim.fetch("actual_jit") == JitStability.mode &&
      proof.fetch("sources").all? { |path, sha| Digest::SHA256.file(path).hexdigest == sha }
  end
  runner, metadata = YjitRegression.setup(group, arm)
  raise "Stats must be disabled in measured workers" if !stats && defined?(Lowrail::Stats) && Lowrail::Stats.enabled?
  runner.run(2000)
  warm = JitStability.warm { |n| runner.run(n) } if JitStability.enabled?
  if stats
    require "lowrail/jit_diagnostics"
    # A separate instrumented native run, never priced as ordinary YJIT Ir.
    before = RubyVM::YJIT.runtime_stats
    runner.run(1000)
    after = RubyVM::YJIT.runtime_stats
    delta = after.select { |_, v| v.is_a?(Numeric) }.to_h { |k, v| [k, v - before.fetch(k, 0)] }
    puts JSON.generate(metadata.merge(ruby: RUBY_DESCRIPTION, calls: 1000, warmup: warm,
      before: before, after: after, delta: delta, diagnostics: Lowrail::JitDiagnostics.snapshot))
    exit
  end
  require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
  windows = HeapWindows.windows(Integer(ENV.fetch("BENCH_REQUESTS")))
  observer = JitStability.method(:snapshot) if JitStability.enabled?
  anchors = HeapWindows.run(windows, observe: observer) { |n, _| runner.run(n) }
  puts "LOWRAIL_BENCH #{JSON.generate(metadata.merge(**JitStability.state, ruby: RUBY_DESCRIPTION,
    windows: windows, jit_warmup: warm, heap_anchors: anchors, ar_installed: 0))}"
  exit
end

group, out = ARGV
abort "usage: yjit_regression.rb GROUP NEW_OUTDIR" unless YjitRegression::GROUPS.key?(group) && out
out = File.expand_path(out)
raise "output must be new" if File.exist?(out)
raise "at most four workers" if Integer(ENV.fetch("BENCH_JOBS", "4")) > 4
FileUtils.mkdir_p(out, mode: 0o700)
base = {"RUBYOPT" => nil, "LOWRAIL_STATS" => nil, "LOWRAIL_OUTCOMES" => nil, "LOWRAIL_JIT_DIAGNOSTICS" => nil}
environments = (%w[off_a off_b] + YjitRegression::GROUPS.fetch(group).drop(1)).to_h do |label|
  arm = label.start_with?("off_") ? "original" : label
  [label, base.merge("YJIT_DIAG_GROUP" => group, "YJIT_DIAG_ARM" => arm,
    "YJIT_DIAG_LIVENESS" => File.join(out, "liveness.json"))]
end
# request_pairs passes a route argument; a tiny launcher avoids changing its API.
launcher = File.join(out, "worker.rb")
File.write(launcher, "ARGV.replace(['--worker', ENV.fetch('YJIT_DIAG_GROUP'), ENV.fetch('YJIT_DIAG_ARM')]); load #{File.expand_path(__FILE__).dump}\n")
sources = [__FILE__, File.expand_path("props_variant.rb", __dir__),
  *Dir[File.expand_path("../../gem/lib/**/*.rb", __dir__)],
  *Dir[File.expand_path("../../gem/ext/lowrail_native/*.{c,rb}", __dir__)],
  *Dir[File.expand_path("../../gem/lib/lowrail/native/**/*.{so,bundle,dll}", __dir__)],
  *%w[request_pairs heap_windows jit_stability].map { File.expand_path("../#{_1}.rb", __dir__) }].to_h { [_1, Digest::SHA256.file(_1).hexdigest] }
# Complete every counted admission probe before even the Valgrind preflight.
# The original/unchecked controls must have zero authorizations and fallbacks;
# exact-guard arms must positively authorize with zero fallbacks. Retain failed
# output, but refuse to launch a cohort. Measured workers recheck guard_valid.
liveness = YjitRegression::GROUPS.fetch(group).to_h do |arm|
  stdout, stderr, status = Open3.capture3(base, RbConfig.ruby, *JitStability.flags,
    __FILE__, "--liveness", group, arm)
  File.write(File.join(out, "liveness-#{arm}.stdout"), stdout)
  File.write(File.join(out, "liveness-#{arm}.log"), stderr)
  raise "#{arm}: untimed liveness refused; no cohort started; inspect #{out}" unless status.success?
  result = JSON.parse(stdout.lines.last)
  raise "#{arm}: liveness/JIT mismatch" unless result.fetch("pass") && result.fetch("actual_jit") == JitStability.mode
  [arm, result]
end
raise "sources changed during liveness" unless sources.all? { |p, sha| Digest::SHA256.file(p).hexdigest == sha }
File.write(File.join(out, "liveness.json"), JSON.pretty_generate(arms: liveness, sources: sources))
metadata = {seed: 41231, rounds: 6, workers: {}, sources: sources, group: group, diagnosis_only: true, liveness: liveness}
accepted = RequestPairs.heap_instructions(environments, Dir.pwd, out, "unused", metadata,
  worker: launcher, requests: Integer(ENV.fetch("BENCH_REQUESTS", "1000")))
raise "sources changed" unless sources.all? { |p, sha| Digest::SHA256.file(p).hexdigest == sha }
File.write(File.join(out, "verdict.json"), JSON.pretty_generate(accepted: accepted))
exit(accepted ? 0 : 2)
