# frozen_string_literal: true

# attrib.rb DIR BASE HEAD : per workload of two script/cpu-census labels (interpreter, JIT-flat), the
# whole-workload change and the part of it in lead A1's methods (owner-condition bookkeeping, #59825/#59836)
# and lead C's (block forwarding in type lookups, #59816), as % of BASE's Ir per op.
require "json"
dir, base, head = ARGV
A1 = /WhereClause#(-|empty\?|initialize)$|WhereClause\.empty$|QueryMethods#where_clause$|keep_owner_conditions|AssociationScope#(add_constraints|last_chain_scope)$/
C = /Attribute#type_caster$|Table#type_for_attribute$|TypeCaster::Map#type_for_attribute$|TableAlias#type_for_attribute$/
load = lambda do |label|
  Dir[File.join(dir, label, "*-interpreter.json")].each_with_object({}) do |path, h|
    run = JSON.parse(File.read(path))
    run["workloads"].each do |w|
      next unless w.fetch("jit_flat", true)
      sum = ->(re) { w["methods"].select { |m| m["method"].match?(re) && m["file"].start_with?("RAILS/") }.sum { _1["self_ir_per_op"] } }
      h[[run["app"], w["workload"]]] = [w["ir_per_op"], sum.(A1), sum.(C)]
    end
  end
end
b, h = load.(base), load.(head)
rows = (b.keys & h.keys).sort.map { |k| [k, *[0, 1, 2].map { |i| (h[k][i] - b[k][i]) / b[k][0] * 100 }] }
puts "app\tworkload\ttotal\tA1\tC"
rows.each { |(app, wl), t, a, c| puts format("%s\t%s\t%+.2f%%\t%+.3f%%\t%+.3f%%", app, wl, t, a, c) }
med = ->(xs) { s = xs.sort; s[s.size / 2] }
all = ->(i) { (b.keys & h.keys).sum { h[_1][i] - b[_1][i] } / (b.keys & h.keys).sum { b[_1][0] } * 100 }
puts format("# %d workloads; A1 median %+.3f%% max %+.3f%%, of all Ir %+.3f%%; C median %+.3f%% max %+.3f%%, of all %+.3f%%; total of all %+.3f%%",
  rows.size, med.(rows.map { _3 }), rows.map { _3 }.max, all.(1), med.(rows.map { _4 }), rows.map { _4 }.max, all.(2), all.(0))
