# frozen_string_literal: true

# Independent K1 review probe (claude-code pass, 2026-11-14): cases beyond keys_probe.rb. Dumps keys, to_hash,
# the slots materialize builds and record-level reads for each. BUNDLE_GEMFILE=<suite for TREE> ruby review_probe.rb
require "bundler/setup"
require "active_record"
require "yaml"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name }
  create_table(:posts) do |t|
    t.references :author
    t.string :title, default: "untitled"
    t.integer :status, default: 0
    t.text :settings
  end
  create_table(:vehicles) do |t|
    t.string :type
    t.string :name
  end
  create_table(:cpks, primary_key: [:a, :b]) do |t|
    t.integer :a
    t.integer :b
    t.string :v
  end
end

class Author < ActiveRecord::Base
  has_many :posts
end

class Post < ActiveRecord::Base
  belongs_to :author, optional: true
  alias_attribute :headline, :title
  enum :status, { draft: 0, live: 1 }
  store :settings, accessors: [:color], coder: JSON
  normalizes :title, with: ->(t) { t.strip }
  attribute :note, :string
  attribute :rank, :integer, default: 5
end

class Vehicle < ActiveRecord::Base; end
class Car < Vehicle
  attribute :wheels, :integer, default: 4
end
class Bike < Vehicle; end

class Cpk < ActiveRecord::Base; end

class PlainModel
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Dirty
  attribute :name, :string
  attribute :count, :integer
end

author = Author.create!(name: "a")
Post.create!(author: author, title: " one ", note: "n", color: "red")
Post.create!(title: "two", status: :live)
Car.create!(name: "c")
Bike.create!(name: "b")
Cpk.create!(a: 1, b: 2, v: "x")

def safe
  yield
rescue Exception => e # rubocop:disable Lint/RescueException
  "#{e.class}: #{e.message.lines.first&.strip}"
end

def set_of(record) = record.instance_variable_get(:@attributes)

def built_slots(set)
  return "n/a #{set.class}" unless set.is_a?(ActiveModel::LazyIndexedAttributeSet)

  copy = set.dup
  copy.send(:materialize)
  attrs = copy.instance_variable_get(:@attributes) || []
  attrs.each_with_index.filter_map { |a, i| [i, a.name, a.class.name.split("::").last, a.initialized?] if a }
end

def dump(record)
  set = set_of(record)
  out = {}
  out[:set_class] = set.class.name
  out[:keys] = safe { set.keys }
  out[:keys_twice_independent] = safe { a = set.keys; a << "zz"; set.keys.include?("zz") ? "ALIASED" : "ok" }
  out[:to_hash_keys] = safe { set.to_hash.keys }
  out[:consistent] = out[:keys] == out[:to_hash_keys]
  out[:built_by_materialize] = safe { built_slots(set) }
  out[:attributes] = safe { record.attributes.transform_values(&:inspect) }
  out[:attribute_names] = safe { record.attribute_names }
  out[:changed?] = safe { record.changed? }
  out[:changes] = safe { record.changes.transform_values(&:inspect) }
  out[:serializable_hash] = safe { record.serializable_hash.transform_values(&:inspect) }
  out[:inspect] = safe { record.inspect }
  out[:dup_attrs] = safe { record.dup.attributes.transform_values(&:inspect) }
  out
end

CASES = {}
def kase(name, &block) = CASES[name] = block

