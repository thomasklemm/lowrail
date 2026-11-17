# frozen_string_literal: true
# claude-code review probe for FH2: ruby -rbundler/setup fh2_review_probe.rb RAILS_CHECKOUT > out.txt; diff main against head.
rails = ARGV.fetch(0)
%w[activesupport actionview actionpack activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_support/core_ext"
require "active_record"
require "action_controller"
require "action_view"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title; t.text :body; t.boolean :published; t.string :category; t.integer :rank; t.string :tags }
  create_table(:comments) { |t| t.integer :post_id; t.string :body; t.string :kind }
end
class Post < ActiveRecord::Base
  has_many :comments
  accepts_nested_attributes_for :comments
end
class Comment < ActiveRecord::Base; belongs_to :post; end
module Admin; class Post < ::Post; end; end
class Item
  include ActiveModel::Model
  include ActiveModel::Attributes
  attribute :title, :string
  attribute :category, :string
  attribute :rank, :integer
end

LOG = []
class Duck
  def initialize(from_user) = @from_user = from_user
  def respond_to_missing?(name, priv = false) = (LOG << "respond_to?(#{name})"; true)
  def method_missing(name, *)
    LOG << "call #{name}"
    return ActiveModel::Name.new(Post) if name == :model_name
    name.end_with?("_came_from_user?") ? @from_user : "#{name}-v"
  end
end
# A record that answers *_before_type_cast but not *_came_from_user?, and one with neither.
class BtcOnly
  def title = (LOG << "title"; "T")
  def title_before_type_cast = (LOG << "title_btc"; "T btc")
  def category = "news"
  def to_model = self
  def model_name = ActiveModel::Name.new(Post)
end
class Plain
  def title = (LOG << "title"; "plain")
  def category = "blog"
end
class LogStr < String
  def +(o) = (LOG << "LogStr#+"; super)
  def gsub(*, &) = (LOG << "LogStr#gsub"; super)
  def match?(*) = (LOG << "LogStr#match?"; super)
end
class NameObj
  def initialize(s) = @s = s
  def to_s = (LOG << "NameObj#to_s"; @s)
  def inspect = "NameObj(#{@s.inspect})"
end
# value.to_s results whose gsub does not return a fresh plain String
class SelfGsub < String
  def gsub(*, &) = (LOG << "SelfGsub#gsub"; replace(super); self)
end
class FrozenGsub < String
  def gsub(*, &) = (LOG << "FrozenGsub#gsub"; super.freeze)
end
class SubGsub < String
  def gsub(*, &) = (LOG << "SubGsub#gsub"; SubGsub.new(super))
  def downcase(*) = (LOG << "SubGsub#downcase"; super)
  def downcase!(*) = (LOG << "SubGsub#downcase!"; super)
  def gsub!(*, &) = (LOG << "SubGsub#gsub!"; super)
end
class ToS
  def initialize(s) = @s = s
  def to_s = @s
  def inspect = "ToS(#{@s.class})"
end
class MyHash < Hash
  def [](k) = (LOG << "MyHash#[](#{k.inspect})"; super)
end

V = ActionView::Base.empty
HWIA = ActiveSupport::HashWithIndifferentAccess

def desc(r)
  case r
  when String then "#{r.inspect} #{r.class} #{r.encoding} frozen=#{r.frozen?} safe=#{r.html_safe?}"
  when Array then "[" + r.map { |x| desc(x) }.join(", ") + "]"
  else "#{r.inspect} #{r.class}"
  end
end

def show(label)
  LOG.clear
  out = begin
    desc(yield)
  rescue Exception => e # rubocop:disable Lint/RescueException
    "#{e.class}: #{e.message[0, 200]}"
  end
  puts "#{label}\t#{out}\t#{LOG.inspect}".gsub(/0x\h+/, "0x")
end

