# frozen_string_literal: true

# Differential probe for skipping the key conflict check when its warning is disabled:
# ruby -I LIB quiet_diff.rb > out; diff two libs' outputs. Rows record results, stored state and the log.
# Lines starting with "accepted" record the two expected differences (ancestors, hook call counts).
require 'hashie'
require 'logger'
require 'stringio'

LOG = StringIO.new
Hashie.logger = Logger.new(LOG)

def show(value)
  case value
  when Hash then "#{value.class.name || 'anon'}{#{value.map { |k, v| "#{k.inspect}(#{k.class})=>#{show(v)}" }.join(',')}}"
  when Array then "#{value.class}[#{value.map { |v| show(v) }.join(',')}]"
  else value.inspect
  end
end

def log
  LOG.string.gsub(/at \S+:\d+/, 'at X').gsub(/0x\h+/, 'X').gsub(/\[[^\]]*#\d+\]/, '[T]').gsub(/#<Class:X>/, 'anon').lines.map { |l| l[/WARN.*/] || l }.join('|')
end

def sub(parent = Hashie::Mash, &body) = Class.new(parent, &body)

ext = Hashie::Extensions::Mash
quiet = sub { disable_warnings }
late = sub
narrowed = sub { disable_warnings; disable_warnings(:zip) }
widened = sub { disable_warnings(:zip); disable_warnings }
dynamic = sub { disable_warnings; def self.disable_warnings?(key = nil) = key != :merge }
direct = sub { disabled_warnings << :zip }
restforce = sub do
  disable_warnings
  def initialize(source_hash = nil, client = nil, default = nil, &blk)
    @client = client
    deep_update(source_hash) if source_hash
    default ? super(default) : super(&blk)
  end

  def dup = self.class.new(self, @client, default)
end
key_store = sub { def self.override_logging = disable_warnings; override_logging }
auth_hash = sub(key_store) do
  def regular_writer(key, value)
    value = self.class.superclass.new(value) if key.eql?('info') && value.is_a?(::Hash)
    super
  end
end

klasses = {
  'Mash' => Hashie::Mash,
  'Sub' => sub,
  'quiet' => quiet,
  'Mash.quiet' => Hashie::Mash.quiet,
  'Mash.quiet(:zip)' => Hashie::Mash.quiet(:zip),
  'quiet(:zip, :size)' => sub { disable_warnings(:zip, :size) },
  'quiet("zip") String' => sub { disable_warnings('zip') },
  'child of quiet' => sub(quiet),
  'child of quiet(:zip)' => sub(Hashie::Mash.quiet(:zip)),
  'child narrows' => sub(quiet) { disable_warnings(:merge) },
  'narrowed' => narrowed,
  'widened' => widened,
  'dynamic disable_warnings?' => dynamic,
  'direct disabled_warnings' => direct,
  'late' => late,
  'Permissive then quiet' => sub { include ext::PermissiveRespondTo; disable_warnings },
  'quiet then Permissive' => sub { disable_warnings; include ext::PermissiveRespondTo },
  'Permissive then quiet(:zip)' => sub { include ext::PermissiveRespondTo; disable_warnings(:zip) },
  'quiet DefineAccessors' => sub { disable_warnings; include ext::DefineAccessors },
  'quiet StrictKeyAccess' => sub { disable_warnings; include ext::StrictKeyAccess },
  'quiet SafeAssignment' => sub { disable_warnings; include ext::SafeAssignment },
  'quiet KeepOriginalKeys' => sub { disable_warnings; include ext::KeepOriginalKeys },
  'quiet SymbolizeKeys' => sub { disable_warnings; include ext::SymbolizeKeys },
  'quiet UnderscoreKeys' => sub { disable_warnings; include ext::UnderscoreKeys },
  'quiet MethodAccessWithOverride' => sub { disable_warnings; include Hashie::Extensions::MethodAccessWithOverride },
  'quiet(:zip) MethodAccessWithOverride' => sub { disable_warnings(:zip); include Hashie::Extensions::MethodAccessWithOverride },
  'quiet own method' => sub { disable_warnings; def info = :own },
  'quiet(:info) own method' => sub { disable_warnings(:info); def info = :own; def other = :own },
  'restforce-like' => restforce,
  'omniauth-like KeyStore' => key_store,
  'omniauth-like AuthHash' => auth_hash
}

to_sym_object = Object.new.tap { |o| def o.to_sym = :zip; def o.to_s = 'zip'; def o.inspect = 'ZIPLIKE' }
bad_to_sym = Object.new.tap { |o| def o.to_sym = 'zip'; def o.to_s = 'badsym'; def o.inspect = 'BADSYM' }
keys = ['zip', :zip, 'size', :merge, 'key', 'default', 'class', 'info', 'other', 'name', :name, 'zip=', 'name=', 'name?', 'zip?', 'zip!', 'zip_', '', 1, nil,
        1.5, [:zip], to_sym_object, bad_to_sym, 'Ünïcode', 'object_id', 'method_missing', '_log_collision?', 'custom_writer', 'respond_to?']
seeds = [{}, { 'zip' => 0, 'name' => 'n' }, { zip: { 'size' => 1, 'x' => [{ 'key' => 2 }] }, 'info' => { 'merge' => 1 } }]

operations = {
  '[]=' => ->(m, k) { m[k] = 1 },
  'method=' => ->(m, k) { m.public_send(:"#{k}=", 1) },
  'update' => ->(m, k) { m.update(k => { 'size' => 1 }) },
  'merge' => ->(m, k) { m.merge(k => [{ 'zip' => 1 }]) },
  'merge block' => ->(m, k) { m.merge(k => 2) { |_key, old, new| [old, new] } },
  'dup' => ->(m, k) { (m[k] = 3; m.dup) },
  'replace' => ->(m, k) { m.replace(k => 1, 'size' => 2) },
  'assign_property' => ->(m, k) { m.assign_property(k, 1) },
  'new' => ->(m, k) { m.class.new(k => { 'zip' => 1, 'size' => [{ 'merge' => 1 }] }) },
  'shallow_update' => ->(m, k) { m.shallow_update(k => 1) },
  'reverse_merge' => ->(m, k) { m.reverse_merge(k => 1) },
  'bang' => ->(m, k) { m.public_send(:"#{k}!") }
}

klasses.each do |label, klass|
  seeds.each_with_index do |seed, si|
    keys.each do |key|
      operations.each do |op, run|
        [false, true].each do |frozen|
          LOG.truncate(0)
          LOG.rewind
          row = begin
            mash = klass.new(seed)
            construction = log
            LOG.truncate(0)
            LOG.rewind
            mash.freeze if frozen
            result = run.call(mash, key)
            [show(result), result.class.name, show(mash), construction, log]
          rescue Exception => e # rubocop:disable Lint/RescueException
            ["#{e.class}: #{e.message.gsub(/0x\h+/, 'X').gsub(/#<Class:X>/, 'anon')}", log]
          end
          puts [label, si, key.inspect, op, frozen, *row].join(' | ')
        end
      end
    end
  end
  flags = [nil, :zip, :size, :merge, 'zip', :name].map { |k| klass.disable_warnings?(k) }
  puts "class #{label} | disable_warnings? #{flags.inspect} | disabled_warnings #{klass.disabled_warnings.inspect}"
end

late_instance = late.new('zip' => 1)
LOG.truncate(0)
LOG.rewind
returned = late.disable_warnings
late_instance['size'] = 1
late.new('merge' => 1)
puts "late disable | returned #{returned.inspect} | #{show(late_instance)} | #{log}"
begin
  Hashie::Mash.disable_warnings
rescue StandardError => e
  puts "base Mash | #{e.class}: #{e.message}"
end
puts "returns | #{sub.disable_warnings(:a, :b).inspect} #{sub.disable_warnings.inspect}"

module Hashie
  module Extensions
    module KeyConflictWarning
      PROBE_BASE_ANCESTORS = [Hashie::Mash.ancestors.size]
    end
  end
end
counts = Hash.new(0)
counting = sub do
  disable_warnings
  define_method(:respond_to_missing?) { |name, priv = false| (counts[:respond_to_missing?] += 1; super(name, priv)) }
  define_singleton_method(:disable_warnings?) { |key = nil| (counts[:disable_warnings?] += 1; super(key)) }
end
counts.clear
counting.new('zip' => 1, 'name' => 2, 'size' => 3)
puts "accepted hook calls for quiet.new of 3 keys | #{counts.sort.inspect}"
puts "accepted ancestors | quiet adds #{quiet.ancestors.size - Hashie::Mash.ancestors.size - 1} module(s): #{(quiet.ancestors - Hashie::Mash.ancestors - [quiet]).inspect} | Mash #{Hashie::Mash.ancestors.size}"
