require 'json'

def sig(value)
  case value
  when String
    [value.class.name, value.bytes, value.encoding.name, value.frozen?, value.valid_encoding?]
  when Array
    value.map { |v| sig(v) }
  when Hash
    value.map { |k, v| [sig(k), sig(v)] }
  else
    value
  end
end

def capture
  ['ok', sig(yield)]
rescue Exception => e
  message = e.message.sub(/\n\n.*\z/m, '').gsub(/0x[0-9a-f]+/, '0xADDRESS')
  ['error', e.class.name, message.bytes, message.encoding.name]
end

def emit(label)
  puts JSON.generate([label, capture { yield }])
end

def isolated(label, entry = 'rack/utils')
  STDOUT.flush
  pid = fork do
    require entry
    emit(label) { yield }
  end
  Process.wait(pid)
  abort "child failed: #{label}" unless $?.success?
end

def routes
  qp = Rack::Utils.default_query_parser
  object = Class.new { include Rack::Utils }.new
  extended = Object.new.extend(Rack::Utils)
  module_object = Module.new { include Rack::Utils }
  module_instance = Class.new { include module_object }.new
  extended_class = Class.new.extend(Rack::Utils)
  extended_module = Module.new.extend(Rack::Utils)
  [capture { Rack::Utils.unescape('a+b') },
   capture { Rack::Utils.method(:unescape).call('a+b') },
   capture { object.send(:unescape, 'a+b') },
   capture { extended.send(:unescape, 'a+b') },
   capture { module_instance.send(:unescape, 'a+b') },
   capture { extended_class.send(:unescape, 'a+b') },
   capture { extended_module.send(:unescape, 'a+b') },
   capture { qp.send(:unescape, 'a+b') },
   capture { Rack::Utils.parse_query('a+b=c+d') },
   capture { Rack::Utils.parse_nested_query('a+b=c+d') },
   capture { Rack::Utils.parse_cookies_header('a=a+b') },
   capture { Rack::Utils.escape('*~ +é') }]
end

isolated('baseline') { routes }
isolated('visibility') do
  [Rack::Utils.respond_to?(:unescape), Rack::Utils.private_method_defined?(:unescape),
   Rack::Utils.public_method_defined?(:unescape), Rack::QueryParser.private_method_defined?(:unescape),
   Rack::Utils.method(:unescape).arity, Rack::Utils.method(:unescape).parameters,
   Rack::QueryParser.instance_method(:unescape).parameters,
   Rack::Utils.instance_method(:unescape).owner.name,
   Rack::QueryParser.instance_method(:unescape).owner.name,
   Rack::Utils.private_instance_methods(false).include?(:unescape)]
end
isolated('singleton replacement') do
  Rack::Utils.singleton_class.class_eval { def unescape(*); 'singleton'; end }
  routes
end
isolated('instance replacement') do
  Rack::Utils.module_eval { def unescape(*); 'instance'; end; private :unescape }
  routes
end
isolated('instance replacement super') do
  Rack::Utils.module_eval { def unescape(*args); "instance<#{super}>"; end; private :unescape }
  routes
end
isolated('query parser replacement') do
  Rack::QueryParser.class_eval { def unescape(*); 'query'; end; private :unescape }
  routes
end
isolated('query parser replacement super') do
  Rack::QueryParser.class_eval { def unescape(*args); "query<#{super}>"; end; private :unescape }
  routes
end
isolated('utils instance prepend') do
  Rack::Utils.prepend(Module.new { def unescape(*args); "prepend<#{super}>"; end; private :unescape })
  routes
end
isolated('utils singleton prepend') do
  Rack::Utils.singleton_class.prepend(Module.new { def unescape(*args); "prepend<#{super}>"; end })
  routes
end
isolated('query parser prepend') do
  Rack::QueryParser.prepend(Module.new { def unescape(*args); "prepend<#{super}>"; end; private :unescape })
  routes
end
isolated('reapply module function') do
  Rack::Utils.module_eval { def unescape(*); 'instance'; end; module_function :unescape }
  routes
end
isolated('reapply module function after prepend') do
  Rack::Utils.prepend(Module.new { def unescape(*args); "prepend<#{super}>"; end; private :unescape })
  Rack::Utils.send(:module_function, :unescape)
  routes
