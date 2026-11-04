# frozen_string_literal: true

# RSpec's JSON formatter, writing one file per process into READINESS_RSPEC_DIR, so suites that start several
# RSpec processes (flatware workers, rake tasks that run rspec more than once) keep every result.
require "fileutils"
require "rspec/core/formatters/json_formatter"

class LowrailReadinessJSON < RSpec::Core::Formatters::JsonFormatter
  RSpec::Core::Formatters.register self, :message, :dump_summary, :dump_profile, :stop, :seed, :close

  def initialize(_output)
    dir = ENV.fetch("READINESS_RSPEC_DIR")
    FileUtils.mkdir_p(dir)
    super(File.open(File.join(dir, "#{Process.pid}-#{Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)}.json"), "w"))
  end

  def close(notification)
    super
    output.close unless output.closed?
  end
end
