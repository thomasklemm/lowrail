require_relative "../analyze"
pat = Regexp.new(ARGV.shift); top = Integer(ENV.fetch("TOP", "15"))
BootAnalyze.by_app(ARGV).each do |app, runs, n|
  t = Hash.new(0.0); tot = 0.0; all = 0.0
  runs.each do |r, p, fr|
    w = BootAnalyze.weight(p)/n
    p["stacks"].each do |s, c|
      all += c*w
      next unless s.any? { fr[_1] && fr[_1][0].match?(pat) }
      tot += c*w
      leaf = fr[s.last]
      ruby = s.reverse.map { fr[_1] }.find { _1 && _1[1] && _1[1] != "<cfunc>" && !_1[1].empty? }
      key = leaf && leaf[1] == "<cfunc>" ? "#{ruby&.first} > #{leaf[0]}" : leaf&.first
      t[key] += c*w
    end
  end
  puts "## #{app} under /#{pat.source}/: #{tot.round(1)} (#{(100*tot/all).round(2)}%)"
  t.sort_by { -_2 }.first(top).each { |k, v| puts format("  %7.1f  %s", v, k) }
end
