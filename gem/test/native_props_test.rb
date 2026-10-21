# frozen_string_literal: true

require_relative "test_helper"

class NativePropsTest < Minitest::Test
  include LowrailTest

  PRELUDE = <<~'RUBY'
    require "json"
    require "lowrail"
    require "lowrail/inertia_props"
    # Capture in the same unrefined lexical scope as the production guard.
    # Run the candidate FIRST: the reference materializes an eigenclass.
    module ReceiverWitness
      include Lowrail::Passes
      def self.reference(object)
        guard = InertiaProps
        return false unless guard::CLASS.bind_call(object).equal?(Hash)
        holder = guard::SINGLETON_CLASS.bind_call(object)
        guard::PUBLIC.bind_call(holder, :each_with_object) && guard::PUBLIC.bind_call(holder, :each) &&
          guard::INSTANCE_METHOD.bind_call(holder, :each_with_object) == guard::EACH_WITH_OBJECT &&
          guard::INSTANCE_METHOD.bind_call(holder, :each) == guard::EACH
      end

      def self.iteration(object)
        direct = []
        object.each { |key, value| direct << [key, value] }
        [direct, object.each_with_object([]) { |pair, output| output << pair }]
      end
    end
    object = {left: 11, right: 37}
  RUBY

  def probe(code)
    ruby_json(PRELUDE + code, setup: false,
      env: {"LOWRAIL" => "0", "RUBYOPT" => "-I#{GEM_LIB}"})
  end

  def test_actual_bodies_and_visibility_without_ruby_callbacks
    cases = {
      "plain" => ["", true, true],
      "frozen" => ["object.freeze", true, true],
      "not Hash" => ["object = Object.new", false, false],
      "immediate" => ["object = nil", false, false],
      "subclass" => ["object = Class.new(Hash)[object]", false, false],
      "singleton each" => ["def object.each(&block) = each_pair(&block)", false, false],
      "private singleton" => ["def object.each(&block) = each_pair(&block); object.singleton_class.send(:private, :each)", false, false],
      "singleton each_with_object" => ["def object.each_with_object(value) = super", false, false],
      "extend" => ["object.extend(Module.new { def each(&block) = super })", false, false],
      "prepend" => ["Hash.prepend(Module.new { def each(&block) = super })", false, false],
      "inherited iterator wrapper" => ["Enumerable.class_eval { def each_with_object(value) = super }", false, false],
      "empty prepend" => ["Hash.prepend(Module.new)", true, true],
      "pair alias" => ["Hash.alias_method(:each, :each_pair)", true, true],
      "different basic body" => ["Hash.alias_method(:each, :each_key)", false, false],
      "identical Ruby wrapper" => ["Hash.class_eval { def each(&block) = each_pair(&block) }", false, false],
      "suppressed hook" => ["def Hash.method_added(name); end; Hash.class_eval { def each(&block) = each_pair(&block) }", false, false],
      "private each" => ["Hash.send(:private, :each)", false, false],
      "protected each" => ["Hash.send(:protected, :each)", false, false],
      "private inherited iterator" => ["Enumerable.send(:private, :each_with_object)", false, false],
      "protected inherited iterator" => ["Enumerable.send(:protected, :each_with_object)", false, false],
      "undef each" => ["Hash.undef_method(:each)", false, false],
      "undef inherited iterator" => ["Enumerable.undef_method(:each_with_object)", false, false],
      "missing each" => ["Hash.undef_method(:each); Hash.class_eval { def method_missing(name, *args, &block) = name == :each ? each_pair(&block) : super }", false, false],
      "existing eigenclass" => ["object.singleton_class", false, true],
      "unrelated singleton" => ["def object.unrelated = 53", false, true],
      "empty extension" => ["object.extend(Module.new)", false, true],
      "restore alias" => ["Hash.alias_method(:saved_each, :each); Hash.class_eval { def each(&block) = each_pair(&block) }; Hash.alias_method(:each, :saved_each)", false, true],
      "reinstall captured native body" => ["Hash.define_method(:each, Hash.instance_method(:each))", false, true]
    }
    cases.each do |label, (mutation, expected, reference)|
      result = probe(<<~RUBY)
        #{mutation}
        # No user dispatch (including respond_to_missing?) is permitted.
        calls = []
        Hash.class_eval do
          define_method(:respond_to_missing?) { |*| calls << "respond_to_missing?"; raise "user dispatch" }
        end
        native = Lowrail::Native.plain_hash_iteration?(object)
        puts JSON.generate(native: native, reference: ReceiverWitness.reference(object), calls: calls)
      RUBY
      assert_equal expected, result.fetch("native"), label
      assert_equal reference, result.fetch("reference"), label
      assert_empty result.fetch("calls"), label
    end
  end

  def test_rechecks_mutation_at_each_traversal_and_does_not_materialize_eigenclasses
    result = probe(<<~'RUBY')
      states = [Lowrail::Native.plain_hash_iteration?(object)]
      Hash.send(:private, :each)
      states << Lowrail::Native.plain_hash_iteration?(object)
      Hash.send(:public, :each)
      states << Lowrail::Native.plain_hash_iteration?(object)
      Enumerable.send(:protected, :each_with_object)
      states << Lowrail::Native.plain_hash_iteration?(object)
      Enumerable.send(:public, :each_with_object)
      states << Lowrail::Native.plain_hash_iteration?(object)
      def Hash.method_added(name); end
      Hash.class_eval { def each(&block) = each_pair(&block) }
      states << Lowrail::Native.plain_hash_iteration?(object)
      puts JSON.generate(states: states)
    RUBY
    assert_equal [true, false, true, false, true, false], result.fetch("states")
  end

  def test_refinements_do_not_change_the_certified_unrefined_sites
    %w[each each_with_object].each do |method|
      result = probe(<<~RUBY)
        module CallerRefinement
          refine Hash do
            def #{method}(*args) = :refined
          end
        end
        using CallerRefinement
        native = Lowrail::Native.plain_hash_iteration?(object)
        actual = object.#{method}#{method == "each" ? "" : "({})"}
        puts JSON.generate(native: native, reference: ReceiverWitness.reference(object),
          actual: actual, iteration: ReceiverWitness.iteration(object))
      RUBY
      assert_equal "refined", result.fetch("actual")
      assert result.fetch("reference"), "caller refinements must not leak into the guard's lexical scope"
      assert_equal method == "each", result.fetch("native"), method
      assert_equal [[["left", 11], ["right", 37]], [["left", 11], ["right", 37]]], result.fetch("iteration")
    end
  end

  def test_main_ractor_boundary_and_steady_state_allocations
    result = probe(<<~'RUBY')
      def allocations(object, n)
        before = GC.stat(:total_allocated_objects)
        n.times { Lowrail::Native.plain_hash_iteration?(object) }
        GC.stat(:total_allocated_objects) - before
      end
      # Warm these exact call sites, not a separate loop ISeq/cache.
      2.times { allocations(object, 0); allocations(object, 1000) }
      control = allocations(object, 0)
      allocated = allocations(object, 1000)
      # Do not mark the whole extension Ractor-safe to admit this experiment.
      other = Ractor.new do
        native = begin
          Lowrail::Native.plain_hash_iteration?({})
        rescue Ractor::UnsafeError => error
          error.class.name
        end
        [native, Lowrail::Passes::InertiaProps.valid?(0, {})]
      end.value
      puts JSON.generate(control: control, allocated: allocated,
        still_plain: Lowrail::Native.plain_hash_iteration?(object), other: other)
    RUBY
    assert_equal 0, result.fetch("control")
    assert_equal 0, result.fetch("allocated")
    assert result.fetch("still_plain")
    assert_equal ["Ractor::UnsafeError", false], result.fetch("other")
  end
end
