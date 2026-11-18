---
id: RK3
repo: rack/rack
fork: thomasklemm/rack
kind: perf
area: Rack::Utils.escape/unescape, QueryParser#unescape
reviewer: jeremyevans
branch: thomasklemm/unescape-cgi
head: "6f48723a862129d42e901d2baae16b1b826404bc"
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
note: "Built 2026-11-18 on rack main da90464e3f (leads doc: docs/upstream/outside-rails-leads.md#rk3-built-2026-11-18). Two commits: d85c4b9a42 decode (RK3), 6f48723a86 escape (RK4; amended from a8a5d747d0, see below); may open as one PR or split at the commit. Suite green (1292 runs, 0 failures, 2 skips) on 4.0.9, 3.4.12, 3.3.10, 3.2.9; 2.7 and 3.0/3.1 not run (no precompiled Ruby here; hosted CI covers them). RuboCop: no new offenses in the touched files against main (main has 436 elsewhere; rack CI doesn't run it). Differentials bench/upstream/rk3/diff_*.rb: 0 differences on all four Rubies and on 3.4 with cgi's pure-Ruby fallback; known boundary: a singleton #b/#dup/#to_s on a String argument is no longer called. New tests fail when the guard, the force_encoding, the */~ mapping or the US-ASCII encoding is removed. No CHANGELOG entry (rack lists no perf entries; #2550 has none). Rack has approved perf PRs unmerged (ours #2550 since 11-14), so opening waits for a claude-code pass and room. 2026-11-18: fork CI on a8a5d747d0 failed on 3.2, 3.3 and 3.4: with the doc group installed (erb 6.0.7) nothing loads cgi/util, and the C CGI.escape calls super into that missing Ruby fallback for a UTF-16 string (NoMethodError in the new UTF-16LE test). Reproduced locally; the escape guard is back to `instance_of?(String) && s.encoding.ascii_compatible?` and the commit amended and force-pushed with a lease (no PR). Suite green again on all four Rubies with the CI bundle; differentials rerun under it (erb 6.0.7, cgi/util not loaded), 0 differences. Per-request numbers were measured without that guard; it costs about 430 instructions per escape call (escape(cookie) 13,930 -> 14,360), at most about 900 per request, under 0.02%. Body benchmark rerun on 6f48723a86 (receipts data/rk3/body-ips; the a8a5d747d0 run kept as body-ips-a8a5d747). Fork CI on 6f48723a86: Test and Test External green on 2.7, 3.0–3.4, 4.0, ruby-head, jruby-head, truffleruby-head and macOS 4.0; 2.7.3 fails in 5 s on both heads: runner setup, not ours. Its log: ubuntu-latest is now Image ubuntu-26.04 (20261111.196.1) and ruby/setup-ruby stops with \"Unavailable version 2.7.3 for ruby on ubuntu-26.04\" (HTTP 404 for ruby-2.7.3-ubuntu-26.04-x64.tar.gz) before bundle install. Rack main's 2.7.3 job of 2026-10-31 (run 41243597466, job 124662353148) ran on ubuntu-24.04, downloaded ruby-2.7.3-ubuntu-24.04, 1284 runs, 0 failures. Rerun of the job on 2026-11-18 (134494001814) failed the same way on ubuntu-26.04. A rack PR will hit the same until rack's matrix moves off 2.7.3 on ubuntu-latest; not ours to fix in this PR. No passes yet."
passes: []
---

# Decode and escape form components with cgi/escape

`Rack::Utils.unescape` and `Rack::QueryParser#unescape` decode every key and value of a query string or form body and every cookie value, and `Rack::Utils.escape` escapes every `Set-Cookie` value. They call `URI.decode_www_form_component` and `URI.encode_www_form_component`, which copy the string and run a `gsub` with a Hash lookup for each escape. `cgi/escape`, which Rack already loads for `escape_html` on Ruby before 3.2, does the same in C.

The first commit decodes with `CGI.unescape`. It keeps URI's check for an invalid %-encoding and its message, so `InvalidParameterError` is raised as before, and it forces the result to the requested encoding as URI does (`CGI.unescape` leaves it in the input's encoding when the bytes aren't valid in the requested one). The second commit escapes with `CGI.escape`, which escapes `*` and leaves `~` alone where URI does the opposite, so the two are mapped back; `%2A` in its output can only come from a `*`, since a `%` becomes `%25`. Anything that isn't a String, String subclasses included, still goes through URI, and so does a string to escape in an encoding that isn't ASCII-compatible such as UTF-16 (the C `CGI.escape` hands those to a Ruby fallback that only `cgi/util` defines).

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
| `parse_nested_query` (5 fields) | 41.1k | 72.6k | 1.77x |
| `parse_cookies_header` (session cookie + 1) | 113k | 238k | 2.11x |
| `set_cookie_header` (session cookie) | 92.8k | 288k | 3.11x |
| same three, YJIT | 49.6k / 120k / 95.7k | 99.0k / 262k / 337k | 2.00x / 2.19x / 3.53x |

Best of three alternating rounds on one pinned core; main varied by up to 9% between rounds. In Callgrind instructions, decoding the escaped session cookie goes from 51.1k to 16.4k and escaping it from 90.3k to 14.4k.

I compared both methods with URI on 300,000 random strings each (escapes, lone and broken `%`, `+`, multibyte and invalid bytes, UTF-8, binary, US-ASCII, ISO-8859-1 and UTF-16LE input, frozen strings, and UTF-8, binary, US-ASCII, Shift_JIS and ISO-8859-1 targets) plus `nil`, Symbols, Integers and String subclasses, on Ruby 3.2, 3.3, 3.4 and 4.0 and with `cgi/escape`'s pure-Ruby fallback: the class, encoding, bytes and frozenness of every result and every exception class and message are the same. The only difference is that URI's own calls on the argument (`#b`, `#dup`, `#to_s`) no longer happen for Strings. The new tests cover the cases that differ between the two libraries: the `*` and `~` mapping, the result encoding, String subclasses and the invalid %-encoding message.

In whole requests of three open-source Rails apps, with the Rails session cookie read and written as usual, this removes 1.0% to 5.1% of the instructions per request without YJIT (four requests in three apps) and 2.8% to 9.8% with it (three requests in two apps), and 56 to 136 objects per request; a JSON request with no query and no cookie written is unchanged.
