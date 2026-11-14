---
id: AB1
repo: rails/rails
kind: perf
area: Action Controller, allow_browser
reviewer: byroot
branch: thomasklemm/allow-browser-verdict-cache
head: "207a7827a76c3f653662e67072c67a261c7071ba"
base: main
built_on: "50c54eed06"
depends_on: []
stacked_on:
alternative_of:
impact: "allow_browser is 0.5-3% of a request in the 3 of 5 profiled apps that use it (Rails 8 default); benchmark-ips 2.1x on a bare controller request (YJIT, best of 5, A/A +1.7%); Callgrind -9.5%/-12.1% Ir on a small JSON request, -2.7%/-3.6% on an HTML page"
rank: 13
risky: false
state: built
pr:
note: "P-MAP top candidate (docs/upstream/p-map.md). ips raw: docs/upstream/data/p-map/ab1-ips.txt (core 3, best of 5; interp best 4,836 -> 7,646 i/s, A/A -3.4%). Callgrind A/A within 0.21%; Fizzy card -0.35% interp; Fizzy YJIT cohort rejected (not JIT-flat)"
passes: []
---

# Keep allow_browser's verdict per user agent for named version sets

`allow_browser versions: :modern`, which the generated `ApplicationController` calls, parses the user agent with
UserAgent on every request. In real apps that use it, that is 0.5 to 3 percent of a request.

For a named set the verdict depends only on the user agent string, so it is now kept per user agent and set, in a
per-Ractor `Concurrent::Map`. The user agent comes from the client, so the map holds at most 1,000 user agents of at
most 512 bytes and is cleared when full. Longer user agents and version Hashes are checked on every request as
before, and a blocked request still instruments and runs the block.

```ruby
require "action_controller"
require "benchmark/ips"

class PagesController < ActionController::Base
  allow_browser versions: :modern

  def show = head(:ok)
end

app = PagesController.action(:show)
user_agent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"

Benchmark.ips do |x|
  x.report("request with allow_browser") { app.call(Rack::MockRequest.env_for("/", "HTTP_USER_AGENT" => user_agent)) }
end
```

```
ruby 4.0.9 (2026-10-23 revision 3e93b23afc) +YJIT +PRISM [x86_64-linux]

before: request with allow_browser     10.032k (± 4.0%) i/s   (99.69 μs/i) -     50.800k in   5.064018s
after:  request with allow_browser     21.214k (± 4.6%) i/s   (47.14 μs/i) -    107.996k in   5.090698s
```

In a small blog app's full request (`GET /articles/:id.json`), it is 161 fewer objects and 9 to 12 percent fewer
instructions.
