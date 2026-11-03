require_relative "../analyze"
phase = ARGV.shift.to_sym
top = Integer(ENV.fetch("TOP","25"))
BootAnalyze.by_app(ARGV).each do |app, runs, n|
  t = Hash.new(0.0); tot = 0.0
  runs.each do |r, p, fr|
    w = BootAnalyze.weight(p)/n
    p["stacks"].each do |s, c|
      next unless BootAnalyze.phase_of(s, fr) == phase
      tot += c*w
      leaf = fr[s.last]
      ruby = s.reverse.map { fr[_1] }.find { _1 && _1[1] && _1[1] != "<cfunc>" && !_1[1].empty? }
      key = leaf && leaf[1] == "<cfunc>" ? "#{ruby&.first} > #{leaf[0]}" : leaf&.first
      t[key] += c*w
    end
  end
  puts "## #{app} #{phase}: #{tot.round} ms"
  t.sort_by { -_2 }.first(top).each { |k, v| puts format("  %6.1f  %s", v, k) }
end
