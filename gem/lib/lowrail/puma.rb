# frozen_string_literal: true

module Lowrail
  # Explicit opt-in for a preloaded, fork-based Puma server:
  #   require "lowrail/puma"
  #   before_fork { Lowrail::Puma.warmup }
  # Requiring this file alone does nothing and does not load Puma or Rails.
  module Puma
    def self.warmup
      pid = Process.pid
      return false if @warmup_pid == pid
      return false unless GC.respond_to?(:compact) && Process.respond_to?(:warmup)

      @warmup_pid = pid
      GC.compact
      Process.warmup
      true
    rescue StandardError
      # A failed opt-in must not prevent the server from forking. Do not retry
      # partially completed work on another before_fork in this process.
      false
    end
  end
end
