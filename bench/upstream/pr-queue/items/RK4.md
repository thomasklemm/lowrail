---
id: RK4
repo: rack/rack
fork: thomasklemm/rack
kind: perf
area: Request#split_header, Request#scheme
reviewer: jeremyevans
branch: thomasklemm/split-header-shared-empty
head: "84a59d35bd"
base: main
built_on: "b432304e8d"
tracker: [rack/rack#2520]
depends_on: []
stacked_on:
alternative_of:
evidence: [bench/upstream/rk4/README.md]
impact: "Campfire 365 of 20,924 objects per request (1.74%), all empty Arrays from split_header(nil) in Request#scheme under base_url; the same objects are removed by linyiru's open, approved rack/rack#2520, so nothing is left for a PR of ours"
rank:
risky: false
state: superseded
pr:
note: "2026-11-25: stopped before measurement. Lead from docs/upstream/profile-hotlines-2026-11-25.md #27. The hot allocation is the empty Array that split_header returns for a missing X-Forwarded-SSL/-Proto/-Scheme header on every Request#scheme call (3 per call on main, which added :ssl to x_forwarded_proto_priority in 85a7ae09; 2 on 3.2.x and 3.1.x), reached in Campfire through Rack's base_url once per importmap entry. linyiru's rack/rack#2520 (open since 2026-10-06, approved by jeremyevans 2026-10-07 on 06c11bea80, conflicts with main only in CHANGELOG.md) skips split_header when the header is missing and makes ssl? call scheme once; on the probe it takes scheme 3 -> 0 and base_url 15 -> 9 objects, the same as our branch. Collaborative rule (DECISIONS, Upstream etiquette): no competing PR. What #2520 leaves (strip + split for a present header, about 3 objects per forwarded header behind a proxy; ip's REMOTE_ADDR, memoized per request) cannot drop strip exactly (strip also removes NUL, LF, VT, FF, CR) and is below the 2% bar. Branch kept on the fork as a record; no fork PR, nothing upstream. No overlap with RACK2550 (Set-Cookie) or RK3 (escape/unescape). Suite on the branch: rake test, Ruby 4.0.9, 1309 runs, 6394 assertions, 0 failures, 2 skips. No script/upstream-bench or Campfire lowrail-profile run: both would price #2520's change, not ours."
ownership: {date: 2026-11-25, checked: ["open PRs naming split_header that change lib/rack/request.rb","rack/rack#2520 and what references it"], hits: ["tracker: rack/rack#2520 (open): Performance improvements in Request, CommonLogger, Response and the multipart parser"]}
passes: []
---

# Return a shared empty Array from split_header for a missing header

Not posted; superseded by rack/rack#2520 before a body was written.

## For Thomas

Every `request.scheme` (and so `ssl?` and `base_url`) asks for each X-Forwarded scheme header and, when it is
missing, `split_header(nil)` builds a new empty Array. Our branch returns one frozen empty Array instead.
linyiru's approved PR #2520 already avoids the call when the header is missing, which removes exactly the same
objects, so we leave it to that PR.
