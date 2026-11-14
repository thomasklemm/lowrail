# frozen_string_literal: true

# calls.rb CASE: Ruby and C method calls per call of a CASE of attr_micro.rb (or MICRO=req_micro.rb)
# (TracePoint, 20 calls after warmup), for RAILS/WIDTH as in attr_micro.rb.
# Diff two trees' outputs to see which calls a change adds.
c = ARGV.fetch(0)
ARGV.replace([])
micro = File.join(__dir__, ENV.fetch("MICRO", "attr_micro.rb"))
src = File.read(micro).sub(/^(names = ARGV|n = Integer).*\z/m, "")
eval(src, TOPLEVEL_BINDING, micro)
fn = CASES.fetch(c)
50.times { fn.() }
counts = Hash.new(0)
tp = TracePoint.new(:call, :c_call) { |t| counts["#{t.defined_class}##{t.method_id}"] += 1 }
tp.enable { 20.times { fn.() } }
counts.sort_by { [-_2, _1] }.each { |k, v| puts format("%8.2f %s", v / 20.0, k) }
