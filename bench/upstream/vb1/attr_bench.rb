# frozen_string_literal: true

# VB1 per-call micro: first attribute reads and record paths at a given table width, every case in one process.
#   RAILS=<tree> BUNDLE_GEMFILE=<suite for tree> WIDTH=30 N=200 valgrind --tool=callgrind --instr-atstart=no \
#     --callgrind-out-file=DIR/cg.%p ruby [--yjit|--zjit] attr_bench.rb [CASE...]
# Same windows as bench/upstream/k1/attr_bench.rb: warmup, then GC.start and GC.disable around one window of N calls
# that IrWin zeroes before and dumps after. Under a JIT, warmup repeats windows of WARM calls until three in a row
# change no JIT counter (at most 30); the line reports the counters' change in the measured window (gate wants 0).
require "bundler/setup"
require "json"
# STATS=1 (with --yjit-stats or --zjit-stats, no Valgrind): JIT counters per call of the window instead of Ir.
STATS = ENV["STATS"] == "1"
if STATS
  module IrWin
    def self.instr_on = nil
    def self.zero = (defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled? ? RubyVM::ZJIT : RubyVM::YJIT).reset_stats!
    def self.dump(_) = nil
  end
  COUNTERS = %i[send_iseq_block_arg_type send_fallback_send_block_arg_not_nil dynamic_send_count
    num_send_dynamic yjit_insns_count zjit_insn_count side_exit_count]
  def stats_per_call(n)
    all = defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled? ? RubyVM::ZJIT.stats : RubyVM::YJIT.runtime_stats
    all.slice(*COUNTERS).transform_values { |v| v.fdiv(n).round(2) }
  end
else
  $LOAD_PATH.unshift(ENV.fetch("IRWIN_DIR"))
  require "irwin"
end
require "active_record"

rails = ENV.fetch("RAILS")
unless ActiveRecord::Base.method(:find).source_location.first.start_with?(File.expand_path(rails) + "/")
  abort "Active Record not loaded from #{rails}"
end

WIDTH = Integer(ENV.fetch("WIDTH", "30"))
N = Integer(ENV.fetch("N", "200"))
WARM = Integer(ENV.fetch("WARM", "100"))
YJIT = defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
ZJIT = defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?

# No pool reaper thread: it wakes on a timer and its work lands in some windows.
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:", reaping_frequency: 0)
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
class Item < ActiveRecord::Base
  # Every reader once, as direct calls: id (fetch_value! -> value_at!), then the generated slot readers
  # (fetch_value_at!).
  class_eval "def self.read_all(r) = (r.id; r.type; #{COLS.map { |n, _| "r.#{n}" }.join("; ")})"
end

VALUES = COLS.to_h { |name, type| [name, type == :string ? "value #{name}" : name.delete("c").to_i] }
10.times { Item.create!(VALUES) }
REC = Item.find(1)
ROWS = Item.connection.select_all(Item.where(id: 1..10).arel)
abort "rows" unless ROWS.length == 10
check = Item._load_from_sql(ROWS).map { |r| [Item.read_all(r), r.attributes] }
ok = check.each_with_index.all? { |(last, h), i| last == VALUES[COLS.last[0]] && h == { "id" => i + 1, "type" => nil }.merge(VALUES) }
abort "values" unless ok

CASES = {
  "_empty" => -> { },
  "load1" => -> { Item.find(1) },
  "load1_read_all" => -> { Item.read_all(Item.find(1)) },
  "load1_id" => -> { Item.find(1).id },
  "rows10" => -> { Item._load_from_sql(ROWS) },
  "rows10_read_all" => -> { Item._load_from_sql(ROWS).each { |r| Item.read_all(r) } },
  "reader_warm" => -> { REC.c1 },
  "read_all_warm" => -> { Item.read_all(REC) },
  "load1_attributes" => -> { Item.find(1).attributes },
  "load1_serializable_hash" => -> { Item.find(1).serializable_hash },
  "load1_dup" => -> { Item.find(1).dup },
  "dup_warm" => -> { REC.dup },
  "new" => -> { Item.new(c1: "n") },
}

def run(fn, n)
  i = 0
  while i < n
    fn.()
    i += 1
  end
end

def jit_counters
  if YJIT
    RubyVM::YJIT.runtime_stats.values_at(:compiled_iseq_count, :compiled_block_count, :invalidation_count)
  elsif ZJIT
    RubyVM::ZJIT.stats.values_at(:compiled_iseq_count, :compiled_side_exit_count, :invalidation_time_ns)
  else
    []
  end
end

IrWin.instr_on
names = ARGV.empty? ? CASES.keys : ["_empty", *ARGV]
names.each do |name|
  fn = CASES.fetch(name)
  run(fn, WARM)
  flat = 0
  if YJIT || ZJIT
    30.times do
      before = jit_counters
      run(fn, WARM)
      flat = jit_counters == before ? flat + 1 : 0
      break if flat == 3
    end
  end
  GC.start
  GC.disable
  allocs = GC.stat(:total_allocated_objects)
  gcs = GC.count
  jit = jit_counters
  IrWin.zero
  run(fn, N)
  IrWin.dump(name)
  stats = stats_per_call(N) if STATS
  delta = jit_counters.zip(jit).map { |a, b| a - b }
  allocs = GC.stat(:total_allocated_objects) - allocs
  gcs = GC.count - gcs
  GC.enable
  gate = (YJIT || ZJIT) ? (flat == 3 && delta.all?(&:zero?) ? "pass" : "fail") : "n/a"
  puts JSON.generate(case: name, width: WIDTH, n: N, objects: allocs.fdiv(N).round(2), gc: gcs, gate: gate, jit_delta: delta,
    **(STATS ? { stats: stats } : {}))
end
