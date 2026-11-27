# frozen_string_literal: true
# TO1 under ZJIT on current Ruby master: the tag() helpers and the form-builder field TO1 held on (f.text_field).
require "active_support"
require "active_support/core_ext"
require "active_record"
require "action_view"
require "action_controller"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title; t.text :body; t.boolean :published }
end
class Post < ActiveRecord::Base; end

ActionView::Helpers::FormHelper.form_with_generates_ids = true
ActionView::Helpers::FormTagHelper.default_enforce_utf8 = false
ActionView::Base.remove_hidden_field_autocomplete = true
routes = ActionDispatch::Routing::RouteSet.new
routes.draw { resources :posts }
view_class = ActionView::Base.with_empty_template_cache
view_class.include(routes.url_helpers)
view = view_class.with_view_paths([])
view.define_singleton_method(:protect_against_forgery?) { false }
post = Post.create!(title: "Hello", body: "Text", published: true)
f = ActionView::Helpers::FormBuilder.new(:post, post, view, {})

UpstreamBench.report("text_field_tag") { view.text_field_tag(:query, "rails") }
UpstreamBench.report("submit_tag") { view.submit_tag("Save") }
UpstreamBench.report("tag.input") { view.tag.input(type: "text", name: "q") }
UpstreamBench.report("f.text_field") { f.text_field(:title) }
UpstreamBench.report("f.check_box") { f.check_box(:published) }
