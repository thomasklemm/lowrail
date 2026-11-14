# Differential probe for the ar_find_entry_hint fast path: run under base and fix, diff the output.
out = []
log = ->(label, v) { out << "#{label}: #{v.inspect}" }

class SelfUnequal
  def hash = 1
  def eql?(_) = false
end

class Counting
  attr_reader :calls
  def initialize(id) = (@id = id; @calls = 0)
  def hash = 7
  def eql?(o) = (@calls += 1; o.is_a?(Counting) && o.id == @id)
  protected attr_reader :id
end

class Converting
  def initialize(h) = @h = h
  def hash = 9
  def eql?(o)
    9.times { |i| @h[:"x#{i}"] = i } # grow the AR table into an st_table mid-lookup
    equal?(o)
  end
end

class MyHash < Hash; end

su = SelfUnequal.new
h = {su => 1, a: 2}
log.("self-unequal same object", [h[su], h.key?(su), h.fetch(su), h.delete(su), h.size])
log.("self-unequal other", {su => 1}[SelfUnequal.new])

nan = Float::NAN
h = {nan => 1}
log.("NaN same object", [h[nan], h[Float::NAN], h.key?(0.0 / 0.0)])

a, b, c = Counting.new(1), Counting.new(1), Counting.new(2)
h = {a => :a, c => :c}
log.("same object, eql? not called", [h[a], a.calls, c.calls])
log.("equal object, eql? called", [h[b], b.calls])
log.("hash collision different key", [h[Counting.new(3)]])

h = {}
conv = Converting.new(h)
h[conv] = 1
other = Converting.new(h)
log.("eql? converts to st_table", [h[other], h.size, h[conv]])

s = "key"
h = {s => 1}
log.("string keys", [h["key"], h[s], h[+"key"], h["key".freeze], h.keys[0].frozen?, h.keys[0].equal?(s)])

ih = {}.compare_by_identity
k1 = +"k"; k2 = +"k"
ih[k1] = 1
log.("identity", [ih[k1], ih[k2], ih["k"], ih.key?(k1), ih.size])
ih2 = {a: 1, b: 2}.compare_by_identity
log.("identity syms", [ih2[:a], ih2[:b], ih2[:c], ih2.compare_by_identity?])

h = {a: 1, b: 2, c: 3}
h.delete(:a)
log.("after delete", [h[:a], h[:b], h[:c], h.to_a])
h[:a] = 4
log.("reinsert", [h.to_a, h[:a]])
h[:b] = 5
log.("update existing", [h.to_a])

mh = MyHash[x: 1, y: 2]
log.("subclass", [mh[:x], mh.fetch(:y), mh.key?(:z), mh.class])

h = Hash.new { |hh, k| hh[k] = k.to_s * 2 }
log.("default proc", [h[:ab], h[:ab], h.size])

lit = {a: 1, b: 2, a: 3} rescue nil
log.("duplicate literal keys", eval("{a: 1, b: 2, a: 3}"))
v = 7
log.("literal with variables", {a: v, b: v, c: v, a: 9})

1.upto(10) do |n|
  hh = (0...n).to_h { [:"k#{_1}", _1] }
  hits = (0...n).map { hh[:"k#{_1}"] }
  log.("size #{n}", [hits, hh[:none], hh.key?(:"k#{n - 1}")])
end

# Many random keys: the same hints in both builds only with the same hash seed, so compare results, not order.
srand(1)
100.times do |t|
  keys = Array.new(rand(1..8)) { [rand(1000), rand(1000).to_s, :"s#{rand(1000)}", rand.round(3)].sample }
  hh = {}
  keys.each_with_index { |k, i| hh[k] = i }
  probe = keys + [rand(1000), rand(1000).to_s, :"s#{rand(1000)}"]
  log.("random #{t}", probe.map { hh[_1] })
end

puts out
