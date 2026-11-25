# Ruby frames with unusual crefs reaching a Symbol-block send
def foo = yield(3)
out = []
src = "def from_iseq_eval = foo(&:succ)"
RubyVM::InstructionSequence.compile(src).eval
bin = RubyVM::InstructionSequence.compile("def from_binary = foo(&:succ)").to_binary
RubyVM::InstructionSequence.load_from_binary(bin).eval
class C; define_method(:bm) { foo(&:succ) }; end
o = Object.new
blk = proc { foo(&:succ) }
fib = Fiber.new { loop { Fiber.yield foo(&:succ) } }; ractor_ok = true
5.times do
  out << from_iseq_eval << from_binary << C.new.bm << o.instance_exec(&blk) << o.instance_eval("foo(&:succ)")
  out << Thread.new { foo(&:succ) }.value << fib.resume << eval("foo(&:succ)", binding) << C.class_eval { foo(&:succ) }
  out << Ractor.new { o = Object.new; def o.foo = yield(3); o.foo(&:succ) }.value rescue (out << $!.class)
  out << [1,2].each_slice(1).map(&:first)
  out << method(:foo).to_proc.call(&:succ)
end
p out
