# frozen_string_literal: true

# Preparation only: no measured-worker/cohort entrypoint. Reuse the published
# native props factory, fresh inputs and lifetime gates without editing them.
require "digest"
require_relative "props_variant"

module PropsFreeze
  FACTORY = File.expand_path("yjit_regression.rb", __dir__)
  SPECIMEN = File.expand_path("props_variant.rb", __dir__)
  PINS = {FACTORY => "dfa1a3ee0d9bcdb4a4730dbf14b6d0e2092faba4dad0fe64ee51832e486d2422",
    SPECIMEN => "e6be6f9060798195719536e3dab348ed6359f8bfaf88630a97530ba350ddcbeb"}.freeze
  ARMS = %w[original split native_split frozen_split checks_original native_checks_original frozen_checks_original each].freeze

  # Ordinary-def variants, not a per-entry Stats test or a super/wrapper frame.
  # The marker lets a late enable count an ALREADY executing uncounted frame.
  # It is deliberately part of the future price, not hidden bookkeeping.
  def self.valid_uncounted?(id, props)
    return false unless ::Ractor.current.equal?(::Ractor.main)
    ok = ::Lowrail::Passes::InertiaProps.active?(id) &&
      (::Lowrail::Guard.state[id] || (::Lowrail::Guard.state[id] = ::Lowrail::Guard.validate(id))) &&
      ::Lowrail::Native.exact_class?(props, ::Hash)
    __lowrail_countable = true
    ok
  rescue TypeError, NameError
    false
  end

  def self.valid_counted?(id, props)
    return false unless ::Ractor.current.equal?(::Ractor.main)
    ok = ::Lowrail::Passes::InertiaProps.active?(id) &&
      (::Lowrail::Guard.state[id] || (::Lowrail::Guard.state[id] = ::Lowrail::Guard.validate(id))) &&
      ::Lowrail::Native.exact_class?(props, ::Hash)
    ::Lowrail::Stats.count(id, !!ok)
    ok
  rescue TypeError, NameError
    false
  end

  class << self
    alias_method :valid?, :valid_uncounted?
  end

  module StatsSelection
    def enable!
      return super if enabled?
      # Watch before super: it publishes @enabled before finishing its hooks.
      # No observer exists in a stats-disabled pricing process. Once selected,
      # new entries run the counted ISeq, never this retired-ISeq observer.
      ::PropsFreeze.watch_uncounted!
      begin
        super
      ensure
        ::PropsFreeze.select_guard!
      end
    end
  end

  def self.watch_uncounted!
    return if @retired_returns
    @retired_returns = TracePoint.new(:return) do |event|
      if event.binding.local_variable_get(:__lowrail_countable) && ::Lowrail::Stats.enabled?
        ::Lowrail::Stats.count(event.binding.local_variable_get(:id), !!event.return_value)
      end
    end
    # Target only the retired guard, never global return/end/class events.
    # The marker excludes early non-main returns and rescued guard errors.
    @retired_returns.enable(target: method(:valid_uncounted?))
  end

  def self.select_guard!
    counted = ::Lowrail::Stats.enabled?
    return if @counted_guard == counted
    singleton_class.alias_method(:valid?, counted ? :valid_counted? : :valid_uncounted?)
    @counted_guard = counted
  end

  def self.install_selection!
    ::Lowrail::Stats.singleton_class.prepend(StatsSelection) unless ::Lowrail::Stats.singleton_class < StatsSelection
    select_guard!
  end

  module Source
    def source(original, shape:, id: 0)
      return super unless shape.start_with?("frozen_")
      result = super(original, shape: shape.delete_prefix("frozen_"), id: id)
      needle = "::Lowrail::Passes::InertiaProps.valid?(#{Integer(id)}, props)"
      raise "missing recursive guard" unless result.scan(needle).size == 1
      result.sub(needle, "::PropsFreeze.valid?(#{Integer(id)}, props)")
    end
  end
  PropsVariant.singleton_class.prepend(Source)

  def self.check_pins!
    raise "published props factory/specimen changed; review before use" unless PINS.all? { |path, sha| Digest::SHA256.file(path).hexdigest == sha }
  end

  def self.source_proof
    paths = [__FILE__, *PINS.keys, File.expand_path("../../gem/lib/lowrail.rb", __dir__),
      *Dir[File.expand_path("../../gem/lib/lowrail/{inertia_props*,guard,manifest,preload_facts,stats,freeze_audit}.rb", __dir__)],
      *Dir[File.expand_path("../../gem/ext/lowrail_native/*.{c,rb}", __dir__)],
      *Dir[File.expand_path("../../gem/lib/lowrail/native/**/*.{so,bundle,dll}", __dir__)]]
    paths.to_h { [_1, Digest::SHA256.file(_1).hexdigest] }
  end

  def self.freeze!
    require_relative "../../gem/lib/lowrail/freeze_audit"
    raise "explicit symmetric freeze contract required" unless ENV["LOWRAIL_FREEZE"] == "1"
    raise "iterator precondition refused" unless Lowrail::Native.plain_hash_iteration?({})
    session = Lowrail::FreezeAudit::Session.new(profile: "holders", holders: [Hash, Enumerable]).start!(audit: false)
    raise "incomplete freeze" unless session.report.fetch("ancestor_closure_complete") && Hash.frozen? && Enumerable.frozen?
    session
  end

  def self.setup(arm, counted:)
    check_pins!
    raise "unknown frozen props arm" unless ARMS.include?(arm)
    # yjit_regression.rb is a CLI, not a require-only library. Evaluate exactly
    # its pinned definitions prefix; never execute its driver/worker tail.
    prefix, tail = File.read(FACTORY).split("\nif ARGV.first == \"--census\"\n", 2)
    raise "factory entrypoint changed" unless tail
    eval(prefix, TOPLEVEL_BINDING, FACTORY) unless defined?(YjitRegression)
    # Declare this preload symmetrically, even in original/unchecked controls.
    # Selection hooks are installed explicitly: no global tracing/require hook.
    require "lowrail"
    require "lowrail/stats"
    install_selection!
    factory_arm = arm.sub("frozen_", "")
    if arm.start_with?("frozen_")
      # Select our emitter only inside this disposable specimen process.
      adapter = Module.new do
        define_method(:source) do |original, shape:, id: 0|
          super(original, shape: "frozen_#{shape}", id: id)
        end
      end
      PropsVariant.singleton_class.prepend(adapter)
    end
    runner, metadata = YjitRegression.setup("props_native", factory_arm)
    if counted
      Lowrail::Stats.enable!
      Lowrail::Stats.reset_counts!
    end
    session = freeze!
    [runner, metadata.merge(arm: arm, contract: session.finish!, measured: false, sources: source_proof)]
  end

  def self.liveness(arm)
    runner, metadata = setup(arm, counted: true)
    runner.run(10)
    hits, fallbacks = Lowrail::Stats.unit_hits, Lowrail::Stats.unit_fallbacks
    expected = !%w[original each].include?(arm)
    manifest = Lowrail::Guard.manifest
    pass = metadata.fetch(:guard_valid) && fallbacks.empty? && hits == (expected ? {"0" => 20} : {}) &&
      JitStability.actual == "interpreter" && manifest.certification_jit == "interpreter" && manifest.format == Lowrail::FORMAT
    metadata.merge(operations: 10, hits: hits, fallbacks: fallbacks, pass: pass,
      ruby: RUBY_DESCRIPTION, actual_jit: JitStability.actual, manifest_format: manifest.format,
      certification_jit: manifest.certification_jit)
  end

  def self.check(out, counted: true)
    check_pins!
    # Reuse the entire published 478-comparison gate. Only select our emitter
    # and insert the SAME contract into original and candidate child processes.
    # Its per-instance mutations remain legal; global-mutation failures are
    # separate contract witnesses, not reinterpreted native-only cases.
    _, gate = File.read(SPECIMEN).split("\nif $PROGRAM_NAME == __FILE__\n", 2)
    raise "lifetime entrypoint changed" unless gate
    gate = "if true\n" + gate
    gate = gate.sub('shapes = mode == "--check-native" ? %w[native_split native_checks_original] : %w[split checks_original]',
      'shapes = %w[frozen_split frozen_checks_original]')
    stats_setup = "::PropsFreeze.install_selection!; "
    stats_setup += if counted
      "Lowrail::Stats.enable!"
    else
      # Untimed receipts only, to reuse the pinned gate's authorization checks
      # while exercising the actual non-counting ISeq. No observer in pricing.
      <<~'RUBY'
        __lowrail_receipts = TracePoint.new(:return) do |event|
          if event.binding.local_variable_get(:__lowrail_countable)
            ::Lowrail::Stats.count(event.binding.local_variable_get(:id), !!event.return_value)
          end
        end
        __lowrail_receipts.enable(target: ::PropsFreeze.method(:valid_uncounted?))
      RUBY
    end
    insertion = <<~'RUBY'
      fixture = "require #{File.expand_path('props_freeze.rb', __dir__).dump}\n" + fixture
      fixture = fixture.sub('Lowrail::Stats.enable!', __STATS_SETUP_LITERAL__)
      # First Ractor startup lazily prepends Kernel in MRI. Explicitly warm it
      # in BOTH arms of this witness; cold post-freeze startup is a refusal.
      fixture = fixture.sub('if ENV["RACTOR"]', 'Ractor.new { nil }.value if ENV.fetch("RACTOR", nil); ::PropsFreeze.freeze!; if ENV["RACTOR"]')
      prefix = <<~RUBY
    RUBY
    gate = gate.sub('  prefix = <<~RUBY', insertion.sub('__STATS_SETUP_LITERAL__', stats_setup.dump).lines.map { "  " + _1 }.join.chomp)
    gate = gate.sub('sources = [File.expand_path(__FILE__),',
      'sources = [*::PropsFreeze.source_proof.keys, File.expand_path(__FILE__),')
    gate = gate.sub('cases: records.size, records: records, measured: false',
      "statistics_mode: #{(counted ? 'enabled' : 'disabled_with_untimed_receipts').dump}, cases: records.size, records: records, measured: false")
    ARGV.replace(["--check-native", out])
    eval(gate, TOPLEVEL_BINDING, SPECIMEN)
  end
end

if $PROGRAM_NAME == __FILE__
  require_relative "../jit_stability"
  require "json"
  JitStability.assert_mode!
  abort "interpreter preparation only" unless JitStability.mode == "interpreter"
  case ARGV.first
  when "--liveness"
    result = PropsFreeze.liveness(ARGV.fetch(1))
    puts JSON.generate(result)
    abort "untimed liveness failed; no pricing permitted" unless result.fetch(:pass)
  when "--check", "--check-uncounted"
    PropsFreeze.check(ARGV.fetch(1), counted: ARGV.first == "--check")
  else
    abort "preparation only: --liveness ARM or --check|--check-uncounted NEW_OUTDIR; no pricing entrypoint"
  end
end
