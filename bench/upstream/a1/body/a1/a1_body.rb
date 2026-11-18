# frozen_string_literal: true

# A1 body numbers (script/upstream-bench): association loads and joins without an association scope,
# where the owner-condition check has nothing to compare, and one scoped association as a control.
require "active_support/all"
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name; t.timestamps }
  create_table(:posts) { |t| t.references :author; t.string :title; t.boolean :published, default: true; t.timestamps }
  create_table(:comments) { |t| t.references :post; t.string :body; t.timestamps }
  create_table(:profiles) { |t| t.references :author; t.string :bio }
end

class Author < ActiveRecord::Base
  has_many :posts
  has_many :published_posts, -> { where(published: true) }, class_name: "Post"
  has_many :comments, through: :posts
  has_one :profile
end

class Post < ActiveRecord::Base
  belongs_to :author
  has_many :comments
end

class Comment < ActiveRecord::Base
  belongs_to :post
end

class Profile < ActiveRecord::Base
  belongs_to :author
end

author = Author.create!(name: "a")
3.times { |i| author.posts.create!(title: "t#{i}") }
author.create_profile!(bio: "b")
comment = author.posts.first.comments.create!(body: "c")

UpstreamBench.report("author.posts") { author.posts.reset; author.posts.to_a }
UpstreamBench.report("author.profile") { author.association(:profile).reset; author.profile }
UpstreamBench.report("comment.post") { comment.association(:post).reset; comment.post }
UpstreamBench.report("author.comments (through)") { author.comments.reset; author.comments.to_a }
UpstreamBench.report("Author.joins(:posts)") { Author.joins(:posts).to_sql }
UpstreamBench.report("author.published_posts (scoped)") { author.published_posts.reset; author.published_posts.to_a }
