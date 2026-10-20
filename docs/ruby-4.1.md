# Ruby 4.1 preview / ZJIT investigation

2026-10-20. **Ruby 4.0 and 4.1 are correctness targets; 4.0.7 remains the
measurement primary while 4.1 is a preview.** Ruby 3.4 is no longer a target.
This is a target policy, not a claim that the application matrix already
passes. The pinned preview builds with both JITs. The initial unchanged-bundle
failure study below is retained as evidence; the authorized follow-up fixes
Lowrail first, then tests source-Nokogiri dependency workarounds in disposable
copies only. ZJIT measurement remains conditional on both steps being green.
The [dual-JIT shape guide](jit-shapes.md), warning-only bytecode check and
opt-in diagnostics do not weaken any gate.

## Follow-up step 1: own-code compatibility

- **Generated-script linking refuses exactly.** The preview's `iseqw_new`
  allocates fresh wrappers; `of(method)` cannot identify the wrapper visited
  through `each_child`. Capture and ordinary method facts still work, but
  facts/observation now record `generated_stats.linking_decline` beginning
  `iseq_identity_unavailable`, with no fabricated `script` links. Structural
  bytecode, source hash and path/line equality do not establish compilation
  identity or lexical environment. On 4.0.7 the identity map and all links are
  unchanged. Tests require links where identity exists, and the explicit
  refusal where it does not; they do not skip the unsupported case.
- **Observation deduplication uses UnboundMethod equality**, not transient
  ISeq wrappers. Repeated explicit observation targets must yield one profile.
- **URI 1.1.2:** the bundled preview `common.rb` differs from the certified
  installed 1.1.2 by three documentation links only. Added its exact SHA256
  to the whitelist; the other four source files are identical. No version-wide
  trust or source-check bypass.
- **Digest 3.3.0:** `digest.rb` and `sha2init.c` are identical to 3.2.1's
  Ruby 4.0.7 copies. The `digest.c` diff changes export linkage, length-number
  conversion in `digest_length`, and initializes a metadata-search local to
  nil; the SHA256/base64digest call closure is unchanged. The expression
  certificate accepts exactly 3.2.1/3.3.0, retaining method/source checks and
  runtime native-binary fingerprints. This does not extend `digest/file_memo`.
- **Endpoint zero-hit explained and fixed:** a captured request shows matching
  template bodies but different 4.1 `source_hash` metadata after Rails generates
  fresh method names. Exclude this parser field alongside node IDs/locations;
  keep the executable instructions, literals and every existing certificate.
  The original end-to-end mutation/visibility/event test now exercises hits
  on both versions instead of silently using the original template.
- **Ractor refusal:** after URI certification, its existing regression test
  exposed 4.1's changed ObjectSpace visibility. `gc.c:2060–2105` now exposes
  our own heap in multi-Ractor mode while hiding foreign unshareable objects.
  The old sentinel alone no longer certifies tracing visibility. A visible
  non-main Ractor now conservatively disables reuse; `Memo.refusal_reason`
  records `ractor_trace_visibility`. Keep the old sentinel too. No hot-path
  instruction was added; this is setup-time admission, not a tracing workaround.

Step-1 checks: full 4.0.7 `rake test` **101 runs / 1,203 assertions, zero
failures/errors, 20 skips**. 4.1 own-code suite (`--exclude '/Corpus/'`)
**98 / 1,124, zero failures/errors, 21 skips**. The three excluded tests boot
the original corpus bundles and still fail at the documented dependency
boundary, so the full 4.1 suite is **not yet green**. They must run again
against the disposable copies in step 2; this exclusion is not a support gate.

## Exact interpreter and reproducible matrix axis

