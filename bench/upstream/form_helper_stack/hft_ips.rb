src = File.read(File.expand_path("hft_count.rb", __dir__)).sub(%q{require_relative "form_stack_patches"}, %Q{require "#{__dir__}/form_stack_patches"}); eval(src[0...src.index("C.each")], TOPLEVEL_BINDING)
require "benchmark/ips"
Benchmark.ips(quiet: true) { |x| x.config(warmup: 1, time: 2); C.each { |l, f| x.report(l, &f) }; x.json!("/tmp/k6s/hips_#{ENV["PATCH"]}_#{ENV["ROUND"]}.json") }
