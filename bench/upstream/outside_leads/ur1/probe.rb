# ruby -I URI_LIB probe.rb: thermos-sol's independent differential (2026-11-27), with base inlined from ruby/uri
# 48cda77 so the helper may change. METHOD=decode_uri_component probes that method (base keeps "+").
require "uri"

METHOD = ENV.fetch("METHOD", "decode_www_form_component").to_sym
REGEXP = METHOD == :decode_uri_component ? /%\h\h/ : /\+|%\h\h/
BASE = lambda do |str, enc = Encoding::UTF_8|
  raise ArgumentError, "invalid %-encoding (#{str})" if /%(?!\h\h)/.match?(str)
  str.b.gsub(REGEXP, URI::TBLDECWWWCOMP_).force_encoding(enc)
end
HEAD = URI.method(METHOD)

def outcome(call, factory, target)
  events = []
  begin
    input = factory.call(events)
  rescue ArgumentError => e
    return [:unconstructible, e.message]
  end
  enc = target.call(events)
  before = String === input ? [String.instance_method(:bytes).bind(input).call, input.frozen?] : nil
  begin
    r = call.call(input, *enc)
    result = [:ok, r.class.name, r.bytes, r.encoding.name, r.valid_encoding?, r.frozen?, r.instance_variables, r.singleton_methods, r.equal?(input)]
  rescue Exception => e
    # error_highlight (Ruby 3.1-3.3) appends the source line, which any edit to that line changes.
    result = [:error, e.class.name, e.message.sub(/\n\n.*\z/m, "").gsub(/0x[0-9a-f]+/, "OBJECT")]
  end
  after = String === input ? [String.instance_method(:bytes).bind(input).call, input.frozen?] : nil
  [result, events, before == after]
end

targets = [->(_) { [] }, ->(_) { [Encoding::BINARY] }, ->(_) { ["UTF-16LE"] }, ->(_) { ["bad-encoding"] }, ->(_) { [nil] }, ->(events) {
  obj = Object.new
  obj.define_singleton_method(:to_str) { events << :enc_to_str; "UTF-8" }
  [obj]
}]
sub = Class.new(String)
cases = 0
skipped = 0
differences = []
check = ->(name, factory, target) {
  a = outcome(BASE, factory, target)
  b = outcome(HEAD, factory, target)
  if a.first == :unconstructible && a == b
    skipped += 1
    next
  end
  cases += 1
  differences << [name, a, b] unless a == b
}

Encoding.list.each do |enc|
  ["", "a", "a+b%2F%00%ff", "\xff\x81\x40".b, (0..255).map { |i| "%%%02X" % i }.join, "%", "%a", "%GG", "%%41"].each do |bytes|
    targets.each do |target|
      [false, true].each do |frozen|
        [false, true].each do |subclass|
          check.call("encoding=#{enc.name} bytes=#{bytes.bytes.first(15)} frozen=#{frozen} subclass=#{subclass}", ->(_) {
            s = subclass ? sub.new(bytes) : bytes.dup
            s.force_encoding(enc)
            s.freeze if frozen
            s
          }, target)
        end
      end
    end
  end
end

rng = Random.new(20261127)
Integer(ENV.fetch("RANDOM_CASES", "20000")).times do |i|
  bytes = Array.new(rng.rand(40)) { rng.rand(256) }.pack("C*")
  enc = Encoding.list.sample(random: rng)
  warn "random #{i} #{bytes.unpack('H*').first} #{enc.name}" if ENV["TRACE"]
  check.call("random #{i}", ->(_) { bytes.dup.force_encoding(enc) }, targets.sample(random: rng))
end

factories = {
  "singleton b" => ->(events) { s = "%41".dup; s.define_singleton_method(:b) { events << :b; "%42" }; s },
  "private singleton b" => ->(events) { s = "%41".dup; s.define_singleton_method(:b) { events << :b; "%42" }; s.singleton_class.send(:private, :b); s },
  "singleton encoding" => ->(events) { s = "%41".dup; s.define_singleton_method(:encoding) { events << :encoding; raise "unexpected encoding call" }; s },
  "private instance_of?" => ->(_) { s = "a".dup; s.singleton_class.send(:private, :instance_of?); s },
  "extend b" => ->(events) { m = Module.new { define_method(:b) { events << :b; "%42" } }; "%41".dup.extend(m) },
  "prepend b" => ->(events) { s = "%41".dup; s.singleton_class.prepend(Module.new { define_method(:b) { events << :b; "%42" } }); s },
  "subclass overriding b" => ->(events) { Class.new(String) { define_method(:b) { events << :b; "%42" } }.new("%41") },
  "subclass spoofing instance_of?" => ->(_) { Class.new(String) { def instance_of?(*); true; end }.new("plain") },
  "duck" => ->(events) { o = Object.new; o.define_singleton_method(:to_str) { events << :to_str; "%41" }; o.define_singleton_method(:b) { events << :b; "%42" }; o },
  "method_missing duck" => ->(events) { Class.new { define_method(:method_missing) { |name, *| events << name; name == :to_str ? "%41" : name == :b ? "%42" : super(name) }; def respond_to_missing?(n, *); [:to_str, :b].include?(n); end }.new },
  "frozen" => ->(_) { "%41+%ff".freeze },
  "nil" => ->(_) { nil },
  "symbol" => ->(_) { :abc },
  "number" => ->(_) { 5 },
  "frozen intermediate" => ->(_) { o = Object.new; def o.to_str; "%41"; end; def o.b; "%42".freeze; end; o },
}
factories.each { |name, factory| check.call(name, factory, targets.first) }

input = nil
check.call("mutating encoding conversion", ->(_) { input = "%41".dup }, ->(events) {
  enc = Object.new
  enc.define_singleton_method(:to_str) { events << :enc_to_str; input.replace("%42"); "UTF-8" }
  [enc]
})
fiber_results = [BASE, HEAD].map do |call|
  input = "%41".dup
  enc = Object.new
  enc.define_singleton_method(:to_str) { Fiber.yield(:encoding_conversion); "UTF-8" }
  fiber = Fiber.new { call.call(input, enc) }
  suspended = fiber.resume
  input.replace("%42")
  [suspended, fiber.resume, input]
end
raise "fiber mutation differs: #{fiber_results.inspect}" unless fiber_results[0] == fiber_results[1]

puts "#{RUBY_DESCRIPTION} #{METHOD}"
puts "#{cases} independent differential cases; #{differences.length} differences; #{skipped} unconstructible inputs skipped; fiber mutation equal #{fiber_results.first.inspect}"
differences.each { |name, a, b| puts "#{name}\n  base #{a.inspect}\n  head #{b.inspect}" }
abort "unexpected ordinary-case differences" if differences.any? { |name, _, _| name.start_with?("encoding=", "random ") }
