# frozen_string_literal: true

# L3 review probe (claude-code pass): cases bench/upstream/l3/probe.rb doesn't cover. Prints, per case, both Hashes,
# the order and count of every type call they make, whether a second call returns the same value objects, what
# the set has read and built afterwards, and whether mutating a returned Hash leaks. Diff the output of two trees.
#
#   RAILS=TREE BUNDLE_GEMFILE=... [ADAPTER=postgresql] ruby review_probe.rb
require "bundler/setup"
require "active_record"
require "tmpdir"

rails = ENV.fetch("RAILS")
unless ActiveRecord::Base.method(:find).source_location.first.start_with?(File.expand_path(rails) + "/")
  abort "Active Record not loaded from #{rails}"
end

ADAPTER = ENV.fetch("ADAPTER", "sqlite3")
if ADAPTER == "sqlite3"
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: File.join(Dir.mktmpdir, "r.sqlite3"))
else
  ActiveRecord::Base.establish_connection(adapter: "postgresql", database: "l3_probe")
end
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord::Encryption.configure(primary_key: "a" * 32, deterministic_key: "b" * 32, key_derivation_salt: "c" * 32)

LOG = []
class Traced < ActiveModel::Type::String
  def serialize(value) = (LOG << [:serialize, value]; super)
  def deserialize(value) = (LOG << [:deserialize, value]; super)
  def changed_in_place?(raw, value) = (LOG << [:changed_in_place?, raw]; super)
end
class Fresh < ActiveModel::Type::Value
  # A new object on every serialize, so the identity of what a second call returns shows memoization.
  def serialize(value) = value.nil? ? nil : +"#{value}!"
end
class Boom < ActiveModel::Type::String
  def serialize(value) = value == "boom" ? raise(ArgumentError, "boom") : super
end

ActiveRecord::Schema.define do
  create_table(:widgets, force: true) do |t|
    t.string :a
    t.string :b
    t.string :c
    t.string :secret
    t.text :doc
    t.string :hidden
  end
  create_table(:parts, force: true) do |t|
    t.integer :widget_id
    t.string :label
  end
  create_table(:cpks, primary_key: [:x, :y], force: true) do |t|
    t.integer :x
    t.integer :y
    t.string :v
  end
end

class Part < ActiveRecord::Base
  belongs_to :widget
end

class Widget < ActiveRecord::Base
  self.ignored_columns = ["hidden"]
  attribute :a, Traced.new
  attribute :b, Fresh.new
  attribute :c, Boom.new
  attribute :extra_attr, :integer
  attribute :with_default, Traced.new, default: "d"
  serialize :doc, coder: JSON
  encrypts :secret
  has_many :parts
end

class Cpk < ActiveRecord::Base
  self.primary_key = [:x, :y]
end

class Plain
  include ActiveModel::API
  include ActiveModel::Attributes
  attribute :p, Traced.new
  attribute :q, :integer, default: 2
end

class Empty
  include ActiveModel::Attributes
end

w = Widget.create!(a: "x", b: "y", c: "z", secret: "s", doc: { "k" => [1] })
Widget.connection.execute("INSERT INTO widgets (id, c) VALUES (2, 'boom')")
Part.create!(widget: w, label: "p1")
Cpk.create!(x: 1, y: 2, v: "c")

def set_of(rec) = rec.instance_variable_get(:@attributes)

def show(v)
  case v
  when Hash then "{" + v.map { |k, x| "#{k}=>#{show(x)}" }.join(", ") + "}"
  when Array then "[" + v.map { |x| show(x) }.join(", ") + "]"
  when String
    v.start_with?('{"p":') ? "ENC[#{ActiveRecord::Encryption.encryptor.decrypt(v)}]" : "#{v.inspect}#{"(f)" if v.frozen?}"
  else v.inspect.gsub(/0x\h+/, "0x")
  end
end

def call(label, &blk)
  LOG.clear
  value = blk.call
  puts "  #{label}: #{show(value)}"
  puts "  #{label} type calls: #{LOG.map { |m, raw| "#{m}(#{raw.inspect})" }.join(" ")}"
  value
