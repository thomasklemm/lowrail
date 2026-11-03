require_relative "../lib/harness"

# Local ruby-bench harness: ZJIT send counters per iteration after warmup.
# Run with --zjit --zjit-stats. Prints one "ZJITSEND <json>" line.
WARMUP_ITRS = Integer(ENV.fetch('WARMUP_ITRS', 15))
MIN_BENCH_ITRS = Integer(ENV.fetch('MIN_BENCH_ITRS', 10))

KEYS = %i[
  send_count dynamic_send_count optimized_send_count
  send_fallback_send_not_optimized_method_type_optimized
  unspecialized_send_def_type_optimized_send
  send_fallback_send_name_not_constant_symbol
].freeze

puts RUBY_DESCRIPTION

def run_benchmark(_num_itrs_hint, **, &block)
  WARMUP_ITRS.times { block.call }
  RubyVM::ZJIT.reset_stats!
  MIN_BENCH_ITRS.times { block.call }
  stats = RubyVM::ZJIT.stats
  out = KEYS.to_h { |k| [k, (stats[k] || 0).fdiv(MIN_BENCH_ITRS)] }
  out[:itrs] = MIN_BENCH_ITRS
  require 'json'
  puts "ZJITSEND #{JSON.generate(out)}"
end
