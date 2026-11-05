# Objects per Object#try / #try! call, warm call sites.
#   RAILS=/path/to/rails ruby try_kwargs.rb
# 8-1-stable and the fix: 1 (the argument Array); main: 2 (plus an empty
# keyword Hash). Ruby 3.4 or later.
$LOAD_PATH.unshift(File.join(ENV.fetch("RAILS"), "activesupport/lib"))
require "active_support"
require "active_support/core_ext/object/try"

class Prop
  def deferred? = false
  def add(a, b: 1) = a + b
end
prop = Prop.new

def allocations
  2.times.map do
    before = GC.stat(:total_allocated_objects)
    yield
    GC.stat(:total_allocated_objects) - before
  end.last
end

puts "Rails #{ActiveSupport.version}, Ruby #{RUBY_VERSION}"
{
  "prop.try(:deferred?)" => -> { prop.try(:deferred?) },
  "prop.try!(:deferred?)" => -> { prop.try!(:deferred?) },
  "prop.try(:add, 1)" => -> { prop.try(:add, 1) },
  "prop.try(:add, 1, b: 2)" => -> { prop.try(:add, 1, b: 2) },
  "nil.try(:deferred?)" => -> { nil.try(:deferred?) },
}.each { |label, call| puts "#{label.ljust(26)} #{allocations(&call)}" }
