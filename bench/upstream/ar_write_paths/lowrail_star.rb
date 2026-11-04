require_relative "../lib/harness"

# Objects per iteration with build_select redefined in both variants; LR_VARIANT main | star.
def run_benchmark(_n, **, &block)
  star = ENV.fetch("LR_VARIANT") == "star"
  ActiveRecord::QueryMethods.module_eval do
    private define_method(:build_select) { |arel|
      if select_values.any?
        arel.project(*arel_columns(select_values))
      elsif model.ignored_columns.any? || model.enumerate_columns_in_select_statements || model.only_columns.any?
        arel.project(*model.column_names.map { |field| table[field] })
      elsif star
        arel.projections << table[Arel.star]
      else
        arel.project(table[Arel.star])
      end
    }
  end
  5.times(&block)
  GC.start; GC.disable
  b = GC.stat(:total_allocated_objects)
  10.times(&block)
  puts "objs/iter=#{(GC.stat(:total_allocated_objects) - b) / 10.0}"
end
