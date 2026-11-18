require "json"

root = File.expand_path("../../..", __dir__)
body = File.join(__dir__, "body/RK3")
data = JSON.parse(File.read(File.join(body, "results.json")))
abort "wrong base" unless data.fetch("sides").fetch("base").fetch("head") == "da90464e3fa93e3cb49dc2d4ede798e6c6b70b4f"
abort "wrong head" unless data.fetch("sides").fetch("candidate").fetch("head") == "02087583dc3685b9f805e3dd975aeb89d1444824"
abort "dirty benchmark trees" if data.fetch("sides").values.any? { |side| side.fetch("dirty") }

puts "Body instructions: recomputed from raw N=0/N=2000 Callgrind logs"
data.fetch("instructions").group_by { |key, _| key.split(" ", 2).first }.each do |mode, rows|
  rows.each_with_index do |(key, result), index|
    name = key.split(" ", 2).last
    measured = %w[base base2 candidate].map do |side|
      counts = [0, data.fetch("n")].map do |n|
        file = "ir-#{mode}-#{index + 1}-#{name.gsub(/\W+/, "_")}-#{side}-n#{n}.valgrind.log"
        raw = File.read(File.join(body, "raw", file))
        abort "Valgrind overflow in #{file}" if raw.match?(/brk segment overflow|Cannot map memory to grow brk segment/)
        Integer(raw.scan(/Collected : (\d+)/).last.fetch(0))
      end
      (counts.last - counts.first).fdiv(data.fetch("n"))
    end
    expected = result.values_at("base1", "base2", "candidate")
    abort "raw mismatch #{key}" unless measured.zip(expected).all? { |a, b| (a - b).abs < 0.000001 }
    baseline = (measured[0] + measured[1]) / 2.0
    change = 100 * (measured.last / baseline - 1)
    aa = 100 * (measured[0] - measured[1]).abs / baseline
    printf "%s: %.1f / %.1f -> %.1f, delta %+.4f%%, A/A %.4f%%\n", key, *measured, change, aa
  end
end

puts "\nBody objects: recomputed from worker output"
data.fetch("objects").each do |key, result|
  mode, name = key.split(" ", 2)
  values = %w[base base2 candidate].map do |side|
    raw = File.readlines(File.join(body, "raw", "objects-#{mode}-#{side}.log"))
    line = raw.find { |text| text.start_with?("objects #{name}\t") }
    Float(line.split("\t").last)
  end
  abort "object mismatch #{key}" unless values == result.values_at("base1", "base2", "candidate")
  puts "#{key}: #{values.join(' / ')}"
end

puts "\nBody YJIT rates: best candidate versus mean of two independent best-of-three baselines"
data.fetch("ips").each do |name, result|
  rounds = %w[base base2 candidate].map do |side|
    (1..3).map do |round|
      text = File.read(File.join(body, "raw", "ips-r#{round}-#{side}.log"))
      line = text.lines.find { |row| row.strip.start_with?(name) && row.include?("i/s") }
      rate, unit = line.match(/\s([\d.]+)([kM]?) \(±/).captures
      Float(rate) * { "" => 1, "k" => 1000, "M" => 1_000_000 }.fetch(unit)
    end
  end
  abort "rate mismatch #{name}" unless rounds == result.fetch("rounds").values_at("base", "base2", "candidate")
  b1, b2, candidate = rounds.map(&:max)
  baseline = (b1 + b2) / 2.0
  aa = 100 * (b1 - b2).abs / baseline
  all_base = rounds.first(2).flatten
  spread = 100 * (all_base.max - all_base.min) / all_base.min
  printf "%s: %.1f -> %.1f, %.4fx, best-baseline A/A %.4f%%, raw baseline-round range %.4f%%\n", name, baseline, candidate, candidate / baseline, aa, spread
end

puts "\nWhole requests: independent aggregate arithmetic, not a rerun of the app experiments"
%w[fh-interp.txt fh-interp2.txt fh-interp3.txt fh-yjit.txt].each do |file|
  groups = File.readlines(File.join(root, "docs/upstream/data/rk3/final-head", file)).filter_map do |line|
    match = /\A(.*?) (interp|yjit) (\S+) Ir\/op (\d+) objs\/op ([\d.]+) jit (\S+)/.match(line)
    next unless match
    [match[1], { patch: match[3], ir: match[4].to_i, objects: match[5].to_f, jit: match[6] }]
  end.group_by(&:first)
  puts "#{file}: #{%w[fh-interp.txt fh-interp2.txt].include?(file) ? 'REJECTED, retained' : 'accepted cohort'}"
  groups.each do |name, pairs|
    rows = pairs.map(&:last)
    bases = rows.select { |row| row.fetch(:patch) == "none.rb" }
    mean = bases.sum { |row| row.fetch(:ir) }.fdiv(bases.size)
    aa = 100 * (bases.map { |row| row.fetch(:ir) }.max - bases.map { |row| row.fetch(:ir) }.min) / mean
    both = rows.find { |row| row.fetch(:patch) == "rk34.rb" }
    change = 100 * (both.fetch(:ir) / mean - 1)
    saved = bases.sum { |row| row.fetch(:objects) }.fdiv(bases.size) - both.fetch(:objects)
    printf "%s: base %.1f (%d runs), both %+.4f%%, A/A %.4f%%, saved %.3f objects, all windows flat=%s\n", name, mean, bases.size, change, aa, saved, rows.all? { |row| row.fetch(:jit) == "0/0" }
  end
end
