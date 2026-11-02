# frozen_string_literal: true

# Census 4 behavior controls: SQL and results for edge cases of the candidate
# paths. Run from a Rails checkout (same flags as census_4_allocs.rb) and diff
# the output between trees.
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name }
  create_table(:posts) { |t| t.integer :author_id; t.boolean :published, default: false; t.string :title }
end
class Author < ActiveRecord::Base
  has_many :posts
  has_many :published_posts, -> { where(published: true) }, class_name: "Post"
  has_many :titled_posts, -> { where("title IS NOT NULL").where(title: %w[t0 t1]) }, class_name: "Post"
end
class Post < ActiveRecord::Base
  belongs_to :author
  scope :published, -> { where(published: true) }
end
2.times { |i| a = Author.create!(name: "a#{i}"); 3.times { |j| a.posts.create!(title: "t#{j}", published: j.odd?) } }
t = Post.arel_table

controls = {
  "in ids" => -> { Post.where(id: [1, 2, 3]) },
  "in with nil" => -> { Post.where(id: [1, nil]) },
  "only nil" => -> { Post.where(id: [nil]) },
  "empty" => -> { Post.where(id: []) },
  "one" => -> { Post.where(id: [2]) },
  "ranges" => -> { Post.where(id: [1..2, 5, nil]) },
  "range only" => -> { Post.where(id: [1..2]) },
  "endless range" => -> { Post.where(id: [4.., 1]) },
  "records" => -> { Post.where(author: Author.all.to_a) },
  "not in" => -> { Post.where.not(id: [1, 2..3]) },
  "merge" => -> { Post.where(author_id: 1).merge(Post.published) },
  "merge overrides" => -> { Post.where(published: false).merge(Post.published) },
  "merge into empty" => -> { Post.all.merge(Post.where(title: "t1")) },
  "merge empty" => -> { Post.where(title: "t1").merge(Post.all) },
  "merge sql string" => -> { Post.where("title = 't1'").merge(Post.where(title: "t2")) },
  "merge arel node" => -> { Post.where(t[:title].lower.eq("t1")).merge(Post.where(t[:title].lower.eq("t2"))) },
  "rewhere" => -> { Post.where(title: "t1").rewhere(title: "t2") },
  "unscope where" => -> { Post.where(title: "t1", published: true).unscope(where: :title) },
  "unscope missing" => -> { Post.all.unscope(where: :title) },
  "or" => -> { Post.where(title: "t1").or(Post.where(title: "t2")) },
  "has_many" => -> { Author.first.posts },
  "scoped has_many" => -> { Author.first.published_posts },
  "scoped sql has_many" => -> { Author.first.titled_posts },
  "belongs_to" => -> { Post.where(id: Post.first.author_id) },
  "preload" => -> { Author.includes(:posts, :published_posts) },
  "except order" => -> { Post.order(:title).where(published: true).except(:order) },
  "except where" => -> { Author.first.published_posts.except(:where) },
  "only where" => -> { Post.where(author_id: 1).order(:id).limit(2).only(:where) },
  "only none" => -> { Post.where(author_id: 1).only },
  "eager_load" => -> { Author.eager_load(:published_posts).where(posts: { title: %w[t0 t1] }) },
}
controls.each do |name, build|
  relation = build.call
  rows = relation.to_a
  rows.each { |r| r.association(:posts).target.size if r.is_a?(Author) && r.association(:posts).loaded? }
  puts "#{name}: #{relation.to_sql} => #{rows.map(&:id).inspect} exists=#{relation.exists?}"
end
