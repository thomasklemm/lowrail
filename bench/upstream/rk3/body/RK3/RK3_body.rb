require "rack/utils"

rng = Random.new(7)
# A synthetic encrypted Rails session cookie: random data, IV and auth tag, Base64-encoded and joined with "--" (284 bytes).
cookie = [180, 12, 16].map { |n| [rng.bytes(n)].pack("m0") }.join("--")
token = [rng.bytes(64)].pack("m0")
form = "_method=patch&authenticity_token=#{Rack::Utils.escape(token)}" \
  "&article%5Btitle%5D=Hello+world&article%5Bbody%5D=Rack+decodes+every+form+value.&commit=Update+Article"
header = "_blog_session=#{Rack::Utils.escape(cookie)}; theme=dark"

UpstreamBench.report("parse_nested_query (5 fields)") { Rack::Utils.parse_nested_query(form) }
UpstreamBench.report("parse_cookies_header (session cookie + 1)") { Rack::Utils.parse_cookies_header(header) }
UpstreamBench.report("set_cookie_header (session cookie)") do
  Rack::Utils.set_cookie_header("_blog_session", {value: cookie, path: "/", httponly: true, same_site: :lax})
end
