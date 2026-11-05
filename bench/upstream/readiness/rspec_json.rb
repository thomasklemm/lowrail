# frozen_string_literal: true

# RSpec's JSON formatter, writing one file per process into READINESS_RSPEC_DIR, so suites that start several
# RSpec processes (flatware workers, rake tasks that run rspec more than once) keep every result. Processes that
# a suite's own tests start in generated projects inherit SPEC_OPTS but run under another Gemfile; they write
# nothing, so their examples don't count as the suite's.
require "fileutils"
require "rspec/core/formatters/json_formatter"

class LowrailReadinessJSON < RSpec::Core::Formatters::JsonFormatter
  RSpec::Core::Formatters.register self, :message, :dump_summary, :dump_profile, :stop, :seed, :close

  def initialize(_output)
    unless File.basename(ENV.fetch("BUNDLE_GEMFILE", "")).start_with?("Gemfile.eco-")
      return super(File.open(File::NULL, "w"))
    end
    dir = ENV.fetch("READINESS_RSPEC_DIR")
    FileUtils.mkdir_p(dir)
    super(File.open(File.join(dir, "#{Process.pid}-#{Process.clock_gettime(Process::CLOCK_REALTIME, :nanosecond)}.json"), "w"))
  end

  def close(notification)
    super
    output.close unless output.closed?
  end
end
