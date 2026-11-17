# frozen_string_literal: true
# claude-code pass on LBL1: main against the head over I18n backends (Simple, Fallbacks de -> en, Chain, KeyValue, Cache,
# Memoize, i18n-active_record 1.4.1 with Missing). Needs `gem fetch i18n-active_record perpetuity` unpacked in
# ~/workspace/gemsrc. Usage: BUNDLE_GEMFILE=<rails-main>/Gemfile bundle exec ruby lbl1_backends_probe.rb <rails> <backend> <out> <calls>
rails, backend_name, out_path, calls_path = ARGV
%w[activesupport activemodel activerecord actionpack actionview].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
$LOAD_PATH.unshift(File.expand_path("~/workspace/gemsrc/i18n-active_record-1.4.1/lib"))
$LOAD_PATH.unshift(File.expand_path("~/workspace/gemsrc/perpetuity-1.0.1/lib"))
require "active_support"
require "active_support/core_ext"
require "active_record"
require "action_view"
require "perpetuity/rails_model"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title; t.boolean :published }
  create_table(:comments) { |t| t.integer :post_id; t.string :body }
  create_table(:admin_users) { |t| t.string :name }
  create_table(:translations) { |t| t.string :locale; t.string :key; t.text :value; t.text :interpolations; t.boolean :is_proc, default: false }
end
class Post < ActiveRecord::Base
  has_many :comments
  accepts_nested_attributes_for :comments
end
class Comment < ActiveRecord::Base; belongs_to :post; end
module Admin; class User < ActiveRecord::Base; self.table_name = "admin_users"; end; end
class Plain; include ActiveModel::Model; attr_accessor :title, :published, :body, :name; end
class NoModel; attr_accessor :title, :published, :body, :name; end
class PPost; include Perpetuity::RailsModel; attr_accessor :title, :published, :body, :name; end
class NoName; attr_accessor :title, :published, :body, :name; def to_model = self; end

LOG = []
CNT = Hash.new(0)
class CountingKey
  def initialize(s) = @s = s
  def to_s = (CNT[:key_to_s] += 1; @s)
end
DuckName = Struct.new(:i18n_key) do
  def human(*) = "Duck"
  def param_key = "post"
  def singular = "post"
end
class Duck
  include ActiveModel::Model
  attr_accessor :title, :published, :body, :name
  class << self; attr_accessor :key; end
  def self.model_name = DuckName.new(key)
  def self.human_attribute_name(attr, *) = "Human #{attr}"
end

counter = Module.new do
  def translate(locale, key, options = {})
    LOG << "T #{locale} #{key.inspect} scope=#{options[:scope].inspect} default=#{options[:default].inspect}"
    super
  end

  def lookup(locale, key, scope = [], options = {})
    LOG << "L #{locale} #{key.inspect} scope=#{scope.inspect}"
    super
  end
end

def simple_with(*mods)
  Class.new(I18n::Backend::Simple) { mods.each { |m| include m } }.new
end

case backend_name
when "simple" then I18n.backend = simple_with
when "fallbacks"
  I18n.backend = simple_with(I18n::Backend::Fallbacks)
  I18n.fallbacks = I18n::Locale::Fallbacks.new(de: [:de, :en])
  I18n.backend.define_singleton_method(:on_fallback) { |*a| LOG << "on_fallback #{a.inspect}" }
when "chain" then I18n.backend = I18n::Backend::Chain.new(simple_with, simple_with)
when "keyvalue" then I18n.backend = I18n::Backend::KeyValue.new({})
when "cache"
  I18n.backend = simple_with(I18n::Backend::Cache)
  I18n.cache_store = ActiveSupport::Cache::MemoryStore.new
when "memoize" then I18n.backend = simple_with(I18n::Backend::Memoize)
when "ar_missing"
  require "i18n/backend/active_record"
  I18n::Backend::Chain.include(I18n::Backend::ActiveRecord::Missing)
  I18n.backend = I18n::Backend::Chain.new(I18n::Backend::ActiveRecord.new, I18n::Backend::Simple.new)
else abort "backend?"
end
(I18n.backend.is_a?(I18n::Backend::Chain) ? [I18n.backend, *I18n.backend.backends] : [I18n.backend]).each do |b|
  b.singleton_class.prepend(counter)
end
I18n.available_locales = [:en, :de]
I18n.enforce_available_locales = false

