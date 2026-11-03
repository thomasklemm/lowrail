# frozen_string_literal: true

# ZJIT-minus-YJIT Ir by bucket, function, ISEQ and call edge (docs/upstream/zjit-yjit-gap.md).
#   ruby SCRIPT CG_DIR [section...]
# CG_DIR holds zjit-{a,b,c}.cg.json and yjit-{a,b,c}.cg.json from zjit_yjit_gap_cg.rb:
# a = --zjit-perf=iseq / --yjit-perf=iseq, b = --zjit-perf=hir / --yjit-perf=codegen, c = no perf map.
# Bucket numbers are means over the three runs; "spread" is the largest minus the smallest run.
require "json"

dir, *sections = ARGV
sections = %w[totals buckets functions jit hir dispatch iseq_dispatch unclassified] if sections.empty?
RUNS = %w[a b c].freeze
load_run = ->(mode, v) { path = File.join(dir, "#{mode}-#{v}.cg.json"); JSON.parse(File.read(path)) if File.exist?(path) }
Z = RUNS.filter_map { load_run.("zjit", _1) }
Y = RUNS.filter_map { load_run.("yjit", _1) }

require_relative "zjit_yjit_gap_buckets"

def mean(xs) = xs.sum.fdiv(xs.size)
def spread(xs) = xs.max - xs.min
def m(x) = format("%.1f", x / 1e6)
def pm(x) = format("%+.1f", x / 1e6)

totals_z = Z.map { _1["total"] }
totals_y = Y.map { _1["total"] }
gap = mean(totals_z) - mean(totals_y)

def by_bucket(run)
  run["self"].each_with_object(Hash.new(0)) { |(name, ir), h| h[bucket_of(name)] += ir }
end

if sections.include?("totals")
  puts "### Totals (M Ir per iteration)"
  puts
  puts "| mode | #{RUNS.map { "run #{_1}" }.join(" | ")} | mean | spread |"
  puts "|---|#{"---:|" * (RUNS.size + 2)}"
  [["ZJIT", totals_z], ["YJIT", totals_y]].each do |label, t|
    puts "| #{label} | #{t.map { m(_1) }.join(" | ")} | #{m(mean(t))} | #{format("%.2f%%", 100 * spread(t) / mean(t))} |"
  end
  puts "| ZJIT − YJIT | | | | #{pm(gap)} (#{format("%+.2f%%", 100 * gap / mean(totals_y))}) | |"
  puts
end

if sections.include?("buckets")
  bz = Z.map { by_bucket(_1) }
  by = Y.map { by_bucket(_1) }
  labels = (bz.flat_map(&:keys) | by.flat_map(&:keys))
  rows = labels.map do |l|
    zs = bz.map { _1[l] }; ys = by.map { _1[l] }
    [l, mean(zs), mean(ys), mean(zs) - mean(ys), [spread(zs), spread(ys)].max]
  end.sort_by { -_4 }
  puts "### Buckets (M Ir per iteration, mean of 3 runs per mode)"
  puts
  puts "| bucket | ZJIT | YJIT | ZJIT − YJIT | share of gap | run spread |"
  puts "|---|---:|---:|---:|---:|---:|"
  rows.each { |l, z, y, d, s| puts "| #{l} | #{m(z)} | #{m(y)} | **#{pm(d)}** | #{format("%.0f%%", 100 * d / gap)} | #{m(s)} |" }
  puts "| total | #{m(mean(totals_z))} | #{m(mean(totals_y))} | **#{pm(gap)}** | 100% | |"
  puts
end

def mean_self(runs)
  keys = runs.flat_map { _1["self"].keys }.uniq
  keys.to_h { |k| [k, mean(runs.map { _1["self"].fetch(k, 0) })] }
end

