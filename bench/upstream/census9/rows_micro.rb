# frozen_string_literal: true

# Census 9: Ir and objects per loaded row of _load_from_sql on a cached result
# of ROWS rows (1, 20, 1000, 10000) and WIDTH columns, for a Rails checkout in
# RAILS. Size sweep for AT-1 and K1. IrCount under census 8's patched
# Callgrind, --instr-atstart=no; prints "load ROWS WIDTH Ir/row obj/row jit".
rails = ENV.fetch("RAILS")
%w[activesupport activemodel activerecord].each { |c| $LOAD_PATH.unshift(File.join(rails, c, "lib")) }
require "active_support"
require "active_record"
require ENV.fetch("IR_COUNT_SO", File.expand_path("~/c9/ext/ir_count.so"))

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Base.logger = nil
ActiveRecord::Migration.verbose = false
width = Integer(ENV.fetch("WIDTH", "5"))
cols = (1..[width - 3, 2].max).map { "c#{_1}" }
ActiveRecord::Schema.define do
  create_table(:items) { |t| cols.each { |c| t.string c }; t.timestamps }
end
class Item < ActiveRecord::Base; end
rows = Integer(ENV.fetch("ROWS", "20"))
now = Time.utc(2026, 1, 1)
Item.insert_all!(Array.new(rows) { |i| cols.to_h { [_1, "v#{i}"] }.merge(created_at: now, updated_at: now) })
RESULT = Item.connection.select_all(Item.all.arel)
raise unless RESULT.length == rows

yjit = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
blocks = -> { yjit ? RubyVM::YJIT.runtime_stats[:compiled_block_count] : 0 }
reps = [2000 / rows, 1].max
fn = -> { Item._load_from_sql(RESULT) }
IrCount.start if IrCount.running?
[reps * 3, 5].max.times { fn.() }
if yjit
  flat = 0
  30.times { b = blocks.(); reps.times { fn.() }; flat = blocks.() == b ? flat + 1 : 0; break if flat == 3 }
end
GC.start
GC.disable
b0 = blocks.()
o0 = GC.stat(:total_allocated_objects)
i0 = IrCount.now
reps.times { fn.() }
i1 = IrCount.now
o1 = GC.stat(:total_allocated_objects)
puts format("load %d %d %10.1f %7.2f %d", rows, width, (i1 - i0).fdiv(reps * rows), (o1 - o0).fdiv(reps * rows), blocks.() - b0)
