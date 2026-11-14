# frozen_string_literal: true

# Lead 6: Ruby method calls per call of an attr_micro.rb case, keyed by "callee <- caller method (call site)".
#   RAILS=DIR WIDTH=300 ruby sites.rb [CASE]   (compare two widths with slope.rb)
ENV["N"] = "1"
ENV["WARM"] = "50"
kase = ARGV.first || "update1"
ARGV.replace([kase])
$stdout = File.open(File::NULL, "w")
load File.expand_path("../attr_micro.rb", __dir__)
$stdout = STDOUT
fn = CASES.fetch(kase)
50.times { fn.() }
root = File.expand_path(ENV.fetch("RAILS")) + "/"
n = Integer(ENV.fetch("CALLS", "10"))
counts = Hash.new(0)
tp = TracePoint.new(:call, :c_call) do |t|
  loc = caller_locations(2, 1).first
  site = loc ? "#{loc.path.delete_prefix(root)}:#{loc.lineno} #{loc.label}" : "?"
  counts["#{t.event == :call ? "R" : "C"} #{t.defined_class}##{t.method_id} <- #{site}"] += 1
end
tp.enable { n.times { fn.() } }
counts.sort_by { |k, v| [-v, k] }.each { |k, v| puts format("%10.1f %s", v.fdiv(n), k) }
