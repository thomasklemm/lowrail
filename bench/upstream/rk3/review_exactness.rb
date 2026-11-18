# Run against the pinned Rack lib with native CGI, then with -r ./pure_cgi.rb.
require "rack/utils"
require "json"

def outcome
  value = yield
  [:ok, value.class.name, value.encoding.name, value.bytes, value.frozen?, value.valid_encoding?]
rescue StandardError => error
  [:error, error.class.name, error.message]
end

differences = Hash.new(0)
examples = {}
checks = 0
compare = lambda do |label, factory, encoding_factory = ->(_input) { Encoding::UTF_8 }|
  [:escape, :unescape, :query_unescape].each do |method|
    next if method == :escape && label.start_with?("encoding/")
    old_input, new_input = factory.call, factory.call
    new_input = old_input unless String === old_input
    expected = outcome do
      method == :escape ? URI.encode_www_form_component(old_input) : URI.decode_www_form_component(old_input, encoding_factory.call(old_input))
    end
    actual = outcome do
      case method
      when :escape then Rack::Utils.escape(new_input)
      when :unescape then Rack::Utils.unescape(new_input, encoding_factory.call(new_input))
      else Rack::Utils.default_query_parser.send(:unescape, new_input, encoding_factory.call(new_input))
      end
    end
    checks += 1
    next if expected == actual
    key = "#{label.split('/').first}/#{method}"
    differences[key] += 1
    examples[key] ||= [label, expected, actual]
  end
end

bytes = ["", "a", "+", "+%2B+", "%", "%%", "%%%", "%2", "%2a", "%2A", "%252A*~", "%2a%7e%2b", "abc%4f%", "%00%ff", "\xFF".b,
  "\xC3\x28".b, "\xFF%".b, "\xE3\x81\x82".b, "\0\n\r\t"]
encodings = ["UTF-8", "ASCII-8BIT", "US-ASCII", "ISO-8859-1", "Shift_JIS", "UTF-16LE", "UTF-16BE", "UTF-32LE", "UTF-32BE", "UTF-16", "UTF-32", "ISO-2022-JP"]
targets = [Encoding::UTF_8, Encoding::BINARY, Encoding::US_ASCII, Encoding::Shift_JIS, Encoding::UTF_16LE, "UTF-8", "UTF-32BE", "", "bogus", nil, false, 1, :UTF_8]
bytes.each do |raw|
  encodings.each do |encoding|
    [false, true].each do |frozen|
      targets.each do |target|
        compare.call("matrix/#{raw.unpack1('H*')}/#{encoding}/#{frozen}/#{target.inspect}", -> {
          value = raw.dup.force_encoding(encoding)
          frozen ? value.freeze : value
        }, ->(_input) { target })
      end
    end
  end
end

[nil, :symbol, :"a b*~", 12, 1.5, false].each { |value| compare.call("nonstring/#{value.inspect}", -> { value }) }
[:to_s, :to_str].each do |conversion|
  ["a b*~", 1].each do |result|
    compare.call("nonstring/#{conversion}/#{result.inspect}", -> {
      Object.new.tap do |o|
        o.define_singleton_method(:to_s) { "duck" }
        o.define_singleton_method(:inspect) { "duck" }
        o.define_singleton_method(conversion) { result }
      end
    })
  end
end
subclass = Class.new(String)
bytes.each { |raw| compare.call("subclass/#{raw.unpack1('H*')}", -> { subclass.new(raw) }) }
compare.call("chilled/literal", -> { eval('"a+%2b*~"') })
basic = Class.new(BasicObject) do
  def to_s; "a b"; end
  def to_str; "%41"; end
  def b; "%41"; end
end
compare.call("basicobject/coercible", -> { basic.new })

compare.call("encoding/stable to_str", -> { "a%41" }, ->(_input) {
  Object.new.tap { |o| o.define_singleton_method(:to_str) { "UTF-8" } }
})
compare.call("encoding/stateful to_str", -> { "%FF" }, ->(_input) {
  calls = 0
  Object.new.tap { |o| o.define_singleton_method(:to_str) { calls += 1; calls == 1 ? "UTF-8" : "ASCII-8BIT" } }
})
compare.call("encoding/raises on second to_str", -> { "a%41" }, ->(_input) {
  calls = 0
  Object.new.tap { |o| o.define_singleton_method(:to_str) { calls += 1; raise "converted twice" if calls > 1; "UTF-8" } }
})
compare.call("encoding/mutates input", -> { "%41" }, ->(input) {
  Object.new.tap { |o| o.define_singleton_method(:to_str) { input.replace("%ZZ"); "UTF-8" } }
})

["a" * 1_000_000, "+%2b%41" * 150_000, "%" * 1_000_000, "%41" * 333_333 + "%"].each_with_index do |input, index|
  compare.call("long/#{index}", -> { input.dup.freeze })
end

puts JSON.pretty_generate(ruby: RUBY_DESCRIPTION, cgi_util_loaded: $LOADED_FEATURES.any? { |path| path.end_with?("/cgi/util.rb") },
  cgi_escape: CGI.method(:escape).source_location,
  cgi_unescape: CGI.method(:unescape).source_location, checks: checks, differences: differences, examples: examples)
exit(differences.empty? ? 0 : 1)
