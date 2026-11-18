# ZSD1 -3 differential probe: String#dup storage, memsize and allocation tracing.
# Run with no JIT options (interpreter) and with ZJIT options; outputs must be identical.
#   ruby zsd3_probe.rb          sizes, encodings, constants, memsize
#   ruby zsd3_probe.rb early    trace_object_allocations_start before warmup
#   ruby zsd3_probe.rb late     trace_object_allocations_start after warmup
require "objspace"

class ZsdProbe
  FROZEN = ("f" * 300).freeze
  MUTABLE = +("m" * 300)
  SMALL_MUTABLE = +"small"
  def copy(s) = s.dup
  def frozen_constant = FROZEN.dup
  def mutable_constant = MUTABLE.dup
  def small_constant = SMALL_MUTABLE.dup
end

P = ZsdProbe.new

def storage(s)
  d = ObjectSpace.dump(s)
  [d.include?('"embedded":true') ? :embedded : :heap, d.include?('"shared":true') ? :shared : :own]
end

def describe(copy, src)
  [copy == src, copy.equal?(src), copy.frozen?, copy.encoding.name, copy.valid_encoding?, copy.ascii_only?,
   copy.bytesize, *storage(copy), ObjectSpace.memsize_of(copy)]
end

def warm
  20.times do
    P.copy(+"warm"); P.frozen_constant; P.mutable_constant; P.small_constant
  end
end

case ARGV.first
when "early", "late"
  ObjectSpace.trace_object_allocations_start if ARGV.first == "early"
  warm
  ObjectSpace.trace_object_allocations_start if ARGV.first == "late"
  src = +"payload"
  [P.copy(src), P.copy("frozen literal"), P.frozen_constant, P.mutable_constant, P.small_constant].each do |c|
    puts [ObjectSpace.allocation_class_path(c), ObjectSpace.allocation_method_id(c),
          ObjectSpace.allocation_sourceline(c), !ObjectSpace.allocation_sourcefile(c).nil?].inspect
  end
  ObjectSpace.trace_object_allocations_stop
  exit
end

warm
encodings = [Encoding::UTF_8, Encoding::BINARY, Encoding::US_ASCII, Encoding::UTF_16LE, Encoding::EUC_JP]
sizes = [0, 1, 7, 8, 22, 23, 24, 100, 199, 200, 215, 216, 230, 231, 232, 233, 255, 256, 300, 488, 500, 600, 640, 1000, 3000]
encodings.each do |enc|
  sizes.each do |n|
    unit = enc == Encoding::UTF_16LE ? "\x61\x00".b : (enc == Encoding::EUC_JP ? "\xA4\xA2".b : "x")
    # String#* embeds its result when it fits a slot, unlike byteslice, which shares
    base = (n % unit.bytesize == 0 ? unit * (n / unit.bytesize) : "x".b * n).force_encoding(enc)
    # kinds: frozen copy, mutable copy, interned, then base itself (embedded up to the largest slot) mutable and frozen
    [base.dup.freeze, +base.dup, -base.dup, base, base.freeze].each_with_index do |src, kind|
      src_before = [*storage(src), ObjectSpace.memsize_of(src)]
      copies = Array.new(50) { P.copy(src) }
      sum = copies.sum { ObjectSpace.memsize_of(it) }
      puts [enc.name, n, kind, src_before, describe(copies.first, src), sum, [*storage(src), ObjectSpace.memsize_of(src)]].inspect
    end
  end
end

# Broken and non-ASCII contents keep their code range answers
["\xff\xfe".b.force_encoding("UTF-8"), +"é" * 120, "日本語" * 40].each do |src|
  puts describe(P.copy(src), src).inspect
end

# Constants, mutated after compilation
puts describe(P.frozen_constant, ZsdProbe::FROZEN).inspect
puts describe(P.mutable_constant, ZsdProbe::MUTABLE).inspect
ZsdProbe::MUTABLE << "!"
ZsdProbe::SMALL_MUTABLE.replace("é" * 200)
puts describe(P.mutable_constant, ZsdProbe::MUTABLE).inspect
puts describe(P.small_constant, ZsdProbe::SMALL_MUTABLE).inspect
ZsdProbe::SMALL_MUTABLE.force_encoding(Encoding::BINARY).clear
puts describe(P.small_constant, ZsdProbe::SMALL_MUTABLE).inspect

# Mutation of a copy or source after dup doesn't leak to the other
src = +("s" * 400)
c = P.copy(src)
c << "c"
src << "s"
puts [c.bytesize, src.bytesize, c[-1], src[-1]].inspect
small = +"tiny"
c = P.copy(small)
c.setbyte(0, 65)
puts [c, small].inspect
