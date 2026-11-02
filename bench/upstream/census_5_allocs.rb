# frozen_string_literal: true

# Census 5 per-call allocation micro. Run from a Rails checkout:
#   ruby [--yjit] -Iactivesupport/lib -Iactivemodel/lib -Iactiverecord/lib SCRIPT
# Prints objects allocated by one warmed call of each idiomatic pattern.
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name }
  create_table(:posts) { |t| t.integer :author_id; t.boolean :published, default: false; t.string :title }
  create_table(:comments) { |t| t.integer :post_id; t.string :body }
end
class Author < ActiveRecord::Base
  has_many :posts
  has_many :published_posts, -> { where(published: true) }, class_name: "Post"
  has_many :comments, through: :posts
end
class Post < ActiveRecord::Base
  belongs_to :author
  has_many :comments
  scope :published, -> { where(published: true) }
  scope :recent, -> { order(id: :desc).limit(5) }
end
class Comment < ActiveRecord::Base
  belongs_to :post
end
authors = 3.times.map { |i| Author.create!(name: "a#{i}") }
authors.each { |a| 2.times { |j| a.posts.create!(title: "t#{j}", published: j.odd?).comments.create!(body: "c") } }

def m(label)
  10.times { yield }
  GC.start
  GC.disable
  before = GC.stat(:total_allocated_objects)
  yield
  puts format("%-58s %d", label, GC.stat(:total_allocated_objects) - before)
ensure
  GC.enable
end

author = Author.first
post = Post.first
m("post.author (belongs_to reader)") { Post.first.author }
m("author.posts.to_a (has_many reader)") { Author.first.posts.to_a }
m("author.published_posts.to_a (scoped has_many)") { Author.first.published_posts.to_a }
m("author.comments.to_a (has_many :through)") { Author.first.comments.to_a }
m("author.posts.where(published: true).to_a") { author.posts.where(published: true).to_a }
m("author.posts.order(:id).first") { author.posts.order(:id).first }
m("author.posts.count") { author.posts.count }
m("author.posts.exists?") { author.posts.exists? }
m("post.comments.size (unloaded)") { Post.first.comments.size }
m("Post.where(author_id: 1).merge(Post.published).to_a") { Post.where(author_id: 1).merge(Post.published).to_a }
m("Post.published.merge(Post.recent).to_a") { Post.published.merge(Post.recent).to_a }
m("Post.where(title: 't1').to_a") { Post.where(title: "t1").to_a }
m("Author.includes(:posts).to_a") { Author.includes(:posts).to_a }
