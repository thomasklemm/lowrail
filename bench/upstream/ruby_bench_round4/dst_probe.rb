# Counts tzinfo period lookups in one lobsters pass after 2 warmup passes, split by
# whether TimeWithZone#wrap_with_time_zone missed its cached period (a DST crossing).
require File.join(Dir.pwd, "lib/harness")
def run_benchmark(_hint, **, &block)
  2.times { block.call }
  $c = Hash.new(0)
  ActiveSupport::TimeZone.prepend(Module.new {
    def period_for_local(*) = ($c[caller_locations(1, 1)[0].label.include?("ensure_valid") ? :refetch : :other] += 1; super)
    def periods_for_local(*) = ($c[:wrap] += 1; super)
  })
  block.call
  puts "DSTPROBE #{Time.now.utc} #{$c.sort.to_h}"
end
