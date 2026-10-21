# frozen_string_literal: true

# Bounded native counterexamples to treating an entry census as sufficient.
# No Rails, Valgrind, compiler writes, threshold override or benchmark windows.
# Run pinned Ruby --yjit --disable-zjit --yjit-log=FILE with DIAG_LOG=FILE.
require "json"
require_relative "yjit_entry_reader"

class YjitEntryPaths
  def optional(value = :default) = value
  def branch(value) = value ? :yes : :no
  def exception(raise_error)
    raise ArgumentError if raise_error
    :ok
  rescue ArgumentError
    :rescued
  end
end

def path_snapshot
  RubyVM::YJIT.runtime_stats.slice(:compiled_iseq_count, :compiled_iseq_entry,
    :compiled_block_count, :compiled_blockid_count, :invalidation_count).merge(log_bytes: File.size(ENV.fetch("DIAG_LOG")))
end

object = YjitEntryPaths.new
%i[optional branch exception].each do |name|
  target = object.method(name)
  iseq = RubyVM::InstructionSequence.of(target)
  # Keep the reader/counter observation shape hot before recording the target.
  1_000.times { YjitEntryReader.state(iseq); path_snapshot }
  1_000.times { target.call(name == :exception ? false : true) }
  state_before = YjitEntryReader.state(iseq)
  before = path_snapshot
  result = name == :optional ? target.call : target.call(name == :exception)
  after = path_snapshot
  puts JSON.generate(path: name, result: result, state_before: state_before,
    state_after: YjitEntryReader.state(iseq),
    delta: after.to_h { |key, value| [key, value - before.fetch(key)] })
end

# Exception entries belong to the catch ISeq, not necessarily its parent.
# Wrapper materialization here is diagnostic only and happens before priming.
rescue_iseq = nil
parent = RubyVM::InstructionSequence.of(object.method(:exception))
parent.each_child { rescue_iseq = _1 if _1.label == "rescue in exception" }
raise "rescue ISeq missing" unless rescue_iseq
threshold = YjitEntryReader.state(rescue_iseq).fetch(:threshold)
threshold.times do
  break if YjitEntryReader.state(rescue_iseq).fetch(:exception_calls) >= threshold - 1
  object.exception(true)
end
state_before = YjitEntryReader.state(rescue_iseq)
before = path_snapshot
result = object.exception(true)
after = path_snapshot
puts JSON.generate(path: "exception_entry", result: result, state_before: state_before,
  state_after: YjitEntryReader.state(rescue_iseq), parent_state: YjitEntryReader.state(parent),
  delta: after.to_h { |key, value| [key, value - before.fetch(key)] })
