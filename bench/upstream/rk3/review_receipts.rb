require "json"

data = File.expand_path("../../../docs/upstream/data/rk3", __dir__)
cohorts = {
  "interp" => ["req-interp.txt"],
  "yjit" => ["req-yjit.txt"],
  "yjit FLAT=40" => ["req-yjit-pingcrm-flat.txt"]
}
cohorts.each do |label, files|
  groups = Hash.new { |h, k| h[k] = [] }
  files.each do |file|
    File.foreach(File.join(data, file)) do |line|
      match = /\A(.*?) (interp|yjit) (\S+) Ir\/op (\d+) objs\/op ([\d.]+)(?: jit (\d+)\/(\d+) settle (\d+))?/.match(line)
      next unless match
      groups[match[1]] << { patch: match[3], ir: match[4].to_i, objects: match[5].to_f, jit: match[6] && [match[6].to_i, match[7].to_i] }
    end
  end
  puts "\n#{label} (A/A spread / base mean)"
  groups.each do |workload, rows|
    base = rows.select { |r| r[:patch] == "none.rb" }
    mean = base.sum { |r| r[:ir] }.fdiv(base.size)
    aa = 100 * (base.map { |r| r[:ir] }.max - base.map { |r| r[:ir] }.min) / mean
    objects = base.sum { |r| r[:objects] }.fdiv(base.size)
    flat = rows.all? { |r| r[:jit] == [0, 0] }
    printf "%s: base %.1f, A/A %.3f%%, %s\n", workload, mean, aa, label == "interp" ? "interpreter" : "all windows flat=#{flat}"
    rows.reject { |r| r[:patch] == "none.rb" }.each do |row|
      printf "  %s %.3f%%, objects %.2f -> %.1f (saved %.2f)\n", row[:patch], 100 * (row[:ir] / mean - 1), objects, row[:objects], objects - row[:objects]
    end
  end
end

%w[interp yjit].each do |mode|
  puts "\nBody benchmark-ips #{mode}: independently computed best of three / main spread"
  by_name = Hash.new { |h, k| h[k] = Hash.new { |g, side| g[side] = [] } }
  Dir[File.join(data, "body-ips", "*-#{mode}-*.json")].sort.each do |file|
    side = File.basename(file).split("-").first
    JSON.parse(File.read(file)).each { |row| by_name[row.fetch("name")][side] << row.fetch("central_tendency") }
  end
  by_name.each do |name, sides|
    main, candidate = sides.fetch("main"), sides.fetch("branch")
    printf "%s %.0f -> %.0f (%.3fx), A/A %.3f%%\n", name, main.max, candidate.max, candidate.max / main.max, 100 * (main.max - main.min) / main.min
  end
end
