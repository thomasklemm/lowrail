# frozen_string_literal: true
# Objects per call for realistic form helper calls on a Rails checkout (ARGV[0]); candidates from sweep_patches.rb
# by name in PATCH (comma-separated). SITES=1 lists allocation sites, OUT=1 prints the rendered HTML instead.
# Run from the checkout with its bundle: bundle exec ruby sweep_count.rb <rails> [label filter]
rails = ARGV.fetch(0)
%w[activesupport actionview actionpack activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_support/core_ext"
require "active_record"
require "action_view"
require "action_controller"
require "objspace"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title; t.text :body; t.string :email; t.boolean :published; t.string :category }
end
class Post < ActiveRecord::Base; end

require_relative "sweep_patches"

# The defaults of a new app (load_defaults on main), which the Railtie would set.
ActionView::Helpers::FormHelper.form_with_generates_ids = true
ActionView::Helpers::FormHelper.form_with_generates_remote_forms = false
ActionView::Helpers::FormTagHelper.default_enforce_utf8 = false
ActionView::Helpers::NavigationHelper.button_to_generates_button_tag = true
ActionView::Base.remove_hidden_field_autocomplete = true

routes = ActionDispatch::Routing::RouteSet.new
routes.draw { resources :posts }
view_class = ActionView::Base.with_empty_template_cache
view_class.include(routes.url_helpers)
V = view_class.with_view_paths([])
V.define_singleton_method(:protect_against_forgery?) { false }
POST = Post.create!(title: "Hello", body: "Text", email: "a@b.c", published: true, category: "news")
F = ActionView::Helpers::FormBuilder.new(:post, POST, V, {})

SCENARIOS = {
  "tag(:input, 3 keys)" => -> { V.tag(:input, type: "text", name: "q", value: "x") },
  "content_tag(:div, class:)" => -> { V.content_tag(:div, "Hi", class: "card") },
  "tag.div(class:)" => -> { V.tag.div("Hi", class: "card") },
  "tag.div(data: {id:})" => -> { V.tag.div("Hi", data: { id: 1 }) },
  "tag.br" => -> { V.tag.br },
  "tag.div(class: [a, b])" => -> { V.tag.div("Hi", class: ["card", "active"]) },
  "link_to" => -> { V.link_to("Post", "/posts/1") },
  "link_to class:" => -> { V.link_to("Post", "/posts/1", class: "nav") },
  "text_field_tag" => -> { V.text_field_tag("q", "x") },
  "text_field_tag class:" => -> { V.text_field_tag("q", "x", class: "input") },
  "hidden_field_tag" => -> { V.hidden_field_tag("post[tag_ids][]", "1") },
  "label_tag" => -> { V.label_tag("q", "Query") },
  "check_box_tag" => -> { V.check_box_tag("accept", "1", true) },
  "submit_tag" => -> { V.submit_tag("Save") },
  "button_to" => -> { V.button_to("Delete", "/posts/1", method: :delete) },
  "button_to params: 1" => -> { V.button_to("Save", "/posts", params: { id: 1 }) },
  "f.text_field" => -> { F.text_field(:title) },
  "f.text_field class:" => -> { F.text_field(:title, class: "input") },
  "f.email_field placeholder:" => -> { F.email_field(:email, placeholder: "you@example.com") },
  "f.text_area" => -> { F.text_area(:body) },
  "f.hidden_field" => -> { F.hidden_field(:title) },
  "f.check_box" => -> { F.check_box(:published) },
  "f.radio_button" => -> { F.radio_button(:category, "news") },
  "f.select" => -> { F.select(:category, %w[news blog]) },
  "f.label" => -> { F.label(:title) },
  "f.label text" => -> { F.label(:title, "Title") },
  "f.submit" => -> { F.submit },
  "form_with (5 fields)" => -> {
    V.form_with(model: POST) do |f|
      f.label(:title, "Title") + f.text_field(:title) + f.text_area(:body) + f.check_box(:published) +
        f.select(:category, %w[news blog]) + f.submit
    end
  },
}

only = ARGV[1]
if ENV["OUT"]
  SCENARIOS.each { |l, fn| puts "#{l}\t#{fn.call}" }
  exit
end
SCENARIOS.each do |label, fn|
  next if only && !label.include?(only)
  3.times { fn.call }
  GC.start
  GC.disable
  before = GC.stat(:total_allocated_objects)
  100.times { fn.call }
  per_call = (GC.stat(:total_allocated_objects) - before) / 100.0
  GC.enable
  printf "%-28s %6.1f\n", label, per_call
  next unless ENV["SITES"]
  GC.start
  GC.disable
  ObjectSpace.trace_object_allocations_start
  g = GC.count
  fn.call
  ObjectSpace.trace_object_allocations_stop
  sites = ObjectSpace.each_object(BasicObject).select { |o| (ObjectSpace.allocation_generation(o) == g rescue false) }
    .map { |o| "#{o.class} #{ObjectSpace.allocation_sourcefile(o).to_s.sub(%r{.*/lib/}, '')}:#{ObjectSpace.allocation_sourceline(o)}" }
  ObjectSpace.trace_object_allocations_clear
  GC.enable
  sites.tally.sort_by { |k, v| [-v, k] }.each { |k, v| puts "    #{v} #{k}" }
end
