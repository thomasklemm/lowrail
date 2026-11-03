def t1(a) = (r = []; a.each_index { |i| r << i; a.pop if i == 0 }; r)
def t2(a) = (r = []; a.each_index { |i| r << i; a << 9 if a.size < 6 }; r)
def t3(a) = a.each_index { |i| break i * 10 if i == 2 }
def t4(a) = a.each_index.to_a
def t5(a) = a.each_index.size
def t6(a) = (a.each_index { |i| }).equal?(a)
def t7(a) = (r = []; a.each_index { |i, j| r << [i, j] }; r)
def t8(a) = (r = []; a.each_index { |*x| r << x }; r)
def t9(a) = (a.each_index(&:itself) rescue $!.class)
def t10(a) = (r = []; a.each_index { |i| r << i; raise "x" if i == 1 } rescue r << $!.message; r)
def t11(a) = (r = []; a.each_index { |i| r << i; a.clear if i == 1 }; r)
def t12(a) = a.each_index.map { |i| next i * 2 if i.odd?; i }
class Sub < Array; end
def t13(a) = Sub.new(a).each_index.to_a
def t14(a) = (r = 0; a.each_index { r += 1; redo if r == 2 }; r)
def t15(a) = (x = a.each_index; x.next rescue $!.class)
out = []
4.times do
  [[1, 2, 3], [], [1], (1..10).to_a, [nil] * 4].each do |arr|
    out << (1..15).map { |n| begin send("t#{n}", arr.dup) rescue [$!.class, $!.message] end }
  end
end
out << (begin; [1,2].freeze.each_index { |i| }; rescue => e; e.class; end)
puts out.map(&:inspect)
