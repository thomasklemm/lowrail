def m(**kw) = kw[:a]
def run(h, v, n)
  i = 0
  while i < n
    m(a: v, **h)
    i += 1
  end
end
res = [0, 1, 2, 3, 8].map do |s|
  h = (1..s).to_h { [:"k#{_1}", _1] }
  run(h, 1, 200_000)
  best = 3.times.map { t = Process.clock_gettime(Process::CLOCK_MONOTONIC); run(h, 1, 2_000_000); Process.clock_gettime(Process::CLOCK_MONOTONIC) - t }.min
  "#{s}:#{(best * 1e9 / 2_000_000).round(1)}"
end
puts res.join(" ")
