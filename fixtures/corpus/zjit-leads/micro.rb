# Minimal repros for ZJIT leads 3 and 7 (docs/upstream/zjit-leads.md).
#   ruby [--zjit|--yjit] micro.rb CASE [K [P]]
# K receiver classes for the lead 3 cases; the first warm window uses only the first P of them (default K),
# like a Rails site that is compiled while one request's models run and later sees the others.
# MODE=stats: warm, reset the JIT counters, N calls, print non-zero counters per call as JSON.
# MODE=callgrind (under valgrind --instr-atstart=no): warm until the JIT counters are flat over FLAT_WINDOWS
#   windows, then an empty window and an N-call window (bench/callgrind.c dumps); prints the gate as JSON.
N = Integer(ENV.fetch("N", 100_000))
WARM = Integer(ENV.fetch("WARM", 5_000))
# Each case method runs CHUNK calls and is called calls / CHUNK times, so the JITs compile the loop itself; the
# interpreted driver adds the same few instructions per chunk in every mode.
CHUNK = 100
FLAT_WINDOWS = Integer(ENV.fetch("FLAT_WINDOWS", 2))
CASE = ARGV.fetch(0)
K = Integer(ARGV.fetch(1, 1))
P = Integer(ARGV.fetch(2, K))

# Lead 3, instances: rails/rails#59141's shared slot reader. One ISEQ per slot, included in every model,
# calls a self method that every model resolves to the same entry.
module Slot
  def read_3 = read_at!(3)
end

class Model
  include Slot
  def initialize = @v = 1
  def read_at!(i) = @v
end

# Lead 3, singleton classes: a class-level method every model inherits (`klass.attribute_types`).
class Model
  def self.types = 1
end

MODELS = Array.new(K) { Class.new(Model) }
OBJS = MODELS.map(&:new)

def poly_inst(n, objs = OBJS)
  k = objs.size
  i = 0
  while i < n
    objs[i % k].read_3
    i += 1
  end
end

def poly_singleton(n, models = MODELS)
  k = models.size
  i = 0
  while i < n
    models[i % k].types
    i += 1
  end
end

# Lead 7: block arguments other than nil or a Proc.
class Cast
  # Rails' LazyIndexedAttributeSet#cast_value: yields only on the rare path.
  def cast_value(index) = index > 1_000_000_000 ? yield(index) : index

  # LazyIndexedAttributeSet#fetch_value_at! on Rails main: `cast_value(..., &:value!)`.
  def fetch_sym(index) = cast_value(index, &:succ)
  # The same call with a block literal.
  def fetch_literal(index) = cast_value(index) { |a| a.succ }

  # `def mon_synchronize(&b) = @mon_data.synchronize(&b)`: forward the block parameter.
  def forward(index, &b) = cast_value(index, &b)
end

C = Cast.new

def sym(n)
  c = C
  i = 0
  while i < n
    c.fetch_sym(i)
    i += 1
  end
end

def literal(n)
  c = C
  i = 0
  while i < n
    c.fetch_literal(i)
    i += 1
  end
end

def proxy(n)
  c = C
  i = 0
  while i < n
    c.forward(i) { |a| a }
    i += 1
  end
end

# Forwarding site that sees nil and the proxy (Rails 8.1's `_read_attribute(name, &block)`).
def mixed(n)
  c = C
  i = 0
  while i < n
    if i.even?
      c.forward(i) { |a| a }
    else
      c.forward(i)
    end
    i += 1
  end
end

def nilblock(n)
  c = C
  i = 0
  while i < n
    c.forward(i)
    i += 1
  end
end

CASES = %w[poly_inst poly_singleton sym literal proxy mixed nilblock].freeze
abort "unknown case #{CASE}" unless CASES.include?(CASE)
body = method(CASE)

def drive(body, calls, *args)
  i = 0
  reps = calls / CHUNK
  while i < reps
    body.call(CHUNK, *args)
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

require "json"
# Load before warmup: loading it later defines a constant, which invalidates JIT code inside the measured window.
if ENV["MODE"] == "callgrind"
  $LOAD_PATH.unshift(ENV.fetch("CG_EXT_DIR"))
  require "lowrail_callgrind"
end
drive(body, WARM, (CASE == "poly_inst" ? OBJS : MODELS).first(P)) if CASE.start_with?("poly")
flat = 0
history = []
last = jit_counters(jit)
8.times do
  drive(body, WARM)
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
  drive(body, 0)
  LowrailCallgrindBench.finish
  before = jit_counters(jit)
  LowrailCallgrindBench.start(false)
  drive(body, N)
  LowrailCallgrindBench.finish
  after = jit_counters(jit)
  gate = jit == :interp ? "n/a" : (flat == FLAT_WINDOWS && before == after ? "pass" : "fail")
  puts JSON.generate(case: CASE, k: K, jit:, n: N, gc: GC.count - gc0, gate:, warm: history, before:, after:)
else
  stats = jit == :zjit ? RubyVM::ZJIT : RubyVM::YJIT
  stats.reset_stats!
  drive(body, N)
  all = jit == :zjit ? stats.stats : stats.runtime_stats
  per_call = all.filter_map do |key, value|
    next unless value.is_a?(Integer) && value != 0
    next unless key.match?(/send|exit|dynamic|fallback|polymorph|megamorph|block|getivar/)
    next if key.match?(/time|bytes|_size\z/)
    [key, (value.fdiv(N)).round(3)]
  end.to_h
  puts JSON.generate(case: CASE, k: K, jit:, n: N, flat: flat == FLAT_WINDOWS, per_call:)
end
