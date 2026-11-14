# frozen_string_literal: true

# K1 differential probe: dumps what attribute sets report (keys, to_hash, each_value, key?, dirty state, before
# type cast, serialization) for every way a record gets its attributes, so two Rails trees can be diffed.
#   BUNDLE_GEMFILE=<suite for TREE> ruby bench/upstream/k1/keys_probe.rb > out-TREE.txt
# Every case also checks that keys equals to_hash.keys and the names each_value yields for initialized attributes.
require "bundler/setup"
require "active_record"
require "active_model"
require "yaml"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name }
  create_table(:posts) do |t|
    t.references :author
    t.string :title, default: "untitled"
    t.text :body
    t.integer :score
    t.text :data
    t.string :legacy
    t.virtual :title_upper, type: :string, as: "UPPER(title)", stored: false
  end
  create_table(:vehicles) do |t|
    t.string :type
    t.string :name
    t.integer :doors, default: 2
  end
end

class Author < ActiveRecord::Base
  has_many :posts
end

class UpcaseType < ActiveModel::Type::String
  def cast(value) = super&.upcase
end

class Post < ActiveRecord::Base
  belongs_to :author, optional: true
  self.ignored_columns = ["legacy"]
  attribute :tags_count, :integer, default: 3
  attribute :note, :string
  attribute :score, :integer, default: 7
  attribute :shout, UpcaseType.new
  serialize :data, coder: JSON
end

class SpecialPost < ActiveRecord::Base
  self.table_name = "posts"
  attribute :special, :string, default: "yes"
end

class Vehicle < ActiveRecord::Base; end
class Car < Vehicle
  attribute :wheels, :integer, default: 4
end
class Truck < Vehicle; end

class PlainModel
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Dirty
  include ActiveModel::Serializers::JSON
  attribute :name, :string
  attribute :count, :integer, default: 1
end

author = Author.create!(name: "a")
Post.create!(author: author, title: "one", body: "b", score: 5, data: { "k" => 1 }, note: "n1")
Post.create!(title: "two", score: nil)
Car.create!(name: "c")
Truck.create!(name: "t")

def safe
  yield
rescue Exception => e # rubocop:disable Lint/RescueException
  "#{e.class}: #{e.message.lines.first&.strip}"
end

def set_of(record) = record.instance_variable_get(:@attributes)

def dump_set(set)
  out = {}
  out[:class] = set.class.name
  out[:keys] = safe { set.keys }
  out[:to_hash] = safe { set.to_hash.transform_values(&:inspect) }
  out[:each_value] = safe { set.each_value.map { |a| [a.name, a.initialized?, a.value_before_type_cast.inspect] } }
  names = (Array(out[:keys]) + %w[id title note tags_count score legacy title_upper extra one special wheels nope]).uniq
  out[:key?] = names.to_h { |n| [n, safe { set.key?(n) }] }
  out[:accessed] = safe { set.accessed }
  if out[:keys].is_a?(Array) && out[:to_hash].is_a?(Hash)
    init = set.each_value.select(&:initialized?).map(&:name)
    out[:consistent] = [out[:keys] == out[:to_hash].keys, out[:keys].sort == init.sort]
  end
  out
end

def dump(record)
  out = { set: dump_set(set_of(record)) }
  out[:attributes] = safe { record.attributes.transform_values(&:inspect) }
  out[:attribute_names] = safe { record.attribute_names }
  out[:before_type_cast] = safe { record.attributes_before_type_cast.transform_values(&:inspect) }
  out[:changed?] = safe { record.changed? }
  out[:changes] = safe { record.changes.transform_values(&:inspect) }
  out[:changed_attributes] = safe { record.changed_attributes.transform_values(&:inspect) }
  out[:serializable_hash] = safe { record.serializable_hash.transform_values(&:inspect) }
  out[:as_json] = safe { record.as_json.to_s }
  out[:inspect] = safe { record.inspect }
  out
end

CASES = {}
def kase(name, &block) = CASES[name] = block

kase("new") { Post.new }
kase("new with args") { Post.new(title: "x", note: "y") }
kase("new then write") { Post.new.tap { |p| p.score = 9; p.shout = "hi" } }
kase("load") { Post.order(:id).first }
kase("load then read all") { Post.order(:id).first.tap { |p| p.attributes } }
kase("load then write") { Post.order(:id).first.tap { |p| p.title = "z"; p.note = "w"; p.tags_count = 8 } }
kase("load nil score") { Post.order(:id).second }
kase("load then in-place mutation") { Post.order(:id).first.tap { |p| p.data["k"] = 2 } }
kase("find") { Post.find(1) }
kase("partial select") { Post.select(:id, :title).first }
kase("partial select no id") { Post.select(:title).first }
kase("partial select write") { Post.select(:id, :title).first.tap { |p| p.title = "q" } }
kase("select as extra") { Post.select("posts.*, title AS extra, 1 AS one").first }
kase("select as extra only") { Post.select("id, score AS extra").first }
kase("select reorder") { Post.select(:score, :id, :title).first }
kase("select extra then write extra") { Post.select("posts.*, 1 AS extra").first.tap { |p| safe { p.write_attribute("extra", 5) } } }
kase("write_attribute unknown") { Post.first.tap { |p| p.instance_variable_set(:@k1_err, safe { p.write_attribute("nope", 1) }) } }
kase("set []= unknown") { Post.first.tap { |p| p.instance_variable_set(:@k1_err, safe { set_of(p).write_from_user("nope", 1) }) } }
kase("eager_load join") { Author.eager_load(:posts).first.posts.first }
kase("preload") { Author.preload(:posts).first.posts.first }
kase("find_by_sql") { Post.find_by_sql("SELECT id, title, 2 AS extra FROM posts").first }
kase("instantiate hash") { Post.instantiate({ "id" => 5, "title" => "h", "zzz" => "1" }) }
kase("instantiate hash with types") { Post.instantiate({ "id" => 5, "score" => "4", "zzz" => "1" }, { "zzz" => ActiveModel::Type::Integer.new }) }
kase("build_from_database legacy") do
  set = Post.attributes_builder.build_from_database({ "id" => 1, "x" => "2" }, { "x" => ActiveModel::Type::Integer.new })
  Post.allocate.init_with_attributes(set)
