require_relative "../lib/harness"
def run_benchmark(_n, **, &block)
  Integer(ENV.fetch("WARMUP_ITRS", 3)).times(&block)
  c = Hash.new(0)
  tp = TracePoint.new(:call) do |t|
    if t.method_id == :execute && t.defined_class == ActiveRecord::StatementCache
      c[:statement_cache_execute] += 1
    elsif t.method_id == :to_sql_and_binds
      a = t.binding.local_variable_get(t.binding.local_variables.first)
      c[:to_sql_and_binds_unfrozen_string] += 1 if String === a && !a.frozen? && !(defined?(Arel::Nodes::SqlLiteral) && Arel::Nodes::SqlLiteral === a)
    elsif t.method_id == :blocked? && t.defined_class.name.to_s.include?("BrowserBlocker")
      c[:browser_blocked_check] += 1
    elsif t.method_id == :call && t.defined_class == Rails::Engine
      c[:requests] += 1
    end
  end
  tp.enable { Integer(ENV.fetch("CALLS_ITRS", 1)).times(&block) }
  $stderr.puts "LOWRAIL per request: " + c.transform_values { |v| (v.to_f / c[:requests]).round(3) }.inspect + " requests=#{c[:requests]}"
end
