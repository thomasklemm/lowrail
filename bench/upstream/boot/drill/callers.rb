require_relative "../analyze"
pat = Regexp.new(ARGV.shift); top = 12
BootAnalyze.by_app(ARGV).each do |app, runs, n|
  t = Hash.new(0.0); tot = 0
  runs.each do |r, p, fr|
    w = BootAnalyze.weight(p)/n
    p["stacks"].each do |s, c|
      i = s.rindex { fr[_1] && fr[_1][0].match?(pat) } or next
      tot += c*w
      # first caller frame outside the matched frames and stdlib/pathname
      caller = s[0...i].reverse.map { fr[_1] }.find { |nm, f, _| f && f != "<cfunc>" && !f.include?("pathname") && !nm.match?(pat) }
      t["#{caller&.first} #{caller&.[](1).to_s.sub(/.*\/(gems|bundler\/gems)\//,"")}:#{caller&.[](2)}"] += c*w
    end
  end
  puts "## #{app}: #{tot.round} under /#{pat.source}/"
  t.sort_by { -_2 }.first(top).each { |k, v| puts format("  %8.0f %s", v, k) }
end
