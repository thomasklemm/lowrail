# frozen_string_literal: true

# When lowrail-profile hands the environment back to the processes a suite
# starts: only once the suite's runner has read its seed. A gem that loads
# RSpec::Core::Runner without running RSpec (rswag-specs in Dawarich's bundle)
# must not make the app's boot hand it back. The children themselves are
# checked in profile_test.rb.
#   ruby -Igem/lib -Igem/test gem/test/profile_env_test.rb

require "test_helper"

class ProfileEnvTest < Minitest::Test
  include LowrailTest

  PROFILE = File.join(GEM_ROOT, "exe/lowrail-profile")
  # What rswag-specs does to a bundle that never runs RSpec.
  RUNNER_LOADED = "module RSpec; module Core; class Runner; end; end; end"

  def profile(dir, *args)
    env = CLEAN_ENV.merge("XDG_CACHE_HOME" => File.join(dir, "cache"), "RAILS_ENV" => "test", "MT_NO_PLUGINS" => "1")
    Open3.capture3(env, RUBY, PROFILE, *args, chdir: dir)
  end

  def test_a_loaded_rspec_runner_outside_rspec_keeps_the_profile
    skip "Rails, sqlite3 and bcrypt are not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir,
        # A Minitest suite: it keeps lowrail-profile's seed.
        "suite_test.rb" => <<~RUBY,
          #{RUNNER_LOADED}
          require_relative "config/environment"
          require "rack/mock"
          require "active_support/test_case"
          require "minitest/autorun"
          class SuiteTest < ActiveSupport::TestCase
            def test_request = Rails.application.call(Rack::MockRequest.env_for("http://localhost/widgets"))
          end
        RUBY
        # `rake spec`: a parent that boots the app, then starts the suite, which is profiled.
        "parent.rb" => <<~RUBY,
          #{RUNNER_LOADED}
          require_relative "config/environment"
          system(RbConfig.ruby, "child.rb") or exit 1
        RUBY
        "child.rb" => <<~'RUBY')
          require_relative "config/environment"
          require "rack/mock"
          Rails.application.call(Rack::MockRequest.env_for("http://localhost/widgets"))
        RUBY
      out, err, status = profile(dir, "--runs", "1", "--out", "minitest", "--", RUBY, "suite_test.rb")
      assert status.success?, err
      assert_equal "Run options: --seed 1234", out[/^Run options: .*/], "the suite keeps the seed capture.json records"
      out, err, status = profile(dir, "--runs", "1", "--out", "rake", "--keep-runs", "--", RUBY, "parent.rb")
      assert status.success?, "#{err}\n#{out}"
      assert_equal 1, Dir[File.join(dir, "rake/run1/*.tsv")].size, "the suite's process is profiled"
    end
  end
end
