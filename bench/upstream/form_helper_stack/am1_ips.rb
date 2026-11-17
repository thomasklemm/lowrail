require "active_support/all"
require "active_model"
require "benchmark/ips"

class Post
  include ActiveModel::Model
  attr_accessor :title
  validates :title, presence: true
end

post = Post.new(title: "Hello")
post.valid?

Benchmark.ips do |x|
  x.report("errors[:title]") { post.errors[:title] }
  x.report("errors[\"title\"]") { post.errors["title"] }
end
