---
id: RK3
repo: rack/rack
fork: thomasklemm/rack
kind: perf
area: Rack::Utils.escape/unescape, QueryParser#unescape
reviewer: jeremyevans
branch: thomasklemm/unescape-cgi
head: "02087583dc3685b9f805e3dd975aeb89d1444824"
base: main
built_on: "da90464e3fa93e3cb49dc2d4ede798e6c6b70b4f"
depends_on: []
stacked_on:
alternative_of:
impact: "Query/form keys and values and cookies read or written are decoded and escaped by cgi/escape: on head 02087583dc, −0.9% to −5.4% instructions per request in the interpreter (four requests, three apps) and −2.9% to −10.1% under YJIT (three requests, two apps, every window JIT-flat), 60–130 fewer objects; zero differences against URI in 300k-case differentials plus coercion/BasicObject cases on Ruby 3.2–4.0 with and without cgi/util and with the Ruby CGI implementation"
rank: 1
risky: false
state: built
pr:
note: >-
  Thermos 2026-11-18: changes on 6f48723a86; the UTF-16 loader failure is fixed, but encoding-duck double/early coercion and BasicObject guards still regress accepted URI inputs. Do not open the unapproved draft body below yet. Full amended-head review, minimal fixes, claim audit and receipts: bench/upstream/rk3/review-thermos-sol/6f48723a86/README.md. One PR retaining both commits recommended after repair.
  Build record preserved: built on rack main da90464e3f, d85c4b9a42 decode and 6f48723a86 escape (amended from a8a5d747d0). Builder reports suite green on 4.0.9/3.4.12/3.3.10/3.2.9; no new RuboCop offenses against main (436 existing); original 300k differentials zero on those four Rubies and pure CGI; mutation tests catch removed guards, normalization and mappings. Singleton String b/dup/to_s dispatch is an acknowledged boundary, not the only one. A changelog entry remains required: the earlier claim that 2550 has none was wrong. Opening also waits for the separate claude-code pass and queue room.
  The previous escape head failed on 3.2–3.4 with ERB 6.0.7 because cgi/util had not initialized older MRI's CGI fallback. The restored ASCII-compatible guard sends UTF-16/32 to URI. Thermos independently reran the amended full suites and both 300k scripts on 3.4.12/4.0.9 with and without util; all ordinary cases pass. Its expanded matrices on 2.7.3/3.4.12/4.0.9 and pure 3.4/4.0 still expose the two coercion findings; diagnostic fixes yield zero differences. Old ERB loads util incidentally on 2.7.3, so that no-preload case is not a no-util case.
  The builder's new-head body-ips cohort is retained in data/rk3/body-ips (old cohort in body-ips-a8a5d747); arithmetic verified. Fresh interpreter cookie escape is 90,311/90,303 -> 14,369 Ir/op. Whole-request receipts predate the restored guard; the builder's roughly 430 extra instructions per escape, 900/request and under 0.02% are estimates, not exact-head request measurements. JSON YJIT is +0.203% against 0.170% A/A, not simply unchanged. Refresh/qualify claims and use the body-number protocol before submission.
  Builder reports all other fork matrix jobs green, including JRuby/TruffleRuby heads and macOS; those engines were not executed locally. The 2.7.3 failure is confirmed provisioning, not a test failure: public annotations say unavailable on ubuntu-26.04, setup-ruby fails and rake is skipped. Full log download was forbidden; job metadata and annotations are retained. The actual pinned Rack minimum is 2.7.3, not 2.4.
  Concurrent builder log investigation retained from Lowrail 34d04379: ubuntu-latest image ubuntu-26.04 (20261111.196.1) returns HTTP 404 for ruby-2.7.3-ubuntu-26.04-x64.tar.gz before bundle install. Rack main's 2026-10-31 run 41243597466/job 124662353148 used ubuntu-24.04 and passed 1,284 tests; the 2026-11-18 rerun job 134494001814 fails on ubuntu-26.04. This workflow/provisioning issue is outside this Rack optimization's diff and is not repaired here. Thermos's own evidence is the public annotations, not those full logs.
  2026-11-18 (after thermos-sol changes on 6f48723a86): rebuilt as e3470303 (decode) + 02087583dc (escape) on rack main da90464e3f, force-pushed with a lease (no PR). Must-fix 1: decoders call CGI.unescape(s, Encoding::BINARY).force_encoding(encoding), so the encoding argument is converted once, after decoding. Must-fix 2: all three guards are `String === s && s.instance_of?(String)` (escape keeps ascii_compatible?). Tests added for both (each fails on its mutant), BasicObject escape via build_nested_query included. CHANGELOG: two Unreleased/Changed lines as #2550 did (my earlier note that #2550 had none was wrong); redundant inner require of cgi/escape removed; escape has one why-comment for the older-MRI fallback. Suite CI=spec bundle exec rake: 1295 runs, 0 failures, 2 skips on 4.0.9/3.4.12/3.3.10/3.2.9, each clean and with RUBYOPT=-rcgi/util. Differentials extended (stateful/second-call-raising/input-mutating encoding to_str, BasicObject with/without to_str, b, to_s): they show 8 + 3 differences on 6f48723a86 and 0 on 02087583dc; bench/upstream/rk3/diff_all.sh runs diff_unescape, diff_escape and the reviewer's review_exactness (17,897 checks) on 3.2–4.0 clean and with cgi/util, and on 3.4/4.0 with the Ruby CGI: 0 differences everywhere (docs/upstream/data/rk3/final-head). RuboCop: same 61 pre-existing offenses in the touched files as main, none new. Body numbers: script/upstream-bench run bench/upstream/rk3/body/RK3 on the exact head (A/A per cell). Whole requests rerun on the exact head (req/rk3.rb, rk34.rb verbatim): YJIT 1,000 warm-ups + FLAT=40, three base runs, all windows 0/0. Interpreter: the first exact-head cohort (fh-interp.txt) and a second (fh-interp2.txt) are rejected, not rescored: blog GET article A/A 0.97% and the JSON control bimodal (4.24M/4.31M Ir); Callgrind attribution put the 1.35M-Ir jump in glibc malloc_consolidate/_int_malloc, so the accepted cohort (fh-interp3.txt) ran with GLIBC_TUNABLES=glibc.malloc.mxfast=0, A/A at most 0.18%. Fork CI on 02087583dc: 2.7.3 again fails in setup (ubuntu-26.04 has no 2.7.3 build), mentioned in the body. Needs a claude-code/thermos pass on 02087583dc before opening; one PR, two commits.
