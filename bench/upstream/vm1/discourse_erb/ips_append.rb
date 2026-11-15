# benchmark-ips of 8 OutputBuffer#<< appends of an unsafe String to a fresh buffer, for the Rails tree given
# as the argument (run through ../tag/ips_matrix.sh with SCRIPT set to this file).
tree = ARGV.fetch(0)
%w[activesupport actionview].each { $LOAD_PATH.unshift File.join(tree, _1, "lib") }
require "action_view"
require "benchmark/ips"
s = "Hello & World"
Benchmark.ips do |x|
  x.config(warmup: 2, time: 5)
  x.report("append8") do
    b = ActionView::OutputBuffer.new
    b << s; b << s; b << s; b << s; b << s; b << s; b << s; b << s
  end
end
