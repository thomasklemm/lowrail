# Per-iteration allocations from audit.rb result files: mean, min, max, spread and the
# difference between the first and last ten measured iterations (growth).
require "json"
ARGV.each do |path|
  rec = JSON.parse(File.read(path))
  deltas = rec["stats"].each_cons(2).map { |a, b| b[1] - a[1] }
  measured = deltas.drop(Integer(ENV.fetch("SKIP", 2)))
  mean = measured.sum.fdiv(measured.size)
  first, last = measured.first(10), measured.last(10)
  puts format("%-28s n=%d mean %.1f min %d max %d spread %.4f%% first10 %.1f last10 %.1f",
              File.basename(path, ".json"), measured.size, mean, measured.min, measured.max,
              100.0 * (measured.max - measured.min) / measured.min, first.sum.fdiv(10), last.sum.fdiv(10))
  puts "  #{measured.join(' ')}" if ENV["ALL"]
end
