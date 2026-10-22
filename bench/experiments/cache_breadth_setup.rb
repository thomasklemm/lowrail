# frozen_string_literal: true

# Disposable production data for cache_breadth.rb, not a runtime installer.
# Run each app through its own frozen bundle, with CENSUS_APP and CENSUS_STATE.
require "fileutils"
require "securerandom"
require "cgi"

module CacheBreadthWorkload
  class << self
    attr_accessor :routes
  end
end

name = ENV.fetch("CENSUS_APP")
app = File.realpath(ENV.fetch("CENSUS_ROOT"))
state = File.expand_path(ENV.fetch("CENSUS_STATE"))
raise "disposable corpus required" unless app.include?("/.corpus/") && !state.start_with?(app + "/")
raise "new disposable state required" if File.exist?(state)
FileUtils.mkdir_p(state, mode: 0o700)
ENV.update("RAILS_ENV" => "production", "RACK_ENV" => "production", "SKIP_TELEMETRY" => "1",
  "SECRET_KEY_BASE" => SecureRandom.hex(64), "RAILS_LOG_LEVEL" => "fatal")

if name == "fizzy"
  require_relative "fizzy_link_fixture"
  # This preparer requires a nonexistent directory and sets all four external
  # SQLite URLs. It inserts only upstream SQL fixtures, not app code/config.
  Dir.rmdir(state)
  FizzyLinkFixture.prepare(app, state)
elsif name == "campfire-r81"
  require_relative "campfire_scenario"
  Dir.rmdir(state)
  CampfireScenario.prepare(app, state)
else
  if name == "casa"
    ENV.update("DATABASE_URL" => "postgresql:///lowrail_cache_breadth_casa?username=user",
      "APP_ENVIRONMENT" => "lowrail_corpus", "SCOUT_MONITOR" => "false",
      "STORAGE_ACCOUNT_NAME" => "lowrailcensusinvalid", "STORAGE_CONTAINER" => "disposable",
      "STORAGE_ACCESS_KEY" => [SecureRandom.random_bytes(64)].pack("m0"))
    require "active_support/encrypted_file"
    key = File.join(state, "master.key")
    File.write(key, ActiveSupport::EncryptedFile.generate_key, perm: 0o600)
    content = File.join(state, "production.yml.enc")
    ActiveSupport::EncryptedFile.new(content_path: Pathname.new(content), key_path: Pathname.new(key),
      env_key: "RAILS_MASTER_KEY", raise_if_missing_key: true).write("BASE_URL: https://casa.example.invalid\n")
  elsif name == "codetriage"
    ENV["DATABASE_URL"] = "postgresql:///lowrail_cache_breadth_codetriage"
  else
    ENV["DATABASE_URL"] = "sqlite3:#{state}/primary.sqlite3"
    %w[CACHE QUEUE CABLE].each { ENV["#{_1}_DATABASE_URL"] = "sqlite3:#{state}/#{_1.downcase}.sqlite3" }
  end
  require "active_record"
  ActiveRecord::Schema.verbose = false
  ActiveRecord::Base.establish_connection(ENV.fetch("DATABASE_URL"))
  raise "empty database required" unless ActiveRecord::Base.connection.tables.empty?
  load File.join(app, "db/schema.rb") unless name == "writebook"
  ActiveRecord::Base.connection_pool.disconnect!
  require File.join(app, "config/application")
  Rails.application.config.yjit = false
  if name == "casa"
    Rails.application.config.credentials.content_path = Pathname.new(content)
    Rails.application.config.credentials.key_path = Pathname.new(key)
  end
  require File.join(app, "config/environment")
  if name == "writebook"
    # Its stock inflection initializer defines leaf/leaves for schema FKs.
    load File.join(app, "db/schema.rb")
    require "active_record/fixtures"
    path = File.join(app, "test/fixtures")
    names = Dir[File.join(path, "**/*.yml")].sort.map { _1.delete_prefix(path + "/").delete_suffix(".yml") }
    ActiveRecord::FixtureSet.create_fixtures(path, names)
  elsif name == "real-blog-r4"
    require_relative "../../fixtures/corpus/blog_show_get_only"
    Article.insert_all!(BlogShowGetOnly.rows(BlogShowGetOnly::ARTICLES))
    Comment.insert_all!(BlogShowGetOnly.rows(BlogShowGetOnly::COMMENTS))
    %w[cache queue cable].each do |database|
      ActiveRecord::Base.establish_connection(database.to_sym)
      load File.join(app, "db/#{database}_schema.rb")
    end
    ActiveRecord::Base.establish_connection(:primary)
  elsif name == "codetriage"
    require "active_record/fixtures"
    path = File.join(app, "test/fixtures")
    ActiveRecord::FixtureSet.create_fixtures(path, Dir[File.join(path, "*.yml")].map { File.basename(_1, ".yml") })
  elsif name == "casa"
    require "factory_bot"
    FactoryBot.definition_file_paths = [File.join(app, "spec/factories")]
    FactoryBot.find_definitions unless FactoryBot.factories.registered?(:casa_org)
    org = FactoryBot.create(:casa_org)
    FactoryBot.create(:casa_admin, casa_org: org, email: "census@example.invalid", password: "12345678")
  else
    raise "unknown census app"
  end
