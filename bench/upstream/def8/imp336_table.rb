# Best of 5 per app, nonce and variant from imp336_run_ips.sh output:  ruby imp336_table.rb DIR
dir = ARGV.fetch(0)
rows = Hash.new { |h, k| h[k] = [] }
Dir["#{dir}/*-r*.txt"].each do |f|
  app, n, v = File.basename(f).split("-")
  line = File.read(f)[/^javascript_importmap_tags\s+[\d.]+k \(.*$/] or next
  rows[[app, n, v]] << [line[/([\d.]+)k \(/, 1].to_f * 1000, line]
end
rows.keys.map { _1[0, 2] }.uniq.sort.each do |app, n|
  base = rows[[app, n, "main"]].map(&:first).max
  puts "#{app} #{n == "n1" ? "nonce" : "no nonce"}"
  %w[main aa im1 comb].each do |v|
    runs = rows[[app, n, v]]
    next if runs.empty?
    best = runs.max_by(&:first)
    printf "  %-5s best %9.0f  %+6.1f%%  runs %s\n", v, best[0], (best[0] / base - 1) * 100, runs.map { (_1[0] / 1000).round(1) }.sort.join(" ")
    puts "        #{best[1]}"
  end
end
