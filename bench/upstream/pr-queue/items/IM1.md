---
id: IM1
repo: rails/importmap-rails
kind: perf
area: importmap tags helper, modulepreload tags
reviewer: "skipkayhil (Ractor-safe map cache), rafaelfranca"
branch: thomasklemm/cache-module-preload-tags
head: "863322e8a1d98da1b460abab019d76e8313cf2a5"
base: main
built_on: "f255e55"
depends_on: []
stacked_on:
alternative_of:
impact: "Every page of every app with importmap-rails (the rails new default) builds a modulepreload tag per preloaded module (7 in a new app) although they are constant without a CSP nonce. Whole request, Callgrind, new app: bare page -10.42% interpreter (A/A +0.12%), -9.47% YJIT (A/A +0.66%); scaffold show -4.68% / -5.19%; index -1.49%, 20-field form -2.14% (interp); 62-64 fewer objects per page. benchmark-ips javascript_importmap_tags 25.2k -> 103.3k i/s (4.1x, YJIT, best of 5, A/A -2.1%). Pages with a nonce unchanged. Lifetime: importmap-rails main and 2.x; runs on every Ruby."
rank: 12
risky: false
state: in-review
pr:
note: "DEF8 (docs/upstream/rails8-defaults.md). Overlaps our open importmap-rails#336 (IMP336, unanswered since 10-22) in the same helper: both apply, whichever lands second needs a rebase; with IM1 the cached path no longer runs #336's lines on pages without a nonce. The repo is slow (last merge 10-09); IM1 is the second of our PRs there, inside the gem cap of 2. #333 (Early Hints, not ours, no review) also touches javascript_importmap_tags. Probe: bench/upstream/def8/im1_probe.rb, 20 cases identical against main (with a false nonce before and after a plain page). Suite: 105 runs 0 failures on 3 seeds (Rails 8.1.1, Ruby 4.0.9). 863322e after the first review: caches only for a nil nonce (52e2d73 leaked nonce=\"false\"), and the new test is claude-code's with a false-nonce step; it fails on 52e2d73, no .dup, the inverted condition, a key without the entry point and a cache outside the map, and passes on main. Numbers measured on 52e2d73; opus measured the fix at -10.54% interp bare page, ips 145.5k vs 146.6k."
passes:
  - {reviewer: claude-code, head: "52e2d737898d731e0fa3b29811d2fa9d9f0e89df", orb: T-01a1dc64-bf9b-767f-a931-99cff8cc12ab, date: 2026-11-15, verdict: changes, open: "Must-fix: the new test lets 4 of 5 plausible wrong implementations pass (no .dup, caching only with a nonce, a key without the entry point, a cache outside the map that pins never clear); replace it with the claude-code test, which fails all five and passes on main (6 runs, 33 assertions). Optional: 62 fewer objects measured 59 per request (the helper call alone 92 -> 30); the public :nodoc: cache_as may draw a request for a dedicated method. Evidence: author and committer Thomas, no trailers, diff --check clean, no added comments; importmap-rails main still f255e55; merge-tree with #336 conflicts in the helper, as the note says; im1_probe.rb (17 cases) and a 38-case extended probe (nonce first, two nonces, empty nonce, String/Symbol/Array entry points in both orders, empty map, append, gsub! and replace on the result, pin added, preload changed, pin_all_from, enable_integrity!, clear_cache, 8 threads x 200 mixed calls with 0 wrong, a Ractor-shareable map) identical on main, branch and a main A/A, with equal class, html_safe, frozen and encoding; rendered home, show, index and new HTML byte-identical; the development FileUpdateChecker sweeper clears both keys; rake test 104 runs main, 105 branch, 0 failures (Rails 8.1.1, Ruby 4.0.9); ips im1_ips.rb (core 1, YJIT, interleaved, best of 5) main 25.9k, A/A 25.6k (-1.3%), branch 100.5k i/s, 3.9x; Callgrind ir.sh interp home -10.64% (A/A -0.18%, -59 objects), show -4.95%, index -1.44%; YJIT home -9.89%, show -5.19%; worst cases within A/A (nonce page, cache cleared every call +2 objects, 100 preloads with a nonce); memory one String per entry point, 500 B for 7 preloads, 9,189 B for 100; prior art none (#176, #266, #329, #333, #334, #336 differ). Did not test a false nonce."}
  - {reviewer: opus, head: "52e2d737898d731e0fa3b29811d2fa9d9f0e89df", orb: T-01a1dc64-c914-71e3-b32d-db2e5e85f50f, date: 2026-11-15, verdict: changes, open: "Must-fix 1 (code): the cache keys on a truthy nonce, but a generator may return false (r.ssl? && ...); main renders nonce=\"false\" on that page only, the head caches it and serves nonce=\"false\" to every later page without a nonce (seen on a real request); cache only when the nonce is nil. Must-fix 2 (tests): no .dup and a key without the entry point pass the suite; add tests for a false nonce, each entry point and appending. With both, 108 runs on 3 seeds; the head fails 4, no-.dup 2, keyless 1. Body, title, message and :nodoc: fine. Evidence: author/committer Thomas, no trailers, diff --check clean; im1_probe.rb 17 cases identical; a wider probe (nonce first, alternating nonces, String/Symbol/Array/nil entry points, pin, re-pin, pin_all_from, enable_integrity!, clear_cache, dev sweeper with a JS file added and removed, five mutations of the result, 8 threads cold cache, duck-typed request) identical except the false nonce; head suite 105 runs (main 104); Callgrind bare page interp 2,794,625 -> 2,499,897 Ir -10.55% (A/A +0.01%), 785 -> 722 objects, fix -10.54%; ips im1_ips.rb (YJIT, core 1, best of 5, interleaved A/A) 37.33k -> 146.6k i/s 3.9x, A/A -0.6%, fix 145.5k; worst cases: cache cleared every call 4.05k -> 4.36k, nonce path +0.64% Ir (A/A +0.04%, 65 objects either way), 0 preloads 1.14M -> 1.78M, 500 preloads 619 -> 2.08M i/s; memory 500 chars (7 modules), 45,889 (500); prior art none caches the tags (#329, #176 differ), #336 (ours) conflicts in merge-tree, #333 merges clean. Not reproduced: YJIT Callgrind and show/index/new rows."}
