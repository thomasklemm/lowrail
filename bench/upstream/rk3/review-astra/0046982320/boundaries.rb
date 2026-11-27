require 'rack/utils'

def show(label)
  p [label, yield]
rescue Exception => e
  p [label, e.class.name, e.message.sub(/\n\n.*\z/m, ''), e.message.encoding.name]
end

case ARGV[0]
when 'error'
  [Rack::Utils.method(:unescape), Rack::QueryParser.make_default(32).method(:unescape), URI.method(:decode_www_form_component)].each do |method|
    ['%', '%'.b, '%'.encode('US-ASCII'), 'é%', "\xff%".b].each do |s|
      show([method.owner.name, s, s.encoding.name]) { method.call(s) }
    end
  end
when 'to_s'
  ['UTF-16LE', 'UTF-32BE', 'ISO-8859-1', 'UTF-8'].each do |encoding|
    s = '%'.dup
    s.define_singleton_method(:to_s) { 'é'.encode(encoding) }
    show(encoding) { Rack::Utils.unescape(s) }
  end
when 'ancestor'
  class ParentParser < Rack::QueryParser
    private
    def unescape(s, *); "parent:#{s}"; end
  end
  class ChildParser < ParentParser
    include Rack::Utils
  end
  parser = ChildParser.make_default(32)
  show('direct') { parser.send(:unescape, 'a+b') }
  show('query') { parser.parse_query('x=a+b') }
when 'super'
  Rack::Utils.module_eval do
    private
    def unescape(*args); "wrapper:#{super}"; end
  end
  show('Utils module method') { Rack::Utils.unescape('a+b') }
  show('Utils instance method') { Object.new.extend(Rack::Utils).send(:unescape, 'a+b') }
  Rack::QueryParser.class_eval do
    private
    def unescape(*args); "wrapper:#{super}"; end
  end
  show('QueryParser reopened') { Rack::QueryParser.make_default(32).parse_query('x=a+b') }
when 'remove'
  show('Utils remove_method') { Rack::Utils.send(:remove_method, :unescape) }
  show('QueryParser remove_method') { Rack::QueryParser.send(:remove_method, :unescape) }
when 'reflection'
  show('Utils owner') { Rack::Utils.instance_method(:unescape).owner.name }
  show('QueryParser owner') { Rack::QueryParser.instance_method(:unescape).owner.name }
  show('Utils own private methods') { Rack::Utils.private_instance_methods(false).include?(:unescape) }
  show('QueryParser parameters') { Rack::QueryParser.instance_method(:unescape).parameters }
  show('Utils method') { [Rack::Utils.method(:unescape).owner.name, Rack::Utils.method(:unescape).parameters] }
  show('public Utils ancestor constant') { Rack::Utils.const_defined?(:Unescape) }
when 'reload'
  3.times do |i|
    load File.join($LOAD_PATH.first, 'rack/query_parser.rb')
    load File.join($LOAD_PATH.first, 'rack/utils.rb')
    show(i) { [Rack::Utils.unescape('a+b'), Rack::Utils.parse_query('a+b=c+d')] }
  end
when 'encoding-fiber'
  s = '%41'.dup
  encoding = Object.new
  encoding.define_singleton_method(:to_str) do
    Fiber.yield 'encoding requested'
    s.replace('%ZZ')
    'UTF-8'
  end
  fiber = Fiber.new { Rack::Utils.unescape(s, encoding) }
  show('yield') { fiber.resume }
  show('result') { fiber.resume }
  show('mutated input') { s }
when 'thread'
  workers = 6.times.map do
    Thread.new do
      qp = Rack::QueryParser.make_default(32)
      200.times.all? do
        Rack::Utils.unescape('a+b%2Bc') == 'a b+c' &&
          Rack::Utils.escape('*~ +') == '*%7E+%2B' &&
          qp.parse_nested_query('a[]=1+2&a[]=3%2B4') == {'a' => ['1 2', '3+4']}
      end
    end
  end
  show('threads') { workers.map(&:value) }
end
