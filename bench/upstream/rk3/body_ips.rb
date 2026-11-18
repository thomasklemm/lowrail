# The benchmark in the RK3 body, verbatim except quiet output, fixed times and JSON output.
require "benchmark/ips"
require "rack/utils"
require "base64"

rng = Random.new(7)
cookie = [180, 12, 16].map { |n| Base64.strict_encode64(rng.bytes(n)) }.join("--") # an encrypted Rails session cookie, 284 bytes
token = Base64.strict_encode64(rng.bytes(64))
form = "_method=patch&authenticity_token=#{Rack::Utils.escape(token)}" \
  "&article%5Btitle%5D=Hello+world&article%5Bbody%5D=Rack+decodes+every+form+value.&commit=Update+Article"
header = "_blog_session=#{Rack::Utils.escape(cookie)}; theme=dark"

Benchmark.ips(quiet: true) do |x|
  x.config(warmup: 2, time: 5)
  x.report("parse_nested_query") { Rack::Utils.parse_nested_query(form) }
  x.report("parse_cookies_header") { Rack::Utils.parse_cookies_header(header) }
  x.report("set_cookie_header") { Rack::Utils.set_cookie_header("_blog_session", {value: cookie, path: "/", httponly: true, same_site: :lax}) }
  x.json! ENV.fetch("OUT")
end
