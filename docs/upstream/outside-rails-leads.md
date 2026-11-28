# Leads outside rails/rails (2026-11-17)

rails/rails is at its 15-open-PR cap, and ruby-i18n/i18n, tzinfo, rubocop-performance and inertia-rails each have PRs
of ours without a maintainer response. This round looks for request costs in gems whose repos have room
(`script/pr-queue status`, 2026-11-17 22:00 UTC), with the default gems in view this time: the earlier gem censuses
([round 1](gem-request-census.md), [round 2](gem-request-census-2.md)) folded Ruby's standard library and default gems
(uri, erb, cgi, json, securerandom, openssl, ipaddr, monitor, …) into their callers, so nothing below Rack or Rails in
the stdlib had been ranked on its own. Nothing was built for upstream, opened or posted.

**Result.** Five leads, ranked. Shares are of one request's instructions inside `Rails.application#call`.

| # | Lead | Repo, reviewer | Request effect (interpreter, Callgrind, fixed heap) | Exact? | Prior work |
| --- | --- | --- | --- | --- | --- |
| 1 | **RK3**: decode query, form and cookie components with `cgi/escape`'s C decoder in `Rack::Utils.unescape` and `QueryParser#unescape` | rack/rack; jeremyevans reviews (approved our #2550 the day it opened), ioquatix and samuel-williams-shopify merge | with RK4: −0.6% to −5.2% on 9 workloads in 4 apps (blog PATCH −5.2%, pingcrm PUT −3.3%, blog GET article −1.6%), 62–143 fewer objects; −0.02% on a JSON control. RK3 alone −0.73% on blog GET article. YJIT not yet claimed | yes, 300,000-case differential identical; boundary: `URI.decode_www_form_component` is no longer called for Strings | none on `unescape`; precedent rack#2099 (`escape_html` → `CGI.escapeHTML`, merged 2023) |
| 2 | **RK4**: escape cookie values with `CGI.escape` in `Rack::Utils.escape` | rack/rack, same | alone −0.50% on blog GET article; per call −85% for a signed cookie | yes, 300,000-case differential identical | none; next to our approved #2550 (same file, other method) |
| 3 | **NK2**: `css` translates the selector to XPath on every call (Action Text) | sparklemotion/nokogiri; flavorjones (outside merges 2026-11-02 and 11-04; on our #3759: "I'll review today or tomorrow") | joined-XPath cache: campfire POST message −1.6%, writebook PATCH page −0.9%; exact flat key alone −0.14% / −0.20% | the flat cache key is exact; the joined-XPath cache is a second cache (L2) | round 2 lead; nokogiri#3226 (2024) added `SelectorCache`; open Ractor PRs #3706 and #3702 touch the same files |
| 4 | **GQ1**: Warden name caches compare by value | rmosolgo/graphql-ruby; rmosolgo (merged our #5877, #5880, #5881 in 2–3 h; outside merges 2026-11-10 and 11-17) | Zammad replay −0.64% per round; validation −7.5% to −43% (round 2, [graphql-ruby](graphql-ruby.md#gq1-warden-name-caches-compare-by-value-held)) | **no**: documented `.get_field` overrides run once per name instead of once per node | built as a PR 2026-11-18 (queue item GQ1, branch `thomasklemm/warden-name-caches-by-value`, [record](graphql-ruby.md#gq1-as-a-pull-request-2026-11-18)); opens as a draft after Astra; the drafted issue is not posted |
| 5 | **UR1**: `URI.decode_www_form_component` and `encode_www_form_component` copy the String twice and run a Hash-table `gsub` | ruby/uri; hsbt (last outside merge 2026-03-16; 13 outside PRs open, the oldest since August) | the root cause under RK3/RK4; for every URI user | yes for the one-copy change | ruby/uri is parked ([DECISIONS](../DECISIONS.md#bets)); czj's open ruby/uri#269 is parsing, not this |

**Recommendation: build RK3 first** (with RK4 as a second commit or a second PR). It reaches every app and every
request that has a query string, a form body or a cookie, it is exact by a differential, the change is a few lines in
one method each, and rack's reviewer answers within a day. Its risk is merge latency: rack has three approved
performance PRs from others (#2519, #2520, #2522) and our approved #2550 still unmerged after two to six weeks. Before
opening it, get a YJIT request number with passing controls (this orb's YJIT batch failed its A/A or was stopped for
memory). NK2 comes next once flavorjones has answered #3759 and the Ractor PRs have landed: the exact flat key alone is
only −0.2%, so it is a question about a second cache, not a PR.

**Not leads** (measured or checked, details under [Checked and rejected](#checked-and-rejected)): cancancan
(stackprof's 5–6% of pingcrm was not real; an exact rewrite moves −0.04%), sqlite3-ruby (`Statement#each` is
jhawthorn's open #768; the rest is `prepare` and `step`), json (one C call each), openssl HMAC (czj's
ruby/openssl#1133, closed; moved to rails/rails#59430), monitor and `SecureRandom.uuid` (ruby/ruby, closed to us;
their callers are Rails), ipaddr (0.1%), propshaft (fixed on main), useragent (UA1, held), Campfire's
`InlineScriptHashes` (app code, our once-campfire#374), Sentry breadcrumbs (spread).

## Pins and method

* **Ruby 4.0.9** (Lowrail's pin), interpreter and YJIT. **Apps:** blog (Rails main `4500a94c34`), campfire,
  writebook, pingcrm and codetriage (census 9's Rails main `50c54eed06`): 5 apps, 42 workloads, set up with
  `script/census setup` on this orb. Fizzy and Lobsters failed in setup on both Rails commits (Fizzy:
  `SystemStackError` in its `uuid_primary_keys` initializer; Lobsters: "User has no attribute
  `prefers_color_scheme`" in `harness.rb prepare`), and redprints-cfp in its JS build; the 2-CPU, 3 GB orb could not
  hold the PostgreSQL-heavy apps. So the corpus is narrower than census 9's, and the gems the bigger apps load
  (graphql-ruby, Sidekiq, Devise beyond codetriage) are not in it.
* **Ranking:** [`stdprof.rb`](../../bench/upstream/outside_leads/stdprof.rb), the gem request census's profiler
  (stackprof, wall mode, 100 µs, 50 warm-up and 150 measured operations per workload), changed so that a frame under
  `rubylibdir` or in a default gem is owned by `std:<lib>` instead of folding into its caller. Each gem or std sample
  also records the nearest frame with another owner, which separates `std:uri <- gem:rack` from
  `std:uri <- harness` (rack-test building the request) and from `std:uri <- app`. Two full YJIT runs (`s1`, `s2`) are
  the A/A; the rows below move by ≤ 0.2 points between them. Ranked with
  [`stdrank.rb`](../../bench/upstream/outside_leads/stdrank.rb).
* **Request numbers:** [`req/reqrun.rb`](../../bench/upstream/outside_leads/req/reqrun.rb) runs one workload under
  Callgrind and counts instructions and objects only inside `Rails.application#call` (not the rack-test session
  around it), GC disabled for the measured 20 requests (fixed heap), 200 warm-up requests (1,000 under YJIT). Each
  lead is a measurement patch loaded after boot ([`req/`](../../bench/upstream/outside_leads/req)); `none.rb` twice
  gives base and A/A. Stackprof shares rank; only Callgrind numbers are claimed.
* **Per call:** Callgrind with GC disabled, `(Ir(N) − Ir(0)) / N`, through
  [`ir.sh`](../../bench/upstream/gem_request_census/ir.sh) and the setups in
  [`micro/`](../../bench/upstream/outside_leads/micro).
* **Receipts:** [`data/outside-rails-leads/`](data/outside-rails-leads/).

## Where request time goes outside Rails

Mean share of each workload's samples (YJIT, `s1` / `s2`, 42 workloads), by owner and who called it; harness rows
left out.

| Owner ← caller | s1 | s2 | Per app (s1) | Disposition |
| --- | ---: | ---: | --- | --- |
| std:uri ← app | 4.50% | 4.59% | campfire 16.0%, writebook 5.6% | `InlineScriptHashes` (app code): our once-campfire#374 |
| gem:rack ← rails | 2.86% | 2.79% | blog 4.3%, pingcrm 3.7%, codetriage 2.1%, writebook 2.1%, campfire 1.8% | ETag digest (rack#2522), our #2550, the rest under 0.2% each |
| gem:sqlite3 ← rails | 2.68% | 2.57% | writebook 5.8%, blog 3.8%, campfire 3.2% | `step`/`prepare`; `to_a` in jhawthorn's sqlite3-ruby#768 |
| gem:i18n ← rails | 1.55% | 1.53% | blog 4.4% | our i18n#763–#766, unanswered |
| gem:concurrent-ruby ← rails | 1.49% | 1.47% | all | call volume (round 1) |
| gem:useragent ← rails | 1.25% | 1.24% | blog 3.3% | UA1, held |
| gem:nokogiri ← rails | 1.24% | 1.22% | campfire 4.9%, writebook 1.1% | **NK2** |
| gem:pg ← rails | 1.07% | 0.65% | codetriage, pingcrm | the wait in `get_result` |
| **std:uri ← gem:rack** | **1.05%** | **0.89%** | pingcrm 2.0%, blog 1.3%, codetriage 1.2%, writebook 0.6%, campfire 0.2% | **RK3, RK4** (UR1 underneath) |
| gem:cancancan ← rails | 1.03% | 1.14% | pingcrm 5.4% / 6.0% | not real (below) |
| gem:inertia_rails ← rails | 0.57% | 0.56% | pingcrm 3.0% | inertia-rails has no room |
| std:monitor ← rails | 0.56% | 0.53% | all | ruby/ruby; Rails' `Response` and connection pool |
| std:json ← rails | 0.52% | 0.53% | all | C generate and parse |
| std:uri ← gem:globalid | 0.35% | 0.37% | jobs | `URI::GID.build`, rejected in round 1 |
| std:openssl, std:random, std:securerandom, std:ipaddr ← rails | 0.13–0.17% each | | all | cookie encryption IVs, request ids, `RemoteIp` |

Under `std:uri ← gem:rack`, three sites: `QueryParser#unescape` (0.36% / 0.34%), `Rack::Utils.unescape` from
`parse_cookies_header` (0.32% / 0.24%) and `Rack::Utils.escape` from `set_cookie_header` (0.31% / 0.27%).

## RK3: rack decodes components with `cgi/escape`

**Site.** `Rack::Utils.unescape` (cookies, `parse_cookies_header`) and `Rack::QueryParser#unescape` (every query
string and form key and value) call `URI.decode_www_form_component`, which checks for a lone `%` with a regexp,
copies the String with `b`, runs `gsub(/\+|%\h\h/, TBLDECWWWCOMP_)` (a Hash lookup and a MatchData per escape) and
forces the encoding. `cgi/escape` ships a C `CGI.unescape(str, enc)` that decodes `+` and `%XX` the same way; rack
already requires `cgi/escape` for `escape_html` on Rubies before 3.2.

**Calls per request** ([`req/count.rb`](../../bench/upstream/outside_leads/req/count.rb), app plus rack-test):
`QueryParser#unescape` 7–24 (two per form field, 7 on a GET from rack-test's own query handling),
`Rack::Utils.unescape` 1–3, `Rack::Utils.escape` 1–2.

**Change measured** ([`req/rack_unescape.rb`](../../bench/upstream/outside_leads/req/rack_unescape.rb)):

```ruby
def unescape(s, encoding = Encoding::UTF_8)
  return URI.decode_www_form_component(s, encoding) unless s.instance_of?(String)
  raise ArgumentError, "invalid %-encoding (#{s})" if /%(?!\h\h)/.match?(s)
  CGI.unescape(s, encoding).force_encoding(encoding)
end
```

**Per call** (Ir, interpreter / YJIT, [`micro/unescape.rb`](../../bench/upstream/outside_leads/micro/unescape.rb)):

| Input | URI | `CGI.unescape` + check | |
| --- | ---: | ---: | ---: |
| `hello` | 4,229 / 3,385 | 2,427 / 2,104 | −43% / −38% |
| `article%5Btitle%5D` (a form key) | 13,413 / 12,644 | 4,135 / 3,702 | −69% / −71% |
| `Hello+world+from+Rack` | 15,536 / 14,692 | 3,711 / 3,391 | −76% / −77% |
| a 250-byte signed cookie value with `%3D%3D` | 18,396 / 17,584 | 8,446 / 7,959 | −54% / −55% |

**Per request:** in the table under [Request numbers](#request-numbers) (RK3 and RK4 together, and each alone on
two workloads).

**Exactness.** [`micro/unescape_diff.rb`](../../bench/upstream/outside_leads/micro/unescape_diff.rb): 300,000 random
Strings over `%`, `+`, hex digits, `%2`, `%zz`, `%e3%81%82`, `é`, `あ`, `\xFF`, in UTF-8, BINARY and US-ASCII, 20%
frozen, decoded to UTF-8, BINARY, Shift_JIS and ISO-8859-1: class, encoding, bytes, frozenness and validity of the
result, and the class and message of any exception, identical. Also identical for `nil`, a Symbol, an Integer, a
UTF-16LE String and a String subclass (these keep going through URI). The pieces that make it exact:

* the lone-`%` check is URI's own regexp and message, run first, so ASCII-incompatible input raises the same
  `Encoding::CompatibilityError` from the same call;
* `CGI.unescape` returns its result in the input's encoding when the bytes are not valid in `encoding`; the
  `force_encoding` puts it back to `encoding`, which is what URI returns (Rails then rejects invalid UTF-8 params as
  before);
* `CGI.unescape` returns a copy of a subclass instance when there is nothing to decode, URI a plain String; the
  `instance_of?(String)` guard sends subclasses and non-Strings to URI.

**Boundary.** Strings no longer go through `URI.decode_www_form_component`, so a prepend on it no longer sees
rack's calls. JRuby and TruffleRuby get `cgi/escape`'s Ruby fallback, which decodes the same way.

**Prior work.** No rack PR or issue touches `unescape` (searched "unescape", "decode_www_form_component",
"cgi/escape"). rack#2099 (2023) delegated `escape_html` to `CGI.escapeHTML`, the same kind of change. #2519
(approved, unmerged since 2026-10-07) changes `each_query_pair` next to it, not `unescape`. ruby/uri has no PR on
decoding.

## RK4: rack escapes cookie values with `CGI.escape`

**Site.** `Rack::Utils.escape` (every `Set-Cookie` value, through `set_cookie_header`; also `build_query`) calls
`URI.encode_www_form_component`, which dups, forces BINARY, and runs `gsub!(/[^*\-.0-9A-Z_a-z]/, TBLENCWWWCOMP_)`.
A Rails session or signed cookie is 200–400 bytes of Base64 and `--`, with `=`, `/` and `+` to escape.

**Change measured** ([`req/rack_escape.rb`](../../bench/upstream/outside_leads/req/rack_escape.rb)). `CGI.escape`
leaves `~` alone and escapes `*`, where URI does the opposite, so the two are mapped back:

```ruby
def escape(s)
  r = CGI.escape(s.to_s).force_encoding(Encoding::US_ASCII)
  r.gsub!("%2A", "*") if r.include?("%2A")
  r.gsub!("~", "%7E") if r.include?("~")
  r
end
```

`%2A` in `CGI.escape`'s output can only come from a `*` (a `%` becomes `%25`), so the mapping is exact.

**Per call** (Ir, interpreter / YJIT, [`micro/escape.rb`](../../bench/upstream/outside_leads/micro/escape.rb)): a
300-byte signed cookie value 67,102 / 65,936 → 9,953 / 9,105 (−85% / −86%); `hello` 5,863 / 4,786 → 4,067 / 3,276.

**Exactness.** [`micro/escape_diff.rb`](../../bench/upstream/outside_leads/micro/escape_diff.rb): 300,000 random
Strings (the characters URI and CGI treat differently, `%2A` itself, NUL, newline, multibyte, invalid bytes; UTF-8,
BINARY, US-ASCII and UTF-16LE; 20% frozen), plus `nil`, a Symbol, an Integer, a Float and a String subclass: identical
class, encoding (US-ASCII), bytes, frozenness and exceptions. The first version without the early `force_encoding`
raised on UTF-16LE input; that is why it comes first. **Boundary:** as RK3, and an object whose `to_s` returns a
non-String raises `TypeError` instead of URI's `NoMethodError`.

## NK2: nokogiri translates CSS to XPath on every call

**Site.** `Searchable#xpath_query_from_css_rule` builds an `XPathVisitor` per implied context and calls
`CSS.xpath_for`, whose `SelectorCache` key is `[selector, visitor.config]`, a new Array holding a new Hash; hashing
and comparing that nested key (with Ruby's recursion guard) is most of a cache hit. Action Text calls `css` 10–41 times
when it renders or updates a rich-text body (`ActionText::Fragment#find_all` and `#update`), next to 10–37
`Document#dup`s.

**Per call** (Ir, interpreter, [`micro/nokogiri_css.rb`](../../bench/upstream/outside_leads/micro/nokogiri_css.rb),
nokogiri 1.19.7, an Action Text-like fragment): `fragment.css("action-text-attachment")` 107,736;
`fragment.xpath(".//*:action-text-attachment")` with the XPath it produces 39,232. Of the difference, the translation
(`xpath_query_from_css_rule`) is 25,899, the `SelectorCache` lookup alone 13,579 (`K.hash` 5,973), `XPathVisitor.new`
3,897, `visitor.config` 1,971, `children` 4,674. A flat key `[selector, builtins, doctype, prefix, namespaces]`
looks up in 6,396 instead of 12,788.

**Per request:** in [Request numbers](#request-numbers): a cache of the joined XPath per (implied contexts, rule,
doctype, namespaces) and, separately, only the flat `SelectorCache` key.

**Exactness.** The flat key is exact: two keys are `eql?` exactly when their config Hashes are, and nothing else
reads the key. The joined-XPath cache returns the String that `xpath_for` built for the same inputs, so `css` returns
the same nodes; but it is a second cache that `SelectorCache.clear_cache` would have to clear too, and hits skip
`CSS.xpath_for` and the visitor (a prepend there would see fewer calls). That makes it L2, as round 2 said.

**Prior work.** nokogiri#3226 (2024) moved the cache into `CSS::SelectorCache`. jhawthorn's #3706 ("Ractor safety",
updated 2026-11-11) and rubys' #3702 change `css.rb`, `selector_cache.rb` and `xpath_visitor.rb`, so a change here
should wait for or build on them. Our #3759 (`DocumentFragment#css` reads `children` once) is open.

## GQ1: graphql-ruby's Warden caches compare names by value

Unchanged from [round 2](graphql-ruby.md#gq1-warden-name-caches-compare-by-value-held), rechecked against the
active-maintainer weighting: rmosolgo merges outside PRs the same day, so this is the one lead in a fast repo. None
of this round's five apps loads graphql-ruby, so there is no new number: Zammad's replay −0.64% per round of 8 desktop
queries, validation of the tracked benchmarks −7.5% to −43.2%. It is **not exact**: with it, `.get_field` and
`Schema.get_type` overrides (a documented hook) run once per name per query instead of once per AST node, and the
skeptic built a schema whose answer changes. The next step is a question to rmosolgo (an issue with the probe), not a
PR.
The issue was drafted (2026-11-18) with a probe against the released 2.6.16 and is not posted: Thomas wants a PR.
Built the same day on master `9c9f8f28cc` as queue item GQ1, with the hook contract change stated in the body; it
opens as a draft after a deep Astra review ([record](graphql-ruby.md#gq1-as-a-pull-request-2026-11-18)).

## UR1: ruby/uri copies twice to decode and escape

Under RK3 and RK4: `_decode_uri_component` is `str.b.gsub(...)` (two new Strings even when nothing is escaped) and
`_encode_uri_component` is `str.to_s.dup` plus `gsub!` with a Hash table. Decoding with one copy (`str = str.b;
str.gsub!(...)`) is exact and helps every `URI.decode_www_form_component` caller, but saves only ~250 Ir per call
(4,229 → 3,978 for `hello`); the large saving needs C, which ruby/uri doesn't have. ruby/uri is parked
([DECISIONS](../DECISIONS.md#bets)), its maintainer last merged an outside PR on 2026-03-16, and 13 outside PRs are
open. Rack can take the gain itself (RK3, RK4), so UR1 stays a note.

## Request numbers

Interpreter, Callgrind, GC off for the 20 measured requests, 200 warm-ups. Base is the mean of two `none.rb` runs;
A/A is their difference. Receipts: `req-r-interp.txt`, `req-rackA.txt`, `req-n-interp.txt`, `req-n2-interp.txt`.

**RK3 + RK4** ([`req/rack_both.rb`](../../bench/upstream/outside_leads/req/rack_both.rb)):

| App, workload | A/A | Base Ir | With RK3+RK4 | Δ | Objects |
| --- | ---: | ---: | ---: | ---: | --- |
| blog PATCH article (redirect) | 0.00% | 4,714,108 | 4,468,803 | **−5.20%** | 1,437.9 → 1,294.8 |
| pingcrm PUT contact (Inertia redirect) | 0.24% | 7,118,708 | 6,884,065 | **−3.30%** | 1,828.6 → 1,722.6 |
| blog POST comment (redirect) | 0.35% | 7,077,146 | 6,905,903 | **−2.42%** | 1,904.7 → 1,805.4 |
| pingcrm GET contacts (Inertia JSON) | 0.01% | 12,495,410 | 12,297,481 | **−1.58%** | 3,096.6 → 3,000.6 |
| blog GET article | 0.17% | 8,347,239 | 8,216,129 | **−1.57%** | 2,025.9 → 1,963.8 |
| pingcrm GET contacts | 0.07% | 13,850,927 | 13,660,819 | **−1.37%** | 3,351.6 → 3,257.8 |
| codetriage PATCH repo subscription (redirect) | 0.07% | 14,330,370 | 14,168,533 | **−1.13%** | 2,595.7 → 2,503.6 |
| codetriage GET repo | 0.02% | 14,907,632 | 14,751,417 | **−1.05%** | 3,268.2 → 3,200.8 |
| writebook GET book | 0.04% | 28,526,142 | 28,355,569 | **−0.60%** | 5,717.1 → 5,631.4 |
| blog GET articles.json (control: no query, no session cookie written) | 0.03% | 4,248,650 | 4,247,653 | −0.02% | 1,130.8 → 1,130.8 |

Campfire GET room is left out: its two base runs were 158.1M and 14.3M Ir (A/A failed). Split on blog GET article
(one batch, base 8,916,738): RK3 alone −0.73% (8,851,747), RK4 alone −0.50% (8,872,522), both −1.64% (8,770,195).

**YJIT** (this lead pass, superseded): blog PATCH's A/A failed (2,591,277 vs 2,701,514, 4.2%) and blog GET article read +1.2% with 200 warm-ups and no JIT-flat check. Those runs measured the warm-up's first compile of the harness's own block inside the window; the build below fixes the harness and has the YJIT numbers.

**NK2** ([`req/noko_cache.rb`](../../bench/upstream/outside_leads/req/noko_cache.rb), joined-XPath cache, L2;
[`req/noko_flatkey2.rb`](../../bench/upstream/outside_leads/req/noko_flatkey2.rb), flat `SelectorCache` key, exact):

| App, workload | A/A | Base Ir | Joined-XPath cache | Flat key only |
| --- | ---: | ---: | ---: | ---: |
| campfire POST message (turbo_stream) | 0.00% | 43,304,835 | 42,617,452 (**−1.59%**, objects 10,953.7 → 10,823.8) | 43,245,951 (−0.14%, → 10,937.8) |
| writebook PATCH page (turbo_stream) | 0.11% | 37,804,459 | 37,472,610 (**−0.88%**, 7,988.5 → 7,916.8) | 37,727,633 (−0.20%, → 7,965.1) |

A second campfire batch repeats the cache at −1.68% (43,317,326 → 42,591,298). YJIT: base A/A 26,634,176 /
26,698,015 (0.24%); the cache run was stopped for memory. So the exact flat key alone is a fifth of a percent; the
gain is in skipping the translation, which needs flavorjones to accept a second cache.

## RK3 built (2026-11-18)

**Exact-head numbers (2026-11-18).** On head `c0a8e93011` against rack main `da90464e3f`, three declared cohorts,
each run once and accepted ([manifest and results](../../bench/upstream/rk3/head/README.md)): the body's micro table
(interpreter −34.4%, −48.9%, −72.5% per call, A/A ≤ 0.24%) and whole requests on full checkouts, not method overlays
(interpreter with fastbins off −1.0% to −5.5%, four requests in three apps, A/A ≤ 0.27%; YJIT −2.8% to −10.0%, three
requests in two apps, every window JIT-flat, A/A ≤ 0.40%). The request figures below are earlier records.

**Thermos review supersedes blanket exactness below (2026-11-18).** Verdict **changes** on amended head
`6f48723a86`, recorded as `thermos-sol`. The restored escape guard fixes the old-head UTF-16 loader failure.
Full Rack suites on 3.4.12/4.0.9 each with and without `cgi/util`: 1,292 runs, 6,270 assertions, zero failures/errors,
two skips; separate-file tests pass. Both original 300k scripts also pass in all four configurations. Two P3
compatibility edges remain: encoding ducks are coerced twice and before native decoding, and BasicObject values
with valid URI coercions fail at `instance_of?`. Smallest repairs: decode to BINARY then force the caller's
encoding once; `String === s` before all exact-class guards. Diagnostic fixes pass 17,897 comparisons in each
of eight configurations (2.7.3/3.4.12/4.0.9 with/without explicit util preload, plus pure 3.4/4.0). Old ERB loads
util incidentally on 2.7.3; that case is not a no-util execution. Both parallel reviewers approve with nits under
an ordinary-input contract; the unified changes verdict reflects the requested exactness and false only-boundary
claim, not a security blocker. One PR retaining two commits is recommended after repairs, changelog and evidence
corrections. The Rack branch was not changed or pushed. Minimum Ruby is 2.7.3, not 2.4; JRuby's inspected CGI
loader selects Java, TruffleRuby's skips C; neither VM was executed. Hosted 2.7.3 fails provisioning because that
patch is unavailable on ubuntu-26.04, with rake skipped (public job/check annotations retained; full log forbidden).
New-head body-ips arithmetic checks out, maximum A/A 9.124%; the old reviewer wall-time cohort remains inconclusive
(56–210% A/A). Fresh interpreter cookie escape: 90,311/90,303 -> 14,369 Ir/op. Historical request arithmetic and
accepted YJIT 0/0 counters were checked, not rerun on the amendment. The under-0.02% guard estimate is not an
exact-head request measurement. JSON YJIT is +0.203% against 0.170% A/A, not simply unchanged. Full claim audit:
[`amended-head review`](../../bench/upstream/rk3/review-thermos-sol/6f48723a86/README.md). The following is the
builder's report, retained as history rather than an approval.

Branch `thomasklemm/unescape-cgi` on the fork, two commits on rack main `da90464e3f`:
`d85c4b9a42` decodes with `CGI.unescape` (RK3), `6f48723a86` escapes with `CGI.escape` (RK4). Queue item
[RK3](../../bench/upstream/pr-queue/items/RK3.md) (state in-review, unapproved draft title and body). Scripts:
[`bench/upstream/rk3/`](../../bench/upstream/rk3/README.md); receipts: [`data/rk3/`](data/rk3/).

The escape commit keeps the lead patch's `ascii_compatible?` guard. A first head (`a8a5d747d0`) dropped it, because
`CGI.escape` matched URI on UTF-16 and UTF-32 locally; rack's CI on the fork then failed on Ruby 3.2, 3.3 and 3.4. CI
installs the doc group, whose erb 6.0.7 no longer loads `cgi/util`, and the C `CGI.escape` hands a string in an
ASCII-incompatible encoding to `super`, the Ruby fallback in `cgi/util`: `NoMethodError` in the new UTF-16LE test.
Locally the default erb had loaded `cgi/util`. The amended head `6f48723a86` sends those strings to URI again; the
differentials below were rerun under rack's CI bundle (erb 6.0.7, `cgi/util` not loaded) as well.

**Exactness.** [`diff_unescape.rb`](../../bench/upstream/rk3/diff_unescape.rb) (both decode methods) and
[`diff_escape.rb`](../../bench/upstream/rk3/diff_escape.rb) against URI, loading rack from the branch: 300,000 random
cases plus 9 fixed odd inputs each, **0 differences** on Ruby 4.0.9, 3.4.12, 3.3.10 and 3.2.9, each both plainly and
under `bundle exec` in the rack checkout with the doc group (`diff-*-bundle.txt`), and on 3.4.12 with
`cgi/escape`'s pure-Ruby fallback ([`pure_cgi.rb`](../../bench/upstream/rk3/pure_cgi.rb)). Boundary, printed by the
scripts and not counted: a singleton `#b` (decode) or `#to_s`/`#dup` (escape) on a String argument is no longer
called. Ruby 2.7–3.1 not run (no precompiled Ruby on this orb); rack's hosted CI covers them.

**Tests.** 6 new tests in `spec_utils.rb` and `spec_query_parser.rb` (result encoding incl. invalid bytes
and Shift_JIS, String subclasses, the invalid %-encoding messages through `parse_query`, `*`/`~`, US-ASCII result,
UTF-16LE). Mutants caught: dropping the `force_encoding` (decode), the lone-`%` check, either `gsub!`, the US-ASCII
`force_encoding`, the `instance_of?` guards in `Utils` (the one in `QueryParser#unescape` only ever sees Strings from `split`). Full suite (`CI=spec bundle exec rake`): 1292 runs, 6270 assertions,
0 failures, 2 skips on 4.0.9, 3.4.12, 3.3.10 and 3.2.9. RuboCop (rack's `.rubocop.yml`): no new
offenses in the four touched files against main; main has 436 elsewhere and rack's CI does not run RuboCop.

**Per call** (Callgrind Ir, GC off, rack main twice as A/A / branch; [`micro.sh`](../../bench/upstream/rk3/micro.sh),
a 284-byte Rails-style encrypted cookie, a 5-field form):

| Call | interpreter main (A/A) | branch | | YJIT main (A/A) | branch | |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `unescape("hello")` | 4,677 / 4,666 | 3,186 | −32% | 3,287 / 3,994 | 2,296 | −37% |
| `unescape("article%5Btitle%5D")` | 13,858 / 13,844 | 4,893 | −65% | 12,905 / 13,167 | 4,215 | −68% |
| `unescape("Hello+world+from+Rack")` | 16,192 / 16,103 | 4,452 | −72% | 15,123 / 15,150 | 3,587 | −76% |
| `unescape(escaped cookie)` | 51,141 / 51,116 | 16,378 | −68% | 50,411 / 50,269 | 15,451 | −69% |
| `escape("hello")` | 6,054 / 6,037 | 5,497 | −9% | 4,397 / 4,823 | 4,445 | −4% |
| `escape(cookie)` | 90,343 / 90,287 | 13,930 | −85% | 89,285 / 89,276 | 12,924 | −86% |
| `parse_nested_query(form)` | 183,607 / 183,438 | 113,376 | −38% | 151,049 / 150,736 | 82,539 | −45% |
| `parse_cookies_header` | 71,446 / 71,504 | 35,083 | −51% | 67,421 / 67,867 | 31,673 | −53% |
| `set_cookie_header` (session cookie) | 105,200 / 105,189 | 28,707 | −73% | 102,044 / 101,807 | 25,813 | −75% |

With the restored guard (measured after the request runs below): `escape("hello")` 5,935 / 4,758, `escape(cookie)`
14,360 / 13,042 (−84% / −85%). The guard adds about 430 instructions per escape call, at most about 900 per
request (one or two `Set-Cookie` values), under 0.02% of any request below and inside every A/A, so the request
tables, measured without it, stand.

YJIT's small-call A/A is loose (`unescape("hello")` 3,287 / 3,994, `escape("hello")` 4,397 / 4,823), so the
`escape("hello")` row is no claim; the rest move far outside it.

**Per request** (Callgrind Ir inside `Rails.application#call`, 20 requests, GC off; patches
[`req/rk3.rb`](../../bench/upstream/rk3/req/rk3.rb) and [`req/rk34.rb`](../../bench/upstream/rk3/req/rk34.rb) are the
branch's method bodies verbatim over rack 3.2.7, whose three methods equal main's).

Interpreter, 200 warm-ups, base = mean of two `none.rb` runs:

| Workload | A/A | Base | RK3 | RK3+RK4 | Objects base → RK3 / both |
| --- | ---: | ---: | ---: | ---: | --- |
| blog PATCH article (redirect) | 0.04% | 4,707,344 | −3.15% | **−5.11%** | 1,438.5 → 1,338.3 / 1,302.8 |
| pingcrm PUT contact (Inertia redirect) | 0.01% | 7,099,802 | −0.48% | **−2.95%** | 1,820.5 → 1,743.9 / 1,728.6 |
| blog GET article | 0.08% | 8,343,453 | −0.42% | **−1.54%** | 2,022.7 → 1,978.7 / 1,966.8 |
| codetriage GET repo | 0.02% | 14,894,759 | −0.38% | **−1.01%** | 3,270.0 → 3,219.8 / 3,204.4 |
| blog GET articles.json (control) | 0.03% | 4,247,778 | +0.05% | −0.02% | 1,130.8 → 1,130.8 / 1,130.8 |

YJIT, 1,000 warm-ups, base = mean of three `none.rb` runs (two before, one after the patched runs), A/A = their
spread, every measured window JIT-flat (0 blocks compiled, 0 invalidations, `jit 0/0` in the receipts):

| Workload | A/A | Base | RK3 | RK3+RK4 | Objects base → both |
| --- | ---: | ---: | ---: | ---: | --- |
| blog PATCH article (redirect) | 0.16% | 2,572,478 | −4.81% | **−9.80%** | 1,441.2 → 1,307.8 |
| pingcrm PUT contact (Inertia redirect) | 0.20% | 4,079,634 | −1.55% | **−5.45%** | 1,836.7 → 1,739.5 |
| blog GET article | 0.25% | 4,756,410 | −0.92% | **−2.83%** | 2,036.0 → 1,977.7 |
| blog GET articles.json (control) | 0.17% | 2,208,688 | −0.08% | +0.20% | 1,139.6 → 1,139.6 |

Rejected and recorded, not rescored: the first YJIT pingcrm cohort (its first base window compiled 14 blocks;
[`req-yjit.txt`](data/rk3/req-yjit.txt)); the pingcrm row above is a fresh cohort with `FLAT=40` (warm in 20-request
windows until one is flat; one window was enough). Also rejected: an earlier YJIT run of this build before the harness
fix ([`req-yjit-rejected-noflat.txt`](data/rk3/req-yjit-rejected-noflat.txt)), whose windows each compiled 12–66 blocks
and invalidated 2 (the harness's measured block and its toggles first ran inside the window). `req.rb` now warms up
through the same block it measures, reports `jit B/I` per window, and takes `FLAT=K`.

Memory held: one valgrind at a time on this 2-CPU, 3.9 GB orb; codetriage was left out of YJIT to keep each run under
the cap.

**Wall time** (benchmark-ips on the first head `a8a5d747d0`, Ruby 4.0.9, one pinned core, best of 3 alternating rounds; main's spread over rounds as
A/A; receipts [`data/rk3/ips/`](data/rk3/ips/)):

| interp | main | branch | | main A/A |
| --- | ---: | ---: | ---: | ---: |
| `Rack::Utils.unescape("hello")` | 2,283,649 | 3,989,478 | 1.75x | 5.3% |
| `Rack::Utils.unescape("article%5Btitle%5D")` | 645,041 | 2,322,515 | 3.60x | 8.6% |
| `Rack::Utils.unescape("Hello+world+from+Rack")` | 539,861 | 2,801,910 | 5.19x | 5.8% |
| `Rack::Utils.unescape(ESCAPED_COOKIE)` | 173,816 | 674,675 | 3.88x | 28.4% |
| `Rack::Utils.escape("hello")` | 1,806,937 | 2,190,253 | 1.21x | 26.1% |
| `Rack::Utils.escape(COOKIE)` | 110,136 | 802,221 | 7.28x | 2.3% |
| `Rack::Utils.parse_nested_query(FORM)` | 39,640 | 71,659 | 1.81x | 2.1% |
| `Rack::Utils.parse_cookies_header(COOKIE_HEADER)` | 105,312 | 233,920 | 2.22x | 14.6% |
| `Rack::Utils.set_cookie_header("_blog_session", {value: COOKIE, path: "/", httponly: true, same_site: :lax})` | 97,535 | 295,193 | 3.03x | 20.3% |

| yjit | main | branch | | main A/A |
| --- | ---: | ---: | ---: | ---: |
| `Rack::Utils.unescape("hello")` | 3,184,819 | 6,698,543 | 2.10x | 0.5% |
| `Rack::Utils.unescape("article%5Btitle%5D")` | 701,969 | 3,166,054 | 4.51x | 4.8% |
| `Rack::Utils.unescape("Hello+world+from+Rack")` | 587,375 | 3,822,373 | 6.51x | 9.1% |
| `Rack::Utils.unescape(ESCAPED_COOKIE)` | 170,206 | 729,160 | 4.28x | 15.2% |
| `Rack::Utils.escape("hello")` | 2,527,914 | 2,834,751 | 1.12x | 3.6% |
| `Rack::Utils.escape(COOKIE)` | 114,042 | 832,773 | 7.30x | 8.9% |
| `Rack::Utils.parse_nested_query(FORM)` | 47,243 | 98,208 | 2.08x | 1.0% |
| `Rack::Utils.parse_cookies_header(COOKIE_HEADER)` | 107,320 | 255,270 | 2.38x | 4.7% |
| `Rack::Utils.set_cookie_header("_blog_session", {value: COOKIE, path: "/", httponly: true, same_site: :lax})` | 85,917 | 320,542 | 3.73x | 0.6% |

The orb's wall-time A/A is wide (up to 28% for one row in the interpreter), so only rows whose change is well
outside it count; `escape("hello")` (1.21x / 1.12x) does not. The body's own script
([`body_ips.rb`](../../bench/upstream/rk3/body_ips.rb), receipts [`data/rk3/body-ips/`](data/rk3/body-ips/)) on the final
head `6f48723a86`, same way: `parse_nested_query` 41,121 → 72,638 i/s (1.77x, A/A 8.9%), `parse_cookies_header`
112,658 → 237,960 (2.11x, 9.1%), `set_cookie_header` 92,786 → 288,196 (3.11x, 7.5%); YJIT 49,556 → 98,963 (2.00x,
4.5%), 119,650 → 262,407 (2.19x, 4.4%), 95,698 → 337,350 (3.53x, 0.9%). (On the first head: 1.81x, 2.12x, 3.35x;
YJIT 1.99x, 2.13x, 3.42x.)

**Rack CI on the fork** (`6f48723a86`): Test and Test External pass on 2.7, 3.0, 3.1, 3.2, 3.3, 3.4, 4.0, ruby-head,
jruby-head, truffleruby-head and macOS 4.0. `2.7.3` fails after 5 s on both heads, and on a rerun: runner setup, not this change. `ubuntu-latest` is now
ubuntu-26.04, for which ruby/setup-ruby has no 2.7.3 build ("Unavailable version 2.7.3 for ruby on ubuntu-26.04");
rack main's passing 2.7.3 job of 2026-10-31 ran on ubuntu-24.04.

## Checked and rejected

* **cancancan `possible_relevant_rules`** (pingcrm 5.4% / 6.0% in stackprof, `Hash#values_at` over the 85 ancestors
  and descendants of a model as its top C function). `can?` runs once per request and `alternative_subjects` 1–3
  times. An exact rewrite that walks the rule index instead of 86 lookups
  ([`req/cancan_keys.rb`](../../bench/upstream/outside_leads/req/cancan_keys.rb)) moves pingcrm's contact list
  13,862,084 → 13,855,958 Ir (−0.04%) in the interpreter and is slower under YJIT; even memoizing the subjects per
  ability (not exact) is −0.36%. Stackprof's wall samples landed on the method's C calls.
* **sqlite3-ruby:** `Statement#each` (2% of blog, 4.6% of writebook under YJIT) is the Enumerable `to_a` that
  jhawthorn's open #768 moves into C; `Statement#initialize` is `prepare`; `bind_params`' splat and `flatten` are
  0.2% and `flatten` calls `to_ary` checks on every value, so a shortcut is not obviously exact.
* **json:** `JSON::Coder#dump` and `JSON.parse` are one C call each; the Ruby wrappers are a few hundred Ir.
* **openssl:** `OpenSSL::HMAC.new` costs ~8 µs on OpenSSL 3.5; czj proposed `EVP_MAC` in ruby/openssl#1133, rhenium
  declined a second implementation, and the fix went to Rails as rails/rails#59430.
* **monitor, `SecureRandom.uuid`, `Random::Formatter#uuid`:** 0.56% and 0.3%, in ruby/ruby (closed to new PRs from
  us) and called by Rails' `Response`, connection pool and `RequestId`.
* **ipaddr** `IPAddr#in_addr` from `RemoteIp`: 0.1%.
* **propshaft** `app_stylesheets_paths`: fixed on Propshaft main ([DEF8](rails8-defaults.md)). **importmap-rails:**
  our #336. **useragent:** UA1 held ([useragent](useragent.md)).
* **Rack::Runtime** `"%0.6f" % time`: 0.5 µs per request.
* **Campfire's and Writebook's `InlineScriptHashes`** (16% and 5.6% under YJIT, 182 and 74 URI parses per page): app
  code, our once-campfire#374.
* **sentry-rails `ActiveSupportLogger` breadcrumbs** (codetriage 2.3%): spread over many methods, opt-in.

## RK3 after the Thermos review (2026-11-18)

Head `02087583dc` (decode `e3470303`, escape `02087583dc`) on rack main `da90464e3f` fixes the two exactness
must-fixes from the thermos-sol pass on `6f48723a86`: the decoders convert the encoding argument once, after decoding
(`CGI.unescape(s, Encoding::BINARY).force_encoding(encoding)`), and every guard is
`String === s && s.instance_of?(String)`, so `BasicObject` coercions reach URI again. It also adds two CHANGELOG lines
(rack#2550 had one; an earlier note here said otherwise) and drops the redundant inner `require 'cgi/escape'`.

* **Exactness:** [`diff_all.sh`](../../bench/upstream/rk3/diff_all.sh) runs both differentials (now with
  encoding-argument ducks and `BasicObject` cases) and the reviewer's `review_exactness.rb` (17,897 checks) on Ruby
  3.2–4.0, clean and with `cgi/util`, and on 3.4/4.0 with the Ruby CGI: 0 differences
  ([`data/rk3/final-head/`](data/rk3/final-head/)). The same scripts show 8 + 3 differences on `6f48723a86`.
* **Suite:** 1295 runs, 0 failures on 3.2–4.0, clean and with `-rcgi/util`. RuboCop: nothing new.
* **Body numbers:** `script/upstream-bench`, [`body/RK3`](../../bench/upstream/rk3/body/RK3/table.md): per call
  −34.9% / −49.1% / −72.2% instructions (interpreter, A/A ≤ 0.23%). Diagnostic only, not body claims:
  −43.7% / −52.4% / −74.3% YJIT instructions (A/A ≤ 0.61%) and benchmark-ips 1.91x / 2.29x / 3.19x
  (best-of-three base rates differ by ≤ 5.4%; raw baseline rounds span up to 11.5%). Neither worker records
  per-window JIT-flat counters; 3,000 warm-up calls are not a substitute for that check.
* **Per request with exact-head method bodies over Rack 3.2.7**, RK3 alone / both commits:

| Workload | Interpreter A/A | Interpreter | YJIT A/A | YJIT (JIT-flat) |
| --- | ---: | ---: | ---: | ---: |
| blog PATCH article | 0.09% | −2.61% / −5.35% | 0.06% | −5.10% / −10.14% |
| pingcrm PUT contact | 0.18% | −0.89% / −3.13% | 0.51% | −1.66% / −5.66% |
| blog GET article | 0.15% | −0.50% / −1.61% | 0.28% | −0.88% / −2.94% |
| codetriage GET repo | 0.03% | −0.36% / −0.89% | — | not run |
| blog GET articles.json | 0.03% | +0.01% / +0.01% | 0.22% | −0.09% / +0.04% |

The JSON control is inside its A/A in both modes. Two interpreter cohorts on this head are rejected, not rescored:
blog GET article's A/A was 0.97% and the JSON control alternated between 4.24M and 4.31M Ir; Callgrind put the
difference in glibc's `malloc_consolidate`, so the accepted cohort ran with `GLIBC_TUNABLES=glibc.malloc.mxfast=0`. Invocations, environment and the attribution: [`req/evidence/`](../../bench/upstream/rk3/req/evidence/README.md).
That changes allocator work and may change an allocation-reducing patch's effect; this is a separate
allocator-specific experiment, not confirmation under the default allocator. The recorded batch invocation and
verified inherited-environment implementation support symmetric application to base and candidate; no fresh
per-process environment capture is claimed. Request YJIT ran without this tunable and every measured window
reports 0/0. These are method-overlay measurements, not full-head-checkout request integration results.
Fork CI: `2.7.3` fails in setup again (ubuntu-26.04); the body says so.

**Final Thermos confirmation:** reviewer `thermos-sol` approves `02087583dc` with nits; no remaining code
must-fix. Eight independent matrices: 143,176 comparisons, zero differences. Full suites on 3.4.12/4.0.9,
with and without `cgi/util`: 1,295 runs, 6,274 assertions, zero failures/errors, two skips each. Extended 300k
scripts also pass clean/util/pure on both Rubies. Raw malloc dumps and all request/micro arithmetic were audited,
not rebenchmarked here. The draft drops ungated YJIT micro claims and qualifies packaging, String dispatch and
the request setup. Optional: add an input-mutating encoding test to protect late coercion as well as once-only
coercion. One PR retaining both commits. [Full sentence audit, commands and receipts](../../bench/upstream/rk3/review-thermos-sol/02087583dc/README.md).

## Re-measure of UR1 and NK2 (2026-11-27)

Rails main `2e299253f9`, Ruby 4.0.10 (interpreter, YJIT) and Ruby master `0d399335b7` built with
`--enable-yjit --enable-zjit` (interpreter, ZJIT). Census copies set up with `script/census setup` on this orb
(blog, campfire, writebook, pingcrm, codetriage on 4.0.10; blog, campfire, writebook on master with the
`frontier-master` overlays). Request numbers come from `req/reqrun.rb`, which now takes `REQ_RUBY` and `REQ_CORPUS`
and reads ZJIT's `compiled_iseq_count` / `compiled_side_exit_count` for the JIT-flat check. GC is off for 20 measured
requests after 200 (interpreter) or 1,000 + `FLAT=40` (JIT) warm-ups, and base is the mean of the `none.rb` runs with
their spread as the A/A. A JIT row counts only when every window of base and patch is `0/0`. Receipts:
[`data/outside-leads-2026-11-27/`](data/outside-leads-2026-11-27/).

**Upstream state.**
* RK3 (rack#2557) is approved and unmerged. GQ1 (graphql-ruby#5908) is open.
* **nokogiri:** flavorjones has not reviewed our #3759 since his 2026-11-05 "I'll review today or tomorrow".
  Its CI workflows still wait for first-contributor approval. Neither Ractor PR landed: jhawthorn's #3706 is open
  (flavorjones pushed a commit to it on 11-11) and rubys' #3702 too, untouched since 10-21. #3706 changes
  `CSS.xpath_for` to skip `SelectorCache` outside the main Ractor, which is the same lines NK2 would touch.
  Outside merges continue (bardrop #3781 in `css/` on 11-21, Priyank-gouda678 #3757 on 11-04), and about ten
  outside PRs from November are open. #3788 (wozhenbang2004) changes `xpath_for`'s option handling.
* **ruby/uri** does not take outside PRs in practice. Every merge since 2026-03-16 is a maintainer's own (hsbt,
  mame's #271 on 11-25, olleolleolle) or Dependabot's; the last outside merge is y-yagi's #209 (03-16). About 30
  outside PRs are open, OskarEichler's 13 since 08-27 and czj's #268/#269 since 11-10. None touches
  `decode_www_form_component`: #253 and #264 change MailTo callers of it.
* **New:** Rails itself calls `URI.decode_www_form_component` for every query string and urlencoded form body key
  and value (`ActionDispatch::QueryParser.each_pair`, since 8.0, unchanged on 8.1.4.1 and main). So UR1 reaches every
  Rails request with parameters even after rack#2557 merges.

### UR1

Two variants, as measurement patches on `URI` ([`req/ur1_copy.rb`](../../bench/upstream/outside_leads/req/ur1_copy.rb),
[`req/ur1_cgi.rb`](../../bench/upstream/outside_leads/req/ur1_cgi.rb)):
* **One copy** (`str.b` then `gsub!`): inside the A/A on every request in both modes, and slower than base for the
  `key` input per call. Dropped.
* **cgi/escape** (`CGI.unescape(str, Encoding::BINARY).force_encoding(enc)` for plain ASCII-compatible Strings, the
  old path otherwise; RK3's shape moved into URI).

Per call, built branch against ruby/uri master (`script/upstream-bench`,
[`body/UR1-4010`](../../bench/upstream/outside_leads/ur1/body/UR1-4010/table.md), A/A ≤ 0.44%, YJIT JIT-flat):

| Input | Interpreter main → branch | YJIT main → branch | Objects |
| --- | ---: | ---: | ---: |
| `hello` | 4,486 → 4,083 (−9.0%) | 3,506 → 2,785 (−20.6%) | 4 → 2 |
| `article%5Btitle%5D` | 13,114 → 5,693 (−56.6%) | 12,307 → 4,349 (−64.7%) | 7 → 1 |
| `Hello+world+from+Rack` | 15,322 → 5,265 (−65.6%) | 14,518 → 3,921 (−73.0%) | 8 → 1 |
| 248-byte cookie value | 18,056 → 10,154 (−43.8%) | 17,272 → 8,810 (−49.0%) | 7 → 1 |

On master `0d399335b7` ([`body/UR1-master`](../../bench/upstream/outside_leads/ur1/body/UR1-master/table.md), A/A ≤
0.21%, ZJIT JIT-flat), interpreter −7.1% / −55.1% / −64.3% / −45.0%, **ZJIT 3,336 → 2,835 (−15.0%), 11,902 → 4,620
(−61.2%), 13,958 → 4,172 (−70.1%), 18,022 → 9,298 (−48.4%)**. The first master run (`UR1-master-aborted`) stopped when
one ZJIT process wrote an empty log; the cause was not established, and four Valgrind batches ran beside it.

Per request, cgi variant as a method overlay:

| Workload | Interpreter 4.0.10 (A/A) | YJIT 4.0.10 (A/A) | ZJIT master (A/A) |
| --- | ---: | ---: | ---: |
| blog PATCH article | −3.11% (0.64%) | **−5.67%** (0.13%) | **−5.19%** (0.39%) |
| blog POST comment | −1.23% (0.44%) | not JIT-flat | not JIT-flat |
| pingcrm PUT contact | −0.78% (0.30%) | **−1.82%** (0.47%) | — |
| blog GET article | −0.35% (0.04%) | −0.95% (0.34%) | −0.64% (0.38%) |
| codetriage GET repo | −0.34% (0.02%) | not JIT-flat | — |
| blog GET articles.json (control) | +0.33% (0.19%), objects equal | +0.02% (0.22%) | +0.10% (0.11%) |

The interpreter JSON control sits just outside its A/A with identical objects. This is the same bimodal allocator
noise RK3 met (`malloc_consolidate`), and it was not rerun with `mxfast=0`. These overlays include Rack's calls
through URI as well as Rails'. Once rack#2557 merges, the Rails part remains: every form field key and value, and
every query parameter.

**Built.** Queue item [UR1](../../bench/upstream/pr-queue/items/UR1.md). Fork branch
`thomasklemm/decode-www-form-component-cgi`, commit `33c17e6` (measured as `a3b201f05b`, which differs only in the RDoc) on ruby/uri master `48cda77031`, no PR. The
differential ([`ur1/diff.rb`](../../bench/upstream/outside_leads/ur1/diff.rb)) ran 300,000 random + 142 fixed cases
on 4.0.10 and master: the only difference is a `BasicObject` with `to_str`, which raises `NoMethodError` either way
with another method name. A singleton `#b` on the input is no longer called. Two test assertions are added, each
caught by its mutant. The suite passes on 4.0.10 and master; fork CI is green on 2.5–4.0, head, JRuby and TruffleRuby.
Reviews (thermos-sol, Astra) and a1.xxlarge timing were started. **ruby/uri is a ruby-org repository and parked:
Thomas decides whether it opens.**

### NK2

nokogiri 1.19.7 (latest release). It is precompiled on 4.0.10; on master it is built against the system libxml2, so
master and 4.0.10 numbers are not comparable. Per call `fragment.css("action-text-attachment")`
([`nk2/micro.sh`](../../bench/upstream/outside_leads/nk2/micro.sh), A/A ≤ 1.3%):

| | base | flat `SelectorCache` key (exact) | joined-XPath cache (L2) |
| --- | ---: | ---: | ---: |
| 4.0.10 interpreter | 108,899 | 98,348 (−9.7%) | 71,431 (−34.4%) |
| 4.0.10 YJIT | 88,724 | 77,714 (−12.4%) | 61,135 (−31.1%) |
| master interpreter | 182,359 | 172,847 (−5.2%) | 146,696 (−19.6%) |
| master ZJIT | 158,253 | 148,660 (−6.1%) | 134,437 (−15.0%) |

Per request, interpreter on 4.0.10: campfire POST message base 42,955,554 (A/A 0.14%), flat key −0.45%, cache
−1.71%; writebook PATCH page 36,660,890 (A/A 0.00%), flat key −0.24%, cache −1.08%. YJIT: no claim, since every
campfire and writebook window compiles 5 blocks even on base. ZJIT on master, campfire: base windows 1/14 and
0/0, so there is no A/A. Against the flat base, the flat key reads −0.83% and the cache −1.90%; this is indicative only.

**Decision: held, not built.** The exact change (flat key) is a fifth to half a percent of an Action Text request.
That is below the relevance bar. The record's conditions still don't hold: #3759 is unreviewed and the Ractor PRs are
open, and #3706 rewrites the `SelectorCache` condition in `CSS.xpath_for`. The larger gain needs a second cache,
which is flavorjones's design call (L2). Next step unchanged: once #3759 is answered and #3706 has landed, ask with
a PR for the flat key, or the joined cache if he wants it.

### Ranking rerun

[`stdrank.rb`](../../bench/upstream/outside_leads/stdrank.rb) `owncallers` over two YJIT passes on 4.0.10
([`stdrank-s1.txt`, `stdrank-s2.txt`, `stdcensus.tar.xz`](data/outside-leads-2026-11-27/)) gives the same order as
on 11-17, with no new owner above 0.4%: `std:uri ← app` 4.46% / 4.73% (campfire's `InlineScriptHashes`),
`gem:sqlite3` 2.9% / 2.8%, `gem:rack ← rails` 2.8% / 2.8%, `concurrent-ruby` 1.5%, `i18n` 1.5%, `nokogiri` 1.5% /
1.2%, `useragent` 1.2%, `cancancan` 1.0%, `std:uri ← gem:rack` 1.0% / 1.0%. `gem:pg` moves between passes (0.65% /
1.41%, the wait in `get_result`). Below the top list, `std:time ← harness` (0.36–0.42%) is the harness, and
`sentry-ruby` (codetriage only, 0.38%) is opt-in instrumentation, as before. Relevance and currency: the census locks pin nokogiri
1.19.4, not the latest 1.19.7. The micro uses 1.19.7, and the code NK2 changes (`SelectorCache`, `xpath_query_from_css_rule`) is the same
in both and on nokogiri main. Every other gem above is maintained and widely used, as on 11-17. No new lead.

### UR1 after review: head `7da6979` (2026-11-27)

thermos-sol found a crash with no hooks involved: released TruffleRuby 40.0.0 crashes on valid GB18030 input through
`a3b201f05b`, because CGI's pure-Ruby `unescape` runs `tr` in the caller's encoding before `b`. Astra found that the
guard (`instance_of?`, `encoding`) added and skipped calls on the input. The rebuilt head keeps the lone-`%` check
and `str.b` and replaces only the `gsub`: `CGI.unescape(str.b, Encoding::BINARY).force_encoding(enc)`, with no
guard. The RDoc is unchanged from base, and a test checks that a GB18030 string decodes to its bytes.
* **Differential:** `diff.rb` (300,000 + 142 cases, also with singleton `#b`) gives 0 differences on 4.0.10, master
  and 3.4.12 with the pure-Ruby CGI. thermos-sol: 0 on 2.5.9, 4.0.10, TruffleRuby 40.0.0 and JRuby 10.1.3.0.
  Astra: 0 in 47,653 value cases per backend; every input-hook case matches base.
* **Remaining boundaries:** a prepend on `CGI.unescape` or on the private `URI._decode_uri_component`, and a
  frozen singleton CGI result.
* **Per call** (`body/UR1-cecaed1-4010` and `-master`, JIT-flat, A/A ≤ 0.62%):

| Input | 4.0.10 interpreter | 4.0.10 YJIT | master ZJIT | Objects |
| --- | ---: | ---: | ---: | ---: |
| `hello` | 4,486 → 3,553 (−20.8%) | 3,506 → 2,678 (−23.6%) | 3,335 → 2,674 (−19.8%) | 4 → 3 |
| `article%5Btitle%5D` | 13,101 → 4,973 (−62.0%) | 12,310 → 4,052 (−67.1%) | 11,903 → 4,247 (−64.3%) | 7 → 2 |
| `Hello+world+from+Rack` | 15,320 → 4,548 (−70.3%) | 14,493 → 3,627 (−75.0%) | 13,996 → 3,793 (−72.9%) | 8 → 2 |
| 248-byte cookie value | 18,059 → 9,283 (−48.6%) | 17,276 → 8,362 (−51.6%) | 18,026 → 9,303 (−48.4%) | 7 → 2 |

* **Per request** (`req/ur1_cgib.rb`, `req-ur1b-*.txt`). Interpreter: blog PATCH −2.88% (A/A 0.07%), pingcrm PUT
  −1.02% (0.24%), blog GET article −0.49% (0.46%), JSON control −0.06% (0.01%, objects equal). YJIT: blog PATCH
  −5.58% (0.51%), GET article −0.95% (0.05%). ZJIT on master: blog PATCH −4.46% (0.92%), GET article −0.95% (0.09%),
  JSON control −0.01% (0.03%). In the ZJIT runs no window compiled an ISEQ or a side exit; master has no
  `invalidation_count`. The earlier request table above prices the guarded `a3b201f05b` and is historical.

**Final UR1 head `c43954f` (2026-11-27).** It has the same tree as `cecaed1`. thermos-sol and Astra both approve it,
with the timing-led body. On a1.xxlarge (`body/UR1-cecaed1-*-time`): interpreter benchmark-ips +40% to +321%, YJIT
wall −35% to −80%, ZJIT master wall −25% to −79%. Every A/A interval contains 0, and every window is JIT-flat. One
difference is accepted and disclosed: on JRuby 9.4, whose `String#b` keeps a String subclass, a subclass input with
nothing to decode returns that subclass. `.to_s` was tried (`545506a`) and dropped, because it doesn't help
SafeBuffer and calls an overridable `to_s`. Waiting for Thomas: ruby/uri is a ruby-org repository and parked.

### UR1 reworked into the shared helper: head `e2d2e21` (2026-11-28)

Thomas found c43954f the wrong shape: it copied the lone-`%` check out of `_decode_uri_component` into the public
method. The new head improves the helper instead. `_decode_uri_component(str, enc)` keeps the check, the `str.b` copy
and `force_encoding(enc)` and yields the BINARY copy to a block. One load-time check (`CGI.respond_to?(:unescapeURIComponent)`
and no `source_location`) picks the decoders: `CGI.unescape` for `decode_www_form_component` and
`CGI.unescapeURIComponent` (keeps `+`) for `decode_uri_component` where cgi/escape has them in C (cgi 0.3.3+, Ruby
3.1.3+) or Java (0.4.1+); otherwise both keep the `gsub` (Ruby 2.5 to 3.1.2, TruffleRuby, JRuby 9.4).
* **Not changed:** `decode_www_form`. It keeps a lone `%` as is, its in-place `gsub!` allocates nothing on plain
  pairs (19 vs 28 objects with CGI), and neither Rack 3.2.9 nor Rails calls it.
* **Fable round:** found the form decoder 2x to 15x slower on TruffleRuby when it always used CGI (Ruby code there);
  the single check fixes it and removes the JRuby 9.4 subclass exception. Polish taken (ASCII_8BIT, comments,
  `assert_instance_of`, body wording); dropping the GB18030 and `%zz` asserts not taken.
* **Exactness:** 0 differences in 28 differential logs for both methods (2.5.9, 3.1.2, 3.4.12, 4.0.10, master, pure
  CGI, JRuby 10.1.3.0, TruffleRuby 40); suite green in 21 runs (native, no C decoder, Ruby decoder) and on JRuby
  9.4.16.0; 14 wrong implementations each caught by a new assertion ([`ur1/rework/`](../../bench/upstream/outside_leads/ur1/rework/)).
* **Per call** on tree 3621b78834 (a1.xxlarge, `body/UR1-d4ce0b0-*-time`): interpreter benchmark-ips +20% to +295%
  (A/A ≤ 7.9%), YJIT wall −29.5% to −80.0%, ZJIT master wall −23.5% to −77.8%, every A/A interval containing 0,
  JIT-flat in 90 processes per case; objects 4–8 down to 2–3.
* **Per request** (`req-ur1c-*.txt`, d09ffb7 tree, same MRI code): blog PATCH YJIT −5.95% (A/A 0.11%), ZJIT
  −5.16% (0.20%); the interpreter −7.97% came with 50 fewer objects than the old head and is unexplained, not used.
* **Reviews:** thermos-sol and Astra approve e2d2e21 and its body, numbers recomputed from raw logs by both.
  Force-pushed to ruby/uri#276, body PATCHed and read back, marked ready on Thomas's authorization. ruby/uri's CI
  awaits first-contributor approval as before; fork CI green on the exact head.
