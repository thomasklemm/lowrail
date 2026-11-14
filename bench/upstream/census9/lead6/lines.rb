# frozen_string_literal: true

# Lead 6: Ruby line and method-call counts per call of an attr_micro.rb case.
#   RAILS=DIR WIDTH=300 ruby lines.rb [CASE]   prints "count path:line" (lines) and "count C Class#method" (C calls)
# Paths are shown relative to RAILS. Counts are per call, over N (default 10) calls after warmup.
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
tp = TracePoint.new(:line, :c_call, :call) do |t|
  path = t.path
  case t.event
  when :line then counts["L #{path.delete_prefix(root)}:#{t.lineno}"] += 1 if path.start_with?(root)
  when :call then counts["R #{t.defined_class}##{t.method_id}"] += 1
  when :c_call then counts["C #{t.defined_class}##{t.method_id}"] += 1
  end
end
tp.enable { n.times { fn.() } }
counts.sort_by { |k, v| [-v, k] }.each { |k, v| puts format("%10.1f %s", v.fdiv(n), k) }
