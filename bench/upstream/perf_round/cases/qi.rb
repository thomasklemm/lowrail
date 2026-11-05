$LOAD_PATH.unshift(*%w[activesupport activemodel activerecord].map { File.join(ENV.fetch("RAILS_PATH"), _1, "lib") })
require "active_record"
require "objspace"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define { create_table(:posts) { |t| t.string :title; t.integer :n; t.timestamps } }
class Post < ActiveRecord::Base; end
Post.create!(title: "a", n: 1)
ActiveRecord::Base.connection_pool.lease_connection
MICRO = {
  "find" => -> { -> { Post.find(1) } },
  "where" => -> { -> { Post.where(n: 1).to_a } },
  "update_all" => -> { -> { Post.where(id: 1).update_all(n: 1) } },
  "insert" => -> { -> { Post.insert({ title: "x", n: 2 }) } },
  "exec_query" => -> { c = Post.connection; -> { c.exec_query("SELECT 1") } },
  "intent" => -> { c = Post.connection; -> { ActiveRecord::ConnectionAdapters::QueryIntent.new(adapter: c, raw_sql: "SELECT 1") } },
}
