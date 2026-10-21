# frozen_string_literal: true

# CENSUS_SETUP fixture, only for a disposable local Fizzy production database.
# Set SKIP_TELEMETRY=1 before boot. No login bypass is installed in the app:
# this creates a normal signed Session and supplies its signed cookie to Rack.
require "action_dispatch/testing/test_request"
account = Account.find_or_create_by!(name: "Epoch census")
user = account.users.find_or_create_by!(email_address: "epoch@example.invalid") do |record|
  record.name = "Epoch census"
  record.password_digest = BCrypt::Password.create(SecureRandom.hex(24))
end
account.buckets.find_or_create_by!(name: "Census bucket", creator: user, all_access: true)
session = user.sessions.create!
request = ActionDispatch::TestRequest.create
request.env.merge!(Rails.application.env_config)
request.cookie_jar.signed[:session_token] = session.signed_id
ENV["CENSUS_HEADERS"] = {"HTTP_COOKIE" => request.cookie_jar.to_header}.to_json
