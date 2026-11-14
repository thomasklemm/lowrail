require "valgrind"
def work = 200_000.times { |i| i.to_s }
V = Valgrind
V.callgrind_stop_instrumentation
work
ENV.fetch("SEQ").split(",").each do |op|
  case op
  when "start" then V.callgrind_start_instrumentation
  when "stop" then V.callgrind_stop_instrumentation
  when "zero" then V.callgrind_zero_stats
  when "dump" then V.callgrind_dump_stats("d")
  when "work" then work
  end
end
