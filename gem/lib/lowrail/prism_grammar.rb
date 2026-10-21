# frozen_string_literal: true

require "prism"

module Lowrail
  # Build/discovery only: respect the app's loaded parser, never its default
  # latest/nearest grammar or a renamed development grammar from an older gem.
  module PrismGrammar
    class Unsupported < StandardError; end

    def self.version
      @version ||= begin
        Prism.parse("", version: RUBY_VERSION)
        RUBY_VERSION
      rescue ArgumentError => error
        Unsupported.new("unsupported_prism_grammar: loaded Prism #{Prism::VERSION} cannot parse running Ruby #{RUBY_VERSION}: #{error.message}")
      end
      raise @version if Unsupported === @version
      @version
    end
  end
end
