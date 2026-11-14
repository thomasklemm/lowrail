# Best of N per label and report from ab1_review.sh output: ruby ab1_best.rb FILE
best = Hash.new { |h, k| h[k] = {} }
label = nil
File.foreach(ARGV[0]) do |line|
  if line =~ /^=== (\S+)/ then label = $1
  elsif line =~ /^\s*(\S.*?)\s+([\d.]+)([kM]?) \(±\s*([\d.]+)%\) i\/s/
    ips = $2.to_f * { "k" => 1e3, "M" => 1e6, "" => 1 }[$3]
    best[$1][label] = [best[$1][label] || 0, ips].max
  end
end
fmt = ->(ips) { ips >= 1e5 ? format("%.3f µs", 1e6 / ips) : format("%.2f µs", 1e6 / ips) }
puts format("%-18s %12s %12s %8s %12s %8s", "report", "base", "A/A", "A/A", "candidate", "change")
best.each do |name, b|
  puts format("%-18s %12s %12s %+7.1f%% %12s %7.2fx", name, fmt.(b["base"]), fmt.(b["base2"]), 100 * (b["base2"] / b["base"] - 1),
              fmt.(b["candidate"]), b["candidate"] / b["base"])
end
