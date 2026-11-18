def tag(name, content)
  "<#{name}>#{content}</#{name}>"
end

def loop_tags(count, values)
  i = 0
  result = nil
  while i < count
    result = tag(values[i % values.length], "payload")
    i += 1
  end
  result
end

mode = ENV.fetch("MODE", "symbol")
values = case mode
when "symbol" then ["div", "span", "b", "i", "a", :em]
when "string" then ["div"]
when "integer" then [1, 2, 3, 4, 5, :em]
when "integer_string" then [1, 2, 3, 4, 5, ""]
when "string_integer" then ["div", "span", "b", "i", "a", 1]
when "string_module" then ["div", "span", "b", "i", "a", Object]
when "module" then [Object, String, Array, Hash, Integer, :em]
when "custom"
  value = Object.new
  def value.to_s = "custom"
  ["div", "span", "b", "i", "a", value]
else raise mode
end
loop_tags(200, [values.first])
loop_tags(1000, values)
GC.start
s0 = RubyVM::ZJIT.stats
a0 = GC.stat(:total_allocated_objects)
t0 = Process.clock_gettime(Process::CLOCK_MONOTONIC)
result = loop_tags(Integer(ENV.fetch("N", "100000")), values)
elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t0
a1 = GC.stat(:total_allocated_objects)
s1 = RubyVM::ZJIT.stats
puts result
warn({mode: mode, seconds: elapsed, allocations: a1 - a0, stats: [:exit_guard_type_failure, :side_exit_count, :dynamic_send_count, :compiled_iseq_count, :invalidation_time_ns, :zjit_alloc_bytes].to_h { |key| [key, s1.fetch(key) - s0.fetch(key)] }}.inspect)
