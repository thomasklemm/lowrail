# btab.rb LIST : per-iteration Ir (one process) of exe_intro_big and exe_large per commit, vs previous row
fmt = ->(x) { x.to_i.to_s.reverse.scan(/\d{1,3}/).join(",").reverse }
ir = ->(c, s, n) { f = "/tmp/cg/b#{c}-a.#{s}.#{n}.out"; File.exist?(f) ? File.read(f)[/^summary: (\d+)/, 1].to_i : nil }
prev = {}
File.readlines(ARGV[0], chomp: true).each do |c|
  row = %w[exe_intro_big exe_large].map do |s|
    a, b = ir.(c, s, 1), ir.(c, s, 3)
    next "#{s} n/a" unless a && b
    m = (b - a) / 2
    d = prev[s] ? format("%+.2f%%", 100.0 * (m - prev[s]) / prev[s]) : ""
    prev[s] = m
    "#{s} #{fmt.(m)} #{d}"
  end
  puts "#{c} #{`git -C /tmp/gr log -1 --format=%s #{c}`.strip[0, 50]}: #{row.join(" | ")}"
end
