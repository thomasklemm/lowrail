# frozen_string_literal: true

# Statement-cached finds and association loads (script/upstream-bench), on the
# thread's already-leased connection.
require "active_support/all"
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name; t.timestamps }
  create_table(:posts) { |t| t.references :author; t.string :title; t.timestamps }
  create_table(:profiles) { |t| t.references :author; t.string :bio }
end

class Author < ActiveRecord::Base
  has_many :posts
  has_one :profile
end

class Post < ActiveRecord::Base
  belongs_to :author
end

class Profile < ActiveRecord::Base
  belongs_to :author
end

author = Author.create!(name: "a")
3.times { |i| author.posts.create!(title: "t#{i}") }
author.create_profile!(bio: "b")
post = author.posts.first
ActiveRecord::Base.lease_connection

UpstreamBench.report("Post.find(id)") { Post.find(post.id) }
UpstreamBench.report("Post.find_by(title:)") { Post.find_by(title: "t1") }
UpstreamBench.report("belongs_to load") { post.association(:author).reset; post.author }
UpstreamBench.report("has_many load") { author.posts.reset; author.posts.to_a }
