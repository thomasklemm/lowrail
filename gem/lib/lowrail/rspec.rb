# frozen_string_literal: true

module Lowrail
  # Installed through RUBYOPT before Bundler, without activating RSpec (or
  # any default gem). RSpec owns configuration/formatter initialization.
  module RSpec
    def self.install(path)
      return if @path
      @path = path
      Object.singleton_class.prepend(ConstHook)
      watch
      rspec = Lowrail.loaded_constant("RSpec")
      rspec.configuration if rspec&.respond_to?(:configuration)
    end

    def self.watch
      rspec = Lowrail.loaded_constant("RSpec") or return
      # rspec/support defines RSpec before rspec/core defines configuration.
      # Do not make an unfinished framework appear ready to other gems.
      hook = rspec.respond_to?(:configuration) ? ConfigurationHook : DefinitionHook
      rspec.singleton_class.prepend(hook) unless rspec.singleton_class < hook
    end

    def self.attach(config)
      ::RSpec::Core::Formatters.register(Formatter, :example_started, :example_passed, :example_failed, :example_pending, :close)
      config.add_formatter(Formatter) unless config.formatters.any?(Formatter)
    end

    module ConstHook
      private

      def const_added(name)
        super
        Lowrail::RSpec.watch if equal?(Object) && name == :RSpec
      end
    end

    module DefinitionHook
      private

      def singleton_method_added(name)
        super
        Lowrail::RSpec.watch if name == :configuration
      end
    end

    module ConfigurationHook
      def configuration
        # super finishes constructing and storing the configuration first.
        # Use public formatter APIs, including after reset/clear_examples.
        # Never wrap require: Bootsnap aliases it during its own boot.
        super.tap { Lowrail::RSpec.attach(_1) }
      end
    end

    class Formatter
      def initialize(_output)
        @tests = {}
      end

      def example_started(notification) = SqlTrace.start(notification.example.id)
      def example_passed(notification) = record(notification.example, "pass")
      def example_failed(notification) = record(notification.example, "fail")
      def example_pending(notification) = record(notification.example, "skip")

      def record(example, status)
        SqlTrace.finish
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
