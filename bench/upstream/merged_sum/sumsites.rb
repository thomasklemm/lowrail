require_relative "../lib/harness"

# Allocation sites of one ruby-bench iteration, for Lowrail's
# docs/upstream/merged-sum.md: WARMUP_ITRS warmup iterations, then one traced
# iteration with GC disabled; every object it allocated is counted by Rails
# source file and line. Writes the census JSON shape (one workload) to SUM_OUT.
WARMUP_ITRS = Integer(ENV.fetch("WARMUP_ITRS", 5))

def run_benchmark(_hint, **)
  WARMUP_ITRS.times { yield }
  require "objspace"
  GC.start
  GC.disable
  gen = GC.count
  ObjectSpace.trace_object_allocations { yield }
  counts = Hash.new(0)
  ObjectSpace.each_object do |o|
    next unless ObjectSpace.allocation_generation(o) == gen
    file = ObjectSpace.allocation_sourcefile(o) or next
    rel = file[%r{/src/wt/[^/]+/(.+)\z}, 1] or next
    counts[[rel, ObjectSpace.allocation_sourceline(o)]] += 1
  end
  GC.enable
  require "json" # after Bundler.setup
  sites = counts.map { |(f, l), n| { "file" => "RAILS/#{f}", "line" => l, "objects_per_op" => n.to_f } }
  File.write(ENV.fetch("SUM_OUT"), JSON.generate("workloads" => [{ "workload" => "iteration", "sites" => sites }]))
end
