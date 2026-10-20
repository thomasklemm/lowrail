# frozen_string_literal: true

module Lowrail
  # Installed through RUBYOPT before Bundler, without activating RSpec (or
  # any default gem). Attach an ordinary formatter once rspec/core loads.
  module RSpec
    def self.install(path)
      return if @path
      @path = path
      return if attach
      # Do not wrap Kernel#require: Bootsnap aliases that method and an
      # inherited prepend would make its original-require alias recurse.
      # This temporary hook disappears as soon as RSpec's API exists.
      @load_hook = TracePoint.new(:end) { attach }
      @load_hook.enable
    end

    def self.attach
      return if @attached || !defined?(::RSpec::Core::Formatters) || !::RSpec.respond_to?(:configure)
      @attached = true
      @load_hook&.disable
      ::RSpec::Core::Formatters.register(Formatter, :example_passed, :example_failed, :example_pending, :close)
      ::RSpec.configure { |config| config.add_formatter(Formatter) }
      true
    end

    class Formatter
      def initialize(_output)
        @tests = {}
      end

      def example_passed(notification) = record(notification.example, "pass")
      def example_failed(notification) = record(notification.example, "fail")
      def example_pending(notification) = record(notification.example, "skip")

      def record(example, status)
        entry = { "result" => status }
        error = example.exception || example.execution_result.pending_exception
        if error
          # Keep the full message: RSpec expectation failures often begin
          # with a blank line. Mask addresses, not assertion differences.
          entry["failure"] = "#{error.class.name}: #{error.message}".gsub(/0x\h{4,16}/, "0x?")
        elsif status == "skip"
          entry["failure"] = example.execution_result.pending_message.to_s
        end
        @tests[example.id] = entry
      end

      def close(_notification)
        path = ENV.fetch("LOWRAIL_OUTCOMES")
        Lowrail.write_json("#{path}.#{Process.pid}", Lowrail::Minitest.file_data(@tests))
      rescue StandardError, ScriptError => e
        warn "[lowrail] could not write RSpec outcomes: #{e.class}: #{e.message}"
      end
    end
  end
end
