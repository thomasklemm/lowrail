# frozen_string_literal: true
# Census-9 lead 8: how many calls to table_name_qualified_unscope_values, and objects per association load and merge.
rails = ARGV.fetch(0)
%w[activesupport activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name }
  create_table(:posts) { |t| t.integer :author_id; t.string :title; t.boolean :published }
  create_table(:comments) { |t| t.integer :post_id; t.string :body }
end
class Author < ActiveRecord::Base; has_many :posts; has_many :comments, through: :posts; has_many :published_posts, -> { where(published: true) }, class_name: "Post"; end
class Post < ActiveRecord::Base; belongs_to :author; has_many :comments; scope :published, -> { where(published: true) }; end
class Comment < ActiveRecord::Base; belongs_to :post; end
a = Author.create!(name: "a"); p1 = a.posts.create!(title: "t", published: true); p1.comments.create!(body: "b")
calls = 0
ActiveRecord::Relation.prepend(Module.new { define_method(:table_name_qualified_unscope_values) { calls += 1; super() } }) if ENV["COUNT"]
cases = {
  "author.posts.to_a" => -> { Author.find(a.id).posts.to_a },
  "author.published_posts.to_a" => -> { Author.find(a.id).published_posts.to_a },
  "author.comments.to_a" => -> { Author.find(a.id).comments.to_a },
  "Post.where.merge(published)" => -> { Post.where(author_id: a.id).merge(Post.published).to_a },
}
cases.each do |name, c|
  300.times { c.() }; calls = 0; GC.start; GC.disable
  b = GC.stat(:total_allocated_objects); 500.times { c.() }; o = (GC.stat(:total_allocated_objects) - b) / 500.0
  GC.enable
  puts format("%-30s objects %.1f  calls/op %.1f", name, o, calls / 500.0)
end
