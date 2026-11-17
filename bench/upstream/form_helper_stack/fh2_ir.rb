# frozen_string_literal: true
# fh2_ir.sh runs this under Callgrind with --toggle-collect=rb_ary_cycle --dump-after=rb_ary_cycle: the sweep's
# Active Record Post on SQLite and new-app defaults (sweep_count.rb), 2,000 warm-up calls per scenario, GC off, then
# each scenario inside its own Array#cycle(N), so every scenario is one Callgrind part. A cycle(0) first measures the
# loop's overhead. Usage: ruby fh2_ir.rb <rails> N
rails, n = ARGV
%w[activesupport actionview actionpack activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_support/core_ext"
require "active_record"
require "action_view"
require "action_controller"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title; t.text :body; t.string :email; t.boolean :published; t.string :category }
end
class Post < ActiveRecord::Base; end

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
  "f.text_field" => -> { F.text_field(:title) },
  "f.text_area" => -> { F.text_area(:body) },
  "f.radio_button" => -> { F.radio_button(:category, "news") },
  "f.select" => -> { F.select(:category, %w[news blog]) },
  "f.label" => -> { F.label(:title) },
  "form_with (5 fields)" => -> {
    V.form_with(model: POST) do |f|
      f.label(:title, "Title") + f.text_field(:title) + f.text_area(:body) + f.check_box(:published) +
        f.select(:category, %w[news blog]) + f.submit
    end
  },
}

SCENARIOS.each_value { |fn| 2000.times { fn.call } }
GC.start
GC.disable
[-> {}].cycle(0) { |o| o.call }
SCENARIOS.each_value { |fn| [fn].cycle(Integer(n)) { |o| o.call } }
$stderr.puts "scenarios: #{SCENARIOS.keys.join(",")}"
