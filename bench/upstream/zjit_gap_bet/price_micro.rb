# Ir per call for two residue shapes of docs/upstream/zjit-gap-census-3.md, under Callgrind:
#   valgrind --tool=callgrind --toggle-collect=rb_ary_cycle ruby [--yjit|--zjit] price_micro.rb CASE N
# The N calls run inside Array#cycle; Ir per call = (Ir at N=200000 - Ir at N=0) / 200000.
# super_block: `super(key)` from a method that got a block, into an ISEQ method that yields
#   (AssociationRoute::Cache#fetch_or_store -> WeakKeyMap#fetch_or_store on Rails main).
# super_plain: the same with an explicit block literal on the inner call removed (no block to pass).
# sym_final / sym_first: `cast(&:value!)` in a method whose final version is reached by exits in an unprofiled
#   branch (fetch_value_at! on shipit), against the same method that never exits.
class Base
  def fetch_or_store(key) = yield(key)
  def plain(key) = key
end

class Cache < Base
  NIL_KEY = Object.new
  def fetch_or_store(key) = super(key.nil? ? NIL_KEY : key)
  def plain(key) = super(key.nil? ? NIL_KEY : key)
end

class Attr
  def value! = 1
end

class Set
  def initialize(attrs) = (@attrs = attrs)
  def cast = yield(Attr.new)

  def fetch(i)
    if (a = @attrs) && (x = a[i])
      x.value!
    else
      cast(&:value!)
    end
  end
end

CASE, N = ARGV[0], Integer(ARGV[1])
cache = Cache.new
lazy = Set.new(nil)
eager = Set.new([Attr.new])
f =
  case CASE
  when "super_block" then -> { cache.fetch_or_store(1) { |k| k } }
  when "super_plain" then -> { cache.plain(1) }
  when "sym_first" then -> { lazy.fetch(0) }
  when "sym_final"
    # Profile only the lazy branch, then take the eager branch until ZJIT has used up its versions.
    2_000.times { lazy.fetch(0) }
    2_000.times { eager.fetch(0) }
    -> { lazy.fetch(0) }
  end
20_000.times { f.() }
GC.disable
[0].cycle(1) { i = 0; while i < N; f.(); i += 1; end }
