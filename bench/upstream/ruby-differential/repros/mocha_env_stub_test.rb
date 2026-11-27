require "minitest/autorun"
require "mocha/minitest"

class EnvStubTest < Minitest::Test
  def test_stub_env
    ENV.stubs(:[]).with("API_KEY").returns("secret")
    assert_equal "secret", ENV["API_KEY"]
  end
end
