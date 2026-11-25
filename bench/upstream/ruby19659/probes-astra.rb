# Run with miniruby, then with --zjit-call-threshold=1 and =2, with and without inlining.
def check(name, expected)
  return unless ARGV.empty? || ARGV.include?(name)
  before = RubyVM::ZJIT.stats if defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?
  actual = yield
  raise "#{name}: #{actual.inspect} != #{expected.inspect}" unless actual == expected
  puts "#{name}: #{actual.inspect}"
  if before && before.key?(:block_iseq_direct_optimized_send_count)
    after = RubyVM::ZJIT.stats
    warn "#{name}: direct=#{after[:block_iseq_direct_optimized_send_count] - before[:block_iseq_direct_optimized_send_count]}"
  end
end

def exit_yielder(x) = [+'lower', yield(x, +'discard'), +'upper']
def exit_caller(x) = exit_yielder(x) { |a| a + 1 }
check('inside-exit', ['lower', 2.5, 'upper']) do
  30.times { exit_caller(1) }
  exit_caller(1.5)
end

def after_yielder(x) = [+'lower', (yield(x, +'discard')) + 7, +'upper']
def after_caller(x) = after_yielder(x) { |a| a }
check('after-exit', ['lower', 8.5, 'upper']) do
  30.times { after_caller(1) }
  after_caller(1.5)
end

def miss_yielder = yield(11, 37, 91)
def miss_forward(&b) = miss_yielder(&b)
def miss_one = miss_forward { |a| a }
def miss_three = miss_forward { |a, b, c| [a, b, c] }
check('proxy-guard-miss', [11, 37, 91]) do
  30.times { miss_one }
  miss_three
end

def poly_yielder = yield(11, 37, 91)
def poly_forward(&b) = poly_yielder(&b)
def poly_zero = poly_forward { :zero }
def poly_one = poly_forward { |a| a }
def poly_three = poly_forward { |a, b, c| [a, b, c] }
check('proxy-polymorphic', [:zero, 11, [11, 37, 91]]) do
  30.times { poly_zero; poly_one; poly_three }
  [poly_zero, poly_one, poly_three]
end

def control_yielder(log)
  [+'lower', yield((log << :first; 11), (log << :second; 37), (log << :third; 91)), +'upper']
end
def redo_caller
  log = []
  count = 0
  result = control_yielder(log) do |a|
    count += 1
    redo if count < 3
    next a + count
  end
  [result, log, count]
end
check('redo-next-once', [['lower', 14, 'upper'], [:first, :second, :third], 3]) do
  30.times { redo_caller }
  redo_caller
end

def break_caller
  log = []
  result = control_yielder(log) { |a| break a + 5 }
  [result, log]
end
check('break-once', [16, [:first, :second, :third]]) do
  30.times { break_caller }
  break_caller
end

def raise_yielder(log)
  [+'lower', yield((log << :first; 11), (log << :second; 37), (log << :third; 91)), +'upper']
ensure
  log << :ensure
end
def raise_caller(bad)
  log = []
  result = begin
    raise_yielder(log) { |a| raise ArgumentError, "block #{a}" if bad; a }
  rescue ArgumentError => e
    e.message
  end
  [result, log]
end
check('block-raise', ['block 11', [:first, :second, :third, :ensure]]) do
  30.times { raise_caller(false) }
  raise_caller(true)
end

def arg_raise_yielder(log, bad)
  yield((log << :first; 11), (log << :second; raise ArgumentError, 'argument' if bad; 37), (log << :third; 91))
end
def arg_raise_caller(bad)
  log = []
  result = begin
    arg_raise_yielder(log, bad) { |a| log << :block; a }
  rescue ArgumentError => e
    e.message
  end
  [result, log]
end
check('argument-raise', ['argument', [:first, :second]]) do
  30.times { arg_raise_caller(false) }
  arg_raise_caller(true)
end

def compact_yielder = [+'lower', yield(+'keep', +'discard', [91]), +'upper']
def compact_caller(do_gc)
  compact_yielder do |a|
    GC.verify_compaction_references(double_heap: true, toward: :empty) if do_gc
    a + '!'
  end
end
check('compact-live-stack', [['lower', 'keep!', 'upper']]) do
  30.times { compact_caller(false) }
  results = 3.times.map { compact_caller(true) }
  results << compact_caller(false)
  results.uniq
end

def many_yielder
  keep = +'alias'
  [+'lower', yield(+'a', +'b', +'c', +'d', +'e', +'f', +'g', +'h', keep, +'discard'), keep]
end
def many_caller(do_gc)
  many_yielder do |a, b, c, d, e, f, g, h|
    GC.verify_compaction_references(double_heap: true, toward: :empty) if do_gc
    [a, b, c, d, e, f, g, h].join('-')
  end
end
check('compact-eight-args', ['lower', 'a-b-c-d-e-f-g-h', 'alias']) do
  30.times { many_caller(false) }
  many_caller(true)
end

def fiber_yielder(n) = [+'lower', yield(n, +'discard'), +'upper']
def fiber_caller(n)
  fiber_yielder(n) do |a|
    local = +"kept#{a}"
    resumed = Fiber.yield([a, local])
    [a, local, resumed]
  end
end
check('fiber-suspended-compact', [[11, 'kept11'], [37, 'kept37'], ['lower', [11, 'kept11', :first], 'upper'], ['lower', [37, 'kept37', :second], 'upper']]) do
  30.times { f = Fiber.new { fiber_caller(1) }; f.resume; f.resume(:warm) }
  f = Fiber.new { fiber_caller(11) }
  g = Fiber.new { fiber_caller(37) }
  first = f.resume
  second = g.resume
  GC.verify_compaction_references(double_heap: true, toward: :empty)
  [first, second, f.resume(:first), g.resume(:second)]
end

def arg_fiber_yielder(log)
  yield((log << :first; 11), (log << :second; Fiber.yield(:argument)), (log << :third; 91))
end
def arg_fiber_caller
  log = []
  [arg_fiber_yielder(log) { |a| log << :block; a }, log]
end
check('fiber-dropped-expression', [:argument, [11, [:first, :second, :third, :block]]]) do
  30.times { f = Fiber.new { arg_fiber_caller }; f.resume; f.resume(37) }
  f = Fiber.new { arg_fiber_caller }
  first = f.resume
  GC.start
  [first, f.resume(37)]
end

def ractor_yielder(n) = [+'lower', yield(n, +'discard', [91]), +'upper']
def ractor_forward(n, &b) = ractor_yielder(n, &b)
def ractor_caller(n)
  ractor_forward(n) do |a|
    GC.start if a % 17 == 0
    a * 3 + 7
  end
end
check('ractor-proxy', [true, true, true, true]) do
  30.times { ractor_caller(1) }
  workers = 4.times.map do |worker|
    Ractor.new(worker) do |w|
      50.times.all? do |i|
        n = 100 * w + i
        ractor_caller(n) == ['lower', n * 3 + 7, 'upper']
      end
    end
  end
  workers.map(&:value)
end
