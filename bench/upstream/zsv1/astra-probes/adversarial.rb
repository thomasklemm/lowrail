$VERBOSE = nil
Warning[:experimental] = false

def check(name, expected)
  actual = yield
  raise "#{name}: expected #{expected.inspect}, got #{actual.inspect}" unless actual == expected
  puts "#{name}: #{actual.inspect}"
end

module Writes
  def write(v) = (@slot = v)
  def write_after = (@slot = yield)
  def next_write(v) = (@next_slot = v)
  def dispatch(v) = [(@slot = v), hook]
end

class Ordinary
  include Writes
  def hook = :base
end

check('singleton metadata and methods', [149, :singleton, :metadata, 73]) do
  o = Ordinary.new.extend(Module.new)
  sc = o.singleton_class
  sc.instance_variable_set(:@slot, :metadata)
  sc.instance_variable_set(:@next_slot, 73)
  def o.class = raise('Ruby class method must not run')
  def o.hook = :singleton
  150.times { |i| raise unless o.dispatch(i) == [i, :singleton] }
  [o.instance_variable_get(:@slot), o.hook, sc.instance_variable_get(:@slot), sc.instance_variable_get(:@next_slot)]
end

check('same shape across unrelated real classes', [300, 89700]) do
  a, b = Class.new(Ordinary), Class.new(Ordinary)
  objects = 300.times.map { |i| (i.even? ? a : b).new.extend(Module.new) }
  objects.each_with_index { |o, i| raise unless o.next_write(i * 2) == i * 2 }
  [objects.count { |o| o.instance_variable_defined?(:@next_slot) }, objects.sum { |o| o.instance_variable_get(:@next_slot) }]
end

[0, 2, 3, 8, 30, 126, 200].each do |count|
  check("capacity #{count}", [299, 300, count + 2, count.zero? ? nil : count - 1]) do
    c = Class.new(Ordinary)
    o = c.new.extend(Module.new)
    count.times { |i| o.instance_variable_set(:"@pad#{i}", i) }
    300.times { |i| o.write(i); o.next_write(i + 1) }
    [o.instance_variable_get(:@slot), o.instance_variable_get(:@next_slot), o.instance_variables.size,
     count.zero? ? nil : o.instance_variable_get(:"@pad#{count - 1}")]
  end
end

check('class module and eigenclass receivers', [299, 299, 299, 299]) do
  owner = Ordinary.new
  receivers = [Class.new, Module.new, owner.singleton_class, owner.singleton_class.singleton_class]
  receivers.map do |o|
    o.extend(Writes)
    300.times { |i| o.write(i) }
    o.instance_variable_get(:@slot)
  end
end

check('generic and typed layouts', [299] * 7) do
  [+'str', [], {}, Object.method(:new), proc {}, Struct.new(:x).new(5), Time.at(0)].map do |o|
    o.extend(Writes)
    300.times { |i| o.write(i) }
    o.instance_variable_get(:@slot)
  end
end

check('immediate and immutable receivers', [FrozenError] * 7) do
  BasicObject.class_eval { def astra_immutable_write = (@astra_immutable = 1) }
  [nil, true, false, 19, 2**100, 1.25, :symbol].map do |o|
    errors = 200.times.map do
      begin; o.astra_immutable_write; rescue FrozenError => e; e.class; end
    end
    raise unless errors.uniq == [FrozenError]
    errors.last
  end
end

check('BasicObject with singleton method', 299) do
  o = BasicObject.new
  class << o
    def write(v) = (@slot = v)
    def read = @slot
  end
  300.times { |i| o.write(i) }
  o.read
end

check('frozen late preserves old value', [FrozenError, 299]) do
  o = Ordinary.new.extend(Module.new)
  300.times { |i| o.write(i) }
  o.freeze
  error = begin; o.write(:wrong); rescue FrozenError => e; e.class; end
  [error, o.instance_variable_get(:@slot)]
end

check('freeze inside writer RHS runs once', [FrozenError, 299, 301]) do
  o = Ordinary.new.extend(Module.new)
  calls = 0
  300.times { |i| o.write_after { calls += 1; i } }
  error = begin; o.write_after { calls += 1; o.freeze; :wrong }; rescue FrozenError => e; e.class; end
  [error, o.instance_variable_get(:@slot), calls]
