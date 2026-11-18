# Differential: Rack::Utils.unescape and QueryParser#unescape on the branch against URI.decode_www_form_component.
#   ruby -I RACK/lib diff_unescape.rb [N]
require "uri"
require "rack/utils"
def run(&b) = (r = b.call; [:ok, r.class, r.encoding, r.b, r.frozen?, r.valid_encoding?]) rescue [:err, $!.class, $!.message]
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
extra = [nil, :sym, :"a%41", 12, "abc".encode("UTF-16LE"), "a%".encode("UTF-16LE"), sub.new("a%41"), sub.new("a"),
  sub.new("a%")]
# The branch calls nothing on a String argument; URI calls #b on it. A singleton or prepended String#b is the boundary.
boundary = ["a".dup.tap { |x| def x.b = "hooked" }]
(extra + boundary).each do |s|
  a = run { URI.decode_www_form_component(s) }; b = run { Rack::Utils.unescape(s) }; c = run { qp.send(:unescape, s) }
  same = a == b && a == c
  bad += 1 unless same || boundary.any? { |x| x.equal?(s) }
  puts "#{boundary.any? { |x| x.equal?(s) } ? "boundary " : ""}#{s.inspect}: #{same ? "same" : "DIFF #{a} #{b} #{c}"}"
end
puts "#{RUBY_DESCRIPTION}: #{n} random cases + #{extra.size} fixed, #{bad} differences"
