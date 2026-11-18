# script/upstream-bench script for FB1, the setup of fb1_ir.rb: an ActiveModel Post, new and persisted.
require "active_support/all"
require "active_model"
require "action_view"

class Post
  include ActiveModel::Model
  include ActiveModel::Attributes
  attribute :title, :string
  attribute :published, :boolean
end

class PersistedPost < Post
  def persisted? = true
end

view = ActionView::Base.empty
form = ActionView::Helpers::FormBuilder.new(:post, Post.new(title: "Hello", published: true), view, {})
persisted = ActionView::Helpers::FormBuilder.new(:post, PersistedPost.new(title: "Hello", published: true), view, {})

UpstreamBench.report("text_field") { form.text_field(:title) }
UpstreamBench.report("checkbox") { form.checkbox(:published) }
UpstreamBench.report("text_field, persisted") { persisted.text_field(:title) }
UpstreamBench.report("checkbox, persisted") { persisted.checkbox(:published) }
