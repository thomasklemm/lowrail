# frozen_string_literal: true
# Differential probe for FH2 (PH, AMT, V, SV, CB, OS, TR): prints each output (or exception) with its class,
# encoding, frozen and html_safe flags, the calls a duck object saw, and the caller's arguments afterwards, one line
# each. Run once per Rails checkout and diff: bundle exec ruby fh2_probe.rb <rails> > out.txt
rails = ARGV.fetch(0)
%w[activesupport actionview actionpack activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_support/core_ext"
require "active_record"
require "action_view"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title; t.text :body; t.boolean :published; t.string :category; t.integer :rank }
  create_table(:comments) { |t| t.integer :post_id; t.string :body }
end
class Post < ActiveRecord::Base
  has_many :comments
  accepts_nested_attributes_for :comments
end
class Comment < ActiveRecord::Base; belongs_to :post; end
class Item
  include ActiveModel::Model
  include ActiveModel::Attributes
  attribute :title, :string
  attribute :category, :string
  attribute :published, :boolean
  attribute :rank, :integer
end
LOG = []
# An object that answers every reader and logs the respond_to?/public_send calls form helpers make on it.
class Duck
  def initialize(from_user) = @from_user = from_user
  def respond_to_missing?(name, priv = false) = (LOG << "respond_to?(#{name})"; true)
  def method_missing(name, *args)
    LOG << "call #{name}"
    name.end_with?("_came_from_user?") ? @from_user : "#{name}-v"
  end
end
class Named
  def initialize(s) = @s = s
  def to_s = @s
  def inspect = "Named(#{@s.inspect})"
end
class FrozenTo
  def to_s = "Frozen Value.X"
  def inspect = "FrozenTo"
end
class SubString < String; end
class Custom < String
  def gsub(*) = (LOG << "Custom#gsub"; super)
  def include?(*) = (LOG << "Custom#include?"; super)
end

V = ActionView::Base.empty
HWIA = ActiveSupport::HashWithIndifferentAccess

def desc(r)
  extra = r.is_a?(String) ? " #{r.class} #{r.encoding} frozen=#{r.frozen?} safe=#{r.html_safe?}" : " #{r.class}"
  "#{r.inspect}#{extra}"
end

def show(label)
  LOG.clear
  out = begin
    desc(yield)
  rescue Exception => e # rubocop:disable Lint/RescueException
    "#{e.class}: #{e.message[0, 160].gsub(/0x\h+/, "0x")}"
  end
  puts "#{label}\t#{out}\t#{LOG.inspect}"
end

values = ["news", "News Item.x", "", "a b\tc", "Ärger ÖL", :news, :"News.x", nil, 1, 1.5, true, false,
          SubString.new("Sub Val"), "Safe <V>".html_safe, "frozen V".freeze, "été".encode("ISO-8859-1"),
          "wide v".encode("UTF-16LE"), "bin\xFF v".b, "bad\xFF v".dup.force_encoding("UTF-8"), Named.new("Named V"),
          FrozenTo.new, Custom.new("Cust V"), ["x", "y"], { a: 1 }]

object_names = [:post, "post", "post".html_safe, "post".freeze, SubString.new("post"), Custom.new("post"),
                "post[comments_attributes][0]", :"post[comments_attributes][12]", "post[comments_attributes][x]",
                "a[b_attributes][1][c_attributes][2]", "_attributes][", "post[]", "", "admin/post", "a b.c",
                "été".encode("ISO-8859-1"), "post".encode("UTF-16LE"), "post\xFF".b, "post\xFF".dup.force_encoding("UTF-8"),
                Named.new("post"), nil, 12]
method_names = [:title, "title", :title?, "title".html_safe, SubString.new("title"), "bad\xFF".dup.force_encoding("UTF-8"),
                "title".encode("UTF-16LE")]

I18n.backend.store_translations(:en, helpers: {
  label: { post: { title: "Label T", comments: { body: "Nested B" } }, comment: { body: "Comment B" } },
  placeholder: { post: { title: "PH T", comments: { body: "PH nested" } }, a: { b: { c: { body: "Deep" } } } },
})

