require_relative "../lib/harness"

def lowrail_sc_patch(freeze)
  f = freeze ? ".freeze" : ""
  ActiveRecord::ConnectionAdapters::DatabaseStatements.class_eval <<~RUBY, __FILE__, __LINE__ + 1
    def cacheable_query(klass, arel)
      if prepared_statements
        collector = collector()
        collector.retryable = true
        sql, binds = visitor.compile(arel.ast, collector)
        query = klass.query(sql#{f}, retryable: collector.retryable)
      else
        collector = klass.partial_query_collector
        collector.retryable = true
        parts, binds = visitor.compile(arel.ast, collector)
        query = klass.partial_query(parts, retryable: collector.retryable)
      end
      [query, binds]
    end
  RUBY
  ActiveRecord::StatementCache::PartialQuery.class_eval <<~RUBY, __FILE__, __LINE__ + 1
    def sql_for(binds, connection)
      val = @values.dup
      @indexes.each do |i|
        value = binds.shift
        if ActiveModel::Attribute === value
          value = value.value_for_database
        end
        val[i] = connection.quote(value)
      end
      val.join#{f}
    end
  RUBY
end

def run_benchmark(_n, **, &block)
  lowrail_sc_patch(ENV["SC_FREEZE"] == "1")
  Integer(ENV.fetch("WARMUP_ITRS", "3")).times(&block)
  GC.start
  n = Integer(ENV.fetch("IR_ITRS", "1"))
  GC.disable
  [nil].cycle(1) { n.times(&block) }
  GC.enable
  puts "ir: measured #{n} iterations, freeze=#{ENV["SC_FREEZE"]}"
end