passes:
  - {reviewer: thermos-sol, orb: "T-01a1ec13-3575-7694-b1c3-e0edd9abc152", head: "a8a5d747d0956efe7af5a0b36520f1d0a9698b40", date: 2026-11-18, verdict: changes, open: "Three introduced compatibility defects: (P2) non-ASCII-compatible escape raises on clean Ruby 3.4.12 + ERB 6.0.7, smallest fix URI fallback for such input; (P3) decoder coerces encoding twice and before decoding, smallest fix CGI.unescape(s, Encoding::BINARY).force_encoding(encoding); (P3) calling instance_of? rejects valid BasicObject coercions, smallest fix String === s before the exact-class predicate in all three guards. Diagnostic repairs pass 17,897 comparisons per configuration on MRI 2.7.3, 2.7.8, 3.4.12, 4.0.9 and pure CGI on 3.4/4.0. No Rack edits or push. Must also replace unsupported exactness/only-boundary and JSON-control prose, scope native/C and Rails caller claims, add the requested changelog, refresh clean-process and performance evidence on the repaired head. Historical request arithmetic and accepted YJIT 0/0 counters verified, not a three-app rebenchmark; body benchmark rerun inconclusive (56–210% main spread). JRuby uses a Java loader, TruffleRuby a Ruby shim; neither engine executed. One PR with two commits. Full synthesis, sentence-by-sentence claim audit, commands and receipts: bench/upstream/rk3/review-thermos-sol/README.md."}
  - {reviewer: thermos-sol, orb: "T-01a1ec13-3575-7694-b1c3-e0edd9abc152", head: "6f48723a862129d42e901d2baae16b1b826404bc", date: 2026-11-18, verdict: changes, open: "Prior P2 fixed by restored ASCII-compatible escape guard. Two P3 exactness must-fixes remain: CGI.unescape(s, Encoding::BINARY).force_encoding(encoding) in both decoders preserves once-only late encoding coercion; String === s before instance_of? in all three guards preserves BasicObject URI coercions. Full suites on 3.4.12/4.0.9 with and without cgi/util: 1292 runs, 6270 assertions, zero failures/errors, two skips, separate files pass. Original 300k scripts zero ordinary differences in all four configurations. Expanded 17,897-comparison matrices on 2.7.3/3.4.12/4.0.9 plus pure 3.4/4.0 find only those two families; diagnostic fixes pass all eight configurations. Both parallel reviewers returned approve-with-nits after the P2 fix; unified changes reflects the requested exactness contract and false only-boundary claim, not a security blocker. Amend message/body qualifications, add changelog, refresh exact-head body-number evidence; historical request arithmetic verified, not rerun. Confirmed 2.7.3 hosted setup failure: unavailable on ubuntu-26.04; rake skipped. One PR, two commits. Full evidence: bench/upstream/rk3/review-thermos-sol/6f48723a86/README.md. No Rack changes or publishing."}
---

# Decode and escape form components with cgi/escape