end
kase("becomes") { Post.first.becomes(SpecialPost) }
kase("becomes then write") { Post.first.becomes(SpecialPost).tap { |p| p.special = "no"; p.title = "b" } }
kase("sti load car") { Vehicle.where(type: "Car").first }
kase("sti load truck") { Vehicle.where(type: "Truck").first }
kase("sti subclass query") { Car.first }
kase("sti becomes") { Car.first.becomes(Truck) }
kase("sti becomes!") { Car.first.becomes!(Truck) }
kase("sti new") { Car.new(name: "n") }
kase("dup") { Post.first.dup }
kase("dup after write") { Post.first.tap { |p| p.title = "d" }.dup }
kase("clone") { Post.first.clone }
kase("clone after write") { Post.first.tap { |p| p.title = "c" }.clone.tap { |p| p.note = "cc" } }
kase("freeze") { Post.first.freeze }
kase("reset") { Post.first.tap { |p| p.title = "r"; set_of(p).reset("title"); set_of(p).reset("note") } }
kase("reload") { Post.first.tap { |p| p.title = "r"; p.reload } }
kase("save") { Post.first.tap { |p| p.title = "s"; p.save! } }
kase("update") { Post.first.tap { |p| p.update!(score: 11, note: "u") } }
kase("create") { Post.create!(title: "new") }
kase("Marshal 7.1") { Marshal.load(Marshal.dump(Post.first.tap { |p| p.title = "m" })) }
kase("Marshal 6.1 format") do
  ActiveRecord.marshalling_format_version = 6.1
  Marshal.load(Marshal.dump(Post.first.tap { |p| p.note = "m6" }))
ensure
  ActiveRecord.marshalling_format_version = 7.1
end
kase("Marshal 6.1 format new record") do
  ActiveRecord.marshalling_format_version = 6.1
  Marshal.load(Marshal.dump(Post.new(title: "m6")))
ensure
  ActiveRecord.marshalling_format_version = 7.1
end
kase("YAML") { YAML.unsafe_load(YAML.dump(Post.first.tap { |p| p.title = "y" })) }
kase("init_with") { Post.allocate.init_with({ "attributes" => set_of(Post.first), "new_record" => false }) }
kase("deep_dup set") { Post.first.tap { |p| p.instance_variable_set(:@attributes, set_of(p).deep_dup) } }
kase("message pack") do
  require "active_record/message_pack"
  data = ActiveSupport::MessagePack.dump(Post.first, )
  ActiveSupport::MessagePack.load(data)
rescue LoadError, NameError
  Post.first
end

results = {}
CASES.each do |name, fn|
  record = fn.call
  results[name] = record.is_a?(String) ? record : dump(record)
rescue Exception => e # rubocop:disable Lint/RescueException
  results[name] = "case raised #{e.class}: #{e.message.lines.first&.strip}"
end

pm = PlainModel.new(name: "p")
results["ActiveModel::Attributes"] = { set: dump_set(pm.instance_variable_get(:@attributes)), changes: pm.changes,
  as_json: pm.as_json }

# Attributes declared after records loaded (a type or a callback adding one): old records keep their layout.
old = Post.first
old.title = "before"
Post.attribute :late, :string, default: "x"
results["declared after load: old record"] = dump(old)
results["declared after load: new load"] = dump(Post.first)
results["declared after load: new record"] = dump(Post.new)

# An after_find that declares an attribute while a result is being instantiated: later rows of the same result
# were laid out with the builder from before the declaration.
class Mid < ActiveRecord::Base
  self.table_name = "posts"
  after_find { self.class.attribute(:mid_late, :string, default: "m") unless self.class.attribute_names.include?("mid_late") }
end
rows = safe { Mid.order(:id).to_a }
results["declared mid-result"] = rows.is_a?(String) ? rows : rows.map { |r| dump(r) }

results.each do |name, out|
  puts "== #{name}"
  puts out.to_yaml
end
bad = results.select { |_, o| o.is_a?(Hash) && o[:set].is_a?(Hash) && o[:set][:consistent] && o[:set][:consistent] != [true, true] }
puts "INCONSISTENT: #{bad.keys.inspect}"
