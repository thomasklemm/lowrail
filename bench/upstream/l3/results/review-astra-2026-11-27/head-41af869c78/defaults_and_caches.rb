# frozen_string_literal: true

require "bundler/setup"
require "active_record"
require "active_support/message_pack"
require "active_record/message_pack"
require "json"
require "timeout"

abort "wrong Rails" unless ActiveRecord::Base.method(:find).source_location.first.start_with?(ENV.fetch("RAILS") + "/")
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Migration.verbose = false
ActiveRecord::Schema.define do
  create_table(:cache_records) { |t| t.string :first; t.string :last; t.integer :number; t.string :empty }
end

EVENTS = []
$callback = nil
$trigger = nil
$default_value = "default"

def hook(stage, value)
  EVENTS << [stage, value]
  if stage == $trigger && (callback = $callback)
    $callback = nil
    callback.call
  end
end

class HookType < ActiveModel::Type::String
  %i[cast deserialize serialize changed_in_place?].each do |stage|
    define_method(stage) do |*args|
      hook(stage, args)
      super(*args)
    end
  end
end

class CacheRecord < ActiveRecord::Base
  attribute :first, HookType.new, default: -> { hook(:default, $default_value); $default_value }
end
class OtherCacheRecord < ActiveRecord::Base
  self.table_name = "cache_records"
  attribute :first, HookType.new, default: -> { hook(:default, $default_value); $default_value }
  attribute :extra, :integer, default: 73
end

FACTORY = MessagePack::Factory.new
ActiveRecord::MessagePack::Extensions.install(FACTORY)
ActiveSupport::MessagePack::Extensions.install(FACTORY)

def observe
  yield
rescue StandardError => error
  ["error", error.class.name, error.message.gsub(/0x\h+/, "0x")]
end

def plain(value)
  case value
  when Hash then value.map { |k, v| [plain(k), plain(v)] }
  when Array then value.map { |v| plain(v) }
  when Proc then "Proc"
  when ActiveModel::Attribute
    [value.class.name, value.instance_variables.sort.map { |key| [key, key == :@type ? value.instance_variable_get(key).class.name : plain(value.instance_variable_get(key))] }]
  when Module then value.name || "sentinel"
  when String, Numeric, NilClass, TrueClass, FalseClass, Symbol then value
  else value.class.name
  end
end

def caches(set)
  if set.is_a?(ActiveModel::ReindexedAttributeSet)
    ["reindexed", caches(set.instance_variable_get(:@shared)), caches(set.instance_variable_get(:@own))]
  else
    %i[@casted_values @attributes @materialized].map { |ivar| [ivar, plain(set.instance_variable_get(ivar))] }
  end
end

def state(record)
  raw = caches(record.instance_variable_get(:@attributes))
  accessed = record.accessed_fields
  reads = %w[first last number empty].map { |name| [name, observe { record.public_send(name) }] }
  [raw, accessed, reads, observe { record.changes }, record.accessed_fields,
    caches(record.instance_variable_get(:@attributes)), record.frozen?, record.readonly?]
end

OPS = {
  btc: ->(r) { r.attributes_before_type_cast },
  db: ->(r) { r.attributes_for_database },
  marshal: ->(r) { Marshal.dump(r).unpack1("H*") },
  msgpack: ->(r) { FACTORY.dump(r).unpack1("H*") }
}

def build(shape, trigger)
  record = if trigger == :default
    CacheRecord.new(last: "original", number: 17)
  else
    CacheRecord.instantiate("id" => 23, "first" => "from database", "last" => "original", "number" => 17, "empty" => nil)
  end
  case shape
  when :partial
    record = CacheRecord.instantiate("id" => 23, "last" => "original", "number" => 17)
  when :assigned
    record.first = "assigned" unless trigger == :default
  when :warm
    record.last
    record.number
    record.first unless trigger == :default
  when :db_warm
    record.attributes_for_database unless trigger == :default
  when :frozen then record.freeze
  when :readonly then record.readonly!
  when :becomes then record = record.becomes(OtherCacheRecord)
  when :marshal_loaded then record = Marshal.load(Marshal.dump(record))
  end
  record
end

%i[default cast deserialize serialize changed_in_place?].each do |trigger|
  shapes = trigger == :default ? %i[new partial warm frozen readonly becomes] : %i[loaded assigned warm db_warm frozen readonly becomes marshal_loaded]
  shapes.each do |shape|
    OPS.each do |op, operation|
      %i[assign read mutate raise freeze becomes clear_changes reenter fiber thread].each do |effect|
        $trigger = nil
        $callback = nil
        $default_value = "default"
        record = build(shape, trigger)
        EVENTS.clear
        $trigger = trigger
        nested = nil
        reached = false
        paused, resume = Queue.new, Queue.new
        $callback = -> do
          reached = true
          case effect
          when :assign then record.last = "replacement"; record.number = 29
          when :read then nested = [record.last, record.number, record.attributes.keys]
          when :mutate then record.last << "!"
          when :raise then record.last = "before raise"; raise ArgumentError, "intentional callback"
          when :freeze then record.freeze
          when :becomes then record.becomes(OtherCacheRecord).last = "shared replacement"
          when :clear_changes then record.clear_changes_information; record.last = "cleared replacement"
          when :reenter then nested = observe { operation.call(record) }; record.last = "after nested"
          when :fiber then Fiber.yield(:paused)
          when :thread then paused << :paused; resume.pop
          end
        end
        result = Timeout.timeout(10) do
          if effect == :fiber
            fiber = Fiber.new { observe { operation.call(record) } }
            value = fiber.resume
            if fiber.alive?
              nested = observe { record.last = "fiber replacement"; record.number = 31 }
              value = fiber.resume
            end
            value
          elsif effect == :thread
            worker = Thread.new { observe { operation.call(record) }.tap { paused << :done } }
            if paused.pop == :paused
              nested = observe { record.last = "thread replacement"; record.number = 37 }
              resume << true
            end
            worker.value
          else
            observe { operation.call(record) }
          end
        end
        $callback = nil
        after = state(record)
        second = observe { operation.call(record) }
        puts JSON.generate(["#{trigger}/#{shape}/#{op}/#{effect}", reached, plain(result), plain(nested), after, plain(second), EVENTS])
      end
    end
  end
end

[nil, false, "mutable", [1, 2], { "a" => 3 }].each do |default|
  OPS.each do |op, operation|
    $trigger = nil
    $callback = nil
    $default_value = default
    record = CacheRecord.new(last: "old", number: 11)
    EVENTS.clear
    $trigger = :default
    $callback = -> { record.last = "new" }
    results = 2.times.map { observe { operation.call(record) } }
    $callback = nil
    puts JSON.generate(["default-return/#{default.inspect}/#{op}", plain(results), state(record), EVENTS])
  end
end
