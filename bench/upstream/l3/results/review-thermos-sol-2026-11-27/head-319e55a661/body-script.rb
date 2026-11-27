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
post = Post.find(Post.create!(values).id)

Benchmark.ips do |x|
  x.report("Marshal.dump") { Marshal.dump(post) }
  x.report("attributes_for_database") { post.attributes_for_database }
end
