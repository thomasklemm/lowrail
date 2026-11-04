# frozen_string_literal: true

# Differential harness for Hash#extract!: RAILS=DIR ruby [--yjit|--zjit] diff_extract.rb
# Prints one line per probe; outputs of two checkouts must be identical.
rails = ENV.fetch("RAILS")
%w[activesupport actionpack actionview].each { |c| $LOAD_PATH.unshift File.join(rails, c, "lib") }
require "active_support"
require "active_support/core_ext/hash/slice"
require "active_support/hash_with_indifferent_access"
require "active_support/ordered_options"
require "action_controller"

LOG = []
def show(h) = h.is_a?(Hash) ? [h.class, h.to_a, h.default, h.default_proc&.lambda?, h.frozen?, h.compare_by_identity?] : h
def probe(label, receiver_builder, keys)
  LOG.clear
  receiver = receiver_builder.call
  result = begin
    r = receiver.extract!(*keys)
    show(r.respond_to?(:to_unsafe_h) ? r.to_unsafe_h : r)
  rescue Exception => e
    "raised #{e.class}: #{e.message}"
  end
  after = receiver.respond_to?(:to_unsafe_h) ? show(receiver.to_unsafe_h) : show(receiver)
  puts "#{label} #{keys.inspect}: #{result.inspect} receiver=#{after.inspect} log=#{LOG.inspect}"
end

class Logged < Hash
  def has_key?(k) = (LOG << [:has_key?, k]; super)
  def delete(k) = (LOG << [:delete, k]; super)
  def []=(k, v)
    LOG << [:[]=, k, v]
    super
  end
  def initialize(*a, &b) = (LOG << [:initialize, a.size, !!b]; super)
end
class NeedsArg < Hash
  def initialize(x) = super()
end
class DeleteRaises < Hash
  def delete(k) = k == :b ? raise(KeyError, "no #{k}") : super
end
class Rewrites < Hash
  def delete(k) = (v = super; self[:z] = v; v)
end

base = -> { { a: 1, b: nil, "c" => 3, d: false, 4 => :four } }
builders = {
  "Hash" => base,
  "Hash default" => -> { Hash.new(0).merge!(base.()) },
  "Hash default_proc" => -> { h = Hash.new { |hh, k| LOG << [:default, k]; :dp }; h.merge!(base.()) },
  "compare_by_identity" => -> { h = {}.compare_by_identity; s = "c"; h[s] = 1; h[:a] = 2; h },
  "HWIA" => -> { ActiveSupport::HashWithIndifferentAccess.new(base.()) },
  "OrderedOptions" => -> { o = ActiveSupport::OrderedOptions.new; o[:a] = 1; o[:b] = 2; o },
  "InheritableOptions" => -> { o = ActiveSupport::InheritableOptions.new({ a: 1, b: 2 }); o[:c] = 3; o },
  "Logged subclass" => -> { Logged.new.merge!(base.()) },
  "NeedsArg subclass" => -> { NeedsArg.new(1).merge!(base.()) },
  "DeleteRaises subclass" => -> { DeleteRaises.new.merge!(base.()) },
  "Rewrites subclass" => -> { Rewrites.new.merge!(base.()) },
  "frozen" => -> { base.().freeze },
  "empty frozen" => -> { {}.freeze },
  "singleton has_key?" => -> { h = base.(); def h.has_key?(k) = (LOG << [:singleton_has_key?, k]; k != :a && super); h },
  "extended delete" => -> { h = base.(); h.extend(Module.new { def delete(k) = (LOG << [:ext_delete, k]; super) }); h },
  "Parameters" => -> { ActionController::Parameters.new(base.().transform_keys(&:to_s)) },
}
key_sets = [[], [:a], [:a, :b], [:b, :d], [:x], [:a, :a], ["c", :c], [:d, :x, :a, 4], ["a", :a], [nil], [[:a]]]
builders.each { |label, b| key_sets.each { |keys| probe(label, b, keys) } }
probe("asset tag options", -> { { "media" => "all", "host" => "cdn" } }, %w[protocol extname host skip_pipeline])
puts "done #{RUBY_DESCRIPTION[/\A\S+ \S+/]} #{defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?} #{defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?}"
