# frozen_string_literal: true

require_relative "test_helper"

class InertiaConfigTest < Minitest::Test
  include LowrailTest

  SCENARIO = <<~'RUBY'
    # This standalone production fixture explicitly accepts sealed delivery;
    # test-mode apps and old unmarked artifacts must remain original-only.
    ENV["RAILS_ENV"] = "production"
    ENV["LOWRAIL_SEALED"] = "1"
    gem "inertia_rails", ENV.fetch("INERTIA_VERSION")
    require "rails"
    require "action_controller/railtie"
    require "inertia_rails"
    require "lowrail"
    require "lowrail/manifest"
    require "lowrail/guard"
    require "lowrail/stats"
    require "lowrail/inertia_config_build"
    Lowrail::Stats.enable!
    klass = InertiaRails::Configuration
    original = klass.instance_method(:bind_controller)
    klass.send(:private, :bind_controller) if ENV["PRIVATE_AT"] == "build"
    if ENV["PRIVATE_AT"] == "schema"
      schema = klass::OPTION_NAMES.dup
      def schema.==(*) = true
      klass.send(:remove_const, :OPTION_NAMES)
      klass.const_set(:OPTION_NAMES, schema.freeze)
    end
    built = Lowrail::InertiaConfigBuild.build
    if ENV["PRIVATE_AT"] == "build"
      raise "private binder built" unless built[:units].empty? && built[:ledger].first["reason"] == "constructor_override"
      puts JSON.generate(contract: "private preserved", hits: 0)
      exit
    end
    if ENV["PRIVATE_AT"] == "schema"
      raise "overridden schema trusted" unless built[:units].empty? && built[:ledger].first["reason"] == "schema_changed"
      puts JSON.generate(contract: "schema refused", hits: 0)
      exit
    end
    raise built.inspect unless built[:units].size == 1 && built[:ledger].first["reason"] == "canonical_schema"
    unit = built[:units].first.merge("id" => 0)
    unit["data"]["sources"].transform_values! { "stale" } if ENV["STALE"]
    manifest = Lowrail::Manifest.new({"format" => 1, "ruby_description" => RUBY_DESCRIPTION,
      "compile_option" => Lowrail::Manifest.compile_option_fingerprint, "files" => {}, "units" => [unit],
      "tier" => "sealed-v1", "rails_env" => "production"}, Dir.pwd)
    preexisting = klass.default
    hash = preexisting.instance_variable_get(:@options)
    def hash.keys = raise("preexisting keys must not run")
    def hash.dup = raise("preexisting dup must not run")
    def hash.default = raise("preexisting default must not run")
    def hash.class = raise("preexisting Hash class must not run")
    def preexisting.class = raise("preexisting Configuration class must not run")
    klass.send(:private, :bind_controller) if ENV["PRIVATE_AT"] == "install"
    Lowrail::Guard.install(manifest, Lowrail::Stats::STATE)
    Lowrail::Passes::InertiaConfig.install(manifest.units)
    Lowrail::Passes::InertiaConfig.activate unless ENV["PLAIN"]
    if ENV["PRIVATE_AT"] == "install"
      raise "private binder published" unless klass.private_method_defined?(:bind_controller)
      puts JSON.generate(contract: "private preserved", hits: Lowrail::Stats.unit_hits.fetch("0", 0))
      exit
    end
    a, b = Object.new, Object.new
    config = klass.default
    options = ->(c) { c.instance_variable_get(:@options) }
    compare = lambda do |source, controller|
      expected = original.bind_call(source, controller)
      actual = source.bind_controller(controller)
      raise "class" unless actual.class.equal?(klass)
      raise "controller" unless actual.instance_variable_get(:@controller).equal?(controller)
      x, y = options.call(expected), options.call(actual)
      raise "options" unless x == y && x.keys == y.keys && x.class == y.class &&
        x.default == y.default && x.default_proc == y.default_proc && x.compare_by_identity? == y.compare_by_identity?
      raise "frozen" if actual.frozen? || y.frozen?
      raise "shared storage" if actual.equal?(source) || y.equal?(options.call(source))
      actual
    end
    compare.call(preexisting, a)
    hash.singleton_class.remove_method(:class)
    preexisting.singleton_class.remove_method(:class)
    left, right = compare.call(config, a), compare.call(config, b)
    left.version = "request only"
    raise "request leakage" if right.version == "request only" || config.version == "request only"
    frozen_source = klass.default.freeze
    compare.call(frozen_source, a).version = "still mutable"
    raise "frozen source poisoned" if compare.call(frozen_source, b).version == "still mutable"
    # Copy live values, but do not deep-copy them: Rails retains these identities.
    value = +"live"
    config.version = value
    raise "not invalidated" if !ENV["PLAIN"] && !ENV["STALE"] && Lowrail::Guard.state[0]
    raise "boot snapshot" unless compare.call(config, b).version.equal?(value)
    value.replace("changed in place")
    raise "stale value bytes" unless compare.call(config, a).version == "changed in place"
    calls = 0
    config.version = -> { calls += 1; @label }
    a.instance_variable_set(:@label, "alpha")
    b.instance_variable_set(:@label, "beta")
    x, y = compare.call(config, a), compare.call(config, b)
    raise "eager lambda" unless calls.zero?
    raise "wrong lambda context" unless [x.version, y.version, x.version] == %w[alpha beta alpha] && calls == 3
    # Actual controller DSL, including a late-created override and inheritance.
    class ParentController < ActionController::Base
      include InertiaRails::Controller
    end
    class SpecialController < ParentController
      inertia_config(version: -> { "controller-#{@label}" }, encrypt_history: true)
    end
    controller = SpecialController.new
    controller.instance_variable_set(:@label, "override")
    bound = controller.send(:inertia_configuration)
    raise "controller override ignored" unless bound.version == "controller-override" && bound.encrypt_history
    raise "parent poisoned" if ParentController.new.send(:inertia_configuration).encrypt_history
    # Same global object is changed by tests and restored after each example.
    previous = InertiaRails.configuration.version
    InertiaRails.configuration.version = "per-test"
    raise "test change ignored" unless ParentController.new.send(:inertia_configuration).version == "per-test"
    InertiaRails.configuration.version = previous
    raise "test restore ignored" unless ParentController.new.send(:inertia_configuration).version == previous
    # All of these must follow the original constructor, not preserve dup's
    # Hash policies, insertion order, subclasses, or an unknown option.
    base = options.call(config)
    variants = [base.dup.tap { _1.default = :missing }, base.dup.tap { _1.default_proc = ->(*) { :missing } },
      base.dup.compare_by_identity, base.to_a.reverse.to_h, base.reject { |k, _| k == :version },
      Class.new(Hash)[base]]
    misses = Lowrail::Stats.unit_fallbacks.fetch("0", 0)
    variants.each { |hash| config.instance_variable_set(:@options, hash); compare.call(config, a) }
    spoof = Object.new
    def spoof.==(other) = other.equal?(:version)
    # Array equality must not trust a caller key's asymmetric == implementation.
    [base.merge(unknown_option: 7), base.transform_keys { _1 == :version ? spoof : _1 }].each do |hash|
      config.instance_variable_set(:@options, hash)
      errors = [-> { original.bind_call(config, a) }, -> { config.bind_controller(a) }].map do |call|
        begin; call.call; raise "unknown key accepted"; rescue ArgumentError => e; [e.class.name, e.message]; end
      end
      raise "unknown key error differs" unless errors.uniq.size == 1
    end
    config.instance_variable_set(:@options, base)
    subclass = Class.new(klass).new(**base)
    compare.call(subclass, b)
    raise "shape refusals not counted" if !ENV["PLAIN"] && !ENV["STALE"] && Lowrail::Stats.unit_fallbacks.fetch("0", 0) - misses != 9
    # Constructor monkey patches must not be bypassed by allocate.
    initialize_method = klass.instance_method(:initialize)
    klass.class_eval do
      define_method(:initialize) do |**attrs|
        initialize_method.bind_call(self, **attrs)
        @options[:version] = "custom initialize"
      end
      private :initialize
    end
    raise "constructor bypassed" unless compare.call(config, a).version == "custom initialize"
    klass.send(:define_method, :initialize, initialize_method)
    klass.send(:private, :initialize)
    compare.call(config, b)
    klass.send(:define_method, :bind_controller) do |controller|
      original.bind_call(self, controller).tap { _1.version = "patched binder" }
    end
    raise "binder redefinition ignored" unless config.bind_controller(a).version == "patched binder"
    klass.send(:define_method, :bind_controller, original)
    compare.call(config, b)
    # Constructor extraction never invokes source Hash copy/reflection hooks.
    # Literal splatting must not introduce one, even before guards existed.
    def base.dup = raise("custom dup must not run")
    def base.keys = raise("custom keys must not run")
    compare.call(config, a)
    base.singleton_class.remove_method(:dup)
    base.singleton_class.remove_method(:keys)
    compare.call(config, a)
    original_schema = klass::OPTION_NAMES
    klass.send(:remove_const, :OPTION_NAMES)
    klass.const_set(:OPTION_NAMES, original_schema.reverse.freeze)
    compare.call(config, b)
    klass.send(:remove_const, :OPTION_NAMES)
    klass.const_set(:OPTION_NAMES, original_schema)
    compare.call(config, b)
    puts JSON.generate(hits: Lowrail::Stats.unit_hits.fetch("0", 0), fallbacks: Lowrail::Stats.unit_fallbacks.fetch("0", 0), contract: "exact")
  RUBY

  def test_binding_contract_across_supported_gems
    versions = %w[3.21.2 3.22.0 3.23.0]
    skip_missing_inertia_versions(*versions)
    versions.each do |version|
      result = ruby_json(SCENARIO, env: {"INERTIA_VERSION" => version})
      assert_equal "exact", result["contract"]
      assert_operator result["hits"], :>=, 10
      assert_operator result["fallbacks"], :>=, 10
    end
  end

  def test_plain_and_stale_build_controls
    skip_missing_inertia_versions("3.23.0")
    %w[PLAIN STALE].each do |control|
      result = ruby_json(SCENARIO, env: {"INERTIA_VERSION" => "3.23.0", control => "1"})
      assert_equal "exact", result["contract"]
      assert_equal 0, result["hits"]
      assert_equal 0, result["fallbacks"]
    end
  end

  def test_private_binding_and_overridden_schema_are_not_installed
    skip_missing_inertia_versions("3.23.0")
    %w[build install schema].each do |phase|
      result = ruby_json(SCENARIO, env: {"INERTIA_VERSION" => "3.23.0", "PRIVATE_AT" => phase})
      assert_equal phase == "schema" ? "schema refused" : "private preserved", result["contract"]
      assert_equal 0, result["hits"]
    end
  end

  private

  def skip_missing_inertia_versions(*versions)
    missing = versions.select { Gem::Specification.find_all_by_name("inertia_rails", _1).empty? }
    skip "install inertia_rails #{missing.join(', ')} to run Inertia configuration tests" unless missing.empty?
  end
end
