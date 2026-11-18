# Differential probe: String#dup receivers that reach gen_string_copy as a compile-time constant.
out = []
def show(o) = [o.class, o, o.encoding, o.bytesize, o.frozen?, o.valid_encoding?, o.instance_variables]

# Mutable constant, mutated after compilation
MUT = +"abc"
def mut = MUT.dup
5.times { mut }
MUT << "xyz"; out << show(mut)
MUT.force_encoding("BINARY"); out << show(mut)
MUT.replace("é" * 50); out << show(mut)
MUT.clear; out << show(mut)
MUT.instance_variable_set(:@iv, 1); out << show(mut)

# Chilled constant (literal without magic comment): mutation warns and unchills
CHL = "chill"
def chl = CHL.dup
5.times { chl }
w = $VERBOSE; $VERBOSE = nil; CHL << "ed"; $VERBOSE = w
out << show(chl)

# Frozen constants
FRZ = "frozen".freeze
def frz = FRZ.dup
INT = -"interned"
def int = INT.dup
SHR = Ractor.make_shareable(+"share")
def shr = SHR.dup
BIG = ("b" * 3000).freeze
def big = BIG.dup
5.times { frz; int; shr; big }
out << show(frz) << show(int) << show(shr) << show(big)
out << [frz.equal?(FRZ), (frz << "!")]

# Frozen constant replaced by a mutable one
RPL = "one".freeze
def rpl = RPL.dup
5.times { rpl }
w = $VERBOSE; $VERBOSE = nil
Object.send(:remove_const, :RPL); RPL = +"two"
$VERBOSE = w
out << show(rpl)
RPL << "!"; out << show(rpl)

# Constant that gets a singleton class after compilation
SNG = +"sng"
def sng = SNG.dup
5.times { sng }
def SNG.dup = "singleton dup"
out << sng

# Constant of a subclass, constant with ivars before compile
class Sub < String; end
SUB = Sub.new("sub")
def sub = SUB.dup
IVC = +"ivc"; IVC.instance_variable_set(:@a, 1)
def ivc = IVC.dup
5.times { sub; ivc }
out << show(sub) << show(ivc)

# Frozen literal receivers and magic comment
def lit_freeze = "lit".freeze.dup
def lit_uminus = (-"um").dup
eval("# frozen_string_literal: true\ndef fsl = 'fsl'.dup")
5.times { lit_freeze; lit_uminus; fsl }
out << show(lit_freeze) << show(lit_uminus) << show(fsl)

# Constant through an inlined reader, nested module constant, other send forms
def mut_reader = MUT
def via_reader = mut_reader.dup
module M; S = +"m"; def self.d = S.dup; end
def via_send = MUT.send(:dup)
def via_public_send = MUT.public_send(:dup)
def via_map = [MUT, FRZ].map(&:dup)
5.times { via_reader; M.d; via_send; via_public_send; via_map }
MUT.replace("late")
M::S << "!"
out << show(via_reader) << show(M.d) << show(via_send) << show(via_public_send) << via_map.map { show(it) }

# Copies don't alias the constant
c = mut; c << "?"; out << [MUT, c]

# String#dup redefined, then restored
class String; alias_method :orig_dup, :dup; def dup = "redefined"; end
out << mut << frz
class String; alias_method :dup, :orig_dup; end
out << show(mut) << show(frz)

out.each { p it }
