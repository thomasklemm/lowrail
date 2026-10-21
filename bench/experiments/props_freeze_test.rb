# frozen_string_literal: true

require "minitest/autorun"
require "json"
require "open3"
require "rbconfig"

class PropsFreezeTest < Minitest::Test
  SCRIPT = File.expand_path("props_freeze.rb", __dir__)
  LIB = File.expand_path("../../gem/lib", __dir__)

  def run_child(code, lowrail: "0")
    env = %w[RUBYOPT RUBY_YJIT_ENABLE RUBY_ZJIT_ENABLE LOWRAIL_STATS LOWRAIL_OUTCOMES LOWRAIL_UNITS
      BUNDLE_GEMFILE LOWRAIL_ROOT LOWRAIL_DIR].to_h { [_1, nil] }
    Open3.capture3(env.merge("LOWRAIL_FREEZE" => "1", "BENCH_JIT" => "0", "LOWRAIL" => lowrail),
      RbConfig.ruby, "--disable-yjit", "--disable-zjit", "-I#{LIB}", "-e", "require #{SCRIPT.dump}\n#{code}")
  end

  def test_same_factory_and_exact_recursive_liveness_in_every_frozen_arm
    arms = %w[original split native_split frozen_split checks_original native_checks_original frozen_checks_original each]
    arms.each do |arm|
      stdout, stderr, status = run_child("require 'json'; puts JSON.generate(PropsFreeze.liveness(#{arm.dump}))")
      assert status.success?, "#{arm}: #{stderr}"
      result = JSON.parse(stdout)
      assert result.fetch("pass"), arm
      assert result.fetch("guard_valid"), arm
      assert_equal(%w[original each].include?(arm) ? {} : {"0" => 20}, result.fetch("hits"), arm)
      assert_empty result.fetch("fallbacks"), arm
      assert result.fetch("contract").fetch("enforced"), arm
      assert_equal "enforced_without_observer", result.fetch("contract").fetch("status")
    end

    # The counted companion must reject a fallback-only candidate even when
    # its manifest and freeze preconditions were admitted successfully.
    stdout, stderr, status = run_child(<<~RUBY)
      require 'json'; require 'lowrail'
      Lowrail::Native.define_singleton_method(:exact_class?) { |*| false }
      puts JSON.generate(PropsFreeze.liveness('frozen_split'))
    RUBY
    assert status.success?, stderr
    result = JSON.parse(stdout)
    refute result.fetch("pass")
    assert_empty result.fetch("hits")
    assert_equal({"0" => 20}, result.fetch("fallbacks"))
  end

  def test_callback_receiver_changes_and_forbidden_class_mutation_are_symmetric
    code = <<~'RUBY'
      require 'json'
      PropsFreeze.setup(ENV.fetch('ARM'), counted: false)
      calls = []
      destination = {target: 47}
      evaluator = ->(value) { Proc === value ? value.call : value }
      props = {lazy: -> do
        calls << 'lazy'
        destination.define_singleton_method(:singleton_method_added) { |_| }
        original = Enumerable.instance_method(:each_with_object)
        destination.define_singleton_method(:each_with_object) do |memo, &block|
          calls << 'destination'
          original.bind_call(self, memo, &block)
          memo[:changed] = 53
          memo
        end
        19
      end, destination: destination}
      result = InertiaRails::PropsResolver.new(props, evaluator: evaluator).resolve
      blocked = begin
        InertiaRails::PropsResolver.new({stop: -> do
          calls << 'forbidden'
          Hash.define_method(:each) { |&block| }
        end}, evaluator: evaluator).resolve
        false
      rescue FrozenError
        true
      end
      puts JSON.generate(result: result, calls: calls, blocked: blocked,
        frozen: [Hash, Enumerable, Object, Kernel, BasicObject].map(&:frozen?))
    RUBY
    results = %w[0 1].flat_map do |mode|
      %w[original frozen_split].map do |arm|
        stdout, stderr, status = run_child("ENV['ARM'] = #{arm.dump}\n" + code, lowrail: mode)
        assert status.success?, "#{mode}/#{arm}: #{stderr}"
        JSON.parse(stdout)
      end
    end
    results.each { assert_equal results.first, _1 }
    assert_equal({"lazy" => 19, "destination" => {"target" => 47, "changed" => 53}}, results.first.fetch("result").first)
    assert_equal %w[lazy destination forbidden], results.first.fetch("calls")
    assert results.first.fetch("blocked")
    assert_equal [true] * 5, results.first.fetch("frozen")
  end
end
