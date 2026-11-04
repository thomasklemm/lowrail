# frozen_string_literal: true

# Differential harness for Fanout#build_handle: RAILS=DIR ruby [--yjit|--zjit] diff_fanout.rb
# Prints one line per probe; outputs of two checkouts must be identical.
$LOAD_PATH.unshift File.join(ENV.fetch("RAILS"), "activesupport/lib")
require "active_support"
require "active_support/notifications"

N = ActiveSupport::Notifications
LOG = []
def probe(label)
  LOG.clear
  result = begin
    yield
  rescue Exception => e
    "raised #{e.class}: #{e.message} #{e.respond_to?(:exceptions) ? e.exceptions.map { |x| [x.class, x.message] }.inspect : ""} cause=#{e.cause&.message.inspect}"
  end
  puts "#{label}: #{result.inspect[0, 300]} log=#{LOG.inspect[0, 2000]}"
end

class EventedSub
  def initialize(tag) = @tag = tag
  def start(name, id, payload) = LOG << [@tag, :start, name, id.size, payload.dup]
  def finish(name, id, payload) = LOG << [@tag, :finish, name, id.size, payload.dup]
end
class SilencedSub < EventedSub
  def initialize(tag, silenced) = (super(tag); @silenced = silenced)
  def silenced?(name) = (LOG << [@tag, :silenced?, name]; @silenced)
end
class Raiser
  def initialize(tag, where) = (@tag, @where = tag, where)
  def start(*) = (raise ArgumentError, "#{@tag} start" if @where == :start)
  def finish(*) = (raise KeyError, "#{@tag} finish" if @where == :finish)
end

def fanout_with(kinds, klass = N::Fanout)
  f = klass.new
  kinds.each_with_index do |k, i|
    case k
    when :timed then f.subscribe("e", nil) { |name, s, fi, id, p| LOG << [i, :timed, name, s.class, fi.class, id.size, p.dup] }
    when :mono then f.subscribe("e", nil, monotonic: true) { |name, s, fi, id, p| LOG << [i, :mono, name, s.class, id.size] }
    when :event then f.subscribe("e") { |ev| LOG << [i, :event, ev.name, ev.payload.dup, ev.transaction_id.size, ev.duration.class] }
    when :evented then f.subscribe("e", EventedSub.new(i))
    when :silenced then f.subscribe("e", SilencedSub.new(i, true))
    when :unsilenced then f.subscribe("e", SilencedSub.new(i, false))
    when :regexp then f.subscribe(/\Ae/) { |*a| LOG << [i, :regexp, a[0]] }
    when :all then f.subscribe(nil) { |*a| LOG << [i, :all, a[0]] }
    when :raise_start then f.subscribe("e", Raiser.new(i, :start))
    when :raise_finish then f.subscribe("e", Raiser.new(i, :finish))
    when :raise_block then f.subscribe("e") { |*a| raise IOError, "block #{i}" }
    when :mutate then f.subscribe("e") { |*a| a[4][:seen] = i }
    end
  end
  f
end

KINDS = %i[timed mono event evented silenced unsilenced regexp all mutate]
combos = [[]] + KINDS.map { [_1] } + KINDS.combination(2).to_a + [KINDS, KINDS.reverse,
  %i[timed mono timed event mono], %i[evented silenced unsilenced evented], %i[raise_start timed],
  %i[timed raise_finish], %i[raise_block raise_block], %i[raise_start raise_finish raise_block mono]]

combos.each do |kinds|
  f = fanout_with(kinds)
  inst = N::Instrumenter.new(f)
  probe("instrument #{kinds}") { payload = { a: 1 }; r = inst.instrument("e", payload) { |p| LOG << [:body, p.dup]; :ret }; [r, payload] }
  probe("handle #{kinds}") do
    h = f.build_handle("e", "id1", { b: 2 })
    groups = h.instance_variable_get(:@groups)
    shape = groups.is_a?(Array) ? [groups.class, groups.frozen?, groups.map { |g| [g.class.name, g.instance_variable_get(:@listeners).size] }] : groups
    h.start
    h.finish
    shape
  end
  probe("start/finish #{kinds}") { f.start("e", "id2", { c: 3 }); f.finish("e", "id2", { c: 3 }); :ok }
  probe("other name #{kinds}") { f.build_handle("x", "id3", {}).class.name }
  probe("raise in body #{kinds}") { inst.instrument("e", { d: 4 }) { raise "boom" } }
end

probe("nested") do
  f = fanout_with(%i[timed event])
  inst = N::Instrumenter.new(f)
  inst.instrument("e", { outer: 1 }) { inst.instrument("e", { inner: 1 }) { :x } }
end

probe("unsubscribe between build and finish") do
  f = fanout_with(%i[timed mono])
  s = f.subscribe("e") { |*a| LOG << [:late, a[0]] }
  h = f.build_handle("e", "id", {})
  h.start
  f.unsubscribe(s)
  h.finish
  f.build_handle("e", "id", {}).instance_variable_get(:@groups).size
end

# groups_for is :nodoc:; a subclass overriding it is the accepted override class, recorded here.
class HashMapOverride < Hash
  def map(&) = (LOG << :subclass_map; super)
  def each(&) = (LOG << :subclass_each; super)
end
class OverridingFanout < N::Fanout
  def groups_for(name) = HashMapOverride[super.to_a]
end
probe("groups_for override (Hash subclass with map/each)") do
  f = fanout_with(%i[timed mono], OverridingFanout)
  f.build_handle("e", "id", {}).instance_variable_get(:@groups).map { _1.class.name }
end
class ArrayGroups < N::Fanout
  def groups_for(name) = super.to_a
end
probe("groups_for override (Array of pairs)") do
  f = fanout_with(%i[timed mono], ArrayGroups)
  f.build_handle("e", "id", {}).instance_variable_get(:@groups).map { _1.class.name }
end

probe("group class new raises") do
  f = fanout_with(%i[timed])
  klass = N::Fanout::TimedGroup
  klass.singleton_class.prepend(Module.new { def new(*) = raise(NameError, "nope") })
  f.build_handle("e", "id", {})
end

probe("threads and fibers") do
  f = fanout_with(%i[mono event])
  inst = N::Instrumenter.new(f)
  counts = Array.new(4) { |t| Thread.new { c = 0; 500.times { inst.instrument("e", { t: t }) { c += 1 } }; c } }.map(&:value)
  fib = Fiber.new { inst.instrument("e", {}) { Fiber.yield :in } ; :done }
  [counts, fib.resume, fib.resume, LOG.size].tap { LOG.clear }
end
LOG.clear
puts "done #{RUBY_DESCRIPTION[/\A\S+ \S+/]} #{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?} #{defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?}"