persisted = Post.create!(title: "Hello", body: "Text", published: true, category: "news", rank: 3)
fresh = Post.new(title: "From user", body: "x", published: "1", rank: "7abc")
changed = Post.find(persisted.id).tap { |p| p.title = "Edited" }
invalid = Post.new(title: "").tap { |p| p.errors.add(:title, :blank); p.errors.add(:body, "bad"); p.errors.add(:category, "c") }
objects = { persisted: persisted, fresh: fresh, changed: changed, invalid: invalid, item: Item.new(title: "t", rank: "4x"),
            duck: Duck.new(false), duck_user: Duck.new(true), none: nil }

# Builder fields: PH, AMT, V, TR (through placeholder and label), SV (radio, label value, multiple check box).
objects.each do |oname, obj|
  object_names.each do |on|
    f = begin
      ActionView::Helpers::FormBuilder.new(on, obj, V, {})
    rescue Exception => e # rubocop:disable Lint/RescueException
      show("builder #{oname} #{on.inspect}") { raise e }
      next
    end
    method_names.each do |m|
      k = "#{oname} #{on.inspect} #{m.inspect}"
      show("text_field #{k}") { f.text_field(m) }
      show("text_field ph #{k}") { f.text_field(m, placeholder: true) }
      show("text_field ph sym #{k}") { f.text_field(m, placeholder: :short) }
      show("text_field ph str #{k}") { f.text_field(m, placeholder: "Given") }
      show("text_field value #{k}") { f.text_field(m, value: "v", class: "c") }
      show("email_field ph #{k}") { f.email_field(m, placeholder: true, id: nil) }
      show("number_field #{k}") { f.number_field(m) }
      show("text_area #{k}") { f.text_area(m, size: "3x4") }
      show("text_area ph #{k}") { f.text_area(m, placeholder: true) }
      show("select #{k}") { f.select(m, %w[news blog], include_blank: true) }
      show("label #{k}") { f.label(m) }
      show("label text #{k}") { f.label(m, "Text") }
      show("label block #{k}") { f.label(m) { |b| "#{b.translation}!" } }
      show("label for #{k}") { f.label(m, for: "given") }
      show("check_box #{k}") { f.check_box(m) }
      show("hidden_field #{k}") { f.hidden_field(m) }
    end
    values.each_with_index do |v, i|
      k = "#{oname} #{on.inspect} #{i}"
      show("radio_button #{k}") { f.radio_button(:category, v) }
      show("label value #{k}") { f.label(:category, value: v) }
      show("check_box multiple #{k}") { f.check_box(:category, { multiple: true }, v, nil) }
      show("check_box values #{k}") { f.check_box(:published, {}, v, v) }
    end
  end
end

# Collection helpers call sanitized_value for every item.
values.each_with_index do |v, i|
  item = Struct.new(:id, :name).new(v, "N#{i}")
  f = ActionView::Helpers::FormBuilder.new(:post, persisted, V, {})
  show("collection_radio_buttons #{i}") { f.collection_radio_buttons(:category, [item], :id, :name) }
  show("collection_check_boxes #{i}") { f.collection_check_boxes(:category, [item], :id, :name) }
end

# CB: the hidden field next to a check box, with every option shape and the caller's arguments afterwards.
unchecked = ["0", "", nil, false, :no, 0, ["a", "b"], ["a", { b: 1 }], { k: "v" }, "frozen".freeze, "x".html_safe]
option_shapes = [{}, { disabled: true, form: "f" }, { "name" => "n", "disabled" => true }, HWIA.new(form: "f"),
                 HWIA.new("name" => "custom", "data" => { "a" => 1 }), { include_hidden: false }, { multiple: true },
                 { id: nil, "type" => "x" }, { value: "given" }]