kase("enum/store/normalizes load") { Post.order(:id).first }
kase("store accessor write") { Post.order(:id).first.tap { |p| p.color = "blue" } }
kase("alias select") { Post.select("id, title AS headline").first }
kase("select model-only attribute name") { Post.select("posts.*, 'sel' AS note, 9 AS rank").first }
kase("joins with typed extra") { Post.joins(:author).select("posts.*, authors.name AS author_name").first }
kase("eager_load with select") { Author.eager_load(:posts).select("authors.*, posts.id AS pid").first }
kase("partial select dup") { Post.select(:id).first.dup }
kase("partial select save") { Post.select(:id, :title).first.tap { |p| p.title = "ps"; p.save! } }
kase("partial select freeze") { Post.select(:id).first.freeze }
kase("new freeze") { Post.new.freeze }
kase("destroy") { Post.create!(title: "gone").tap(&:destroy) }
kase("becomes new record") { Post.new(title: "bn").becomes(Post) }
kase("becomes with extra select") { Car.select("vehicles.*, 1 AS extra").first.becomes(Bike) }
kase("sti parent query, subclass attribute") { Vehicle.order(:id).first }
kase("sti find_by_sql relayout") { Vehicle.find_by_sql("SELECT type, id, name FROM vehicles").first }
kase("sti instantiate IndexedRow relayout") { Vehicle.instantiate(ActiveModel::IndexedRow[{ "id" => 1, "type" => "Car", "name" => "x" }]) }
kase("instantiate foreign IndexedRow") { Post.instantiate(ActiveModel::IndexedRow[{ "id" => 1, "title" => "x" }]) }
kase("instantiate Result#indexed_rows") do
  Post.instantiate(Post.connection.select_all("SELECT id, title FROM posts").indexed_rows.first)
end
kase("instantiate hash + types for model and extra") do
  Post.instantiate({ "id" => 3, "rank" => "8", "zz" => "4" }, { "rank" => ActiveModel::Type::String.new, "zz" => ActiveModel::Type::Integer.new, "nope" => ActiveModel::Type::Integer.new })
end
kase("composite primary key") { Cpk.first }
kase("composite primary key update") { Cpk.first.tap { |c| c.update!(v: "y") } }
kase("reload partial") { Post.select(:id).first.tap(&:reload) }

class ResetMid < ActiveRecord::Base
  self.table_name = "posts"
  after_find { self.class.reset_column_information }
end
kase("reset_column_information mid-result") { ResetMid.order(:id).to_a.last }

class Vehicle2 < ActiveRecord::Base
  self.table_name = "vehicles"
  self.inheritance_column = nil
end
kase("thread declares attribute mid-result (simulated)") do
  rows = Vehicle2.order(:id).to_a.tap { Vehicle2.attribute(:late2, :string) }
  Vehicle2.order(:id).first.tap { |v| v.instance_variable_set(:@old_rows, rows) }
end

results = {}
CASES.each do |name, fn|
  record = fn.call
  results[name] = dump(record)
rescue Exception => e # rubocop:disable Lint/RescueException
  results[name] = "case raised #{e.class}: #{e.message.lines.first&.strip}"
end

pm = PlainModel.new(name: "p")
results["ActiveModel::Attributes"] = { keys: set_of(pm).keys, built: built_slots(set_of(pm)), names: pm.attribute_names,
  changes: pm.changes, dup: pm.dup.attributes, frozen_names: pm.dup.freeze.attribute_names }

# Mid-result declaration in an eager_load (JoinDependency reads attributes_builder per row too).
class MidAuthor < ActiveRecord::Base
  self.table_name = "authors"
  has_many :mid_posts, foreign_key: :author_id
end
class MidPost < ActiveRecord::Base
  self.table_name = "posts"
  after_find { self.class.attribute(:mid_late, :string) unless self.class.attribute_names.include?("mid_late") }
end
Post.create!(author: author, title: "three")
rows = safe { MidAuthor.eager_load(:mid_posts).first.mid_posts.to_a }
results["eager_load mid-result"] = rows.is_a?(String) ? rows : rows.map { |r| dump(r) }

results.each do |name, out|
  puts "== #{name}"
  puts out.to_yaml
end
bad = results.select { |_, o| o.is_a?(Hash) && o.key?(:consistent) && !o[:consistent] }
puts "INCONSISTENT: #{bad.keys.inspect}"
