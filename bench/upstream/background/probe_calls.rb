# In a census copy (CENSUS_SET=background): bundle exec ruby probe_calls.rb APP "Const#meth,Const#meth2" [workload substring]: calls per op and distinct receivers per op
require_relative "../census/harness"
app, specs, filter = ARGV
RailsCensus.boot(app)
ops = RailsCensus.workloads(app)
ops = ops.select { _1.name.include?(filter) } if filter
COUNTS = Hash.new(0)
RECV = Hash.new { |h, k| h[k] = {} }
specs.split(",").each do |spec|
  single = !spec.include?("#")
  const, meth = spec.split(single ? "." : "#")
  mod = Module.new do
    define_method(meth) do |*a, **k, &b|
      COUNTS[spec] += 1
      RECV[spec][__id__] = true
      super(*a, **k, &b)
    end
  end
  target = Object.const_get(const)
  (single ? target.singleton_class : target).prepend(mod)
end
ops.each do |op|
  3.times { op.call.call; RailsCensus.reset_side_effects }
  COUNTS.clear; RECV.clear
  5.times { op.call.call; RailsCensus.reset_side_effects }
  next if COUNTS.empty?
  puts format("%-60s %s", op.name[0, 60], COUNTS.map { |k, v| "#{k}: #{v / 5.0} calls, #{RECV[k].size / 5.0} receivers" }.join("; "))
end
