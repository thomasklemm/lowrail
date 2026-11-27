# frozen_string_literal: true
# revive_jit.sh: revive_ir.rb for YJIT and ZJIT, with the harness blocks as &:call so nothing of the harness compiles in the window.
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
  "text_field_tag" => -> { V.text_field_tag(:query, "rails") },
  "hidden_field_tag" => -> { V.hidden_field_tag(:token, "abc") },
  "submit_tag" => -> { V.submit_tag("Save") },
  "tag.input" => -> { V.tag.input(type: "text", name: "q") },
  "button_to 1 param" => -> { V.button_to("Go", "/posts", params: { k: "v" }) },
  "f.text_field" => -> { F.text_field(:title) },
  "f.text_area" => -> { F.text_area(:body) },
  "f.check_box" => -> { F.check_box(:published) },
  "f.radio_button" => -> { F.radio_button(:category, "news") },
  "f.select" => -> { F.select(:category, %w[news blog]) },
  "f.label" => -> { F.label(:title) },
  "form_with 5 fields (label text)" => -> {
    V.form_with(model: POST) do |f|
      f.label(:title, "Title") + f.text_field(:title) + f.label(:body, "Body") + f.text_area(:body) +
        f.label(:email, "Email") + f.email_field(:email) + f.label(:published, "Published") + f.check_box(:published) +
        f.label(:category, "Category") + f.select(:category, %w[news blog]) + f.submit
    end
  },
  "form_with 5 fields (f.label)" => -> {
    V.form_with(model: POST) do |f|
      f.label(:title) + f.text_field(:title) + f.label(:body) + f.text_area(:body) +
        f.label(:email) + f.email_field(:email) + f.label(:published) + f.check_box(:published) +
        f.label(:category) + f.select(:category, %w[news blog]) + f.submit
    end
  },
}

jit = if defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? then -> { RubyVM::YJIT.runtime_stats[:compiled_block_count] }
elsif defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled? then -> { RubyVM::ZJIT.stats.then { _1[:compiled_iseq_count] + _1[:compiled_side_exit_count] } }
end
# Each scenario warms up in rounds of N calls, GC off as in the window, until three rounds in a row compile nothing
# (at most 30). The window then reports each scenario's own compile count, taken outside its Callgrind part.
n = Integer(n)
SCENARIOS.each_value do |fn|
  500.times { fn.call }
  next unless jit
  GC.disable
  streak = 0
  30.times do
    b = jit.()
    n.times { fn.call }
    streak = jit.() == b ? streak + 1 : 0
    break if streak == 3
  end
  GC.enable
end
GC.start
GC.disable
[-> {}].cycle(0, &:call)
# A first pass with cycle(0) compiles this loop itself, so the measured pass compiles only scenario code; its parts
# are skipped (skip_parts).
[0, n].each do |k|
  SCENARIOS.each do |name, fn|
    b = jit&.call
    [fn].cycle(k, &:call)
    $stderr.puts "jit_window: #{name} #{jit.() - b}" if jit && k > 0
  end
end
$stderr.puts "skip_parts: #{SCENARIOS.size}"
$stderr.puts "scenarios: #{SCENARIOS.keys.join(",")}"
