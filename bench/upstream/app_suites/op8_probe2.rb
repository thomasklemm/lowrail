# OP8 second probe: dirty/save with and without a first read, nested sharing, and coder calls at schema load.
# RAILS_PATH=/path/to/rails ruby op8_probe2.rb   (PGHOST/PGPORT/PGUSER; uses database postgres)
require "bundler/inline"
gemfile do
  source "https://rubygems.org"
  gem "rails", path: ENV.fetch("RAILS_PATH")
  gem "pg"
end
require "active_record"
require "json"
ActiveRecord::Base.establish_connection(adapter: "postgresql", database: "postgres")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :op8_items, force: true do |t|
    t.string :prefs, default: ""
    t.string :settings, default: '{"theme":{"mode":"light"}}'
    t.string :name
  end
end

module EmptyCoder # "" loads as [] and dumps as "[]": no round trip
  def self.load(v) = v.blank? ? [] : JSON.parse(v)
  def self.dump(v) = JSON.dump(v)
end
module CountingCoder
  class << self; attr_accessor :loads; end
  self.loads = 0
  def self.load(v) = (self.loads += 1; v.blank? ? {} : JSON.parse(v))
  def self.dump(v) = JSON.dump(v)
end

class Item < ActiveRecord::Base
  self.table_name = "op8_items"
  serialize :prefs, coder: EmptyCoder
  serialize :settings, coder: JSON
end
a = Item.new
puts "unread: changed=#{a.changed.inspect}"
a.save!; puts "  saved prefs=#{a.reload.prefs_before_type_cast.inspect}"
b = Item.new; b.prefs
puts "read first: changed=#{b.changed.inspect}"
b.save!; puts "  saved prefs=#{b.reload.prefs_before_type_cast.inspect}"
c = Item.new; c.settings["theme"]["mode"] = "dark"
puts "nested shared: #{Item.new.settings["theme"]["mode"] == "dark"}"

class Counted < ActiveRecord::Base
  self.table_name = "op8_items"
  serialize :settings, coder: CountingCoder
end
Counted.new; before = CountingCoder.loads; Counted.new.settings
puts "counting coder: loads before first read=#{before}, after=#{CountingCoder.loads}"
CountingCoder.loads = 0
class CountedProc < ActiveRecord::Base
  self.table_name = "op8_items"
  serialize :settings, coder: CountingCoder
  attribute :name, default: -> { "x" }
end
CountedProc.new; before = CountingCoder.loads; CountedProc.new.settings
puts "with a later proc default: loads before first read=#{before}, after=#{CountingCoder.loads}"
