# compact.rb DIR MODE: main vs 8.1 for query/read/includes/inc_read/fresh at 1/10/50/100 rows, SQLite and PG x widths
dir, mode = ARGV
data = {}
Dir[File.join(dir, "*-#{mode}.txt")].each { |f| File.foreach(f) { |l| t, a, _, c, r, w, ir, _o, j = l.split; data[[t, a, c, r.to_i, w.to_i]] = [ir.to_i, j.to_i] } }
pct = ->(a, b) { x = ((a.fdiv(b) - 1) * 100).round(1); x.zero? ? "0.0%" : format("%+.1f%%", x).sub("-", "−") }
cols = %w[sqlite3 postgresql].product([6, 15, 30])
puts "| Case | Rows | " + cols.map { |a, w| "#{a == "sqlite3" ? "SQLite" : "PG"} #{w}" }.join(" | ") + " |"
puts "| --- | ---: |" + " ---: |" * cols.size
%w[fresh query read includes inc_read].each do |c|
  [1, 10, 50, 100].each do |r|
    cells = cols.map do |a, w|
      m, s = data[["main", a, c, r, w]], data[["s81", a, c, r, w]]
      next "—" unless m && s
      m[1].zero? && s[1].zero? ? pct.(m[0], s[0]) : "not flat"
    end
    puts "| #{c} | #{r} | #{cells.join(" | ")} |"
  end
end
