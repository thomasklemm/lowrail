# Who calls LazyIndexedAttributeSet#keys and #[] during update! of one column (30 columns).
require "bundler/setup"
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
callers = Hash.new(0)
tp = TracePoint.new(:call) do |t|
  next unless t.defined_class == ActiveModel::LazyIndexedAttributeSet && %i[keys []].include?(t.method_id)
  loc = caller_locations(2, 1).first
  callers["#{t.method_id} <- #{loc.label} #{File.basename(loc.path)}:#{loc.lineno}"] += 1
end
tp.enable { post.update!("count_0" => 8) }
callers.sort.each { |k, v| puts "#{v}\t#{k}" }
