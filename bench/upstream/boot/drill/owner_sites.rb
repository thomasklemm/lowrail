require_relative "../analyze"
prefix = ARGV.shift; top = Integer(ENV.fetch("TOP", "15"))
ARGV.each do |path|
  r, p, fr = BootAnalyze.load(path); root = BootAnalyze.app_root(r)
  t = Hash.new(0); total = 0
  p["stacks"].each do |s, n|
    total += n
    id = s.reverse.find { f = fr[_1]; f && f[1] && f[1] != "<cfunc>" && !f[1].empty? }
    name, file, line = fr[id] || ["?", "?", 0]
    next unless BootAnalyze.owner(file, root).start_with?(prefix)
    t["#{file.to_s.sub(%r{.*/rails-\h+/}, "")}:#{line} #{name} [#{fr[s.last]&.first}]"] += n
  end
  puts "## #{r["app"]} #{prefix}: #{t.values.sum} of #{total}"
  t.sort_by { -_2 }.first(top).each { |k, v| puts format("  %7d %5.2f%% %s", v, 100.0 * v / total, k[0, 170]) }
end
