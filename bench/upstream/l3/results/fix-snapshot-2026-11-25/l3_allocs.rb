require "active_record"
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
def objs(n = 1000) = (GC.disable; a = GC.stat(:total_allocated_objects); n.times { yield }; r = (GC.stat(:total_allocated_objects) - a) / n.to_f; GC.enable; r)
cold = Post.find(post.id)
c = objs(1) { cold.attributes_for_database }
puts "cold attributes_for_database #{c}"
post.attributes_for_database
puts "attributes_for_database #{objs { post.attributes_for_database }}"
puts "attributes_before_type_cast #{objs { post.attributes_before_type_cast }}"
puts "Marshal.dump #{objs { Marshal.dump(post) }}"