PROC_NIL = ->(*, **) { CNT[:proc] += 1; nil }
PROC_STR = ->(*, **) { CNT[:proc] += 1; "From proc" }
LABEL = { post: { title: "Label title" } }
setups = {
  "none" => {},
  "hit" => { helpers: { label: LABEL } },
  "empty" => { helpers: { label: { post: { title: "" } } } },
  "nil" => { helpers: { label: { post: { title: nil } } } },
  "proc_str" => { helpers: { label: { post: { title: PROC_STR } } } },
  "proc_nil" => { helpers: { label: { post: { title: PROC_NIL } } } },
  "proc_nil_all" => { helpers: { label: { post: { title: PROC_NIL, published: PROC_NIL }, comment: { body: PROC_NIL },
    article: { title: PROC_NIL }, admin_user: { name: PROC_NIL }, plain: { title: PROC_NIL }, ppost: { title: PROC_NIL } },
    placeholder: { post: { title: PROC_NIL } } } },
  "symbol_link" => { helpers: { label: { post: { title: :"links.title" } } }, links: { title: "Linked" } },
  "symbol_missing" => { helpers: { label: { post: { title: :"links.nope" } } } },
  "hash" => { helpers: { label: { post: { title: { one: "One" } } } } },
  "ar_attr" => { activerecord: { attributes: { post: { title: "AR title" }, comment: { body: "AR body" } } },
    activemodel: { attributes: { plain: { title: "AM title" } } } },
  "model_key" => { helpers: { label: { comment: { body: "Comment key" }, post: { title: "Post key" },
    "admin/user": { name: "Admin key" } } } },
  "nested_key" => { helpers: { label: { post: { comments: { body: "Nested" } } } } },
  "value_key" => { helpers: { label: { post: { published: { true: "Yes" }, title: { foo_bar: "FB" } } } } },
  "placeholder" => { helpers: { placeholder: { post: { title: "PH" }, article: { title: "PH article" } } } },
  "interp" => { helpers: { label: { post: { title: "Hi %{x}" } } } },
}

def obj(kind)
  case kind
  when :post then Post.new(title: "t")
  when :post_nested then Post.new(title: "t").tap { |p| p.comments.build(body: "b") }
  when :admin then Admin::User.new(name: "n")
  when :plain then Plain.new
  when :nomodel then NoModel.new
  when :ppost then PPost.new
  when :noname then NoName.new
  when :nil then nil
  when Array then Class.new(Duck) { self.key = kind[1]; def self.name = "Duck" }.new
  end
end

V = ActionView::Base.empty
def render(r) = r.is_a?(String) ? "#{r.inspect} #{r.class} #{r.encoding} safe=#{r.html_safe?}" : r.inspect
def show
  render(yield)
rescue Exception => e # rubocop:disable Lint/RescueException
  "#{e.class}: #{e.message.gsub(/0x\h+/, "0x").inspect}"
end

fields = {
  "label" => ->(f, m) { f.label(m) },
  "label_text" => ->(f, m) { f.label(m, "Text") },
  "label_block" => ->(f, m) { f.label(m) { "Blk" } },
  "label_block_t" => ->(f, m) { f.label(m) { |b| b.translation } },
  "label_value_true" => ->(f, m) { f.label(m, value: true) },
  "label_value_str" => ->(f, m) { f.label(m, value: "Foo Bar") },
  "label_opts" => ->(f, m) { f.label(m, class: "c") },
  "text_field_ph" => ->(f, m) { f.text_field(m, placeholder: true) },
  "text_area_ph" => ->(f, m) { f.text_area(m, placeholder: true) },
}

# [name, ->(&blk) { yields a builder }, methods]
forms = []
fb = ->(name, kind) { ->(&b) { b.(ActionView::Helpers::FormBuilder.new(name, obj(kind), V, {})) } }
[[:post, :post], ["post", :post], ["article", :post], ["post[comments_attributes][0]", :post], ["admin_user", :admin],
 ["admin/user", :admin], ["plain", :plain], ["post", :plain], ["post", :nomodel], ["post", :nil], ["ppost", :ppost],
 ["p_post", :ppost], ["post", :noname], ["post", [:duck, :post]], ["post", [:duck, "post"]], ["post", [:duck, nil]],
 ["post", [:duck, CountingKey.new("post")]], ["admin/user", [:duck, :"admin/user"]], ["post", [:duck, :"post.x"]],
 ["post", [:duck, :Post]], ["Post", [:duck, :post]], ["post".b, :post], ["pöst", [:duck, :pöst]],
 ["pöst".encode("ISO-8859-1"), [:duck, :pöst]]].each do |name, kind|
  forms << ["fb(#{name.inspect}, #{kind.inspect.gsub(/0x\h+/, "")})", fb.(name, kind), %i[title published body name]]
