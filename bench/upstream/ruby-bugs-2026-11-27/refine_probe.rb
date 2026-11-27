# Differential probe: every lookup path for many refinement shapes; prints one line per case.
LOOKUPS = {
  direct: ->(o, m) { o.__send__(:instance_eval) { public_send(m) } rescue $!.class },
  send: ->(o, m) { o.send(m) },
  public_send: ->(o, m) { o.public_send(m) },
  method: ->(o, m) { o.method(m).owner.to_s[/\A[^:#<]+|#<Module/] },
  call_method: ->(o, m) { o.method(m).call },
  respond_to: ->(o, m) { o.respond_to?(m) },
  instance_method_owner: ->(o, m) { o.class.instance_method(m).owner.to_s[/\A[^:#<]+|#<Module/] },
  method_defined: ->(o, m) { o.class.method_defined?(m) },
  sym_proc: ->(o, m) { [o].map(&m).first },
  try_convert: ->(o, m) { o.then { |x| x.respond_to?(m, true) } },
}
def run(label, o, m)
  LOOKUPS.each do |k, l|
    r = begin; l.(o, m); rescue Exception => e; e.class; end
    puts "#{label} #{k}: #{r.inspect}"
  end
end
n = 0
[:super_class, :later_module, :class_itself, :prepend, :none].each do |where|
  [:module, :class, :prepended_module].each do |refined|
    [false, true].each do |used|
      n += 1
      P = Class.new { def foo = :p } if where == :super_class && !defined?(P)
      parent = Class.new { def foo = :parent }
      later = Module.new { def foo = :later }
      m = Module.new
      klass = Class.new(where == :none ? Object : parent)
      klass.include(later) if where == :later_module
      klass.include(m) if refined == :module
      klass.prepend(m) if refined == :prepended_module
      klass.class_eval { def foo = :klass } if where == :class_itself
      klass.prepend(Module.new { def foo = [:pre, super] }) if where == :prepend
      target = refined == :class ? klass : m
      r = Module.new { refine(target) { def foo = :refined } }
      o = klass.new
      if used
        # activate in an eval scope only; lookups below run outside it except via this lambda
        res = eval("using r; [o.foo, o.send(:foo), (o.foo rescue $!.class)]", binding)
        puts "#{where}/#{refined}/used in-scope: #{res.inspect}"
      end
      run("#{where}/#{refined}/#{used ? 'used' : 'unused'}", o, :foo)
      neq = Class.new(parent)
      neq.include(m)
      puts "#{where}/#{refined}/#{used} != : #{(neq.new != 1 rescue $!.class).inspect}"
    end
  end
end
# Kernel and Comparable/Enumerable modules
Module.new { refine(Kernel) { def ==(o) = 1 } }
Module.new { refine(Comparable) { def frozen? = :r } }
x = Object.new
puts "kernel ==: #{[x != 1, x.send(:==, x), [x].include?(x), x.method(:==).owner].inspect rescue $!.class}"
puts "comparable frozen?: #{(1.send(:frozen?) rescue $!.class).inspect} #{('a'.respond_to?(:frozen?)).inspect}"
# undef/alias boundary
c = Class.new(Class.new { def bar = :bar }); mm = Module.new; c.include(mm); Module.new { refine(mm) { def bar = 1 } }
puts "alias: #{(c.class_eval { alias_method :baz, :bar }; c.new.baz) rescue $!.class}"
puts "undef: #{(c.class_eval { undef_method :bar }; c.new.respond_to?(:bar)) rescue $!.class}"
