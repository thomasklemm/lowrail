require "uri"

KEY = "article%5Btitle%5D"
VALUE = "Hello+world+from+Rack"
COOKIE = "#{"A" * 200}--#{"b" * 40}%3D%3D"
USER = "user%40example.com"

UpstreamBench.report("hello") { URI.decode_www_form_component("hello") }
UpstreamBench.report("form key") { URI.decode_www_form_component(KEY) }
UpstreamBench.report("form value") { URI.decode_www_form_component(VALUE) }
UpstreamBench.report("cookie") { URI.decode_www_form_component(COOKIE) }
UpstreamBench.report("uri hello") { URI.decode_uri_component("hello") }
UpstreamBench.report("uri user") { URI.decode_uri_component(USER) }
