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

  # Identical to PropsVariant.valid_native? except for its native predicate.
  # Freeze is established once before any candidate operations, in every arm.
  def self.valid?(id, props)
    return false unless ::Ractor.current.equal?(::Ractor.main)
    ok = ::Lowrail::Passes::InertiaProps.active?(id) &&
      (::Lowrail::Guard.state[id] || (::Lowrail::Guard.state[id] = ::Lowrail::Guard.validate(id))) &&
      ::Lowrail::Native.exact_class?(props, ::Hash)
    ::Lowrail::Stats.count(id, !!ok) if defined?(::Lowrail::Stats) && ::Lowrail::Stats.enabled?
    ok
  rescue TypeError, NameError
    false
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
      require "lowrail/stats"
      Lowrail::Stats.enable!
      Lowrail::Stats.reset_counts!
    end
    session = freeze!
    [runner, metadata.merge(arm: arm, contract: session.finish!, measured: false)]
  end

  def self.liveness(arm)
    runner, metadata = setup(arm, counted: true)
    runner.run(10)
    hits, fallbacks = Lowrail::Stats.unit_hits, Lowrail::Stats.unit_fallbacks
    expected = !%w[original each].include?(arm)
    pass = metadata.fetch(:guard_valid) && fallbacks.empty? && hits == (expected ? {"0" => 20} : {})
    metadata.merge(operations: 10, hits: hits, fallbacks: fallbacks, pass: pass,
      actual_jit: JitStability.actual, sources: PINS)
  end

  def self.check(out)
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
    gate = gate.sub('  prefix = <<~RUBY', <<~'RUBY'.lines.map { "  " + _1 }.join.chomp)
      fixture = "require #{File.expand_path('props_freeze.rb', __dir__).dump}\n" + fixture
      # First Ractor startup lazily prepends Kernel in MRI. Explicitly warm it
      # in BOTH arms of this witness; cold post-freeze startup is a refusal.
      fixture = fixture.sub('if ENV["RACTOR"]', 'Ractor.new { nil }.value if ENV.fetch("RACTOR", nil); ::PropsFreeze.freeze!; if ENV["RACTOR"]')
      prefix = <<~RUBY
    RUBY
    gate = gate.sub('sources = [File.expand_path(__FILE__),',
      "sources = [#{File.expand_path(__FILE__).dump}, #{File.expand_path('../../gem/lib/lowrail/freeze_audit.rb', __dir__).dump}, File.expand_path(__FILE__),")
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
  when "--check"
    PropsFreeze.check(ARGV.fetch(1))
  else
    abort "preparation only: --liveness ARM or --check NEW_OUTDIR; no pricing entrypoint"
  end
end
