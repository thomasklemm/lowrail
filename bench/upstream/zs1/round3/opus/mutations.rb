# One Symbol#to_proc mutation per process (ARGV[0]); identity, lambda?, result before and after.
SYMS = 200.times.map { |i| :"evict_#{i}" }
def materialize(&b)
  SYMS.each(&:to_proc)
  [b.equal?(:succ.to_proc), b.lambda?, b.call(1)] rescue [$!.class]
end
def iseq = materialize(&:succ)
def cfunc = [1].flat_map(&:succ)
def variadic = [1].sum(&:succ)
def run = [iseq, (cfunc rescue $!.class), (variadic rescue $!.class)]
r = [run, run, run]
case ARGV[0]
when "same_def" then Symbol.define_method(:to_proc, Symbol.instance_method(:to_proc))
when "public" then Symbol.class_eval { public :to_proc }
when "private_public" then Symbol.class_eval { private :to_proc; public :to_proc }
when "prepend_empty" then Symbol.prepend(Module.new)
when "prepend_def" then Symbol.prepend(Module.new { def to_proc = proc { |x| x + 100 } })
when "include_def" then Symbol.include(Module.new { def to_proc = proc { |x| x + 100 } })
when "alias_self" then Symbol.class_eval { alias_method :to_proc, :to_proc }
when "alias_other" then Symbol.class_eval { alias_method :old_to_proc, :to_proc; def to_proc = old_to_proc }
when "singleton" then (s = :succ; s.singleton_class) rescue nil
when "refine_unused" then Module.new { refine(Symbol) { def to_proc = proc { 0 } } }
when "compact" then GC.verify_compaction_references(expand_heap: true, toward: :empty) rescue GC.compact
when "same_def_compact" then Symbol.define_method(:to_proc, Symbol.instance_method(:to_proc)); GC.compact
when "none" then nil
end
r << run << run << run
p r
