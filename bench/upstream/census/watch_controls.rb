# frozen_string_literal: true

# Rails main watch, behavior control: calls every Active Support core
# extension defined on Enumerable, Array, Hash, String, Symbol and Range
# with a fixed set of receivers, arguments and block shapes, and prints one
# line per call (result or exception class). Diffed between two Rails
# commits by `script/census watch`; lines that differ between two runs at
# the same commit (the A/A pair) are dropped as nondeterministic. Written
# after 2b88dc1995 changed `Hash#index_with` block arguments unnoticed: the
# census measured allocations and SQL, not results.
#   bundle exec ruby watch_controls.rb   (inside a census app copy)
require "active_support"
require "active_support/all"

ENV["TZ"] = "UTC"
Pair = Struct.new(:left, :right)

# Yields two values per element, unlike Array/Hash.
class TwoValues
  include Enumerable

  def each
    return to_enum(:each) unless block_given?
    yield 1, :a
    yield 2, :b
    self
  end
end

RECEIVERS = {
  Enumerable => -> {
    { "array" => [3, 1, 2], "empty" => [], "pairs" => [[1, :a], [2, :b]], "hash" => { a: 1, b: 2 },
      "hwia" => ActiveSupport::HashWithIndifferentAccess.new("a" => 1, "b" => 2), "struct" => Pair.new(1, 2),
      "range" => (1..3), "set" => Set[1, 2], "two_values" => TwoValues.new, "each_slice" => [1, 2, 3].each_slice(2) }
  },
  Array => -> { { "array" => [1, nil, "", [2], { k: 1 }], "empty" => [], "words" => %w[a b c] } },
  Hash => -> {
    { "hash" => { a: 1, "b" => { c: [2, { d: nil }] }, e: "" }, "empty" => {},
      "hwia" => ActiveSupport::HashWithIndifferentAccess.new("a" => 1, "b" => { "c" => 2 }) }
  },
  String => -> { { "snake" => +"hello_world Foo", "empty" => +"", "unicode" => +"Ümlaut ß ǅ", "spaces" => +"  a  b  " } },
  Symbol => -> { { "symbol" => :hello_world } },
  Range => -> { { "ints" => (1..5), "exclusive" => (1...5), "letters" => ("a".."c") } },
}.freeze

ARGUMENTS = [[], [2], [:a], ["b"]].freeze
BLOCKS = {
  "" => nil,
  "{|x|}" => proc { |x| x.inspect },
  "{|a, b|}" => proc { |a, b| [a, b].inspect },
}.freeze
# Mutating or environment-dependent; a few would also print the process.
SKIP = %i[load require_dependency silence_warnings enable_warnings with_warnings suppress capture
  instance_variable_names instance_values to_time to_datetime in_time_zone constantize safe_constantize].freeze

def show(value)
  value = value.to_a.first(20) if value.is_a?(Enumerator)
  value.inspect.gsub(/0x\h+/, "0x").then { _1.size > 160 ? "#{_1[0, 160]}…" : _1 }
end

def active_support_methods(mod)
  mod.instance_methods(false).concat(mod.private_instance_methods(false)).select do |name|
    file = mod.instance_method(name).source_location&.first
    file&.include?("/active_support/") && !SKIP.include?(name) && !name.end_with?("=")
  end.sort
end

RECEIVERS.each do |mod, receivers|
  active_support_methods(mod).each do |name|
    receivers.call.each_key do |key|
      ARGUMENTS.each do |args|
        BLOCKS.each do |label, block|
          receiver = receivers.call.fetch(key)
          result = begin
            show(receiver.__send__(name, *args, &block))
          rescue StandardError => e
            "! #{e.class}"
          end
          puts "#{mod}##{name} #{key}(#{args.map(&:inspect).join(", ")})#{label} => #{result}"
        end
      end
    end
  end
end