`Rack::Utils.unescape` and `Rack::QueryParser#unescape` decode the keys and values of query strings and form bodies and every cookie value, and `Rack::Utils.escape` escapes every `Set-Cookie` value. They call `URI.decode_www_form_component` and `URI.encode_www_form_component`, which copy the string and run a `gsub` with a Hash lookup for each escape. `cgi/escape` decodes and escapes the same way, in C on MRI. It ships with every Ruby Rack supports: MRI has had `CGI.escape` and `CGI.unescape(str, encoding)` in `cgi/escape` since 2.3, and cgi is a default gem since 2.7. Rack already requires it for `escape_html` on Ruby before 3.2. TruffleRuby uses its Ruby implementation and JRuby its own Java one.

The first commit decodes with `CGI.unescape`. It keeps URI's check for an invalid %-encoding and its message, so `InvalidParameterError` is raised as before, and like URI it decodes to bytes and converts the encoding argument once, afterwards. The second commit escapes with `CGI.escape`, which escapes `*` and leaves `~` alone where URI does the opposite, so the two are mapped back; `%2A` in its output can only come from a `*`, since a `%` becomes `%25`. Anything that isn't a plain String (subclasses, other objects, `BasicObject`) still goes through URI, and so does a string to escape in an encoding that isn't ASCII-compatible, such as UTF-16: on MRI before 4.0 the C `CGI.escape` hands those to a Ruby fallback that only `cgi/util` defines.

```ruby
require "rack/utils"

rng = Random.new(7)
# A synthetic encrypted Rails session cookie: random data, IV and auth tag, Base64-encoded and joined with "--" (284 bytes).
cookie = [180, 12, 16].map { |n| [rng.bytes(n)].pack("m0") }.join("--")
token = [rng.bytes(64)].pack("m0")
form = "_method=patch&authenticity_token=#{Rack::Utils.escape(token)}" \
  "&article%5Btitle%5D=Hello+world&article%5Bbody%5D=Rack+decodes+every+form+value.&commit=Update+Article"
header = "_blog_session=#{Rack::Utils.escape(cookie)}; theme=dark"

Rack::Utils.parse_nested_query(form)
Rack::Utils.parse_cookies_header(header)
Rack::Utils.set_cookie_header("_blog_session", {value: cookie, path: "/", httponly: true, same_site: :lax})
```

| Ruby 4.0.9 | main | this branch | |
| --- | ---: | ---: | ---: |
| `parse_nested_query`, instructions / objects | 183.0k / 100 | 119.0k / 51 | −34.9% |
| `parse_cookies_header`, instructions / objects | 71.1k / 34 | 36.2k / 17 | −49.1% |
| `set_cookie_header`, instructions / objects | 103.9k / 29 | 28.8k / 15 | −72.2% |
| same three with YJIT, i/s | 42.8k / 86.9k / 76.2k | 81.7k / 199.0k / 242.8k | 1.91x / 2.29x / 3.19x |

Instructions are Callgrind counts per call; two runs of main differ by less than 0.25%. Rates are the best of three rounds on one pinned core; main varied by up to 5.4% between rounds.

Both methods were compared with URI on 300,000 random strings each: escapes, lone and broken `%`, `+`, multibyte and invalid bytes, UTF-8, binary, US-ASCII, ISO-8859-1 and UTF-16LE input, frozen strings, and UTF-8, binary, US-ASCII, Shift_JIS and ISO-8859-1 targets. Fixed cases add `nil`, Symbols, Integers, String subclasses, `BasicObject` with and without `to_s`, `to_str` and `b`, and encoding arguments whose `to_str` changes its answer, raises on a second call or changes the input. This ran on Ruby 3.2, 3.3, 3.4 and 4.0, with and without `cgi/util` loaded, and with `cgi/escape`'s Ruby implementation. For these inputs the result's class, encoding, bytes, validity and frozenness, and every exception class and message, are the same. What does change is that URI's own calls on a plain String argument (`b`, `dup`, `to_s`) no longer happen, so a singleton method or a redefinition of those on String is no longer called. The new tests cover the cases where the two libraries differ: the `*` and `~` mapping, the result encoding, String subclasses and `BasicObject`, the encoding argument and the invalid %-encoding message.

In Rails, cookies are read and written through these methods and form bodies are parsed by Rack, while query strings go through Rails' own parser. In whole requests of three open-source Rails apps this removes 0.9% to 5.4% of the instructions per request without YJIT and 2.9% to 10.1% with it, mostly from the session cookie, and 60 to 130 objects. A JSON request with no query and no cookie written moves +0.01% without YJIT and +0.04% with it, within the noise of two unchanged runs.

The `test (ubuntu-latest, 2.7.3)` job fails on my fork before any test runs: `ubuntu-latest` is now Ubuntu 26.04, for which `ruby/setup-ruby` has no 2.7.3 build. The other jobs pass.
