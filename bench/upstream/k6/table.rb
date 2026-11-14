# frozen_string_literal: true

# table.rb DIR MODE: Markdown table from sweep.sh output (DIR/TREE-MODE.txt for
# pre, main, main2, k6). Under yjit a cell counts only when main, main2 and k6
# compiled nothing in their measured windows; pre counts only when it was flat too.
dir, mode = ARGV
read = ->(tree) do
  path = File.join(dir, "#{tree}-#{mode}.txt")
  File.exist?(path) ? File.readlines(path).to_h { |l| c, ir, obj, jit, = l.split; [c, { ir: Float(ir), obj: Float(obj), jit: Integer(jit) }] } : {}
end
pre, main, main2, k6 = %w[pre main main2 k6].map(&read)
fmt = ->(x) { x.round.to_s.reverse.scan(/\d{1,3}/).join(",").reverse }
pct = ->(a, b) { format("%+.1f%%", (a / b - 1) * 100).sub("-", "−") }
puts "| Case | before #50312 | main | K6 | K6 vs main | K6 vs before #50312 | A/A | objects before / main / K6 |"
puts "| --- | ---: | ---: | ---: | ---: | ---: | ---: | --- |"
main.each do |c, m|
  m2 = main2[c] or next
  k = k6[c] or next
  p = pre[c]
  flat = [m, m2, k].all? { _1[:jit].zero? }
  if mode == "yjit" && !flat
    puts "| `#{c}` | | not flat | not flat | | | | |"
    next
  end
  pre_ok = p && (mode != "yjit" || p[:jit].zero?)
  aa = format("%.2f%%", ((m2[:ir] / m[:ir]) - 1).abs * 100)
  objs = [p && fmt.(p[:obj]), fmt.(m[:obj]), fmt.(k[:obj])].map { _1 || "—" }.join(" / ")
  puts "| `#{c}` | #{pre_ok ? fmt.(p[:ir]) : (p ? "not flat" : "—")} | #{fmt.(m[:ir])} | #{fmt.(k[:ir])} | #{pct.(k[:ir], m[:ir])} | " \
       "#{pre_ok ? pct.(k[:ir], p[:ir]) : "—"} | #{aa} | #{objs} |"
end
