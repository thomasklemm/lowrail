# frozen_string_literal: true

require "json"
require "active_support/core_ext/class/attribute"

if ENV["VARIANT"] == "constant"
  module ActiveSupport::ClassAttribute
    class << self
      def redefine_method(owner, name, private: false, &block)
        holder = Module.new
        holder.const_set(:OWNER, block.call)
        holder.module_eval("def owner; OWNER; end", __FILE__, __LINE__)
        owner.silence_redefinition_of_method(name)
        owner.define_method(name, holder.instance_method(:owner))
        owner.send(:private, name) if private
      end
    end
  end
end

class Base
  class_attribute :setting, default: :base
end
class Inherited < Base; end
class Overridden < Base; end
Overridden.setting = :child
class Grandchild < Overridden; end

BASE_INSTANCE = Base.new
CHILD_INSTANCE = Overridden.new
OVERRIDDEN_INSTANCE = Base.new
OVERRIDDEN_INSTANCE.setting = :instance

CASES = {
  class_read: ["Base.setting", :base],
  instance_read: ["BASE_INSTANCE.setting", :base],
  predicate: ["Base.setting?", true],
  inherited_read: ["Inherited.setting", :base],
  subclass_override: ["Overridden.setting", :child],
  grandchild_read: ["Grandchild.setting", :child],
  overridden_class_instance: ["CHILD_INSTANCE.setting", :child],
  instance_override: ["OVERRIDDEN_INSTANCE.setting", :instance]
}.freeze

CASES.each do |name, (expression, expected)|
  raise expression unless eval(expression) == expected
  eval <<~RUBY, TOPLEVEL_BINDING, __FILE__, __LINE__ + 1
    def run_#{name}(n)
      i = 0
      while i < n
        #{expression}
        i += 1
      end
    end
  RUBY
end

warmup = Integer(ENV.fetch("WARMUP", 2_000_000))
iterations = Integer(ENV.fetch("ITERATIONS", 5_000_000))
rounds = Integer(ENV.fetch("ROUNDS", 5))
runners = CASES.to_h { |name, _| [name, method(:"run_#{name}")] }
runners.each_value { |runner| runner.call(warmup) }
results = CASES.to_h { |name, _| [name, []] }
rounds.times do |round|
  CASES.keys.rotate(round).each do |name|
    runner = runners.fetch(name)
    GC.start
    before = GC.stat(:total_allocated_objects)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    runner.call(iterations)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    allocated = GC.stat(:total_allocated_objects) - before
    results[name] << { ips: iterations / elapsed, allocations: allocated, iterations: iterations }
  end
end

puts JSON.pretty_generate(
  ruby: RUBY_DESCRIPTION,
  yjit: defined?(RubyVM::YJIT) && RubyVM::YJIT.enabled?,
  zjit: defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?,
  variant: ENV.fetch("VARIANT", "main"),
  warmup: warmup,
  results: results,
  owner_iseq: RubyVM::InstructionSequence.of(Base.method(:__class_attr_setting_owner)).to_a[9]
)
