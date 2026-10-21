# frozen_string_literal: true

# Untimed native mechanism diagnostic on an unchanged Rails reader. Run in a
# disposable production blog with --yjit --yjit-stats=quiet --yjit-log=FILE,
# DIAG_LOG=FILE, LOWRAIL=0. Not a request price or a historical worker replay.
require "json"
require_relative "yjit_entry_reader"
require File.expand_path("config/environment", Dir.pwd)
Rails.application.eager_load!

KEYS = %i[compiled_iseq_count compiled_iseq_entry compiled_block_count compiled_blockid_count invalidation_count compile_time_ns vm_insns_count yjit_insns_count].freeze
def snapshot
  RubyVM::YJIT.runtime_stats.slice(*KEYS).merge(log_bytes: File.size(ENV.fetch("DIAG_LOG")))
end
def delta(before, after)
  after.to_h { |key, value| [key, value - before.fetch(key)] }
end

# Compile the caller before taking its helper branch for the first time.
def jitted_caller(receiver)
  receiver.auto_include_nonce_for_styles if $diag_active
end

# Not the singleton-extended .helpers proxy YJIT declines to call directly.
receiver = ApplicationController.new.view_context
target = receiver.method(:auto_include_nonce_for_styles)
iseq = RubyVM::InstructionSequence.of(target)
puts JSON.generate(event: "target", ruby: RUBY_DESCRIPTION, owner: target.owner.name,
  source: target.source_location, iseq: iseq.disasm, entry_state: YjitEntryReader.state(iseq))
before = snapshot
$diag_active = false
10_000.times { jitted_caller(receiver) }
$diag_active = true
10_000.times { jitted_caller(receiver) }
after = snapshot
puts JSON.generate(event: "primed", delta: delta(before, after), counters: after, entry_state: YjitEntryReader.state(iseq))

# Offset the target threshold from the diagnostic loop's own 120th call.
17.times { target.call }
puts JSON.generate(event: "entry_prefill", entry_state: YjitEntryReader.state(iseq))
rows = []
240.times do |index|
  before_state = YjitEntryReader.state(iseq)
  before = snapshot
  value = target.call
  after = snapshot
  rows << { call: index + 1, value: value, delta: delta(before, after), before: before, after: after,
    entry_before: before_state, entry_after: YjitEntryReader.state(iseq) }
end
puts JSON.generate(event: "interpreter_entries", rows: rows)
puts JSON.generate(event: "done", counters: snapshot)
