require_relative "../lib/harness"
def run_benchmark(_n, **, &block)
  3.times(&block)
  counts = Hash.new(0)
  tp = TracePoint.new(:call) { |t| counts[t.method_id] += 1 if t.method_id == :resolve_attribute_name || (t.method_id == :escape && t.defined_class.name.to_s.end_with?("UriEncoder")) }
  n = 5
  tp.enable { n.times(&block) }
  puts "COUNTS #{counts.transform_values { _1.fdiv(n) }}"
end
