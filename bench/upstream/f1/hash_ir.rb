# Ir per operation for small and large Hash lookups and inserts (F1, ruby master round 2).
# Run under Callgrind with --instr-atstart=no and the lowrail_callgrind extension on -I:
#   valgrind --tool=callgrind --instr-atstart=no --callgrind-out-file=OUT/cg.%p ruby -I CGEXT hash_ir.rb OUT/cases.json
# Each case runs its setup and 0, then N, iterations of one expression in a while loop, each in its own
# Callgrind window (two dumps per case, in cases order); Ir per op = (W(N) - W(0)) / N, loop included.
# "empty" is the same loop with `x = h`.
require "lowrail_callgrind"
require "json"

N = Integer(ENV.fetch("N", 200_000))
WARM = 2_000
JIT_WARM = 100

# JIT-flat gate (docs/bench.md): no compilation or invalidation between the end of the N=0 window and the end of the
# N window, so the difference of the two windows holds no JIT work. The polymorphic send(m, ...) into each case may
# compile a block version in the N=0 window; that cost is in both windows and cancels.
def jit_counters
  if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?
    RubyVM::ZJIT.stats.slice(:compiled_iseq_count, :compiled_side_exit_count, :invalidation_time_ns)
  elsif defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?
    RubyVM::YJIT.runtime_stats.slice(:compiled_iseq_count, :compiled_block_count, :invalidation_count)
  end
end

def keys(n) = (0...n).map { :"k#{_1}" }
def sym_hash(n) = keys(n).to_h { [_1, 1] }

cases = {}
add = ->(name, setup, expr) { cases[name] = [setup, expr] }

add.("empty", "h = {k0: 1}", "h")
(1..8).each do |n|
  add.("aref sym n=#{n} first", "h = sym_hash(#{n})", "h[:k0]")
  add.("aref sym n=#{n} last", "h = sym_hash(#{n})", "h[:k#{n - 1}]")
  add.("aref sym n=#{n} miss", "h = sym_hash(#{n})", "h[:zz]")
end
add.("aref sym n=3 :b", "h = {a: 1, b: 2, c: 3}", "h[:b]")
[9, 16, 64, 1000].each do |n|
  add.("aref sym n=#{n} hit", "h = sym_hash(#{n})", "h[:k#{n / 2}]")
  add.("aref sym n=#{n} miss", "h = sym_hash(#{n})", "h[:zz]")
end
add.("aref str n=3 same", "h = {'a' => 1, 'b' => 2, 'c' => 3}; k = h.keys[1]", "h[k]")
add.("aref str n=3 equal", "h = {'a' => 1, 'b' => 2, 'c' => 3}; k = +'b'", "h[k]")
add.("aref str n=3 miss", "h = {'a' => 1, 'b' => 2, 'c' => 3}; k = +'z'", "h[k]")
add.("aref int n=3", "h = {1 => 1, 2 => 2, 3 => 3}", "h[2]")
add.("aref sym n=3 fetch", "h = {a: 1, b: 2, c: 3}", "h.fetch(:b)")
add.("aref sym n=3 key?", "h = {a: 1, b: 2, c: 3}", "h.key?(:b)")
add.("aref sym n=0 miss", "h = {}", "h[:a]")
# ruby/ruby#18222's benchmark/hash_ar_aref.yml (8 keys), one lookup per iteration
add.("ar_aref hit_first", "h = {a:1, b:2, c:3, d:4, e:5, f:6, g:7, h:8}", "h[:a]")
add.("ar_aref hit_third", "h = {a:1, b:2, c:3, d:4, e:5, f:6, g:7, h:8}", "h[:c]")
add.("ar_aref hit_fourth", "h = {a:1, b:2, c:3, d:4, e:5, f:6, g:7, h:8}", "h[:d]")
add.("ar_aref hit_last", "h = {a:1, b:2, c:3, d:4, e:5, f:6, g:7, h:8}", "h[:h]")
add.("ar_aref miss", "h = {a:1, b:2, c:3, d:4, e:5, f:6, g:7, h:8}", "h[:_]")
add.("ar_aref miss_empty", "h = {}", "h[:a]")
# compare_by_identity (ruby/ruby#18476 made these AR tables)
[1, 3, 8].each do |n|
  add.("ident sym n=#{n} last", "h = sym_hash(#{n}).compare_by_identity", "h[:k#{n - 1}]")
  add.("ident sym n=#{n} miss", "h = sym_hash(#{n}).compare_by_identity", "h[:zz]")
