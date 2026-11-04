# k.hash calls for m(k => v, **h, **n, z => v) with n = nil, vs. without **n
class K; def initialize(n) = @n = n; def hash = ($c[@n] += 1; @n.hash); def eql?(o) = o.is_a?(K) && hash == o.hash; end
def m(**kw) = kw
k = K.new(:k); z = K.new(:z); v = 1; n = nil
rows = (0..9).map do |s|
  h = (1..s).to_h { [:"h#{_1}", _1] }
  $c = Hash.new(0); m(k => v, **h, **n, z => v); a = $c[:k]
  $c = Hash.new(0); m(k => v, **h, z => v); b = $c[:k]
  $c = Hash.new(0); {k => v, **h, **n, z => v}; c = $c[:k]
  $c = Hash.new(0); {k => v, **h, z => v}; d = $c[:k]
  "#{s}:#{a}/#{b}/#{c}/#{d}"
end
puts rows.join(" ")
