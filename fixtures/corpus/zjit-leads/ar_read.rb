# First reads of loaded records on Rails main (rails/rails#59141's slot readers), with and without a block
# literal in place of `&:value!` in LazyIndexedAttributeSet (docs/upstream/zjit-leads.md, lead 7).
#   VARIANT=sym|literal MODE=stats|callgrind ruby [--zjit|--yjit] ar_read.rb   (BUNDLE_GEMFILE: Rails main + sqlite3)
# One op instantiates 10 records from a cached result and reads their 5 attributes once (50 slot reads, each
# the first read of that attribute). Both variants redefine the two methods the same way, so they differ only
# in the block argument.
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
VARIANT = ENV.fetch("VARIANT")
cast = { "sym" => "cast_value(%s, index, &:value!)",
         "literal" => "cast_value(%s, index) { |attribute| attribute.value! }" }.fetch(VARIANT)

ActiveModel::LazyIndexedAttributeSet.class_eval <<~RUBY, __FILE__, __LINE__ + 1
  def fetch_value_at!(index)
    value = @casted_values.fetch(index, UNCAST)
    return value unless UNCAST.equal?(value)

    if (attrs = @attributes) && (attr = attrs[index])
      cache_value_at(index, attr.value!)
    else
      #{cast % "@ctx.name_at(index)"}
    end
  end

  private def value_at!(index, name)
    value = @casted_values.fetch(index, UNCAST)
    return value unless UNCAST.equal?(value)

    if (attrs = @attributes) && (attr = attrs[index])
      cache_value_at(index, attr.value!)
    else
      #{cast % "name"}
    end
  end
RUBY

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table :posts do |t|
    t.string :title
    t.text :body
    t.integer :score
    t.boolean :published
  end
end

class Post < ActiveRecord::Base; end
10.times { |i| Post.create!(title: "t#{i}", body: "b" * 40, score: i, published: i.even?) }
RESULT = Post.connection.select_all(Post.all.arel)

def op(n)
  i = 0
  while i < n
    Post._load_from_sql(RESULT).each do |post|
      post.id
      post.title
      post.body
      post.score
      post.published
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

check = Post._load_from_sql(RESULT).map { |p| [p.id, p.title, p.body.size, p.score, p.published] }
abort "wrong values" unless check == 10.times.map { |i| [i + 1, "t#{i}", 40, i, i.even?] }

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
  puts JSON.generate(variant: VARIANT, jit:, n: N, gc: GC.count - gc0, gate:, warm: history, before:, after:)
else
  stats = jit == :zjit ? RubyVM::ZJIT : RubyVM::YJIT
  stats.reset_stats!
  op(N)
  all = jit == :zjit ? stats.stats : stats.runtime_stats
  keys = %i[dynamic_send_count send_fallback_send_block_arg_not_nil num_send_dynamic send_iseq_block_arg_type send_megamorphic]
  puts JSON.generate(variant: VARIANT, jit:, n: N, flat: flat == FLAT_WINDOWS,
    per_op: all.slice(*keys).transform_values { |v| v.fdiv(N).round(2) })
end
