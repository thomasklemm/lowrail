require 'json'
ARGV.each { |name| require name }
if ENV['LOAD_ONLY']
  puts JSON.generate({features: $LOADED_FEATURES.map { |f| f.sub(%r{.*/lib/rack/}, 'rack/') }.grep(%r{\Arack/|/cgi/|/uri/}).sort, constants: Rack.constants(false).map { |c| [c, Rack.autoload?(c)] }.sort_by { |r| r[0].to_s }, utils_defined: !!defined?(Rack::Utils), parser_defined: !!defined?(Rack::QueryParser)})
  exit
end
require 'rack/utils'

def check(name)
  raise "FAIL #{name}" unless yield
  puts "PASS #{name}"
end
u = Rack::Utils
q = Rack::QueryParser
o = Class.new { include Rack::Utils }.new
p = q.make_default(32)
check('Utils singleton public') { u.respond_to?(:unescape) && u.singleton_class.public_method_defined?(:unescape) }
check('Utils instance private') { u.private_method_defined?(:unescape) && !u.public_method_defined?(:unescape) && !o.respond_to?(:unescape) }
check('QueryParser instance private') { q.private_method_defined?(:unescape) && !q.public_method_defined?(:unescape) && !p.respond_to?(:unescape) }
check('arity preserved') { [u.method(:unescape).arity, q.instance_method(:unescape).arity] == [-2, -2] }
check('subclass override super through parse') do
  sub = Class.new(q) do
    private
    def unescape(s, encoding = Encoding::UTF_8)
      "<#{super}>"
    end
  end
  sub.make_default(32).parse_query('k=a%41') == {'<k>' => '<aA>'}
end
check('prepend override super through parse') do
  sub = Class.new(q)
  sub.prepend(Module.new do
    private
    def unescape(s, encoding = Encoding::UTF_8)
      "[#{super}]"
    end
  end)
  sub.make_default(32).parse_query('k=%2B') == {'[k]' => '[+]'}
end
check('include Utils override super') do
  cls = Class.new do
    include Rack::Utils
    def decode(s)
      unescape(s)
    end
    private
    def unescape(s)
      "<#{super}>"
    end
  end
  cls.new.decode('a+b') == '<a b>'
end
check('frozen receivers and strings') do
  u.unescape('a%41'.freeze) == 'aA' && o.freeze.send(:unescape, '+'.freeze) == ' ' && p.freeze.send(:unescape, '%2b'.freeze) == '+'
end
check('late single coercion across fiber suspension') do
  input = '%41'.dup
  count = 0
  enc = Object.new
  enc.define_singleton_method(:to_str) { count += 1; Fiber.yield(:converting); 'UTF-8' }
  fiber = Fiber.new { u.unescape(input, enc) }
  paused = fiber.resume
  input.replace('%ZZ')
  paused == :converting && fiber.resume == 'A' && count == 1
end
check('other Utils methods remain module functions') { u.escape('a *~') == 'a+*%7E' && u.build_nested_query('x' => 'a b') == 'x=a+b' && u.private_method_defined?(:build_query) }
check('Utils singleton prepend and super') do
  mod = Module.new { def unescape(*args); "[#{super}]"; end }
  u.singleton_class.prepend(mod)
  value = u.unescape('%41')
  mod.send(:remove_method, :unescape)
  value == '[A]'
end
check('module_function is a snapshot of instance implementation') do
  u.module_eval { private; def unescape(*); 'replaced'; end }
  u.unescape('%41') == 'A' && o.send(:unescape, '%41') == 'replaced' && p.send(:unescape, '%41') == 'A'
end
puts JSON.generate({utils_parameters: u.method(:unescape).parameters, parser_parameters: q.instance_method(:unescape).parameters, parser_owner: q.instance_method(:unescape).owner.name})
