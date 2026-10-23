# Exact file-digest memo

**Current status: sealed-only.** Suppressed method hooks bypass the digest
certificate even when file bytes are unchanged. Guarded `+digest_memo` and
old/mixed artifacts are refused in full; see the
[audit and current gates](suppressed-hooks.md). Only the separate
[sealed contract](../sealed.md) permits production research, not test mode.
The guarded measurements and commands below are historical.

As of 2026-10-20. Pass name: `digest/file_memo`.

## Boundary and delivery

The pass replaces only `Digest::MD5.file(path).hexdigest` and
`Digest::SHA1.file(path).hexdigest` intrinsics in
`RailsVite::Manifest#digest`/`#watched_files_digest` and
`ViteRuby::Builder#watched_files_digest`/`#file_digest`, where present.
Prism rewrites gem code while preserving line numbers; the existing
compiler/ISeq loader delivers it. Method names, parameters, visibility,
surrounding rescues and remaining gem code are retained. The helper receives
the algorithm and argument exactly once, in original order; an invalid
guard calls `algorithm.file(name).hexdigest`.

There is **no memo for an arbitrary Inertia version proc**. The proc still
runs at every original call. Gem-owned globs, sorting, directory filters,
time windows and existing file-stat caches are unchanged. In particular,
the pass neither strengthens nor weakens vite_ruby's existing mtime/size
cache: only its actually reached SHA1 file call is specialized.

`gem/exe/lowrail-runtime-build` runs the digest builder alongside the selected
runtime builders in one app boot. Rust writes shared `units.json` before
the normal compiler. Gem files get separate units, ledger entries, source
hashes and compiler fingerprints. The environment guard, `LOWRAIL=0`,
`LOWRAIL_UNITS`, `verify --bisect` and bisection denylist remain applicable.
The digest install block follows the memo block; capture/observe hooks are
unchanged.

## What a cache hit proves

Every call reopens the file with **`rb`**, reading to EOF like
`Digest::Instance#file` in **16,384-byte chunks with a reused read buffer**.
Only then are all read bytes compared with the private cache entry.
Complete equality is required for reuse. A Ruby String hash is only an
index: full byte comparison still decides collisions. A filename, stat
tuple or truncated hash is **not** content proof.

A miss hashes that same already-read stream, not a reopened file. Cache
keys, stored bytes and digest results are private snapshots. The stored
result is duplicated/frozen; each hit returns a fresh mutable copy with
the original US-ASCII encoding. A thread switch between reading and cache
insertion therefore cannot associate later file contents with an old digest.

Each unit retains at most **32 entries of up to 1 MiB each**. Larger streams
switch to incremental hashing of the same open file after crossing the
limit and are not cached. These computations, cold misses and failed file
operations do not count as hits. Hits count actual digest reuse; fallbacks
count original-path execution on guard/input refusal.

There is **no stat-only mode**, including as an implicit faster memo.

## File races and errors

The contract is a **stream contract**, not an atomic file snapshot:

- Renaming/replacing or removing the path during reading does not change
  the open descriptor. The first digest belongs to its read stream; the
  next call opens the then-current path.
- In-place modification between reads can produce an old prefix and new
  remainder, just as with original `Digest#file`. The cache stores only
  that actual stream; the next call rereads and compares every byte.
- An extra control read or reopen after comparison would introduce a
  different race and is not performed.
- `ENOENT`, `EACCES`, `EISDIR`, empty files, binary contents and
  binary-encoded paths use the same native open/read operations. Error
  classes/messages remain intact; RailsVite's original `ENOENT` rescue
  still returns its sentinel.
- Integer descriptors need no path, so the helper does not additionally
  call `File#path` or perform a second path conversion.

As in the original, an externally modified stream may yield different bytes
between runs. No snapshot is promised, nor is the result retrospectively
claimed to match the last `stat`.

## Guards and refusals

The build certifies the Ruby bodies of `Digest::Class.file` and
`Digest::Instance#file` by tokens, SHA-256-pinning their implementation file
and loaded native digest libraries. Initially only Digest 3.2.1 is certified.
Skipped digest operations (`new`, initialization, `update`, `hexdigest`,
clone/copy and `finish`), open/read, String operations and built-in Pathname
conversion get method facts; native digest owners must match stock owners.
Array and algorithm hash/equality dispatch for cache keys are pinned too.
Native aliases are checked through `original_name`: matching owner and
`source_location == nil` alone are insufficient. Definition/module hooks
invalidate the unit and trigger revalidation.

Accepted paths are exact Strings, Integer descriptors and ordinary Pathnames
with plain String contents and certified conversion. Custom path objects
and subclasses stay original: their `to_path` can have effects and is not
called early. A different lexical digest receiver or shadowed `Digest::File`
is not bypassed. Original calls retain effects/errors. Certified digest
modules are captured only after first successful validation, not activated
before Bundler. Later namespace rebinding also falls back. Non-main Ractors
use the original path without accessing unshareable memo/stats state; their
fallbacks are not counted.

Changed Ruby digest bodies, non-native/differently aliased primitives,
customized path conversion, refinements, multiline intrinsics and denylisted
files are conservatively refused. Unknown expression shapes are not replaced.
The general guard limitations remain: definition hooks without `super`,
visibility-only changes, refinements from other code, C metaprogramming and
ISeq/stack inspection do not acquire a new safety guarantee. As with other
call-site guards, methods must stay stable during one intrinsic; monkeypatching
concurrently inside an IO read is not a certified synchronization protocol.

## Public fixture and executable gates

`fixtures/digest-app` is a small public Rails app without a database/JS build,
using rails_vite 0.3.0, inertia_rails 3.22.0 and vite_ruby 3.11.1. Its Inertia
version is a lazy proc. No private application source is needed.

```sh
cargo build --release
cargo test
ruby -Igem/lib -Igem/test -e 'Dir["gem/test/*_test.rb"].each { require_relative _1 }'
(cd fixtures/digest-app && bundle install)
target/release/lowrail build fixtures/digest-app --passes default,+digest_memo
target/release/lowrail verify fixtures/digest-app --bisect -- bin/rails test --seed 1729
```

The fixture checks binary data/result mutability, equal length with restored
mtime, missing/recreated/empty/unreadable files, directory errors, Integer
descriptors and path encoding. TracePoint probes replace/overwrite/remove a
file exactly after the first read; another removes a match after glob
expansion. Time travel checks glob order and the existing time window. The
Inertia page checks changed versions and the 409 Location response for stale
clients. EACCES is checked only when the running user actually lacks read
access; root can read mode 0000.

Result: **7/7 identical, 71 assertions/mode, 65 hits** (52 MD5, 13 SHA1),
**zero fallbacks, no skips**. Gem tests also check opt-in, intentional
clone/native-alias overrides, custom path conversion, lexical digest
shadowing and namespace replacement. A custom algorithm `hash` that the
original call does not use must not execute either. Without its method
fact, the same public probe raises an extra exception; the complete
certificate returns the original digest. Six counted fallbacks there are
intentional negative controls; memo hits must resume after restoration.
Another probe checks the native original path in a second Ractor. A
lexically refined method is refused at its `using` AST even after a
semicolon; its differing return is preserved.

Aggregate historical measurements are in
[Private Rails app with Inertia Rails](../m0/private-inertia-app.md); no application source,
class/file/test names or dependency inventory is published there.
