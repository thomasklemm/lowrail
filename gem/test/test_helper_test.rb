# frozen_string_literal: true

require_relative "test_helper"

class TestHelperTest < Minitest::Test
  include LowrailTest

  def test_strict_prerequisites_fail_but_optional_skips_stay_named
    fixture = <<~RUBY
      require #{File.join(__dir__, "test_helper").dump}
      class GateFixture < Minitest::Test
        include LowrailTest
        def test_required = missing_prerequisite("install the fixture dependency")
        def test_optional = skip("optional external app absent")
      end
    RUBY
    out, err, status = ruby("-e", fixture, setup: false, env: {"LOWRAIL_STRICT_GATES" => nil})
    assert status.success?, "#{out}\n#{err}"
    assert_includes out, "Lowrail gate summary (normal): 2 named skips"
    assert_includes out, "GateFixture#test_required: missing prerequisite: install the fixture dependency"
    assert_includes out, "GateFixture#test_optional: optional external app absent"

    out, err, status = ruby("-e", fixture, setup: false, env: {"LOWRAIL_STRICT_GATES" => "1"})
    refute status.success?, "#{out}\n#{err}"
    assert_match(/1 failures?, 0 errors, 1 skips?/, out)
    assert_includes out, "missing prerequisite: install the fixture dependency"
    assert_includes out, "Lowrail gate summary (strict): 1 named skips"
    assert_includes out, "GateFixture#test_optional: optional external app absent"

    out, err, status = ruby("-e", fixture, "--", "-n", "/optional/", setup: false, env: {"LOWRAIL_STRICT_GATES" => "1"})
    assert status.success?, "#{out}\n#{err}"
    assert_includes out, "Lowrail gate summary (strict): 1 named skips"
  end
end
