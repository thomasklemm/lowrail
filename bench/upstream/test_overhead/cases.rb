# frozen_string_literal: true

# Workloads for perf_round/percall.sh; app bundles and helpers stay unmodified.
require "json"
require "stringio"
root = File.realpath(File.join(ENV.fetch("RAILS_PATH"), "app"))
Dir.chdir(root)
ENV["RAILS_ENV"] = "test"
require File.join(root, "config/application")
Rails.application.config.yjit = ENV["PTEST_YJIT"] == "1"
$LOAD_PATH.unshift(File.join(root, "test"), File.join(root, "spec"))

if ENV.fetch("PTEST_FRAMEWORK") == "minitest"
  require File.join(root, ENV.fetch("PTEST_FILE"))
  require "rails/test_unit/reporter"
  Minitest.seed = 4242
  klass = Object.const_get(ENV.fetch("PTEST_CLASS"))
  name = ENV.fetch("PTEST_NAME")
  if ENV["PTEST_EMPTY"] == "1"
    klass.define_method(name) { self.assertions = 1 }
  elsif ENV["PTEST_EMPTY"] == "literal"
    klass.define_method(name) {}
  end
  measure_class = klass
  reporter = Rails::TestUnitReporter.new(StringIO.new, {})
  reporter.start
  operation = -> {
    result = klass.new(name).run
    raise result.failures.map(&:message).join("\n") unless result.passed?
    reporter.record(result)
    reporter.io.truncate(0)
    reporter.io.rewind
  }
  at_exit do
    error = $!
    warn error.full_message if error && !error.is_a?(SystemExit)
    exit!(error.is_a?(SystemExit) ? error.status : error ? 1 : 0)
  end
else
  require "rspec/core"
  runner = RSpec::Core::Runner.new(RSpec::Core::ConfigurationOptions.new([ENV.fetch("PTEST_FILE"), "--seed", "4242"]))
  runner.setup($stderr, StringIO.new)
  example = RSpec.world.all_examples.find { _1.full_description == ENV.fetch("PTEST_NAME") }
  raise "example not found" unless example
  example.instance_variable_set(:@example_block, proc {}) if ENV["PTEST_EMPTY"] == "1"
  config = RSpec.configuration
  reporter = config.reporter
  config.send(:run_suite_hooks, "a `before(:suite)` hook", config.instance_variable_get(:@before_suite_hooks))
  group = example.example_group
  measure_class = group
  group.parent_groups.reverse_each { _1.run_before_context_hooks(_1.new) }
  operation = -> {
    example.instance_variable_set(:@exception, nil)
    example.instance_variable_set(:@execution_result, RSpec::Core::Example::ExecutionResult.new)
    instance = group.new
    group.parent_groups.reverse_each { |g| g.before_context_ivars.each { |key, value| instance.instance_variable_set(key, value) } }
    raise example.exception.full_message unless example.run(instance, reporter)
  }
end

if (phase = ENV["PTEST_PHASE"])
  Integer(ENV.fetch("PTEST_PHASE_WARMUP", "2000")).times { operation.call }
  require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
  if phase.start_with?("example.")
    measure_class = RSpec::Core::Example
    phase = phase.delete_prefix("example.")
  end
  if phase == "ptest_seam"
    measure_class.define_method(:ptest_seam) {}
    operation = -> { measure_class.allocate.send(:ptest_seam) }
  end
  measure_class.prepend(Module.new do
    define_method(phase) do
      LowrailCallgrindBench.start
      begin
        super()
      ensure
        LowrailCallgrindBench.finish
      end
    end
  end)
end

warn "PTEST #{JSON.generate(root: root, ruby: RUBY_DESCRIPTION, rails: Rails.version,
  yjit: RubyVM::YJIT.enabled?, name: ENV.fetch("PTEST_NAME"), empty: ENV["PTEST_EMPTY"] == "1")}"
MICRO = { "test" => -> { operation } }
