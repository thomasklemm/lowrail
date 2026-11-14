# frozen_string_literal: true

# VB1 differential probe: run on main and on the branch, diff the output.
#   RAILS=<tree> BUNDLE_GEMFILE=<suite> ruby probe.rb [sqlite|postgresql] > TREE.txt
# Prints values, exception classes, messages and the Rails frames of each backtrace, plus a log of every type
# cast and deserialize in order, so a change in what is cast, when, or how often shows up as a diff.
require "bundler/setup"
require "active_record"

ADAPTER = ARGV.fetch(0, "sqlite")
RAILS = File.expand_path(ENV.fetch("RAILS")) + "/"
abort "wrong tree" unless ActiveRecord::Base.method(:find).source_location.first.start_with?(RAILS)

if ADAPTER == "postgresql"
  ActiveRecord::Base.establish_connection(adapter: "postgresql", database: ENV.fetch("PGDATABASE", "vb1_probe"))
else
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
end
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false

LOG = []

class TracedString < ActiveModel::Type::String
  def deserialize(value) = (LOG << "deserialize(#{value.inspect})"; super)
  def cast(value) = (LOG << "cast(#{value.inspect})"; super)
end

# Raises when it casts or deserializes a String, so nil and schema setup pass.
class Exploding < ActiveModel::Type::Value
  def deserialize(value) = (LOG << "boom deserialize(#{value.inspect})"; value.is_a?(String) ? raise(ArgumentError, "boom #{value}") : value)
  def cast(value) = (LOG << "boom cast(#{value.inspect})"; value.is_a?(String) ? raise(ArgumentError, "boom #{value}") : value)
end

class LazyDefault
  def self.calls = @calls ||= 0
  def self.call = (@calls = calls + 1; LOG << "default proc"; "computed")
end

ActiveRecord::Schema.define do
  create_table :posts, force: true do |t|
    t.string :type
    t.string :title
    t.text :body
    t.integer :score, default: 7
    t.boolean :published
    t.string :traced
    t.string :fragile
  end
end

class Post < ActiveRecord::Base
  attribute :traced, TracedString.new
  attribute :fragile, Exploding.new
  attribute :virtual, :string, default: "v"
  attribute :virtual_proc, :string, default: -> { LazyDefault.call }
  attribute :virtual_nil, :integer
  attribute :virtual_traced, TracedString.new, default: "vt"
  attribute :virtual_fragile, Exploding.new, default: "vf"
end
class SpecialPost < Post
  attribute :extra, :string, default: "e"
end

Post.insert_all!([
  { type: nil, title: "a", body: "x", score: 1, published: true, traced: "t1", fragile: nil },
  { type: nil, title: "b", body: nil, score: nil, published: false, traced: nil, fragile: nil },
  { type: "SpecialPost", title: "s", body: "y", score: 3, published: nil, traced: "t3", fragile: nil },
])
Post.connection.execute("UPDATE posts SET fragile = 'f' WHERE id = 2")

def frames(error)
  (error.backtrace_locations || []).filter_map do |l|
    path = l.absolute_path || l.path
    next unless path&.start_with?(RAILS) || path == __FILE__
    "#{path.delete_prefix(RAILS).delete_prefix(File.dirname(__FILE__) + "/")}:#{l.lineno} #{l.base_label}"
  end
end

def show(label)
  LOG.clear
  value = yield
  puts "#{label} => #{value.inspect}"
rescue Exception => e
  puts "#{label} !! #{e.class}: #{e.message}"
  puts "  backtrace(#{(e.backtrace || []).size}): #{frames(e).join(" | ")}"
ensure
  puts "  log: #{LOG.join(", ")}" unless LOG.empty?
end

READERS = %w[id type title body score published traced fragile virtual virtual_proc virtual_nil virtual_traced virtual_fragile]

def every_read(label, record, via:)
  READERS.each do |name|
    show("#{label} #{via} #{name}") do
      case via
      when :reader then record.public_send(name)
      when :read_attribute then record.read_attribute(name)
      when :bracket then record[name]
      when :_read_attribute then record._read_attribute(name)
      when :read_attr then record.read_attr(name)
      when :_read_attribute! then record._read_attribute!(name)
      end
    end
    show("#{label} #{via} #{name} again") { record.public_send(name) } if via == :reader
  end
  show("#{label} attributes") { record.attributes }
end

def load(scope = Post.order(:id)) = scope.to_a

%i[reader read_attribute bracket _read_attribute read_attr _read_attribute!].each do |via|
  load.each_with_index { |r, i| every_read("loaded[#{i}]", r, via:) }
end

load(Post.select(:id, :title).order(:id)).each_with_index do |r, i|
  every_read("partial[#{i}]", r, via: :reader)
  every_read("partial[#{i}]", Post.select(:id).find(r.id), via: :_read_attribute!)
  every_read("partial[#{i}]", Post.select(:id).find(r.id), via: :_read_attribute)
end
every_read("select_extra", Post.select("posts.*, 'x' AS extra_col").order(:id).first, via: :reader)
show("select_extra extra_col") { Post.select("posts.*, 'x' AS extra_col").order(:id).first.extra_col }

def built(label)
  record = nil
  show("#{label} build") { record = yield; :ok }
  every_read(label, record, via: :reader) if record
end

built("new") { Post.new(title: "n") }
built("new_blank") { Post.new }
built("sti") { Post.find(3) }
show("sti extra") { Post.find(3).extra }
built("becomes") { Post.find(1).becomes(SpecialPost) }
show("becomes extra") { Post.find(1).becomes(SpecialPost).extra }
built("frozen") { Post.find(1).freeze }
built("dup") { Post.find(1).dup }
built("written") { Post.find(1).tap { _1.title = "w"; _1.virtual = "vw" } }
show("lazy proc default calls after loads") { LazyDefault.calls }

r = Post.find(1)
show("lazy: one read") { r.title }
show("lazy: changed") { r.changed? }
show("lazy: second read") { r.traced }
show("lazy: virtual_traced") { r.virtual_traced }
show("lazy: virtual_traced again") { r.virtual_traced }
show("lazy: attributes") { r.attributes.keys }
show("lazy: save") { r.save! }
show("lazy: save after fragile reset") { r.virtual_fragile = nil; r.save! }
show("lazy: reload title") { r.reload.title }

class Undupable
  def initialize_copy(_) = raise(TypeError, "no dup")
  def inspect = "#<Undupable>"
end
class UndupableType < ActiveModel::Type::Value
  def cast(value) = value.is_a?(String) ? Undupable.new : value
end
class Plain < ActiveRecord::Base
  self.table_name = "posts"
  self.inheritance_column = nil
  attribute :undupable, UndupableType.new
end
d = Plain.find(1)
show("dup: undupable unread") { d.dup.attributes }
d.undupable = "u"
show("dup: undupable cast") { d.undupable }
show("dup: undupable dup") { d.dup }
show("dup: deep_dup identity") do
  a = Plain.find(2)
  a.title
  b = a.dup
  [b.title, b.title.equal?(a.title), b.changed?, b.changes, b.new_record?, b.id]
end
show("dup: frozen") { Plain.find(1).freeze.dup.attributes }
show("dup: partial") { Plain.select(:id, :title).find(1).dup.attributes }

class Widget
  include ActiveModel::Attributes
  attribute :name, :string, default: "w"
  attribute :fragile, Exploding.new, default: -> { "x" }
end
show("am name") { Widget.new.name }
show("am fragile") { Widget.new.fragile }
puts "end"
