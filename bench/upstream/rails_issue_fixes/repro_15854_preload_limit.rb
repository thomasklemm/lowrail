require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define { create_table(:blogs); create_table(:posts) { |t| t.references :blog } }
class Post < ActiveRecord::Base; end
class Blog < ActiveRecord::Base
  has_many :posts
  has_many :limited_posts, -> { order(:id).limit(2) }, class_name: "Post"
end
2.times { b = Blog.create!; 3.times { b.posts.create! } }
p Blog.order(:id).map { |b| b.limited_posts.size }
p Blog.includes(:limited_posts).order(:id).map { |b| b.limited_posts.size }
p preload: Blog.preload(:limited_posts).order(:id).map { |b| b.limited_posts.size }
p eager_load: Blog.eager_load(:limited_posts).order(:id).map { |b| b.limited_posts.size }
p first: Blog.includes(:limited_posts).first.limited_posts.size
p sql: Blog.preload(:limited_posts).to_a && nil
