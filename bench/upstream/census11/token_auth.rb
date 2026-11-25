# Token auth header matrix: token_and_options and authenticate, per Rails tree.
require "action_controller"
T = ActionController::HttpAuthentication::Token
req = ->(h) { ActionDispatch::Request.new(Rack::MockRequest.env_for("/", "HTTP_AUTHORIZATION" => h)) }
ctrl = Struct.new(:request)
headers = ['Token token="abc"', 'Token abc', 'token abc', 'Bearer abc', 'bearer abc', 'Bearer  abc', 'DPoP abc', 'Basic YWxhZGRpbjpvcGVu',
  'Digest username="x"', 'Custom abc', 'abc', 'Token token="abc", nonce="def"', 'Bearer abc.def-ghi_jkl=', 'Token', 'Bearer ',
  'Token token=abc', "Bearer\tabc", 'TOKEN abc', 'Bearer abc, other="x"', 'MAC id="x"']
puts "Rails #{ActionPack.version}"
headers.each do |h|
  tao = T.token_and_options(req.(h)) rescue "#{$!.class}"
  auth = T.authenticate(ctrl.new(req.(h))) { |t, o, *s| [t, o.to_h, *s] } rescue "#{$!.class}"
  auth_b = (T.authenticate(ctrl.new(req.(h)), scheme: "Bearer") { |t, o, *s| [t, o.to_h, *s] } rescue "#{$!.class}")
  puts "#{h.inspect}: tao=#{tao.inspect} auth=#{auth.inspect} auth(Bearer)=#{auth_b.inspect}"
end
