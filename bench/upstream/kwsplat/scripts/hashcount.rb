# Count #hash / #eql? calls for {k => v, **h} and m(k => v, **h) with custom keys
class K
  attr_reader :id
  def initialize(id) = @id = id
  def hash
    $h += 1
    raise "rehash" if $armed && id == 7 && ($seen[id] += 1) == 2
    id
  end
  def eql?(o) = ($e += 1; id == o.id)
end
def m(**kw) = kw
out = []
[0, 1, 2, 3, 6, 7, 8, 9, 12].each do |n|
  keys = (0..n).map { K.new(_1) }
  h = keys[1..].to_h { [_1, nil] }
  k = keys[0]; v = nil
  $armed = false
  $h = $e = 0; r = {k => v, **h}; lit = [$h, $e, r.size]
  $h = $e = 0; r = m(k => v, **h); call = [$h, $e, r.size]
  $h = $e = 0; r = {k => v, k2 = K.new(100) => 1, **h}; lit2 = [$h, $e, r.size]
  out << "n=#{n} literal #{lit} call #{call} 2pairs-literal #{lit2}"
end
# Sol's raise case: key 7's second #hash raises
[[8, :literal], [8, :call], [7, :literal], [7, :call], [9, :literal], [9, :call], [12, :call]].each do |n, kind|
  keys = (0..n).map { K.new(_1) }
  h = keys[1..].to_h { [_1, nil] }
  $h = $e = 0; $seen = Hash.new(0); $armed = true
  res = begin
    kind == :literal ? {keys[0] => nil, **h}.size : m(keys[0] => nil, **h).size
  rescue => e
    e.message
  end
  $armed = false
  out << "raise n=#{n} #{kind}: #{res}"
end
puts out
