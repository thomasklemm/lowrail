# frozen_string_literal: true

# table.rb DIR NAME MODE TREE... : Markdown table of a sweep.sh run, Ir/call and objects/call
# per tree, and each tree's change against the first. Cells with YJIT blocks compiled in the
# measured window are marked "(not flat)".
dir, name, mode, *trees = ARGV
rows = trees.to_h do |t|
  path = File.join(dir, "#{name}-#{t}-#{mode}.txt")
  [t, File.exist?(path) ? File.readlines(path).to_h { |l| c, ir, obj, jit = l.split; [c, [ir.to_f, obj.to_f, jit.to_i]] } : {}]
end
base = rows.fetch(trees.first)
puts "| Case | #{trees.join(" | ")} |"
puts "| --- |#{" ---: |" * trees.size}"
base.each_key do |c|
  cells = trees.map do |t|
    ir, obj, jit = rows[t][c]
    next "—" unless ir
    s = "#{ir.round.to_s.gsub(/\B(?=(\d{3})+\z)/, ",")} / #{obj.round(1)}"
    s += format(" (%+.1f%%)", (ir / base[c][0] - 1) * 100) unless t == trees.first
    s += " (not flat)" if jit.positive?
    s
  end
  puts "| #{c} | #{cells.join(" | ")} |"
end
