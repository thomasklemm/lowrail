# frozen_string_literal: true

# Preload in the suite runner, not its fixture subprocesses. Rake's parent
# loads this too but never starts Minitest, so it does not write a receipt.
if ENV["LOWRAIL_GATE_REPORT"]
  require "minitest"
  require "json"

  class LowrailGateReporter < Minitest::StatisticsReporter
    def census
      @threads = [@threads || 0, Dir["/proc/self/task/*"].size].max
    end

    def prerecord(*) = census
    def record(result)
      census
      super
    end

    def report
      super
      data = { tests: count, assertions: assertions, failures: failures,
        errors: errors, skips: skips, observed_threads: @threads,
        named_skips: results.select(&:skipped?).map { { test: "#{_1.klass}##{_1.name}", reason: _1.failure.message } } }
      File.write(options.fetch(:gate_report), JSON.pretty_generate(data) + "\n")
    end
  end

  def Minitest.plugin_lowrail_receipt_init(options)
    path = ENV.delete("LOWRAIL_GATE_REPORT")
    reporter << LowrailGateReporter.new(options[:io], options.merge(gate_report: path)) if path
  end
  Minitest.extensions << "lowrail_receipt"
end
