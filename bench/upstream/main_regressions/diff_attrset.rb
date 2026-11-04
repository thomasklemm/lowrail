# frozen_string_literal: true

# Differential probes for LazyAttributeSet copies (map, deep_dup) and #keys:
#   RAILS=DIR ruby [--yjit|--zjit] diff_attrset.rb > out.txt
# Run once per checkout and diff the outputs; every line is an observable
# result (values, key order, dirty state, errors), never an object id.
rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_record"
require "yaml"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveSupport.event_reporter.debug_mode = false if ActiveSupport.respond_to?(:event_reporter)
ActiveRecord.use_yaml_unsafe_load = true
ActiveRecord::Schema.define do
  create_table(:authors) { |t| t.string :name; t.timestamps }
  create_table(:posts) do |t|
    t.references :author
    t.string :title, default: "untitled"
    t.text :body
    t.integer :views, default: 0
    t.text :settings
    t.text :tags
    t.integer :status, default: 0
    t.integer :lock_version, default: 0
    t.timestamps
  end
end

class MutableStringType < ActiveModel::Type::String
  def cast_value(value) = value.to_s.dup
  def changed_in_place?(raw_old_value, new_value) = raw_old_value != serialize(new_value)
end

class Author < ActiveRecord::Base
  has_many :posts
end

class Post < ActiveRecord::Base
  belongs_to :author, optional: true
  serialize :tags, coder: JSON
  store :settings, accessors: [:color, :size], coder: JSON
  enum :status, { draft: 0, published: 1 }
  attribute :virtual_count, :integer, default: 3
  attribute :note, MutableStringType.new
  alias_attribute :headline, :title
  attr_accessor :log
  validates :title, length: { maximum: 20 }
  after_save { (self.log ||= []) << [:after_save, saved_changes.keys.sort, changed_attribute_names_to_save] }
  before_save { (self.log ||= []) << [:before_save, changes_to_save.keys, attribute_names.first(4)] }
end

$out = []
def show(label)
  value = begin
    yield
  rescue => e
    "#{e.class}: #{e.message[0, 120]}"
  end
  $out << "#{label}: #{value.inspect}"
end

def state(label, record)
  show("#{label} attributes") { record.attributes.to_a }
  show("#{label} attribute_names") { record.attribute_names }
  show("#{label} keys") { record.instance_variable_get(:@attributes).keys }
  show("#{label} changed") { record.changed }
  show("#{label} changes") { record.changes.to_a }
  show("#{label} changed?") { record.changed? }
  show("#{label} has_changes_to_save?") { record.has_changes_to_save? }
  show("#{label} saved_changes") { record.saved_changes.except("updated_at", "created_at").to_a }
  show("#{label} attributes_in_database") { record.attributes_in_database.except("updated_at", "created_at").to_a }
  show("#{label} before_type_cast") { record.attributes_before_type_cast.except("updated_at", "created_at").to_a }
  show("#{label} as_json") { record.as_json.except("updated_at", "created_at").to_a }
  show("#{label} key? virtual") { record.has_attribute?(:virtual_count) }
  show("#{label} log") { record.log }
end

author = Author.create!(name: "a")
Post.create!(title: "one", author: author, tags: %w[x y], color: "red")
Post.create!(title: "two", body: "b")

p1 = Post.find(1)
state("loaded", p1)
p1.views += 1
state("assigned", p1)
p1.save!
state("saved", p1)
p1.title = "again"
p1.note = "n"
state("assigned twice", p1)
p1.save!
state("saved twice", p1)
p1.note << "!"
state("mutated in place", p1)
p1.save!
state("saved in place", p1)
p1.tags << "z"
state("serialized in place", p1)
p1.save!
state("serialized saved", p1)

d = p1.dup
state("dup", d)
d.save!
state("dup saved", d)
c = p1.clone
c.views = 99
state("clone", c)
state("original after clone", p1)

p2 = Post.select(:id, :title, :lock_version).find(2)
state("partial", p2)
show("partial body") { p2.body }
p2.title = "two!"
show("partial save") { p2.save! }
state("partial saved", p2)
show("partial body after save") { p2.body }
show("partial attribute_names after save") { p2.attribute_names }
p4 = Post.select(:id, :title).find(2)
state("partial without lock", p4)
p4.title = "two?"
show("partial without lock save") { p4.save! }
state("partial without lock after save", p4)

p3 = Post.select("posts.*, 42 AS extra").find(1)
state("extra column", p3)
p3.update!(views: 7)
state("extra column saved", p3)
show("extra after save") { p3[:extra] }

n = Post.new(title: "new", virtual_count: 5)
state("new", n)
n.save!
state("new saved", n)
n.update!(status: :published, size: "L")
state("new updated", n)

bad = Post.find(1)
bad.title = "x" * 30
show("invalid save") { bad.save }
state("invalid", bad)
bad.title = "ok"
bad.save!
state("valid after invalid", bad)

rb = Post.find(2)
Post.transaction do
  rb.update!(views: 50)
  raise ActiveRecord::Rollback
end
state("rolled back", rb)
rb.reload
state("reloaded", rb)

t = Post.find(1)
t.touch
state("touched", t)
t.increment!(:views)
state("incremented", t)
t.update_columns(views: 1)
state("update_columns", t)
t.toggle(:status) rescue nil
t.headline = "via alias"
state("alias assigned", t)
t.save!
state("alias saved", t)

y = YAML.unsafe_load(YAML.dump(Post.find(1)))
state("yaml", y)
y.update!(views: 3)
state("yaml saved", y)
m = Marshal.load(Marshal.dump(Post.find(1).tap { _1.update!(views: 4) }))
state("marshal of saved", m)
m.update!(views: 5)
state("marshal saved", m)

b = Post.find(1).becomes(Post)
b.update!(views: 6)
state("becomes saved", b)

f = Post.find(1)
f.update!(views: 8)
f.freeze
state("frozen", f)
show("frozen write") { f.views = 1 }

del = Post.create!(title: "gone")
del.destroy
state("destroyed", del)

saved = Post.find(1)
3.times { |i| saved.update!(views: 100 + i) }
state("saved thrice", saved)
show("reload after saves") { saved.reload.attributes.except("updated_at", "created_at").to_a }
show("Post.all") { Post.order(:id).map { _1.attributes.except("updated_at", "created_at") } }
puts $out
