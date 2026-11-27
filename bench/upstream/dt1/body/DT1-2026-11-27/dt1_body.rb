# frozen_string_literal: true

# DT1 body numbers (script/upstream-bench): a record loaded from a 30-column table
# (id, 9 x string/integer/boolean, timestamps), then one column saved or changed? asked,
# as a request does. $dt1_groups sets the width (9 groups = 30 columns, 32 = 99).
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
groups = $dt1_groups || 9
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

UpstreamBench.report("find, then update! of one column") { post = Post.find(id); post.update!(count_0: post.count_0 + 1) }
UpstreamBench.report("find, then changed?") { Post.find(id).changed? }
