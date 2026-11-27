# ruby -I URI_LIB diff.rb [N]: differential of URI.decode_www_form_component as loaded from URI_LIB (the branch)
# against the shipped body (BASE below, ruby/uri 48cda77's _decode_uri_component). Compares the result's class,
# encoding, bytes, frozenness, validity, instance variables and singleton methods, the input afterwards,
# conversion calls on the encoding argument, and the class and message of any exception. SINGLETON_B=1 also gives
# 5% of the inputs a singleton #b, which the branch no longer calls (the expected boundary).
require "uri"
abort "branch not loaded" unless URI.method(:decode_www_form_component).source_location[0].start_with?(File.expand_path($:.first))

module BASE
  def self.decode(str, enc = Encoding::UTF_8)
    raise ArgumentError, "invalid %-encoding (#{str})" if /%(?!\h\h)/.match?(str)
    str.b.gsub(/\+|%\h\h/, URI::TBLDECWWWCOMP_).force_encoding(enc)
  end
end

class Sub < String; end
class EncDuck
  attr_reader :calls
  def initialize(name) = (@name, @calls = name, 0)
  def to_str = (@calls += 1; @name)
end
class StrDuck
  def initialize(s) = @s = s
  def to_str = @s
  def to_s = @s
end

def snap(x)
  return [:basic] if BasicObject === x && !(Object === x)
  [x.class, (x.encoding.name if x.respond_to?(:encoding)), (x.b if String === x), x.frozen?,
    (x.valid_encoding? if String === x), x.instance_variables.map { [_1, x.instance_variable_get(_1)] },
    x.singleton_methods.sort]
end

def run(m, input, enc)
  r = m.call(input, *enc)
  [:ok, snap(r), r.equal?(input)]
rescue Exception => e
  [:raise, e.class, e.message]
end

PIECES = ["a", "Z", "0", "9", "%", "+", "%2", "%zz", "%41", "%2B", "%25", "%e3%81%82", "%E3%81", "%FF", "%a",
  "é", "あ", "\xFF".b, " ", "~", "*", "-", "%0", "%%41", "++", "\0", "\n"]
ENCS = [Encoding::UTF_8, Encoding::BINARY, Encoding::US_ASCII, Encoding::Shift_JIS, Encoding::EUC_JP,
  Encoding::ISO_8859_1, Encoding::UTF_16LE, Encoding::UTF_32BE, Encoding::UTF_7]
TARGETS = [[], [Encoding::UTF_8], [Encoding::BINARY], [Encoding::Shift_JIS], [Encoding::ISO_8859_1], ["EUC-JP"],
  ["nope"], [nil], [Encoding::UTF_16LE], [:duck]]

def make(rng)
  s = String.new
  rng.rand(0..8).times { s << PIECES.sample(random: rng).b }
  s = s.dup.force_encoding(ENCS.sample(random: rng))
  s = Sub.new(s) if rng.rand < 0.1
  s.instance_variable_set(:@tag, 1) if rng.rand < 0.1
  s.define_singleton_method(:b) { "singleton" } if ENV["SINGLETON_B"] && rng.rand < 0.05
  s.freeze if rng.rand < 0.2
  s
end

def compare(input, target, diffs, label = nil)
  plain = Object === input
  a_in = !plain || input.frozen? ? input : (input.dup rescue input)
  b_in = !plain || input.frozen? ? input : (input.dup rescue input)
  if plain && String === input && !input.frozen?
    [a_in, b_in].each { |c| input.instance_variables.each { c.instance_variable_set(_1, input.instance_variable_get(_1)) } }
  end
  da = target == [:duck] ? [EncDuck.new("UTF-8")] : target
  db = target == [:duck] ? [EncDuck.new("UTF-8")] : target
  base = run(BASE.method(:decode), a_in, da)
  head = run(URI.method(:decode_www_form_component), b_in, db)
  base << snap(a_in) << (da[0].calls if EncDuck === da[0])
  head << snap(b_in) << (db[0].calls if EncDuck === db[0])
  diffs << [label || input.inspect, target, base, head] unless base == head
end

n = Integer(ARGV[0] || 300_000)
rng = Random.new(42)
diffs = []
n.times { compare(make(rng), TARGETS.sample(random: rng), diffs) }
fixed = [nil, :sym, :"a%41", 1, 1.5, StrDuck.new("a%41+b"), "", "".encode("UTF-16LE"), "a".encode("UTF-16LE"),
  "%".encode("UTF-16LE"), "a+b".force_encoding("UTF-16LE"), "x" * (1024 * 1024), "%41" * 100_000]
fixed.each { |f| TARGETS.each { |t| compare(f, t, diffs) } }
bo = BasicObject.new
TARGETS.each { |t| compare(bo, t, diffs, "BasicObject") }
bs = BasicObject.new
def bs.to_str = "a%41"
compare(bs, [], diffs, "BasicObject with to_str")
chilled = eval('"a%41+b"') # a chilled literal on 3.4+
compare(chilled, [], diffs, "chilled literal")
puts "#{RUBY_DESCRIPTION}: #{n} random + #{(fixed.size + 1) * TARGETS.size + 2} fixed cases, #{diffs.size} differences"
diffs.group_by { [_1[2][0], _1[3][0], _1[2][1].to_s[0, 40], _1[3][1].to_s[0, 40]] }.first(20).each do |k, v|
  puts "  #{v.size}x e.g. #{v[0][0][0, 60]} #{v[0][1].inspect}\n    base #{v[0][2].inspect[0, 300]}\n    head #{v[0][3].inspect[0, 300]}"
end
