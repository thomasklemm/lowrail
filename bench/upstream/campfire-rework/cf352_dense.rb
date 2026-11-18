# One filter pass over "<span>x</span>" × n, the dense input the #352 confirm found slow (cf352_cohort.md).
# usage: RAILS_ENV=test LABEL=main bin/rails runner cf352_dense.rb, in a Campfire checkout
require "benchmark"
[3_000, 12_000, 90_000].each do |n|
  content = ActionText::Content.new("<span>x</span>" * n)
  seconds = Benchmark.realtime { ContentFilters::TextMessagePresentationFilters.apply(content) }
  puts "#{ENV["LABEL"]} n=#{n}: #{format("%.2f", seconds)} s"
end
