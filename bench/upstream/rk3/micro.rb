# Per-call setup for ir.sh and ips.rb: load rack from the -I path (rack main or the branch).
require "rack/utils"
require "base64"
rng = Random.new(7)
# A Rails encrypted session cookie: three strict-Base64 parts joined by "--" (data, IV, auth tag).
COOKIE = [180, 12, 16].map { |n| Base64.strict_encode64(rng.bytes(n)) }.join("--")
ESCAPED_COOKIE = URI.encode_www_form_component(COOKIE)
FORM = "_method=patch&authenticity_token=#{URI.encode_www_form_component(Base64.strict_encode64(rng.bytes(64)))}" \
  "&article%5Btitle%5D=Hello+world&article%5Bbody%5D=Lowrail+measures+Rails+requests.&commit=Update+Article"
COOKIE_HEADER = "_blog_session=#{ESCAPED_COOKIE}; theme=dark"
QP = Rack::Utils.default_query_parser
