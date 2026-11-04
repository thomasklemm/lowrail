require_relative "../lib/harness"

# Counts update-timestamp passes, clock reads in them, and default star projections per iteration.
def run_benchmark(_n, **, &block)
  3.times(&block)
  c = Hash.new(0)
  ActiveRecord::Timestamp.prepend(Module.new do
    define_method(:record_update_timestamps) { |*a, &b| c[:passes] += 1; c[:reads_in] = c[:reads]; super(*a, &b) }
  end)
  ActiveRecord::Timestamp::ClassMethods.prepend(Module.new do
    define_method(:current_time_from_proper_timezone) { c[:reads] += 1; super() }
  end)
  Arel::SelectManager.prepend(Module.new do
    define_method(:project) { |*p| c[:star] += 1 if p.size == 1 && p[0].is_a?(Arel::Attributes::Attribute) && p[0].name.to_s == "*"; super(*p) }
  end)
  10.times(&block)
  puts "wcount: " + c.except(:reads_in).transform_values { _1 / 10.0 }.inspect
end