end
forms << ["form_with(model:)", ->(&b) { V.form_with(model: Post.new, url: "/x") { |f| b.(f); "" } }, %i[title published]]
forms << ["form_with(model:, scope: :article)", ->(&b) { V.form_with(model: Post.new, scope: :article, url: "/x") { |f| b.(f); "" } }, %i[title]]
forms << ["form_with(model: admin)", ->(&b) { V.form_with(model: Admin::User.new, url: "/x") { |f| b.(f); "" } }, %i[name]]
forms << ["form_with(model: plain)", ->(&b) { V.form_with(model: Plain.new, url: "/x") { |f| b.(f); "" } }, %i[title]]
forms << ["fields_for nested", ->(&b) { V.form_with(model: obj(:post_nested), url: "/x") { |f| f.fields_for(:comments) { |c| b.(c); "" }; "" } }, %i[body]]
forms << ["fields_for :comment", ->(&b) { V.form_with(model: Post.new, url: "/x") { |f| f.fields_for(:comment, Comment.new) { |c| b.(c); "" }; "" } }, %i[body]]
forms << ["fields_for :post", ->(&b) { V.fields_for(:post, Post.new) { |c| b.(c); "" } }, %i[title]]

raise_modes = {
  "plain" => -> { },
  "handler_raise" => -> { I18n.exception_handler = ->(e, *) { raise(e.is_a?(I18n::MissingTranslation) ? e.to_exception : e) } },
  "av_raise" => -> { ActionView::Helpers::TranslationHelper.raise_on_missing_translations = true },
  "am_strict" => -> { ActiveModel::Translation.raise_on_missing_translations = true },
}
default_handler = I18n.exception_handler

out = File.open(out_path, "w")
calls = File.open(calls_path, "w")
out.puts "translator: #{ActionView::Helpers::Tags::Translator.instance_method(:i18n_default).source_location.inspect.sub(rails, "RAILS")}"
locales = backend_name == "fallbacks" ? [:de, :en] : [:en]
setups.each do |sname, data|
  next if backend_name == "keyvalue" && sname.start_with?("proc") # KeyValue stores cannot hold Procs
  I18n.backend.reload! if I18n.backend.respond_to?(:reload!)
  if backend_name == "ar_missing"
    I18n.backend.backends.last.reload!
    I18n.backend.backends.last.store_translations(:en, data)
  elsif backend_name == "chain"
    I18n.backend.backends.each(&:reload!)
    I18n.backend.backends.last.store_translations(:en, data)
  elsif backend_name == "keyvalue"
    I18n.backend = I18n::Backend::KeyValue.new({}).tap { |b| b.singleton_class.prepend(counter) }
    I18n.backend.store_translations(:en, data)
  else
    I18n.backend.store_translations(:en, data)
  end
  I18n.cache_store&.clear if backend_name == "cache"
  locales.each do |locale|
    raise_modes.each do |rname, setup_raise|
      I18n.exception_handler = default_handler
      ActionView::Helpers::TranslationHelper.raise_on_missing_translations = false
      ActiveModel::Translation.raise_on_missing_translations = false
      setup_raise.()
      I18n.with_locale(locale) do
        forms.each do |fname, form, methods|
          methods.each do |m|
            fields.each do |field_name, field|
              LOG.clear; CNT.clear
              I18n::Backend::ActiveRecord::Translation.delete_all if backend_name == "ar_missing"
              r = nil
              form.() { |f| r = show { field.(f, m) } }
              id = "#{sname} #{locale} #{rname} #{fname} #{m} #{field_name}"
              out.puts "#{id} => #{r}  proc=#{CNT[:proc]} key_to_s=#{CNT[:key_to_s]}"
              stubs = backend_name == "ar_missing" ? I18n::Backend::ActiveRecord::Translation.order(:key).pluck(:locale, :key) : []
              calls.puts "#{id} => T=#{LOG.count { _1.start_with?("T ") }} L=#{LOG.count { _1.start_with?("L ") }} fb=#{LOG.count { _1.start_with?("on_fallback") }} stubs=#{stubs.inspect}"
            end
          end
        end
        # Translator directly, as gems call it
        [["post", :post], ["article", :post], [:post, :post]].each do |name, kind|
          LOG.clear; CNT.clear
          r = show { ActionView::Helpers::Tags::Translator.new(obj(kind), name, "title", scope: "helpers.label").translate }
          id = "#{sname} #{locale} #{rname} Translator(#{name.inspect}) title"
          out.puts "#{id} => #{r}"
          calls.puts "#{id} => T=#{LOG.count { _1.start_with?("T ") }} L=#{LOG.count { _1.start_with?("L ") }}"
        end
      end
    end
  end
end
I18n.exception_handler = default_handler
out.puts "done"
