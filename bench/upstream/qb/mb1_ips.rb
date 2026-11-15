# frozen_string_literal: true

# MB1 (skip merging a relation without values): a where chain on a has_many.
#   MB1_RAILS=/path/to/rails [MB1_INSTALL=1] ruby -I BENCHMARK_IPS_LIB THIS
require "bundler/inline"

gemfile(ENV["MB1_INSTALL"] == "1") do
  source "https://rubygems.org"
  gem "activerecord", path: File.join(ENV.fetch("MB1_RAILS"), "activerecord")
  gem "activesupport", path: File.join(ENV.fetch("MB1_RAILS"), "activesupport")
  gem "activemodel", path: File.join(ENV.fetch("MB1_RAILS"), "activemodel")
  gem "sqlite3"
end

require "active_record"
require "benchmark/ips"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.define do
  create_table :posts
  create_table :comments do |t|
    t.references :post
    t.boolean :approved, default: true
  end
end

class Post < ActiveRecord::Base
  has_many :comments
end

class Comment < ActiveRecord::Base
  belongs_to :post
end

post = Post.create!
3.times { post.comments.create! }

Benchmark.ips do |x|
  x.report("post.comments.where(approved: true)") { post.comments.where(approved: true) }
  x.report("post.comments.where(approved: true).to_a") { post.comments.where(approved: true).to_a }
end
