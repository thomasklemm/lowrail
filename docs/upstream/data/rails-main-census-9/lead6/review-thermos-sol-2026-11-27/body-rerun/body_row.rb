# frozen_string_literal: true

require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
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
UpstreamBench.report("serializable_hash") { post.serializable_hash }
