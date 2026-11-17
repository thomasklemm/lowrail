require "active_record"
require "benchmark/ips"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table :posts do |t|
    9.times { |i| t.string "title_#{i}"; t.integer "count_#{i}"; t.boolean "flag_#{i}" }
    t.timestamps
  end
end

class Post < ActiveRecord::Base; end

values = {}
9.times { |i| values.merge!("title_#{i}" => "Hello", "count_#{i}" => i, "flag_#{i}" => true) }
id = Post.create!(values).id
post = Post.find(id)

Benchmark.ips do |x|
  x.report("update! of one column") { post.update!(count_0: post.count_0 + 1) }
  x.report("find, then changed?") { Post.find(id).changed? }
  x.report("serializable_hash") { post.serializable_hash }
end
