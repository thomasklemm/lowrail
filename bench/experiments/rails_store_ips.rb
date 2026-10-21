# frozen_string_literal: true

require "json"
require "active_record"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
ActiveRecord::Schema.define do
  create_table :users do |t|
    t.text :settings
    t.json :preferences
  end
end

class User < ActiveRecord::Base
  store :settings, accessors: [:color], coder: JSON
  store_accessor :preferences, :theme
end

if ENV["VARIANT"] == "plain"
  User::GeneratedStoreMethods.module_eval <<~RUBY, __FILE__, __LINE__ + 1
    def color
      read_store_attribute(:settings, :color)
    end

    def theme
      read_store_attribute(:preferences, :theme)
    end
  RUBY
end

class DecoratedUser < User
  def color
    super || :missing
  end
end

USER = User.new(settings: { color: "blue" }, preferences: { "theme" => "dark" })
DECORATED = DecoratedUser.new(settings: { color: "red" })
CASES = {
  serialized_reader: ["USER.color", "blue"],
  json_reader: ["USER.theme", "dark"],
  overridden_reader_with_super: ["DECORATED.color", "red"]
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

warmup = 1_000_000
iterations = 3_000_000
runners = CASES.to_h { |name, _| [name, method(:"run_#{name}")] }
runners.each_value { |runner| runner.call(warmup) }
results = CASES.to_h { |name, _| [name, []] }
5.times do |round|
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
  rails: ActiveRecord.version.to_s,
  store_source: User.instance_method(:color).source_location,
  variant: ENV.fetch("VARIANT", "main"),
  warmup: warmup,
  results: results,
  reader_iseq: RubyVM::InstructionSequence.of(User.instance_method(:color)).to_a[9]
)
