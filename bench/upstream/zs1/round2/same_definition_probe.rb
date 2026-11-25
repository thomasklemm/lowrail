def foob(&b) = b
def foo = yield 3
def cf = [3].map(&:succ)
def t
  b = foob(&:succ)
  [b.equal?(:succ.to_proc), b.lambda?, b.arity, b.inspect.sub(/0x\h+/, ''), foo(&:succ), cf, (foo(&:nope) rescue $!.backtrace.first(4).map { _1.sub(/^.*:\d+:/, '') }), (foo(&:private_methods).class)]
end
r = []
3.times { r << t }
Symbol.define_method(:to_proc, Symbol.instance_method(:to_proc))
3.times { r << t }
Symbol.send(:public, :to_proc)
3.times { r << t }
r.uniq.each { p _1 }
