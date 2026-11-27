# frozen_string_literal: true

# L6 body numbers (script/upstream-bench): the census 9 lead 6 cases on a 30-column table
# (id, 9 x string/integer/boolean, timestamps), as in docs/upstream/data/rails-main-census-9/lead6/l6_ips.rb.
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
groups = $l6_groups || 9
ActiveRecord::Schema.define do
  create_table :posts do |t|
    groups.times { |i| t.string "title_#{i}"; t.integer "count_#{i}"; t.boolean "flag_#{i}" }
    t.timestamps
  end
end

class Post < ActiveRecord::Base; end

values = {}
groups.times { |i| values.merge!("title_#{i}" => "Hello", "count_#{i}" => i, "flag_#{i}" => true) }
id = Post.create!(values).id
post = Post.find(id)

UpstreamBench.report("update! of one column") { post.update!(count_0: post.count_0 + 1) }
UpstreamBench.report("find, then changed?") { Post.find(id).changed? }
UpstreamBench.report("serializable_hash") { post.serializable_hash }
