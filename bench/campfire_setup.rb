# frozen_string_literal: true

# After loading Campfire's fixtures into its DISPOSABLE production database:
#   RAILS_ENV=production SECRET_KEY_BASE_DUMMY=1 bin/rails runner /abs/lowrail/bench/campfire_setup.rb
# Writes local benchmark inputs to tmp/m0; never use against a real deployment.
require "json"
require "rack/mock"

abort "only run inside Lowrail's .corpus directory" unless Rails.root.to_s.start_with?(File.expand_path("../.corpus/", __dir__) + "/")
abort "requires production corpus fixtures" unless Rails.env.production? && User.find_by(email_address: "david@37signals.com")
Rails.logger.level = :error
Room::MessagesCount.ensure!
Room::MessagesCount.backfill!
# Fixture insertion bypasses the model's search-index callbacks.
Message.connection.execute("DELETE FROM message_search_index")
Message.find_each { |message| message.send(:create_in_index) }

room = Room.find_by!(name: "All Talk")
bot = User.find_by!(name: "Bender Bot")
client = ActionDispatch::Integration::Session.new(Rails.application)
client.host! "localhost"
client.https!
client.post "/session", params: { email_address: "david@37signals.com", password: "secret123456" },
  headers: { "Sec-Fetch-Site" => "same-origin", "Origin" => "https://localhost" }
raise "login failed" unless client.response.redirect? && client.cookies["session_token"]
# Persist the room-selection cookie too, so timed requests don't change session state.
client.get "/rooms/#{room.id}"
raise "room failed" unless client.response.status == 200
cookie = client.cookies.to_hash.map { |key, value| "#{key}=#{Rack::Utils.escape(value)}" }.join("; ")
headers = { "HTTP_COOKIE" => cookie }
paths = {
  room: "/rooms/#{room.id}",
  messages: "/rooms/#{room.id}/messages",
  sidebar: "/users/me/sidebar",
  search: "/searches?q=pain",
  stream: "/rooms/#{room.id}/refresh.turbo_stream?since=0",
  json: "/rooms/#{room.id}/#{bot.bot_key}/messages"
}

# Check actual bodies, not merely successful login or redirect responses.
mock = Rack::MockRequest.new(Rails.application)
checks = paths.map do |name, path|
  response = mock.get(path, { "HTTP_HOST" => "localhost", "HTTPS" => "on" }.merge(name == :json ? {} : headers))
  raise "#{name}: #{response.status}" unless response.status == 200
  body = response.body
  valid = case name
  when :json then response.media_type == "application/json" && JSON.parse(body).length == room.messages.count
  when :stream then response.media_type == "text/vnd.turbo-stream.html" && body.include?('<turbo-stream action="append"') && body.include?("Champagne")
  when :room, :messages then response.media_type == "text/html" && body.include?("Champagne")
  when :sidebar then body.include?("All Talk") && body.include?("Designers")
  when :search then body.include?("Pain is easy to write")
  end
  raise "#{name}: wrong body" unless valid
  { route: name, status: response.status, type: response.media_type, bytes: body.bytesize }
end

dir = Rails.root.join("tmp/m0")
dir.mkpath
File.write(dir.join("headers.json"), JSON.generate(headers), perm: 0o600)
File.write(dir.join("paths.json"), JSON.pretty_generate(paths), perm: 0o600)
File.write(dir.join("checks.json"), JSON.pretty_generate(checks))
puts JSON.pretty_generate(checks)
