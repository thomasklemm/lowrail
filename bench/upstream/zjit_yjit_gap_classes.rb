# frozen_string_literal: true

# Sorts the ZJIT − YJIT instruction gap into the classes of bet Z13 (docs/upstream/zjit-yjit-gap.md):
#   ruby SCRIPT CG_DIR ZJIT_STATS.json YJITII_STATS.json
# CG_DIR holds {zjit,yjit}-{a,b,c}.cg.json from zjit_yjit_gap_cg.rb; ZJIT_STATS.json is a GAP_MODE=stats run with
# --zjit-stats-iseq and GAP_II=1, YJITII_STATS.json the same build with --yjit and GAP_II=1.
#
# Function buckets (zjit_yjit_gap_buckets.rb) give Δ self Ir per mechanism. Δ of the generic call path (method dispatch,
# block invocation, ZJIT entry trampoline) and Δ of generic ivar access are spread over ZJIT's fallback reasons in
# proportion to their extra operations against YJIT at the same ISEQ (zjit_yjit_gap_sites.rb), at one price per
# extra send or yield and one per extra ivar read. "Not compiled" is ZJIT's interpreted YARV instructions in ISEQs
# without JIT code at ZJIT's Ir per interpreted instruction; the rest of Δ interpreter is interpretation after exits.
# YJIT's split is not comparable (YJIT sets jit_entry only for entries from the interpreter, so code it reaches
# JIT-to-JIT and exits from counts as "without JIT code"); its totals are printed for reference.
require "json"
require_relative "zjit_yjit_gap_buckets"

dir, zstats_path, yii_path = ARGV

CLASS_OF_REASON = [
  # Profile-driven: the site is specialized for what its profile saw; other receivers or blocks go generic.
  [/\Asend_fallback_(send_polymorphic_fallback|send_polymorphic|send_megamorphic|send_no_profiles|invokeblock_polymorphic_miss|super_polymorphic|super_fallback_no_profile|singleton_class_seen)\z/, "fallbacks: polymorphic, megamorphic, unprofiled"],
  [/\A(get|set)ivar_fallback_/, "missing specialization: ivars"],
  [/\Asend_fallback_(invokeblock_not_specialized|send_block_arg_not_nil|bmethod_non_iseq_proc)\z/, "missing specialization: blocks"],
  [/\Asend_fallback_super_/, "missing specialization: super"],
  [/\Asend_fallback_(one_or_more_complex_arg_pass|sendforward_not_specialized|invokesuperforward_not_specialized|argc_param_mismatch|unexpected_keyword_args|send_direct_)/, "missing specialization: splat, kwargs, forwarding"],
  [/\Asend_fallback_send_cfunc_|\Asend_fallback_obj_to_string/, "missing specialization: cfuncs"],
  [/\Asend_fallback_send_not_optimized_/, "missing specialization: protected, send, other method types"],
  [/\Asend_fallback_/, "missing specialization: other"],
].freeze

def class_of_reason(c) = CLASS_OF_REASON.find { |re, _| c.match?(re) }&.last

def norm(name)
  name.delete_prefix("JIT:").delete_prefix("[JIT] ").sub(/:\d+\z/, "")
      .sub(%r{/home/user/w/rbc/[^/]+/}, "").gsub(/__-?\d+_\d+/, "")
end

def kind_of_counter(c)
  case c
  when /\Asend_fallback_invokeblock_/ then "yield"
  when /\Asend_fallback_/ then "send"
  when /\A(get|set)ivar_fallback_/ then "ivar"
  end
end

KINDS = {
  "send" => %w[rb_vm_send rb_vm_opt_send_without_block rb_vm_invokesuper rb_vm_sendforward rb_vm_invokesuperforward],
  "yield" => %w[rb_vm_invokeblock rb_vm_yield_with_cfunc],
  "ivar" => %w[rb_ivar_get rb_vm_getinstancevariable rb_ivar_get_at_no_ractor_check rb_ivar_get_at rb_vm_setinstancevariable rb_ivar_set],
}.freeze

runs = ->(mode) { %w[a b c].filter_map { |v| f = File.join(dir, "#{mode}-#{v}.cg.json"); JSON.parse(File.read(f)) if File.exist?(f) } }
zr = runs.("zjit"); yr = runs.("yjit")
mean = ->(xs) { xs.sum.fdiv(xs.size) }
bucket = ->(rs, label) { mean.(rs.map { |r| r["self"].sum { |n, ir| bucket_of(n) == label ? ir : 0 } }) }
delta = ->(label) { bucket.(zr, label) - bucket.(yr, label) }
gap = mean.(zr.map { _1["total"] }) - mean.(yr.map { _1["total"] })
mapped = zr.select { _1["jit"].key?("entry trampoline") }
trampoline = mean.(mapped.map { _1["jit"]["entry trampoline"] })

