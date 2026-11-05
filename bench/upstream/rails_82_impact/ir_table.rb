# frozen_string_literal: true

# Instruction table for docs/upstream/rails-82-impact.md from ruby_bench_ir.rb
# (ruby-bench) or census_ir_run.rb (app GET pages) results:
#   ruby ir_table.rb ruby-bench DIR    # files TAG-BENCH-MODE-VARIANT-ITRS.ir
#   ruby ir_table.rb apps DIR          # files APP-MODE-VARIANT-ITRS.ir
# Per benchmark and mode: Ir per iteration (long minus short run) for each
# tree's A/A pair, then each comparison as the change of pair means. A row is
# claimed when |Δ| > 2 × the larger A/A of its two pairs, and, under YJIT,
# when all four runs were JIT-flat (jit_counts.rb); otherwise it is rejected.
kind, dir = ARGV
abort "usage: ir_table.rb ruby-bench|apps DIR" unless dir
PAIRS = { "main" => %w[sum-main sum-main2 main main2], "minus-ours" => %w[sum-rev sum-rev2 rev rev2],
          "8-1-stable" => %w[imp-81 imp-81b e81 e812], "merge-base" => %w[mb-a mb-b mb mb2],
          "main+Erubi" => %w[erb-a erb-b] }.freeze
re = kind == "apps" ? /\A(?<bench>[^-]+)-(?<mode>interpreter|yjit)-(?<var>.+)-(?<itrs>\d+)\z/ :
                      /\A[^-]+-(?<bench>.+)-(?<mode>interpreter|yjit)-(?<var>.+)-(?<itrs>\d+)\z/
ir = Dir[File.join(dir, "*.ir")].filter_map do |f|
  m = File.basename(f, ".ir").match(re) or next
  [[m[:bench], m[:mode], m[:var], m[:itrs].to_i], Integer(File.read(f))]
end.to_h
per = ir.keys.map { _1[0, 3] }.uniq.filter_map do |k|
  itrs = ir.keys.select { _1[0, 3] == k }.map(&:last).sort
  next if itrs.size < 2
  [k, (ir[[*k, itrs.last]] - ir[[*k, itrs.first]]) / (itrs.last - itrs.first).to_f]
end.to_h
flat = lambda do |k|
  return true unless k[1] == "yjit"
  itrs = ir.keys.select { _1[0, 3] == k }.map(&:last).max
  s = File.read(Dir[File.join(dir, "*#{k[0]}-#{k[1]}-#{k[2]}-#{itrs}.jit")].first.to_s) rescue (return false)
  s[/before: (\{.*?\})/, 1] == s[/after: (\{.*?\})/, 1]
end
pair = lambda do |b, m, name|
  vs = PAIRS[name].select { per.key?([b, m, _1]) }.first(2)
  vs.size == 2 ? { mean: vs.sum { per[[b, m, _1]] } / 2, aa: (per[[b, m, vs[1]]] / per[[b, m, vs[0]]] - 1) * 100, flat: vs.all? { flat.([b, m, _1]) } } : nil
end
CMP = [["main", "8-1-stable", "total"], ["main", "minus-ours", "ours"], ["minus-ours", "8-1-stable", "residual (others)"],
       ["8-1-stable", "merge-base", "8-1 backports"], ["main+Erubi", "main", "Herb control"]].freeze
puts "| Benchmark | Mode | Comparison | Ir/iteration old → new | Δ | A/A new, old | Verdict |"
puts "| --- | --- | --- | ---: | ---: | ---: | --- |"
per.keys.map { _1[0, 2] }.uniq.sort.each do |b, m|
  CMP.each do |new, old, label|
    n, o = pair.(b, m, new), pair.(b, m, old)
    next unless n && o
    d = (n[:mean] / o[:mean] - 1) * 100
    v = !(n[:flat] && o[:flat]) ? "rejected (not JIT-flat)" : d.abs > 2 * [n[:aa].abs, o[:aa].abs].max ? "claimed" : "rejected (A/A)"
    puts format("| %s | %s | %s: %s vs %s | %.4g → %.4g | %+.2f%% | %+.2f%%, %+.2f%% | %s |", b, m, label, new, old, o[:mean], n[:mean], d, n[:aa], o[:aa], v)
  end
end
