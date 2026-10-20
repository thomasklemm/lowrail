# frozen_string_literal: true

# Run with `RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails runner
# /abs/lowrail/bench/inertia_setup.rb` in one of the public corpus apps.
# Creates deterministic disposable data and private benchmark headers. This
# is not a production deployment setup and must never target real data.
require "json"
require "rack/mock"

corpus = File.expand_path("../.corpus", __dir__)
abort "only run inside Lowrail's production corpus" unless Rails.env.production? && Rails.root.to_s.start_with?(corpus + "/")
Rails.logger.level = :error
ActiveRecord::Base.logger = nil
client = ActionDispatch::Integration::Session.new(Rails.application)
client.host! "localhost"
client.https!
origin = { "Sec-Fetch-Site" => "same-origin", "Origin" => "https://localhost" }
email = "m0-inertia@example.test"
password = "m0-disposable-password"

case Rails.application.class.module_parent_name
when "Pingcrm"
  account = Account.find_or_create_by!(name: "M0 Inertia")
  user = account.users.find_or_initialize_by(email: email)
  user.update!(first_name: "M0", last_name: "Inertia", password: password, owner: true)
  30.times do |i|
    org = account.organizations.find_or_create_by!(name: format("M0 Organization %02d", i)) do |o|
      o.email = "org#{i}@example.test"
      o.city = "Tallinn"
      o.country = "EE"
    end
    account.contacts.find_or_create_by!(email: "contact#{i}@example.test") do |c|
      c.first_name = "Contact"
      c.last_name = format("%02d", i)
      c.organization = org
      c.city = "Tallinn"
    end
  end
  client.get "/login"
  token = Nokogiri::HTML(client.response.body).at_css('meta[name="csrf-token"]')&.[]("content")
  client.post "/login", params: { user: { email: email, password: password }, authenticity_token: token }, headers: origin
  raise "login failed" unless client.response.redirect?
  paths = { organizations: "/organizations", contacts: "/contacts" }
  identity = ->(page) { page.dig("props", "auth", "user", "id") == user.id }
  content = ->(page) { page.fetch("props").fetch(page["component"].split("/").first.downcase).fetch("data").size == 10 }
when "RedprintsCFP"
  user = User.find_or_create_by!(email: email) { |u| u.name = "M0 Inertia" }
  user.create_speaker_profile!(name: user.name, email: email, bio: "M0 speaker", company: "M0", role: "Engineer", socials: "M0") unless user.speaker_profile
  20.times do |i|
    user.proposals.find_or_create_by!(title: format("M0 Proposal %02d", i)) do |p|
      p.cfp_id = CFP.primary.id
      p.abstract = "M0 abstract"
      p.details = "M0 details"
      p.pitch = "M0 pitch"
      p.track = "general"
      p.status = "submitted"
      p.submitted_at = Time.utc(2026, 10, 20)
    end
  end
  # Same signed-cookie construction as spec/support/auth_helpers.rb. OAuth
  # requires external provider credentials; authentication itself stays real.
  jar = ActionDispatch::Request.new(Rails.application.env_config.deep_dup).cookie_jar
  jar.signed[:session_token] = user.auth_token
  client.cookies[:session_token] = jar[:session_token]
  paths = { proposals: "/proposals", proposal: "/proposals/#{user.proposals.order(:id).first.to_param}" }
  identity = ->(page) { page.dig("props", "user", "id") == user.id }
  content = ->(page) { page.dig("props", "proposals")&.size == 20 || page.dig("props", "proposal", "title") == "M0 Proposal 00" }
when "ReactStarterKit"
  user = User.find_or_initialize_by(email: email)
  user.update!(name: "M0 Inertia", password: password, verified: true)
  client.get "/sign_in"
  token = Nokogiri::HTML(client.response.body).at_css('meta[name="csrf-token"]')&.[]("content")
  client.post "/sign_in", params: { email: email, password: password, authenticity_token: token }, headers: origin
  raise "login failed" unless client.response.redirect? && client.cookies[:session_token]
  paths = { dashboard: "/dashboard", profile: "/settings/profile" }
  identity = ->(page) { page.dig("props", "auth", "user", "id") == user.id }
  content = ->(page) { page.dig("props", "auth", "user", "name") == "M0 Inertia" }
