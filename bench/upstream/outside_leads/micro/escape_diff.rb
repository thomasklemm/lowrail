load File.expand_path("escape.rb", __dir__)
def run(&b) = (r = b.call; [:ok, r.class, r.encoding, r.b, r.frozen?]) rescue [:err, $!.class, $!.message]
alpha = ["%", "+", "a", "Z", "0", "9", " ", "=", "&", "é", "\xFF".b, "~", "*", "あ", "-", ".", "_", "/", "%2A", "\0", "\n"]
encs = [Encoding::UTF_8, Encoding::BINARY, Encoding::US_ASCII, Encoding::UTF_16LE]
rng = Random.new(2); bad = 0; n = 0
300_000.times do
  s = Array.new(rng.rand(0..12)) { alpha.sample(random: rng) }.map(&:b).join.force_encoding(encs.sample(random: rng))
  s.freeze if rng.rand < 0.2
  a = run { URI.encode_www_form_component(s) }; b = run { alt_escape(s) }; n += 1
  (bad += 1; p [s, a, b] if bad < 5) if a != b
end
[nil, :sym, 12, 1.5, Class.new(String).new("a b*~")].each { |s| a = run { URI.encode_www_form_component(s) }; b = run { alt_escape(s) }; puts "#{s.inspect}: #{a == b ? "same" : "DIFF #{a} #{b}"}" }
puts "#{n} cases, #{bad} differences"
