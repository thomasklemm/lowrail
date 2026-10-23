# frozen_string_literal: true

# Executable public fixtures, not production traffic. Only disposable local
# corpus databases; fixture insertion deliberately bypasses callbacks.
raise "disposable corpus DB required" unless %w[test production].include?(Rails.env) &&
  Rails.root.to_s.start_with?(File.expand_path("../../.corpus/", __dir__) + "/")
db = ActiveRecord::Base.connection_db_config
safe_db = if db.adapter == "sqlite3"
  File.expand_path(db.database, Rails.root).start_with?(Rails.root.to_s + "/")
else
  db.database.start_with?("lowrail_advise_") && [nil, "localhost", "127.0.0.1", "/var/run/postgresql"].include?(db.host)
end
raise "refusing fixture writes outside disposable local corpus DB" unless safe_db
require "active_record/fixtures"
require "rack/mock"

headers = { "HTTP_HOST" => "localhost", "HTTPS" => "on" }
case File.basename(Rails.root)
when /writebook/
  ActiveRecord::FixtureSet.create_fixtures(Rails.root.join("test/fixtures"),
    %w[accounts users books sections pages pictures leaves accesses action_text/markdowns active_storage/blobs active_storage/attachments])
  book = Book.find_by!(title: "Handbook")
  book.update_columns(published: true)
  route = "/#{book.id}/#{book.slug}"
  marker = "Welcome to The Handbook!"
  label = "GET book TOC (4 fixture leaves)"
when /campfire/
  directory = Rails.root.join("test/fixtures")
  fixtures = Dir.glob("**/*.yml", base: directory).map { _1.delete_suffix(".yml") }
  ActiveRecord::FixtureSet.create_fixtures(directory, fixtures)
  room = Room.find_by!(name: "All Talk")
  login = ActionDispatch::Integration::Session.new(Rails.application)
  login.host! "localhost"
  login.https!
  login.get "/session/new"
  token = Nokogiri::HTML(login.response.body).at_css('input[name="authenticity_token"]')&.[]("value")
  raise "missing production login CSRF token" if Rails.env.production? && !token
  login.post "/session", params: { email_address: "david@37signals.com", password: "secret123456", authenticity_token: token }
  raise "login failed" unless login.response.redirect? && login.cookies["session_token"]
  headers["HTTP_COOKIE"] = login.cookies.to_hash.map { |key, value| "#{key}=#{Rack::Utils.escape(value)}" }.join("; ")
  route = "/rooms/#{room.id}"
  marker = "Champagne"
  label = "GET Campfire room (public fixtures)"
when /fizzy/
  directory = Rails.root.join("test/fixtures")
  fixtures = Dir.glob("**/*.yml", base: directory).map { _1.delete_suffix(".yml") }
  ActiveRecord::FixtureSet.create_fixtures(directory, fixtures)
  require "action_dispatch/testing/test_request"
  # Keep authentication's SQL bind identical across fresh A/B/A processes.
  session = Session.find_by!(user: User.find_by!(email_address: "david@37signals.com"))
  request = ActionDispatch::TestRequest.create
  request.env.merge!(Rails.application.env_config)
  request.cookie_jar.signed[:session_token] = session.signed_id
  headers["HTTP_COOKIE"] = request.cookie_jar.to_header
  route = "/"
  marker = "Writebook"
  label = "GET Fizzy buckets (public fixtures)"
when /codetriage/
  directory = Rails.root.join("test/fixtures")
  fixtures = Dir.glob("**/*.yml", base: directory).map { _1.delete_suffix(".yml") }
  ActiveRecord::FixtureSet.create_fixtures(directory, fixtures)
  route = "/"
  marker = "CodeTriage"
  label = "GET CodeTriage home (public fixtures)"
when /casa/
  require "factory_bot_rails"
  FactoryBot.find_definitions if FactoryBot.factories.none?
  org = CasaOrg.find_by(name: "Lowrail advice corpus") || FactoryBot.create(:casa_org, name: "Lowrail advice corpus")
  admin = CasaAdmin.find_by(email: "advise@example.invalid") || FactoryBot.create(:casa_admin, casa_org: org, email: "advise@example.invalid")
  if org.casa_cases.none?
    25.times { FactoryBot.create(:casa_case, casa_org: org) }
  end
  # Match the app's own request-spec authentication fixture. Authorization,
  # organization scopes and the actual controller/render pipeline stay live.
  require "warden/test/helpers"
  extend Warden::Test::Helpers
  Warden.test_mode!
  login_as admin, scope: :user
  route = "/casa_cases"
  marker = "CINA-"
  label = "GET CASA cases (25 factory cases)"
else
  raise "unknown corpus workload"
end
client = Rack::MockRequest.new(Rails.application)
{ label => -> {
  login_as admin, scope: :user if File.basename(Rails.root).match?(/casa/)
  response = client.get(route, headers)
  raise "wrong response #{response.status}" unless response.status == 200 && response.body.include?(marker)
  response
} }
