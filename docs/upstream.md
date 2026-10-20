# Upstream findings

Profiling findings that are best fixed in the gem that causes them, so every
user of that gem benefits. Lowrail passes cover apps on older versions; the
upstream fix removes the cause.

| Finding | Measured | Gem / version | Proposed fix | Status |
|---|---|---|---|---|
| `Manifest#digest` re-reads and MD5-hashes the Vite manifest on every call; with a lazy Inertia version proc that is every request | ~279 µs/call; 12.8–15.8 % self per Inertia JSON request (private app, aggregates only). Version computed once at boot: two pages −19 % and −23 %, one within noise (production mode, 5 interleaved pairs) | `rails_vite` 0.3.0 | Memoize the digest outside `Rails.env.local?` like `Manifest#data`; do not cache `"no-manifest"` | [issue #56](https://github.com/skryukov/rails_vite/issues/56), [PR #57](https://github.com/skryukov/rails_vite/pull/57) |
| CSP importmap processing (`InlineScriptHashes#script_locations`) on every cached page | 34.8 % inclusive on Campfire's cached HTML | Campfire / Rails importmap + CSP | Not yet analysed upstream; the memo pass covers one SHA-256 site only | open |