---

# Cache the modulepreload tags of an entry point

`javascript_importmap_tags` builds a `<link rel="modulepreload">` tag for every preloaded module on every page. A new Rails app preloads seven, and building their tags is about a tenth of the instructions of a request for a page with an empty view, although the tags are the same on every page.

The packages behind the tags are already cached in the map per entry point. When the page has no CSP nonce, the tags now go into the same cache, so they're cleared together when a pin changes or the cache sweeper runs. Each call returns a copy, so appending to the result doesn't change the next page. With a nonce, the tags are built as before.

```ruby
# bin/rails runner in a new app
require "benchmark/ips"

controller = ApplicationController.new
controller.request = ActionDispatch::Request.new(Rack::MockRequest.env_for("https://localhost/"))
view = controller.view_context

Benchmark.ips do |x|
  x.report("javascript_importmap_tags") { view.javascript_importmap_tags }
end
```

```
ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +YJIT +PRISM [x86_64-linux]

before: javascript_importmap_tags     25.167k (± 4.5%) i/s   (39.73 μs/i) -    126.550k in   5.028335s
after:  javascript_importmap_tags    103.331k (± 4.1%) i/s    (9.68 μs/i) -    525.453k in   5.085144s
```

In the request for that page, that is about 60 fewer objects.

---

<sub>Found while measuring the request path of a new Rails app ([record](https://github.com/thomasklemm/lowrail/blob/7b7f24bf8985eed81bcb20aca6157384cde2dab6/docs/upstream/rails8-defaults.md)).</sub>
