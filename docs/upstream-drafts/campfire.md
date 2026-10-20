# Campfire: cache derived importmap CSP locations

**Draft only. Do not publish automatically.** Target is
`basecamp/once-campfire`, not importmap-rails, Propshaft or Rails. Based on
Campfire `af4dd9fd599c65e0e0fc1f614ee469f70156ddf5`.
Local fork: `.corpus/campfire-importmap`, branch `cache-script-locations`.
[Portable patch](campfire.patch); [full investigation and measurements](../passes/importmap.md).

## Issue title

Cached HTML responses still parse 90 import URLs to build one CSP source

## Issue body

On warm production HTML requests, `InlineScriptHashes#script_locations`
parses the resolved importmap JSON and runs `URI.join(request.base_url, url)`
once per import. This runs even when `CachedResponses` serves an existing
page: CSP is computed by a before-action and is not in the cached response
header allowlist.

The pinned app has 90 distinct import URLs in a 7,703-byte importmap. They
all produce the same CSP location (`localhost/assets/` in this benchmark),
but each request still performs 90 joins / 180 URI parses. The full
script-location method was 34.8% inclusive in the earlier four-route warm
HTML profile. This is not caused by importmap-rails resolving assets on every
request: `Importmap::Map#to_json` already caches the JSON, and Propshaft's
production resolver already holds its compiled manifest.

Could we cache the **derived location list**, while continuing to obtain
the current importmap JSON and build each request's policy? A safe key must
contain the complete resolved JSON, effective asset directory, request base
URL and host-with-port. Map object identity, mtime/size, a fixed deployment
host, or a TTL would be insufficient. A bounded process-local store avoids
unbounded host-dependent entries and requires no shared cache/network call.

The attached candidate uses a 1 MiB `ActiveSupport::Cache::MemoryStore`,
with untruncated JSON-encoded keys. It keeps the original last-asset-directory
rule, exact external-URL fallback, script hashes and worker source. It does
not widen `script-src` to the origin, memoize a whole policy, introduce
nonces, cache request/controller objects, or bypass the importmap API.

Ruby 4.0.7 +YJIT micro: full location calculation **1265.45 → 26.56 µs**,
**5335.9 → 52 allocations** per call. This is a method micro, not an
end-to-end speed claim. The controlled interpreter instruction experiment
observed **19.766M → 6.151M instructions/request**, but **failed A/A**:
off/off −8.17%, interval −8.89…−0.054%, outside ±0.5%. These instruction
results are retained as diagnostics, not an accepted speedup. The native
YJIT request experiment observed 3219.84 → 1518.32 µs/request (paired CPU
−53.85%), but **also failed A/A**: its off/off CPU interval is
−10.07…+15.16%, outside ±2%. All five cohorts are retained. Neither experiment
passes the request-performance gate. A fresh room-only profile puts
`script_locations` at 32.4% inclusive (38,892 raw samples), consistent with
the earlier mixed-route finding but not the same sampling workload.

One contract decision needs explicit review: a cache hit reuses a prior
successful URI-derived result rather than rerunning the parser and its
timeouts/hooks. This is an **application-owned caching policy**, not a
transparent compiler optimization. Rails' default regexp timeout remains
unchanged. If the application requires every parser invocation to remain
observable, do not adopt this cache. Nothing here claims that ordinary short
asset URLs time out with the default 1-second setting.

## PR title

Cache CSP script locations by resolved importmap and request origin

## PR body

### Why

The importmap is already resolved/cached by importmap-rails, but Campfire
reparses its URLs on every response, even on page-cache hits. With the
current pins, that means 90 joins for one final asset-directory source.

### Change

- Bound derived-location storage to 1 MiB of process-local memory.
- Key by full importmap JSON, effective assets directory, current base URL
  and host-with-port. JSON encoding keeps component boundaries unambiguous;
  `max_key_size: false` prevents Rails from replacing long keys with a digest.
- Continue resolving via the existing importmap API and constructing the
  request's policy, inline hashes and worker URL normally.
- Preserve fresh cache return values using MemoryStore's normal coder.
  Exceptions do not populate an entry; there is no timer or stat invalidation.

### Tests

`PARALLEL_WORKERS=1 bin/rails test test/integration/content_security_policy_test.rb --seed 41231`:
**12 tests, 1,390 assertions, no failures/errors/skips**. The new warm-page
test checks both the returned policy and the removal of actual URI work
using a TracePoint, not a replacement parser. It fails on unchanged code
with **90 joins instead of 0**. A second test changes a pinned URL from
`one.example.test` to the same-length `two.example.test` and checks that
the old location disappears. Existing cases cover CDN/protocol-relative/
sharded/proc hosts, CDN paths containing `/assets`, relative roots,
non-default ports, uploads, disabled CSP and exact inline hashes.

Full serial non-system suite: **636 tests, 3,869 assertions, zero failures
or errors, two existing libvips skips**. The original 634 test outcomes and
**15,053 ordered same-thread SQL events** match the unchanged app. One
concurrency test has 13 vs 12 other-thread events (advisory); do not describe
this as complete cross-thread SQL equivalence.

A production probe preserves the already-cached HTML and substitutes only
the fork's actual location method, comparing complete body bytes plus
enforcing/report-only CSP on room/messages/sidebar/search. This avoids
mistaking newly randomized CSRF masks in independent renders for a CSP
change. It is not a fresh-render HTML identity claim. No system suite was
run for this patch. See the measurement report for the failed instruction
control and the native request control verdict, rather than claiming a
general request speedup from the micro.

### Review decision

Please review the explicit successful-result cache contract described in
the issue draft. It is appropriate for this application to choose caching;
Lowrail cannot silently impose it on old app versions while promising
unchanged timeout/tracing behavior. No generic gem cache change is proposed.

## Applying the candidate locally

```sh
# Inside an independent Campfire checkout at the pin above:
git apply /absolute/path/to/lowrail/docs/upstream-drafts/campfire.patch
PARALLEL_WORKERS=1 bin/rails test test/integration/content_security_policy_test.rb --seed 41231
PARALLEL_WORKERS=1 bin/rails test --seed 41231
```

Dependencies remain those in Campfire's frozen lockfile: importmap-rails
2.2.2 (`51c1a531327f`), Propshaft 1.3.2 (`dc979db89cd0`), Rails 8.2.0.alpha
(`e3d5c569d217`), URI 1.1.1. Nothing was patched in the shared bundle.
