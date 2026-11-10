# ruby --zjit --zjit-call-threshold=2 [--zjit-stats=quiet] big.rb SHAPE N
#   calls: N `s ^= o.hash` (the PR body's script): many CCalls, short intervals
#   live:  N values each from a call, all summed at the end: many CCalls, many long intervals
#   one:   N values from arithmetic, one CCall in the middle, all summed after it
shape, n = ARGV[0], Integer(ARGV[1])
src = +"def big(o)\n"
case shape
when "calls"
  src << "  s = 0\n"
  n.times { src << "  s ^= o.hash\n" }
  src << "  s\n"
when "live"
  n.times { |i| src << "  a#{i} = o.hash\n" }
  src << "  " << n.times.map { "a#{_1}" }.join(" ^ ") << "\n"
when "one"
  src << "  x = o.object_id\n"
  n.times { |i| src << "  a#{i} = x + #{i}\n" }
  src << "  o.hash\n"
  src << "  " << n.times.map { "a#{_1}" }.join(" ^ ") << "\n"
end
src << "end\n"
eval(src)
o = Object.new
3.times { big(o) }
if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled? && RubyVM::ZJIT.stats_enabled?
  s = RubyVM::ZJIT.stats
  warn "#{shape} n=#{n} compile_time_ms=#{s[:compile_time_ns].to_i / 1_000_000} compiled=#{s[:compiled_iseq_count]} failed=#{s[:failed_iseq_count]} code=#{s[:code_region_bytes]}"
end
