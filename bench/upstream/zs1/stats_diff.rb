# stats_diff.rb MASTER MASTER_AGAIN BRANCH: diff of three `--zjit-stats` texts in diff format.
# A counter is printed when the branch differs from master by more than MIN_REL of its value, by more than MIN_ABS
# and by more than NOISE times the master/master-again difference. Times, ratios and byte sizes are left out.
MIN_REL = Float(ENV.fetch("MIN_REL", "0.01"))
MIN_ABS = Integer(ENV.fetch("MIN_ABS", "1000"))
NOISE = Float(ENV.fetch("NOISE", "3"))
SKIP = /_time\z|_ratio\z|_bytes\z|\Agc_time|\Aprofile_time/

def parse(path)
  section, left = nil, 0
  File.readlines(path, chomp: true).each_with_object({}) do |line, h|
    if (m = line.match(/\ATop-(\d+) (.+?) \(([\d.]+)% of total ([\d,]+)\):\z/))
      section, left = m[2], m[1].to_i
      h[[section, :total]] = [m[4].delete(",").to_i, "#{section} (total)"]
      h[[section, :complete]] = [0, nil] if m[3] == "100.0"
    elsif (m = line.match(/\A\s*(\S.*?):\s+([\d,]+)(?: \(\s*[\d.]+%\))?\z/))
      section = nil if left == 0
      left -= 1
      h[[section, m[1]]] = [m[2].delete(",").to_i, m[1]]
    end
  end
end

fmt = ->(n) { n.to_s.reverse.scan(/\d{1,3}/).join(",").reverse }
a, a2, b = ARGV.map { parse(_1) }
# A list that covers 100% of its total is complete, so an entry missing from one side is 0 there.
complete = ->(section) { section && [a, a2, b].all? { _1.key?([section, :complete]) } }
last = nil
(a.keys | b.keys).each do |key|
  section, entry = key
  next if entry == :complete || (entry != :total && entry.match?(SKIP))
  next unless [a, a2, b].all? { _1.key?(key) } || complete.(section)
  va, vb, name = a.dig(key, 0) || 0, b.dig(key, 0) || 0, (a[key] || b[key])[1]
  noise = ((a2.dig(key, 0) || 0) - va).abs
  next if (vb - va).abs <= [MIN_REL * va, MIN_ABS, NOISE * noise].max
  if section && section != last && entry != :total
    puts " #{section}:"
    last = section
  end
  pad = entry == :total || section.nil? ? "" : "  "
  puts "-#{pad}#{name}: #{fmt.(va)}", "+#{pad}#{name}: #{fmt.(vb)}"
end
