# frozen_string_literal: true

# External, disposable data only. No app patches, test runtime in HTTP workers,
# fake Current/session injection, seeds, jobs or telemetry services.
require "fileutils"
require "json"
require "securerandom"

module FizzyLinkFixture
  module_function

  def environment(app, state)
    raise "isolated corpus copy required" unless File.realpath(app).include?("/.corpus/")
    {"RAILS_ENV" => "production", "RACK_ENV" => "production", "LOWRAIL" => "0",
      "SKIP_TELEMETRY" => "1", "SOLID_QUEUE_IN_PUMA" => nil, "RUBYOPT" => nil,
      "SECRET_KEY_BASE" => File.read(File.join(state, "secret_key_base")),
      "RAILS_LOG_LEVEL" => "error", "RUBY_YJIT_ENABLE" => "0", "RUBY_ZJIT_ENABLE" => "0",
      "DATABASE_URL" => "sqlite3:#{state}/primary.sqlite3",
      "CACHE_DATABASE_URL" => "sqlite3:#{state}/cache.sqlite3",
      "QUEUE_DATABASE_URL" => "sqlite3:#{state}/queue.sqlite3",
      "CABLE_DATABASE_URL" => "sqlite3:#{state}/cable.sqlite3"}
  end

  def boot(app)
    require File.join(app, "config/application")
    Rails.application.config.yjit = false
    require File.join(app, "config/environment")
    raise "production interpreter required" unless Rails.env.production? &&
      !RubyVM::YJIT.enabled? && !(defined?(RubyVM::ZJIT) && RubyVM::ZJIT.enabled?)
  end

  def prepare(app, state)
    raise "fixture output must be new" if File.exist?(state)
    FileUtils.mkdir_p(state, mode: 0o700)
    File.write(File.join(state, "secret_key_base"), SecureRandom.hex(64), perm: 0o600)
    environment(app, state).each { |key, value| value ? ENV[key] = value : ENV.delete(key) }
    require "active_record"
    ActiveRecord::Schema.verbose = false
    {"primary" => "schema", "cache" => "cache_schema", "queue" => "queue_schema", "cable" => "cable_schema"}.each do |database, schema|
      ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: File.join(state, "#{database}.sqlite3"))
      load File.join(app, "db/#{schema}.rb")
      ActiveRecord::Base.connection_pool.disconnect!
    end
    boot(app)
    # Fixtures are evaluated only in this data-preparation process, never in
    # the production HTTP/counted workers. SQL fixture insertion skips callbacks.
    require "active_record/fixtures"
    path = File.join(app, "test/fixtures")
    names = Dir[File.join(path, "**/*.yml")].sort.map { _1.delete_prefix(path + "/").delete_suffix(".yml") }
    ActiveRecord::FixtureSet.create_fixtures(path, names)
    id = ->(label) { ActiveRecord::FixtureSet.identify(label) }
    account, user, bucket, bubble, stage = %w[37s kevin writebook logo qa_triage].map { id.call(_1) }
    second = Bucket.find(bucket).attributes.except("id").merge("id" => id.call("link_second_bucket"), "name" => "Link second bucket")
    Bucket.insert_all!([second])
    Access.insert_all!([{bucket_id: second.fetch("id"), user_id: user, created_at: Time.current, updated_at: Time.current}])
    Bubble.where(id: bubble).update_all(stage_id: stage)
    # Reuse a genuine saved filter, associated with the authenticated user.
    Filter.where(id: id.call("jz_assignments")).update_all(creator_id: user)
    query = Rack::Utils.build_nested_query(bucket_ids: [bucket, second.fetch("id")], creator_ids: [id.call("david")], stage_ids: [stage])
    vector = ["/buckets", "/bubbles?#{query}", "/account/users", "/workflows", "/notifications", "/buckets/#{bucket}/bubbles/#{bubble}"]
    File.write(File.join(state, "vector.json"), JSON.pretty_generate(vector), perm: 0o600)
    # Password is an upstream public test-fixture value, not a user's secret.
    File.write(File.join(state, "login.json"), JSON.generate(email_address: "kevin@37signals.com", password: "secret123456"), perm: 0o600)
    puts JSON.generate(prepared: true, source: app, vector: vector, fixture: "isolated upstream SQL fixtures, not production data")
  end
end

if $PROGRAM_NAME == __FILE__
  app, state = ARGV.map { File.expand_path(_1) }
  abort "usage: fizzy_link_fixture.rb APP NEW_STATE" unless app && state
  FizzyLinkFixture.prepare(app, state)
end
