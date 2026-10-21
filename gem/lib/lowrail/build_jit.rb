# frozen_string_literal: true

require_relative "../lowrail"

module Lowrail
  # Shared by the oracle, runtime builders and ISeq compiler, never setup.
  # Only explicit build requests configure JITs; runtime admission observes.
  module BuildJit
    def self.prepare(mode = nil)
      mode ||= ENV["LOWRAIL_BUILD_JIT"]
      mode = {"0" => "interpreter", "1" => "yjit"}.fetch(mode, mode)
      return unless mode
      raise ArgumentError, "unknown certification JIT mode #{mode}" unless %w[interpreter yjit zjit].include?(mode)
      if mode != "yjit" && File.file?("config/application.rb")
        require File.expand_path("config/application")
        Rails.application.config.yjit = false
      end
      RubyVM::YJIT.enable if mode == "yjit" && !RubyVM::YJIT.enabled?
      if mode == "zjit"
        raise "ZJIT unavailable in this Ruby" unless defined?(RubyVM::ZJIT)
        RubyVM::ZJIT.enable unless RubyVM::ZJIT.enabled?
      end
      check(mode)
      mode
    end

    def self.check(mode)
      if mode && mode != Lowrail.jit_mode
        raise "certification JIT mode mismatch: expected #{mode}, observed #{Lowrail.jit_mode}; certification refused"
      end
    end
  end
end