end
add.("ident obj n=3 hit", "o = Array.new(3) { Object.new }; h = {}.compare_by_identity; o.each { h[_1] = 1 }; k = o[1]", "h[k]")
add.("ident str n=3 hit", "o = %w[a b c].map(&:dup); h = {}.compare_by_identity; o.each { h[_1] = 1 }; k = o[1]", "h[k]")
add.("ident new n=3", "o = Array.new(3) { Object.new }; a, b, c = o", "g = {}.compare_by_identity; g[a] = 1; g[b] = 2; g[c] = 3; g")
# inserts
(1..8).each do |n|
  add.("literal n=#{n}", "v = 2", "{" + keys(n).map { "#{_1}: v" }.join(", ") + "}")
end
[9, 16].each { |n| add.("literal n=#{n}", "v = 2", "{" + keys(n).map { "#{_1}: v" }.join(", ") + "}") }
add.("literal str n=3", "v = 2", "{'a' => v, 'b' => v, 'c' => v}")
add.("aset new n=2", "v = 2", "g = {}; g[:a] = v; g[:b] = v; g")
add.("aset new n=3", "v = 2", "g = {}; g[:a] = v; g[:b] = v; g[:c] = v; g")
add.("aset existing n=3", "h = {a: 1, b: 2, c: 3}; v = 2", "h[:b] = v")
add.("aset existing n=1000", "h = sym_hash(1000); v = 2", "h[:k500] = v")
add.("merge n=3", "h = {a: 1, b: 2, c: 3}; o = {b: 5}", "h.merge(o)")
add.("dup n=3 literal", "h = {a: 1, b: 2, c: 3}", "h.dup")
add.("kwargs n=3", "def kw(a:, b:, c:) = b; v = 2", "kw(a: v, b: v, c: v)")

if (only = ENV["CASES"])
  cases.select! { |name, _| only.split(",").include?(name) }
end
out = ARGV.fetch(0)
results = {}
# Define every case's method first, then warm all, then measure: defining a method on Object after the JIT
# compiled code invalidates it, so no definition happens once warmup starts. Under a JIT the harness's own
# block compiles after ~30 calls; it runs on throwaway "empty" windows first, whose dumps the report skips.
names = cases.keys
names.each_with_index do |name, idx|
  setup, expr = cases.fetch(name)
  Object.class_eval(<<~RUBY, name)
    def run_case_#{idx}(n)
      #{setup}
      i = 0
      x = nil
      while i < n
        x = #{expr}
        i += 1
      end
      x
    end
  RUBY
end
names.each_index do |idx|
  send(:"run_case_#{idx}", WARM)
  JIT_WARM.times { send(:"run_case_#{idx}", 10) }
end
warm_harness = jit_counters ? 40 : 0
plan = [0] * warm_harness + names.each_index.to_a
plan.each_with_index do |idx, step|
  m = :"run_case_#{idx}"
  GC.start
  LowrailCallgrindBench.start(false)
  send(m, 0)
  LowrailCallgrindBench.finish
  before = jit_counters
  GC.start
  LowrailCallgrindBench.start(false)
  send(m, N)
  LowrailCallgrindBench.finish
  results[names[idx]] = { n: N, jit_flat: before == jit_counters } if step >= warm_harness
end
File.write(out, JSON.pretty_generate(cases: results.keys, skip_dumps: 2 * warm_harness, n: N, ruby: RUBY_DESCRIPTION, jit_flat: results.transform_values { _1[:jit_flat] }))
