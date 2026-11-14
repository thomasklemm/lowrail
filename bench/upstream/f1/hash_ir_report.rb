# hash_ir_report.rb LABEL=DIR... : Ir per op for each case of hash_ir.rb, one column per DIR, plus % vs the first.
require "json"

def totals(dir)
  meta = JSON.parse(File.read(File.join(dir, "cases.json")))
  files = Dir[File.join(dir, "cg.*.*")].select { _1 =~ /\.\d+\.\d+$/ }.sort_by { _1[/\.(\d+)$/, 1].to_i }
  irs = files.map { |f| Integer(File.foreach(f).find { _1.start_with?("totals: ") }.split[1]) }.drop(meta.fetch("skip_dumps", 0))
  failed = meta.fetch("jit_flat", {}).reject { |_, ok| ok }.keys
  warn "#{dir}: JIT-flat gate failed for #{failed.join(", ")}" unless failed.empty?
  raise "#{dir}: #{irs.size} dumps for #{meta["cases"].size} cases" unless irs.size == 2 * meta["cases"].size
  n = meta["n"]
  meta["cases"].each_with_index.to_h { |c, i| [c, (irs[2 * i + 1] - irs[2 * i]).fdiv(n)] }
end

cols = ARGV.map { _1.split("=", 2) }.map { |l, d| [l, totals(d)] }
base = cols.first[1]
puts ["case".ljust(28), *cols.map { _1[0].rjust(9) }, *cols.drop(1).map { "#{_1[0]} %".rjust(10) }].join(" ")
base.each_key do |c|
  vals = cols.map { _1[1][c] }
  pct = vals.drop(1).map { format("%+.1f%%", (_1 / vals[0] - 1) * 100).rjust(10) }
  puts [c.ljust(28), *vals.map { format("%9.1f", _1) }, *pct].join(" ")
end
