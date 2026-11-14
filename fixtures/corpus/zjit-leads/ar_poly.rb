# Lead 3 on Rails main: rails/rails#59141's slot reader `_read_attribute_N` is one method shared by every model
# and calls `_read_attribute_at!` on self. K models with the same columns; the first window loads only the first
# P of them (a site compiled while one request's models ran), then every op loads all K.
#   MODE=stats|callgrind ruby [--zjit|--yjit] ar_poly.rb K P   (BUNDLE_GEMFILE: Rails main + sqlite3)
require "bundler/setup"
require "active_record"
require "json"
# Load before warmup: loading it later defines a constant, which invalidates JIT code inside the measured window.
if ENV["MODE"] == "callgrind"
  $LOAD_PATH.unshift(ENV.fetch("CG_EXT_DIR"))
  require "lowrail_callgrind"
end

N = Integer(ENV.fetch("N", 2_000))
WARM = Integer(ENV.fetch("WARM", 500))
FLAT_WINDOWS = 2
K = Integer(ARGV.fetch(0))
P = Integer(ARGV.fetch(1))

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
MODELS = Array.new(K) do |m|
  ActiveRecord::Schema.define do
    create_table :"posts#{m}" do |t|
      t.string :title
      t.integer :score
    end
  end
  model = Class.new(ActiveRecord::Base) { self.table_name = "posts#{m}" }
  Object.const_set(:"Post#{m}", model)
  2.times { |i| model.create!(title: "t#{i}", score: i) }
  # Load each model's readers before timing.
  model.first.title
  [model, model.connection.select_all(model.all.arel)]
end

def op(n, models = MODELS)
  i = 0
  while i < n
    models.each do |model, result|
      model._load_from_sql(result).each do |post|
        post.title
        post.score
      end
    end
    i += 1
  end
end

jit = if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled? then :zjit
      elsif defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled? then :yjit
      else :interp
      end

def jit_counters(jit)
  case jit
  when :zjit then RubyVM::ZJIT.stats.slice(:compiled_iseq_count, :compiled_side_exit_count, :invalidation_time_ns)
  when :yjit then RubyVM::YJIT.runtime_stats.slice(:compiled_iseq_count, :compiled_block_count, :invalidation_count)
  end
end

op(WARM, MODELS.first(P))
flat = 0
history = []
last = jit_counters(jit)
8.times do
  op(WARM)
  now = jit_counters(jit)
  flat = now == last ? flat + 1 : 0
  history << now
  last = now
  break if flat == FLAT_WINDOWS
end

if ENV["MODE"] == "callgrind"
  3.times { GC.start }
  gc0 = GC.count
  LowrailCallgrindBench.start(false)
  op(0)
  LowrailCallgrindBench.finish
  before = jit_counters(jit)
  LowrailCallgrindBench.start(false)
  op(N)
  LowrailCallgrindBench.finish
  after = jit_counters(jit)
  gate = jit == :interp ? "n/a" : (flat == FLAT_WINDOWS && before == after ? "pass" : "fail")
  puts JSON.generate(k: K, p: P, jit:, n: N, gc: GC.count - gc0, gate:, warm: history, before:, after:)
else
  stats = jit == :zjit ? RubyVM::ZJIT : RubyVM::YJIT
  stats.reset_stats!
  op(N)
  all = jit == :zjit ? stats.stats : stats.runtime_stats
  keys = %i[dynamic_send_count send_fallback_send_polymorphic_fallback send_fallback_send_block_arg_not_nil
    num_send_dynamic send_megamorphic send_iseq_block_arg_type num_send_polymorphic]
  puts JSON.generate(k: K, p: P, jit:, n: N, flat: flat == FLAT_WINDOWS,
    per_op: all.slice(*keys).transform_values { |v| v.fdiv(N).round(2) })
end
