# Counts LazyIndexedAttributeSet#keys, #[] and the private index_for_name/lookup calls during update! of one column (30 columns).
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
post.update!("count_0" => 7)
counts = Hash.new(0)
tp = TracePoint.new(:call) { |t| counts[t.method_id] += 1 if t.defined_class == ActiveModel::LazyIndexedAttributeSet && %i[keys [] index_for_name lookup attribute_at].include?(t.method_id) }
tp.enable { post.update!("count_0" => 8) }
p counts.sort.to_h
counts.clear
post = Post.find(post.id)
tp.enable { post.changed? }
p changed: counts.sort.to_h
