# Ir per call of m(a: v, **h) with h of SIZE entries; callee reads one keyword
def m(**kw) = kw[:a]
def run(h, v, n)
  i = 0
  while i < n
    m(a: v, **h)
    i += 1
  end
end
h = (1..Integer(ENV.fetch('SIZE'))).to_h { |i| [:"k#{i}", i] }
run(h, 1, 1000)
GC.start; GC.disable
run(h, 1, Integer(ENV.fetch('N')))
