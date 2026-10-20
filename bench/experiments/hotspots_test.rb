# frozen_string_literal: true

# Run under the patched Valgrind with both compiled extensions in ENV.
# Independent isolated Ir prices, asymmetric nested work, recursive frames,
# native primitives and a full GC exercise the profiler's public contract.
require "json"
require ENV.fetch("BENCH_CALLGRIND_EXTENSION")
require ENV.fetch("HOTSPOT_EXTENSION")
eval(<<~'RUBY', TOPLEVEL_BINDING, "hotspot-a.rb")
  def a
    x = 0
    20_000.times { |i| x += i * 3 }
    raise "wrong A result" unless x == 599_970_000
  end
  def parent(depth = 2)
    return parent(depth - 1) if depth.positive?
    a
    b
  end
RUBY
eval(<<~'RUBY', TOPLEVEL_BINDING, "hotspot-b.rb")
  def b
    x = 0
    60_000.times { |i| x += i * 7 }
    raise "wrong B result" unless x == 12_599_790_000
  end
RUBY
parent
[-> { a }, -> { b }].each do |operation|
  LowrailCallgrindBench.start
  10.times { operation.call }
  LowrailCallgrindBench.finish
end
LowrailCallgrindBench.start
HotspotProbe.measure(2, 918273) { 10.times { parent } }
LowrailCallgrindBench.finish
LowrailCallgrindBench.start
HotspotProbe.measure(3, 728193) { GC.start(full_mark: true, immediate_sweep: true) }
LowrailCallgrindBench.finish
3.times { GC.start }
result = HotspotProbe.results
window = result.fetch("windows").fetch(2)
raise "lost/delayed samples" unless window["issued"] == window["signals"] && window["lag_max_ir"] < 3277
raise "invalid stack capture" unless window.values_at("empty", "truncated", "dropped") == [0, 0, 0]
own = Hash.new(0)
inclusive = Hash.new(0)
result.fetch("stacks").each do |paths, counts|
  own[paths.first] += counts.fetch(2)
  paths.uniq.each { inclusive[_1] += counts.fetch(2) }
end
total = window.fetch("signals")
raise "self must partition" unless own.values.sum == total
raise "recursion must not double count" unless inclusive.values.max <= total
raise "A must include B" unless inclusive.fetch("hotspot-a.rb") > total * 0.97 && own.fetch("hotspot-a.rb") < total * 0.35
prices = (1..2).map do |part|
  Integer(File.foreach("#{ENV.fetch('HOTSPOT_TEST_DUMP')}.#{part}").find { _1.start_with?("totals:") }.split.fetch(1))
end
expected = prices.last.fdiv(prices.sum)
observed = inclusive.fetch("hotspot-b.rb").fdiv(total)
raise "instruction weighting failed: #{[expected, observed]}" unless (observed - expected).abs < 0.03
raise "full GC not sampled" unless result.fetch("windows").fetch(3).fetch("gc").positive?
puts JSON.pretty_generate(passed: true, samples: total, expected_b_inclusive: expected,
  observed_b_inclusive: observed, b_self: own.fetch("hotspot-b.rb").fdiv(total),
  a_inclusive: inclusive.fetch("hotspot-a.rb").fdiv(total),
  lag_max_ir: window.fetch("lag_max_ir"), gc_samples: result.fetch("windows").fetch(3).fetch("gc"))
