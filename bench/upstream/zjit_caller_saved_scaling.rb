# handle_caller_saved_regs scaling (Shopify/ruby#1065): one method with N calls whose results all stay live.
# ruby --zjit --zjit-call-threshold=2 bench/upstream/zjit_caller_saved_scaling.rb N
n = Integer(ARGV[0])
src = +"def big(o)\n"
n.times { |i| src << "  v#{i} = o.to_s\n" }
src << "  [" << n.times.map { |i| "v#{i}" }.join(", ") << "]\nend\n"
eval(src)
o = Object.new
before = RubyVM::ZJIT.stats
big(o); big(o)
after = RubyVM::ZJIT.stats
%i[compile_time_ns compile_lir_time_ns compile_hir_time_ns].each { |k| print k, "=", (after[k] - before[k]) / 1_000_000.0, "ms " }
puts
