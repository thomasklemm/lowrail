# frozen_string_literal: true
# Prints the output (or exception class and message) of tag and form helpers over many names, option shapes and
# builders, one line each, so main and PATCH=... can be diffed. Run from the checkout with its bundle:
#   bundle exec ruby sweep_fuzz.rb <rails> > main.txt; PATCH=all bundle exec ruby sweep_fuzz.rb <rails> > all.txt
rails = ARGV.fetch(0)
%w[activesupport actionview actionpack activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_support/core_ext"
require "active_record"
require "action_view"
require "action_controller"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title; t.text :body; t.boolean :published; t.string :category; t.string :tags }
end
class Post < ActiveRecord::Base
  def tag_list = %w[a b]
end
class Item
  include ActiveModel::Model
  attr_accessor :title, :published, :category, :tags
  def persisted? = false
end
module Admin
  class Post < ::Post; end
end

require_relative "sweep_patches"

routes = ActionDispatch::Routing::RouteSet.new
routes.draw { resources :posts }
view_class = ActionView::Base.with_empty_template_cache
view_class.include(routes.url_helpers)
V = view_class.with_view_paths([])
V.define_singleton_method(:protect_against_forgery?) { false }
CALLS = Hash.new(0)
# to_s that counts its calls, so a candidate that calls it more or less often shows up in the output.
class Counted
  def initialize(s) = @s = s
  def to_s = "#{@s}#{CALLS[@s] += 1}"
  def inspect = "Counted(#{@s})"
end
class Named
  def initialize(s) = @s = s
  def to_s = @s
  def inspect = "Named(#{@s})"
end
class SubHash < Hash; end
rng = Random.new(7)
parts = ["post", "comment", "[", "]", "][", "_", "?", ".", ":", "-", "ä", " ", "0", "x", "[]", "_attributes", "\"", "<", "&"]
names = ["", "post", "post[title]", "post[tags][]", "line_item", "user_", "a.b:c-d", "q?", "ä", "Post Title.x", :post,
         :title?, nil, 12, 1.5, Named.new("post[title]"), Counted.new("c"), "post[title]".html_safe, "<b>".html_safe,
         "post[comments_attributes][0]", "été", "bad\xFF".dup.force_encoding("UTF-8"),
         "x".encode("UTF-16LE")] + 40.times.map { Array.new(rng.rand(1..4)) { parts.sample(random: rng) }.join }

