# frozen_string_literal: true

# The environments lowrail-profile runs things in: the counter's build, outside
# the app's bundle; and the processes a suite starts, handed back their
# environment only once the suite's runner has read its seed. A gem that loads
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

  # Under bundle exec the counter is built in a directory of its own, where an
  # app's Gemfile that reads a file relative to the cwd (Dawarich's
  # .ruby-version) cannot be evaluated: the build runs outside the bundle.
  def test_the_counter_builds_under_an_apps_bundle
    realpath_tmpdir do |dir|
      File.write(File.join(dir, ".ruby-version"), RUBY_VERSION)
      File.write(File.join(dir, "Gemfile"), "source \"https://rubygems.org\"\nFile.read(\".ruby-version\")\n")
      bundle = Gem.bin_path("bundler", "bundle")
      env = CLEAN_ENV.merge("XDG_CACHE_HOME" => File.join(dir, "cache"), "PATH" => "#{File.dirname(RUBY)}:#{ENV["PATH"]}")
      _, err, status = Open3.capture3(env, RUBY, bundle, "lock", "--local", chdir: dir)
      assert status.success?, err
      _, err, status = Open3.capture3(env, RUBY, bundle, "exec", RUBY, PROFILE, "--runs", "1", "--out", "o", "--", RUBY, "-e", "exit", chdir: dir)
      refute_match(/building the counter failed/, err)
      assert_match(/no runs with requests/, err, "the command ran: #{status.inspect}")
      assert_equal 1, Dir[File.join(dir, "cache/lowrail/profile/*/*/lowrail_profile.#{RbConfig::CONFIG.fetch("DLEXT")}")].size
    end
  end

  # Under a parent that never reaps orphans (a container's PID 1 without an
  # init), a process of the stopped run stays a zombie in its group: the
  # 10 s for the group to end do not wait for it.
  def test_timeout_does_not_wait_for_a_zombie
    skip "needs Linux's PR_SET_CHILD_SUBREAPER and python3" unless RUBY_PLATFORM.include?("linux") && system("python3", "-c", "", err: File::NULL)
    realpath_tmpdir do |dir|
      reaper = "import ctypes, subprocess, sys; ctypes.CDLL(None).prctl(36, 1, 0, 0, 0); sys.exit(subprocess.run(sys.argv[1:]).returncode)"
      env = CLEAN_ENV.merge("XDG_CACHE_HOME" => File.join(dir, "cache"))
      profile(dir, "--runs", "1", "--out", "warm", "--", RUBY, "-e", "exit") # builds the counter first
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      _, err, status = Open3.capture3(env, "python3", "-c", reaper, RUBY, PROFILE, "--timeout", "1", "--out", "o", "--",
        RUBY, "-e", 'spawn("sleep", "60"); sleep', chdir: dir)
      took = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      assert_equal 124, status.exitstatus, err
      assert_operator took, :<, 6, "waited #{took.round(1)} s for a zombie"
    end
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
