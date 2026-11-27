require 'json'
require 'rack/query_parser'
require 'rack/utils'

class TaggedString < String; end
class Converting
  def initialize(value, events, kind)
    @value, @events, @kind = value, events, kind
  end
  def to_s
    @events << 'to_s'
    @value
  end
  def to_str
    @events << 'to_str'
    raise 'second conversion' if @kind == :once && @events.count('to_str') > 1
    @value.replace('%ZZ') if @kind == :mutate
    Fiber.yield('conversion') if @kind == :fiber
    @kind == :mutate ? 'UTF-8' : @value
  end
end

def signature(value)
  case value
  when String
    ['string', value.class.name, value.bytes, value.encoding.name, value.frozen?, value.valid_encoding?, value.instance_variables.sort.map { |iv| [iv.to_s, value.instance_variable_get(iv)] }]
  when Array
    value.map { |v| signature(v) }
  when Hash
    value.map { |k, v| [signature(k), signature(v)] }
  else
    value
  end
end

def capture
  ['ok', signature(yield)]
rescue Exception => e
  message = e.respond_to?(:original_message) ? e.original_message : e.message
  message = message.gsub(/0x[0-9a-f]+/, '0xADDR')
  ['error', e.class.name, message.bytes, message.encoding.name]
end

qp = Rack::QueryParser.make_default(32)
sub = Class.new(Rack::QueryParser) do
  private
  def unescape(value, encoding = Encoding::UTF_8)
    "[#{super}]"
  end
end.make_default(32)
includer = Class.new { include Rack::Utils }.new
decoders = {
  'utils' => ->(args) { Rack::Utils.unescape(*args) },
  'parser' => ->(args) { qp.send(:unescape, *args) },
  'include' => ->(args) { includer.send(:unescape, *args) },
  'override-super' => ->(args) { sub.send(:unescape, *args) }
}
escapers = {
  'utils-escape' => ->(args) { Rack::Utils.escape(args.first) },
  'include-escape' => ->(args) { includer.send(:escape, args.first) }
}
n = 0
emit = ->(label, maker, routes) do
  routes.each do |route, call|
    events = []
    args = maker.call(events)
    result = capture { call.call(args) }
    puts JSON.generate([label, route, result, signature(args.first), events])
    n += 1
  end
end

targets = [Encoding::UTF_8, Encoding::BINARY, Encoding::UTF_16LE, 'Shift_JIS', 'ISO-8859-1', nil, :UTF_8, 'unknown-encoding']
fixed = ['', 'abc', '%', '%0', '%g0', '%0g', '%%41', '%41%', '%00', '%FF%FE', '+%2b%2B', '*~', 'a%20b', "café%", "\xFF%41".b, "\0%zz", "\xC3%".b, '%C0%AF', '%ED%A0%80']
Encoding.list.each do |enc|
  next if enc.dummy?
  fixed.each_with_index do |str, i|
    targets.each_with_index do |target, j|
      emit.call("fixed:#{enc.name}:#{i}:#{j}", ->(_) { [str.dup.force_encoding(enc), target] }, decoders)
    end
    emit.call("fixed-escape:#{enc.name}:#{i}", ->(_) { [str.dup.force_encoding(enc)] }, escapers)
  end
end
['UTF-16', 'UTF-32', 'UTF-7', 'ISO-2022-JP'].each do |enc|
  fixed.each_with_index do |str, i|
    emit.call("dummy:#{enc}:#{i}", ->(_) { [str.dup.force_encoding(enc)] }, decoders.merge(escapers))
  end
end

rng = Random.new(612557)
encodings = ['UTF-8', 'ASCII-8BIT', 'US-ASCII', 'Windows-31J', 'EUC-JP', 'ISO-8859-1', 'UTF-16LE', 'UTF-32BE']
fragments = ['%', '%0', '%G0', '%00', '%aF', '%41', '%FF', '+', '*', '~', '&', '=', '[', ']', "\0", "\xFF".b, "\xC3\xA9".b]
5000.times do |i|
  bytes = Array.new(rng.rand(1..12)) { fragments[rng.rand(fragments.size)].b }.join
  encoding = encodings[rng.rand(encodings.size)]
  target = targets[rng.rand(targets.size)]
  frozen = i % 4 == 0
  emit.call("random:#{i}", ->(_) { s = bytes.dup.force_encoding(encoding); s.freeze if frozen; [s, target] }, decoders.merge(escapers))
end

factories = {
  'nil' => ->(_) { [nil] },
  'integer' => ->(_) { [42] },
  'symbol' => ->(_) { [:'a%41'] },
  'array' => ->(_) { [[1, 'x%41']] },
  'hash' => ->(_) { [{'x' => '%41'}] },
  'duck' => ->(e) { [Converting.new('a%41', e, :normal)] },
  'private-to-s' => ->(e) { o = Converting.new('a%41', e, :normal); o.singleton_class.send(:private, :to_s, :to_str); [o] },
  'method-missing' => ->(e) { o = Object.new; o.singleton_class.send(:undef_method, :to_s); o.define_singleton_method(:method_missing) { |m, *| e << m.to_s; m == :to_str || m == :to_s ? '%41' : super(m) }; o.define_singleton_method(:respond_to_missing?) { |*| true }; [o] },
  'basic-object' => ->(_) { o = BasicObject.new; def o.to_s; 'a%41'; end; def o.to_str; 'a%41'; end; [o] },
  'encoding-once' => ->(e) { ['%41'.dup, Converting.new('UTF-8', e, :once)] },
  'encoding-mutate' => ->(e) { s = '%41'.dup; [s, Converting.new(s, e, :mutate)] },
  'encoding-private' => ->(e) { o = Converting.new('UTF-8', e, :normal); o.singleton_class.send(:private, :to_str); ['%41', o] },
  'encoding-invalid-input' => ->(e) { ['%ZZ', Converting.new('UTF-8', e, :normal)] }
}
['', 'abc', '%', 'a%41', '*~', "\xFF".b].each_with_index do |str, i|
  factories["subclass-#{i}"] = ->(_) { s = TaggedString.new(str); s.instance_variable_set(:@tag, 'keep'); [s] }
  factories["ivar-#{i}"] = ->(_) { s = str.dup; s.instance_variable_set(:@tag, 'keep'); [s] }
end
[:instance_of?, :encoding, :to_s, :b, :dup, :gsub, :force_encoding].each do |method|
  factories["singleton-#{method}"] = ->(e) { s = 'a%41'.dup; s.define_singleton_method(method) { |*args| e << method.to_s; super(*args) }; [s] }
end
factories.each do |label, maker|
  decoders.merge(escapers).each do |route, call|
    events = []
    args = maker.call(events)
    before = String === args.first ? signature(args.first) : args.first.class.name rescue 'BasicObject'
    result = capture { call.call(args) }
    after = String === args.first ? signature(args.first) : before
    puts JSON.generate([label, route, result, after, events])
    n += 1
  end
end

['a=x+y&a=%41', 'a[%41]=b&a[c][]=d', 'a=%ZZ', "a=\xFF".b].each_with_index do |query, i|
  {'parse' => -> { qp.parse_query(query) }, 'nested' => -> { qp.parse_nested_query(query) }, 'override-parse' => -> { sub.parse_query(query) }, 'cookies' => -> { Rack::Utils.parse_cookies_header(query) }}.each do |route, call|
    puts JSON.generate(["request-#{i}", route, capture(&call), nil, []])
    n += 1
  end
end
warn "#{RUBY_DESCRIPTION}: #{n} cases; CGI=#{CGI.method(:unescape).source_location.inspect}"
