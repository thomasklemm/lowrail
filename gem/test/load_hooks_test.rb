# frozen_string_literal: true

require_relative "test_helper"

class LoadHooksTest < Minitest::Test
  include LowrailTest

  def test_native_autoload_waits_for_successful_outer_load_without_eager_loading
    realpath_tmpdir do |dir|
      File.write(File.join(dir, "child.rb"), "class Deferred; VALUE = 29; end\n")
      File.write(File.join(dir, "outer.rb"), "Deferred\n$events << :outer_done\n")
      File.write(File.join(dir, "broken.rb"), "class Broken; end\nraise 'partial'\n")
      result = ruby_json(<<~'RUBY', setup: false, chdir: dir, env: {"RUBYLIB" => GEM_LIB})
        require "lowrail/passes"
        require "json"
        $events = []
        Object.autoload(:Deferred, File.expand_path("child.rb"))
        Object.autoload(:Broken, File.expand_path("broken.rb"))
        Lowrail::Passes.when_loaded(["Deferred"]) { $events << Deferred::VALUE }
        Lowrail::Passes.when_loaded(["Broken"]) { $events << :wrong }
        untouched = $events.empty? && !!Object.autoload?(:Deferred)
        begin
          Broken
        rescue RuntimeError
        end
        require "set" # An unrelated completion cannot authorize Broken.
        require File.expand_path("outer.rb")
        puts JSON.generate(untouched: untouched, events: $events)
      RUBY
      assert_equal({"untouched" => true, "events" => ["outer_done", 29]}, result)
    end
  end

  def test_bootstrap_and_targeted_completion_preserve_lazy_loading_and_jit_returns
    skip "Rails is not installed" unless LowrailTest.rails_installed?
    realpath_tmpdir do |dir|
      LowrailTest.write_rails_app(dir)
      env = {"RUBYOPT" => "-I#{GEM_LIB} --yjit --yjit-stats=quiet", "RAILS_ENV" => "test"}
      result = ruby_json(<<~'RUBY', setup: false, chdir: dir, env: env)
        require "lowrail/passes"
        require "lowrail/ar_guard"
        require "json"
        $events = []
        module RuntimeProbe
          def self.activate
            $events << Rails.application.initialized?
          end
        end
        Lowrail::AR.install
        Lowrail::Passes.after_initialize(RuntimeProbe)
        early = !defined?(Rails) && !defined?(ActiveSupport) && !defined?(ActiveRecord)
        require_relative "config/environment"
        # A late registration uses the same readiness path immediately.
        Lowrail::Passes.after_initialize(RuntimeProbe)
        def request(value) = value * 7 + 13
        1000.times { request(19) }
        before = RubyVM::YJIT.runtime_stats.fetch(:exit_trace_leave)
        value = request(19)
        exits = RubyVM::YJIT.runtime_stats.fetch(:exit_trace_leave) - before
        puts JSON.generate(early: early, events: $events, value: value, exits: exits,
          epochs_installed: Lowrail::AR.installed?)
      RUBY
      assert_equal({"early" => true, "events" => [true, true], "value" => 146,
        "exits" => 0, "epochs_installed" => true}, result)
    end
  end
end
