# Slot bytes and objects allocated per query (warmed up), from GC.stat_heap: sum of slot_size x new objects per heap.
#   RAILS_PATH=tree BUNDLE_GEMFILE=... ruby -rbundler/setup qi_bytes.rb [N]
$LOAD_PATH.unshift(*%w[activesupport activemodel activerecord].map { File.join(ENV.fetch("RAILS_PATH"), _1, "lib") })
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title; t.integer :n; t.timestamps } }
class Post < ActiveRecord::Base; end
Post.create!(title: "a", n: 1)
ActiveRecord::Base.connection_pool.lease_connection
n = Integer(ARGV[0] || 2000)
cases = {
  "find" => -> { Post.find(1) },
  "where.to_a" => -> { Post.where(n: 1).to_a },
  "update_all" => -> { Post.where(id: 1).update_all(n: 1) },
  "insert" => -> { Post.insert({ title: "x", n: 2 }) },
  "exec_query" => -> { Post.connection.exec_query("SELECT 1") },
}
heaps = GC.stat_heap.keys
cases.each do |name, blk|
  500.times { blk.call }
  GC.start; GC.disable
  before = heaps.to_h { [_1, GC.stat_heap(_1, :total_allocated_objects)] }
  n.times { blk.call }
  bytes = heaps.sum { (GC.stat_heap(_1, :total_allocated_objects) - before[_1]) * GC.stat_heap(_1, :slot_size) }
  objs = heaps.sum { GC.stat_heap(_1, :total_allocated_objects) - before[_1] }
  GC.enable
  printf("%-11s %8.1f B/call %6.2f objects/call\n", name, bytes / n.to_f, objs / n.to_f)
end