if sections.include?("functions") || sections.include?("unclassified")
  sz = mean_self(Z); sy = mean_self(Y)
  rows = (sz.keys | sy.keys).map { [_1, sz.fetch(_1, 0), sy.fetch(_1, 0)] }.map { |n, z, y| [n, z, y, z - y, bucket_of(n)] }
  if sections.include?("functions")
    puts "### Largest function differences (self Ir, M per iteration)"
    puts
    puts "| function | bucket | ZJIT | YJIT | ZJIT − YJIT |"
    puts "|---|---|---:|---:|---:|"
    rows.sort_by { -_4.abs }.first(Integer(ENV.fetch("FN_LIMIT", 40))).each { |n, z, y, d, b| puts "| `#{n[0, 80]}` | #{b.split(" (").first} | #{m(z)} | #{m(y)} | #{pm(d)} |" }
    puts
  end
  if sections.include?("unclassified")
    puts "### Unclassified (other runtime) differences above 0.5M"
    rows.select { _5.start_with?("other") && _4.abs > 5e5 }.sort_by { -_4.abs }.each { |n, z, y, d, _| puts "  #{pm(d)} #{n}" }
    puts
  end
end

# YJIT names an ISEQ by its first line, ZJIT by the line of its first instruction: compare by label@path.
def norm(name) = name.delete_prefix("JIT:").delete_prefix("[JIT] ").sub(/:\d+\z/, "")
def short(name) = name.sub(%r{\A(.*?@).*/gems/}, '\1').sub(%r{\A(.*?@).*/lib/ruby/[^/]+/}, '\1')

def jit_map(run)
  return {} unless run
  run["jit"].each_with_object(Hash.new(0)) { |(k, v), h| h[norm(k)] += v }
end

if sections.include?("jit")
  za = jit_map(Z[0]); ya = jit_map(Y[0])
  rows = (za.keys | ya.keys).map { [_1, za.fetch(_1, 0), ya.fetch(_1, 0)] }
  puts "### JIT code self Ir by ISEQ (run a; M per iteration)"
  puts
  puts "| ISEQ | ZJIT | YJIT | ZJIT − YJIT |"
  puts "|---|---:|---:|---:|"
  rows.sort_by { -(_2 - _3).abs }.first(Integer(ENV.fetch("JIT_LIMIT", 30))).each { |n, z, y| puts "| `#{short(n)[0, 110]}` | #{m(z)} | #{m(y)} | #{pm(z - y)} |" }
  puts
end

if sections.include?("hir")
  zb = jit_map(Z[1]); yb = jit_map(Y[1])
  tz = zb.values.sum; ty = yb.values.sum
  puts "### JIT code by ZJIT HIR instruction (run b, M per iteration; total #{m(tz)})"
  puts
  zb.sort_by { -_2 }.first(Integer(ENV.fetch("HIR_LIMIT", 25))).each { |n, v| puts "  #{m(v).rjust(7)} #{format("%5.1f%%", 100 * v / tz)} #{n}" }
  puts
  puts "### JIT code by YJIT codegen symbol (run b, M per iteration; total #{m(ty)})"
  puts
  yb.sort_by { -_2 }.first(Integer(ENV.fetch("HIR_LIMIT", 25))).each { |n, v| puts "  #{m(v).rjust(7)} #{format("%5.1f%%", 100 * v / ty)} #{n}" }
  puts
end

# Call edges whose caller is JIT code, summed by callee.
def jit_callees(runs)
  runs.map do |r|
    r["edges"].select { |c, *| c.start_with?("JIT:") }.each_with_object(Hash.new { |h, k| h[k] = [0, 0] }) do |(_, callee, calls, incl), h|
      h[callee][0] += calls
      h[callee][1] += incl
    end
  end
end

if sections.include?("dispatch")
  cz = jit_callees(Z); cy = jit_callees(Y)
  keys = cz.flat_map(&:keys) | cy.flat_map(&:keys)
  rows = keys.map do |k|
    [k, mean(cz.map { _1[k][0] }), mean(cy.map { _1[k][0] }), mean(cz.map { _1[k][1] }), mean(cy.map { _1[k][1] })]
  end
  puts "### C functions called from JIT code (calls per iteration; inclusive Ir includes callees)"
  puts
  puts "| callee | ZJIT calls | YJIT calls | ZJIT − YJIT calls | ZJIT incl M | YJIT incl M |"
  puts "|---|---:|---:|---:|---:|---:|"
  rows.sort_by { -(_2 - _3).abs }.first(Integer(ENV.fetch("CALL_LIMIT", 30))).each do |k, z, y, iz, iy|
    puts "| `#{k[0, 70]}` | #{z.round} | #{y.round} | #{(z - y).round} | #{m(iz)} | #{m(iy)} |"
  end
  puts
end

DISPATCH = (ENV["DISPATCH"] || "rb_vm_send,rb_vm_opt_send_without_block,rb_vm_invokeblock,rb_vm_invokesuper,rb_vm_sendforward,rb_vm_invokesuperforward,rb_ivar_get,rb_vm_getinstancevariable,rb_vm_setinstancevariable,rb_ivar_set,rb_hash_aref").split(",")
if sections.include?("iseq_dispatch")
  per = ->(run) {
    run["edges"].select { _1.start_with?("JIT:") && DISPATCH.include?(_2) }.each_with_object(Hash.new(0)) do |(caller, callee, calls, _), h|
      h[[norm(caller), callee]] += calls
    end
  }
  pz = per.(Z[0]); py = per.(Y[0])
  puts "### Generic calls from JIT code by ISEQ (run a; calls per iteration)"
  puts
  puts "| ISEQ | callee | ZJIT | YJIT | ZJIT − YJIT |"
  puts "|---|---|---:|---:|---:|"
  (pz.keys | py.keys).map { [_1, pz[_1], py[_1]] }.sort_by { -(_2 - _3) }.first(Integer(ENV.fetch("ISEQ_LIMIT", 40))).each do |(iseq, callee), z, y|
    puts "| `#{short(iseq)[0, 100]}` | `#{callee}` | #{z.round} | #{y.round} | #{(z - y).round} |"
  end
  puts
end
