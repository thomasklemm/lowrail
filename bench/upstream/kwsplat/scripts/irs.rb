# Ir per call of m(**h, &b) (single mutable keyword splat) with h of SIZE entries
def m(**kw) = kw[:a]
def b = nil
def run(h, n)
  i = 0
  while i < n
    m(**h, &b)
    i += 1
  end
end
h = (1..Integer(ENV.fetch('SIZE'))).to_h { |i| [:"k#{i}", i] }
run(h, 1000)
GC.start; GC.disable
run(h, Integer(ENV.fetch('N')))
