require "uri"; require "cgi/escape"
def alt(s, encoding = Encoding::UTF_8)
  return URI.decode_www_form_component(s, encoding) unless s.instance_of?(String)
  raise ArgumentError, "invalid %-encoding (#{s})" if /%(?!\h\h)/.match?(s)
  CGI.unescape(s, encoding).force_encoding(encoding)
end
def run(&b) = (r = b.call; [:ok, r.class, r.encoding, r.b, r.frozen?, r.valid_encoding?]) rescue [:err, $!.class, $!.message]
alpha = ["%", "+", "a", "Z", "0", "9", "f", "F", "g", " ", "=", "&", "é", "\xFF".b, "%2", "%41", "%e3%81%82", "%FF", "%zz", "~", "*", "\u3042"]
encs = [Encoding::UTF_8, Encoding::BINARY, Encoding::US_ASCII]
targets = [Encoding::UTF_8, Encoding::BINARY, Encoding::Shift_JIS, Encoding::ISO_8859_1]
rng = Random.new(1)
n = 0; bad = 0
300_000.times do
  s = Array.new(rng.rand(0..12)) { alpha.sample(random: rng) }.map(&:b).join
  s.force_encoding(encs.sample(random: rng))
  s.freeze if rng.rand < 0.2
  t = targets.sample(random: rng)
  a = run { URI.decode_www_form_component(s.dup, t) }
  b = run { alt(s.dup, t) }
  n += 1
  if a != b
    bad += 1
    p [s, s.encoding, t, a, b] if bad < 10
  end
end
extra = [nil, :sym, 12, "abc".encode("UTF-16LE"), Class.new(String).new("a%41")]
extra.each { |s| a = run { URI.decode_www_form_component(s) }; b = run { alt(s) }; puts "#{s.inspect}: #{a == b ? "same" : "DIFF #{a} #{b}"}" }
puts "#{n} cases, #{bad} differences"