end
isolated('alias wrapper utils') do
  Rack::Utils.module_eval do
    alias_method :original_unescape, :unescape
    def unescape(*args); "alias<#{original_unescape(*args)}>"; end
    private :unescape
  end
  routes
end
isolated('alias wrapper query parser') do
  Rack::QueryParser.class_eval do
    alias_method :original_unescape, :unescape
    def unescape(*args); "alias<#{original_unescape(*args)}>"; end
    private :unescape
  end
  routes
end
isolated('remove instance method utils') do
  result = capture { Rack::Utils.send(:remove_method, :unescape); 'removed' }
  [result, routes]
end
isolated('undef instance method utils') do
  Rack::Utils.send(:undef_method, :unescape)
  routes
end
isolated('remove instance method query parser') do
  result = capture { Rack::QueryParser.send(:remove_method, :unescape); 'removed' }
  [result, routes]
end
isolated('undef instance method query parser') do
  Rack::QueryParser.send(:undef_method, :unescape)
  routes
end
isolated('query parser subclass super') do
  parser = Class.new(Rack::QueryParser) do
    def unescape(*args); "sub<#{super}>"; end
    private :unescape
  end.make_default(32)
  Rack::Utils.default_query_parser = parser
  routes
end
isolated('query parser subclass no super') do
  parser = Class.new(Rack::QueryParser) do
    def unescape(s, *); "sub<#{s}>"; end
    private :unescape
  end.make_default(32)
  Rack::Utils.default_query_parser = parser
  routes
end
isolated('query parser subclass includes utils') do
  parser = Class.new(Rack::QueryParser) { include Rack::Utils }.make_default(32)
  [parser.send(:unescape, 'a+b'), parser.parse_query('a+b=c+d')]
end
isolated('visibility on utils only') do
  Rack::Utils.send(:public, :unescape)
  [Rack::Utils.public_method_defined?(:unescape), Rack::QueryParser.private_method_defined?(:unescape), routes]
end
isolated('freeze') do
  Rack::Utils.freeze
  Rack::QueryParser.freeze
  routes
end

['rack', 'rack/query_parser', 'rack/utils', 'rack/request', 'rack/mock_request'].each do |entry|
  pid = fork do
    before = $LOADED_FEATURES.dup
    require entry
    emit("load #{entry}") do
      [($LOADED_FEATURES - before).map { |s| s.sub($LOAD_PATH.first, 'RACK_LIB') },
       Rack.autoload?(:Utils), Rack.autoload?(:QueryParser),
       Rack.const_defined?(:Utils, false), Rack.const_defined?(:QueryParser, false)]
    end
    emit("use #{entry}") do
      [capture { Rack::QueryParser.make_default(32).parse_query('a+b=c+d') },
       capture { Rack::Utils.unescape('a+b') }]
    end
  end
  Process.wait(pid)
  abort "load child failed" unless $?.success?
end

isolated('all encodings') do
  qp = Rack::Utils.default_query_parser
  Encoding.list.each do |encoding|
    ['%', '%2', '%zz', 'a+b%41', "é%", "\xff%".b].each do |bytes|
      s = bytes.dup.force_encoding(encoding).freeze
      emit("encoding #{encoding.name} #{bytes.bytes}") do
        [capture { Rack::Utils.unescape(s) }, capture { qp.send(:unescape, s) },
         capture { URI.decode_www_form_component(s) }, capture { Rack::Utils.escape(s) }]
      end
    end
  end
  'done'
end

if defined?(Ractor)
  isolated('ractor', 'rack') do
    Rack::Utils
    Rack::QueryParser
    require 'rack/ractorize'
    worker = Ractor.new do
      qp = Rack::QueryParser.make_default(32)
      [Rack::Utils.unescape('a+b%41'), Rack::Utils.escape('*~ +é'),
       qp.parse_query('a+b=c+d'), qp.parse_nested_query('x[]=a+b&x[]=c%2Bd'),
       Class.new { include Rack::Utils }.new.send(:unescape, 'a+b')]
    end
    worker.respond_to?(:value) ? worker.value : worker.take
  end
end
