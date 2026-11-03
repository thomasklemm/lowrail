# Side-exit code size when N locals stay live across N calls (bet Z9).
# ruby --zjit --zjit-call-threshold=2 bench/upstream/zjit_live_exits.rb N
n = Integer(ARGV[0])
src = +"def big(o)\n"
n.times { |i| src << "  v#{i} = o.hash\n" }
src << "  s = 0\n"
n.times { |i| src << "  s ^= v#{i}\n" }
src << "  s\nend\n"
eval(src)
o = Object.new
before = RubyVM::ZJIT.stats
3.times { big(o) }
after = RubyVM::ZJIT.stats
keys = %i[compiled_iseq_count failed_iseq_count compiled_side_exit_count side_exit_size_bytes compile_time_ns]
puts "N=#{n} " + keys.map { |k| "#{k}=#{after[k] - before[k]}" }.join(" ") + " code_region_bytes=#{after[:code_region_bytes]}"
