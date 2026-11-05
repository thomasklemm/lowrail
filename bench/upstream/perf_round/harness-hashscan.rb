# ruby-bench harness (copy to harness/hashscan.rb): WARMUP_ITRS iterations, then one iteration with
# allocation tracing and GC disabled. Afterwards every Hash allocated in that iteration is grouped by
# allocation site: count, mean size, mean memsize, and how many hold an st_table (memsize above the
# largest ar_table slot). Objects with more than 30 ivars are grouped by class. Writes HS_OUT (JSON).
require_relative "../lib/harness"
require "objspace"


WARMUP_ITRS = Integer(ENV.fetch("WARMUP_ITRS", 2))

def run_benchmark(_hint, **)
  WARMUP_ITRS.times { yield }
  root = ENV["CG_RAILS"].to_s + "/"
  rel = ->(path) { path.to_s.sub(root, "RAILS/").sub(%r{\A.*/gems/}, "GEM/").sub(%r{\A.*/benchmarks/}, "BENCH/") }
  GC.start
  GC.disable
  gen = GC.count
  ObjectSpace.trace_object_allocations { yield }
  sites = Hash.new { |h, k| h[k] = { "count" => 0, "size" => 0, "memsize" => 0, "st" => 0, "sizes" => Hash.new(0) } }
  wide = Hash.new { |h, k| h[k] = { "count" => 0, "ivars" => Hash.new(0), "memsize" => 0 } }
  ObjectSpace.each_object(Hash) do |h|
    next unless ObjectSpace.allocation_generation(h) == gen
    file = ObjectSpace.allocation_sourcefile(h) or next
    s = sites["#{rel.(file)}:#{ObjectSpace.allocation_sourceline(h)}"]
    m = ObjectSpace.memsize_of(h)
    s["count"] += 1; s["size"] += h.size; s["memsize"] += m; s["sizes"][h.size] += 1
    s["st"] += 1 if m > 160
  end
  ObjectSpace.each_object(Object) do |o|
    next unless ObjectSpace.allocation_generation(o) == gen
    n = o.instance_variables.size rescue next
    next unless n > 30
    w = wide[(o.class.name rescue "?").to_s]
    w["count"] += 1; w["ivars"][n] += 1; w["memsize"] += ObjectSpace.memsize_of(o)
  end
  GC.enable
  require "json"
  File.write(ENV.fetch("HS_OUT"), JSON.generate(ruby: RUBY_DESCRIPTION, hashes: sites, wide: wide) + "\n")
end