else
  abort "unknown corpus app: #{Rails.application.class.module_parent_name}"
end

version = InertiaRails.configuration.version
raise "expected a boot-fixed version string" unless version.is_a?(String)
client.get paths.values.first
raise "authenticated HTML failed: #{client.response.status}" unless client.response.status == 200
cookie = client.cookies.to_hash.map { |key, value| "#{key}=#{Rack::Utils.escape(value)}" }.join("; ")
html = { "HTTP_COOKIE" => cookie, "HTTP_ACCEPT" => "text/html" }
json = html.merge("HTTP_X_INERTIA" => "true", "HTTP_X_INERTIA_VERSION" => version,
                  "HTTP_X_REQUESTED_WITH" => "XMLHttpRequest")
mock = Rack::MockRequest.new(Rails.application)
base = { "HTTP_HOST" => "localhost", "HTTPS" => "on" }
checks = paths.flat_map do |name, path|
  [html, json].map do |headers|
    response = mock.get(path, base.merge(headers))
    raise "#{name}: #{response.status}" unless response.status == 200
    if headers == json
      page = JSON.parse(response.body)
      raise "#{name}: wrong identity/content/version" unless identity.call(page) && content.call(page) && page["version"] == version
      raise "not an Inertia JSON response" unless response.media_type == "application/json" && response["x-inertia"] == "true"
    else
      raise "not initial HTML" unless response.media_type == "text/html" && response.body.include?("data-page")
      if Rails.application.class.module_parent_name == "ReactStarterKit"
        root = Nokogiri::HTML(response.body).at_css("#app")
        raise "SSR renderer is unavailable; start the corpus SSR service" unless root && root.element_children.any?
      end
    end
    { route: name, format: headers == json ? "json" : "html", status: response.status, bytes: response.body.bytesize }
  end
end
# Negative control: the version header must matter, not silently time a 409.
stale = mock.get(paths.values.first, base.merge(json).merge("HTTP_X_INERTIA_VERSION" => "m0-stale"))
raise "expected version mismatch 409" unless stale.status == 409
unsigned = mock.get(paths.values.first, base.merge(json).except("HTTP_COOKIE"))
raise "expected authentication redirect" unless unsigned.status == 302

# Trace actual requests, outside benchmark windows. Count only asset-version
# entrypoints, not unrelated security hashes. Caching at boot means zero.
calls = Hash.new(0)
trace = TracePoint.new(:call) do |event|
  if [:digest, :watched_files_digest].include?(event.method_id) && event.defined_class.to_s.match?(/ViteRuby|RailsVite/)
    calls["#{event.defined_class}##{event.method_id}"] += 1
  end
end
trace.enable { defined?(ViteRuby) ? ViteRuby.digest : RailsVite.digest }
raise "digest trace positive control failed" if calls.empty?
control = calls.dup
calls.clear
trace.enable do
  paths.each_value do |path|
    [html, json].each do |headers|
      100.times do
        response = mock.get(path, base.merge(headers))
        raise "trace request failed" unless response.status == 200
      end
    end
  end
end
dir = Rails.root.join("tmp/m0")
dir.mkpath
{ "headers-html.json" => html, "headers-json.json" => json, "paths.json" => paths,
  "checks.json" => checks, "version-trace.json" => { requests: paths.size * 200, version_class: version.class.name, control: control, calls: calls } }.each do |file, data|
  File.write(dir.join(file), JSON.pretty_generate(data), perm: 0o600)
end
puts JSON.pretty_generate(checks: checks, version_requests: paths.size * 200, version_calls: calls)
