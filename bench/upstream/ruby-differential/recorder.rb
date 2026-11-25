# Loaded with -r (RUBYOPT) by script/ruby-differential into every Ruby process of a suite run.
# The first process records which JIT ran and, for Minitest suites, every test's outcome.
main = [nil, Process.pid.to_s].include?(ENV["RDIFF_MAIN_PID"])
ENV["RDIFF_MAIN_PID"] = Process.pid.to_s

# Rails' :enable_yjit initializer (config.yjit, true under load_defaults 7.2) and apps such as Writebook
# and Sure call RubyVM::YJIT.enable after boot; the interpreter baseline must stay on the interpreter.
if ENV["RDIFF_MODE"].to_s.start_with?("interp") && defined?(RubyVM::YJIT.enable)
  RubyVM::YJIT.singleton_class.prepend(Module.new { def enable(*, **) = false })
end

if main && (jit_out = ENV["RDIFF_JIT_OUT"])
  at_exit do
    if Process.pid.to_s == ENV["RDIFF_MAIN_PID"]
      state = { "ruby" => RUBY_DESCRIPTION, "yjit" => !!(defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?),
        "zjit" => !!(defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?) }
      File.write(jit_out, state.map { |k, v| "#{k}=#{v}" }.join("\n") + "\n")
    end
  end
end

if main && ENV["RDIFF_KIND"] == "minitest" && (path = ENV["RDIFF_OUT"])
  require "bundler/setup"
  require "json"
  require "minitest"
  module RdiffOutcomes
    class Reporter
      def initialize(path) = (@path, @pid, @tests = path, Process.pid, {})
      def start; end
      def prerecord(*); end
      def passed? = true

      def record(r)
        klass = r.respond_to?(:klass) ? r.klass : r.class.name
        res = if r.skipped? then "skip" elsif r.error? then "error" elsif r.passed? then "pass" else "fail" end
        f = r.failures.first
        exc = f && (f.respond_to?(:error) ? f.error.class.name : f.class.name)
        msg = f && f.message.to_s.lines.first.to_s.strip[0, 300]
        loc = r.respond_to?(:source_location) ? r.source_location.join(":") : nil
        @tests["#{klass}##{r.name}"] = { "r" => res, "e" => exc, "m" => msg, "loc" => loc }.compact
      end

      def report
        return unless Process.pid == @pid
        File.write(@path, JSON.generate("kind" => "minitest", "tests" => @tests))
      end
    end
  end
  Minitest.singleton_class.prepend(Module.new do
    define_method(:init_plugins) do |options|
      super(options)
      reporter << RdiffOutcomes::Reporter.new(path) unless reporter.reporters.any?(RdiffOutcomes::Reporter)
    end
  end)
end
