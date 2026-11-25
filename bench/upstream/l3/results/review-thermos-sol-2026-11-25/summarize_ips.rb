# frozen_string_literal: true

require "json"

best = Hash.new { |h, k| h[k] = {} }
samples = Hash.new { |h, k| h[k] = Hash.new { |hh, kk| hh[kk] = [] } }
tree = round = nil
label = nil
File.foreach(ARGV.fetch(0)) do |line|
  if line =~ /^=== (\S+) round (\d+) ===/
    tree, round = $1, $2.to_i
  elsif line =~ /^\s*([[:alpha:]_].+?)\s+([\d.]+)([kM]?) \(.*i\/s/
    label, count, scale = $1, $2.to_f, $3
    count *= { "" => 1, "k" => 1000, "M" => 1_000_000 }.fetch(scale)
    entry = { tree: tree, round: round, ips: count, output: line.strip }
    samples[label][tree] << entry
    best[label][tree] = entry if !best[label][tree] || count > best[label][tree][:ips]
  elsif line.strip != "" && !line.start_with?(" ", "\t")
    label = line.strip
  elsif label && line =~ /^\s+([\d.]+)([kM]?) \(.*i\/s/
    count = $1.to_f * { "" => 1, "k" => 1000, "M" => 1_000_000 }.fetch($2)
    entry = { tree: tree, round: round, ips: count, output: "#{label} #{line.strip}" }
    samples[label][tree] << entry
    best[label][tree] = entry if !best[label][tree] || count > best[label][tree][:ips]
  end
end

best.each do |name, trees|
  next unless trees.key?("main")
  main = trees.fetch("main").fetch(:ips)
  row = trees.map do |name, entry|
    "#{name} #{entry[:ips].round(2)} (#{format("%+.2f%%", (entry[:ips] / main - 1) * 100)}) r#{entry[:round]}"
  end
  puts "#{name}: #{row.join("; ")}"
  trees.each_value { |entry| puts "  #{entry[:tree]}: #{entry[:output]}" }
end
File.write(ARGV.fetch(1), JSON.pretty_generate({ best: best, samples: samples }) + "\n") if ARGV[1]
