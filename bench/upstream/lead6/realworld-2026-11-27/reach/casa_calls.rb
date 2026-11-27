require File.expand_path("~/workspace/repo/bench/upstream/census/harness.rb")
RailsCensus.boot("casa")
op = RailsCensus.workloads("casa").find { _1.name == ENV.fetch("W") }
20.times { op.call.call; RailsCensus.reset_side_effects }
c = Hash.new(0)
tp = TracePoint.new(:call, :c_call) { |t| c["#{t.defined_class}##{t.method_id}"] += 1 }
tp.enable { op.call.call }
c.sort.each { |k, v| puts "#{k}\t#{v}" }
