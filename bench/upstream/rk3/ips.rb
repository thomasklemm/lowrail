# ruby -I RACK/lib ips.rb: calls per second of each micro_exprs.txt line (benchmark-ips, 2 s warm-up, 5 s run).
# ips.sh runs it pinned to one core for rack main and the branch, alternating, ROUNDS times.
require "benchmark/ips"
require_relative "micro"
exprs = File.readlines(File.expand_path("micro_exprs.txt", __dir__), chomp: true)
Benchmark.ips(quiet: true) do |x|
  x.config(warmup: 2, time: 5)
  exprs.each { |e| x.report(e, "#{e}") } # string reports compile the expression into the loop
  x.json! ENV.fetch("OUT")
end
