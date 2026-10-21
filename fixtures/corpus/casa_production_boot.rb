# frozen_string_literal: true

# Boot fixture, NOT the app's credentials. Invoked only by script/corpus's
# explicit --casa-production-boot-fixture option; no requests, jobs or seeds.
require "uri"
require "tmpdir"
require "pathname"
require "base64"
require "securerandom"
require "json"

root = File.realpath(Dir.pwd)
corpus = File.realpath(File.expand_path("../../.corpus", __dir__))
abort "corpus_copy_required" unless root.start_with?(corpus + "/")
url = ENV.fetch("LOWRAIL_CORPUS_DATABASE_URL")
database = URI.parse(url)
abort "empty_local_disposable_database_required" unless
  %w[postgres postgresql].include?(database.scheme) && %w[localhost 127.0.0.1].include?(database.host) &&
    database.path.match?(%r{\A/lowrail_corpus_casa_[a-z0-9_]+\z}) && !database.query && !database.fragment

ENV.update("DATABASE_URL" => url, "APP_ENVIRONMENT" => "lowrail_corpus", "SCOUT_MONITOR" => "false",
  "STORAGE_ACCOUNT_NAME" => "lowrailcensusinvalid", "STORAGE_CONTAINER" => "disposable",
  "STORAGE_ACCESS_KEY" => Base64.strict_encode64(SecureRandom.random_bytes(64)))

# Loading the schema before the application avoids its production initializers
# and development seeds. Never replace tables in a previously used database.
require "active_record"
ActiveRecord::Base.establish_connection(url)
abort "disposable_database_not_empty" unless ActiveRecord::Base.connection.tables.empty?
ActiveRecord::Schema.verbose = false
load File.join(root, "db/schema.rb")
ActiveRecord::Base.connection_pool.disconnect!

require "active_support/encrypted_file"
Dir.mktmpdir("lowrail-casa-boot-fixture-") do |dir|
  abort "credentials_must_be_external" if File.realpath(dir).start_with?(root + "/")
  key_path = Pathname.new(File.join(dir, "master.key"))
  File.write(key_path, ActiveSupport::EncryptedFile.generate_key, perm: 0o600)
  content_path = Pathname.new(File.join(dir, "production.yml.enc"))
  ActiveSupport::EncryptedFile.new(content_path: content_path, key_path: key_path,
    env_key: "RAILS_MASTER_KEY", raise_if_missing_key: true).write("BASE_URL: https://casa.example.invalid\n")
  require File.join(root, "config/application")
  Rails.application.config.credentials.content_path = content_path
  Rails.application.config.credentials.key_path = key_path
  require File.join(root, "config/environment")
  puts JSON.generate(fixture: "boot fixture, not the app's credentials", boot: "ok",
    production: Rails.env.production?, eager_load: Rails.application.config.eager_load,
    require_master_key: Rails.application.config.require_master_key, rails: Rails.version,
    ruby: RUBY_VERSION, yjit: RubyVM::YJIT.enabled?, lowrail: ENV["LOWRAIL"], schema_only: true)
end
