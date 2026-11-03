# frozen_string_literal: true

# Ties ZJIT fallbacks to ISEQs and checks what YJIT does at the same ISEQ (docs/upstream/zjit-yjit-gap.md).
#   ruby SCRIPT CG_DIR ZJIT_STATS_ISEQ.json [LIMIT]
# ZJIT side: per-ISEQ fallback counters from --zjit-stats-iseq (counted at the ISEQ of the instruction's
# FrameState, so inlined callees count for themselves). YJIT side: generic calls made from that ISEQ's
# YJIT code in Callgrind run a (YJIT does not inline ISEQs). Extra = ZJIT fallbacks − YJIT generic calls
# of the same kind at that ISEQ, floored at 0. Price per extra operation (an estimate that treats every
# extra call alike): send/yield = Δ(method dispatch + block buckets + ZJIT entry trampoline) / extra
# sends and yields; ivar = Δ(ivar bucket) / extra ivar reads. Δ is the mean of runs a/b/c.
require "json"
require_relative "zjit_yjit_gap_buckets"

dir, stats_path, limit = ARGV
limit = Integer(limit || 30)

def norm(name)
  name.delete_prefix("JIT:").delete_prefix("[JIT] ").sub(/:\d+\z/, "")
      .sub(%r{/home/user/w/rbc/[^/]+/}, "").gsub(/__-?\d+_\d+/, "")
end

def short(name) = name.sub(%r{\A(.*?@).*/gems/}, '\1').sub(%r{\A(.*?@).*/lib/ruby/[^/]+/}, '\1')

KINDS = {
  "send" => %w[rb_vm_send rb_vm_opt_send_without_block rb_vm_invokesuper rb_vm_sendforward rb_vm_invokesuperforward],
  "yield" => %w[rb_vm_invokeblock rb_vm_yield_with_cfunc],
  "ivar" => %w[rb_ivar_get rb_vm_getinstancevariable rb_ivar_get_at_no_ractor_check rb_ivar_get_at rb_vm_setinstancevariable rb_ivar_set],
}.freeze

def kind_of_counter(c)
  case c
  when /\Asend_fallback_invokeblock_/ then "yield"
  when /\Asend_fallback_/ then "send"
  when /\A(get|set)ivar_fallback_/ then "ivar"
  when /\Aexit_/ then "exit"
  end
end

yjit = JSON.parse(File.read(File.join(dir, "yjit-a.cg.json")))
ygen = Hash.new(0)
yjit["edges"].each do |caller, callee, calls, _|
  next unless caller.start_with?("JIT:")
  kind = KINDS.find { |_, names| names.include?(callee) }&.first
  ygen[[norm(caller), kind]] += calls if kind
end

stats = JSON.parse(File.read(stats_path))["per_itr"]
sites = Hash.new { |h, k| h[k] = Hash.new(0) }
stats.each do |key, count|
  next unless key.start_with?("iseq:")
  counter, iseq = key.delete_prefix("iseq:").split(":", 2)
  kind = kind_of_counter(counter) or next
  sites[[norm(iseq), kind]][counter] += count
end

rows = sites.map do |(iseq, kind), counters|
  z = counters.values.sum
  y = kind == "exit" ? 0 : ygen[[iseq, kind]]
  [iseq, kind, z, y, [z - y, 0].max, counters.sort_by { -_2 }]
end

runs = ->(mode) { %w[a b c].filter_map { |v| f = File.join(dir, "#{mode}-#{v}.cg.json"); JSON.parse(File.read(f)) if File.exist?(f) } }
bucket_mean = lambda do |rs, label|
  rs.sum { |r| r["self"].sum { |n, ir| bucket_of(n) == label ? ir : 0 } } / rs.size
end
zr = runs.("zjit"); yr = runs.("yjit")
delta = ->(label) { bucket_mean.(zr, label) - bucket_mean.(yr, label) }
mapped = zr.select { _1["jit"].key?("entry trampoline") } # run c has no perf map
trampoline = mapped.sum { _1["jit"]["entry trampoline"] } / mapped.size
d_call = delta.("method dispatch (generic send path)") + delta.("block and proc invocation (generic)") + trampoline
d_ivar = delta.("ivar and attr access (generic)")
extra_call = rows.sum { |_, kind, _, _, e, _| %w[send yield].include?(kind) ? e : 0 }
extra_ivar = rows.sum { |_, kind, _, _, e, _| kind == "ivar" ? e : 0 }
price = {"send" => d_call / extra_call, "yield" => d_call / extra_call, "ivar" => d_ivar / extra_ivar}
puts "Price per extra operation: send/yield #{price["send"].round} Ir (#{(d_call / 1e6).round(1)} M over #{extra_call.round} calls), " \
     "ivar #{price["ivar"].round} Ir (#{(d_ivar / 1e6).round(1)} M over #{extra_ivar.round} reads)"
puts

by_reason = Hash.new(0)
reason_kind = {}
rows.each do |_, kind, z, _, extra, counters|
  next if z.zero?
  counters.each { |c, n| by_reason[c] += extra * n / z; reason_kind[c] = kind }
end

puts "#### Extra generic operations by ZJIT reason (ZJIT fallbacks not matched by a YJIT generic call at the same ISEQ; per iteration)"
puts
puts "| reason | ZJIT count | extra vs YJIT | est. M Ir |"
puts "|---|---:|---:|---:|"
totals = Hash.new(0)
stats.each { |k, v| totals[k] += v if !k.start_with?("iseq:") && kind_of_counter(k) }
by_reason.sort_by { -_2 }.first(limit).each do |c, e|
  ir = price[reason_kind[c]] ? format("%.1f", e * price[reason_kind[c]] / 1e6) : "–"
  puts "| `#{c}` | #{totals[c].round} | #{e.round} | #{ir} |"
end
puts
puts "#### Top sites (per iteration)"
puts
puts "| ISEQ | kind | ZJIT fallbacks | YJIT generic calls | extra | est. M Ir | ZJIT reasons |"
puts "|---|---|---:|---:|---:|---:|---|"
rows.sort_by { -_5 }.first(limit).each do |iseq, kind, z, y, extra, counters|
  reasons = counters.first(3).map { |c, n| "#{c.sub(/\A(send_fallback_|getivar_fallback_|setivar_fallback_)/, "")} #{n.round}" }.join(", ")
  ir = price[kind] ? format("%.1f", extra * price[kind] / 1e6) : "–"
  puts "| `#{short(iseq)[0, 95]}` | #{kind} | #{z.round} | #{y.round} | #{extra.round} | #{ir} | #{reasons} |"
end
puts
