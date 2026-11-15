require "active_record"
require "benchmark/ips"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :posts do |t|
    27.times { |i| t.string "column#{i}" }
    t.timestamps
  end
end

class Post < ActiveRecord::Base; end

10.times { Post.create!((0...27).to_h { |i| ["column#{i}", "value #{i}"] }) }
names = Post.attribute_names
post = Post.first

Benchmark.ips do |x|
  x.report("load 10 posts, read every attribute") { Post.limit(10).each { |p| names.each { |name| p.public_send(name) } } }
  x.report("dup a post") { post.dup }
end
