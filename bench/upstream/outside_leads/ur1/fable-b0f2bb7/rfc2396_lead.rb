# How close is URI::RFC2396_PARSER.unescape(str) to CGI.unescapeURIComponent(str, str.encoding)? A lead check, not a claim.
require "uri"; require "cgi/escape"
rng = Random.new(1)
alphabet = ["%", "%", "%4", "%41", "%e3%81%82", "%FF", "+", "a", "Z", " ", "\u3042", "\xFF", "%zz", "%%", "/"]
encs = [Encoding::UTF_8, Encoding::BINARY, Encoding::US_ASCII, Encoding::EUC_JP, Encoding::Shift_JIS, Encoding::ISO_8859_1]
diffs = Hash.new(0); n = 0; examples = {}
snap = ->(blk) { begin; r = blk.call; [r.class, r.encoding, r.b, r.valid_encoding?, r.frozen?]; rescue Exception => e; [:error, e.class]; end }
100_000.times do
  s = Array.new(rng.rand(0..6)) { alphabet.sample(random: rng) }.join.b.force_encoding(encs.sample(random: rng))
  s = Class.new(String).new(s) if rng.rand(20) == 0
  a = snap.(-> { URI::RFC2396_PARSER.unescape(s) }); b = snap.(-> { CGI.unescapeURIComponent(s, s.encoding) })
  n += 1
  next if a == b
  kind = s.class != String ? :subclass : a[0] == :error || b[0] == :error ? :error : a[1] != b[1] ? :encoding : :other
  diffs[kind] += 1; examples[kind] ||= [s, s.encoding, a, b]
end
puts "#{n} cases, differences: #{diffs.inspect}"
examples.each { |k, v| puts "#{k}: #{v.inspect}" }
