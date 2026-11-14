# #59141's CHANGELOG: defaults are cast and frozen at schema load; records work on a dup.
require "active_record"
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table(:posts) { |t| t.text :prefs; t.text :tags; t.text :meta; t.text :settings; t.string :state, null: false, default: "new" }
end
def probe(name)
  puts "#{name}: #{yield.inspect}"
rescue Exception => e
  puts "#{name}: #{e.class}: #{e.message.lines.first&.strip}"
end
class Prefs # a coder object without initialize_copy that keeps state in an ivar Hash
  attr_reader :h
  def initialize(h = {}) = @h = h
  def self.load(s) = new(s ? JSON.parse(s) : {})
  def self.dump(o) = o && JSON.dump(o.h)
end
class Upcase < ActiveModel::Type::String # overrides cast, not cast_value
  def cast(v) = v.upcase
end
class Post < ActiveRecord::Base
  serialize :prefs, coder: Prefs
  serialize :tags, type: Array, coder: YAML
  serialize :meta, coder: JSON
  store :settings, accessors: [:color], coder: JSON
end
probe("store accessor on new") { p = Post.new; p.color = "red"; p.save!; Post.last.color }
probe("serialize Array default mutate") { p = Post.new; p.tags << "a"; p.save!; Post.last.tags }
probe("serialize JSON default") { Post.new.meta }
probe("custom coder default mutate") { p = Post.new; p.prefs.h["x"] = 1; p.prefs.h }
probe("second new record sees clean default") { Post.new.prefs.h }
probe("type overriding cast without nil handling") do
  k = Class.new(ActiveRecord::Base) { self.table_name = "posts"; attribute :settings, Upcase.new }
  k.new.settings
end
probe("enum-like default string mutate") { p = Post.new; p.state << "!"; p.state }
