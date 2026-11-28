# frozen_string_literal: true

# ASC1 body numbers (script/upstream-bench): association loads through the
# statement cache, on the thread's already-leased connection.
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

class ApplicationRecord < ActiveRecord::Base
  primary_abstract_class
end

class Author < ApplicationRecord
  has_many :posts
  has_one :profile
end

class Post < ApplicationRecord
  belongs_to :author
end

class Profile < ApplicationRecord
  belongs_to :author
end

author = Author.create!(name: "a")
3.times { |i| author.posts.create!(title: "t#{i}") }
author.create_profile!(bio: "b")
post = author.posts.first
ActiveRecord::Base.lease_connection

UpstreamBench.report("belongs_to load") { post.association(:author).reset; post.author }
UpstreamBench.report("has_one load") { author.association(:profile).reset; author.profile }
UpstreamBench.report("has_many load") { author.posts.reset; author.posts.to_a }
