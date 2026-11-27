# Every claim of the default_order upgrade-guide section and PR body, run on Active Record 8.1.4.1
# (AR_VERSION) or a Rails checkout (RAILS_PATH). SQLite in memory.
require "bundler/inline"
gemfile(true, quiet: true) do
  source "https://rubygems.org"
  if (path = ENV["RAILS_PATH"])
    %w[activesupport activemodel activerecord].each { gem _1, path: "#{path}/#{_1}" }
  else
    gem "activerecord", ENV.fetch("AR_VERSION", "8.1.4.1")
  end
  gem "sqlite3"
end
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.string :title; t.integer :position; t.boolean :published, default: true }
  create_table(:licenses) { |t| t.string :name; t.boolean :default, default: false; t.boolean :enabled, default: true }
  create_table(:pools) { |t| t.string :name; t.integer :size; t.datetime :updated_at }
  create_table(:items) { |t| t.string :default_order; t.integer :default_order_id; t.integer :post_id }
  create_table(:comments) { |t| t.integer :post_id; t.integer :position }
end
puts "Active Record #{ActiveRecord.version}"

def run(label)
  r = yield
  puts "#{label} => #{r.inspect}"
rescue Exception => e
  puts "#{label} => #{e.class}: #{e.message}"
end

puts "\n## 1. scope :default_order"
run("class ScopePost < AR::Base; scope :default_order, ...; end") do
  Class.new(ActiveRecord::Base) do
    self.table_name = "posts"
    def self.name = "Post"
    scope :default_order, -> { order(:position) }
  end
  "defined"
end

puts "\n## Mechanism"
run("ActiveRecord::Base.respond_to?(:default_order)") { ActiveRecord::Base.respond_to?(:default_order) }
run("Object.respond_to?(:default_order, true)") { Object.respond_to?(:default_order, true) }
run("ActiveRecord::Base.method(:default_order).owner") { ActiveRecord::Base.method(:default_order).owner }
run("ActiveRecord::Querying::QUERYING_METHODS.include?(:default_order)") { ActiveRecord::Querying::QUERYING_METHODS.include?(:default_order) }
run("ActiveRecord::Relation.method_defined?(:default_order)") { ActiveRecord::Relation.method_defined?(:default_order) }
run("ActiveRecord::Relation.instance_method(:default_order).owner") { ActiveRecord::Relation.instance_method(:default_order).owner }

class Post < ActiveRecord::Base
  def self.default_order = order(:position)
end
class Comment < ActiveRecord::Base; end
run("Comment.send(:dangerous_class_method?, :default_order) (plain model)") { Comment.send(:dangerous_class_method?, :default_order) }
run("Post.method(:default_order).owner (def self.default_order)") { Post.method(:default_order).owner }
run("Post.where(nil).method(:default_order).owner") { Post.where(nil).method(:default_order).owner }

Post.create!(title: "b", position: 2); Post.create!(title: "a", position: 1); Post.create!(title: "c", position: 3, published: false)

puts "\n## 2. def self.default_order on the model"
run("Post.default_order.pluck(:title)") { Post.default_order.pluck(:title) }
run("Post.default_order.to_sql") { Post.default_order.to_sql }

puts "\n## 3. on a relation"
run("Post.where(published: true).default_order.pluck(:title)") { Post.where(published: true).default_order.pluck(:title) }
run("Post.all.default_order.pluck(:title)") { Post.all.default_order.pluck(:title) }

puts "\n## 4. with arguments"
class ArgPost < ActiveRecord::Base
  self.table_name = "posts"
  def self.default_order(column) = order(column => :desc)
end
run("ArgPost.default_order(:position).pluck(:title)") { ArgPost.default_order(:position).pluck(:title) }
run("ArgPost.where(published: true).default_order(:position).pluck(:title)") { ArgPost.where(published: true).default_order(:position).pluck(:title) }
run("ArgPost.where(published: true).default_order(:position).to_sql") { ArgPost.where(published: true).default_order(:position).to_sql }
run("ArgPost.where(published: true).default_order(:position).order(:title).pluck(:title)") { ArgPost.where(published: true).default_order(:position).order(:title).pluck(:title) }

# codidact/qpixel License.default_order(category = nil, user_default = nil), called as
# License.enabled.default_order(category, user_default) and License.enabled.default_order
class License < ActiveRecord::Base
  scope :enabled, -> { where(enabled: true) }
  def self.default_order(category = nil, user_default = nil)
    if category.present? && user_default.present?
      License.all.order(Arel.sql(sanitize_sql_array(["name = ? DESC", user_default])))
             .order(Arel.sql(sanitize_sql_array(["id = ? DESC", category.license_id])))
             .order(default: :desc)
    elsif user_default.present?
      License.all.order(Arel.sql(sanitize_sql_array(["name = ? DESC", user_default])))
             .order(default: :desc)
    elsif category.present?
      License.all.order(Arel.sql(sanitize_sql_array(["id = ? DESC", category.license_id])))
             .order(default: :desc)
    else
      License.all.order(default: :desc)
    end.order(name: :asc)
  end
