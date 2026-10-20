# frozen_string_literal: true

# Run in a corpus app, production, Ruby --yjit. No database writes. Repeated
# real SQL rows isolate Ruby loading from SQL and permit exactly 1/20/200 rows
# even in small fixtures. BENCH_MODEL names a real model; BENCH_JSON is output.
if ENV["BENCH_PROFILE"]
  spec = Gem::Specification.find_by_name("stackprof")
  $LOAD_PATH.unshift(*spec.full_require_paths)
end
require File.expand_path("config/environment", Dir.pwd)
require "json"
Rails.application.eager_load!
Rails.logger.level = :error
ActiveRecord::Base.logger = nil
abort "YJIT required" unless RubyVM::YJIT.enabled?

model = Object.const_get(ENV.fetch("BENCH_MODEL"))
model.define_attribute_methods
sample = model.with_connection { |c| c.select_all(model.unscoped.limit(20).arel) }
abort "seed #{model.name} first" if sample.empty?
seconds = Float(ENV.fetch("BENCH_SECONDS", "1"))
rounds = Integer(ENV.fetch("BENCH_ROUNDS", "5"))
builder = model.attributes_builder
record = sample.indexed_rows.first
column_types = sample.column_types.reject { |key, _| model.attribute_types.key?(key) }
result_types = sample.column_types.empty? ? nil : sample.columns.each_index.map { sample.column_types[_1] }
attributes = builder.build_from_database(record, column_types)
probe = model.allocate.init_with_attributes(attributes)
internals = probe.method(:init_internals)
callbacks = -> { probe.send(:_run_find_callbacks); probe.send(:_run_initialize_callbacks) }
rows = []

def measure(seconds, block)
  300.times { block.call }
  GC.start
  hits = PassProbe.counts if defined?(PassProbe)
  before = GC.stat(:total_allocated_objects)
  n = 0
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  deadline = start + seconds
  while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
    block.call
    n += 1
  end
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
  sample = { us: elapsed * 1e6 / n, allocations: (GC.stat(:total_allocated_objects) - before).fdiv(n) }
  sample.merge!(PassProbe.sample(n, hits)) if defined?(PassProbe)
  sample
end

cases = {
  "attributes_builder_lookup_per_row" => -> { model.attributes_builder },
  "allocate_per_row" => -> { model.allocate },
  "builder_per_row" => -> { builder.build_from_database(record, column_types) },
  "init_with_attributes_per_row" => -> { model.allocate.init_with_attributes(attributes) },
  "init_internals_per_row" => -> { internals.call },
  "callbacks_per_row" => callbacks,
  "instantiate_instance_of_per_row" => -> { model.send(:instantiate_instance_of, model, record, column_types) },
  "instrumentation_per_result" => -> {
    ActiveSupport::Notifications.instrumenter.instrument("instantiation.active_record", { record_count: 20, class_name: model.name }) {}
  }
}
plan = model.instance_variable_get(:@_lowrail_instantiate)
if ENV["LOWRAIL"] == "1"
  abort "selected model variant is inactive" unless plan && plan.valid?
  abort "selected result uses STI fallback" if sample.includes_column?(model.inheritance_column)
end
if plan
  plan.valid?
  plan.builder
  cases["guard_per_row"] = -> { plan.current? }
  cases["epoch_per_row"] = -> { Lowrail::AR.epoch(model) }
end
[1, 20, 200].each do |size|
  values = Array.new(size) { sample.rows[_1 % sample.length] }
  result = ActiveRecord::Result.new(sample.columns, values, result_types)
  result.indexed_rows # warm, separately measure fresh result/index construction
  cases["indexed_rows_fresh_#{size}"] = -> { ActiveRecord::Result.new(sample.columns, values, result_types).indexed_rows }
  cases["load_#{size}"] = -> { model._load_from_sql(result) }
  cases["load_and_read_#{size}"] = -> { model._load_from_sql(result).each { |r| r.attributes } }
  cases["column_types_#{size}"] = -> {
    types = result.column_types
    types.reject { |key, _| model.attribute_types.key?(key) } unless types.empty?
  }
end
if ENV["BENCH_CASES"]
  names = ENV.fetch("BENCH_CASES").split(",")
  cases.select! { |name, _| names.include?(name) }
end
rounds.times do |round|
  (round.even? ? cases.to_a : cases.to_a.reverse).each do |name, block|
    rows << measure(seconds, block).merge(case: name, round: round)
  end
end
abort "model guard changed during measurement" if plan && !plan.current?
summary = rows.group_by { _1[:case] }.map do |name, runs|
  times = runs.map { _1[:us] }.sort
  allocs = runs.map { _1[:allocations] }.sort
  { case: name, median_us: times[times.size / 2], min_us: times.first, max_us: times.last,
    allocations: allocs[allocs.size / 2] }
end
output = { ruby: RUBY_DESCRIPTION, rails: Rails.version, model: model.name,
  find_callbacks: model._find_callbacks.count, initialize_callbacks: model._initialize_callbacks.count,
  result_columns: sample.columns, additional_types: sample.column_types.size,
  summary: summary, samples: rows }
File.write(ENV.fetch("BENCH_JSON"), JSON.pretty_generate(output))
puts JSON.pretty_generate(output.except(:samples))

if (path = ENV["BENCH_PROFILE"])
  require "stackprof"
  profile = StackProf.run(mode: :cpu, interval: 100, raw: true) do
    deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + 5
    while Process.clock_gettime(Process::CLOCK_MONOTONIC) < deadline
      cases.fetch("load_and_read_200").call
    end
  end
  File.write(path, JSON.generate(profile))
end
