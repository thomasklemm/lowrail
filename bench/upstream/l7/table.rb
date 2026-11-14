# frozen_string_literal: true

# table.rb DIR: Markdown tables from sweep.sh output (DIR/*-{interp,yjit}.txt): main against 8.1
# per case, rows and width, with main2 (A/A), K1 and VB1 against main. A YJIT cell counts only
# when both trees compiled nothing in their measured windows.
dir = ARGV.fetch(0)
data = {}
Dir[File.join(dir, "*-{interp,yjit}.txt")].each do |f|
  File.foreach(f) do |line|
    tree, adapter, mode, c, rows, width, ir, obj, jit = line.split
    data[[tree, adapter, mode, c, rows.to_i, width.to_i]] = [ir.to_i, obj.to_f, jit.to_i]
  end
end
pct = ->(a, b) do
  x = ((a.fdiv(b) - 1) * 100).round(1)
  x.zero? ? "0.0%" : format("%+.1f%%", x).sub("-", "−")
end
%w[sqlite3 postgresql].each do |adapter|
  %w[interp yjit].each do |mode|
    keys = data.keys.select { _1[1] == adapter && _1[2] == mode && _1[0] == "main" }
    next if keys.empty?
    widths = keys.map(&:last).uniq.sort
    puts "### #{adapter == "sqlite3" ? "SQLite" : "PostgreSQL"}, #{mode == "interp" ? "interpreter" : "YJIT"}", ""
    puts "| Case | Rows | " + widths.map { "#{_1} cols: 8.1 → main (objects) | A/A | K1 | VB1" }.join(" | ") + " |"
    puts "| --- | ---: | " + widths.map { "---: | ---: | ---: | ---:" }.join(" | ") + " |"
    keys.map { _1[3..4] }.uniq.each do |c, rows|
      cells = widths.map do |w|
        k = ->(t) { data[[t, adapter, mode, c, rows, w]] }
        m, s = k.("main"), k.("s81")
        next "— | — | — | —" unless m && s
        flat = [m, s].all? { _1[2].zero? }
        main_vs = flat ? "#{pct.(m[0], s[0])} (#{s[1].round} → #{m[1].round})" : "not flat"
        others = %w[main2 k1 vb1].map { |t| (o = k.(t)) && o[2].zero? && m[2].zero? ? pct.(o[0], m[0]) : "—" }
        ([main_vs] + others).join(" | ")
      end
      puts "| #{c} | #{rows} | #{cells.join(" | ")} |"
    end
    puts
  end
end
