# frozen_string_literal: true

# Census 4 per-call allocation micro. Run from a Rails checkout:
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
end
class Post < ActiveRecord::Base
  belongs_to :author
  has_many :comments
  scope :published, -> { where(published: true) }
end
class Comment < ActiveRecord::Base
  belongs_to :post
end
authors = 3.times.map { |i| Author.create!(name: "a#{i}") }
authors.each { |a| 2.times { |j| a.posts.create!(title: "t#{j}", published: j.odd?).comments.create!(body: "c") } }
ids = Post.ids

def m(label)
  10.times { yield }
  GC.start
  GC.disable
  before = GC.stat(:total_allocated_objects)
  yield
  puts format("%-52s %d", label, GC.stat(:total_allocated_objects) - before)
ensure
  GC.enable
end

m("Post.where(id: ids).to_a") { Post.where(id: ids).to_a }
m("Post.where(id: [ids.first, nil]).to_a") { Post.where(id: [ids.first, nil]).to_a }
m("Post.where(id: [1..2, 5]).to_a") { Post.where(id: [1..2, 5]).to_a }
m("Author.includes(:posts).to_a") { Author.includes(:posts).to_a }
m("Post.preload(:author, :comments).to_a") { Post.preload(:author, :comments).to_a }
m("author.posts.to_a (has_many reader)") { Author.first.posts.to_a }
m("author.published_posts.to_a (scoped has_many)") { Author.first.published_posts.to_a }
m("post.author (belongs_to reader)") { Post.first.author }
m("Post.where(author_id: 1).merge(Post.published).to_a") { Post.where(author_id: 1).merge(Post.published).to_a }
m("Post.published.merge(Post.where(title: 't1')).to_a") { Post.published.merge(Post.where(title: "t1")).to_a }
m("Post.where(title: 't1').unscope(where: :title).to_a") { Post.where(title: "t1").unscope(where: :title).to_a }
m("Post.where(author_id: 1).exists?") { Post.where(author_id: 1).exists? }
m("author.posts.exists?") { Author.first.posts.exists? }
m("Post.order(:id).except(:order).to_a") { Post.order(:id).except(:order).to_a }
m("Post.where(author_id: 1).only(:where).to_a") { Post.where(author_id: 1).only(:where).to_a }
ActiveRecord::Base.connection_pool.release_connection
m("Post.first, then release (one checkin)") { Post.first; ActiveRecord::Base.connection_pool.release_connection }
m("Post.first with no lease held (per-query lease)") { Post.first }
m("release_connection alone (one checkin)") { ActiveRecord::Base.connection; ActiveRecord::Base.connection_pool.release_connection }
