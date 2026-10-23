# frozen_string_literal: true

# Production discovery with external throwaway credentials, never CASA's own
# production secrets. Same prerequisite as casa_production_boot.rb; this driver
# additionally replays the public request fixture against an already prepared DB.
app = File.realpath(ARGV.fetch(0))
raise "dedicated corpus copy required" unless app.start_with?(File.expand_path("../../.corpus/", __dir__) + "/")
ENV.update("RAILS_ENV" => "production", "RACK_ENV" => "production", "APP_ENVIRONMENT" => "lowrail_corpus",
  "SCOUT_MONITOR" => "false", "SECRET_KEY_BASE_DUMMY" => "1", "SECRET_KEY_BASE" => nil, "RAILS_MASTER_KEY" => nil)
# Keep the tools visible before Bundler, but use CASA's locked JSON version.
version = File.read(File.join(app, "Gemfile.lock")).match(/^    json \(([^)]+)\)/).captures.first
gem "json", version
require_relative "../../bench/advise"
require "active_support"
require "active_support/encrypted_file"
require "tmpdir"
require "pathname"
require "base64"
require "securerandom"

ENV.update("STORAGE_ACCOUNT_NAME" => "lowrailcensusinvalid", "STORAGE_CONTAINER" => "disposable",
  "STORAGE_ACCESS_KEY" => Base64.strict_encode64(SecureRandom.random_bytes(64)))
Dir.mktmpdir("lowrail-advise-casa-credentials-") do |dir|
  raise "credentials must stay external" if File.realpath(dir).start_with?(app + "/")
  key = Pathname.new(File.join(dir, "master.key"))
  file = Pathname.new(File.join(dir, "production.yml.enc"))
  File.write(key, ActiveSupport::EncryptedFile.generate_key, perm: 0o600)
  ActiveSupport::EncryptedFile.new(content_path: file, key_path: key,
    env_key: "RAILS_MASTER_KEY", raise_if_missing_key: true).write("BASE_URL: https://casa.example.invalid\n")
  require File.join(app, "config/application")
  Rails.application.config.credentials.content_path = file
  Rails.application.config.credentials.key_path = key
  Advise.cli([app, *ARGV.drop(1)])
end
