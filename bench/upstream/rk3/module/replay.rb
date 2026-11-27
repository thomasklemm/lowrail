# ruby -I RACK/lib replay.rb RECORDFILE > out.txt
# Replays recorded suite inputs and adversarial ones through every way of reaching
# unescape and escape; prints one line per call, so two trees can be diffed.
require "rack"
require "rack/utils"
require "rack/query_parser"

def cls(c); c.name || "anonymous < #{c.superclass}"; end
def msg(e); e.message.gsub(/0x\h+/, "0x").gsub(/#<Class:0x>/, "#<Class>"); end
def sig(r)
  return [:ok, r.inspect] unless r.is_a?(String) || r.is_a?(Hash)
  return [:ok, cls(r.class), r.to_a.inspect] if r.is_a?(Hash)
  [:ok, cls(r.class), r.encoding.to_s, r.b.inspect, r.frozen?, r.valid_encoding?, r.instance_variables]
end
def run
  sig(yield)
rescue Exception => e
  [:err, e.class.to_s, msg(e).b, msg(e).encoding.to_s]
end

qp = Rack::Utils.default_query_parser
includer = Class.new { include Rack::Utils }.new
sub_qp = Class.new(Rack::QueryParser) do
  def unescape(s, encoding = Encoding::UTF_8)
    "<#{super}>"
  end
end.make_default(32)

inputs = []
File.open(ARGV[0], "rb") do |f|
  while (len = f.read(4))
    inputs << Marshal.load(f.read(len.unpack1("N")))
  end
end
recorded = inputs.size
inputs.uniq!

# Adversarial: random mixes of %, + and bytes in several encodings, then fixed odd cases.
alpha = ["%", "+", "a", "Z", "0", "9", "f", "F", "g", " ", "=", "&", ";", "é", "\xFF".b, "\xC3".b, "%2", "%41",
  "%e3%81%82", "%FF", "%zz", "%G1", "~", "*", "\u3042", "\0", "%%", "%2B", "%2a", "%7E", "%C3%A9", "[", "]"]
encs = [Encoding::UTF_8, Encoding::BINARY, Encoding::US_ASCII, Encoding::Shift_JIS, Encoding::ISO_8859_1, Encoding::EUC_JP]
targets = [Encoding::UTF_8, Encoding::BINARY, Encoding::Shift_JIS, Encoding::ISO_8859_1, Encoding::US_ASCII, "UTF-8", "binary"]
rng = Random.new(2557)
(ARGV[1] || 20_000).to_i.times do
  s = Array.new(rng.rand(0..10)) { alpha.sample(random: rng) }.map(&:b).join.force_encoding(encs.sample(random: rng))
  s.freeze if rng.rand < 0.2
  inputs << [:unescape, [s, targets.sample(random: rng)]]
  inputs << [:escape, [s]]
end
sub = Class.new(String)
fixed = ["", "%", "%2", "a%", "%%41", "%zz", "%4", "+%", "%\u3042", "\u3042%41", "%E3%81", "%FF%FE", "a+b", "a%20b",
  "\xFF%41".b, "caf\xE9".dup.force_encoding("ISO-8859-1"), "\x82\xA0%41".dup.force_encoding("Shift_JIS"),
  "\xFF\xFE".dup.force_encoding("UTF-8"), "a%41".encode("UTF-16LE"), "a%".encode("UTF-16BE"), "a%41".encode("UTF-32LE"),
  "a+%41".dup.force_encoding("UTF-7"), "*~ -_.!'()", "x".freeze, sub.new("a%41"), sub.new("a"), sub.new("%"),
  sub.new("~*"), nil, :sym, :"a%41", 12, 1.5, Object.new.tap { |o| def o.to_s; "%41"; end }, [1], {}]
fixed << "a".dup.tap { |x| x.instance_variable_set(:@tag, 1) } << sub.new("b").tap { |x| x.instance_variable_set(:@tag, 1) }
fixed.each do |s|
  [Encoding::UTF_8, Encoding::BINARY, "Shift_JIS", "nope", nil, :utf_8, Encoding::UTF_16LE].each { |t| inputs << [:unescape, [s, t]] }
  inputs << [:unescape, [s]] << [:escape, [s]]
end

def basic(str, to_str: true, b: true)
  o = BasicObject.new
  o.instance_eval { @v = str }
  if to_str
    def o.to_str; @v; end
  end
  if b
    def o.b; @v.b; end
  end
  o
end
def stateful_enc
  Object.new.tap { |o| def o.to_str; (@n = (@n || 0) + 1) == 1 ? "UTF-8" : "ASCII-8BIT"; end }
end
def mutating_enc(input)
  Object.new.tap { |o| o.instance_variable_set(:@s, input); def o.to_str; @s.replace("%ZZ"); "UTF-8"; end }
end
fresh = {
  "basic to_str" => -> { [basic("a%41")] },
  "basic no to_str" => -> { [basic("a%41", to_str: false)] },
  "basic no b" => -> { [basic("a%41", b: false)] },
  "stateful encoding" => -> { ["%FF".dup, stateful_enc] },
  "mutating encoding" => -> { s = "%41".dup; [s, mutating_enc(s)] },
  "singleton gsub" => -> { s = "a%41".dup; def s.gsub(*); "X"; end; [s] },
  "singleton b" => -> { s = "a%41".dup; def s.b; "X"; end; [s] },
  "extended" => -> { [ "a%41".dup.extend(Module.new { def to_s; "X"; end })] },
}

calls = {
  "Utils.unescape" => ->(a) { Rack::Utils.unescape(*a) },
  "QueryParser#unescape" => ->(a) { qp.send(:unescape, *a) },
  "include Utils #unescape" => ->(a) { includer.send(:unescape, *a) },
  "subclass super" => ->(a) { sub_qp.send(:unescape, *a) },
}
escapes = {
  "Utils.escape" => ->(a) { Rack::Utils.escape(*a) },
  "include Utils #escape" => ->(a) { includer.send(:escape, *a) },
}

n = 0
inputs.each do |kind, args|
  label = args.map { |x| x.is_a?(String) ? [x.b, x.encoding.to_s, cls(x.class)] : x }.inspect.gsub(/0x\h+/, "0x")
  (kind == :unescape ? calls : escapes).each do |name, c|
    puts "#{name} #{label} => #{run { c.(args.map { |x| x.dup rescue x }) }.inspect}"
    n += 1
  end
  next unless kind == :unescape && args[0].is_a?(String) && args[0].encoding.ascii_compatible?
  s = args[0]
  { "parse_query" => -> { Rack::Utils.parse_query("k=#{s}&#{s}=v") },
    "parse_nested_query" => -> { Rack::Utils.parse_nested_query("a[#{s}]=#{s}") },
    "subclass parse_query" => -> { sub_qp.parse_query("k=#{s}") },
    "parse_cookies_header" => -> { Rack::Utils.parse_cookies_header("c=#{s}; d=#{s}") } }.each do |name, c|
    puts "#{name} #{label} => #{run(&c).inspect}"
    n += 1
  rescue Encoding::CompatibilityError
  end
end
fresh.each do |label, make|
  calls.merge(escapes).each { |name, c| puts "#{name} #{label} => #{run { c.(make.()) }.inspect}"; n += 1 }
end

# The interface: visibility, module_function, arity, and what subclasses and includers see.
probe = {
  "Utils responds" => -> { Rack::Utils.respond_to?(:unescape) },
  "Utils singleton public" => -> { Rack::Utils.singleton_class.public_method_defined?(:unescape) },
  "Utils instance private" => -> { Rack::Utils.private_method_defined?(:unescape) },
  "Utils instance public" => -> { Rack::Utils.public_method_defined?(:unescape) },
  "Utils arity" => -> { Rack::Utils.method(:unescape).arity },
  "Utils parameters" => -> { Rack::Utils.method(:unescape).parameters },
  "QueryParser private" => -> { Rack::QueryParser.private_method_defined?(:unescape) },
  "QueryParser public" => -> { Rack::QueryParser.public_method_defined?(:unescape) },
  "QueryParser arity" => -> { Rack::QueryParser.instance_method(:unescape).arity },
  "QueryParser parameters" => -> { Rack::QueryParser.instance_method(:unescape).parameters },
  "includer public call" => -> { includer.unescape("a") },
  "qp public call" => -> { qp.unescape("a") },
  "Utils.escape public" => -> { Rack::Utils.escape("a b") },
  "Utils escape private" => -> { Rack::Utils.private_method_defined?(:escape) },
  "Utils.public_send" => -> { Rack::Utils.public_send(:unescape, "a%41") },
  "Utils.method call" => -> { Rack::Utils.method(:unescape).call("a+b") },
  "Utils.unescape redefinable" => -> { m = Module.new { def unescape(*); "P"; end }; Rack::Utils.singleton_class.prepend(m); r = Rack::Utils.unescape("x"); m.send(:remove_method, :unescape); r },
}
probe.each { |k, v| puts "probe #{k} => #{run(&v).inspect}" }
warn "recorded #{recorded} (#{inputs.size} with adversarial), #{n} calls"
