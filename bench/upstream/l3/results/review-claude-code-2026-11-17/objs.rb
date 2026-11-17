# objects per call and correctness of attributes_for_database / attributes_before_type_cast at WIDTH columns
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
w = Integer(ENV.fetch("WIDTH", "30")) - 3
ActiveRecord::Schema.define do
  create_table :posts do |t|
    (w / 3).times { |i| t.string "title_#{i}"; t.integer "count_#{i}"; t.boolean "flag_#{i}" }
    (w % 3).times { |i| t.string "extra_#{i}" }
    t.timestamps
  end
end
class Post < ActiveRecord::Base; end
values = {}
(w / 3).times { |i| values.merge!("title_#{i}" => "Hello", "count_#{i}" => i, "flag_#{i}" => true) }
values.merge!("created_at" => Time.utc(2026, 1, 1), "updated_at" => Time.utc(2026, 1, 1))
post = Post.find(Post.create!(values).id)
require "digest"
def objs(n = 1000)
  yield
  GC.disable
  a = GC.stat(:total_allocated_objects)
  n.times { yield }
  (GC.stat(:total_allocated_objects) - a) / n.to_f
ensure
  GC.enable
end
puts "cols=#{Post.columns.size} afd=#{objs { post.attributes_for_database }} abtc=#{objs { post.attributes_before_type_cast }} dump=#{objs { Marshal.dump(post) }} sha=#{Digest::SHA256.hexdigest(Marshal.dump([post.attributes_for_database, post.attributes_before_type_cast, post.attributes, Marshal.dump(post)]))[0,12]}"