rescue => e
  puts "  #{label}: raised #{e.class}: #{e.message.gsub(/0x\h+/, "0x")}"
  nil
end

def probe(name, rec_fn)
  puts name
  rec = begin
    rec_fn.call
  rescue => e
    puts "  build raised #{e.class}: #{e.message.gsub(/0x\h+/, "0x")}"
    return
  end
  set = set_of(rec)
  puts "  set: #{set.class}"
  db = call("for_database") { set.values_for_database }
  db2 = call("for_database again") { set.values_for_database }
  if db && db2
    same = db.keys.select { |k| db[k].equal?(db2[k]) }
    puts "  same objects on second call: #{same.inspect}; ==: #{db == db2}; same Hash: #{db.equal?(db2)}"
    db.each { |k, v| v << "MUT" if k != "secret" && v.is_a?(String) && !v.frozen? }
    db["injected"] = 1
    call("for_database after mutating the first result") { set.values_for_database }
  end
  btc = call("before_type_cast") { set.values_before_type_cast }
  if btc
    btc["injected"] = 1
    btc.clear
    call("before_type_cast after clearing the first result") { set.values_before_type_cast }
  end
  call("accessed") { set.accessed }
  call("keys") { set.keys }
  call("to_hash") { set.to_hash }
  call("changed") { rec.respond_to?(:changed) ? rec.changed : nil }
  call("frozen?") { set.frozen? }
  if rec.is_a?(ActiveRecord::Base) && !rec.frozen? && !rec.readonly?
    call("save") { rec.save }
    call("for_database after save") { set_of(rec).values_for_database }
  end
end

CASES = {
  "loaded" => -> { Widget.find(1) },
  "loaded, read a, b first" => -> { r = Widget.find(1); r.a; r.b; r },
  "loaded with serialize raising" => -> { Widget.find(2) },
  "loaded, doc mutated in place" => -> { r = Widget.find(1); r.doc["k"] << 2; r },
  "loaded, a mutated in place" => -> { r = Widget.find(1); r.a << "!"; r },
  "loaded, written" => -> { r = Widget.find(1); r.a = "new"; r.extra_attr = "5"; r },
  "new" => -> { Widget.new },
  "new with values" => -> { Widget.new(a: "q", secret: "t") },
  "partial select" => -> { Widget.select(:id, :b).first },
  "select with extras and duplicates" => -> { Widget.select("widgets.*, a AS a2, a AS a2, 1 AS one").first },
  "find_by_sql duplicate columns" => -> { Widget.find_by_sql("SELECT id, a, a, b FROM widgets ORDER BY id").first },
  "eager_load with select extra" => -> { Widget.eager_load(:parts).select("widgets.*, 7 AS seven").first },
  "instantiate unknown names" => -> { Widget.instantiate("id" => 9, "a" => "i", "zz" => "u") },
  "instantiate with types" => -> { Widget.instantiate({ "id" => 9, "zz" => "3" }, { "zz" => ActiveModel::Type::Integer.new }) },
  "frozen loaded" => -> { Widget.find(1).freeze },
  "frozen new" => -> { Widget.new(a: "f").freeze },
  "readonly loaded" => -> { Widget.readonly.find(1) },
  "dup" => -> { Widget.find(1).dup },
  "clone after read" => -> { r = Widget.find(1); r.a; r.clone },
  "becomes" => -> { Widget.find(1).becomes(Widget) },
  "reload" => -> { r = Widget.find(1); r.a = "z"; r.reload },
  "cpk" => -> { Cpk.first },
  "after save" => -> { r = Widget.find(1); r.update!(a: "s1"); r },
  "attribute declared after load" => -> { r = Widget.find(1); Widget.attribute :late, :string, default: "L"; Widget.find(1) },
  "ActiveModel::Attributes" => -> { Plain.new(p: "m") },
  "ActiveModel::Attributes empty" => -> { Empty.new },
}

CASES.each { |name, fn| probe(name, fn) }
