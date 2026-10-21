# frozen_string_literal: true

require "json"
require "active_record"
require "active_support/code_generator"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :entries do |t|
    t.string :entryable_type
    t.integer :entryable_id
  end
end

class Message < ActiveRecord::Base; end
class Entry < ActiveRecord::Base
  delegated_type :entryable, types: %w[Message Comment]
end
class AnotherEntry < ActiveRecord::Base
  self.table_name = "entries"
  delegated_type :entryable, types: %w[Message Comment]
end

if ENV["VARIANT"] == "codegen"
  [Entry, AnotherEntry].each do |model|
    ActiveSupport::CodeGenerator.batch(model, __FILE__, __LINE__) do |generator|
      generator.define_cached_method(:__entryable_name, as: :entryable_name, namespace: :survey_delegated_type) do |batch|
        batch << "def __entryable_name; public_send(:entryable_class).model_name.singular.inquiry; end"
      end
    end
  end
elsif %w[symbol hoist].include?(ENV["VARIANT"])
  [Entry, AnotherEntry].each do |model|
    role = :entryable
    role_class = ENV["VARIANT"] == "symbol" ? :"#{role}_class" : "#{role}_class"
    model.define_method(:entryable_name) { public_send(role_class).model_name.singular.inquiry }
  end
end

ENTRY = Entry.new(entryable_type: "Message", entryable_id: 7)
ANOTHER = AnotherEntry.new(entryable_type: "Message", entryable_id: 11)
raise unless ENTRY.entryable_name.message? && ANOTHER.entryable_name.message?

def monomorphic(n)
  i = 0
  while i < n
    ENTRY.entryable_name
    i += 1
  end
end

def polymorphic(n)
  i = 0
  while i < n
    ENTRY.entryable_name
    ANOTHER.entryable_name
    i += 1
  end
end

iterations = Integer(ENV.fetch("ITERATIONS", "1000000"))
runners = { monomorphic: method(:monomorphic), polymorphic: method(:polymorphic) }
runners.each_value { _1.call(500_000) }
results = runners.to_h { |name, _| [name, []] }
5.times do |round|
  runners.keys.rotate(round).each do |name|
    runner = runners.fetch(name)
    GC.start
    before = GC.stat(:total_allocated_objects)
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    runner.call(iterations)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    allocated = GC.stat(:total_allocated_objects) - before
    calls = name == :polymorphic ? iterations * 2 : iterations
    results[name] << { ips: calls / elapsed, allocations: allocated, iterations: calls }
  end
end

puts JSON.pretty_generate(ruby: RUBY_DESCRIPTION, rails: ActiveRecord.version.to_s,
  variant: ENV.fetch("VARIANT", "main"), results: results,
  iseq_type: RubyVM::InstructionSequence.of(Entry.instance_method(:entryable_name)).to_a[9])
