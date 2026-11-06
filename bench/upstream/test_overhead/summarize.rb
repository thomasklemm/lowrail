# frozen_string_literal: true

require "json"
require "digest"

rows = ARGV.flat_map do |directory|
  Dir[File.join(directory, "*.log")].sort.map do |path|
    log = File.read(path)
    parse = ->(label) { line = log.lines.find { _1.start_with?("#{label} ") }; JSON.parse(line.split(" ", 2).last) if line }
    state = parse.call("PERFCALL_STATE")
    instructions = log[/Collected : (\d+)/, 1]&.to_i
    objects = log[/OBJECTS_PER_CALL ([\d.]+)/, 1]&.to_f
    count = log[/cases\.rb test (\d+)/, 1]&.to_i
    brk_overflow = log.include?("brk segment overflow")
    valid = instructions&.positive? && objects && count&.positive? && state &&
      state["jit_flat"] && state["heap_before"] == state["heap_after"] && !brk_overflow
    { cohort: File.basename(directory), file: File.basename(path), sha256: Digest::SHA256.hexdigest(log),
      status: valid ? "valid_window" : "rejected_or_incomplete", input: parse.call("PTEST"),
      count: count, instructions: instructions, instructions_per_test: valid ? instructions.fdiv(count) : nil,
      objects_per_test: objects, brk_overflow: brk_overflow, state: state }
  end
end
puts JSON.pretty_generate(rows)
