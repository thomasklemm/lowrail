def a(&b) = [b.class, b&.lambda?, block_given?, (yield 1 rescue $!.class)]
def o(x = 1, *r, k: 2, &b) = [x, r, k, b.class, block_given?, (b ? b.(5) : nil), (yield 3 rescue $!.class)]
def re(&b) = (b = nil; [b, block_given?, (yield 2 rescue $!.class)])
def ident(&b) = b
def bg(&b) = block_given?
def nested(&b) = a(&b)
def nested2(&b) = o(9, &b)
def proc_from(&b) = b
class C; def to_proc = proc { |x| [:c, x] }; end
M = 10.method(:+)
def run(blk)
  [a(&blk), o(&blk), o(1, 2, 3, k: 4, &blk), re(&blk), (ident(&blk).equal?(blk) rescue $!.class), bg(&blk),
   nested(&blk), nested2(&blk), (proc_from(&blk)&.call(7) rescue $!.class)]
end
inputs = [proc { |x| x }, lambda { |x| x * 2 }, :to_s, nil, M, C.new, proc { |*x| x }, lambda { |x, y = 1| [x, y] }, proc { |x, y| [x, y] }]
out = []
3.times { inputs.each_with_index { |i, n| out << [n, (run(i) rescue [$!.class, $!.message])] } }
# mix call sites polymorphically
inputs.reverse.each_with_index { |i, n| out << [:rev, n, (run(i) rescue [$!.class, $!.message])] }
p out.hash
puts out.map(&:inspect)
