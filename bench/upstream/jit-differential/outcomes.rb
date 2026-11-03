# Per-test outcomes recorder. Loaded with -r; registers a Minitest plugin.
require "bundler/setup" if ENV["BUNDLE_GEMFILE"]
require "json"
require "minitest"
module JitdiffOutcomes
  PATH = ENV.fetch("JITDIFF_OUT")
  MAIN_PID = Process.pid
  class Reporter
    def initialize; @tests = {}; @pid = Process.pid; File.write("/tmp/jd.txt", "JITDIFF new\n", mode: "a") if ENV["JITDIFF_DEBUG"]; end
    def start; end
    def prerecord(klass, name); end
    def record(r)
      klass = r.respond_to?(:klass) ? r.klass : r.class.name
      res = if r.skipped? then "skip" elsif r.error? then "error" elsif r.passed? then "pass" else "fail" end
      f = r.failures.first
      msg = f ? "#{f.respond_to?(:error) ? f.error.class : f.class}: #{f.message.to_s.lines.first.to_s.strip[0, 300]}" : nil
      @tests["#{klass}##{r.name}"] = { "r" => res, "m" => msg }
      if defined?(JitdiffOutcomes::PRE) && (pre = JitdiffOutcomes::PRE["#{klass}##{r.name}"])
        @tests["#{klass}##{r.name}"]["p"] = pre
      end
    end
    def report
      File.write("/tmp/jd.txt", "JITDIFF report #{@tests.size} pid=#{Process.pid} #{@pid}\n", mode: "a") if ENV["JITDIFF_DEBUG"]
      File.write("#{PATH}", JSON.pretty_generate({ "ruby" => RUBY_DESCRIPTION, "zjit" => (defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?), "yjit" => (defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?), "argv" => ARGV, "pid" => @pid, "tests" => @tests })) if Process.pid == @pid
    end
    def passed?; true; end
  end
end
module JitdiffInit
  def init_plugins(options)
    super
    reporter << JitdiffOutcomes::Reporter.new unless reporter.reporters.any?(JitdiffOutcomes::Reporter)
  end
end
Minitest.singleton_class.prepend(JitdiffInit)
if (n = ENV["JITDIFF_REPEAT"].to_i) > 1
  module JitdiffRepeat
    def jitdiff_repeat(klass, method_name, reporter)
      (n_pre = ENV["JITDIFF_REPEAT"].to_i - 1).times do |i|
        r = klass.new(method_name).run
        res = if r.skipped? then "skip" elsif r.error? then "error" elsif r.passed? then "pass" else "fail" end
        (JitdiffOutcomes::PRE["#{klass}##{method_name}"] ||= []) << res
      end
    end
    if Minitest::VERSION.to_i >= 6
      def run(klass, method_name, reporter) = (jitdiff_repeat(klass, method_name, reporter); super)
    else
      def run_one_method(klass, method_name, reporter) = (jitdiff_repeat(klass, method_name, reporter); super)
    end
  end
  JitdiffOutcomes::PRE = {}
  Minitest::Runnable.singleton_class.prepend(JitdiffRepeat)
end
GC.auto_compact = true if ENV["JITDIFF_COMPACT"]
if ENV["JITDIFF_COVERAGE"]
  require "coverage"
  Coverage.start(lines: true, branches: true, methods: true)
  at_exit do
    if Process.pid == JitdiffOutcomes::MAIN_PID
      res = Coverage.result.select { |k, _| k.include?("/.corpus/rails/") && !k.include?("/test/") }
      out = res.transform_values do |v|
        { "lines" => v[:lines], "branches" => v[:branches]&.map { |b, t| [b.inspect, t.map { |k2, c| [k2.inspect, c] }] },
          "methods" => v[:methods]&.map { |m, c| [m.inspect, c] } }
      end
      File.write(JitdiffOutcomes::PATH + ".cov.json", JSON.generate(out))
    end
  end
end
