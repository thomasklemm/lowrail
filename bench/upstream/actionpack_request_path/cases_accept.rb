FF = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
CHR = "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7"
CASES["parse_ff"] = -> { Mime::Type.parse(FF) }
CASES["parse_chrome"] = -> { Mime::Type.parse(CHR) }
CASES["parse_json"] = -> { Mime::Type.parse("application/json") }
CASES["parse_turbo"] = -> { Mime::Type.parse("text/vnd.turbo-stream.html, text/html, application/xhtml+xml") }
CASES["noop"] = -> { nil }
p Mime::Type.parse(FF), Mime::Type.parse(CHR) if ENV["SHOW"]
