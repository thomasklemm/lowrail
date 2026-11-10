n = Integer(ARGV[1])
if ARGV[0] == "noparam" then def run(n) = n.times { } else def run(n) = n.times { |i| } end
100.times { run(1000) }
K = %i[compiled_iseq_count compiled_side_exit_count invalidation_time_ns compile_error_out_of_memory]
st = -> { RubyVM::ZJIT.stats.slice(*K) }
run(n)
GC.start; GC.disable
a = st.(); run(n); b = st.()
warn "flat=#{a == b} #{a.zip(b).reject { _1 == _2 }}"
