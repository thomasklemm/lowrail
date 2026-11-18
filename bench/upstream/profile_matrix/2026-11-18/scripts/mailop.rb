# Allocations per call (GC.stat, so hidden VM objects too) of the DSL's mail op shape against a plain lambda.
o = Object.new
lets = {}
r = Object.new
o.define_singleton_method(:reply) { lets.fetch(:reply) { lets[:reply] = r } }
o.define_singleton_method(:recipient) { lets.fetch(:recipient) { lets[:recipient] = r } }
def o.deliver(a, b) = nil
dsl = proc { deliver(reply, recipient) }
op_dsl = -> { o.instance_exec(&dsl) }
x = r; y = r
op_yml = eval("-> { o.deliver(x, y) }", binding, "mailer", 1)
plain_ret = proc { deliver(r, r) }
op_exec = -> { o.instance_exec(&plain_ret) }
GC.disable
{ "dsl (instance_exec + 2 lets)" => op_dsl, "instance_exec, no lets" => op_exec, "yaml-like lambda" => op_yml }.each do |name, op|
  3.times { op.() }
  a = GC.stat(:total_allocated_objects); 1000.times { op.() }; b = GC.stat(:total_allocated_objects)
  base_a = GC.stat(:total_allocated_objects); 1000.times { }; base_b = GC.stat(:total_allocated_objects)
  printf "%-30s %.3f\n", name, ((b - a) - (base_b - base_a)) / 1000.0
end
