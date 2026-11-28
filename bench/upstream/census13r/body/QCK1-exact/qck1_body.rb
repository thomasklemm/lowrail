# frozen_string_literal: true

# QCK1 body numbers (script/upstream-bench): queries with binds under the query
# cache, as a miss (cache cleared first) and as a hit.
require "active_support/all"
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.integer :author_id; t.string :title; t.boolean :published; t.timestamps }
end

class Post < ActiveRecord::Base
end

Post.create!(author_id: 1, title: "a", published: true)
connection = ActiveRecord::Base.lease_connection
ActiveRecord::Base.connection_pool.enable_query_cache!
post = Post.first

UpstreamBench.report("find, miss") { connection.clear_query_cache; Post.find(post.id) }
UpstreamBench.report("find, hit") { Post.find(post.id) }
UpstreamBench.report("where with 3 binds, miss") { connection.clear_query_cache; Post.where(author_id: 1, published: true).limit(5).to_a }
UpstreamBench.report("where with 3 binds, hit") { Post.where(author_id: 1, published: true).limit(5).to_a }
