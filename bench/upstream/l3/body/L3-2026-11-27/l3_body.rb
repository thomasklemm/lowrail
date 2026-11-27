# frozen_string_literal: true

# L3 body numbers (script/upstream-bench): the body's benchmark-ips setup (30 columns), plus
# attributes_before_type_cast and the MessagePack cache coder. l3_body_w6.rb and l3_body_w102.rb set other widths.
require "active_record"
require "active_support/message_pack"
require "active_record/message_pack"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
groups = $l3_groups || 9
ActiveRecord::Schema.define do
  create_table :posts do |t|
    groups.times { |i| t.string "title_#{i}"; t.integer "count_#{i}"; t.boolean "flag_#{i}" }
    t.timestamps
  end
end

class Post < ActiveRecord::Base; end

values = {}
groups.times { |i| values.merge!("title_#{i}" => "Hello", "count_#{i}" => i, "flag_#{i}" => true) }
post = Post.find(Post.create!(values).id)
msgpack = MessagePack::Factory.new.tap do |factory|
  ActiveRecord::MessagePack::Extensions.install(factory)
  ActiveSupport::MessagePack::Extensions.install(factory)
end

UpstreamBench.report("Marshal.dump") { Marshal.dump(post) }
UpstreamBench.report("attributes_for_database") { post.attributes_for_database }
UpstreamBench.report("attributes_before_type_cast") { post.attributes_before_type_cast }
UpstreamBench.report("MessagePack dump") { msgpack.dump(post) }
