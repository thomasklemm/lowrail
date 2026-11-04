# Gem request census, round 2: the gems every Rails app loads

Lowrail bet G1, third round. The brief: rank the gems that almost every Rails app loads on the request path (i18n,
rack, rack-session, zeitwerk, concurrent-ruby, tzinfo, mail, globalid, erubi, builder, nokogiri/loofah/
rails-html-sanitizer, marcel, mini_mime, jbuilder, propshaft, importmap-rails, turbo-rails, sprockets and similar) by
request CPU and allocations in the census apps; check each gem's maintainers and our open PRs there before proposing
more; and take small, exact, readable candidates through the full review path. Nothing was opened or posted during the census.

**Result.** Two candidates, opened on 2026-11-04 with Thomas's OK as [rack/rack#2550](https://github.com/rack/rack/pull/2550) (K1) and [sparklemotion/nokogiri#3759](https://github.com/sparklemotion/nokogiri/pull/3759) (N1); see [Open → Gems](contributions.md#gems-1):

| # | Fork branch @ SHA | Per call | Breadth (estimated from the census, not rerun) | L |
| --- | --- | --- | --- | --- |
| K1 | rack: [`thomasklemm/set-cookie-header-single-value`](https://github.com/thomasklemm/rack/tree/thomasklemm/set-cookie-header-single-value) @ `43ceb88370` | `set_cookie_header("k", "value")`: 12 → 9 objects, −14% instructions (interpreter), −13% (YJIT), −15% (ZJIT) | 17 of 20 apps write 0.6–2.0 cookies per request: about −2.5 objects per workload | L1 |
| N1 | nokogiri: [`thomasklemm/fragment-css-children-once`](https://github.com/thomasklemm/nokogiri/tree/thomasklemm/fragment-css-children-once) @ `7ef8b0d431` | `DocumentFragment#css`: 41 → 39 objects and −1.5% instructions on an HTML5 fragment; 79 → 70 and −5.5% on a Loofah fragment | 6 apps call it 1–9 times per request (Campfire, Fizzy, Discourse, Writebook, Loomio, Thinkroom): about −2.6 objects per workload | L0 |

Both are small. The gems' remaining request CPU is mostly required work (rack's parsing, nokogiri's libxml2 and
Gumbo calls, json's generator, tzinfo's Timestamps), call volume behind Rails (concurrent-ruby), or already in
someone's open PR (rack/rack#2519, #2520, #2522). Most of the brief's other gems spend nothing measurable on the
request path: zeitwerk, erubi and builder have no sample and no object in any of the 213 workloads, and mini_mime,
sprockets and marcel are below 0.01% in at most two apps.

**Leave alone for now** (details under [Maintainers](#maintainers-and-our-open-prs)): i18n (four of our PRs open,
no response, one merge in 60 days), tzinfo (our #171 unanswered for 13 days while two older PRs were merged),
importmap-rails (our #336 unanswered for 13 days), mail (84 open PRs, last merge in July), rack-session,
rack-mini-profiler, useragent, builder, turbo-rails and jbuilder (no recent external merges), and propshaft until
our #289 gets a first response.

## Pins and method

* **Ranking data:** the [gem request census](gem-request-census.md) receipts (labels `p`/`p2`, 20 apps, 213
  workloads, Rails main `1105756f42`, Ruby 4.0.7, interpreter and YJIT, 2026-11-03) and the [gem census](gem-census.md)
  allocation receipts (label `g2`, 23 configurations, 251 workloads). Both are one day old, and the apps' gem locks
  have not changed since, so they were not rerun. The census copies are not set up on this orb; app-level effects
  below are estimates from the census call counts, not reruns.
* **No reach threshold:** [`gems_all.rb`](../../bench/upstream/gem_request_census_2/gems_all.rb) lists every gem with
  any sample or object, so the small gems of the brief appear (the first round ranked only gems reaching ≥ 0.1% of
  a workload). [`site_per_app.py`](../../bench/upstream/gem_request_census_2/site_per_app.py) gives per-app objects
  at given gem lines.
* **Maintainers:** [`maintainer_activity.sh`](../../bench/upstream/gem_request_census_2/maintainer_activity.sh) (last
  commit, merges in 60 days, open PRs, recent merges and who merged them), plus `gh pr view` on our open PRs.
* **Gem mains** (2026-11-04): rack `da90464e`, nokogiri `f2bca270`, loofah `bbe007e`, rails-html-sanitizer
  `bac36ce`, tzinfo `1207d60`, concurrent-ruby `cdb9082`, globalid `01a1a1c`, rack-session `06d1b89`, json `1c67ef2`.
* **Per call:** Callgrind instructions with GC disabled, `(Ir(N) − Ir(0)) / N` after a warm-up, base, base again
  (A/A) and branch on one Ruby: [`ir.sh`](../../bench/upstream/gem_request_census/ir.sh) for rack, and
  [`ir_region.sh`](../../bench/upstream/gem_request_census/ir_region.sh) through
  [`nokogiri_ir.sh`](../../bench/upstream/gem_request_census_2/nokogiri_ir.sh) for nokogiri. Rubies: 4.0.9 (the pin)
  interpreter and YJIT; master [`4d2f677b60`](https://github.com/ruby/ruby/commit/4d2f677b609ba15e1006242da9766e0d0dab9d06)
  (built here with `--enable-zjit`) interpreter and ZJIT. CPU time: [`cpu_ns.rb`](../../bench/upstream/gem_request_census_2/cpu_ns.rb),
  best of 7 batches, two alternating rounds.
* **Reviews:** codex is not installed on this orb, so the primary review of each candidate and the adversarial round
  for K1 were subagents of this thread's model, not GPT-6.1 Sol and GPT-6 Astra. Their reports are summarised in
  each candidate's section. A third, separate reviewer checked both drafts against this doc and the raw outputs and
  read them as an outsider; its edits are applied (behavior claims narrowed to what was shown, call counts called
  averages, test coverage named precisely, the Lowrail link pointing at the repository instead of this page).
* **Receipts:** [`data/gem-request-census-2/receipts.tar.xz`](data/gem-request-census-2/receipts.tar.xz): the
  all-gems table, maintainer activity, instruction and CPU outputs, and the rack differential.

## Ranking

Request CPU from the gem request census (`p2`; A/A is `p2 − p` in percentage points), mean over all 213 workloads;
objects per operation from the same profiler; allocation-census objects per workload from `g2`. Apps: apps with any
sample or object in the gem. The census folds Ruby's default gems (uri, erb, cgi, securerandom, …) into their
callers, so rack's share includes the uri decoding it calls.

| # | Gem | Apps | Interp share (A/A) | YJIT share (A/A) | µs/op interp | Objects/op | Allocation census, objects/workload | Maintainers | Disposition |
| ---: | --- | ---: | ---: | ---: | ---: | ---: | ---: | --- | --- |
| 1 | rack | 20 | 2.09% (−0.10) | 2.42% (+0.01) | 606 | 177 | 95.5 | active | **K1**; the rest is required or in rack/rack#2519, #2520, #2522 |
| 2 | mail | 5 | 1.34% (+0.00) | 1.28% (+0.00) | 89 | 76 | 74.5 | unresponsive | leave alone; mailer workloads only |
| 3 | i18n | 20 | 1.27% (−0.01) | 1.07% (+0.03) | 1,122 | 410 | 248.2 | slow | leave alone: our #763–#766 open |
| 4 | concurrent-ruby | 20 | 1.13% (−0.02) | 1.44% (+0.02) | 637 | 5.9 | 6.4 | active | nothing exact: call volume behind Rails |
| 5 | nokogiri | 12 | 0.72% (−0.01) | 0.93% (−0.01) | 416 | 131 | 88.8 | very active | **N1**; the rest is libxml2/Gumbo work |
| 6 | json | 19 | 0.37% (+0.01) | 0.54% (+0.02) | 146 | 44 | 40.5 | very active | required: `Coder#dump` and `parse` are one C call each |
| 7 | useragent | 7 | 0.37% (+0.01) | 0.45% (+0.01) | 66 | 43 | 38.5 | unmaintained | leave alone (first round's lead is for Rails) |
| 8 | tzinfo | 20 | 0.36% (+0.01) | 0.23% (+0.00) | 237 | 84 | 66.8 | stalled for us | leave alone: our #171 unanswered; lead T1 below |
| 9 | globalid | 11 | 0.27% (+0.01) | 0.32% (+0.01) | 83 | 24 | 15.7 | active | mostly URI's generic build and checks (rejected in round 1) |
| 10 | jbuilder | 6 | 0.16% (+0.00) | 0.14% (−0.00) | 93 | 25 | 20.3 | slow | leave alone; `_key`'s `to_s` is the R7-2 case (a 4.1 loss) |
| 11 | logger | 20 | 0.13% (+0.00) | 0.14% (−0.00) | 47 | 0.4 | 0.2 | dependabot only | level checks; required |
| 12 | rack-session | 19 | 0.13% (+0.01) | 0.09% (+0.00) | 34 | 2.4 | 2.3 | slow | leave alone; two objects per request |
| 13 | connection_pool | 11 | 0.12% (+0.01) | 0.10% (+0.00) | 62 | 14 | 13.5 | active | our #225 merged |
| 14 | base64 | 17 | 0.11% (−0.01) | 0.14% (−0.01) | 41 | 11 | 5.8 | dependabot only | required: pack/unpack |
| 15 | turbo-rails | 10 | 0.07% (+0.00) | 0.08% (+0.01) | 30 | 9.7 | 11.0 | slow | leave alone; header reads are one String each |
| 16 | propshaft | 12 | 0.07% (+0.00) | 0.07% (+0.00) | 25 | 11 | 12.3 | active | wait for our #289 |
| 17 | sprockets-rails | 3 | 0.03% | 0.02% | 10 | 3.0 | 2.0 | occasional | nothing |
| 18 | importmap-rails | 6 | 0.03% | 0.03% | 13 | 23 | 27.9 | slow | leave alone: our #336 unanswered |
| 19 | loofah | 7 | 0.02% | 0.03% | 14 | 6.3 | 2.4 | very active | decorating nodes with `extend` is its design |
| 20 | rails-html-sanitizer | 6 | 0.01% | 0.01% | 7.7 | 2.2 | 1.0 | very active | the per-call tag copy is security code (below) |
| 21 | marcel | 1 | 0.01% | 0.01% | 9.6 | 4.6 | 3.4 | occasional | uploads only |
| 22 | sprockets | 2 | 0.00% | 0.00% | 0.3 | 0.0 | – | occasional | nothing |
| 23 | mini_mime | 1 | 0.00% | 0.00% | 0.3 | 0.0 | 0.0 | occasional | nothing |
| – | zeitwerk, erubi, builder | 0 | – | – | – | – | – | active, active, dormant | no request-path work: eager loading, templates compiled once, no feeds in the workloads |

The census drives requests through rack-test, not a server, so Puma's own request handling (header parsing, response
writing) is in none of these numbers. It runs on every request of almost every app; measuring it needs a harness that
goes through the server (a gap, not a lead yet).

## Maintainers and our open PRs

Checked 2026-11-04 with `maintainer_activity.sh` and `gh pr view`. "External" means a PR from someone outside the
maintainers.

| Gem | Activity | Our open PRs | Decision |
| --- | --- | --- | --- |
| i18n | 1 merge in 60 days (#761, 2026-10-24, by radar); 24 open PRs | #763–#766 (2026-11-03), no response, CI awaiting approval; C2, C3 held | no more until the first one moves |
| tzinfo | philr merged #166 (opened 2026-02) on 10-31 and #165 (opened 2025-11) on 11-01; before that, 2022 | #171 (2026-10-22), no response, CI awaiting approval | none; T1 stays a lead |
| importmap-rails | last merge 2026-10-09 | #336 (2026-10-22), no response | none |
| propshaft | three merges on 11-02, one external | #289 (2026-11-03), no response yet | none until #289 is answered (request share 0.07% anyway) |
| rack-mini-profiler | last human merge 2026-04-27 | #670 (2026-11-03) | none |
| mail | last merge 2026-07-01; 84 open PRs | – | none |
| rack-session, turbo-rails, jbuilder, builder, useragent | last merges 2026-09-01, 07-01, 06-01, 2024-06, 2024-12 | – | none |
| rack | 16 merges in 60 days; jeremyevans approved three external performance PRs within days (#2519, #2520, #2522), still unmerged after a month | – | K1 |
| nokogiri | 50 merges in 60 days, external ones the same day (#3755) | – | N1 |
| concurrent-ruby, globalid, json, loofah, rails-html-sanitizer, zeitwerk, erubi | active | – | nothing exact found |

rack's three approved external performance PRs have not been merged yet; K1 targets the gem with the most
request CPU, where reviews come within days.

## K1: rack escapes a single cookie value without wrapping it in an Array

`Rack::Utils.set_cookie_header(key, value)` builds every `Set-Cookie` header. It wrapped a non-Array value in an
Array, mapped it through `escape` and joined the result, so a single value built two Arrays and a String that were
thrown away:

```diff
-      value = [value] unless Array === value
+      escaped = Array === value ? value.map { |v| escape v }.join('&') : escape(value)
 
-      return "#{key}=#{value.map { |v| escape v }.join('&')}#{domain}" \
+      return "#{key}=#{escaped}#{domain}" \
```

**Where it runs.** Rails' cookie jar (`ActionDispatch::Cookies::CookieJar#write` → `Response#set_cookie`), so the
session cookie and every other cookie Rails writes. In the gem census, 17 of 20 apps (18 configurations) reach the
wrapper line, 0.6 to 2.0 times per operation (PingCRM, Redprints, react-starter-kit, Thinkroom, Hackatime, Writebook,
Flow ≥ 1.6), 0.84 per workload over all 251. At three objects per call that is about −2.5 objects per workload.
rack 3.2.6–3.2.8 (the apps' locks) and main have the same lines.

**Exactness.** Joining a one-element Array of a String returns a copy of that String with the same encoding, so the
header is the same for every value, and `escape` runs on the same receiver with the same argument. Checked:

* [`rack_diff.rb`](../../bench/upstream/gem_request_census_2/rack_diff.rb): 26 values (String, frozen, binary,
  invalid UTF-8, nil, false, Integer, Symbol, Arrays, nested, empty, an Array subclass with its own `map`, a String
  subclass with its own `to_s`, objects with `to_s`/`to_str`/`to_ary`, a singleton `to_s`, Hash values with every
  attribute, an invalid `same_site`), plus `delete_set_cookie_header`, `set_cookie_header!` and a Symbol key: same
  header, encoding, frozenness, exceptions and conversion calls on base and branch.
* The primary review repeated this with BasicObject, `method_missing`, prepends, a class that includes
  `Rack::Utils` with its own `escape`, UTF-16LE and Latin-1 values, CRLF and `;` injection attempts, and on master
  with low-threshold YJIT and ZJIT: identical.
* **The one difference** (found by the primary review): an override of `Rack::Utils.escape` that returns something
  other than a String. `join` converted it with `to_str` or `to_ary` first; interpolation calls `to_s`. The stock
  `escape` (`URI.encode_www_form_component`) always returns a String, so this needs a monkeypatch that breaks
  `escape`'s contract. Accepted, like other overrides of a method to return the wrong type.
* **Suite:** 2,572 runs, 0 failures. Both branches of the new ternary are covered by the existing assertions.
  The review found that nothing in the suite checked that cookie values are escaped at all (a mutant that skips
  `escape` passed), so the commit adds two assertions: a single value with a space, `;` and CRLF, plain and from a
  Hash.

**Per call** (`rack_setup.rb`; single value `"value"`, and a session-style Hash with `path`, `httponly`, `same_site`):

| Callgrind instructions | Base (A/A) | Branch | Change |
| --- | ---: | ---: | ---: |
| single value, 4.0.9 interpreter | 15,806 / 15,819 | 13,585 | −14.1% |
| single value, 4.0.9 YJIT | 12,359 / 12,352 | 10,758 | −12.9% |
| single value, master interpreter | 14,945 / 14,935 | 12,866 | −13.9% |
| single value, master ZJIT | 11,088 / 11,034 | 9,453 | −14.5% |
| session Hash, 4.0.9 interpreter | 35,733 / 35,743 | 33,469 | −6.4% |
| session Hash, 4.0.9 YJIT | 32,001 / 32,006 | 30,421 | −4.9% |
| session Hash, master interpreter | 34,716 / 34,718 | 32,637 | −6.0% |
| session Hash, master ZJIT | 31,116 / 30,978 | 29,431 | −5.2% |

CPU, 4.0.9, best of 7, two rounds: single value 1.92 / 1.92 → 1.58 / 1.60 µs (interpreter), 1.61 / 1.61 → 1.37 /
1.41 µs (YJIT); session Hash 3.89 / 3.93 → 3.53 / 3.59 µs, 3.55 / 3.55 → 3.35 / 3.30 µs. Objects: single value
12 → 9, session Hash 19 → 16, Array value 16 → 16.

**Reviews.** Primary (correctness and maintainability): approve-with-nits on both. The nits were applied: the
escaped value has its own name instead of reassigning `value`, the CHANGELOG line is a performance note, and the
escaping assertions were added. Readability **L1** (a ternary where two statements were). Because cookie escaping
is a security boundary, an adversarial round followed: see [K1 adversarial round](#k1-adversarial-round).

**Interlocks.** rack/rack#2454 (open since 2026-04, "Fix '+' Encoding/Decoding in the cookie value", jeremyevans
asked for more) rewrites the same return line; whichever merges second needs a one-line rebase.

### K1 adversarial round

A second reviewer tried to break "same header, every value escaped as before" on 4.0.9 and on master with
low-threshold ZJIT and YJIT, base and branch in separate processes. Every input reached the header as the same
escaped bytes: encodings from binary to UTF-16LE, UTF-32BE, Shift_JIS and ISO-2022-JP, CRLF and `;` in values, an
800 KB value, recursive and mutated Arrays, Hash subclasses, a class that includes `Rack::Utils` with its own
`escape`, `$,`/`$;`, 8 threads × 200 calls with `Thread.pass` inside `escape`, fibers, and every rack caller of the
line. Two differences, neither a security one, both because the value is now escaped before the interpolation starts:

* **Order against the key's `to_s`.** Base converted the key, then escaped the value; the branch escapes the value
  first. Only a key that is not a String runs code there: a Symbol with a redefined `Symbol#to_s`, or a key object
  that defines its own `=~` to pass the key check. If both raise, the other exception wins; if the key's `to_s`
  mutates the value, the branch escapes the value as it was. Accepted: core method redefinition, or a key class that
  imitates a String. The value is fully escaped either way.
* **Backtraces.** For a single value, `escape` no longer runs inside `Array#map`, so the `block in` and `Array#map`
  frames are gone from backtraces and from `caller_locations` in an overridden `escape`. Same exception class and
  message. Accepted: backtrace shape is not behavior.

Keeping the old order would need the conditional inside the interpolation, which reads worse; not done. The reviewer
also noted, on base and branch alike, that a value whose `to_s` mutates a String key after the key check puts the
mutated key into the header; that is outside this change.

### Draft (rack/rack)

> **Escape a single cookie value without wrapping it in an Array**
>
> `Rack::Utils.set_cookie_header` wraps a cookie value that is not an Array in a one-element Array, maps it through
> `escape` and joins the result. So every `Set-Cookie` header with a single value, which is the usual case, builds
> two Arrays and a String that are thrown away. With the stock `escape`, the header is the same for every value.
> Only unusual code could notice: an `escape` override that returns a non-String is now converted with `to_s`
> (`join` tried `to_str` and `to_ary` first), a non-String key's `to_s` now runs after the value is escaped instead
> of before, and `Array#map` no longer appears in `escape`'s backtrace.
>
> | One call | Before | After |
> | --- | ---: | ---: |
> | `set_cookie_header("k", "value")`, Ruby 4.0.9 | 15.8k instructions, 1.92 µs, 12 objects | 13.6k, 1.59 µs, 9 objects |
> | same, YJIT | 12.4k instructions, 1.61 µs | 10.8k, 1.39 µs |
> | same, Ruby master (4d2f677b60) with ZJIT | 11.1k instructions | 9.5k |
> | session cookie with `path`, `httponly`, `same_site`, Ruby 4.0.9 | 35.7k instructions, 19 objects | 33.5k, 16 objects |
>
> Instructions are Callgrind counts per call; two runs of the unchanged code differ by less than 0.5%. Times are the
> best of seven batches, averaged over two rounds. Rails writes its session cookie and every other cookie through
> this method; in 17 of the 20 open-source Rails apps I profile, requests write 0.6 to 2 cookies on average. I found
> it in a census of gem allocations in those apps with [Lowrail](https://github.com/thomasklemm/lowrail), my research
> project. No test checked that a cookie value is escaped, so I added two assertions.

On opening, add the PR link to the CHANGELOG line.

## N1: nokogiri searches a fragment's children once in `DocumentFragment#css`

`DocumentFragment#css` called `children` twice on a non-empty fragment, once for `children.any?` and once to run the
search. Each call builds a new NodeSet and runs the document's decorators on it; on a Loofah document that means
`extend`ing the NodeSet with `Loofah::ScrubBehavior::NodeSet`, which creates a singleton class.

```diff
       def css(*args)
-        if children.any?
-          children.css(*args) # 'children' is a smell here
+        nodes = children # 'children' is a smell here
+        if nodes.any?
+          nodes.css(*args)
         else
           NodeSet.new(document)
         end
```

**Where it runs.** Action Text searches its fragments this way when it renders rich text (`ActionText::Fragment#find_all`
→ `source.css`), and so does any code that calls `css` on an HTML fragment (Discourse's post processing). In the gem
census, `document_fragment.rb:175` allocates the second NodeSet and the splat Array of each call: Campfire 18.2
objects per workload (about 9 calls), Fizzy 10.3 (5), Discourse 8.7 (4), Writebook 5.0, Thinkroom 2.0, Loomio 1.9.
At two objects per call that is about −2.6 objects per workload over all 251. nokogiri 1.19.4–1.19.7 and main have
the same method.

**Exactness.** The search runs on the same children, in the same order, with the same arguments; the empty case is
unchanged. The primary review compared base and branch on XML, HTML4, HTML5 and Loofah (HTML4/HTML5) fragments,
several selectors, namespace bindings, `slop!`, `at_css` and `search`, a custom handler that mutates the fragment
during the search, an invalid selector on empty and non-empty fragments, and 50 `GC.compact` rounds plus
`GC.stress`: identical results, classes, documents and decorations. The differences it could build all need a hook
with side effects on the call that is skipped: a decorator whose `extended` hook counts or mutates, a subclass whose
`children` returns something different on the second call, or a NodeSet `any?` that mutates its receiver. Neither
nokogiri nor Loofah defines such a hook. Accepted, as overrides of public methods with side effects.
JRuby shares this Ruby method, and its `children` also builds a new NodeSet per call (read, not run).

* **Suite:** 2,973 runs, 0 failures, 47 skips on base and branch (Ruby 4.0.9, system libxml2 2.9.14). standardrb
  reports no new offense.

**Per call** (`fragment.css("action-text-attachment")` on an Action Text-like fragment,
[`nokogiri_setup.rb`](../../bench/upstream/gem_request_census_2/nokogiri_setup.rb); nokogiri main built against system
libxml2 2.9.14; Callgrind instructions):

| | Base (A/A) | Branch | Change |
| --- | ---: | ---: | ---: |
| HTML5 fragment, 4.0.9 interpreter | 231,815 / 231,559 | 228,239 | −1.5% |
| HTML5 fragment, 4.0.9 YJIT | 208,803 / 209,085 | 205,700 | −1.5% |
| HTML5 fragment, master interpreter | 243,114 / 243,443 | 240,282 | −1.2% |
| HTML5 fragment, master ZJIT | 217,543 / 217,350 | 214,564 | −1.3% |
| Loofah fragment, 4.0.9 interpreter | 327,647 / 326,865 | 309,420 | −5.5% |
| Loofah fragment, 4.0.9 YJIT | 302,802 / 302,200 | 286,063 | −5.4% |
| Loofah fragment, master interpreter | 346,611 / 346,586 | 327,528 | −5.5% |
| Loofah fragment, master ZJIT | 326,031 / 325,963 | 306,985 | −5.8% |

Objects (nokogiri 1.19.7 with the same file change): HTML5 fragment 41 → 39, Loofah fragment 79 → 70. CPU time was
within its run-to-run spread (about 5% while other work ran on the orb), so there is no time claim.

**Reviews.** Primary (correctness and maintainability): approve / approve-with-nits; the nit (the comment sat on a
line without `children`) was applied. Readability **L0**. Not critical (no escaping, caching or state), so no
adversarial round.

### Draft (sparklemotion/nokogiri, in its PR template)

> **Call `children` once in `DocumentFragment#css`**
>
> **What problem is this PR intended to solve?**
>
> `DocumentFragment#css` calls `children` twice when the fragment is not empty: once for `children.any?` and once
> to run the search. Each call builds a new NodeSet and passes it through the document's decorators, and the first
> one is thrown away. On a Loofah document, decorating the NodeSet extends it with `Loofah::ScrubBehavior::NodeSet`,
> which creates a singleton class and costs more than the NodeSet itself. Keeping the first NodeSet saves 1.5% of the
> instructions of a search on an HTML5 fragment and 5.5% on a Loofah one.
>
> | `fragment.css("action-text-attachment")` | Before | After |
> | --- | ---: | ---: |
> | HTML5 fragment, Ruby 4.0.9 | 231.7k instructions, 41 objects | 228.2k, 39 objects |
> | HTML5 fragment, YJIT | 208.9k instructions | 205.7k |
> | Loofah HTML5 fragment, Ruby 4.0.9 | 327.3k instructions, 79 objects | 309.4k, 70 objects |
> | Loofah HTML5 fragment, YJIT | 302.5k instructions | 286.1k |
>
> Instructions are Callgrind counts per call with system libxml2 2.9.14; two runs of the unchanged code differ by
> less than 0.3%. Objects were counted on 1.19.7 with the same change. Action Text calls this when it renders rich
> text, and Discourse in its post processing: in six of the open-source Rails apps I profile, that is about one to
> nine calls per request on average. I found it in a census of gem allocations in those apps with
> [Lowrail](https://github.com/thomasklemm/lowrail), my research project.
>
> **Have you included adequate test coverage?**
>
> The result is the same; only a decorator or `children` override with side effects would notice that it runs once
> instead of twice. Existing tests cover both branches: `css` on non-empty XML fragments, `at_css` on HTML5
> fragments, and an empty HTML4 fragment. The suite passes on CRuby 4.0.9 with system libxml2 2.9.14.
>
> **Does this change affect the behavior of either the C or the Java implementations?**
>
> No. It is Ruby code that both use, and on JRuby `XmlNode#children` also builds and decorates a new NodeSet on
> every call (I read the Java source; I did not run it on JRuby).

## Leads and rejections

* **T1, tzinfo: the UTC zone builds a new period per lookup** (18 apps; 2.8 + 2.6 objects per workload).
  `ConstantOffsetDataTimezoneInfo#period_for` returns `OffsetTimezonePeriod.new(@constant_offset)` on every call,
  and `periods_for_local` wraps a new one in a new Array. "UTC", the Rails default zone, is such a zone, so every
  `TimeWithZone` period lookup in most apps builds one. Keeping one period per info object would remove it, but it
  is memoization of an object that `Timezone#period_for` returns to callers (identity and singleton methods become
  shared), so it is a critical change, and tzinfo has not answered #171 in 13 days. Not built, not measured per call.
* **rack `clean_path_info`** (16 apps, 8 objects per workload via `ActionDispatch::Static`): a fast path for already
  clean paths would remove the split and join, but it is path-traversal code, and ioquatix's own rack/rack#2302 and
  jeremyevans's #2458 change the same area. Not built.
* **rack `set_cookie_header`'s `key =~ VALID_COOKIE_KEY`** (one MatchData per cookie): `match?` would save it, but it
  converts a non-String key with `to_str` where base raised, and raises a different exception for an Integer key. Left
  out of K1.
* **nokogiri `extract_params`'s `hashes.reverse`** (9 apps, 1.7 objects per workload): `reverse!` saves one Array
  per `css`/`xpath`/`search` (19 → 18 objects for `doc.css("li")`), but `css` instructions moved by 0.35% against an
  A/A of 0.16%, too close to call. Not built.
* **nokogiri CSS-to-XPath per call** (8 apps, about 3 objects each for the visitor, its config Hash and the cache
  key): caching the joined XPath per selector and document type would need a new cache (L2).
* **Loofah decorates every node and NodeSet with `extend`** (7 apps): one singleton class per decorated object. It is
  Loofah's design; changing it is not small.
* **rails-html-sanitizer `PermitScrubber#tags=`** copies the allowed-tags Set on every `sanitize` call with default
  tags, because `validate!` may delete entries. Skipping the copy when nothing needs deleting touches the code of
  three security fixes. Not built.
* **concurrent-ruby `Map#[]`, `#fetch`, `#compute_if_absent`** (20 apps, 0.8% together): one or two Ruby frames over
  `Hash#[]`/`#fetch`; the time is the hashing of Rails' cache keys. Nothing to remove in the gem.
* **globalid `set_model_components`**: `reject!` instead of `reject` saves one Array per GID (0.8 per workload); the
  rest of `URI::GID.build` is URI's generic build and validation. Too small to open alone.
* **jbuilder `_key`**: `Symbol#to_s` per key; `Symbol#name` would save it on 4.0 but costs more on Ruby master (the
  R7-2 finding in [rails-r7-queue](rails-r7-queue.md)).
* **turbo-rails** `request.headers["Turbo-Frame"]` and `["X-Turbo-Request-Id"]`: one String per request each; the
  gem's maintainers have not merged an external PR since July.
