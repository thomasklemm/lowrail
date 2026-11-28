# frozen_string_literal: true

# QCK1 body numbers (script/upstream-bench): IN-list queries, one bind per id,
# under the query cache, as a miss (cache cleared first) and as a hit.
require "active_support/all"
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.integer :author_id; t.string :title; t.timestamps }
end

class Post < ActiveRecord::Base
end

100.times { |i| Post.create!(author_id: i, title: "t#{i}") }
connection = ActiveRecord::Base.lease_connection
ActiveRecord::Base.connection_pool.enable_query_cache!
ids20 = Post.order(:id).limit(20).ids
ids100 = Post.order(:id).ids

UpstreamBench.report("where(id: 20 ids), miss") { connection.clear_query_cache; Post.where(id: ids20).to_a }
UpstreamBench.report("where(id: 20 ids), hit") { Post.where(id: ids20).to_a }
UpstreamBench.report("where(id: 100 ids), miss") { connection.clear_query_cache; Post.where(id: ids100).to_a }
UpstreamBench.report("where(id: 100 ids), hit") { Post.where(id: ids100).to_a }