end
Category = Struct.new(:license_id)
License.create!(name: "CC BY-SA"); License.create!(name: "MIT", default: true); License.create!(name: "Apache")
cat = Category.new(3)
run("License.default_order.pluck(:name)") { License.default_order.pluck(:name) }
run("License.enabled.default_order.pluck(:name)") { License.enabled.default_order.pluck(:name) }
run("License.enabled.default_order(nil, 'CC BY-SA').pluck(:name)") { License.enabled.default_order(nil, "CC BY-SA").pluck(:name) }
run("License.enabled.default_order(nil, 'CC BY-SA').to_sql") { License.enabled.default_order(nil, "CC BY-SA").to_sql }
run("License.enabled.default_order(cat, 'CC BY-SA').pluck(:name)") { License.enabled.default_order(cat, "CC BY-SA").pluck(:name) }
run("License.enabled.default_order(cat, nil).pluck(:name)") { License.enabled.default_order(cat, nil).pluck(:name) }

puts "\n## 5. other shapes"
class SingletonPost < ActiveRecord::Base
  self.table_name = "posts"
  class << self
    def default_order = order(:position)
  end
end
run("class << self: SingletonPost.default_order.pluck(:title)") { SingletonPost.default_order.pluck(:title) }
run("class << self: SingletonPost.where(published: true).default_order.pluck(:title)") { SingletonPost.where(published: true).default_order.pluck(:title) }

# danbooru: ApplicationRecord extends Searchable (default_order, apply_default_order); Pool extends SearchMethods
# (default_order, search), pool.rb L83 `q.order(Arel.sql(...)).default_order`, else `q.apply_default_order(params)`.
module Searchable
  extend ActiveSupport::Concern
  def apply_default_order(params)
    params[:order] == "custom" ? order(:id) : default_order
  end
  def default_order = order(id: :desc)
end
class ApplicationRecord < ActiveRecord::Base
  self.abstract_class = true
  extend Searchable
end
class Pool < ApplicationRecord
  module SearchMethods
    def default_order = order(updated_at: :desc)
    def search(params)
      q = where(nil)
      case params[:order]
      when "name" then q = q.order("pools.name")
      when "post_count" then q = q.order(Arel.sql("size desc")).default_order
      else q = q.apply_default_order(params)
      end
      q
    end
  end
  extend SearchMethods
end
Pool.create!(name: "x", size: 1, updated_at: Time.utc(2026, 1, 2)); Pool.create!(name: "y", size: 5, updated_at: Time.utc(2026, 1, 1))
run("Pool.method(:default_order).owner") { Pool.method(:default_order).owner }
run("Pool.default_order.pluck(:name)") { Pool.default_order.pluck(:name) }
run("Pool.search(order: 'post_count').pluck(:name)") { Pool.search(order: "post_count").pluck(:name) }
run("Pool.search(order: 'post_count').to_sql") { Pool.search(order: "post_count").to_sql }
run("Pool.search({}).pluck(:name) (apply_default_order on relation)") { Pool.search({}).pluck(:name) }
run("Pool.search({}).to_sql") { Pool.search({}).to_sql }
run("Pool.where(nil).default_order.pluck(:name)") { Pool.where(nil).default_order.pluck(:name) }

class Item < ActiveRecord::Base; end
run("Item attribute default_order: Item.create!(default_order: 'x').default_order") { Item.create!(default_order: "x").default_order }
run("Item.where(default_order: 'x').count") { Item.where(default_order: "x").count }
class AssocItem < ActiveRecord::Base
  self.table_name = "items"
  belongs_to :default_order, class_name: "Comment", optional: true
end
run("belongs_to :default_order; AssocItem.new.default_order") { AssocItem.new.default_order }
class HasManyPost < ActiveRecord::Base
  self.table_name = "posts"
  has_many :default_order, class_name: "Comment", foreign_key: :post_id
end
run("has_many :default_order; HasManyPost.first.default_order.to_a") { HasManyPost.first.default_order.to_a }

run("Post.where(nil).unscope(:default_order).to_sql (model has def self.default_order)") { Post.where(nil).unscope(:default_order).to_sql }
run("Post.unscope(:default_order).default_order.to_sql") { Post.unscope(:default_order).default_order.to_sql }
run("has_many :comments, default_order: :position") do
  Class.new(ActiveRecord::Base) do
    self.table_name = "posts"
    def self.name = "OptPost"
    def self.default_order = order(:position)
    has_many :comments, foreign_key: :post_id, default_order: :position
  end.first.comments.to_sql
end
