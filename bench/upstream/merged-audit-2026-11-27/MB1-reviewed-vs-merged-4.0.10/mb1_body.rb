# frozen_string_literal: true

# MB1 amendment check: building an association relation (merges a blank
# scope_for_association) and a plain Relation#merge with values, the case where
# the merged head calls one extra private predicate before the merge.
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table :posts
  create_table :comments do |t|
    t.references :post
    t.boolean :approved, default: true
  end
end

class Post < ActiveRecord::Base
  has_many :comments
end

class Comment < ActiveRecord::Base
  belongs_to :post
end

post = Post.create!
3.times { post.comments.create! }
approved = Comment.where(approved: true)
ordered = Comment.order(:id)

UpstreamBench.report("post.comments.where(approved: true)") { post.comments.where(approved: true) }
UpstreamBench.report("where.merge(order)") { approved.merge(ordered) }
