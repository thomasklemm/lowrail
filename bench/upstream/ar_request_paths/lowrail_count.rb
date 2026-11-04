require_relative "../lib/harness"

# Counts SQLite3 query results and their columns per benchmark iteration.
def run_benchmark(_n, **, &block)
  3.times(&block)
  counts = Hash.new(0)
  ActiveRecord::Result.prepend(Module.new do
    define_method(:initialize) do |columns, rows, column_types = nil, **kw|
      if column_types
        counts[:results] += 1
        counts[:columns] += columns.size
      end
      super(columns, rows, column_types, **kw)
    end
  end)
  10.times(&block)
  puts "count: results/iter=#{counts[:results] / 10.0} columns/iter=#{counts[:columns] / 10.0}"
end
