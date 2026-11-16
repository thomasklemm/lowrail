# frozen_string_literal: true
# f.label outputs over translation setups, object names and options; diff main vs PATCH=L.
rails = ARGV.fetch(0)
%w[activesupport actionview actionpack activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"; require "active_support/core_ext"; require "active_model"; require "action_view"
gem "sqlite3", "2.10.2"; require "active_record"
require_relative "form_stack_patches"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title; t.boolean :published }
  create_table(:comments) { |t| t.integer :post_id; t.string :body }
  create_table(:admin_users) { |t| t.string :name }
end
class Post < ActiveRecord::Base; has_many :comments; accepts_nested_attributes_for :comments; end
class Comment < ActiveRecord::Base; belongs_to :post; end
module Admin; class User < ActiveRecord::Base; self.table_name = "admin_users"; end; end
class Plain; include ActiveModel::Model; attr_accessor :title; end
class NoModel; attr_accessor :title; end
V = ActionView::Base.empty
def show(&b) = (b.call.inspect rescue "#{$!.class}: #{$!.message}")
COUNT = Hash.new(0)
I18n::Backend::Simple.prepend(Module.new { def lookup(*a) = (COUNT[:n] += 1; super) })
setups = {
  "none" => {},
  "helpers.label hit" => { helpers: { label: { post: { title: "Label T" } } } },
  "helpers.label empty" => { helpers: { label: { post: { title: "" } } } },
  "helpers.label proc" => { helpers: { label: { post: { title: ->(k, o) { "Proc #{k}" } } } } },
  "helpers.label symbol link" => { helpers: { label: { post: { title: :"helpers.label.post.other" , other: "Linked" } } } },
  "attributes" => { activerecord: { attributes: { post: { title: "AR T" }, "admin/user": { name: "AdminName" } } } },
  "nested helpers" => { helpers: { label: { post: { comments: { body: "Nested B" } }, comment: { body: "Comment B" }, "admin/user": { name: "NS" }, admin_user: { name: "Under" } } } },
  "values" => { helpers: { label: { post: { published: { "true": "Yes pub" } } } } },
}
setups.each do |name, data|
  I18n.backend = ENV["FB"] ? Class.new(I18n::Backend::Simple) { include I18n::Backend::Fallbacks }.new : I18n::Backend::Simple.new
  I18n.fallbacks = [:de, :en] if ENV["FB"]; I18n.available_locales = [:en, :de] if ENV["FB"]
  I18n.backend.store_translations(:en, data); I18n.backend.store_translations(:de, { helpers: { label: { post: { body: "DE body" } } } })
  I18n.locale = ENV["FB"] ? :de : :en
  [false, true].each do |raise_missing|
    ActionView::Helpers::TranslationHelper.raise_on_missing_translations = raise_missing if ActionView::Helpers::TranslationHelper.respond_to?(:raise_on_missing_translations=)
    post = Post.new(title: "x"); post.comments.build
    forms = {
      "post" => ActionView::Helpers::FormBuilder.new(:post, post, V, {}),
      "post str" => ActionView::Helpers::FormBuilder.new("post", post, V, {}),
      "as article" => ActionView::Helpers::FormBuilder.new(:article, post, V, {}),
      "nested" => ActionView::Helpers::FormBuilder.new("post[comments_attributes][0]", post.comments.first, V, {}),
      "admin" => ActionView::Helpers::FormBuilder.new(:admin_user, Admin::User.new, V, {}),
      "admin slash" => ActionView::Helpers::FormBuilder.new("admin/user", Admin::User.new, V, {}),
      "plain" => ActionView::Helpers::FormBuilder.new(:plain, Plain.new, V, {}),
      "nomodel" => ActionView::Helpers::FormBuilder.new(:post, NoModel.new, V, {}),
      "nil obj" => ActionView::Helpers::FormBuilder.new(:post, nil, V, {}),
    }
    forms.each do |fname, f|
      %i[title body name published other].each do |m|
        COUNT[:n] = 0
        out = [show { f.label(m) }, show { f.label(m, value: true) }, show { f.label(m, value: "a b") }, show { f.label(m, "Text") }, show { f.label(m) { |b| b.translation } }]
        puts "#{name} raise=#{raise_missing} #{fname} #{m}: #{out.join(' | ')}"
        $stderr.puts "#{name} #{fname} #{m} lookups=#{COUNT[:n]}"
      end
    end
  end
end
