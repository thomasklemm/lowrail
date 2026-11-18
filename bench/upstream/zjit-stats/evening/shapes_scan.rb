# shapes_scan.rb SITES.tsv STATS.json: classify InvokeBlock trace samples by the block's shape at
# the yielding builtin's caller line and scale samples to per-iteration counts.
require "json"
rows = File.readlines(ARGV[0]).drop(1).map { _1.chomp.split("\t") }.select { _2 =~ /InvokeBlock/ }
per = JSON.parse(File.read(ARGV[1]))["per_itr"]
total_counter = per.fetch("send_fallback_invokeblock_polymorphic_miss", 0) + per.fetch("send_fallback_invokeblock_not_specialized", 0)
total_samples = rows.sum { _4.to_i }
scale = total_counter / total_samples
classes = Hash.new { |h, k| h[k] = [0, []] }
rows.each do |_, reason, site, n|
  frames = site.split(" < ").map { _1.match(/\A(.*) \((.*):(\d+)\)\z/)&.captures }
  top, caller = frames
  cls =
    if top && top[1].start_with?("<internal:") && caller && File.exist?(caller[1])
      lines = File.readlines(caller[1])
      line = lines[caller[2].to_i - 1].to_s
      body = lines[caller[2].to_i - 1, 12].join
      if line =~ /\(&\w+\)|\(&:[^)]+\)|, &\w+\)/ then "block arg (&blk / &:sym)"
      elsif line =~ /(\{|do)\s*\|\s*\w+\s*,\s*[\w*]+/ then "auto-splat (one value into |a, b|)"
      elsif body =~ /\b(break|return)\b/ then "break/return in block (throw)"
      else "other builtin yield"
      end
    else "yield in Ruby method (block elsewhere)"
    end
  classes[cls][0] += n.to_i
  classes[cls][1] << [n.to_i, site.split(" < ").last[0, 90]]
end
puts "scale #{scale.round(2)} per sample (#{total_counter.round} invokeblock fallbacks/itr, #{total_samples} samples)"
classes.sort_by { -_2[0] }.each do |cls, (n, sites)|
  puts format("%-40s %7d samples  ~%8d/itr  %4.1f%%", cls, n, n * scale, 100.0 * n / total_samples)
  sites.max_by(3) { _1[0] }.each { puts "      #{_1[0]}  #{_1[1]}" }
end
