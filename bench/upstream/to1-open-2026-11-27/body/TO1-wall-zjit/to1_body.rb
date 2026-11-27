# frozen_string_literal: true
# TO1 per call: tag() and void tag.* elements with attributes, through the form tag, asset and form builder helpers.
require "active_support"
require "active_support/core_ext"
require "active_model"
require "action_view"

class Post
  include ActiveModel::Model
  include ActiveModel::Attributes
  attribute :title, :string
  attribute :published, :boolean
end

ActionView::Helpers::FormTagHelper.default_enforce_utf8 = false
view = ActionView::Base.with_empty_template_cache.with_view_paths([])
post = Post.new(title: "Hello", published: true)
f = ActionView::Helpers::FormBuilder.new(:post, post, view, {})

UpstreamBench.report("text_field_tag") { view.text_field_tag(:query, "rails") }
UpstreamBench.report("hidden_field_tag") { view.hidden_field_tag(:return_to, "/posts") }
UpstreamBench.report("submit_tag") { view.submit_tag("Save") }
UpstreamBench.report("tag.input") { view.tag.input(type: "text", name: "q") }
UpstreamBench.report("image_tag") { view.image_tag("/images/logo.png", alt: "Logo") }
UpstreamBench.report("f.text_field") { f.text_field(:title) }
UpstreamBench.report("f.check_box") { f.check_box(:published) }
