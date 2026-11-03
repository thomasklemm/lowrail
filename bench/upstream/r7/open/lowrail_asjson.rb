# frozen_string_literal: true
# Count Hash#as_json calls (and Symbol keys they stringify) per request.
require_relative "../lib/harness"
def run_benchmark(_n, **, &block)
  Integer(ENV.fetch("WARMUP_ITRS", 5)).times(&block)
  c = Hash.new(0)
  tp = TracePoint.new(:call) do |t|
    if t.method_id == :as_json && t.defined_class == Hash
      c[:hash_as_json] += 1
      c[:symbol_keys] += t.self.each_key.count { |k| Symbol === k }
    elsif t.method_id == :call && t.defined_class == Rails::Engine
      c[:requests] += 1
    end
  end
  tp.enable { Integer(ENV.fetch("CALLS_ITRS", 3)).times(&block) }
  $stderr.puts "per request: " + c.transform_values { |v| (v.to_f / c[:requests]).round(2) }.inspect
end
