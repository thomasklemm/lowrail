require "active_record"
require_relative "prototype" if ENV["PROTO"]
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.integer :position } }
calls = 0
if ENV["PROTO"]
  ShadowCheck.singleton_class.prepend(Module.new { define_method(:check) { |*a| calls += 1; super(*a) } })
end
t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
class Post < ActiveRecord::Base
  200.times { |i| define_singleton_method(:"m#{i}") { where(id: i) } }
  def self.default_order(c = :position) = order(c => :desc)
end
defs = Process.clock_gettime(Process::CLOCK_MONOTONIC) - t
5.times { |i| Post.create!(position: i) }
at_def = calls
GC.start; GC.disable
a = GC.stat(:total_allocated_objects)
1000.times { Post.where(position: 1).m5.order(:id).to_a; Post.all.default_order(:id).first }
alloc = GC.stat(:total_allocated_objects) - a
puts "proto=#{!!ENV["PROTO"]} check calls at definition=#{at_def} during 1000 query iterations=#{calls - at_def} allocations=#{alloc} 201 class-method definitions took #{(defs * 1000).round(2)} ms"
