require_relative "../lib/harness"
# Counts the callers of CALLERS_METHOD ("Const#meth") over one iteration after 3 warmup iterations (Z13 site probes).
def run_benchmark(_n, **, &block)
  3.times { block.call }
  owner_name, meth = ENV.fetch("CALLERS_METHOD").split("#")
  owner = Object.const_get(owner_name)
  counts = Hash.new(0)
  depth = Integer(ENV.fetch("CALLERS_DEPTH", 3))
  on = false
  owner.prepend(Module.new { define_method(meth) { |*a, **k, &b| counts[caller_locations(1, depth).map { _1.to_s.sub(%r{.*/gems/}, "") }] += 1 if on; super(*a, **k, &b) } })
  on = true
  block.call
  on = false
  counts.sort_by { -_2 }.first(Integer(ENV.fetch("CALLERS_TOP", 12))).each { |locs, n| puts "#{n.to_s.rjust(7)} #{locs.join("\n        ")}" }
end
