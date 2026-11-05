# memsize of a fresh QueryIntent and bytes per find, before and after one load_async (ASYNC=1).
$LOAD_PATH.unshift(*%w[activesupport activemodel activerecord].map { File.join(ENV.fetch("RAILS_PATH"), _1, "lib") })
require "active_record"
require "objspace"
ActiveRecord.async_query_executor = :global_thread_pool
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: "/tmp/qiw/#{$$}.db", pool: 3)
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts, force: true) { |t| t.string :title; t.integer :n; t.timestamps } }
class Post < ActiveRecord::Base; end
Post.create!(title: "a", n: 1)
QI = ActiveRecord::ConnectionAdapters::QueryIntent
def bytes(n = 2000)
  heaps = GC.stat_heap.keys
  500.times { Post.find(1) }
  GC.start; GC.disable
  before = heaps.to_h { [_1, GC.stat_heap(_1, :total_allocated_objects)] }
  n.times { Post.find(1) }
  b = heaps.sum { (GC.stat_heap(_1, :total_allocated_objects) - before[_1]) * GC.stat_heap(_1, :slot_size) }
  o = heaps.sum { GC.stat_heap(_1, :total_allocated_objects) - before[_1] }
  GC.enable
  format("%.1f B/find %.2f obj/find", b / n.to_f, o / n.to_f)
end
caught = []
tp = TracePoint.new(:return) { |t| caught << t.self if t.method_id == :initialize && t.self.is_a?(QI) }
ActiveRecord::Base.connection_pool.with_connection do
  puts "fresh memsize #{ObjectSpace.memsize_of(QI.allocate)}  #{bytes}"
  ActiveRecord::Base.asynchronous_queries_tracker.start_session
  tp.enable { r = Post.where(n: 1).load_async; sleep 0.2; r.to_a; Post.where(n: [1, 2]).load_async.to_a; Post.async_count.value }
  caught.each { |i| puts "async intent ivars=#{i.instance_variables.size} ran_async=#{i.ran_async.inspect} lock_wait=#{i.lock_wait.inspect} memsize=#{ObjectSpace.memsize_of(i)}" }
  puts "after async memsize #{ObjectSpace.memsize_of(QI.allocate)}  #{bytes}"
  i = QI.new(adapter: Post.connection, raw_sql: "SELECT 1"); puts "foreground ivars after init=#{i.instance_variables.size}"
end
