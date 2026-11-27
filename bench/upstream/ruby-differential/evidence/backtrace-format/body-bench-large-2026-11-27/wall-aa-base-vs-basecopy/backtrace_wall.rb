# Depth 50, as in benchmark/vm_backtrace_to_s.yml.
def deep(n, &block) = n.zero? ? block.call : deep(n - 1, &block)
def deep_raise(n) = n.zero? ? raise("x") : deep_raise(n - 1)

locations = deep(50) { caller_locations }

UpstreamBench.report("Location#to_s") { locations.each(&:to_s) }
UpstreamBench.report("caller") { deep(50) { caller } }
UpstreamBench.report("Exception#backtrace") do
  deep_raise(50)
rescue => e
  e.backtrace
end
