# frozen_string_literal: true

# Census 5 behavior controls: SQL, results and relation state for edge cases of
# the candidate paths (Relation#merge, association scopes, extensions). Run from
# a Rails checkout (same flags as census_5_allocs.rb) and diff the output
# between trees.
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name }
  create_table(:posts) { |t| t.integer :author_id; t.boolean :published, default: false; t.string :title; t.string :type }
  create_table(:comments) { |t| t.integer :post_id; t.string :body; t.string :commentable_type; t.integer :commentable_id }
  create_table(:taggings) { |t| t.integer :post_id; t.string :taggable_type; t.integer :taggable_id }
  create_table(:tags) { |t| t.string :name }
end
module Countable
  def counted = "counted #{count}"
end
module Titled
  def titles = pluck(:title)
end
class Author < ActiveRecord::Base
  has_many :posts
  has_many :published_posts, -> { where(published: true) }, class_name: "Post"
  has_many :extended_posts, -> { extending(Titled) }, class_name: "Post"
  has_many :block_posts, class_name: "Post" do
    def firsts = limit(1).to_a
  end
  has_many :comments, through: :posts
  has_many :published_comments, -> { where(body: "c") }, through: :published_posts, source: :comments
  has_many :limited_posts, -> { limit(1).offset(1).distinct.readonly.annotate("x") }, class_name: "Post"
end
class Post < ActiveRecord::Base
  belongs_to :author
  has_many :comments
  has_many :taggings
  has_many :tags, through: :taggings, source: :taggable, source_type: "Tag"
  scope :published, -> { where(published: true) }
  scope :recent, -> { order(id: :desc).limit(5) }
  scope :counting, -> { extending(Countable) }
end
class SpecialPost < Post; end
class Comment < ActiveRecord::Base
  belongs_to :post
end
class Tagging < ActiveRecord::Base
  belongs_to :post
  belongs_to :taggable, polymorphic: true
end
class Tag < ActiveRecord::Base; end
class ScopedPost < ActiveRecord::Base
  self.table_name = "posts"
  default_scope { where(published: true).extending(Titled) }
end
class Reader < ActiveRecord::Base
  self.table_name = "authors"
  has_many :scoped_posts, foreign_key: :author_id
end
2.times do |i|
  a = Author.create!(name: "a#{i}")
  3.times do |j|
    p = a.posts.create!(title: "t#{j}", published: j.odd?)
    p.comments.create!(body: j.even? ? "c" : "d")
    p.taggings.create!(taggable: Tag.create!(name: "g#{j}"))
  end
end
SpecialPost.create!(author_id: 1, title: "s")

def state(rel)
  values = rel.values.to_h { |k, v| [k, v.is_a?(Array) ? v.map { |x| x.is_a?(Module) ? x.name || "anon" : x.to_s } : v.to_s] }
  { sql: rel.to_sql, values: values.sort.to_h, extends: rel.singleton_class.ancestors.take_while { _1 != rel.class }.map { _1.name || "anon" } }
end

author = Author.first
controls = {
  "merge plain" => -> { Post.where(author_id: 1).merge(Post.published) },
  "merge counting (extending)" => -> { Post.where(author_id: 1).merge(Post.counting) },
  "merge into counting" => -> { Post.counting.merge(Post.published) },
  "merge extending block" => -> { Post.all.merge(Post.extending { def hi = 1 }) },
  "merge recent (limit/order)" => -> { Post.published.merge(Post.recent) },
  "merge distinct/readonly/annotate/offset" => -> { Post.all.merge(Post.distinct.readonly.annotate("y").offset(1).limit(2)) },
  "merge strict_loading/group/having" => -> { Post.all.merge(Post.strict_loading.group(:author_id).having("count(*) > 0")) },
  "merge unscope" => -> { Post.where(title: "t1").merge(Post.unscope(where: :title)) },
  "merge references/eager_load" => -> { Post.all.merge(Post.eager_load(:author).references(:authors)) },
  "merge none" => -> { Post.all.merge(Post.none) },
  "merge hash" => -> { Post.all.merge(where: { published: true }, limit: 1) },
  "merge proc" => -> { Post.all.merge(-> { where(published: true) }) },
  "merge other model" => -> { Post.joins(:author).merge(Author.where(name: "a0")) },
  "self merge!" => -> { r = Post.where(title: "t1").limit(1); r.merge!(r) },
  "has_many scope" => -> { author.posts },
  "scoped has_many" => -> { author.published_posts },
  "extended has_many" => -> { author.extended_posts },
  "block has_many" => -> { author.block_posts },
  "through" => -> { author.comments },
  "scoped through" => -> { author.published_comments },
  "limited has_many" => -> { author.limited_posts },
  "source_type through" => -> { Post.first.tags },
  "default_scope model" => -> { ScopedPost.where(title: "t1") },
  "has_many to default_scope model" => -> { Reader.first.scoped_posts },
  "STI" => -> { SpecialPost.where(title: "s") },
  "belongs_to scope" => -> { Post.first.association(:author).scope },
}
controls.each do |name, build|
  rel = build.call
  rows = rel.respond_to?(:group_values) && rel.group_values.any? ? rel.count : rel.to_a.map { |r| r.attributes.values }
  puts "#{name}: #{state(rel).inspect.gsub(/0x\h+/, "0x")} => #{rows.inspect}"
end
puts "counting: #{Post.where(author_id: 1).merge(Post.counting).counted}"
puts "extended: #{author.extended_posts.titles.inspect}"
puts "block: #{author.block_posts.firsts.map(&:id).inspect}"
puts "default_scope titles: #{Reader.first.scoped_posts.titles.inspect}"
puts "reader: #{Post.first.author.name} #{author.posts.to_a.size} #{author.published_posts.to_a.size} #{author.comments.to_a.size} #{author.published_comments.to_a.size} #{Post.first.tags.to_a.size}"
puts "exists/count: #{author.posts.exists?} #{author.posts.count} #{Post.first.comments.size}"
