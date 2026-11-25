# frozen_string_literal: true

load File.expand_path("../../review_probe.rb", __dir__)

class CallbackType < ActiveModel::Type::String
  attr_accessor :effect

  def serialize(value)
    effect&.call
    super
  end
end

CALLBACK_TYPE = CallbackType.new
class SnapshotWidget < ActiveRecord::Base
  self.table_name = "widgets"
  attribute :a, CALLBACK_TYPE
end

def snapshot_record
  SnapshotWidget.instantiate("id" => 101, "a" => "trigger", "b" => "old", "c" => "ok")
end

def extension_case(name)
  LOG.clear
  result = yield
  puts "extension #{name}: #{show(result)}"
  puts "extension #{name} log: #{LOG.inspect}"
rescue => error
  puts "extension #{name}: #{error.class}: #{error.message.lines.first.strip.gsub(/0x\h+/, "0x")}"
ensure
  CALLBACK_TYPE.effect = nil
end

extension_case("serialize writes later column") do
  record = snapshot_record
  CALLBACK_TYPE.effect = -> { CALLBACK_TYPE.effect = nil; record.b = "changed" }
  [record.attributes_for_database, record.b, record.changes]
end

extension_case("serialize writes earlier column") do
  record = snapshot_record
  CALLBACK_TYPE.effect = -> { CALLBACK_TYPE.effect = nil; record.id = 202 }
  [record.attributes_for_database, record.id]
end

extension_case("serialize writes later column then raises") do
  record = snapshot_record
  CALLBACK_TYPE.effect = -> { CALLBACK_TYPE.effect = nil; record.b = "changed"; raise ArgumentError, "callback" }
  error = begin
    record.attributes_for_database
  rescue => exception
    [exception.class.name, exception.message]
  end
  [error, record.attributes_for_database, record.changes]
end

extension_case("fiber suspended during serialize") do
  record = snapshot_record
  CALLBACK_TYPE.effect = -> { CALLBACK_TYPE.effect = nil; Fiber.yield :paused }
  fiber = Fiber.new { record.attributes_for_database }
  paused = fiber.resume
  record.b = "changed"
  [paused, fiber.resume, record.b]
end

extension_case("Marshal serializes while later column changes") do
  record = snapshot_record
  CALLBACK_TYPE.effect = -> { CALLBACK_TYPE.effect = nil; record.b = "changed" }
  [Marshal.load(Marshal.dump(record)).b, record.b]
end

require "active_support/message_pack"
require "active_record/message_pack"
extension_case("MessagePack serializes while later column changes") do
  factory = MessagePack::Factory.new
  ActiveRecord::MessagePack::Extensions.install(factory)
  ActiveSupport::MessagePack::Extensions.install(factory)
  record = snapshot_record
  CALLBACK_TYPE.effect = -> { CALLBACK_TYPE.effect = nil; record.b = "changed" }
  [factory.load(factory.dump(record)).b, record.b]
end

extension_case("standard string type to_s writes later column") do
  SnapshotWidget.attribute :a, :string
  record = snapshot_record
  input = Object.new
  input.define_singleton_method(:to_s) { LOG << :mutating_to_s; record.b = "changed"; "converted" }
  record.a = input
  [record.attributes_for_database, record.b]
end

module TypeExtension
  def serialize(value)
    LOG << :extended_serialize
    super
  end
end

module TypePrepend
  def serialize(value)
    LOG << :prepended_serialize
    super
  end
end

class MissingSerialize < ActiveModel::Type::Value
  def method_missing(name, *args)
    return (LOG << :missing_serialize; args.first) if name == :serialize
    super
  end

  def respond_to_missing?(name, include_private = false)
    name == :serialize || super
  end
end

types = {
  singleton: ActiveModel::Type::Value.new.tap do |type|
    type.define_singleton_method(:serialize) { |value| LOG << :singleton_serialize; value }
  end,
  private_singleton: ActiveModel::Type::Value.new.tap do |type|
    type.define_singleton_method(:serialize) { |value| value }
    type.singleton_class.send(:private, :serialize)
  end,
  extended: ActiveModel::Type::Value.new.extend(TypeExtension),
  prepended: ActiveModel::Type::Value.new.tap { |type| type.singleton_class.prepend(TypePrepend) },
  missing: MissingSerialize.new.tap { |type| type.singleton_class.undef_method(:serialize) }
}

types.each do |name, type|
  extension_case("type dispatch #{name}") do
    SnapshotWidget.attribute :a, type
    record = snapshot_record
    [record.attributes_for_database, record.attributes_before_type_cast]
  end
end

class InputString < String
  def to_s = (LOG << :string_to_s; super)
  def to_str = (LOG << :string_to_str; super)
end

class InputArray < Array
  def to_a = (LOG << :array_to_a; super)
  def each(&block) = (LOG << :array_each; super)
  def map(&block) = (LOG << :array_map; super)
end

class InputHash < Hash
  def to_hash = (LOG << :hash_to_hash; super)
  def each(&block) = (LOG << :hash_each; super)
  def []=(key, value)
    LOG << :hash_store
    super
  end
end

class ConversionInput
  def to_s = (LOG << :input_to_s; "converted")
end

class PrivateConversionInput < ConversionInput
  private :to_s
end

[
  ["string subclass", InputString.new("str"), ActiveModel::Type::Value.new],
  ["array subclass", InputArray[1, false, nil], ActiveModel::Type::Value.new],
  ["hash subclass", InputHash["x", [2]], ActiveModel::Type::Value.new],
  ["frozen string", "frozen".freeze, ActiveModel::Type::Value.new],
  ["frozen array", [3].freeze, ActiveModel::Type::Value.new],
  ["frozen hash", { "q" => 4 }.freeze, ActiveModel::Type::Value.new],
  ["public conversion", ConversionInput.new, ActiveModel::Type::String.new],
  ["private conversion", PrivateConversionInput.new, ActiveModel::Type::String.new]
].each do |name, input, type|
  extension_case("value #{name}") do
    SnapshotWidget.attribute :a, type
    record = snapshot_record
    record.a = input
    first = record.attributes_for_database
    second = record.attributes_for_database
    identity = first["a"].equal?(second["a"])
    result = [first, record.attributes_before_type_cast, identity, first.class.name]
    first.clear
    result << record.attributes_for_database
  end
end

extension_case("empty lazy layout") do
  klass = Class.new(ActiveRecord::Base) { self.table_name = "widgets" }
  record = klass.instantiate({})
  [record.attributes_for_database, record.attributes_before_type_cast]
end

extension_case("frozen result from serialize") do
  type = ActiveModel::Type::Value.new
  type.define_singleton_method(:serialize) { |_value| { "immutable" => 3 }.freeze }
  SnapshotWidget.attribute :a, type
  record = snapshot_record.freeze
  first = record.attributes_for_database
  [first["a"].frozen?, first["a"].equal?(record.attributes_for_database["a"]), first.frozen?]
end
