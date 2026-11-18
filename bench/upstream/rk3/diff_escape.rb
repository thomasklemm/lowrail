# Differential: Rack::Utils.escape on the branch against URI.encode_www_form_component.
#   ruby -I RACK/lib diff_escape.rb [N]
require "uri"
require "rack/utils"
def run(&b) = (r = b.call; [:ok, r.class, r.encoding, r.b, r.frozen?]) rescue [:err, $!.class, $!.message]
alpha = ["%", "+", "a", "Z", "0", "9", " ", "=", "&", "é", "\xFF".b, "~", "*", "あ", "-", ".", "_", "/", "%2A", "%7E",
  "\0", "\n", "A2"]
encs = [Encoding::UTF_8, Encoding::BINARY, Encoding::US_ASCII, Encoding::ISO_8859_1, Encoding::UTF_16LE]
rng = Random.new(2)
n = (ARGV[0] || 300_000).to_i; bad = 0
n.times do
  s = Array.new(rng.rand(0..12)) { alpha.sample(random: rng) }.map(&:b).join.force_encoding(encs.sample(random: rng))
  s.freeze if rng.rand < 0.2
  a = run { URI.encode_www_form_component(s) }; b = run { Rack::Utils.escape(s) }
  next if a == b
  bad += 1
  p [s, a, b] if bad < 5
end
sub = Class.new(String)
counted = Object.new.tap { |o| def o.to_s = (($to_s_calls += 1); "a b") }
extra = [nil, :sym, :"a b*", 12, 1.5, sub.new("a b*~"), sub.new(""), counted, Object.new.tap { |o| def o.to_s = 1 }]
# The branch calls nothing on a String argument; URI calls #to_s and #dup on it. Singleton or prepended String#to_s
# and String#dup are the boundary.
boundary = ["a b".dup.tap { |x| def x.to_s = "hooked" }, "a b".dup.tap { |x| def x.dup = "hooked" }]
(extra + boundary).each do |s|
  $to_s_calls = 0; a = run { URI.encode_www_form_component(s) }; ca = $to_s_calls
  $to_s_calls = 0; b = run { Rack::Utils.escape(s) }; cb = $to_s_calls
  same = a == b && ca == cb
  bad += 1 unless same || boundary.any? { |x| x.equal?(s) }
  puts "#{boundary.any? { |x| x.equal?(s) } ? "boundary " : ""}#{s.inspect}: #{same ? "same" : "DIFF #{a} #{b} to_s #{ca}/#{cb}"}"
end
puts "#{RUBY_DESCRIPTION}: #{n} random cases + #{extra.size} fixed, #{bad} differences"
