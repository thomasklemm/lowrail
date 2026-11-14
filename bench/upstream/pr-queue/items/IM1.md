---
id: IM1
repo: rails/importmap-rails
kind: perf
area: importmap tags helper, modulepreload tags
reviewer: "skipkayhil (Ractor-safe map cache), rafaelfranca"
branch: thomasklemm/cache-module-preload-tags
head: "52e2d737898d731e0fa3b29811d2fa9d9f0e89df"
base: main
built_on: "f255e55"
depends_on: []
stacked_on:
alternative_of:
impact: "Every page of every app with importmap-rails (the rails new default) builds a modulepreload tag per preloaded module (7 in a new app) although they are constant without a CSP nonce. Whole request, Callgrind, new app: bare page -10.42% interpreter (A/A +0.12%), -9.47% YJIT (A/A +0.66%); scaffold show -4.68% / -5.19%; index -1.49%, 20-field form -2.14% (interp); 62-64 fewer objects per page. benchmark-ips javascript_importmap_tags 25.2k -> 103.3k i/s (4.1x, YJIT, best of 5, A/A -2.1%). Pages with a nonce unchanged. Lifetime: importmap-rails main and 2.x; runs on every Ruby."
rank: 12
risky: false
state: built
pr:
note: "DEF8 (docs/upstream/rails8-defaults.md). Overlaps our open importmap-rails#336 (IMP336, unanswered since 10-22) in the same helper: both apply, whichever lands second needs a rebase; with IM1 the cached path no longer runs #336's lines on pages without a nonce. The repo is slow (last merge 10-09); IM1 is the second of our PRs there, inside the gem cap of 2. #333 (Early Hints, not ours, no review) also touches javascript_importmap_tags. Probe: bench/upstream/def8/im1_probe.rb, 17 cases identical against main. Suite: 105 runs 0 failures (Rails 8.1.1, Ruby 4.0.9)."
passes: []
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

In the request for that page, that is 62 fewer objects.

---

<sub>Found while measuring the request path of a new Rails app ([record](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/rails8-defaults.md)).</sub>