end

check('grow inside writer RHS runs once', [301, 151, 150]) do
  o = Ordinary.new.extend(Module.new)
  calls = 0
  300.times { |i| o.write_after { calls += 1; i } }
  result = o.write_after do
    calls += 1
    150.times { |i| o.instance_variable_set(:"@rhs#{i}", i) }
    calls
  end
  [result, o.instance_variables.size, o.instance_variable_get(:@rhs149) + 1]
end

check('fiber mutates suspended assignment', [FrozenError, 299]) do
  o = Ordinary.new.extend(Module.new)
  300.times { |i| o.write_after { i } }
  f = Fiber.new { begin; o.write_after { Fiber.yield; :wrong }; rescue FrozenError => e; e.class; end }
  f.resume
  o.freeze
  [f.resume, o.instance_variable_get(:@slot)]
end

check('shape variation exhaustion', [299, 299, true]) do
  c = Class.new(Ordinary)
  40.times { |i| c.new.instance_variable_set(:"@unique_astra_#{i}", i) }
  o = c.new.extend(Module.new)
  o.instance_variable_set(:@unique_astra_final, 1)
  300.times { |i| o.write(i); o.next_write(i) }
  complex = RubyVM::Shape.of(o).complex?
  [o.instance_variable_get(:@slot), o.instance_variable_get(:@next_slot), complex]
end

check('removed ivars plus object id', [299, 299, true]) do
  o = Ordinary.new.extend(Module.new)
  id = o.object_id
  300.times { |i| o.write(i); o.remove_instance_variable(:@slot); o.next_write(-i); o.write(i) }
  [o.instance_variable_get(:@slot), -o.instance_variable_get(:@next_slot), o.object_id == id]
end

check('old receiver young values and compaction', [799, 'heap799']) do
  o = Ordinary.new.extend(Module.new)
  300.times { |i| o.write([i]); o.next_write("heap#{i}") }
  GC.start
  800.times do |i|
    o.write([i])
    o.next_write("heap#{i}")
    GC.start(full_mark: false) if i % 37 == 0
  end
  GC.verify_compaction_references(expand_heap: true, toward: :empty)
  [o.instance_variable_get(:@slot).first, o.instance_variable_get(:@next_slot)]
end

check('anonymous class profile survives compaction', [99, 100]) do
  module SharedCold
    def cold(v) = (@cold_astra = v)
  end
  60.times do
    c = Class.new { include SharedCold }
    o = c.new.extend(Module.new)
    o.cold(1)
  end
  c = o = nil
  GC.start
  GC.verify_compaction_references(expand_heap: true, toward: :empty)
  receiver = Class.new { include SharedCold }.new.extend(Module.new)
  100.times { |i| receiver.cold(i) }
  [receiver.instance_variable_get(:@cold_astra), receiver.cold(100)]
end

if Ruby::Box.enabled?
  check('box-local extended objects and class ivars', [[1, 299, 300], [2, 299, 300]]) do
    [1, 2].map do |marker|
      Ruby::Box.new.eval(<<~RUBY)
        module BW
          def write(v) = (@slot = v)
        end
        class BC
          def self.write(v) = (@slot = v)
        end
        o = BC.new.extend(BW)
        def o.class = raise('must not dispatch class')
        300.times { |i| o.write(i); BC.write(i + 1) }
        [#{marker}, o.instance_variable_get(:@slot), BC.instance_variable_get(:@slot)]
      RUBY
    end
  end

  check('box-specific builtin class ivars', [901, 902, nil]) do
    boxes = [Ruby::Box.new, Ruby::Box.new]
    values = boxes.each_with_index.map do |box, index|
      box.eval(<<~RUBY)
        class String
          def self.box_writer(v) = (@astra_box_slot = v)
        end
        300.times { String.box_writer(#{901 + index}) }
        String.instance_variable_get(:@astra_box_slot)
      RUBY
    end
    values + [String.instance_variable_get(:@astra_box_slot)]
  end
end
