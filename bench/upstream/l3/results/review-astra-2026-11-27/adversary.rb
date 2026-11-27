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
ActiveRecord::Encryption.configure(primary_key: "a" * 32, deterministic_key: "b" * 32, key_derivation_salt: "c" * 32)
ActiveRecord::Schema.define do
  create_table :samples do |t|
    t.string :a
    t.string :b
    t.string :secret
    t.text :doc
    t.string :tail
  end
end

EVENTS = []
class AdversarialType < ActiveModel::Type::String
  attr_accessor :callback, :at

  %i[cast deserialize serialize changed_in_place?].each do |method|
    define_method(method) do |*args|
      EVENTS << [method, *args]
      if at == method && (fn = callback)
        self.callback = nil
        fn.call
      end
      super(*args)
    end
  end
end
TYPE = AdversarialType.new

class AdversarialCoder
  class << self
    attr_accessor :callback
    def dump(value)
      if fn = callback
        self.callback = nil
        fn.call
      end
      JSON.dump(value) unless value.nil?
    end
    def load(value)
      JSON.parse(value) unless value.nil?
    end
  end
end

class Sample < ActiveRecord::Base
  attribute :a, TYPE
  encrypts :secret
  serialize :doc, coder: AdversarialCoder
end
class OtherSample < ActiveRecord::Base
  self.table_name = "samples"
  attribute :extra, :integer, default: 17
  attribute :a, TYPE
  encrypts :secret
  serialize :doc, coder: AdversarialCoder
end

FACTORY = MessagePack::Factory.new
ActiveRecord::MessagePack::Extensions.install(FACTORY)
ActiveSupport::MessagePack::Extensions.install(FACTORY)
OPS = {
  database: ->(r) { r.attributes_for_database },
  before_cast: ->(r) { r.attributes_before_type_cast },
  marshal: ->(r) { Marshal.load(Marshal.dump(r)).attributes_for_database },
  message_pack: ->(r) { FACTORY.load(FACTORY.dump(r)).attributes_for_database }
}

def normalize(value)
  case value
  when Hash then value.map { |k, v| [k, normalize(v)] }
  when Array then value.map { |v| normalize(v) }
  when String
    value.start_with?('{"p":') ? ["encrypted", ActiveRecord::Encryption.encryptor.decrypt(value)] : value
  else value
  end
end

def record
  Sample.instantiate("id" => 81, "a" => "trigger", "b" => "old", "secret" => nil, "doc" => '{"x":[1]}', "tail" => "end")
end

def run(label)
  EVENTS.clear
  result = Timeout.timeout(10) { yield }
  puts JSON.generate([label, normalize(result), EVENTS])
rescue => error
  puts JSON.generate([label, error.class.name, error.message, EVENTS])
ensure
  TYPE.callback = nil
  AdversarialCoder.callback = nil
end

%i[cast deserialize serialize changed_in_place?].each do |at|
  OPS.each do |op, action|
    %i[assign mutate freeze readonly becomes reset_columns raise reenter].each do |effect|
      run("#{at}/#{op}/#{effect}") do
        r = record
        if at == :cast
          r.a = Object.new.tap { |obj| obj.define_singleton_method(:to_s) { "converted" } }
        elsif at == :changed_in_place?
          r.attributes_for_database
        end
        TYPE.at = at
        nested = nil
        TYPE.callback = -> do
          case effect
          when :assign then r.b = "new"
          when :mutate then r.b << "!"
          when :freeze then r.freeze
          when :readonly then r.readonly!
          when :becomes then r.becomes(OtherSample).b = "via becomes"
          when :reset_columns then Sample.reset_column_information; r.b = "reset"
          when :raise then r.b = "before error"; raise ArgumentError, "intentional"
          when :reenter then nested = action.call(r); r.b = "after nested"
          end
        end
        result = begin
          action.call(r)
        rescue => e
          [e.class.name, e.message]
        end
        TYPE.callback = nil
        [result, nested, r.b, r.accessed_fields, r.changes, r.frozen?, r.readonly?]
      end
    end
  end
end

OPS.each do |op, action|
  %i[fiber thread].each do |kind|
    run("#{kind}/#{op}/assign") do
      r = record
      TYPE.at = :serialize
      paused, resume = Queue.new, Queue.new
      TYPE.callback = -> { kind == :fiber ? Fiber.yield(:paused) : (paused << :paused; resume.pop) }
      if op == :before_cast
        result = action.call(r)
      elsif kind == :fiber
        fiber = Fiber.new { action.call(r) }
        raise "no suspension" unless fiber.resume == :paused
        r.b = "new"
        result = fiber.resume
      else
        thread = Thread.new { action.call(r) }
        raise "no suspension" unless paused.pop == :paused
        r.b = "new"
        resume << true
        result = thread.value
      end
      TYPE.callback = nil
      [result, r.b, r.changes, r.accessed_fields]
    end
  end
  run("coder/#{op}/assign") do
    r = record
    AdversarialCoder.callback = -> { r.tail = "coder changed tail" }
    result = action.call(r)
    AdversarialCoder.callback = nil
    [result, r.tail, r.changes, r.accessed_fields]
  end
end

%i[new loaded readonly frozen becomes partial].each do |kind|
  OPS.each do |op, action|
    run("encryption/#{kind}/#{op}") do
      r = kind == :new ? Sample.new : record
      r.secret = "secret"
      r = Sample.instantiate(r.attributes_for_database) unless kind == :new
      case kind
      when :readonly then r.readonly!
      when :frozen then r.freeze
      when :becomes then r = r.becomes(OtherSample)
      when :partial then r = Sample.instantiate(r.attributes_for_database.slice("id", "secret"))
      end
      first = action.call(r)
      accessed = r.accessed_fields
      second = action.call(r)
      [first, first == second, accessed, r.accessed_fields, r.changes]
    end
  end
end

run("Marshal and MessagePack payload bytes") do
  r = record
  [Marshal.dump(r).unpack1("H*"), FACTORY.dump(r).unpack1("H*"), r.changes, r.accessed_fields]
end
