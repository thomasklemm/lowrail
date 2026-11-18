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
impact: "Held for compatibility fixes. Historical request receipts show −1.0% to −5.1% interpreter instructions and −2.8% to −9.8% YJIT instructions for Rack's query/form and cookie helpers; Thermos disproved blanket exactness at this head. See bench/upstream/rk3/review-thermos-sol/README.md."
rank: 1
risky: false
state: in-review
pr:
note: >-
  Thermos 2026-11-18: changes on 6f48723a86; the UTF-16 loader failure is fixed, but encoding-duck double/early coercion and BasicObject guards still regress accepted URI inputs. Do not open the unapproved draft body below yet. Full amended-head review, minimal fixes, claim audit and receipts: bench/upstream/rk3/review-thermos-sol/6f48723a86/README.md. One PR retaining both commits recommended after repair.
  Build record preserved: built on rack main da90464e3f, d85c4b9a42 decode and 6f48723a86 escape (amended from a8a5d747d0). Builder reports suite green on 4.0.9/3.4.12/3.3.10/3.2.9; no new RuboCop offenses against main (436 existing); original 300k differentials zero on those four Rubies and pure CGI; mutation tests catch removed guards, normalization and mappings. Singleton String b/dup/to_s dispatch is an acknowledged boundary, not the only one. A changelog entry remains required: the earlier claim that 2550 has none was wrong. Opening also waits for the separate claude-code pass and queue room.
  The previous escape head failed on 3.2–3.4 with ERB 6.0.7 because cgi/util had not initialized older MRI's CGI fallback. The restored ASCII-compatible guard sends UTF-16/32 to URI. Thermos independently reran the amended full suites and both 300k scripts on 3.4.12/4.0.9 with and without util; all ordinary cases pass. Its expanded matrices on 2.7.3/3.4.12/4.0.9 and pure 3.4/4.0 still expose the two coercion findings; diagnostic fixes yield zero differences. Old ERB loads util incidentally on 2.7.3, so that no-preload case is not a no-util case.
  The builder's new-head body-ips cohort is retained in data/rk3/body-ips (old cohort in body-ips-a8a5d747); arithmetic verified. Fresh interpreter cookie escape is 90,311/90,303 -> 14,369 Ir/op. Whole-request receipts predate the restored guard; the builder's roughly 430 extra instructions per escape, 900/request and under 0.02% are estimates, not exact-head request measurements. JSON YJIT is +0.203% against 0.170% A/A, not simply unchanged. Refresh/qualify claims and use the body-number protocol before submission.
  Builder reports all other fork matrix jobs green, including JRuby/TruffleRuby heads and macOS; those engines were not executed locally. The 2.7.3 failure is confirmed provisioning, not a test failure: public annotations say unavailable on ubuntu-26.04, setup-ruby fails and rake is skipped. Full log download was forbidden; job metadata and annotations are retained. The actual pinned Rack minimum is 2.7.3, not 2.4.
  Concurrent builder log investigation retained from Lowrail 34d04379: ubuntu-latest image ubuntu-26.04 (20261111.196.1) returns HTTP 404 for ruby-2.7.3-ubuntu-26.04-x64.tar.gz before bundle install. Rack main's 2026-10-31 run 41243597466/job 124662353148 used ubuntu-24.04 and passed 1,284 tests; the 2026-11-18 rerun job 134494001814 fails on ubuntu-26.04. This workflow/provisioning issue is outside this Rack optimization's diff and is not repaired here. Thermos's own evidence is the public annotations, not those full logs.
passes:
  - {reviewer: thermos-sol, orb: "T-01a1ec13-3575-7694-b1c3-e0edd9abc152", head: "a8a5d747d0956efe7af5a0b36520f1d0a9698b40", date: 2026-11-18, verdict: changes, open: "Three introduced compatibility defects: (P2) non-ASCII-compatible escape raises on clean Ruby 3.4.12 + ERB 6.0.7, smallest fix URI fallback for such input; (P3) decoder coerces encoding twice and before decoding, smallest fix CGI.unescape(s, Encoding::BINARY).force_encoding(encoding); (P3) calling instance_of? rejects valid BasicObject coercions, smallest fix String === s before the exact-class predicate in all three guards. Diagnostic repairs pass 17,897 comparisons per configuration on MRI 2.7.3, 2.7.8, 3.4.12, 4.0.9 and pure CGI on 3.4/4.0. No Rack edits or push. Must also replace unsupported exactness/only-boundary and JSON-control prose, scope native/C and Rails caller claims, add the requested changelog, refresh clean-process and performance evidence on the repaired head. Historical request arithmetic and accepted YJIT 0/0 counters verified, not a three-app rebenchmark; body benchmark rerun inconclusive (56–210% main spread). JRuby uses a Java loader, TruffleRuby a Ruby shim; neither engine executed. One PR with two commits. Full synthesis, sentence-by-sentence claim audit, commands and receipts: bench/upstream/rk3/review-thermos-sol/README.md."}
  - {reviewer: thermos-sol, orb: "T-01a1ec13-3575-7694-b1c3-e0edd9abc152", head: "6f48723a862129d42e901d2baae16b1b826404bc", date: 2026-11-18, verdict: changes, open: "Prior P2 fixed by restored ASCII-compatible escape guard. Two P3 exactness must-fixes remain: CGI.unescape(s, Encoding::BINARY).force_encoding(encoding) in both decoders preserves once-only late encoding coercion; String === s before instance_of? in all three guards preserves BasicObject URI coercions. Full suites on 3.4.12/4.0.9 with and without cgi/util: 1292 runs, 6270 assertions, zero failures/errors, two skips, separate files pass. Original 300k scripts zero ordinary differences in all four configurations. Expanded 17,897-comparison matrices on 2.7.3/3.4.12/4.0.9 plus pure 3.4/4.0 find only those two families; diagnostic fixes pass all eight configurations. Both parallel reviewers returned approve-with-nits after the P2 fix; unified changes reflects the requested exactness contract and false only-boundary claim, not a security blocker. Amend message/body qualifications, add changelog, refresh exact-head body-number evidence; historical request arithmetic verified, not rerun. Confirmed 2.7.3 hosted setup failure: unavailable on ubuntu-26.04; rake skipped. One PR, two commits. Full evidence: bench/upstream/rk3/review-thermos-sol/6f48723a86/README.md. No Rack changes or publishing."}
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
