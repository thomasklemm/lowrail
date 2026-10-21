# frozen_string_literal: true

# Native-only, read-only diagnostic, NOT a supported VM API or a benchmark gate.
# Offsets independently read from this executable's DWARF at Ruby revision
# 229531a6cfbf07e3caef30dbac24a2a3f3fed482. Never reuse them on another binary.
require "digest"
require "fiddle"

module YjitEntryReader
  EXECUTABLE_SHA256 = "fa450b858aa41a97d0f839a4fce6a4a33e07c5da0dc7374330bbf58e39bfc895"
  # RbConfig.ruby describes the installation and can name a different binary.
  # Pin the running executable, not merely the configured Ruby command path.
  raise "unsupported Ruby executable; refusing DWARF pointer reads" unless
    File.file?("/proc/self/exe") && Digest::SHA256.file("/proc/self/exe").hexdigest == EXECUTABLE_SHA256
  raise "DWARF reader requires x86_64 Linux / 64-bit pointers" unless
    RUBY_PLATFORM.include?("x86_64-linux") && Fiddle::SIZEOF_VOIDP == 8

  UNWRAP = Fiddle::Function.new(Fiddle::Handle::DEFAULT["rb_iseqw_to_iseq"],
    [Fiddle::TYPE_VOIDP], Fiddle::TYPE_VOIDP)

  def self.state(iseq)
    raise ArgumentError, "expected InstructionSequence" unless iseq.is_a?(RubyVM::InstructionSequence)
    pointer = UNWRAP.call(Fiddle.dlwrap(iseq))
    state_at(pointer)
  end

  # For a current-process IMEMO/iseq address from ObjectSpace.dump_all only.
  # The companion must keep GC disabled from dump through the final read.
  # Do not accept addresses from another process or an earlier heap dump.
  def self.state_at(pointer)
    pointer = Fiddle::Pointer.new(pointer)
    return nil if pointer[16, 8].unpack1("Q").zero? # lazy/unmaterialized body
    body = Fiddle::Pointer.new(pointer[16, 8].unpack1("Q"))
    { entry: !body[304, 8].unpack1("Q").zero?, calls: body[312, 8].unpack1("Q"),
      exception_entry: !body[320, 8].unpack1("Q").zero?, exception_calls: body[328, 8].unpack1("Q"),
      payload: !body[336, 8].unpack1("Q").zero?,
      threshold: Fiddle::Pointer.new(Fiddle::Handle::DEFAULT["rb_yjit_call_threshold"])[0, 8].unpack1("Q") }
  end
end
