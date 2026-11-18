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
| 4 | **GQ1**: Warden name caches compare by value | rmosolgo/graphql-ruby; rmosolgo (merged our #5877, #5880, #5881 in 2–3 h; outside merges 2026-11-10 and 11-17) | Zammad replay −0.64% per round; validation −7.5% to −43% (round 2, [graphql-ruby](graphql-ruby.md#gq1-warden-name-caches-compare-by-value-held)) | **no**: documented `.get_field` overrides run once per name instead of once per node | held branch `thomasklemm/warden-name-caches`; a question for rmosolgo first |
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

Branch `thomasklemm/unescape-cgi` on the fork, two commits on rack main `da90464e3f`:
`d85c4b9a42` decodes with `CGI.unescape` (RK3), `6f48723a86` escapes with `CGI.escape` (RK4). Queue item
[RK3](../../bench/upstream/pr-queue/items/RK3.md) (state built, draft title and body). Scripts:
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
