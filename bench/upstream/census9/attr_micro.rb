# frozen_string_literal: true

# Census 9: Active Record attribute paths per call, for a Rails checkout in
# RAILS (lib directories, no bundle), on an in-memory SQLite table of WIDTH
# columns (id, a type column, timestamps and WIDTH - 4 data columns cycling
# string, integer, boolean, datetime, float, text; at least 2, so WIDTH 5 has 6).
#
#   RAILS=DIR WIDTH=30 ruby [--yjit] attr_micro.rb [CASE...]   prints CASE Ir/call objects/call jit_delta
#
# Under census 8's patched Callgrind (--instr-atstart=no), IrCount (ir_count.so,
# IR_COUNT_SO) reads the thread's exact Ir around N calls (N, default 200) after
# WARM warmup calls; without Valgrind it prints objects only. jit_delta is the
# YJIT compiled-block count inside the measured window (0 = JIT-flat).
rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_support/core_ext"
require "active_record"
require ENV.fetch("IR_COUNT_SO", File.expand_path("~/c9/ext/ir_count.so"))

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveSupport.event_reporter.debug_mode = false if ActiveSupport.respond_to?(:event_reporter)
ActiveRecord::Migration.verbose = false
# 8.1 defaults to the 6.1 format (plain ivars); main has only 7.1. Compare like with like.
ActiveRecord::Marshalling.format_version = 7.1
raise "not #{rails}" unless ActiveRecord::Base.method(:find).source_location.first.start_with?(File.expand_path(rails))

WIDTH = Integer(ENV.fetch("WIDTH", "30"))
TYPES = %i[string integer boolean datetime float text].freeze
DATA = (1..[WIDTH - 4, 2].max).map { |i| ["c#{i}", TYPES[(i - 1) % TYPES.size]] }
ActiveRecord::Schema.define do
  create_table(:items) do |t|
    t.string :type
    DATA.each { |name, type| t.column name, type }
    t.timestamps
  end
end

class Item < ActiveRecord::Base; end
class SubItem < Item; end
class PlainItem < ActiveRecord::Base
  self.table_name = "items"
  self.inheritance_column = nil
end
# Models that declare attributes with the attribute API: one virtual, one
# overriding a column's type.
class ApiItem < ActiveRecord::Base
  self.table_name = "items"
  self.inheritance_column = nil
  attribute :extra, :string, default: "x"
  attribute :c2, :string
end

def value(type, i)
  case type
  when :string, :text then "v#{i}"
  when :integer then i
  when :boolean then i.odd?
  when :datetime then Time.utc(2026, 1, 1) + i
  when :float then i * 1.5
  end
end
50.times do |r|
  attrs = DATA.to_h { |name, type| [name, value(type, r)] }
  (r.even? ? Item : SubItem).create!(attrs)
end

CONN = ActiveRecord::Base.connection
R1 = CONN.select_all(PlainItem.where(id: 1).arel)
R20 = CONN.select_all(PlainItem.order(:id).limit(20).arel)
R1_STI = CONN.select_all(Item.where(id: 2).arel)
R1_PARTIAL = CONN.select_all(PlainItem.select(:id, :c1, :c2).where(id: 1).arel)
R1_API = CONN.select_all(ApiItem.where(id: 1).arel)
NAMES = PlainItem.column_names.freeze
READERS = NAMES.map(&:to_sym).freeze
STR = DATA.find { _2 == :string }.first
INT = DATA.find { _2 == :integer }.first
SLICE = [:id, STR.to_sym, INT.to_sym].freeze
REC = PlainItem.find(1)
REC_ATTR = PlainItem.find(3)
REC_W = PlainItem.find(5)
NEW_ATTRS = { STR => "n", INT => 7 }.freeze
FLIP = [false]
def load1 = PlainItem._load_from_sql(R1).first
def flip = (FLIP[0] = !FLIP[0])