unchecked.each_with_index do |u, i|
  option_shapes.each_with_index do |o, j|
    arg = u.dup rescue u
    opts = o.dup
    show("check_box helper #{i} #{j}") { V.check_box(:post, :published, opts, "yes", arg) }
    show("check_box helper args #{i} #{j}") { [arg, opts] }
    show("check_box builder #{i} #{j}") { ActionView::Helpers::FormBuilder.new(:post, persisted, V, {}).check_box(:published, o.dup, "1", u) }
  end
end
[true, false].each do |remove|
  ActionView::Base.remove_hidden_field_autocomplete = remove
  show("check_box autocomplete #{remove}") { V.check_box(:post, :published, { form: "f" }, "1", "0") }
end

# OS: options_for_select and select with every selected/disabled shape; the caller's argument afterwards.
containers = [%w[news blog], [["News", "news"], ["Blog", :blog]], { "News" => "news", "Blog" => 2 }, [1, 2, nil],
              [["<x>", 1, { class: "o", disabled: true }]], "<option>raw</option>", "<b>".html_safe, [],
              [["A", "a", { "data-x" => 1 }], "b"]]
selecteds = [nil, "news", :news, 2, %w[news blog], ["news"].freeze, { selected: "blog", disabled: "news" },
             { selected: %w[news blog], disabled: ["news", 1] }, { disabled: "blog" }, { "selected" => "news" },
             HWIA.new(selected: "news"), ->(v) { v == "news" }, [{ selected: :blog }], ["news", { disabled: "blog" }],
             Named.new("news"), "news".html_safe, ""]
containers.each_with_index do |c, i|
  selecteds.each_with_index do |s, j|
    arg = s.is_a?(Proc) ? s : s.deep_dup
    show("options_for_select #{i} #{j}") { V.options_for_select(c, arg) }
    show("options_for_select arg #{i} #{j}") { arg.is_a?(Proc) ? :proc : arg }
  end
end
selecteds.each_with_index do |s, j|
  f = ActionView::Helpers::FormBuilder.new(:post, persisted, V, {})
  show("select selected #{j}") { f.select(:category, %w[news blog], selected: s.is_a?(Proc) ? s : s.deep_dup) }
  show("select disabled #{j}") { f.select(:category, %w[news blog], disabled: s.is_a?(Proc) ? s : s.deep_dup) }
end

# TR: the Translator directly, with the caller's object name afterwards.
object_names.each_with_index do |on, i|
  [persisted, Item.new, nil].each_with_index do |obj, j|
    name = on.is_a?(String) && !on.frozen? ? on.dup : on
    show("translator #{i} #{j}") do
      t = ActionView::Helpers::Tags::Translator.new(obj, name, "title", scope: "helpers.label")
      [t.translate, t.send(:object_name)].map { |x| desc(x) }.join(" | ")
    end
    show("translator arg #{i} #{j}") { name }
  end
end

# AMT: content_tag through Tags with each arity and with a block.
ta = ActionView::Helpers::Tags::TextArea.new(:post, :title, V, object: invalid)
tv = ActionView::Helpers::Tags::TextArea.new(:post, :title, V, object: persisted)
[ta, tv].each_with_index do |t, i|
  show("content_tag 1 #{i}") { t.send(:content_tag, "p") }
  show("content_tag 2 #{i}") { t.send(:content_tag, "p", "x") }
  show("content_tag 3 #{i}") { t.send(:content_tag, "p", "x", { class: "c" }) }
  show("content_tag 4 #{i}") { t.send(:content_tag, "p", "<x>", { class: "c" }, false) }
  show("content_tag 5 #{i}") { t.send(:content_tag, "p", "x", {}, true, 1) }
  show("content_tag block #{i}") { t.send(:content_tag, "p", { class: "c" }) { "blk" } }
  show("content_tag block nil #{i}") { t.send(:content_tag, "p", nil) { "blk" } }
  show("content_tag select #{i}") { t.send(:content_tag, "select", "x", { class: "c" }) }
  show("content_tag optgroup #{i}") { t.send(:content_tag, "optgroup", "x") }
  show("content_tag kw #{i}") { t.send(:content_tag, "p", "x", class: "c") }
end
