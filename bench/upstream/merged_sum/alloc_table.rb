# frozen_string_literal: true

# Objects and GC runs per ruby-bench iteration, main ("sum-main", "sum-main2")
# against main with our merged perf PRs reverted ("sum-rev", "sum-rev2"), from
# the JSON files ruby-bench's harness/sumalloc.rb writes. Per process: the mean
# over its iterations; per tree: the mean of its two processes.
#   ruby alloc_table.rb DIR
require "json"

dir = ARGV.fetch(0)
load = ->(f) { File.exist?(f) ? JSON.parse(File.read(f))["iterations"] : nil }
mean = ->(rows, k) { rows.sum { _1[k] }.fdiv(rows.size) }
puts "| Benchmark | Mode | Objects/iter without → with | Δ | A/A with, without | GC/iter without → with | major/iter without → with |"
puts "| --- | --- | ---: | ---: | ---: | ---: | ---: |"
%w[railsbench erubi-rails lobsters shipit].each do |b|
  %w[interp yjit].each do |m|
    w1, w2, o1, o2 = %w[sum-main sum-main2 sum-rev sum-rev2].map { load.(File.join(dir, "#{b}-#{m}-#{_1}.json")) }
    next unless [w1, w2, o1, o2].all?
    w = (mean.(w1, "objects") + mean.(w2, "objects")) / 2
    o = (mean.(o1, "objects") + mean.(o2, "objects")) / 2
    aa = ->(a, c) { format("%+.2f%%", (mean.(c, "objects") / mean.(a, "objects") - 1) * 100) }
    g = ->(x, y, k) { format("%.2f", (mean.(x, k) + mean.(y, k)) / 2) }
    puts format("| %s | %s | %d → %d | %+.2f%% | %s, %s | %s → %s | %s → %s |", b, m == "interp" ? "interpreter" : "YJIT", o, w,
                (w / o - 1) * 100, aa.(w1, w2), aa.(o1, o2), g.(o1, o2, "gc"), g.(w1, w2, "gc"), g.(o1, o2, "major"), g.(w1, w2, "major"))
  end
end