- [Ruby 4.1.0-preview1 release](https://www.ruby-lang.org/en/news/2026/10/12/ruby-4-1-0-preview1-released/),
  tag `v4.1.0-preview1`, commit
  [`2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1`](https://github.com/ruby/ruby/commit/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1).
- Release tarball SHA256:
  `fb530bb88e90de3ae91c1310a27ae090e6bd989b8726de50ef12a890a85b88ef`,
  checked against the release page and downloaded bytes.
- Linux x86-64; GCC 12.2.0; rustc 1.99.1 (ZJIT requires ≥1.85).
  Configure: `--enable-yjit --enable-zjit --disable-install-doc` with the
  installation prefix below; release build, `make -j6`, `make install`.
- Description: `ruby 4.1.0preview1 (2026-10-11 master 2d08b5f42f) +PRISM [x86_64-linux]`.
  Same executable reports YJIT-only and ZJIT-only with the flags below.

Rebuild without editing `mise.toml` (which stays pinned to **4.0.7**):

```sh
curl -fLO https://cache.ruby-lang.org/pub/ruby/4.1/ruby-4.1.0-preview1.tar.gz
echo 'fb530bb88e90de3ae91c1310a27ae090e6bd989b8726de50ef12a890a85b88ef  ruby-4.1.0-preview1.tar.gz' | sha256sum -c -
tar xf ruby-4.1.0-preview1.tar.gz
# Run these three commands in the extracted source directory:
./configure --prefix="$HOME/.rubies/lowrail-4.1.0-preview1" \
  --enable-yjit --enable-zjit --disable-install-doc
make -j6
make install
mise link ruby@4.1.0-preview1 "$HOME/.rubies/lowrail-4.1.0-preview1"
```

Use the existing **explicit mise version per invocation** as the matrix axis,
not a second version-selection wrapper or an environment variable that child
processes may ignore. Both the Rust CLI's `bundle exec ruby` and the Ruby
drivers' `RbConfig.ruby` use that selected installation. Verify now preserves
each outcome writer's `RUBY_DESCRIPTION` in `last.json` and prints it; bench
already records the actual worker interpreter, not only the requested version.

```sh
mise exec ruby@4.0.7 -- ruby -v             # primary, also: mise exec -- ruby -v
mise exec ruby@4.1.0-preview1 -- ruby -v    # experimental second column
mise exec ruby@4.1.0-preview1 -- ruby --disable-yjit --disable-zjit -e 'p [RubyVM::YJIT.enabled?, RubyVM::ZJIT.enabled?]'
mise exec ruby@4.1.0-preview1 -- ruby --yjit --disable-zjit -e 'p [RubyVM::YJIT.enabled?, RubyVM::ZJIT.enabled?]'
mise exec ruby@4.1.0-preview1 -- ruby --zjit --disable-yjit -e 'p [RubyVM::YJIT.enabled?, RubyVM::ZJIT.enabled?]'
```

These print `[false, false]`, `[true, false]`, `[false, true]`.
Do not reuse facts, generated scripts or manifests across versions. The
manifest's existing interpreter guard refuses mismatched binaries, but cached
facts alone are not a matrix run. Use separate disposable corpus copies per
version, keep their lockfiles identical, and build each one under its own
interpreter before verify/bench. No lockfiles were changed in this study.

```sh
# From gem/, for each version:
mise exec ruby@4.1.0-preview1 -- rake test
# From the repository root, on a fresh per-version corpus:
mise exec ruby@4.1.0-preview1 -- cargo test
for app in real-blog-r4 campfire pingcrm redprints-cfp react-starter-kit; do
  LOWRAIL_BUILD_JIT=0 mise exec ruby@4.1.0-preview1 -- \
    target/debug/lowrail build ".corpus/$app" --env test --passes all-opt-in
  mise exec ruby@4.1.0-preview1 -- target/debug/lowrail verify ".corpus/$app"
done
RUBYOPT=--yjit mise exec ruby@4.1.0-preview1 -- \
  target/debug/lowrail verify .corpus/real-blog-r4
# Once compatibility is fixed, bench uses the identical version axis:
BENCH_JIT=1 mise exec ruby@4.1.0-preview1 -- target/debug/lowrail bench \
  .corpus/real-blog-r4 --pass ar_instantiate --path /articles --out /tmp/new-41-cohort
```

The final bench command is an example of version selection, **not an executed
or accepted measurement**. `BENCH_JIT` still accepts only `0`/`1`.

## Initial correctness matrix: unchanged applications first

Lowrail base:
[`07205de`](https://github.com/thomasklemm/lowrail/commit/07205de08030f5406eb224b3bfe467fd01be799f).
Corpus sources are `script/corpus` pins, not latest application branches:

| App / corpus directory | Source pin | Locked Rails | 4.1 interpreter build / verify | Classification |
|---|---|---|---|---|
| Blog / `real-blog-r4` | Roundhouse fixture [`bb90df2`](https://github.com/rubys/roundhouse/commit/bb90df2514f80817f98d89848dd0a6baa8df20a9) | 8.1.4 | blocked / no outcomes | Rails-on-4.1 dependency boundary, before Rails boots |
| Campfire / `campfire` | [`af4dd9f`](https://github.com/basecamp/once-campfire/commit/af4dd9fd599c65e0e0fc1f614ee469f70156ddf5) | 8.2 alpha, as pinned | blocked / no outcomes | same pre-Rails dependency boundary |
| PingCRM / `pingcrm` | [`22464f8`](https://github.com/ledermann/pingcrm/commit/22464f822dcf59c4425993dd623780ad44497fda) | 8.1.4 | blocked / no outcomes | same pre-Rails dependency boundary |
| Redprints / `redprints-cfp` | [`6080fc2`](https://github.com/evilmartians/redprints-cfp/commit/6080fc24fbf0015f7e5a5ae932e903731502c65a) | 8.1.3, as pinned | blocked / no outcomes | same pre-Rails dependency boundary |
| Starter / `react-starter-kit` | [`f808193`](https://github.com/inertia-rails/react-starter-kit/commit/f8081935e9bda68f8ef1ec53dc7eed19c819ee68) | 8.1.4 | blocked / no outcomes | same pre-Rails dependency boundary |
| Blog YJIT | same fixture and lock | 8.1.4 | verify blocked / no outcomes | same boundary, not a JIT failure |

All five build attempts and six verify invocations exit nonzero. Verify
correctly refuses to call a process with no outcomes equivalent. There is no
Lowrail fast-path coverage claim for any 4.1 app. Campfire and Redprints stay
on their historical framework versions rather than being silently relabeled
as Rails 8.1.4 tests.

The locked native `nokogiri-1.19.4-x86_64-linux-gnu` requires
**`>= 3.2, < 4.1.dev`**. This is directly visible in its gemspec and in the
Redprints Bundler 2.6.8 failure. The four Bundler 4.0.20 installations fail
resolution with `Could not find gems matching 'mini_portile2' valid for all
resolution platforms`; changing platforms/forcing source gems would not test
the unchanged corpus. Their subsequent build/verify boot errors list the
uninstalled bundle, including Nokogiri. **This is not evidence that Rails
8.1.4's runtime is broken.** No local Rails patch, lock regeneration or
platform override was made. Standalone source Nokogiri/SQLite installations
were used only for the gem suite's synthetic Rails app.

Lockfile SHA256s, in table order:

```text
blog       570c9c31129469dc2679780a9f7f7d26aca93e57e4e119250735322741ac8596
campfire   b26ccac52dda4ab689c1aadbbf5d5ce75492cb25349b930c826f1ad2885501ae
pingcrm    1086ac22d14b19f5d2cc15bc43e3c4d274dbd43bab9c6ebffc329804062265c0
redprints  74d2f70ab268cb2de8158152d51fbbb56255fab1370e38e7199731d260275b82
starter    e1819832e7a2b33f45b0fe9675ef42308b9586b1203d4ed213c08c3a2a15a2fb
```

### Lowrail-on-4.1 failures, separate from the app boundary

Before diagnostic edits, `gem/rake test`:

- 4.0.7: **97 runs, 1,164 assertions, 0 failures, 0 errors, 17 skips**.
- 4.1 preview: **97 runs, 973 assertions, 11 failures, 1 error, 18 skips**.
- Two standalone Rails 8.1.4 materialization/model-surface tests pass:
  **2 runs / 81 assertions**. This is a small control, not a full Rails suite.

Exact failure accounting:

| Failure(s) | Classification / observed reason |
|---|---|
| MaterializeCorpus real_blog + campfire; ObserveCorpus real_blog (3 failures) | Rails-on-4.1 dependency/setup boundary above; not Lowrail semantics |
| Observe definitions, ScriptCapture linking, Materialize attribute linking (3 failures), Materialize template linking (1 error) | **Lowrail-on-4.1 incompatibility:** ISeq wrappers are no longer identity-stable |
| Endpoint coverage (1 failure: expected hit 1, actual 0) | **Lowrail-on-4.1** fast path declined in a standalone Rails app; exact cause not established; responses before the hit assertion pass |
| Memo URI scenarios (3 failures) | **Lowrail-on-4.1 conservative refusal:** `uncertified URI source common.rb`; do not relax the source certificate |
| Memo Digest scenario (1 failure) | **Lowrail-on-4.1 conservative refusal:** preview bundles Digest 3.3.0, certificate requires 3.2.1 |

`ScriptCapture.iseq_index` uses identity keys, and `Facts.method_entry` looks
up `InstructionSequence.of(method)` in that map. On 4.0.7, two `of` calls on
the same method, and the corresponding `each_child` wrapper, are identical;
on 4.1 neither is identical, though `to_a` agrees. Preview
[`iseq.c:1727–1734`](https://github.com/ruby/ruby/blob/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1/iseq.c#L1727-L1734)
allocates a wrapper each time. This verifies the identity-map failure; it does
not establish the endpoint's separate cause. No compatibility repair here.

Clean 4.1 `cargo test`: **34 unit tests pass; corpus types/MCP integration
fails at bundle setup**; separately, **2 verify boundary tests pass**. An
earlier run reused 4.0-generated facts and looked green: **discarded as
cross-version evidence**, rerun after removing those disposable facts.
4.0.7 final `cargo test` passes all **34 + 1 + 2** tests.

After adding one compiler regression test and extending the outcome tests:
4.0.7 gem suite **98 / 1,199, zero failures/errors, 17 skips**; 4.1
**98 / 1,008, the same 11 failures + 1 error, 18 skips**. The targeted
compiler/reporter suite passes **7 / 106 on both**. Benchmark preflight tests
pass **16 / 157**. Interpreter/YJIT/ZJIT diagnostic snapshots were also
exercised on the same preview binary; these are API probes, not benchmarks.

After rebasing onto the latest `origin/main` (including the separate Inertia
props work), both full gem suites were rerun: **101 / 1,199, zero
failures/errors, 20 skips** on 4.0.7; **101 / 1,008, the same 11 failures +
1 error, 21 skips** on 4.1. The three additional tests skip because their
supported Inertia gem versions are not installed in these test environments.
The final Cargo results remain **34 + 1 + 2 passing** on 4.0.7, and
**34 passing, corpus integration blocked, 2 verify tests separately passing**
on 4.1 with the cached 4.0 facts withheld. Benchmark preflight again passes
**16 / 157**. These reruns are correctness checks, not measurement retries.

## ZJIT cohort disposition and gate requirements

| Requested finite cohort | Interpreter / YJIT / ZJIT on 4.1 | Disposition |
|---|---|---|
| Old cached guard vs K | not started | blocked by the explicit compatibility stop; no numbers |
| Allocation-study props micro | not started | same stop, including the otherwise standalone micro |
| Blog index/show: off vs historical default, L2/L2_events | not started | corpus blocked; no numbers or accepted/rejected measurement cohort |

No retries-until-green, cohort salvage or substitutions. Existing
[YJIT rejections](bench.md#matched-interpreter--yjit-request-study) remain
rejected. Later work must pin the historical default at the published
[`c9d2397`](https://github.com/thomasklemm/lowrail/commit/c9d2397f1748579b04f6bddff48bc3bfc53d79b0)
study and its specimen/harness hashes, rebuild ISeqs on the selected Ruby,
keep quarantine on current main, and retain the specimens' known semantic
omissions. The allocation study's older default is
[`8df58ed`](https://github.com/thomasklemm/lowrail/commit/8df58ed), not today's
empty default. These are different baselines, not interchangeable results.

The next ZJIT seam needs **three flat warm windows and no compilation or
invalidation in any measured window**, alongside unchanged fixed heaps,
both A/A controls, GC.stat_heap-signature prewarm and request-only settling.
ZJIT's `compiled_side_exit_count` counts **compiled exit stubs**, not executed
exits. `invalidation_time_ns` is time, not a public invalidation generation.
The release build does not supply `ratio_in_zjit` or executed side-exit counts;
do not replace the strict YJIT gate with whichever ZJIT numbers are available.
ZJIT remains diagnostic, never pass promotion evidence in this investigation.

## Mutation APIs: no usable public broad epoch found

Inspected the built preview and, read-only, master
[`c71329d`](https://github.com/ruby/ruby/commit/c71329d4298a4ce03dabea45328933c6464cf362).
The relevant public Ruby surface and examined public C/debug headers expose
no supported method/visibility/constant mutation subscription or broad epoch.

- [`vm.c:846–907`](https://github.com/ruby/ruby/blob/c71329d4298a4ce03dabea45328933c6464cf362/vm.c#L846-L907):
  `RubyVM.stat` still has constant-cache invalidations/misses,
  `global_cvar_state`, `next_shape_id`, `shape_cache_size`, not a method epoch.
  Cache invalidation counts are not mutation counts; shape allocation counts
  are not per-object value generations; cvar state covers its own cache.
- [`vm_method.c:314–345`](https://github.com/ruby/ruby/blob/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1/vm_method.c#L314-L345):
  internal `vm_cme_invalidate` marks a callable method entry and calls both
  JITs; constant-cache clearing calls both constant-state hooks.
- Root [`yjit.h:35–55`](https://github.com/ruby/ruby/blob/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1/yjit.h#L35-L55)
  / [`zjit.h:118–132`](https://github.com/ruby/ruby/blob/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1/zjit.h#L118-L132):
  CME, constant, singleton-class, tracing and environment-escape invalidation
  functions are **VM-private hooks**, not an extension subscription API.
- ZJIT [`invariants.rs`](https://github.com/ruby/ruby/blob/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1/zjit/src/invariants.rs)
  tracks individual CME/constant patchpoints; `hir.rs:6147–6370` guards object
  shapes. Neither certifies arbitrary Ruby object contents or a Lowrail fact.

Do not export or interpose those internals, and do not substitute aggregate
JIT counters for exact guards. The separate mutation-epoch experiment remains
responsible for counterexample coverage and measured read costs.

## Ruby::Box: interesting isolation, not a certificate

Preview [`doc/language/box.md`](https://github.com/ruby/ruby/blob/2d08b5f42f2cbed4a4e6ecf8d62987a4f21f98c1/doc/language/box.md)
still requires process-start `RUBY_BOX=1` and labels Box experimental. Against
4.0.7 that document changes prose/examples only; the examined master document
is identical to preview. This is **not** a claim that implementation code is
unchanged. The documented native-extension install and ActiveSupport core-ext
issues remain. A small preview probe confirms isolated definitions:
outer `BoxProbe#value => :outer`, boxed `=> :inner`, classes not identical.

A box separates class/module definitions, monkey patches and loading; it
does not freeze object state, callbacks, configuration, database/schema or IO.
Box creation also invalidates ZJIT's root-box assumption
(`invariants.rs:511ff`). It is a possible future experiment with two fully
separate app worlds, not a drop-in isolation boundary around selected methods
of today's live Rails object graph. Keep process isolation for verification
and retain exact guards. No Box integration was implemented.