# Extra generic operations per ZJIT reason against YJIT's generic calls at the same ISEQ (run a).
ya = yr.first
ygen = Hash.new(0)
ya["edges"].each do |caller, callee, calls, _|
  next unless caller.start_with?("JIT:")
  kind = KINDS.find { |_, names| names.include?(callee) }&.first
  ygen[[norm(caller), kind]] += calls if kind
end
zstats = JSON.parse(File.read(zstats_path))
stats = zstats["per_itr"]
sites = Hash.new { |h, k| h[k] = Hash.new(0) }
stats.each do |key, count|
  next unless key.start_with?("iseq:")
  counter, iseq = key.delete_prefix("iseq:").split(":", 2)
  kind = kind_of_counter(counter) or next
  sites[[norm(iseq), kind]][counter] += count
end
extra = Hash.new(0)
sites.each do |(iseq, kind), counters|
  z = counters.values.sum
  e = [z - ygen[[iseq, kind]], 0].max
  counters.each { |c, n| extra[c] += e * n / z }
end
calls = extra.sum { |c, e| %w[send yield].include?(kind_of_counter(c)) ? e : 0 }
reads = extra.sum { |c, e| kind_of_counter(c) == "ivar" ? e : 0 }
d_call = delta.("method dispatch (generic send path)") + delta.("block and proc invocation (generic)") + trampoline
d_ivar = delta.("ivar and attr access (generic)")
price = { "send" => d_call / calls, "yield" => d_call / calls, "ivar" => d_ivar / reads }

# Interpreted instructions per iteration, split by whether the ISEQ had JIT code.
ii = ->(data) { data["interp_iseqs"].each_with_object([0.0, 0.0]) { |(_, u, c), acc| acc[0] += u; acc[1] += c } }
zu, zc = ii.(zstats)
yu, yc = ii.(JSON.parse(File.read(yii_path)))
ir_per_insn = ->(rs, n) { bucket.(rs, "interpreter (YARV loop and insn helpers)") / n }
pz = ir_per_insn.(zr, zu + zc); py = ir_per_insn.(yr, yu + yc)
not_compiled = zu * pz
after_exit = delta.("interpreter (YARV loop and insn helpers)") - not_compiled

classes = Hash.new(0)
extra.each { |c, e| classes[class_of_reason(c)] += e * price[kind_of_counter(c)] }
classes["code ZJIT does not compile (interpreted ISEQs without JIT code)"] += not_compiled
classes["fallbacks: side exits and frame materialization"] += delta.("side exits and frame materialization")
classes["fallbacks: interpreter after side exits"] += after_exit
classes["codegen quality in compiled code (JIT code without the entry trampoline)"] += delta.("JIT code") - trampoline
classes["GC, allocation, write barriers"] += delta.("GC (marking, sweeping, freeing)") +
  delta.("allocation (objects, malloc)") + delta.("write barriers")
classes["everything else (cfunc bodies and runtime, compile, invalidation)"] +=
  gap - classes.values.sum

m = ->(x) { format("%+.1f", x / 1e6) }
puts "Gap #{m.(gap)} M Ir per iteration. Price per extra send/yield #{price["send"].round} Ir " \
     "(#{(d_call / 1e6).round(1)} M over #{calls.round}), per extra ivar read #{price["ivar"].round} Ir " \
     "(#{(d_ivar / 1e6).round(1)} M over #{reads.round}). Interpreted insns per iteration: ZJIT #{zu.round} in " \
     "ISEQs without JIT code + #{zc.round} after exits at #{pz.round(1)} Ir; YJIT #{yu.round} + #{yc.round} at #{py.round(1)} Ir."
puts
puts "| class | M Ir | share of gap |"
puts "|---|---:|---:|"
classes.sort_by { -_2 }.each { |label, ir| puts "| #{label} | #{m.(ir)} | #{format("%.0f%%", 100 * ir / gap)} |" }
puts
puts "| reason | class | extra per iteration | M Ir |"
puts "|---|---|---:|---:|"
extra.select { _2 >= 500 }.sort_by { -_2 * price[kind_of_counter(_1)] }.each do |c, e|
  puts "| `#{c}` | #{class_of_reason(c).sub(/\A[^:]+: /, "")} | #{e.round} | #{m.(e * price[kind_of_counter(c)])} |"
end