def translations(on)
  I18n.backend.reload!
  return unless on
  I18n.backend.store_translations(:en,
    helpers: {
      label: { post: { title: "Label T", category: { news: "News L", "a_b" => "AB L" }, comments: { body: "Nested B" } },
               comment: { body: "Comment B" }, "admin/post": { title: "Admin T" }, item: { title: "Item T" } },
      placeholder: { post: { title: "PH T", body: "PH B", short: "x", comments: { body: "PH nested" } } },
    },
    activerecord: { attributes: { post: { title: "AR Title", body: "AR Body" }, comment: { body: "AR Comment" } } },
    activemodel: { attributes: { item: { title: "AM Title" } } })
end

persisted = Post.create!(title: "Hello", body: "Text", published: true, category: "news", rank: 3)
persisted.comments.create!(body: "c1")
persisted.comments.create!(body: "c2")
fresh = Post.new(title: "From user", body: "x", published: "1", rank: "7abc", category: "News Item")
changed = Post.find(persisted.id).tap { |p| p.title = "Edited"; p.rank = "9x" }
invalid = Post.new(title: "").tap { |p| p.errors.add(:title, :blank); p.errors.add(:rank, "bad") }
objects = { persisted: persisted, fresh: fresh, changed: changed, invalid: invalid, admin: Admin::Post.new(title: "a"),
            item: Item.new(title: "t", rank: "4x"), duck: Duck.new(false), duck_user: Duck.new(true), btc: BtcOnly.new,
            plain: Plain.new, none: nil }
object_names = [:post, "post", "post".html_safe, -"post", LogStr.new("post"), "post[comments_attributes][0]",
                "post[comments_attributes][1][x_attributes][2]", "post[]", "admin/post", "", "pöst", "post\xFF".b,
                "post\xFF".dup.force_encoding("UTF-8"), "post".encode("UTF-16LE"), NameObj.new("post"), nil, 7]
option_sets = { none: {}, hwia: HWIA.new(class: "c"), hwia_ph: HWIA.new(placeholder: true), sub: MyHash[class: "c"],
                index: { index: 3 }, index_nil: { index: nil }, ns: { namespace: "ns" }, id_nil: { id: nil },
                ph_true: { placeholder: true }, ph_sym: { placeholder: :short }, ph_str: { placeholder: "Given" },
                value: { value: "v" }, frozen: { class: "c" }.freeze }

