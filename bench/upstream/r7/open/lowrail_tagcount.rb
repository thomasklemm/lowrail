# frozen_string_literal: true
# Count build_tag_values / token_list calls and their Array/Hash arguments per request.
require_relative "../lib/harness"
def run_benchmark(_n, **, &block)
  Integer(ENV.fetch("WARMUP_ITRS", 5)).times(&block)
  c = Hash.new(0)
  tp = TracePoint.new(:call) do |t|
    case t.method_id
    when :build_tag_values then c[:build_tag_values] += 1
    when :token_list then c[:token_list] += 1
    when :call then c[:requests] += 1 if t.defined_class == Rails::Engine
    end
  end
  tp.enable { Integer(ENV.fetch("CALLS_ITRS", 3)).times(&block) }
  $stderr.puts c.inspect
  $stderr.puts "per request: " + c.transform_values { |v| (v.to_f / c[:requests]).round(2) }.inspect
end
