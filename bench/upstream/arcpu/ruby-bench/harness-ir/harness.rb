# frozen_string_literal: true

# Instruction counts for ruby-bench under Callgrind: warm up, then run the
# measured iterations inside Array#cycle, the only rb_ary_cycle call, so
#   valgrind --tool=callgrind --collect-atstart=no --toggle-collect=rb_ary_cycle
# collects exactly those iterations. WARMUP_ITRS (default 3), IR_ITRS (default 2).
require_relative "../harness/harness-common"

def run_benchmark(_n, **, &block)
  Integer(ENV.fetch("WARMUP_ITRS", "3")).times(&block)
  GC.start
  n = Integer(ENV.fetch("IR_ITRS", "2"))
  # GC off in the window: mutator instructions only, independent of GC timing.
  GC.disable
  [nil].cycle(1) { n.times(&block) }
  GC.enable
  puts "ir: measured #{n} iterations"
  puts "RUBY_LOADED_RAILS=#{$LOADED_FEATURES.grep(%r{/activerecord/lib/active_record\.rb\z}).first}"
end
