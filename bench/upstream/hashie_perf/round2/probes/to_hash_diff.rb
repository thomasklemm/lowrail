# frozen_string_literal: true

# Differential probe for Hashie::Hash#to_hash reading each value once:
# ruby -I LIB to_hash_diff.rb > out; diff two libs' outputs. "accepted" lines record the expected read counts.
require 'hashie'
require 'json'
require 'logger'
require 'stringio'

Hashie.logger = Logger.new(StringIO.new)

def show(value)
  case value
  when Hash then "#{value.class.name || 'anon'}{#{value.map { |k, v| "#{k.inspect}(#{k.class})=>#{show(v)}" }.join(',')}}#{"dp" if value.default_proc}#{"d=#{value.default.inspect}" if value.default}"
  when Array then "#{value.class}[#{value.map { |v| show(v) }.join(',')}]"
  else "#{value.inspect.gsub(/0x\h+/, 'X')}:#{value.class.name}:#{value.frozen?}"
  end
end

ext = Hashie::Extensions::Mash
class Person < Hashie::Dash
  property :name
end
zero = Class.new { def to_hash = { zero: 1 } }
one = Class.new { def to_hash(options = {}) = { one: options.keys } }
missing = Class.new do
  def respond_to_missing?(name, _priv = false) = name == :to_hash
  def method_missing(name, *args) = name == :to_hash ? { mm: args.size } : super
end
info = Class.new(Hashie::Mash) do
  disable_warnings
  def to_hash
    hash = super
    hash['name'] ||= 'derived'
    hash
  end
end
reads = Hash.new(0)
counting = Class.new(Hashie::Hash) do
  define_method(:[]) { |key| (reads[key] += 1; super(key)) }
end
copying = Class.new(Hashie::Hash) { def [](key) = super.dup }
alternating = Class.new(Hashie::Hash) do
  def [](key) = (@n = (@n || 0) + 1).odd? ? super : [super]
end

klasses = {
  'Hashie::Hash' => Hashie::Hash,
  'Mash' => Hashie::Mash,
  'Mash sub' => Class.new(Hashie::Mash),
  'StrictKeyAccess' => Class.new(Hashie::Mash) { include ext::StrictKeyAccess },
  'KeepOriginalKeys' => Class.new(Hashie::Mash) { include ext::KeepOriginalKeys },
  'SymbolizeKeys' => Class.new(Hashie::Mash) { include ext::SymbolizeKeys },
  'DefineAccessors' => Class.new(Hashie::Mash) { include ext::DefineAccessors },
  'MethodAccessWithOverride' => Class.new(Hashie::Mash) { include Hashie::Extensions::MethodAccessWithOverride },
  'InfoHash-like' => info,
  'IndifferentAccess' => Class.new(Hashie::Hash) { include Hashie::Extensions::MergeInitializer; include Hashie::Extensions::IndifferentAccess },
  'copying []' => copying,
  'Clash' => Hashie::Clash,
  'Rash' => Hashie::Rash
}
values = {
  'scalars' => { 'a' => 1, b: 'two', 3 => nil, nil => false, 'f' => 1.5 },
  'nested' => { 'user' => { 'name' => 'Ada', tags: [{ 'k' => 1 }, [2, { z: 3 }], 'x'] }, 'empty' => {}, 'list' => [] },
  'objects' => { 'zero' => zero.new, 'one' => one.new, 'mm' => missing.new, 'list' => [zero.new, one.new, missing.new, nil] },
  'hashie' => { 'mash' => Hashie::Mash.new(x: { y: 1 }), 'dash' => Person.new(name: 'Ada'), 'hash' => Hashie::Hash[q: [Hashie::Mash.new(r: 1)]], 'info' => info.new(email: 'a@b') },
  'arrays' => { 'frozen' => [1, { a: 1 }].freeze, 'hashie array' => Hashie::Array[{ 'a' => 1 }], 'sub' => Class.new(Array).new([1]) },
  'conflicts' => { 'zip' => 1, 'size' => [1], 'key' => { 'default' => 1 }, 'to_hash' => 1, 'class' => 2 }
}
options = [{}, { stringify_keys: true }, { symbolize_keys: true }, { stringify_keys: true, symbolize_keys: true }, { other: 1 }]

klasses.each do |label, klass|
  values.each do |vlabel, source|
    options.each do |opts|
      [false, true].each do |frozen|
        %i[none default proc].each do |default|
          row = begin
            hash = klass == Hashie::Rash ? klass.new(source) : klass.new
            source.each { |k, v| hash[k] = v } unless klass == Hashie::Rash || klass == Hashie::Clash
            hash.default = 'D' if default == :default && hash.respond_to?(:default=)
            hash.default_proc = proc { |_h, k| "proc #{k}" } if default == :proc && hash.respond_to?(:default_proc=)
            hash.freeze if frozen
            result = opts.empty? ? hash.to_hash : hash.to_hash(opts)
            json = begin
              hash.to_json
            rescue StandardError => e
              e.class
            end
            [show(result), result.equal?(hash), show(hash), json.to_s.gsub(/0x\h+/, 'X')]
          rescue Exception => e # rubocop:disable Lint/RescueException
            ["#{e.class}: #{e.message.gsub(/0x\h+/, 'X')}"]
          end
          puts [label, vlabel, opts.inspect, frozen, default, *row].join(" | ").gsub(/#<Class:0x\h+>/, "anon")
        end
      end
    end
  end
end

alt = alternating.new
alt.merge!('a' => 1, 'b' => [2])
puts "alternating [] | #{begin; show(alt.to_hash); rescue StandardError => e; e.class; end}"
counted = counting.new
counted.merge!('scalar' => 1, 'array' => [1, 2], 'hash' => { 'a' => 1 })
counted.to_hash
puts "accepted reads per key | #{reads.sort.inspect}"
calls = 0
with_proc = Hashie::Mash.new('a' => 1, 'b' => [1])
with_proc.default_proc = proc { |_h, _k| calls += 1 }
with_proc.to_hash
puts "default proc calls for stored keys | #{calls}"
