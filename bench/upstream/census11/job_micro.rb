# frozen_string_literal: true

# Census 11: per-call Ir and objects of perform_now (#59893 sets the job with
# ExecutionContext.set and a block), for a Rails checkout in RAILS. Same
# measurement and output as census9/req_micro.rb; run with census10/sweep.sh.
rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord activejob].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_support/core_ext"
require "active_record"
require "active_job"
require ENV.fetch("IR_COUNT_SO", File.expand_path("~/c9/ext/ir_count.so"))

ActiveJob::Base.logger = Logger.new(nil)
ActiveSupport.event_reporter.debug_mode = false if ActiveSupport.respond_to?(:event_reporter)
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil

class EmptyJob < ActiveJob::Base
  def perform(x) = x
end

CASES = {
  "perform_now" => -> { EmptyJob.perform_now(1) },
  "exec_context_assign" => -> { ActiveSupport::ExecutionContext[:job] = 1 },
  "exec_context_set_block" => -> { ActiveSupport::ExecutionContext.set(job: 1) { } },
}

n = Integer(ENV.fetch("N", "300"))
warm = Integer(ENV.fetch("WARM", "300"))
yjit = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
blocks = -> { yjit ? RubyVM::YJIT.runtime_stats[:compiled_block_count] : 0 }
IrCount.start if IrCount.running?
(ARGV.empty? ? CASES.keys : ARGV).each do |name|
  fn = CASES.fetch(name)
  warm.times { fn.() }
  if yjit
    flat = 0
    30.times do
      b = blocks.()
      n.times { fn.() }
      flat = blocks.() == b ? flat + 1 : 0
      break if flat == 3
    end
  end
  GC.start
  GC.disable
  b0 = blocks.()
  o0 = GC.stat(:total_allocated_objects)
  i0 = IrCount.now
  n.times { fn.() }
  i1 = IrCount.now
  o1 = GC.stat(:total_allocated_objects)
  jit = blocks.() - b0
  GC.enable
  puts format("%-24s %12.1f %8.2f %d", name, (i1 - i0).fdiv(n), (o1 - o0).fdiv(n), jit)
  $stdout.flush
end
