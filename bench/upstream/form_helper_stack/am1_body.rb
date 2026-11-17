# script/upstream-bench script for AM1, the setup of am1_objs.rb: a valid Post and a form builder field on it.
require "active_support/all"
require "active_model"
require "action_view"

class Post
  include ActiveModel::Model
  include ActiveModel::Attributes
  attribute :title, :string
  validates :title, presence: true
end

post = Post.new(title: "Hello")
post.valid?

view = ActionView::Base.empty
form = ActionView::Helpers::FormBuilder.new(:post, post, view, {})

UpstreamBench.report("errors[:title]") { post.errors[:title] }
UpstreamBench.report("errors[\"title\"]") { post.errors["title"] }
UpstreamBench.report("text_field") { form.text_field(:title) }
