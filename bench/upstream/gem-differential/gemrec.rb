# Loaded with -r (RUBYOPT) into every Ruby process of a gem suite run by script/gem-differential.
# Hooks Minitest, RSpec and test-unit once each is loaded, and appends one JSON line per finished test
# to $GEMREC_DIR/PID.tsv, so suites that run their tests in child processes (rake test) are recorded too.
# It loads no library: requiring json here would activate the default gem before Bundler picks the locked one.
if (dir = ENV["GEMREC_DIR"])
  module GemRec
    @dir = ENV["GEMREC_DIR"]
    @hooked = {}

    def self.emit(id, result, exc = nil, msg = nil)
      fields = [id, result, exc, msg && msg.to_s.lines.first.to_s.strip[0, 300]]
      File.open(File.join(@dir, "#{Process.pid}.tsv"), "a") { |f| f.puts(fields.map { _1.to_s.b.unpack1("H*") }.join("\t")) }
    rescue StandardError
      nil
    end

    def self.hook!
      if !@hooked[:minitest] && defined?(::Minitest::CompositeReporter)
        @hooked[:minitest] = true
        ::Minitest::CompositeReporter.prepend(Module.new do
          def record(r)
            klass = r.respond_to?(:klass) ? r.klass : r.class.name
            res = if r.skipped? then "skip" elsif r.error? then "error" elsif r.passed? then "pass" else "fail" end
            f = r.failures.first
            exc = f && (f.respond_to?(:error) ? f.error.class.name : f.class.name)
            GemRec.emit("#{klass}##{r.name}", res, exc, f&.message)
            super
          end
        end)
      end
      if !@hooked[:rspec] && defined?(::RSpec::Core::Reporter)
        @hooked[:rspec] = true
        ::RSpec::Core::Reporter.prepend(Module.new do
          def example_finished(example)
            er = example.execution_result
            res = { passed: "pass", failed: "fail", pending: "skip" }.fetch(er.status, er.status.to_s)
            e = er.exception
            res = "error" if res == "fail" && e && !e.is_a?(::RSpec::Expectations::ExpectationNotMetError) &&
              !(defined?(::RSpec::Mocks::MockExpectationError) && e.is_a?(::RSpec::Mocks::MockExpectationError))
            GemRec.emit("#{example.id} #{example.full_description}"[0, 400], res, e&.class&.name, e&.message)
            super
          end
        end)
      end
      if !@hooked[:testunit] && defined?(::Test::Unit::TestCase) && ::Test::Unit::TestCase.method_defined?(:run)
        @hooked[:testunit] = true
        ::Test::Unit::TestCase.prepend(Module.new do
          def run(result, ...)
            before = result.respond_to?(:faults) ? result.faults.size : 0
            ret = super
            faults = result.respond_to?(:faults) ? result.faults[before..] : []
            kinds = faults.map { |f| f.class.name.split("::").last }
            res = if kinds.include?("Error") then "error" elsif kinds.include?("Failure") then "fail"
                  elsif kinds.any? { %w[Pending Omission].include?(_1) } then "skip" else "pass" end
            bad = faults.find { %w[Error Failure].include?(_1.class.name.split("::").last) }
            exc = bad && (bad.respond_to?(:exception) ? bad.exception.class.name : bad.class.name)
            GemRec.emit("#{self.class.name}##{name}", res, exc, bad&.message)
            ret
          end
        end)
      end
    end
  end

  module GemRecRequire
    private def require(path)
      ret = super
      GemRec.hook! if path.to_s.match?(/minitest|rspec|test.unit|test-unit/)
      ret
    end
  end
  Kernel.prepend(GemRecRequire)
  GemRec.hook!
end
