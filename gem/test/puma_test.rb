# frozen_string_literal: true

require_relative "test_helper"

class PumaTest < Minitest::Test
  include LowrailTest

  def test_require_is_inert_and_explicit_warmup_only_runs_once
    result = ruby_json(<<~'RUBY', setup: false, env: {"RUBYLIB" => GEM_LIB})
      require "json"
      GC.auto_compact = false
      before = GC.stat(:compact_count)
      require "lowrail/puma"
      inert = GC.stat(:compact_count) == before && !defined?(::Puma) && !defined?(::Rails)
      value = "hello"
      first = Lowrail::Puma.warmup
      after = GC.stat(:compact_count)
      second = Lowrail::Puma.warmup
      puts JSON.generate(inert: !!inert, first: first, second: second,
        compacted: after >= before + 2, not_repeated: GC.stat(:compact_count) == after,
        value: value << " world")
    RUBY
    assert_equal({"inert" => true, "first" => true, "second" => false,
      "compacted" => true, "not_repeated" => true, "value" => "hello world"}, result)
  end

  def test_unavailable_or_failed_warmup_does_not_prevent_boot_or_retry_partial_work
    %w[missing failed].each do |mode|
      result = ruby_json(<<~'RUBY', setup: false, env: {"RUBYLIB" => GEM_LIB, "PROBE_MODE" => mode})
        require "json"
        require "lowrail/puma"
        if ENV.fetch("PROBE_MODE") == "missing"
          Process.singleton_class.send(:undef_method, :warmup)
        else
          def Process.warmup = raise("warmup unavailable")
        end
        first = Lowrail::Puma.warmup
        after = GC.stat(:compact_count)
        second = Lowrail::Puma.warmup
        puts JSON.generate(first: first, second: second,
          not_repeated: GC.stat(:compact_count) == after, app_result: 29 * 7)
      RUBY
      assert_equal({"first" => false, "second" => false,
        "not_repeated" => true, "app_result" => 203}, result, mode)
    end
  end
end
