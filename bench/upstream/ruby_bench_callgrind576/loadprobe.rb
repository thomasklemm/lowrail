require File.join(ENV.fetch("RB_DIR"), "lib/harness")

def loadprobe_snapshot
  y = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? ? RubyVM::YJIT.runtime_stats : {}
  s = RubyVM.stat
  { features: $LOADED_FEATURES.size, const_inval: s[:constant_cache_invalidations],
    yjit_inval: y[:invalidation_count], compiled_iseq: y[:compiled_iseq_count] }
end

def run_benchmark(_hint, **, &block)
  Integer(ENV.fetch("WARMUP_ITRS", 5)).times { block.call; get_rss }
  Integer(ENV.fetch("MIN_BENCH_ITRS", 5)).times do |i|
    before = loadprobe_snapshot
    block.call
    get_rss
    after = loadprobe_snapshot
    puts "LOADPROBE itr=#{i + 1} " + after.map { |k, v| "#{k}=+#{v && before[k] ? v - before[k] : 'n/a'}" }.join(" ")
  end
end
