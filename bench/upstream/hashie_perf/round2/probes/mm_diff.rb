# frozen_string_literal: true

# Differential probe for Mash#method_missing's signature: ruby -I LIB mm_diff.rb > out; diff two libs' outputs.
# Every Mash flavour x seed x frozen x method name x argument shape, called the ways a caller can reach it.
require 'hashie'
require 'logger'
require 'stringio'

LOG = StringIO.new
Hashie.logger = Logger.new(LOG)

def show(value)
  case value
  when Hash then "#{value.class.name || 'anon'}{#{value.map { |k, v| "#{k.inspect}(#{k.class},#{k.frozen?})=>#{show(v)}" }.join(',')}}"
  when Array then "#{value.class}[#{value.map { |v| show(v) }.join(',')}]"
  else "#{value.inspect}:#{value.class}:#{value.frozen?}"
  end
end

SEEN = []
RECORDING = Module.new do
  def assign_property(name, value)
    SEEN << [name, value]
    super
  end
end

klasses = {
  'Mash' => Hashie::Mash,
  'Sub' => Class.new(Hashie::Mash),
  'quiet' => Hashie::Mash.quiet,
  'DefineAccessors' => Class.new(Hashie::Mash) { include Hashie::Extensions::Mash::DefineAccessors },
  'StrictKeyAccess' => Class.new(Hashie::Mash) { include Hashie::Extensions::Mash::StrictKeyAccess },
  'KeepOriginalKeys' => Class.new(Hashie::Mash) { include Hashie::Extensions::Mash::KeepOriginalKeys },
  'SymbolizeKeys' => Class.new(Hashie::Mash) { include Hashie::Extensions::Mash::SymbolizeKeys },
  'PermissiveRespondTo' => Class.new(Hashie::Mash) { include Hashie::Extensions::Mash::PermissiveRespondTo },
  'SafeAssignment' => Class.new(Hashie::Mash) { include Hashie::Extensions::Mash::SafeAssignment },
  'MethodAccessWithOverride' => Class.new(Hashie::Mash) { include Hashie::Extensions::MethodAccessWithOverride },
  'zsuper *args' => Class.new(Hashie::Mash) { def method_missing(name, *args, &blk) = [:own, args.size, super] },
  'super(name)' => Class.new(Hashie::Mash) { def method_missing(name, *args, &blk) = [:own, super(name)] },
  'super(name, *args, &blk)' => Class.new(Hashie::Mash) { def method_missing(name, *args, &blk) = [:own, super(name, *args, &blk)] },
  'super ...' => Class.new(Hashie::Mash) { def method_missing(name, ...) = [:own, super] },
  'ruby2_keywords' => Class.new(Hashie::Mash) { ruby2_keywords def method_missing(name, *args, &blk) = [:own, super(name, *args, &blk)] },
  'prepended' => Class.new(Hashie::Mash) { prepend(Module.new { def method_missing(name, *args, &blk) = [:pre, super] }) },
  'assign_property' => Class.new(Hashie::Mash) { include RECORDING },
  'Singleton' => :singleton,
  'Mash+dp' => Hashie::Mash
}

frozen_array = [1, 2].freeze
hash_arg = { a: 1 }
string_arg = +'text'
shapes = {
  'none' => ->(c) { c.call },
  'one' => ->(c) { c.call(string_arg) },
  'nil' => ->(c) { c.call(nil) },
  'false' => ->(c) { c.call(false) },
  'two' => ->(c) { c.call(string_arg, 2) },
  'three' => ->(c) { c.call(1, 2, 3) },
  'array' => ->(c) { c.call(frozen_array) },
  'hash' => ->(c) { c.call(hash_arg) },
  'nested hash' => ->(c) { c.call({ 'b' => { c: [{ d: 1 }] } }) },
  'kwargs' => ->(c) { c.call(a: 1) },
  'one+kwargs' => ->(c) { c.call(string_arg, a: 1) },
  '**hash' => ->(c) { c.call(**hash_arg) },
  '**empty' => ->(c) { c.call(**{}) },
  '*empty' => ->(c) { c.call(*[]) },
  '*two' => ->(c) { c.call(*frozen_array) },
  '*nil-first' => ->(c) { c.call(*[nil, 5]) },
  'block' => ->(c) { c.call { |v| SEEN << [:block, v] } },
  'one+block' => ->(c) { c.call(string_arg) { |v| SEEN << [:block, v] } },
  'mash' => ->(c) { c.call(Hashie::Mash.new(x: 1)) }
}

names = %i[name name? name! name_ name= new_key new_key? new_key! new_key_ new_key= zip= key= value value= args= owner! Ünïcode= a?=]
seeds = [{}, { 'name' => 'Ada', 'owner' => { 'login' => 'o' }, 'value' => 9, 'args' => [1], 'a?' => 1 }, { name: 'sym', zip: 1 }]
ways = {
  'public_send' => ->(m, n) { ->(*a, **k, &b) { m.public_send(n, *a, **k, &b) } },
  'method_missing' => ->(m, n) { ->(*a, **k, &b) { m.send(:method_missing, n, *a, **k, &b) } },
  'method.call' => ->(m, n) { ->(*a, **k, &b) { m.method(n).call(*a, **k, &b) } },
  'String name' => ->(m, n) { ->(*a, **k, &b) { m.send(:method_missing, n.to_s, *a, **k, &b) } }
}

klasses.each do |label, klass|
  seeds.each_with_index do |seed, si|
    [false, true].each do |frozen|
      names.each do |name|
        shapes.each do |shape, apply|
          ways.each do |way, build|
            LOG.truncate(0)
            LOG.rewind
            SEEN.clear
            mash = begin
              klass == :singleton ? Hashie::Mash.new(seed).tap { |m| m.define_singleton_method(:name) { |*a| [:singleton, a] } } : klass.new(seed)
            rescue ArgumentError => e
              puts [label, si, frozen, name.inspect, shape, way, "new raised #{e.message}"].join(' | ')
              next
            end
            mash.default_proc = proc { |_h, key| [:dp, key, key.frozen?] } if label.end_with?('+dp')
            mash.freeze if frozen
            result = begin
              show(apply.call(build.call(mash, name)))
            rescue Exception => e # rubocop:disable Lint/RescueException
              "#{e.class}: #{e.message.gsub(/0x\h+/, 'X')}"
            end
            stored = mash.values.map { |v| [string_arg, frozen_array, hash_arg].index { |o| o.equal?(v) } }
            seen = SEEN.map { |n, v| [n, show(v), [string_arg, frozen_array, hash_arg].index { |o| o.equal?(v) }] }
            log = LOG.string.gsub(/at \S+:\d+/, 'at X').gsub(/0x\h+/, 'X').gsub(/\[[^\]]*#\d+\]/, '[T]')
            puts [label, si, frozen, name.inspect, shape, way, result, show(mash), stored.inspect, seen.inspect, log.inspect].join(' | ')
          end
        end
      end
    end
  end
end
puts "hash_arg #{hash_arg.inspect} string_arg #{string_arg.inspect}"
