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
  # 10 s for the group to end do not wait for it. Linux only (a subreaper);
  # defined there alone, since CI allows no skips.
  if RUBY_PLATFORM.include?("linux")
  def test_timeout_does_not_wait_for_a_zombie
    skip "needs python3 for PR_SET_CHILD_SUBREAPER" unless system("python3", "-c", "", err: File::NULL)
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
  end

  # A ps that runs but fails says nothing about the group: the grace still
  # holds, so a process that cleans up on TERM for 3 s finishes before KILL.
  def test_timeout_waits_out_the_grace_when_ps_fails
    realpath_tmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "bin"))
      File.write(File.join(dir, "bin/ps"), "#!/bin/sh\necho ps: broken >&2\nexit 1\n")
      File.chmod(0o755, File.join(dir, "bin/ps"))
      profile(dir, "--runs", "1", "--out", "warm", "--", RUBY, "-e", "exit") # builds the counter first
      cleanup = 'trap("TERM") { sleep 3; File.write("cleaned", ""); exit }; File.write("ready", ""); sleep'
      env = CLEAN_ENV.merge("XDG_CACHE_HOME" => File.join(dir, "cache"), "PATH" => "#{File.join(dir, "bin")}:#{ENV["PATH"]}")
      _, err, status = Open3.capture3(env, RUBY, PROFILE, "--timeout", "2", "--out", "o", "--",
        RUBY, "-e", "spawn(RbConfig.ruby, '-e', #{cleanup.inspect}); sleep", chdir: dir)
      assert_equal 124, status.exitstatus, err
      assert File.exist?(File.join(dir, "ready")), "the grandchild started"
      assert File.exist?(File.join(dir, "cleaned")), "the grandchild's cleanup was cut off by KILL"
      refute_match(/ps: broken/, err, "ps's own errors stay out of lowrail-profile's output")
    end
  end

  # After a run, INT, TERM and HUP are the caller's again: they end
  # lowrail-profile while it builds the report. A FIFO left as a run file
  # holds the report open, so the signal arrives there.
  def test_signals_end_the_report_after_a_timeout_run
    realpath_tmpdir do |dir|
      env = CLEAN_ENV.merge("XDG_CACHE_HOME" => File.join(dir, "cache"))
      %w[INT TERM HUP].each do |signal|
        err = File.join(dir, "#{signal}.err")
        # A shell may start commands with INT ignored, which exec keeps; a terminal gives it as default.
        pid = Process.spawn(env, RUBY, "-e", 'trap("INT", "SYSTEM_DEFAULT"); exec(*ARGV)', RUBY, PROFILE, "--timeout", "60", "--runs", "1", "--out", signal, "--",
          "sh", "-c", 'mkfifo "$LOWRAIL_PROFILE/1.tsv"', chdir: dir, err: err, out: File::NULL, pgroup: true)
        fifo = File.join(dir, signal, "run1/1.tsv")
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 60
        sleep 0.1 until File.pipe?(fifo) || Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline
        sleep 1 # the run has exited and the report opened the FIFO
        Process.kill(signal, pid)
        waiter = Process.detach(pid)
        unless waiter.join(10)
          Process.kill("KILL", -pid)
          flunk "#{signal} during the report was swallowed: #{File.read(err)}"
        end
        assert_equal Signal.list.fetch(signal), waiter.value.termsig, "#{signal}: #{File.read(err)}"
      end
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
