# frozen_string_literal: true
# Differential probe for LBL1: f.label, placeholders and Translator outputs (value, class, encoding, frozen,
# html_safe, or the exception) over translation setups, backends, object names and models. Lookups per case go to
# stderr, since dropping the duplicate lookup is the change. Run once per Rails checkout and diff stdout:
#   bundle exec ruby lbl1_probe.rb <rails> > out.txt 2> lookups.txt   (FB=1: Fallbacks backend, de -> en)
rails = ARGV.fetch(0)
%w[activesupport actionview actionpack activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_support/core_ext"
require "active_record"
require "action_view"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title; t.boolean :published }
  create_table(:comments) { |t| t.integer :post_id; t.string :body }
  create_table(:admin_users) { |t| t.string :name }
end
class Post < ActiveRecord::Base
  has_many :comments
  accepts_nested_attributes_for :comments
end
class Comment < ActiveRecord::Base; belongs_to :post; end
module Admin; class User < ActiveRecord::Base; self.table_name = "admin_users"; end; end
class Plain; include ActiveModel::Model; attr_accessor :title, :name, :body; end
class NoModel; attr_accessor :title; end
# model_name ducks: a String i18n_key (as some gems return), an i18n_key with a counting to_s, nil.
NameDuck = Struct.new(:i18n_key, :human) do
  def param_key = "post"
  def singular = "post"
end
class Counting
  def initialize(s) = @s = s
  def to_s = (CALLS[:to_s] += 1; @s)
end
CALLS = Hash.new(0)
class Ducky
  include ActiveModel::Model
  attr_accessor :title
  class << self; attr_accessor :key; end
  def self.model_name = NameDuck.new(key, "Ducky")
  def self.human_attribute_name(attr, *) = "Human #{attr}"
end
class SubString < String; end

V = ActionView::Base.empty
def desc(r) = r.is_a?(String) ? "#{r.inspect} #{r.class} #{r.encoding} frozen=#{r.frozen?} safe=#{r.html_safe?}" : r.inspect
def show
  desc(yield)
rescue Exception => e # rubocop:disable Lint/RescueException
  "#{e.class}: #{e.message[0, 160].gsub(/0x\h+/, "0x")}"
end
LOOKUPS = Hash.new(0)
lookup_counter = Module.new { def lookup(*) = (LOOKUPS[:n] += 1; super) }
I18n::Backend::Simple.prepend(lookup_counter)

PROC = ->(key, **) { CALLS[:proc] += 1; nil }
setups = {
  "none" => {},
  "label hit" => { helpers: { label: { post: { title: "Label T" } } } },
  "label empty" => { helpers: { label: { post: { title: "" } } } },
  "label proc" => { helpers: { label: { post: { title: ->(k, **) { "Proc #{k}" } } } } },
  "label proc nil" => { helpers: { label: { post: { title: PROC } } } },
  "label symbol link" => { helpers: { label: { post: { title: :"helpers.label.post.other", other: "Linked" } } } },
  "label hash" => { helpers: { label: { post: { title: { a: "A" } } } } },
  "attributes" => { activerecord: { attributes: { post: { title: "AR T" }, "admin/user": { name: "AdminName" } } },
                    activemodel: { attributes: { plain: { title: "AM T" } } } },
  "nested" => { helpers: { label: { post: { comments: { body: "Nested B" } }, comment: { body: "Comment B" },
                                    "admin/user": { name: "NS" }, admin_user: { name: "Under" } } } },
  "values" => { helpers: { label: { post: { published: { "true": "Yes pub", a_b: "AB" } } } } },
  "placeholder" => { helpers: { placeholder: { post: { title: "PH T", body: { short: "Short" } } } } },
  "under key" => { helpers: { label: { article: { title: "Article T" } } } },
}
object_names = [:post, "post", "post".html_safe, "post".freeze, SubString.new("post"), "post[comments_attributes][0]",
                :article, "admin_user", "admin/user", "post[]", "", "post".encode("UTF-16LE"),
                "post\xFF".dup.force_encoding("UTF-8"), "pöst", :plain, :ducky]
methods = [:title, "title", :body, :name, :published, :other]

setups.each do |sname, data|
  I18n.backend = (ENV["FB"] == "1") ? Class.new(I18n::Backend::Simple) { include I18n::Backend::Fallbacks }.new : I18n::Backend::Simple.new
  if (ENV["FB"] == "1")
    I18n.available_locales = [:en, :de]
    I18n.fallbacks = [:de, :en]
    I18n.locale = :de
  end
  I18n.backend.store_translations(:en, data)
  I18n.backend.store_translations(:de, helpers: { label: { post: { body: "DE body" } } })
  [false, true].each do |raise_missing|
    ActionView::Helpers::TranslationHelper.raise_on_missing_translations = raise_missing
    post = Post.new(title: "x")
    post.comments.build
    models = { post: post, comment: post.comments.first, admin: Admin::User.new, plain: Plain.new, nomodel: NoModel.new,
               none: nil, duck_sym: [Ducky, :post], duck_str: [Ducky, "post"], duck_count: [Ducky, Counting.new("post")],
               duck_nil: [Ducky, nil], duck_ns: [Ducky, :"admin/user"] }
    models.each do |mname, m|
      obj = if m.is_a?(Array)
        m[0].key = m[1]
        m[0].new
      else
        m
      end
      object_names.each do |on|
        f = begin
          ActionView::Helpers::FormBuilder.new(on, obj, V, {})
        rescue Exception => e # rubocop:disable Lint/RescueException
          puts "#{sname} raise=#{raise_missing} #{mname} #{on.inspect} builder\t#{e.class}"
          next
        end
        methods.each do |meth|
          LOOKUPS.clear
          CALLS.clear
          out = [
            show { f.label(meth) }, show { f.label(meth, value: true) }, show { f.label(meth, value: "a b") },
            show { f.label(meth, "Text") }, show { f.label(meth) { |b| b.translation } },
            show { f.text_field(meth, placeholder: true) }, show { f.text_area(meth, placeholder: :short) },
            show { ActionView::Helpers::Tags::Translator.new(obj, on, meth.to_s, scope: "helpers.label").translate },
          ]
          puts "#{sname} raise=#{raise_missing} #{mname} #{on.inspect} #{meth.inspect}\t#{out.join(" | ")}\tto_s=#{CALLS[:to_s]}"
          $stderr.puts "#{sname} raise=#{raise_missing} #{mname} #{on.inspect} #{meth.inspect} lookups=#{LOOKUPS[:n]} proc=#{CALLS[:proc]}"
        end
      end
    end
  end
end
