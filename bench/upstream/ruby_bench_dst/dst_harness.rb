# ruby-bench harness: WARM passes, then PASSES passes inside [0].cycle(1) so
# Callgrind's --toggle-collect=rb_ary_cycle measures only them.
# COUNT=1 counts tzinfo local lookups; FIX=1 loads the Active Support patch.
require File.join(ENV.fetch("RUBY_BENCH_DIR", File.expand_path("~/src/ruby-bench")), "lib/harness")
def run_benchmark(_n, **)
  require ENV["FIX"] if ENV["FIX"]
  if ENV["COUNT"]
    $tz = Hash.new(0)
    TZInfo::DataSources::TransitionsDataTimezoneInfo.prepend(Module.new { def periods_for_local(t) = ($tz[:tzinfo_lookups] += 1; super) })
    ActiveSupport::TimeZone.prepend(Module.new {
      def period_for_local(t, dst = true) = ($tz[:as_period_for_local] += 1; super)
      def periods_for_local(t) = ($tz[:as_periods_for_local] += 1; super)
    })
  end
  Integer(ENV.fetch("WARM", 3)).times { yield }
  $tz&.clear
  k = Integer(ENV.fetch("PASSES", 2))
  GC.start
  b = GC.stat(:total_allocated_objects); g = GC.count
  [0].cycle(1) { k.times { yield } }
  puts "DST allocs/pass=#{(GC.stat(:total_allocated_objects) - b).fdiv(k).round(1)} gc=#{GC.count - g} now=#{Time.now.utc} tz=#{$tz&.transform_values { _1.fdiv(k) }.inspect}"
end
