---
id: RK3
repo: rack/rack
fork: thomasklemm/rack
kind: perf
area: Rack::Utils.escape/unescape, QueryParser#unescape
reviewer: jeremyevans
branch: thomasklemm/unescape-cgi
head: "a8a5d747d0956efe7af5a0b36520f1d0a9698b40"
base: main
built_on: "da90464e3fa93e3cb49dc2d4ede798e6c6b70b4f"
depends_on: []
stacked_on:
alternative_of:
impact: "Every query/form key and value and every cookie read or written is decoded or escaped in C: form posts and cookie-writing requests −1.0% to −5.1% instructions (interpreter, four requests, three apps) and −2.8% to −9.8% (YJIT, JIT-flat, three requests, two apps), 56–136 fewer objects per request; exact by a 300,000-case differential per method on Ruby 3.2–4.0"
rank: 1
risky: false
state: built
pr:
note: "Built 2026-11-18 on rack main da90464e3f (leads doc: docs/upstream/outside-rails-leads.md#rk3-built-2026-11-18). Two commits: d85c4b9a42 decode (RK3), a8a5d747d0 escape (RK4); may open as one PR or split at the commit. Suite green (1292 runs, 0 failures, 2 skips) on 4.0.9, 3.4.12, 3.3.10, 3.2.9; 2.7 and 3.0/3.1 not run (no precompiled Ruby here; hosted CI covers them). RuboCop: no new offenses in the touched files against main (main has 436 elsewhere; rack CI doesn't run it). Differentials bench/upstream/rk3/diff_*.rb: 0 differences on all four Rubies and on 3.4 with cgi's pure-Ruby fallback; known boundary: a singleton #b/#dup/#to_s on a String argument is no longer called. New tests fail when the guard, the force_encoding, the */~ mapping or the US-ASCII encoding is removed. No CHANGELOG entry (rack lists no perf entries; #2550 has none). Rack has approved perf PRs unmerged (ours #2550 since 11-14), so opening waits for a claude-code pass and room. No passes yet."
passes: []
---

# Decode and escape form components with cgi/escape

`Rack::Utils.unescape` and `Rack::QueryParser#unescape` decode every key and value of a query string or form body and every cookie value, and `Rack::Utils.escape` escapes every `Set-Cookie` value. They call `URI.decode_www_form_component` and `URI.encode_www_form_component`, which copy the string and run a `gsub` with a Hash lookup for each escape. `cgi/escape`, which Rack already loads for `escape_html` on Ruby before 3.2, does the same in C.

The first commit decodes with `CGI.unescape`. It keeps URI's check for an invalid %-encoding and its message, so `InvalidParameterError` is raised as before, and it forces the result to the requested encoding as URI does (`CGI.unescape` leaves it in the input's encoding when the bytes aren't valid in the requested one). The second commit escapes with `CGI.escape`, which escapes `*` and leaves `~` alone where URI does the opposite, so the two are mapped back; `%2A` in its output can only come from a `*`, since a `%` becomes `%25`. Anything that isn't a String, String subclasses included, still goes through URI.

```ruby
require "benchmark/ips"
require "rack/utils"
require "base64"

rng = Random.new(7)
cookie = [180, 12, 16].map { |n| Base64.strict_encode64(rng.bytes(n)) }.join("--") # an encrypted Rails session cookie, 284 bytes
token = Base64.strict_encode64(rng.bytes(64))
form = "_method=patch&authenticity_token=#{Rack::Utils.escape(token)}" \
  "&article%5Btitle%5D=Hello+world&article%5Bbody%5D=Rack+decodes+every+form+value.&commit=Update+Article"
header = "_blog_session=#{Rack::Utils.escape(cookie)}; theme=dark"

Benchmark.ips do |x|
  x.report("parse_nested_query") { Rack::Utils.parse_nested_query(form) }
  x.report("parse_cookies_header") { Rack::Utils.parse_cookies_header(header) }
  x.report("set_cookie_header") { Rack::Utils.set_cookie_header("_blog_session", {value: cookie, path: "/", httponly: true, same_site: :lax}) }
end
```

| Ruby 4.0.9, i/s | main | this branch | |
| --- | ---: | ---: | ---: |
| `parse_nested_query` (5 fields) | 40.4k | 73.3k | 1.81x |
| `parse_cookies_header` (session cookie + 1) | 107k | 226k | 2.12x |
| `set_cookie_header` (session cookie) | 88.6k | 296k | 3.35x |
| same three, YJIT | 49.6k / 121k / 98.1k | 98.7k / 258k / 336k | 1.99x / 2.13x / 3.42x |

Best of three alternating rounds on one pinned core; main varied by up to 23% between rounds. In Callgrind instructions, decoding the escaped session cookie goes from 51.1k to 16.4k and escaping it from 90.3k to 13.9k.

I compared both methods with URI on 300,000 random strings each (escapes, lone and broken `%`, `+`, multibyte and invalid bytes, UTF-8, binary, US-ASCII, ISO-8859-1 and UTF-16LE input, frozen strings, and UTF-8, binary, US-ASCII, Shift_JIS and ISO-8859-1 targets) plus `nil`, Symbols, Integers and String subclasses, on Ruby 3.2, 3.3, 3.4 and 4.0 and with `cgi/escape`'s pure-Ruby fallback: the class, encoding, bytes and frozenness of every result and every exception class and message are the same. The only difference is that URI's own calls on the argument (`#b`, `#dup`, `#to_s`) no longer happen for Strings. The new tests cover the cases that differ between the two libraries: the `*` and `~` mapping, the result encoding, String subclasses and the invalid %-encoding message.

In whole requests of three open-source Rails apps, with the Rails session cookie read and written as usual, this removes 1.0% to 5.1% of the instructions per request without YJIT (four requests in three apps) and 2.8% to 9.8% with it (three requests in two apps), and 56 to 136 objects per request; a JSON request with no query and no cookie written is unchanged.
