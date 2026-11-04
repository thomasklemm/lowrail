class K; attr_reader :id; def initialize(i)=@id=i; def hash = id; def eql?(o) = ($e += 1; id == o.id); end
k0, k1 = K.new(0), K.new(1)
$e = 0; h = {k0 => 1}; h.update({k1 => 2}); a = $e
$e = 0; h = {k0 => 1}; h[k1] = 2; b = $e
$e = 0; h = {}; h[k0] = 1; h[k1] = 2; c = $e
p [a, b, c]