[false, true].each do |tr|
  translations(tr)
  objects.each do |oname, obj|
    object_names.each do |on|
      f = begin
        ActionView::Helpers::FormBuilder.new(on, obj, V, {})
      rescue => e
        show("builder #{oname} #{on.inspect}") { raise e }
        next
      end
      [:title, "title", :rank, :title?, "body"].each do |m|
        option_sets.each do |sname, opts|
          k = "t#{tr ? 1 : 0} #{oname} #{on.inspect} #{m.inspect} #{sname}"
          o = -> { opts.frozen? ? opts : opts.dup }
          show("text_field #{k}") { f.text_field(m, o.call) }
          show("text_area #{k}") { f.text_area(m, o.call) }
          show("label #{k}") { f.label(m, o.call) }
          next unless %i[none hwia index ns ph_true value].include?(sname)
          show("password_field #{k}") { f.password_field(m, o.call) }
          show("email_field #{k}") { f.email_field(m, o.call) }
          show("search_field #{k}") { f.search_field(m, o.call) }
          show("number_field #{k}") { f.number_field(m, o.call) }
          show("date_field #{k}") { f.date_field(m, o.call) }
          show("color_field #{k}") { f.color_field(m, o.call) }
          show("hidden_field #{k}") { f.hidden_field(m, o.call) }
          show("textarea #{k}") { f.textarea(m, o.call) }
          show("select #{k}") { f.select(m, %w[news blog], { include_blank: true }, o.call) }
          show("select block #{k}") { f.select(m, nil, {}, o.call) { "<option>x</option>".html_safe } }
          show("label text #{k}") { f.label(m, "Text", o.call) }
          show("label block #{k}") { f.label(m, o.call) { |b| "#{b.translation}!" } }
          show("check_box #{k}") { f.check_box(m, o.call) }
          show("radio_button #{k}") { f.radio_button(m, "News Item.x", o.call) }
          show("button #{k}") { f.button("Go", o.call) }
        end
      end
      %w[news a\ b Ä.x].each_with_index do |v, i|
        k = "t#{tr ? 1 : 0} #{oname} #{on.inspect} #{i}"
        show("label value #{k}") { f.label(:category, value: v) }
        show("label value text #{k}") { f.label(:category, "X", value: v) }
        show("collection_radio_buttons #{k}") { f.collection_radio_buttons(:category, [[v, "N"], ["b", "B"]], :first, :last) }
        show("collection_check_boxes #{k}") { f.collection_check_boxes(:category, [[v, "N"]], :first, :last) { |b| b.label + b.check_box } }
        show("collection_select #{k}") { f.collection_select(:category, [[v, "N"]], :first, :last) }
      end
    end
  end

  # fields_for, nested attributes, index and namespace through form_with
  [persisted, fresh].each_with_index do |post, i|
    k = "t#{tr ? 1 : 0} #{i}"
    show("fields_for nested #{k}") do
      V.fields_for(:post, post) do |f|
        f.fields_for(:comments) { |c| c.label(:body) + c.text_field(:body, placeholder: true) + c.radio_button(:kind, "A b") + c.label(:kind, value: "A b") }
      end
    end
    show("fields_for child_index #{k}") do
      V.fields_for(:post, post) { |f| f.fields_for(:comments, Comment.new, child_index: "NEW") { |c| c.label(:body) + c.text_area(:body, placeholder: true) } }
    end
    show("fields_for index #{k}") { V.fields_for(:post, post, index: 5) { |f| f.label(:title) + f.text_field(:title) + f.radio_button(:category, "x y") } }
    show("form_with ns #{k}") do
      V.form_with(model: post, url: "/p", namespace: "nsx", scope: :post) { |f| f.label(:title) + f.text_field(:title, placeholder: true) + f.text_area(:body) + f.select(:category, %w[news]) + f.radio_button(:category, "news") }
    end
    show("form_with index #{k}") { V.form_with(model: post, url: "/p", index: 2) { |f| f.label(:title) + f.text_field(:title) } }
    show("form_with no model #{k}") { V.form_with(url: "/p") { |f| f.label(:title) + f.text_field(:title, placeholder: true) + f.text_area(:body) } }
    show("form_for sym #{k}") { V.form_for(:post, url: "/p") { |f| f.label(:title) + f.text_field(:title, placeholder: true) } }
  end
end

translations(true)

# SV: value objects; the caller's value afterwards
sv_values = -> { ["news", "News Item.x", "", "İstanbul ǅ", :news, nil, 1, 2.5, "Safe <V> x".html_safe, -"frozen V",
                  SelfGsub.new("Self G.x"), FrozenGsub.new("Frozen G.x"), SubGsub.new("Sub G.x"), ToS.new(SelfGsub.new("ToS Self.x")),
                  ToS.new(FrozenGsub.new("ToS Frozen")), ToS.new(SubGsub.new("ToS Sub")), ToS.new(-"ToS frozen"),
                  "été".encode("ISO-8859-1"), "w v".encode("UTF-16LE"), "b\xFF v".b, "bad\xFF".dup.force_encoding("UTF-8")] }
tag = ActionView::Helpers::Tags::Base.new(:post, :title, V, object: persisted)
sv_values.call.each_with_index do |v, i|
  show("sanitized_value #{i} #{v.inspect}") { [tag.send(:sanitized_value, v), v] }
  f = ActionView::Helpers::FormBuilder.new(:post, persisted, V, {})
  show("radio sv #{i}") { [f.radio_button(:category, v), v] }
  show("label sv #{i}") { [f.label(:category, value: v), v] }
  show("check_box multiple sv #{i}") { [f.check_box(:category, { multiple: true }, v, nil), v] }
  show("collection_radio sv #{i}") { [f.collection_radio_buttons(:category, [[v, "N"]], :first, :last), v] }
end

