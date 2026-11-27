require File.expand_path("~/workspace/repo/bench/upstream/census/harness.rb")
RailsCensus.boot("casa")
ops = RailsCensus.workloads("casa")
op = ops.find { _1.name == ENV.fetch("W") }
20.times { op.call.call; RailsCensus.reset_side_effects }
c = Hash.new(0); stats = Hash.new { |h, k| h[k] = [] }
S = ActiveModel::LazyIndexedAttributeSet
tp = TracePoint.new(:call, :return) do |t|
  next unless t.defined_class <= ActiveModel::AttributeSet || t.defined_class == ActiveModel::AttributeMutationTracker || t.defined_class == ActiveModel::ReindexedAttributeSet
  next unless %i[touched_keys forgetting_assignments keys map attr_names].include?(t.method_id)
  if t.event == :call
    c[[t.defined_class.name.split("::").last, t.method_id]] += 1
  elsif t.method_id == :touched_keys && t.self.is_a?(S)
    stats[:touched] << [t.return_value.size, t.self.send(:row_keys).size]
  end
end
tp.enable { op.call.call }
RailsCensus.reset_side_effects
c.each { |k, v| puts "#{k.join('#')}: #{v}" }
t = stats[:touched]
puts "touched_keys on lazy sets: #{t.size} calls, touched/total #{t.map { _1.join('/') }.tally}"
