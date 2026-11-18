# Differential: Rack::Utils.unescape and QueryParser#unescape on the branch against URI.decode_www_form_component.
#   ruby -I RACK/lib diff_unescape.rb [N]
require "uri"
require "rack/utils"
# Anonymous classes and object addresses differ between the fresh objects each side gets.
def cls(c) = c.name || "anonymous < #{c.superclass}"
def msg(e) = e.message.gsub(/0x\h+/, "0x")
def run(&b) = (r = b.call; [:ok, cls(r.class), r.encoding, r.b, r.frozen?, r.valid_encoding?]) rescue [:err, $!.class, msg($!)]
qp = Rack::Utils.default_query_parser
alpha = ["%", "+", "a", "Z", "0", "9", "f", "F", "g", " ", "=", "&", "é", "\xFF".b, "%2", "%41", "%e3%81%82", "%FF",
  "%zz", "~", "*", "\u3042", "\0", "%%", "%2B"]
encs = [Encoding::UTF_8, Encoding::BINARY, Encoding::US_ASCII]
targets = [Encoding::UTF_8, Encoding::BINARY, Encoding::Shift_JIS, Encoding::ISO_8859_1, Encoding::US_ASCII]
rng = Random.new(1)
n = (ARGV[0] || 300_000).to_i; bad = 0
n.times do
  s = Array.new(rng.rand(0..12)) { alpha.sample(random: rng) }.map(&:b).join
  s.force_encoding(encs.sample(random: rng))
  s.freeze if rng.rand < 0.2
  t = targets.sample(random: rng)
  a = run { URI.decode_www_form_component(s.dup, t) }
  b = run { Rack::Utils.unescape(s.dup, t) }
  c = run { qp.send(:unescape, s.dup, t) }
  next if a == b && a == c
  bad += 1
  p [s, s.encoding, t, a, b, c] if bad < 10
end
sub = Class.new(String)
tagged = sub.new("a").tap { |x| x.instance_variable_set(:@tag, true) }
extra = [nil, :sym, :"a%41", 12, "abc".encode("UTF-16LE"), "a%".encode("UTF-16LE"), sub.new("a%41"), sub.new("a"),
  sub.new("a%"), tagged]
# Fresh objects per side: encoding arguments whose to_str is stateful, raises on a second call or mutates the input,
# and BasicObject inputs (no instance_of?) with and without the conversions URI uses.
def stateful_enc = Object.new.tap { |o| def o.to_str = (@n = (@n || 0) + 1) == 1 ? "UTF-8" : "ASCII-8BIT" }
def once_enc = Object.new.tap { |o| def o.to_str = (raise "second conversion" if @done; @done = true; "UTF-8") }
def mutating_enc(input) = Object.new.tap { |o| o.instance_variable_set(:@s, input); def o.to_str = (@s.replace("%ZZ"); "UTF-8") }
def basic(str, b: true)
  o = BasicObject.new
  o.instance_eval { @v = str }
  def o.to_str = @v
  if b
    def o.b = @v.b
  end
  o
end
ducks = {
  "stateful encoding %FF" => -> { ["%FF".dup, stateful_enc] },
  "stateful encoding %41" => -> { ["%41".dup, stateful_enc] },
  "encoding raising on 2nd to_str" => -> { ["%E3%81%82".dup, once_enc] },
  "encoding mutating the input" => -> { s = "%41".dup; [s, mutating_enc(s)] },
  "BasicObject to_str+b" => -> { [basic("a%41"), Encoding::UTF_8] },
  "BasicObject to_str+b, lone %" => -> { [basic("a%"), Encoding::UTF_8] },
  "BasicObject to_str only" => -> { [basic("a%41", b: false), Encoding::UTF_8] },
  "plain BasicObject" => -> { [BasicObject.new, Encoding::UTF_8] },
}
ducks.each do |name, make|
  a = run { URI.decode_www_form_component(*make.()) }; b = run { Rack::Utils.unescape(*make.()) }
  c = run { qp.send(:unescape, *make.()) }
  same = a == b && a == c
  bad += 1 unless same
  puts "#{name}: #{same ? "same" : "DIFF #{a} #{b} #{c}"}"
end
puts "cgi/util loaded: #{$LOADED_FEATURES.any? { _1.end_with?("cgi/util.rb") }}"

# The branch calls nothing on a String argument; URI calls #b on it. A singleton or prepended String#b is the boundary.
boundary = ["a".dup.tap { |x| def x.b = "hooked" }]
(extra + boundary).each do |s|
  a = run { URI.decode_www_form_component(s) }; b = run { Rack::Utils.unescape(s) }; c = run { qp.send(:unescape, s) }
  same = a == b && a == c
  bad += 1 unless same || boundary.any? { |x| x.equal?(s) }
  puts "#{boundary.any? { |x| x.equal?(s) } ? "boundary " : ""}#{s.inspect}: #{same ? "same" : "DIFF #{a} #{b} #{c}"}"
end
puts "#{RUBY_DESCRIPTION}: #{n} random cases + #{extra.size + ducks.size} fixed, #{bad} differences"
