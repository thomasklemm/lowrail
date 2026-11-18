# Differential: Rack::Utils.escape on the branch against URI.encode_www_form_component.
#   ruby -I RACK/lib diff_escape.rb [N]
require "uri"
require "rack/utils"
# Anonymous classes and object addresses differ between the fresh objects each side gets.
def cls(c) = c.name || "anonymous < #{c.superclass}"
def msg(e) = e.message.gsub(/0x\h+/, "0x")
def run(&b) = (r = b.call; [:ok, cls(r.class), r.encoding, r.b, r.frozen?]) rescue [:err, $!.class, msg($!)]
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
tagged = sub.new("a").tap { |x| x.instance_variable_set(:@tag, true) }
extra = [nil, :sym, :"a b*", 12, 1.5, sub.new("a b*~"), sub.new(""), sub.new("~"), sub.new("*"), sub.new("a"), tagged,
  counted, Object.new.tap { |o| def o.to_s = 1 }]
# BasicObject has no instance_of?; URI only needs to_s.
basics = {
  "BasicObject to_s" => -> { o = BasicObject.new; def o.to_s = "a b*~"; o },
  "BasicObject to_s returning a subclass" => -> { o = BasicObject.new; def o.to_s = Class.new(String).new("a b"); o },
  "plain BasicObject" => -> { BasicObject.new },
}
basics.each do |name, make|
  a = run { URI.encode_www_form_component(make.()) }; b = run { Rack::Utils.escape(make.()) }
  b2 = run { Rack::Utils.build_nested_query("x" => make.()) }; a2 = run { "x=" + URI.encode_www_form_component(make.()) }
  # build_nested_query returns a binary String (utils.rb is a binary source file), so compare its bytes.
  same = a == b && (a2[0] == :ok ? b2[0] == :ok && a2[3] == b2[3] : a2.values_at(0, 1) == b2.values_at(0, 1))
  bad += 1 unless same
  puts "#{name}: #{same ? "same" : "DIFF #{a} #{b} #{a2} #{b2}"}"
end
puts "cgi/util loaded: #{$LOADED_FEATURES.any? { _1.end_with?("cgi/util.rb") }}"

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
puts "#{RUBY_DESCRIPTION}: #{n} random cases + #{extra.size + basics.size} fixed, #{bad} differences"
