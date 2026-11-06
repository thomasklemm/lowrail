# per_request_sum.rb PREFIX LABELS: Ir per request kind from per_request.rb dumps.
prefix, labels_path = ARGV
labels = File.readlines(labels_path, chomp: true)
files = Dir["#{prefix}.*"].select { _1 =~ /\.\d+\z/ }.sort_by { _1[/\d+\z/].to_i }
irs = files.map { |f| Integer(File.foreach(f).find { _1.start_with?("summary:", "totals:") }.split[1]) }
# irs[0]: boot + warmup; then (gap, request) per label; then the tail.
reqs = labels.each_with_index.map { |l, k| [l, irs[2 + 2 * k]] }
total = irs[1, 2 * labels.size + 1].sum
by = Hash.new { |h, k| h[k] = [0, 0, 0, 0] }
reqs.each do |l, ir|
  verb, shape, status, gc = l.split
  key = "#{verb} #{shape} #{status}"
  by[key][0] += 1; by[key][1] += ir
  if gc.to_i.zero? then by[key][2] += 1; by[key][3] += ir end
end
puts "iteration Ir #{total}, in requests #{reqs.sum { _2 }} (#{reqs.size} requests)"
puts "requests with a GC: #{reqs.count { _1[0].split[3].to_i > 0 }}"
by.sort_by { -_2[1] }.each { |k, (n, ir, m, irm)| puts format("%-40s %4d req %5.1f%%  %9d Ir/req  no-GC %4d req %9d Ir/req", k, n, 100.0 * ir / total, ir / n, m, m.zero? ? 0 : irm / m) }