# V: method name objects whose to_s is a String subclass with its own +
[persisted, fresh, Duck.new(false), Duck.new(true), BtcOnly.new].each_with_index do |obj, i|
  [ToS.new(LogStr.new("title")), LogStr.new("title"), NameObj.new("title"), "title".encode("UTF-16LE"), "títle".b].each_with_index do |m, j|
    f = ActionView::Helpers::FormBuilder.new(:post, obj, V, {})
    show("v text_field #{i} #{j}") { f.text_field(m) }
    show("v text_area #{i} #{j}") { f.text_area(m) }
    show("v direct #{i} #{j}") { ActionView::Helpers::Tags::TextField.new(:post, m, V, object: obj).send(:value_before_type_cast) }
  end
end

# TR: Translator directly with each object name; the caller's name afterwards
[*object_names, LogStr.new("post[comments_attributes][0]"), "post[comments_attributes][0]".html_safe, :"post[comments_attributes][0]",
 -"post[comments_attributes][0]"].each_with_index do |on, i|
  [persisted, Item.new, nil].each_with_index do |obj, j|
    name = on.is_a?(String) && !on.frozen? ? on.dup : on
    show("translator #{i} #{j} #{on.inspect}") do
      t = ActionView::Helpers::Tags::Translator.new(obj, name, "title", scope: "helpers.label")
      [t.translate, name]
    end
  end
end

# PH: Placeholderable#initialize with keywords, blocks and subclasses
class MyField < ActionView::Helpers::Tags::TextField
  def initialize(object_name, method_name, template_object, options = {}, &blk)
    LOG << "MyField block=#{!blk.nil?}"
    super
  end
end
show("ph params") { ActionView::Helpers::Tags::Placeholderable.instance_method(:initialize).arity }
show("ph pos") { ActionView::Helpers::Tags::TextField.new(:post, :title, V, { placeholder: true, object: persisted }).render }
show("ph kw") { ActionView::Helpers::Tags::TextField.new(:post, :title, V, placeholder: true, object: persisted).render }
show("ph kw ta") { ActionView::Helpers::Tags::TextArea.new(:post, :title, V, placeholder: :short, object: persisted).render }
show("ph 3 args") { ActionView::Helpers::Tags::TextField.new(:post, :title, V).render }
show("ph 2 args") { ActionView::Helpers::Tags::TextField.new(:post, :title).render }
show("ph 5 args") { ActionView::Helpers::Tags::TextField.new(:post, :title, V, {}, 1).render }
show("ph block") { MyField.new(:post, :title, V, { placeholder: true, object: persisted }) { }.render }
show("ph hwia") { ActionView::Helpers::Tags::TextField.new(:post, :title, V, HWIA.new(placeholder: true, object: persisted)).render }

# AMT: arities, keywords, blocks, select markup
ta = ActionView::Helpers::Tags::TextArea.new(:post, :title, V, object: invalid)
[["p"], ["p", "x"], ["p", "x", { class: "c" }], ["p", "<x>", { class: "c" }, false], ["p", "x", {}, true, 1],
 ["p", { class: "c" }], ["select", "x"], ["option", "x", nil, false]].each_with_index do |args, i|
  show("amt #{i}") { ta.send(:content_tag, *args) }
  show("amt block #{i}") { ta.send(:content_tag, *args) { "blk" } }
end
show("amt kw") { ta.send(:content_tag, "p", "x", class: "c") }
show("amt kw only") { ta.send(:content_tag, "p", class: "c") { "b" } }

# AMT: an override of TagHelper#content_tag prepended below ActiveModelInstanceTag
module CountArgs
  def content_tag(name, *args, &)
    LOG << "content_tag #{name} args=#{args.size} last=#{args.last.class}"
    super
  end
end
ActionView::Helpers::TagHelper.prepend(CountArgs)
f = ActionView::Helpers::FormBuilder.new(:post, invalid, V, {})
show("prepend text_area") { f.text_area(:title) }
show("prepend label") { f.label(:title) }
show("prepend label block") { f.label(:title) { "x" } }
show("prepend select") { f.select(:category, %w[a]) }
