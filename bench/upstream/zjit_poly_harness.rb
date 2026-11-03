require_relative File.join(ENV.fetch("RUBY_BENCH", "../lib"), "harness")
# ruby-bench harness for the ZJIT polymorphism probe (docs/upstream/zjit-polymorphism.md).
# Run from a ruby-bench checkout as: ruby --zjit -r ./harness/polyprobe.rb benchmarks/B/benchmark.rb

# Local harness: warm up, reset ZJIT stats (and the polyprobe), run measured
# iterations, then read RubyVM::ZJIT.stats (which writes the probe file).
WARMUP_ITRS = Integer(ENV.fetch('WARMUP_ITRS', 15))
MIN_BENCH_ITRS = Integer(ENV.fetch('MIN_BENCH_ITRS', 10))

def run_benchmark(_num_itrs_hint, **, &block)
  WARMUP_ITRS.times { block.call }
  RubyVM::ZJIT.reset_stats!
  MIN_BENCH_ITRS.times { block.call }
  s = RubyVM::ZJIT.stats
  keys = s.keys.grep(/send_fallback_|getivar_fallback_|dynamic_send_count|side_exit_count|send_count|zjit_insn_count/)
  puts "ITRS #{MIN_BENCH_ITRS}"
  keys.each { |k| puts "STAT #{k} #{s[k]}" if s[k].is_a?(Integer) && s[k] != 0 }
end
