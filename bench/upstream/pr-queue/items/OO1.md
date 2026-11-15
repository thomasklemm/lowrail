---
id: OO1
repo: rails/rails
kind: perf
area: Active Support, OrderedOptions
reviewer: "amatsuda (InheritableOptions reads, #59105 and #59091)"
branch: thomasklemm/ordered-options-public-get
head: "b44663e7e9851ecf9ba87561d264f2729b152228"
base: main
built_on: "8217632cf8"
depends_on: []
stacked_on:
alternative_of:
impact: "Every read of a key an InheritableOptions doesn't hold itself (controller and view config chains): about 21 per railsbench request on Rails 8.1.1 (41.8k per 2,000-request iteration), 25 on main. Callgrind Ir per read through two levels, Ruby 4.0.9: no JIT 3,822 -> 3,343 (-12.5%, A/A +0.05%), YJIT 2,202 -> 2,102 (-4.5%, A/A -0.01%); master ZJIT 3,528 -> 2,276 (-35.5%, A/A +0.02%). Whole railsbench, estimated from the counts: 4.0.9 no JIT about 10 M Ir per iteration (~0.1%), YJIT about 2 M (0.04%), master ZJIT about 26 M (0.5%, 16% of the ZJIT-YJIT gap)."
rank: 40
risky: false
state: held
pr:
note: "Parked idea, held (both reviews: the code is exact and L0, but whole requests don't move: railsbench 4.0.9 -0.15% Ir without JIT, -0.02% under YJIT inside A/A; below the rails/rails opening bar). Z13 Rails-side lead (docs/upstream/zjit-yjit-gap.md, protected sends): ZJIT falls back on every protected send with an explicit receiver (SendNotOptimizedNeedPermission; Shopify/ruby#1109 open, unassigned), so under master ZJIT the read is -35% Ir. Wins on 4.0.9 by itself per call (-12.5% no JIT, -4.5% YJIT, both reviewers reproduced it). b44663e7e9 is 715436d3b1 with the commit message rewritten after both reviews (trailer removed, 'about half the cost', seven reads / 21 calls through three levels, the behaviour change named); the tree is unchanged, so the code passes on 715436d3b1 stand for the code. The body below is fixed the same way; it needs a benchmark-ips before/after in the project's format and a confirm pass before it could open."
passes:
  - {reviewer: opus, head: "715436d3b19758c8338777e31a92f1f788d46fb0", orb: T-01a1df46-d5d8-7266-8fdf-0f168c4e9de5, date: 2026-11-15, verdict: changes, open: "Code exact for every read path, readability L0 (one deleted line, no comment added, line 106's comment still accurate). Must-fix: (1) the commit carried an Amp-Thread-ID trailer, already on the fork; (2) 'about twenty reads per request' counts calls, not reads: railsbench (Rails 8.1, 4.0.9) makes 20.9 protected _get calls per request from 7.0 reads (logger x2, csrf_token_storage_strategy x2, allow_forgery_protection, request_forgery_protection_token, per_form_csrf_tokens), each through 3 levels; a 10-row scaffold page with link_to and image_tag made 32 reads and 120 calls at 3-4 levels (the view's config adds one); 'while profiling a few Rails apps' has only railsbench behind it; 'two or three such levels' should be 'three or four'; (3) opening bar: whole railsbench under Callgrind, 4.0.9, Ir per request no JIT 4,014.1k / A/A 3,802.6k (5.3%) / branch 4,010.2k, YJIT 2,644.9k / 2,758.3k (4.3%) / 2,737.9k; expected effect ~5.0k Ir per request without JIT (0.12%) and ~1k under YJIT (0.04%), so hold, don't open. Nits: the protected check is about half the call's cost in the interpreter (protected 519 Ir above the loop, public 280), not 'most'; the body's 'more than the hash lookup' holds (check 239 Ir, plain Hash#[] 144); put the behaviour change in the commit message; api.rubyonrails.org already lists _get as public (as an alias of OrderedOptions#[], wrongly). Micro on 4.0.9, Ir per read: no JIT 3,818.5 / 3,819.7 -> 3,337.5 / 3,339.7 (-12.6%), YJIT 2,200.4 / 2,200.3 -> 2,104.3 / 2,101.0 (-4.4%); master ZJIT not reproduced (no master build in a 2-core orb). Probe, 6 parent kinds x 4 depths plus Configurable class -> subclass -> instance: [], string keys, dig, fetch, accessors, x!, key?, to_h, respond_to?(:_get), dup, frozen chains, late parent writes, compiled accessors, duck parent and singleton private :_get identical; differences only for external _get calls and introspection (public_send, public_method, public_methods, protected_methods) and a contrived singleton protected :_get on a parent; no Rails caller calls _get from outside; ordered_options_test 35/106 and configurable_test 10/35 green on base and branch."}
  - {reviewer: claude-code, head: "715436d3b19758c8338777e31a92f1f788d46fb0", orb: T-01a1df46-8b92-73f8-b0e5-42629f57434b, date: 2026-11-15, verdict: changes, open: "Code exact, L0. Must-fix: (1) Amp-Thread-ID trailer on the commit; (2) 'most of the cost of the call' is false: protected 518 Ir per _get call, public 278, the check 240 Ir (~46%); the body's 'more than the hash lookup' holds (rb_hash_aref 92 Ir); (3) 'about twenty reads per request': railsbench (Rails 8.1, 4.0.9, 2,000 requests, TracePoint) makes 41,805 _get calls from 13,935 reads, each through exactly 3 levels, so ~7 reads per request; 'a few Rails apps' unbacked; (4) the commit message doesn't say why it is safe, and the body should lead with benchmark-ips before/after output in the project's format if it opens. Nit: name the external-_get boundary in a clause. Probe, 687 cases on 4.0.9 interpreter and YJIT: every read identical ([] Symbol/String keys, accessors, !, dig, fetch, values_at, key?, to_h, 3- and 5-level chains, subclasses, [] overrides, subclass/prepended/singleton _get overrides public/protected/private, frozen leaf and parent, Hash and nil parents, Configurable compiled readers, respond_to?(:_get)); only external _get calls and introspection (public_send, public_method, public_methods, protected_methods, public_method_defined?) change. ordered_options_test 35 and configurable_test 10 runs green on base and head. Micro on 4.0.9, Ir per read: no JIT 3,834.7 [3,834.8] -> 3,358.8 [3,354.9] (-12.5%), YJIT 2,216.1 [2,218.5] -> 2,118.8 [2,115.4] (-4.5%). Whole railsbench iteration, 4.0.9, GC off, runtime public :_get: interpreter 7,050.0 / 7,055.1 M -> 7,042.9 / 7,041.5 M (-0.15%, A/A <= 0.07%), YJIT 4,442.8 / 4,437.4 -> 4,441.9 / 4,436.5 M (-0.02%, inside the 0.12% A/A). Recommends held (parked idea). Raw: that orb's .amp/in/orb-backup/ordered-options-review/."}
---

# Make `OrderedOptions#_get` public

`InheritableOptions` reads a key it doesn't hold from its parent with `@parent._get(k)`. Because `_get` is
protected, each of these calls first checks that the caller is an `OrderedOptions`, which costs more than the hash
lookup behind it. A controller's `config` falls through three such levels on each read; on railsbench that is about
seven reads, or 21 calls, per request.

Making `_get` public drops the check. Reads through `[]`, `dig`, `fetch` and the accessors return the same values;
only a call to `_get` from outside an `OrderedOptions` now reaches `Hash#[]` instead of `method_missing`.

Callgrind instructions per read through two levels, Ruby 4.0:

| | main | this branch |
| --- | ---: | ---: |
| no JIT | 3,822 | 3,343 |
| YJIT | 2,202 | 2,102 |
