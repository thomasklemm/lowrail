# frozen_string_literal: true

# LR1 body numbers (script/upstream-bench): connection lease lookups that hit an existing lease, and the
# association reset/load operations census 11 priced, on the thread's already-leased connection.
require "active_support/all"
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name; t.timestamps }
  create_table(:posts) { |t| t.references :author; t.string :title; t.timestamps }
  create_table(:comments) { |t| t.references :post; t.string :body; t.timestamps }
  create_table(:profiles) { |t| t.references :author; t.string :bio }
end

class Author < ActiveRecord::Base
  has_many :posts
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

UpstreamBench.report("lease_connection") { ActiveRecord::Base.lease_connection }
UpstreamBench.report("with_connection") { ActiveRecord::Base.with_connection { } }
UpstreamBench.report("has_many reset/load") { author.posts.reset; author.posts.to_a }
UpstreamBench.report("has_one reset/load") { author.association(:profile).reset; author.profile }
UpstreamBench.report("belongs_to reset/load") { comment.association(:post).reset; comment.post }
UpstreamBench.report("joins to_sql") { Author.joins(:posts).to_sql }
