require "active_support/all"
require "active_model"
require "action_view"
require "benchmark/ips"

class Post
  include ActiveModel::Model
  include ActiveModel::Attributes
  attribute :title, :string
  attribute :published, :boolean
end

view = ActionView::Base.empty
form = ActionView::Helpers::FormBuilder.new(:post, Post.new(title: "Hello", published: true), view, {})

Benchmark.ips do |x|
  x.report("text_field") { form.text_field(:title) }
  x.report("checkbox") { form.checkbox(:published) }
end
