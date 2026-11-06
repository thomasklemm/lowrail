# frozen_string_literal: true

require "json"

def median(values)
  sorted = values.sort
  (sorted[(sorted.length - 1) / 2] + sorted[sorted.length / 2]) / 2.0
end

def interval(values)
  random = Random.new(41231)
  samples = 5000.times.map { median(Array.new(values.length) { values.sample(random: random) }) }.sort
  [samples[125], samples[4875]]
end

directories = ARGV
results = directories.to_h do |directory|
  paths = Dir[File.join(directory, "*.jsonl")].sort
  expected_arms = paths.map { File.basename(_1, ".jsonl").match(/\A(.+)-(\d+)\z/)[1] }.uniq.sort
  rows = paths.flat_map do |path|
    arm, repetition = File.basename(path, ".jsonl").match(/\A(.+)-(\d+)\z/).captures
    File.readlines(path).each_with_index.map do |line, index|
      record = JSON.parse(line)
      dump = File.read(path.sub(/\.jsonl\z/, ".cg.#{index + 1}"))
      total = Integer(dump.scan(/^totals: (\d+)$/).last.fetch(0))
      sample = record.fetch("samples").fetch(0)
      { arm: arm, repetition: Integer(repetition), case: record.fetch("case"), count: record.fetch("count"),
        ruby: record.fetch("ruby"),
        ir: total.fdiv(record.fetch("count")), objects: sample.fetch("objects"),
        flat: sample.fetch("flat"), jit_before: sample.fetch("before"), jit_after: sample.fetch("after"),
        warmup: record.fetch("warmup"), warmup_count: record.fetch("warmup_count"),
        heap_before: sample.fetch("heap_before"), heap_after: sample.fetch("heap_after") }
    end
  end
  cases = rows.group_by { _1.fetch(:case) }.transform_values do |case_rows|
    arms = case_rows.group_by { _1.fetch(:arm) }
    base = arms.fetch("base").sort_by { _1.fetch(:repetition) }
    summaries = arms.transform_values do |arm_rows|
      ordered = arm_rows.sort_by { _1.fetch(:repetition) }
      ratios = ordered.zip(base).map { |a, b| (a.fetch(:ir) / b.fetch(:ir) - 1) * 100 }
      { repetitions: ordered.map { _1.fetch(:repetition) },
        ir: median(ordered.map { _1.fetch(:ir) }), objects: median(ordered.map { _1.fetch(:objects) }),
        delta_percent: median(ratios), ci: interval(ratios),
        jit_flat: ordered.all? { _1.fetch(:flat) },
        heap_unchanged: ordered.all? do |row|
          row.fetch(:heap_before).all? do |pool, before|
            page = GC::INTERNAL_CONSTANTS.fetch(:HEAP_PAGE_SIZE) / GC.stat_heap(Integer(pool), :slot_size)
            (row.fetch(:heap_after).fetch(pool) - before).abs <= page
          end
        end }
    end
    aa = summaries.fetch("aa")
    aa[:pass] = aa.fetch(:ci).first <= 0 && aa.fetch(:ci).last >= 0 && aa.fetch(:ci).all? { _1.abs <= 0.5 }
    matched = case_rows.first.fetch(:heap_before).keys.all? do |pool|
      slots = case_rows.flat_map { [_1.fetch(:heap_before).fetch(pool), _1.fetch(:heap_after).fetch(pool)] }
      page = GC::INTERNAL_CONSTANTS.fetch(:HEAP_PAGE_SIZE) / GC.stat_heap(Integer(pool), :slot_size)
      slots.max - slots.min <= page
    end
    complete = arms.keys.sort == expected_arms && summaries.values.all? { _1.fetch(:repetitions) == [1, 2, 3] }
    same_protocol = case_rows.map { _1.values_at(:ruby, :count, :warmup_count) }.uniq.one?
    accepted = complete && same_protocol && aa.fetch(:pass) && matched && summaries.values.all? do |arm|
      arm.fetch(:jit_flat) && arm.fetch(:heap_unchanged)
    end
    { accepted: accepted, complete: complete, same_protocol: same_protocol,
      arms: summaries, heaps_matched: matched, rows: case_rows }
  end
  [File.basename(directory), cases]
end
puts JSON.pretty_generate(results)