hwia = ActiveSupport::HashWithIndifferentAccess
OPTS = [
  {}, { class: "c" }, { "class" => "c" }, hwia.new(class: "c", "autocomplete" => "on"), SubHash[:class, "s"],
  { class: "f" }.freeze, { id: nil }, { "id" => "given" }, { id: "x", "id" => "y" },
  { data: { controller: "hello", turbo_frame: "f", id: 1, "a_b" => "s", nil => 1, "" => 2, x: nil } },
  { aria: { label: "L", describedby: ["a", "b"], expanded: false, hidden: { a: true } } },
  { class: ["a", { b: true, c: false }, nil, "<x>"] }, { class: ["a b", :c] }, { "data-x" => "1", data: "plain" },
  { disabled: true, form: "f", required: true }, { hidden: "until-found" }, { title: :sym, alt: /re"x/, size: 3 },
  { value: "v\"<" }, { name: "n" }, { type: "email" }, { autocomplete: "on" }, { nil => 1, "" => 2, " " => 3 },
  { "data-disable-with" => false }, { data: { disable_with: "Wait" } }, { escape: false, a: "<" },
]
def show(label)
  out = begin
    r = yield
    r.inspect
  rescue Exception => e # rubocop:disable Lint/RescueException
    "#{e.class}: #{e.message[0, 200].gsub(/0x\h+/, "0x")}"
  end
  puts "#{label}\t#{out}"
end
def copy(o) = o.frozen? ? o : o.dup

names.each_with_index do |n, i|
  [nil, 1, "ns"].each do |idx|
    show("field_id #{i} #{idx}") { V.field_id(n, n, index: idx) }
    show("field_id ns #{i} #{idx}") { V.field_id(n, :m?, "s", namespace: idx) }
    show("field_name #{i} #{idx}") { V.field_name(n, "m", index: idx) }
    show("field_name x #{i} #{idx}") { V.field_name(n, "m", "x", "y", multiple: true, index: idx) }
  end
  show("label_tag #{i}") { V.label_tag(n) }
  show("label_tag c #{i}") { V.label_tag(n, "C", nil) }
  show("check_box_tag #{i}") { V.check_box_tag(n) }
  show("check_box_tag 1 #{i}") { V.check_box_tag(n, "1") }
  show("check_box_tag 3 #{i}") { V.check_box_tag(n, "1", true, "x") }
  show("submit_tag #{i}") { V.submit_tag(n) }
  show("button_to #{i}") { V.button_to("x", "/p", params: { a: n, "b" => [n, 1] }) }
  show("tag #{i}") { V.tag(:input, value: n, name: n) }
  show("tag.div #{i}") { V.tag.div(n, data: { n => n }, class: [n]) }
  OPTS.each_with_index do |o, j|
    show("text_field_tag #{i} #{j}") { V.text_field_tag(n, "v", copy(o)) }
    show("hidden_field_tag #{i} #{j}") { V.hidden_field_tag(n, n, copy(o)) }
    show("check_box_tag o #{i} #{j}") { V.check_box_tag(n, "1", false, copy(o)) }
    show("label_tag o #{i} #{j}") { V.label_tag(n, "C", copy(o)) }
  end
end
OPTS.each_with_index do |o, j|
  show("tag #{j}") { V.tag(:input, copy(o)) }
  show("tag open #{j}") { V.tag(:div, copy(o), true) }
  show("tag noescape #{j}") { V.tag(:img, copy(o), false, false) }
  show("tag.br #{j}") { V.tag.br(**o.to_h.select { |k, _| Symbol === k }) }
  show("tag.input noescape #{j}") { V.tag.input(escape: false, **o.to_h.select { |k, _| Symbol === k }) }
  show("tag.div #{j}") { V.tag.div("x", **o.to_h.select { |k, _| Symbol === k }) }
  show("content_tag #{j}") { V.content_tag(:p, "<x>", copy(o)) }
  show("attributes #{j}") { V.tag.attributes(o) }
  show("submit_tag #{j}") { V.submit_tag("Save", copy(o)) }
  show("label_tag block #{j}") { V.label_tag("n", copy(o)) { "b" } }
end
[nil, false, "", [], "str"].each { |o| show("tag opts #{o.inspect}") { V.tag(:br, o) } }

persisted = Post.create!(title: "Hello", body: "B", published: true, category: "news", tags: "a")
fresh = Post.new(title: "From user", published: "1")
invalid = Post.new(title: "").tap { |p| p.errors.add(:title, :blank); p.errors.add(:category, "bad") }
objects = { persisted: persisted, fresh: fresh, invalid: invalid, item: Item.new(title: "t", published: true), none: nil,
            admin: Admin::Post.new(title: "a") }
object_names = [:post, "post", "post[comments_attributes][0]", "admin_post", "admin/post", "post[]", "", "a b.c", :"x?"]
methods = [:title, "title", :published, :category, :body, :"title?", "bad\xFF".dup.force_encoding("UTF-8")]
field_opts = OPTS.first(12) + [{ placeholder: true }, { placeholder: "P" }, { placeholder: :short }, { multiple: true },
                               { index: 3 }, { namespace: "ns" }, { index: nil, namespace: "n" }, { checked: true },
                               { include_hidden: false }, { value: "News Item.x" }, { skip_default_ids: true },
                               { maxlength: 5 }, { size: "3x4" }, { disabled: true, form: "f" }]
I18n.backend.store_translations(:en, helpers: { label: { post: { body: "Body text" } }, placeholder: { post: { title: "PH" } } })
objects.each do |oname, obj|
  object_names.each do |on|
    f = begin
      ActionView::Helpers::FormBuilder.new(on, obj, V, {})
    rescue ArgumentError => e
      show("builder #{oname} #{on.inspect}") { raise e }
      next
    end
    methods.each do |m|
      show("f.label #{oname} #{on.inspect} #{m.inspect}") { f.label(m) }
      show("f.label text #{oname} #{on.inspect} #{m.inspect}") { f.label(m, "Text") }
      show("f.label block #{oname} #{on.inspect} #{m.inspect}") { f.label(m) { |b| "#{b.translation}!" } }
      show("f.check_box nil #{oname} #{on.inspect} #{m.inspect}") { f.check_box(m, {}, "1", nil) }
      field_opts.each_with_index do |o, j|
        k = "#{oname} #{on.inspect} #{m.inspect} #{j}"
        show("f.text_field #{k}") { f.text_field(m, copy(o)) }
        show("f.text_area #{k}") { f.text_area(m, copy(o)) }
        show("f.hidden_field #{k}") { f.hidden_field(m, copy(o)) }
        show("f.check_box #{k}") { f.check_box(m, copy(o), "yes", "no") }
        show("f.radio_button #{k}") { f.radio_button(m, "News Item.x", copy(o)) }
        show("f.select #{k}") { f.select(m, [["News", "news"], "blog", ["<x>", 1, { class: "o" }]], { include_blank: true }, copy(o)) }
        show("f.select sel #{k}") { f.select(m, %w[news blog], { selected: "blog", disabled: ["news"] }, copy(o)) }
        show("f.label o #{k}") { f.label(m, copy(o)) }
      end
    end
    show("f.submit #{oname} #{on.inspect}") { f.submit }
  end
end
show("form_with") { V.form_with(model: persisted) { |f| f.text_field(:title) + f.check_box(:published) } }

attrs = [:title, "title", :missing, "missing", nil, 1, Object.new.tap { |o| def o.to_sym = :title; def o.inspect = "O" },
         Class.new(String).new("title"), "bad\xFF".dup.force_encoding("UTF-8"),
         "title".dup.tap { |s| def s.to_sym = (CALLS[:sym] += 1).odd? ? :title : :category }]
[Post.new, invalid].each_with_index do |model, mi|
  attrs.each_with_index do |a, ai|
    show("errors[] #{mi} #{ai}") { model.errors[a] }
    show("errors.where #{mi} #{ai}") { model.errors.where(a).map(&:type) }
    show("errors.where type #{mi} #{ai}") { model.errors.where(a, :blank).size }
    show("errors.where opts #{mi} #{ai}") { model.errors.where(a, count: 1).size }
    show("errors.messages_for #{mi} #{ai}") { model.errors.messages_for(a) }
    show("errors.include? #{mi} #{ai}") { model.errors.include?(a) }
    show("errors.added? #{mi} #{ai}") { model.errors.added?(a, :blank) }
  end
end
puts "CALLS #{CALLS.map { |k, v| [k.to_s, v] }.sort.inspect}"
