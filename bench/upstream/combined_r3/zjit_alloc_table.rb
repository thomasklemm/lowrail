# frozen_string_literal: true

# ruby-bench objects and GC runs per iteration under ZJIT for round 3 (run_master.sh's sumalloc JSONs):
#   ruby zjit_alloc_table.rb DIR
# Rails axis: main-a/main-b (with) against without-a/without-b. Ruby axis: main-b/main-c (Ruby master with)
# against rwo-a/rwo-b (our ruby/ruby commits reverted), all on Rails main. Per tree: the mean of its two processes.
require "json"

dir = ARGV.fetch(0)
load = ->(b, v) { JSON.parse(File.read(File.join(dir, "#{b}-zjit-#{v}.json")))["iterations"] }
mean = ->(rows, k) { rows.sum { _1[k] }.fdiv(rows.size) }
pct = ->(a, b) { format("%+.2f%%", (a / b - 1) * 100).sub("-", "−") }
puts "| Axis | Benchmark | Objects/iter without → with | Δ | A/A with, without | GC/iter without → with |"
puts "| --- | --- | ---: | ---: | ---: | ---: |"
{ "Rails" => [%w[main-a main-b], %w[without-a without-b]], "Ruby" => [%w[main-b main-c], %w[rwo-a rwo-b]] }.each do |axis, (w, o)|
  %w[railsbench lobsters shipit].each do |b|
    w1, w2, o1, o2 = (w + o).map { load.(b, _1) }
    wm = (mean.(w1, "objects") + mean.(w2, "objects")) / 2
    om = (mean.(o1, "objects") + mean.(o2, "objects")) / 2
    g = ->(x, y) { format("%.2f", (mean.(x, "gc") + mean.(y, "gc")) / 2) }
    puts format("| %s | %s | %s → %s | %s | %s, %s | %s → %s |", axis, b, om.round.to_s.reverse.scan(/\d{1,3}/).join(",").reverse,
      wm.round.to_s.reverse.scan(/\d{1,3}/).join(",").reverse, pct.(wm, om), pct.(mean.(w2, "objects"), mean.(w1, "objects")),
      pct.(mean.(o2, "objects"), mean.(o1, "objects")), g.(o1, o2), g.(w1, w2))
  end
end
