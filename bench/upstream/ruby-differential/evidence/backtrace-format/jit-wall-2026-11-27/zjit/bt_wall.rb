# Wall cohort for BT1: 50 frames deep, as benchmark/vm_backtrace_to_s.yml. A report block runs at the worker's
# shallow stack, so caller and Exception#backtrace recurse inside each call; the recursion is the same on both sides.
def deep(n, &b) = n.zero? ? b.call : deep(n - 1, &b)

locations = deep(50) { caller_locations }
UpstreamBench.report("caller") { deep(50) { caller } }
UpstreamBench.report("Exception#backtrace") do
  deep(50) do
    raise "x"
  rescue => e
    e.backtrace
  end
end
UpstreamBench.report("locations.each(&:to_s)") { locations.each(&:to_s) }
