# frozen_string_literal: true

# Summarizes interleave.sh logs: per run the median of the timed iterations;
# per app and mode, each variant against the mean of the same round's mainA
# and mainB, and the A/A (mainB / mainA).
#   ruby wall.rb OUT_DIR
dir = ARGV.fetch(0)
med = ->(a) { s = a.sort; s.size.odd? ? s[s.size / 2] : (s[s.size / 2 - 1] + s[s.size / 2]) / 2.0 }
runs = Hash.new { |h, k| h[k] = {} }
Dir[File.join(dir, "*.log")].each do |f|
  app, mode, variant, round = File.basename(f, ".log").split("-")
  times = File.read(f).scan(/^itr #\s*(\d+):\s*(\d+)ms/).map { [_1.to_i, _2.to_f] }
  times = File.read(f).scan(/#\s*(\d+):\s*(\d+)ms/).map { [_1.to_i, _2.to_f] } if times.empty?
  timed = times.last(Integer(ENV.fetch("TIMED", 20))).map(&:last)
  runs[[app, mode]][[variant, round]] = med.(timed) unless timed.empty?
end
pct = ->(x) { format("%+.1f%%", 100 * (x - 1)) }
puts "| app | mode | rounds | mainA ms | mainB ms | variant | variant ms | variant / main (median, range) | A/A mainB / mainA (median, range) |"
puts "|---|---|---:|---:|---:|---|---:|---|---|"
runs.sort.each do |(app, mode), r|
  rounds = r.keys.map(&:last).uniq.sort.select { |rd| r[["mainA", rd]] && r[["mainB", rd]] }
  aa = rounds.map { |rd| r[["mainB", rd]] / r[["mainA", rd]] }
  (r.keys.map(&:first).uniq - %w[mainA mainB]).sort.each do |v|
    rs = rounds.select { |rd| r[[v, rd]] }
    ratios = rs.map { |rd| r[[v, rd]] / ((r[["mainA", rd]] + r[["mainB", rd]]) / 2) }
    next if ratios.empty?
    puts "| #{app} | #{mode} | #{rs.size} | #{med.(rs.map { r[["mainA", _1]] })} | #{med.(rs.map { r[["mainB", _1]] })} | #{v} | " \
      "#{med.(rs.map { r[[v, _1]] })} | #{pct.(med.(ratios))} (#{pct.(ratios.min)} … #{pct.(ratios.max)}) | " \
      "#{pct.(med.(aa))} (#{pct.(aa.min)} … #{pct.(aa.max)}) |"
  end
end
