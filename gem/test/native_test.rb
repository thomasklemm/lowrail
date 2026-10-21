# frozen_string_literal: true

require_relative "test_helper"

class NativeTest < Minitest::Test
  include LowrailTest

  def test_exact_class_matches_the_objspace_admission_oracle_without_app_dispatch
    result = ruby_json(<<~'RUBY', setup: false, env: {"RUBYOPT" => "-I#{GEM_LIB}"})
      require "json"
      require "lowrail"
      before = $LOADED_FEATURES.grep(/objspace/)
      class View
        def link_to = "original"
      end
      calls = []
      objects = {stock: View.new, private_override: View.new, prepend: View.new,
        undef: View.new, respond_to_missing: View.new, empty_eigenclass: View.new,
        subclass: Class.new(View).new, hash: {}, regexp: /x/, integer: 17, nil: nil}
      objects[:private_override].singleton_class.class_eval { private; def link_to = "override" }
      objects[:prepend].singleton_class.prepend(Module.new { private; def link_to = "prepend" })
      objects[:undef].singleton_class.class_eval { undef_method :link_to }
      objects[:respond_to_missing].define_singleton_method(:respond_to_missing?) { |*args| calls << args; true }
      objects[:empty_eigenclass].singleton_class
      objects.each_value do |object|
        # Even a lying #class/#instance_of? must not affect the native read.
        next unless object.equal?(objects[:respond_to_missing])
        object.define_singleton_method(:class) { calls << :class; View }
        object.define_singleton_method(:instance_of?) { |*| calls << :instance_of; true }
      end
      classes = [View, Hash, Regexp, Integer, NilClass]
      native = objects.transform_values { |object| classes.map { Lowrail::Native.exact_class?(object, _1) } }
      require "objspace" # Diagnostic oracle only, after the native decisions.
      oracle = objects.transform_values { |object| classes.map { ObjectSpace.internal_class_of(object).equal?(_1) } }
      puts JSON.generate(native: native, oracle: oracle, calls: calls, before: before)
    RUBY
    assert_equal result.fetch("oracle"), result.fetch("native")
    assert_equal [true, false, false, false, false], result.fetch("native").fetch("stock")
    %w[private_override prepend undef respond_to_missing empty_eigenclass subclass].each do |name|
      assert_equal [false] * 5, result.fetch("native").fetch(name), name
    end
    assert_empty result.fetch("calls")
    assert_empty result.fetch("before")
  end

  def test_gem_load_is_symmetric_and_a_missing_or_unloadable_binary_is_optional
    code = <<~'RUBY'
      require "json"
      require "lowrail"
      puts JSON.generate(native: !!defined?(Lowrail::Native),
        features: $LOADED_FEATURES.grep(/lowrail|objspace/))
    RUBY
    off, on = %w[0 1].map { ruby_json(code, setup: false, env: {"LOWRAIL" => _1, "RUBYOPT" => "-I#{GEM_LIB}"}) }
    assert_equal true, on.fetch("native")
    assert_equal off, on
    realpath_tmpdir do |dir|
      FileUtils.cp(File.join(GEM_LIB, "lowrail.rb"), File.join(dir, "lowrail.rb"))
      %w[missing unloadable].each do |state|
        if state == "unloadable"
          require "lowrail"
          path = File.join(dir, "lowrail/native", Lowrail::NATIVE_VARIANT)
          FileUtils.mkdir_p(path)
          File.write(File.join(path, "lowrail_native.#{RbConfig::CONFIG.fetch('DLEXT')}"), "not a shared library")
        end
        result = ruby_json(code, setup: false, env: {"RUBYOPT" => "-I#{dir}"})
        assert_equal false, result.fetch("native"), state
        assert_empty result.fetch("features").grep(/objspace/)
      end
    end
  end
end
