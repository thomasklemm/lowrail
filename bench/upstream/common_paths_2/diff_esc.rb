# Differential: main's UriEncoder vs the candidate's, same process.
# ruby diff_esc.rb MAIN_UTILS_RB CAND_UTILS_RB
main_src, cand_src = ARGV.map { File.read(_1) }
eval(main_src.sub("class Utils # :nodoc:", "class UtilsMain # :nodoc:"), TOPLEVEL_BINDING, ARGV[0])
eval(cand_src.sub("class Utils # :nodoc:", "class UtilsCand # :nodoc:"), TOPLEVEL_BINDING, ARGV[1])
M = ActionDispatch::Journey::Router::UtilsMain
C = ActionDispatch::Journey::Router::UtilsCand
KINDS = %i[escape_segment escape_path escape_fragment]

def outcome(mod, kind, input)
  r = mod::ENCODER.public_send(kind, input)
  [:ok, r.b, r.encoding.name, r.frozen?, r.equal?(input), r.class]
rescue Exception => e
  [:raise, e.class, e.message]
end

$checked = 0
$diffs = []
def check(input)
  KINDS.each do |k|
    a = outcome(M, k, input)
    b = outcome(C, k, input)
    $checked += 1
    $diffs << [k, input, a, b] if a != b
  end
end

encs = %w[UTF-8 US-ASCII ASCII-8BIT ISO-8859-1 Shift_JIS EUC-JP Windows-1252 UTF-16LE UTF-32BE].map { Encoding.find(_1) }
# every single byte in each encoding, plus every single codepoint up to U+2FFF and some astral ones
(0..255).each { |b| encs.each { |e| check(b.chr.force_encoding(e)) } }
((0..0x2FFF).to_a + [0xD7FF, 0xE000, 0xFFFD, 0x10000, 0x1F600, 0x10FFFF]).each { |cp| check(cp.chr(Encoding::UTF_8)) rescue nil }
# all strings of length <= 3 over a tricky alphabet
alpha = ["a", "Z", "0", "-", ".", "_", "~", "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "=", ":", "@", "/", "?", "#", "%", " ", "\n", "\t", "\0", "[", "]", "\"", "<", ">", "\\", "^", "`", "{", "|", "}", "\u00e9", "\u2028", "\u{1F600}", "\x7F"]
strs = [""]
1.upto(3) { |len| alpha.repeated_permutation(len) { |p| strs << p.join } }
strs.each { |s| check(s); check(s.dup.force_encoding("ASCII-8BIT")); check(s.encode("UTF-16LE")) }
# broken and odd encodings
["\xff", "a\xffb", "\xe2\x82", "ok\xc3", "\xc3\xa9"].each { |s| check(s.dup.force_encoding("UTF-8")); check(s.b) }
check("caf\xe9".force_encoding("ISO-8859-1")); check("\x82\xa0".force_encoding("Shift_JIS"))
# frozen, long, random
check("my-first-post-about-rails".freeze); check("a" * 10_000); check("a" * 9_999 + " ")
rng = Random.new(41231)
pool = alpha + ("a".."z").to_a + ("0".."9").to_a
200_000.times { check(Array.new(rng.rand(1..24)) { pool[rng.rand(pool.size)] }.join) }
20_000.times { check(Array.new(rng.rand(1..12)) { rng.rand(256).chr }.join.force_encoding(%w[UTF-8 ASCII-8BIT US-ASCII].sample(random: rng))) }
# String subclass and singleton methods
class Sub < String; end
check(Sub.new("abc")); check(Sub.new("a b"))
puts "checked #{$checked} (input, kind) pairs; differences: #{$diffs.size}"
$diffs.first(10).each { p _1 }
