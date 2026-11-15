# Raw benchmark-ips lines of the best round per label and report, from ab1_review.sh output: ruby best_lines.rb FILE
best = {}
label = nil
File.foreach(ARGV[0]) do |line|
  if line =~ /^=== (\S+)/ then label = $1
  elsif line =~ /^\s*(\S.*?)\s+([\d.]+)([kM]?) \(±\s*([\d.]+)%\) i\/s/
    ips = $2.to_f * { "k" => 1e3, "M" => 1e6, "" => 1 }[$3]
    key = [label, $1]
    best[key] = [ips, line.rstrip] if !best[key] || ips > best[key][0]
  end
end
best.sort_by { |(l, r), _| [r, l] }.each { |(l, r), (_, line)| puts "#{l.ljust(9)} #{line}" }
