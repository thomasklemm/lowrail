# Differential probes for surplus-arg yields into simple ISEQ blocks (RUBY19659).
# Output must be identical in the interpreter and under ZJIT at any threshold:
#   ruby probes.rb; ruby --zjit-call-threshold=1 probes.rb; ruby --zjit-call-threshold=2 probes.rb
V = [10, 20, 30, 40, 50]
out = []
probe = lambda do |name, &b|
  r = 4.times.map do
    b.call
  rescue => e
    "#{e.class}: #{e.message}"
  end
  out << "#{name}: #{r.uniq.map(&:inspect).join(' | ')}"
end

# argc 0..5 into lead 0..3, asymmetric values
(0..5).each do |argc|
  args = V.first(argc).join(", ")
  [[0, "{ :none }"], [1, "{ |a| [a] }"], [2, "{ |a, b| [a, b] }"], [3, "{ |a, b, c| [a, b, c] }"]].each do |lead, blk|
    eval "def y#{argc}_#{lead} = yield(#{args}); def c#{argc}_#{lead} = y#{argc}_#{lead} #{blk}"
    probe.("argc=#{argc} lead=#{lead}") { send("c#{argc}_#{lead}") }
  end
end

# auto-splat and trailing comma
def y1(x) = yield(x)
def y2(x, z) = yield(x, z)
probe.("splat |a,b| [5,6]") { y1([5, 6]) { |a, b| [a, b] } }
probe.("splat |a,| [5,6]") { y1([5, 6]) { |a,| a } }
probe.("splat |a,| (5,6)") { y2(5, 6) { |a,| a } }
probe.("splat |a| [5,6]") { y1([5, 6]) { |a| a } }
probe.("splat _1 [5,6]") { y1([5, 6]) { _1 } }
probe.("splat it [5,6]") { y1([5, 6]) { it } }
probe.("_1,_2 (5,6)") { y2(5, 6) { [_1, _2] } }
probe.("_1 (5,6)") { y2(5, 6) { _1 } }
probe.("|a,(b,c)| (1,[2,3])") { y2(1, [2, 3]) { |a, (b, c)| [a, b, c] } }
class Duck; attr_reader :n; def initialize = @n = 0; def to_ary = (@n += 1; [:d1, :d2]); end
probe.("duck into |a,b|") { d = Duck.new; [y1(d) { |a, b| [a, b] }, d.n] }
probe.("duck into no params") { d = Duck.new; [y1(d) { :none }, d.n] }
probe.("duck surplus into |a|") { d = Duck.new; [y2(1, d) { |a| a }, d.n] }
class Sub < Array; end
probe.("Array subclass into |a,b|") { y1(Sub[7, 8]) { |a, b| [a, b] } }

# dropped args are evaluated, in order, with side effects and exceptions
def ylog(log) = yield(log << :a, log << :b, log << :c)
probe.("dropped args order") { log = []; [ylog(log) { |x| x.size }, log] }
def yraise = yield(1, raise(ArgumentError, "dropped"))
probe.("dropped arg raises") { yraise { |a| a } }

# lambdas, procs, nonlocal exit, too few
def y12 = yield(1, 2)
probe.("lambda arity") { y12(&->(a) { a }) }
probe.("proc surplus") { y12(&proc { |a| a }) }
probe.("break with surplus") { y12 { |a| break a * 100 } }
probe.("too few |a,b,c|") { y1(1) { |a, b, c| [a, b, c] } }
probe.("rest |a,*r|") { y12 { |a, *r| [a, r] } }
probe.("opt |a,b=9|") { y1(1) { |a, b = 9| [a, b] } }

# block side exit with live caller values, GC with heap args
def yside(x) = [0, yield(x, 2), 3]
probe.("side exit fixnum") { yside(1) { |a| a + 1 } }
probe.("side exit float") { [yside(1) { |a| a + 1 }, yside(1.5) { |a| a + 1 }, yside(1) { |a| a + 1 }] }
def yheap = yield("s" * 3, [1, 2], { k: 1 })
probe.("GC with heap args") { yheap { |a| GC.start; a.dup } }
probe.("times no param") { n = 0; 3.times { n += 1 }; n }
probe.("each no param") { n = 0; [4, 5, 6].each { n += 1 }; n }

# polymorphic site, alternating arities
def ypoly(&b) = yield(1, 2, 3)
probe.("polymorphic") { [ypoly { :z }, ypoly { |a| a }, ypoly { |a, b| a + b }, ypoly { |a, b, c| a + b + c }] }

puts out
