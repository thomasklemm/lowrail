# frozen_string_literal: true

require_relative "test_helper"

class GateTest < Minitest::Test
  include LowrailTest

  def test_receipt_counts_real_outcomes_without_counting_fixture_subprocesses
    Dir.mktmpdir do |dir|
      report = File.join(dir, "suite.json")
      preload = File.expand_path("../script/gate_reporter.rb", GEM_ROOT)
      code = <<~'RUBY'
        require "minitest/autorun"
        require "rbconfig"
        class ExampleTest < Minitest::Test
          def test_pass
            child = IO.popen([RbConfig.ruby, "-e", 'print ENV.key?("LOWRAIL_GATE_REPORT") || !!defined?(Minitest)'], &:read)
            assert_equal "false", child
          end
          def test_fail = flunk("real failure")
          def test_error = raise("real error")
          def test_skip = skip("named optional prerequisite")
        end
      RUBY
      out, err, status = ruby("-e", code, setup: false, env: {
        "LOWRAIL_GATE_REPORT" => report, "RUBYOPT" => "-r#{preload}", "MT_CPU" => "1" })
      refute status.success?, "#{out}\n#{err}"
      data = JSON.parse(File.read(report))
      assert_equal [4, 2, 1, 1, 1], data.values_at("tests", "assertions", "failures", "errors", "skips")
      assert_equal [{ "test" => "ExampleTest#test_skip", "reason" => "named optional prerequisite" }], data.fetch("named_skips")
      assert_operator data.fetch("observed_threads"), :>, 0
    end
  end
end
