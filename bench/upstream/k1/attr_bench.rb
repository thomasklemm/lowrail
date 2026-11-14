# frozen_string_literal: true

# K1 per-call micro: Active Record record paths at a given table width, every case in one process.
#   BUNDLE_GEMFILE=<suite for TREE> WIDTH=30 N=200 valgrind --tool=callgrind --instr-atstart=no \
#     --callgrind-out-file=DIR/cg.%p ruby [--yjit] attr_bench.rb [CASE...]
# Each case runs warmup calls, then GC.start and GC.disable around one window of N calls, which IrWin zeroes
# before and dumps after (stock Callgrind client requests, irwin.c built into IRWIN_DIR). Prints one JSON line
# per case with objects per call and, under YJIT, the blocks compiled in the window (the JIT-flat gate wants 0).
# Under YJIT, warmup repeats windows of WARM calls until three in a row compile nothing (at most 30).
require "bundler/setup"
require "json"
$LOAD_PATH.unshift(ENV.fetch("IRWIN_DIR", File.expand_path("~/k1/ext")))
require "irwin"
require "active_record"

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
# id and type, then WIDTH - 2 columns alternating string and integer.
COLS = (1..WIDTH - 2).map { |i| ["c#{i}", i.odd? ? :string : :integer] }
ActiveRecord::Schema.define do
  create_table(:items) do |t|
    t.string :type
    COLS.each { |name, type| t.column name, type }
  end
end
class Item < ActiveRecord::Base; end
class Special < Item; attribute :extra, :string; end

VALUES = COLS.to_h { |name, type| [name, type == :string ? "value #{name}" : name.delete("c").to_i] }
Item.create!(VALUES)                 # 1
Special.create!(VALUES)              # 2
Item.create!(VALUES)                 # 3, for writes
REC = Item.find(1)
WREC = Item.find(3)
PARTIAL = Item.select(:id, :c1).where(id: 1)
counter = 0

CASES = {
  "_empty" => -> { },
  "load1" => -> { Item.find(1) },
  "reader_warm" => -> { REC.c1 },
  "load1_attributes" => -> { Item.find(1).attributes },
  "attribute_names_warm" => -> { REC.attribute_names },
  "changed?_warm" => -> { REC.changed? },
  "load1_changed?" => -> { Item.find(1).changed? },
  "load1_assign_changes" => -> { r = Item.find(1); r.c1 = "x"; r.changes },
  "load1_save" => -> { Item.find(1).save },
  "update1" => -> { WREC.update!(c2: (counter += 1)) },
  "load1_update1" => -> { Item.find(3).update!(c2: (counter += 1)) },
  "load1_dup" => -> { Item.find(1).dup },
  "serializable_hash_warm" => -> { REC.serializable_hash },
  "load1_as_json" => -> { Item.find(1).as_json },
  "partial_changed?" => -> { PARTIAL.first.changed? },
  "partial_as_json" => -> { PARTIAL.first.as_json },
  "sti_load1_changed?" => -> { Item.find(2).changed? },
  "sti_load1_attributes" => -> { Item.find(2).attributes },
  "new" => -> { Item.new(c1: "n") },
  "new_changed?" => -> { Item.new(c1: "n").changed? },
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
