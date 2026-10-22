# frozen_string_literal: true

require_relative "lobsters_native_validation"

# Fixture-only setup. Same SQLite backup as ruby-bench's benchmark.rb and
# bet H; no application/configuration edits or specialization installer.
module Exploration
  def self.install(config:, state:, arm:)
    file = SQLite3::Database.new(File.join(state, "primary.sqlite3"))
    backup = SQLite3::Backup.new(ActiveRecord::Base.connection.raw_connection, "main", file, "main")
    backup.step(-1)
    backup.finish
    file.close
    LobstersNativeValidation.install(config.fetch("app"),
      policy: File.expand_path("../../fixtures/corpus/lobsters-rps-entropy.json", __dir__))
  end

  def self.validation_request(**arguments)
    LobstersNativeValidation.validation_request(**arguments)
  end
end
