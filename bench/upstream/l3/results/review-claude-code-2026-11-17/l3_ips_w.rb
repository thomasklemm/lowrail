W = Integer(ENV.fetch("WIDTH", "30")) - 3
require "active_record"
require "benchmark/ips"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table :posts do |t|
    (W / 3).times { |i| t.string "title_#{i}"; t.integer "count_#{i}"; t.boolean "flag_#{i}" }
    (W % 3).times { |i| t.string "extra_#{i}" }
    t.timestamps
  end
end

class Post < ActiveRecord::Base; end

values = {}
(W / 3).times { |i| values.merge!("title_#{i}" => "Hello", "count_#{i}" => i, "flag_#{i}" => true) }
post = Post.find(Post.create!(values).id)
abort "columns #{Post.columns.size}" unless Post.columns.size == W + 3

Benchmark.ips do |x|
  x.report("Marshal.dump") { Marshal.dump(post) }
  x.report("attributes_for_database") { post.attributes_for_database }
end
