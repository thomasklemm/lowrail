# frozen_string_literal: true

# Differential probe for the suffix-name change: ruby -I LIB c1_diff.rb > out; diff the outputs of two libs.
require 'hashie'
require 'logger'
require 'stringio'

LOG = StringIO.new
Hashie.logger = Logger.new(LOG)

def show(value)
  case value
  when Hash then "#{value.class.name || 'anon'}{#{value.map { |k, v| "#{k.inspect}(#{k.class},#{k.frozen?})=>#{show(v)}" }.join(',')}}"
  when Array then "[#{value.map { |v| show(v) }.join(',')}]"
  else "#{value.inspect}:#{value.class}"
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
  'TransformKeys' => Class.new(Hashie::Mash) { include Hashie::Extensions::Mash::TransformKeys; transform_keys_with(&:downcase) },
  'UnderscoreKeys' => Class.new(Hashie::Mash) { include Hashie::Extensions::Mash::UnderscoreKeys },
  'MethodAccessWithOverride' => Class.new(Hashie::Mash) { include Hashie::Extensions::MethodAccessWithOverride },
  'Subclass mm override' => Class.new(Hashie::Mash) { def method_missing(name, *args, &blk) = name.to_s.end_with?('!') ? [:own, super] : super },
  'Singleton' => :singleton
}
names = %i[name name? name! name_ name= new_key new_key? new_key! new_key_ new_key= zip zip= key key= Ünïcode? 名前= a?= ?! = _ a__ size= private? owner! homepage_ Name=]
names += names.map(&:to_s)
seeds = [{}, { 'name' => 'Ada', 'Name' => 'Up', 'owner' => { 'login' => 'o' }, 'private' => false, 'homepage' => nil, 'a?' => 1, 'Ünïcode' => true }, { name: 'sym', zip: 1 }]

klasses.each do |label, klass|
  seeds.each_with_index do |seed, si|
    [false, true].each do |frozen|
      names.each do |name|
        LOG.truncate(0)
        LOG.rewind
        mash = begin
          klass == :singleton ? Hashie::Mash.new(seed).tap { |m| m.define_singleton_method(:name) { 'singleton' } } : klass.new(seed)
        rescue ArgumentError => e
          puts [label, si, frozen, name.inspect, "new raised #{e.message}"].join(' | ')
          next
        end
        mash.freeze if frozen
        args = name.to_s.end_with?('=') ? ['v'] : []
        result = begin
          r = name.is_a?(String) ? mash.send(:method_missing, name, *args) : mash.public_send(name, *args)
          [r, (r.frozen? if r.is_a?(String))]
        rescue Exception => e # rubocop:disable Lint/RescueException
          "#{e.class}: #{e.message.gsub(/0x\h+/, 'X')}"
        end
        resp = begin
          [mash.respond_to?(name), mash.respond_to?(name, true)]
        rescue Exception => e # rubocop:disable Lint/RescueException
          e.class
        end
        puts [label, si, frozen, name.inspect, show(result), resp.inspect, show(mash), LOG.string.gsub(/at \S+:\d+/, 'at X').gsub(/0x\h+/, 'X').inspect].join(' | ')
        # A second call exercises accessors that DefineAccessors defined on the first.
        second = begin
          name.is_a?(String) ? mash.send(:method_missing, name, *args) : mash.public_send(name, *args)
        rescue Exception => e # rubocop:disable Lint/RescueException
          e.class
        end
        puts "  again #{show(second)} #{show(mash)}"
      end
    end
  end
end
