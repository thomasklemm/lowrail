def m(**kw) = kw
class P; def d(e, url_safe: false) = e; end
class C < P; def d(e, url_safe: true) = super; end
v = 2; c = C.new
h0 = {}; h1 = {k: 1}; h3 = {k: 1, l: 2, n: 3}; h7 = (1..7).to_h { [:"k#{_1}", _1] }
cases = {
  "m(a:,b:,c:, **h0)" => -> { i = 0; while i < 2_000_000; m(a: v, b: v, c: v, **h0); i += 1; end },
  "m(a: v, **h1)" => -> { i = 0; while i < 2_000_000; m(a: v, **h1); i += 1; end },
  "m(a:,b:,c:, **h1)" => -> { i = 0; while i < 2_000_000; m(a: v, b: v, c: v, **h1); i += 1; end },
  "m(a: v, **h3)" => -> { i = 0; while i < 2_000_000; m(a: v, **h3); i += 1; end },
  "m(a: v, **h7)" => -> { i = 0; while i < 2_000_000; m(a: v, **h7); i += 1; end },
  "zsuper kw" => -> { i = 0; while i < 2_000_000; c.d(1); i += 1; end },
}
cases.each do |name, f|
  f.call
  t = 5.times.map { s = Process.clock_gettime(Process::CLOCK_MONOTONIC); f.call; Process.clock_gettime(Process::CLOCK_MONOTONIC) - s }.sort[2]
  printf("%-20s %6.1f ns/call\n", name, t * 1e9 / 2_000_000)
end
