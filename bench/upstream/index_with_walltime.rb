# frozen_string_literal: true

# Summarize interleaved ruby-bench wall-time logs: ruby SCRIPT DIR
# Logs are APP-RUBY-MODE-VARIANT-rROUND.log from ruby-bench's default harness
# (10 warmup + 20 timed iterations). Per process: median of the timed
# iterations. Per round: each variant over the mean of that round's main-A and
# main-B. Reported: median per-process time over rounds, and the median and
# range of the per-round ratios; main-B / main-A is the A/A control.
dir = ARGV.fetch(0)
med = ->(a) { s = a.sort; s.size.odd? ? s[s.size / 2] : (s[s.size / 2 - 1] + s[s.size / 2]) / 2.0 }
runs = Hash.new { |h, k| h[k] = {} }
Dir[File.join(dir, "*.log")].each do |f|
  app, ruby, mode, *v, round = File.basename(f, ".log").split("-")
  times = File.readlines(f).grep(/\A\s*#\d+:\s+\d+ms/).map { _1[/(\d+)ms/, 1].to_f }
  next warn("incomplete #{f}") unless times.size == 30
  runs[[app, ruby, mode]][[v.join("-"), round]] = med.(times.last(20))
end
puts "| app | Ruby | mode | rounds | main-A ms | main-B ms | variant | variant ms | variant / main (median, range) | A/A main-B / main-A (median, range) |"
puts "|---|---|---|---:|---:|---:|---|---:|---|---|"
runs.sort.each do |(app, ruby, mode), r|
  names = r.keys.map(&:first).uniq
  variants = names - %w[main-A main-B]
  rounds = r.keys.map(&:last).uniq.sort.select { |rd| names.all? { r.key?([_1, rd]) } }
  next if rounds.empty?
  aa = rounds.map { r[["main-B", _1]] / r[["main-A", _1]] }
  variants.sort.each do |v|
    ratios = rounds.map { |rd| r[[v, rd]] / ((r[["main-A", rd]] + r[["main-B", rd]]) / 2) }
    pct = ->(x) { format("%+.1f%%", (x - 1) * 100) }
    puts "| #{app} | #{ruby == "41" ? "4.1.0dev" : "4.0.7"} | #{mode == "interp" ? "interpreter" : "YJIT"} | #{rounds.size} | " \
      "#{med.(rounds.map { r[["main-A", _1]] }).round(1)} | #{med.(rounds.map { r[["main-B", _1]] }).round(1)} | #{v} | " \
      "#{med.(rounds.map { r[[v, _1]] }).round(1)} | #{pct.(med.(ratios))} (#{pct.(ratios.min)} … #{pct.(ratios.max)}) | " \
      "#{pct.(med.(aa))} (#{pct.(aa.min)} … #{pct.(aa.max)}) |"
  end
end
