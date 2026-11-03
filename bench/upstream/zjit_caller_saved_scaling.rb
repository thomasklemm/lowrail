# Compile-time scaling with method size (Shopify/ruby#1064, #1065): one method of N `s ^= o.hash` calls.
# ruby --zjit --zjit-call-threshold=2 bench/upstream/zjit_caller_saved_scaling.rb N
n = Integer(ARGV[0])
src = +"def big(o)\n  s = 0\n"
n.times { src << "  s ^= o.hash\n" }
src << "  s\nend\n"
eval(src)
o = Object.new
before = RubyVM::ZJIT.stats
3.times { big(o) }
after = RubyVM::ZJIT.stats
%i[compiled_iseq_count failed_iseq_count compile_time_ns compile_lir_time_ns code_region_bytes].each { |k| print k, "=", (after[k] - before[k]), " " }
puts
