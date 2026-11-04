require_relative "../lib/harness"
def run_benchmark(_n, **, &block)
  block.call
  c = Hash.new(0)
  tp = TracePoint.new(:call) { |t| v = t.binding.local_variable_get(:value); c[case v when String then "String" when Array, Hash then "Array/Hash" else v.class.name end] += 1 }
  tp.enable(target: ActionView::Helpers::TagHelper::TagBuilder.instance_method(:tag_option)) { block.call }
  sj = 0
  tp2 = TracePoint.new(:call) { sj += 1 }
  tp2.enable(target: ActionView::Helpers::OutputSafetyHelper.instance_method(:safe_join)) { block.call }
  puts "per iteration: #{c.inspect}, safe_join #{sj}"
end