CASES = {
  # Loading: _load_from_sql on a cached result (no SQL), and a full query.
  "load1" => -> { load1 },
  "load20" => -> { PlainItem._load_from_sql(R20) },
  "find" => -> { PlainItem.find(1) },
  "where_to_a20" => -> { PlainItem.where(id: 1..20).to_a },
  # Readers on a fresh record (first read casts) and on a warm one.
  "load1_read1" => -> { load1.public_send(STR) },
  "load1_read_all" => -> { r = load1; READERS.each { r.public_send(_1) } },
  "read1_warm" => -> { REC.public_send(STR) },
  "read_all_warm" => -> { READERS.each { REC.public_send(_1) } },
  "read_attribute" => -> { REC.read_attribute(STR) },
  "index_read" => -> { REC[STR] },
  "load1_read_attribute_all" => -> { r = load1; NAMES.each { r.read_attribute(_1) } },
  # Whole-record hashes.
  "load1_attributes" => -> { load1.attributes },
  "attributes_warm" => -> { REC.attributes },
  "load1_as_json" => -> { load1.as_json },
  "serializable_hash_warm" => -> { REC.serializable_hash },
  "slice" => -> { REC.slice(*SLICE) },
  "values_at" => -> { REC.values_at(*SLICE) },
  "attributes_before_type_cast" => -> { REC.attributes_before_type_cast },
  # Writes and dirty tracking, no SQL.
  "new" => -> { PlainItem.new(NEW_ATTRS) },
  "new_empty" => -> { PlainItem.new },
  "write_attribute" => -> { REC_W.write_attribute(STR, flip ? "a" : "b") },
  "writer" => -> { REC_W.public_send("#{STR}=", flip ? "a" : "b") },
  "load1_assign_changes" => -> { r = load1; r.public_send("#{STR}=", "z"); r.changes },
  "load1_changed?" => -> { load1.changed? },
  "load1_dup" => -> { load1.dup },
  # Save: one column update with SQL (the record and table stay the same size).
  "update1" => -> { REC_W.update!(INT => flip ? 1 : 2) },
  "load1_update1" => -> { r = load1; r.update!(INT => flip ? 3 : 4) },
  # STI, becomes, the attribute API, partial selects.
  "sti_load1" => -> { Item._load_from_sql(R1_STI).first },
  "sti_load1_attributes" => -> { Item._load_from_sql(R1_STI).first.attributes },
  "becomes" => -> { REC_ATTR.becomes(Item) },
  "api_load1_read" => -> { r = ApiItem._load_from_sql(R1_API).first; r.c2; r.extra },
  "api_load1_attributes" => -> { ApiItem._load_from_sql(R1_API).first.attributes },
  "partial_load1_read" => -> { PlainItem._load_from_sql(R1_PARTIAL).first.public_send(STR) },
  "partial_load1_attributes" => -> { PlainItem._load_from_sql(R1_PARTIAL).first.attributes },
  # Record caching: Marshal (Rails 7.1+ format) and attributes_for_database, which MessagePack uses.
  "marshal_dump" => -> { Marshal.dump(REC) },
  "load1_marshal_dump" => -> { Marshal.dump(load1) },
  "attributes_for_database" => -> { REC.attributes_for_database },
  # By-name reads Rails itself makes: the primary key and _read_attribute.
  "id" => -> { REC.id },
  "_read_attribute" => -> { REC._read_attribute(STR) },
}.freeze

names = ARGV.empty? ? CASES.keys : ARGV
n = Integer(ENV.fetch("N", "200"))
warm = Integer(ENV.fetch("WARM", "300"))
yjit = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
blocks = -> { yjit ? RubyVM::YJIT.runtime_stats[:compiled_block_count] : 0 }
IrCount.start if IrCount.running?
names.each do |name|
  fn = CASES.fetch(name)
  warm.times { fn.() }
  # JIT-flat: warm until three windows of n calls in a row compile nothing (at most 30).
  if yjit
    flat = 0
    30.times do
      b = blocks.()
      n.times { fn.() }
      flat = blocks.() == b ? flat + 1 : 0
      break if flat == 3
    end
  end
  GC.start
  GC.disable
  b0 = blocks.()
  o0 = GC.stat(:total_allocated_objects)
  i0 = IrCount.now
  n.times { fn.() }
  i1 = IrCount.now
  o1 = GC.stat(:total_allocated_objects)
  jit = blocks.() - b0
  GC.enable
  puts format("%-28s %12.1f %8.2f %d", name, (i1 - i0).fdiv(n), (o1 - o0).fdiv(n), jit)
  $stdout.flush
end
