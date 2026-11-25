# RK4: rack `Request#split_header` (stopped, superseded by rack/rack#2520)

Lead: [profile-hotlines-2026-11-25](../../../docs/upstream/profile-hotlines-2026-11-25.md) #27, `split_header` in 9 of
12 apps, Campfire 1.74% of request objects.

## Where the objects come from

`split_header(value)` is `value ? value.strip.split(/[, \t]+/) : []`. Its callers are `forwarded_for`,
`forwarded_port`, `forwarded_authority` (only when the header is present), `ip` (`REMOTE_ADDR`, memoized by
`Rack::Request#ip`) and `forwarded_scheme`, which calls it for every entry of `x_forwarded_proto_priority` whose header
is missing. So each `scheme` call on a request without forwarded headers builds one empty Array per entry: 3 on main
(`:ssl` joined the list in 85a7ae09, unreleased), 2 on 3.2.x and 3.1.x. `ssl?` calls `scheme` twice, `base_url` once.

Campfire's capture (`profile_release/2026-11-25/campfire/profiled`, rack 3.2.x, line 693): 365 objects per request at
that line, 659 of 666 requests, mostly Array, 49% from `inline_script_hashes.rb:40` (`request.base_url` per importmap
entry). The test env sends no forwarded headers, so these are the nil branch's empty Arrays.

## Ownership

rack/rack#2520 (linyiru, open since 2026-10-06, approved by jeremyevans on 2026-10-07 at 06c11bea80; conflicts with
main only in CHANGELOG.md) changes `forwarded_scheme` to skip `split_header` when the header is missing and `ssl?` to
call `scheme` once. `script/ownership RK4` records it as the tracker hit. RACK2550 (Set-Cookie) and RK3
(escape/unescape) don't touch these methods.

## Probe

`probe.rb TREE [ENV_KEY VALUE]`: objects per call of `Rack::Request` readers on a `MockRequest` env, Ruby 4.0.9,
[probe-4.0.9.txt](probe-4.0.9.txt). main b432304e8d, #2520 06c11bea80, our branch 84a59d35bd (main plus a frozen
empty Array returned for nil):

| per call | main | #2520 | our branch |
| --- | ---: | ---: | ---: |
| `scheme`, no forwarded headers | 3 | 0 | 0 |
| `ssl?` | 6 | 0 | 0 |
| `base_url` | 15 | 9 | 9 |
| `scheme` with X-Forwarded-Proto: https | 6 | 5 | 5 |

Both remove the same objects, so a PR of ours would compete with an approved one. What #2520 leaves, `strip` and
`split` on a present header, cannot lose `strip` exactly: `strip` also removes NUL, LF, VT, FF and CR, which the split
pattern does not. That is about one String per forwarded header behind a proxy, well under the 2% bar.

Suite on our branch: `bundle exec rake test`, Ruby 4.0.9: 1309 runs, 6394 assertions, 0 failures, 0 errors, 2 skips.
No Callgrind or Campfire lowrail-profile run, since both would measure #2520's effect rather than anything of ours.
