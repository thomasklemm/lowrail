# frozen_string_literal: true

# L3 per-call micro: Marshal, MessagePack, attributes_for_database and attributes_before_type_cast at a given
# table width, every case in one process. Same windows as bench/upstream/k1/attr_bench.rb (IrWin client requests,
# GC.start then GC.disable around N calls after WARM warmup calls; under YJIT warm windows repeat until three in a
# row compile nothing). Table as census 9's attr_micro.rb: id, type, data columns cycling string, integer,
# boolean, datetime, float and text, and timestamps.
require "bundler/setup"
require "json"
$LOAD_PATH.unshift(ENV.fetch("IRWIN_DIR", File.expand_path("~/l3/ext")))
require "irwin"
require "active_record"
require "active_support/message_pack"
require "active_record/message_pack"

rails = ENV.fetch("RAILS")
unless ActiveRecord::Base.method(:find).source_location.first.start_with?(File.expand_path(rails) + "/")
  abort "Active Record not loaded from #{rails}"
end

WIDTH = Integer(ENV.fetch("WIDTH", "30"))
N = Integer(ENV.fetch("N", "200"))
WARM = Integer(ENV.fetch("WARM", "100"))
YJIT = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
ActiveRecord::Marshalling.format_version = 7.1

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

def value(type, i)
  case type
  when :string, :text then "v#{i}"
  when :integer then i
  when :boolean then i.odd?
  when :datetime then Time.utc(2026, 1, 1) + i
  when :float then i + 0.5
  end
end
VALUES = DATA.each_with_index.to_h { |(name, type), i| [name, value(type, i)] }
Item.create!(VALUES)
REC = Item.find(1)
REC.c1
MSGPACK = MessagePack::Factory.new.tap do |factory|
  ActiveRecord::MessagePack::Extensions.install(factory)
  ActiveSupport::MessagePack::Extensions.install(factory)
end
DUMPED = Marshal.dump(REC)
SET = REC.instance_variable_get(:@attributes)

CASES = {
  "_empty" => -> { },
  "load1" => -> { Item.find(1) },
  "reader_warm" => -> { REC.c1 },
  "load1_attributes" => -> { Item.find(1).attributes },
  "marshal_dump" => -> { Marshal.dump(REC) },
  "load1_marshal_dump" => -> { Marshal.dump(Item.find(1)) },
  "marshal_load" => -> { Marshal.load(DUMPED) },
  "msgpack_dump" => -> { MSGPACK.dump(REC) },
  "load1_msgpack_dump" => -> { MSGPACK.dump(Item.find(1)) },
  "attributes_for_database" => -> { REC.attributes_for_database },
  "load1_attributes_for_database" => -> { Item.find(1).attributes_for_database },
  "attributes_before_type_cast" => -> { REC.attributes_before_type_cast },
  "load1_attributes_before_type_cast" => -> { Item.find(1).attributes_before_type_cast },
  "load1_dump_save" => -> { r = Item.find(1); Marshal.dump(r); r.save },
  # The set's protected #attributes alone: main copies the row on each call, 8.1 returns its materialized Hash.
  "set_attributes" => -> { SET.send(:attributes) },
}

def run(fn, n)
  i = 0
  while i < n
    fn.()
    i += 1
  end
end

def jit_blocks = YJIT ? RubyVM::YJIT.runtime_stats[:compiled_block_count] : 0

IrWin.instr_on
names = ARGV.empty? ? CASES.keys : ["_empty", *ARGV]
names.each do |name|
  fn = CASES.fetch(name)
  run(fn, WARM)
  if YJIT
    flat = 0
    30.times do
      before = jit_blocks
      run(fn, WARM)
      flat = jit_blocks == before ? flat + 1 : 0
      break if flat == 3
    end
  end
  GC.start
  GC.disable
  allocs = GC.stat(:total_allocated_objects)
  jit = jit_blocks
  IrWin.zero
  run(fn, N)
  IrWin.dump(name)
  jit = jit_blocks - jit
  allocs = GC.stat(:total_allocated_objects) - allocs
  GC.enable
  puts JSON.generate(case: name, width: WIDTH, n: N, objects: allocs.fdiv(N).round(2), jit_blocks: jit)
end
