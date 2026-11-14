# Keyword-splat size sweep under Callgrind (round 2, KW2 check).
#   valgrind --tool=callgrind --instr-atstart=no --callgrind-out-file=OUT.%p ruby -I CGEXT kw_sweep.rb CASES.json
# Each case runs once with 0 calls (seam) and once with N calls; Ir/call = (dump_N - dump_0) / N.
# Dumps are numbered in the order written to CASES.json. GC is excluded (collector segments toggled off).
require "lowrail_callgrind"
require "json"

def m(**kw) = kw
def m1(a: nil, **kw) = kw
class P; def z(e, a: 1, b: 2) = e; end
class C < P; def z(e, a: 1, b: 2) = super; end

def m0(a) = a
SHAPES = {
  "control: loop + lambda" => ->(v, h) { v },
  "control: m0(v)" => ->(v, h) { m0(v) },
  "control: m(a: v)" => ->(v, h) { m(a: v) },
  "control: {a: v}" => ->(v, h) { {a: v} },
  "control: h.dup" => ->(v, h) { h.dup },
  "m(a: v, **h)" => ->(v, h) { m(a: v, **h) },
  "{a: v, **h}" => ->(v, h) { {a: v, **h} },
  "m(**h, a: v)" => ->(v, h) { m(**h, a: v) },
  "{**h}" => ->(v, h) { {**h} },
  "m(**h)" => ->(v, h) { m(**h) },
  "m(a: v, b: v, c: v, **h)" => ->(v, h) { m(a: v, b: v, c: v, **h) },
}
SIZES = (ENV["SIZES"] || "0,1,2,3,5,7,8,9,16,64,1000,100000").split(",").map(&:to_i)
c = C.new
cases = []
dump = 0
run = lambda do |name, size, n, &blk|
  GC.start
  LowrailCallgrindBench.start(true); LowrailCallgrindBench.finish; dump += 1; seam = dump
  GC.start
  LowrailCallgrindBench.start(true); n.times(&blk); LowrailCallgrindBench.finish; dump += 1
  cases << { shape: name, size:, n:, seam:, dump: }
end
SIZES.each do |size|
  h = (0...size).to_h { |i| [:"k#{i}", i] }
  n = size >= 100_000 ? 10 : size >= 1000 ? 200 : 20_000
  SHAPES.each do |name, f|
    v = 2
    200.times { f.(v, h) }
    run.(name, size, n) { f.(v, h) }
  end
end
200.times { c.z(1) }
run.("zsuper with keywords", 0, 20_000) { c.z(1) }
File.write(ARGV.fetch(0), JSON.pretty_generate(ruby: RUBY_DESCRIPTION, jit: (defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?) ? "yjit" : "interp", cases:))
