require "uri"

KEY = "article%5Btitle%5D"
VALUE = "Hello+world+from+Rack"
COOKIE = "#{"A" * 200}--#{"b" * 40}%3D%3D"

UpstreamBench.report("hello") { URI.decode_www_form_component("hello") }
UpstreamBench.report("form key") { URI.decode_www_form_component(KEY) }
UpstreamBench.report("form value") { URI.decode_www_form_component(VALUE) }
UpstreamBench.report("cookie") { URI.decode_www_form_component(COOKIE) }
