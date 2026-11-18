require "objspace"

def d(s) = s.dup

def desc(o)
  [o.class, o, o.encoding, o.frozen?, o.valid_encoding?, o.ascii_only?,
   o.instance_variables, (o.singleton_class.instance_methods(false) rescue :none),
   (ObjectSpace.memsize_of(o) > 0)]
rescue => e
  [:err, e.class, e.message]
end

class Sub < String; end
class SubCopy < String
  def initialize_copy(o) = (super; @copied = true)
end

def receivers
  lit = "literal"                      # chilled literal (no magic comment)
  frozen = "frozen".freeze
  interned = -"interned"
  big = "x" * 5000
  shared = big[10, 3000]
  embed_big = "y" * 300
  bin = "\xff\xfe".b
  utf = +"é"
  ascii = "us".encode("US-ASCII")
  broken = "\xff".dup.force_encoding("UTF-8")
  cap = String.new(capacity: 1000) << "cap"
  ivar = +"ivar"; ivar.instance_variable_set(:@a, 1)
  oid = +"oid"; oid.object_id
  ext = +"ext"; ext.extend(Comparable)
  sing = +"sing"; def sing.hello = 1
  sdup = +"sdup"; def sdup.dup = "singleton dup"
  shareable = Ractor.make_shareable(+"share")
  utf16 = "wide".encode("UTF-16LE")
  [lit, frozen, interned, big, shared, embed_big, bin, utf, ascii, broken, cap, ivar,
   oid, ext, sing, sdup, shareable, utf16, Sub.new("sub"), SubCopy.new("subcopy")]
end

out = []
# Warm the call site on a bare String so it compiles inlined, then feed everything.
5.times { d(+"warm") }
receivers.each { |r| x = d(r); out << desc(x) << x.equal?(r) }

# Mutated after dup: the copy must not alias.
s = +"abc"; c = d(s); s << "!"; out << [s, c]
big = "q" * 2000; c = d(big); big[0] = "Z"; out << [big[0], c[0]]

# ivars added after compilation
late = +"late"; 3.times { d(late) }; late.instance_variable_set(:@z, 9)
out << d(late).instance_variable_get(:@z)

# Chilled literal warning state
def chill = "chilled".dup
out << chill.frozen? << (chill << "ok")

# Constant receiver mutated mid-run
BUF = +"abc"
def cdup = BUF.dup
5.times { cdup }
BUF << "xyz"; out << [cdup, cdup.bytesize]
BUF.force_encoding("BINARY"); out << cdup.encoding
BUF.replace("é"); out << [cdup, cdup.ascii_only?]
BUF.instance_variable_set(:@iv, 1); out << cdup.instance_variable_get(:@iv)

# Allocation tracing
ObjectSpace.trace_object_allocations do
  x = d(+"traced")
  out << !ObjectSpace.allocation_sourcefile(x).nil?
end
cnt = 0
tp = TracePoint.new(:c_call) { |t| cnt += 1 if t.method_id == :dup }
tp.enable { d(+"tp") }
out << [:c_call_dup, cnt]
out << GC.stat(:total_allocated_objects).then { |a| 100.times { d(+"z") }; GC.stat(:total_allocated_objects) - a }

# GC.compact between calls
keep = Array.new(50) { +"keep#{it}" }
GC.compact rescue nil
out << (keep.map { d(it) } == keep)

# Refinement of String#dup
module R; refine(String) { def dup = "refined" }; end
module UseR; using R; def self.go(s) = s.dup; end
out << UseR.go(+"r") << d(+"r")

# Prepended module on String
module P; def dup = "prepended"; end
String.prepend(P)
out << d(+"p") << d("lit")
module P; remove_method :dup; end
out << d(+"p2")

# Redefinition mid-run
class String; alias_method :orig_dup, :dup; def dup = "redefined"; end
out << d(+"x")
class String; alias_method :dup, :orig_dup; end
out << d(+"y")

out.each { p it }
# Chilled and frozen constant receivers
CH = "chill"
def chdup = CH.dup
5.times { chdup }
CH << "ed"
p [chdup, chdup.frozen?]
FZ = "fz".freeze
def fzdup = FZ.dup
5.times { fzdup }
p [fzdup, fzdup.frozen?, fzdup.encoding, (fzdup << "!")]
