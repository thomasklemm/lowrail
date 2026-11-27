$LOAD_PATH.unshift(*%w[activesupport activemodel activerecord].map { "/home/user/w/rails-main/#{_1}/lib" })
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.lease_connection.execute("create table posts (id integer primary key, title text)")
class ApplicationRecord < ActiveRecord::Base; primary_abstract_class; end
class Post < ApplicationRecord; end
pool = Post.connection_pool
h = Post.connection_handler
$op = case ENV["CASE"]
when "noop" then -> { }
when "pool" then -> { Post.connection_pool }
when "handler" then -> { Post.connection_handler }
when "role" then -> { Post.current_role }
when "shard" then -> { Post.current_shard }
when "spec" then -> { Post.connection_specification_name }
when "retrieve" then -> { h.retrieve_connection_pool("ActiveRecord::Base", role: :writing, shard: :default, strict: true) }
when "poolwith" then -> { pool.with_connection { } }
when "with" then -> { Post.with_connection { } }
end
