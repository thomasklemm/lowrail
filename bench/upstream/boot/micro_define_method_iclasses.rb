# M is included by N helper modules (as controllers' HelperMethods include the
# routes' path helpers), each included in a class; define K new methods on M.
def run(n, k)
  m = Module.new
  n.times { h = Module.new; h.include(m); c = Class.new; c.include(h); Class.new(c).new }
  pr = proc { |*a| a }
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  k.times { |i| m.define_method(:"helper_#{n}_#{i}_path", pr) }
  ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - t) * 1e6 / k).round(2)
end
[0, 1, 17, 50, 218, 500].each { |n| puts "#{n} iclass sites: #{run(n, 1000)} us per define_method" }