end

require "rack/mock"
if name == "campfire-r81"
  driver = CampfireScenario::Driver.new(state, record: false)
  driver.login
  CacheBreadthWorkload.routes = %w[room pagination sidebar search refresh].to_h { |id| [id, -> { driver.run(id) }] }
else
  rack, cookies = Rack::MockRequest.new(Rails.application), {}
  request = ->(verb, path, params = nil) {
    headers = {"HTTP_HOST" => "localhost", "HTTPS" => "on", "HTTP_ORIGIN" => "https://localhost",
      "HTTP_SEC_FETCH_SITE" => "same-origin", "REMOTE_ADDR" => "127.0.0.1",
      "HTTP_USER_AGENT" => "Mozilla/5.0 Firefox/140.0", "HTTP_ACCEPT_ENCODING" => "identity",
      "HTTP_COOKIE" => cookies.map { |k, v| "#{k}=#{v}" }.join("; ")}
    headers[:params] = params if params
    response = rack.request(verb, path, headers)
    Array(response.headers["set-cookie"]).each do |cookie|
      k, v = cookie.split(";", 2).first.split("=", 2)
      cookies[k] = v
    end
    response
  }
  if %w[fizzy writebook casa].include?(name)
    path = name == "casa" ? "/users/sign_in" : "/session"
    page = request.call("GET", name == "casa" ? path : path + "/new")
    raise "login page HTTP #{page.status}" unless page.status == 200
    token = page.body[/name="csrf-token" content="([^"]+)"/, 1] || page.body[/name="authenticity_token" value="([^"]+)"/, 1]
    raise "natural CSRF required" unless token
    params = if name == "casa"
      {user: {email: "census@example.invalid", password: "12345678"}}
    else
      {email_address: "kevin@37signals.com", password: "secret123456"}
    end
    response = request.call("POST", path, params.merge(authenticity_token: CGI.unescapeHTML(token)))
    raise "login failed #{response.status}" unless response.status == 302 || response.status == 303
  end
  paths = case name
  when "fizzy" then JSON.parse(File.read(File.join(state, "vector.json")))
  when "writebook"
    book = Book.find_by!(slug: "handbook")
    leaf = book.leaves.find_by!(title: "Welcome to The Handbook!")
    ["/", "/#{book.id}/#{book.slug}", "/#{book.id}/#{book.slug}/#{leaf.id}/#{leaf.slug}"]
  when "casa" then ["/casa_cases", "/volunteers"]
  when "codetriage" then ["/", "/what", "/#{Repo.first!.full_name}"]
  when "real-blog-r4" then ["/articles", "/articles/1", "/articles/1/edit"]
  end
  CacheBreadthWorkload.routes = paths.to_h { |path| [path, -> { request.call("GET", path) }] }
end
