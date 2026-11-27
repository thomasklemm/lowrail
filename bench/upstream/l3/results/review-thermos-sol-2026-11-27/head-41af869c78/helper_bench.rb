require "active_record"
require "benchmark/ips"

script = "/home/user/workspace/repo/bench/upstream/l3/l3_ips.rb"
eval(File.read(script).split("Benchmark.ips do").first, TOPLEVEL_BINDING, script)
post = TOPLEVEL_BINDING.local_variable_get(:post)

Benchmark.ips do |x|
  x.config(warmup: 0.5, time: 1.5)
  x.report("Marshal.dump") { Marshal.dump(post) }
  x.report("attributes_for_database") { post.attributes_for_database }
end
