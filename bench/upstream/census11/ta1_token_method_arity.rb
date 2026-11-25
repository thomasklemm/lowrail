# TA1: authenticate_with_http_token(&method(:authenticator)) with a two-parameter method, as keygen-api and quepid do.
require "action_controller"
class ApiController < ActionController::Base
  def show
    user = authenticate_with_http_token(&method(:authenticator))
    render plain: user.inspect
  end

  def show_defaults
    render plain: authenticate_with_http_token(&method(:authenticator_with_defaults)).inspect
  end

  private
    def authenticator(token, _options) = "user for #{token}"
    def authenticator_with_defaults(token = nil, options = nil) = "user for #{token}"
end
%w[show show_defaults].each do |action|
  env = Rack::MockRequest.env_for("/", "HTTP_AUTHORIZATION" => "Bearer abc")
  status, _, body = ApiController.action(action).call(env)
  puts "Rails #{ActionPack.version} #{action}: #{status} #{body.each.to_a.join}"
rescue => e
  puts "Rails #{ActionPack.version} #{action}: #{e.class}: #{e.message}"
end
