# Ruby 4.1 preview / ZJIT investigation

2026-10-20. **Ruby 4.0 and 4.1 are correctness targets; 4.0.7 remains the
measurement primary while 4.1 is a preview.** Ruby 3.4 is no longer a target.
The pinned preview builds with both JITs. Lowrail's full gem and Cargo suites
now pass on both versions. All five disposable application copies pass
interpreter verification, and blog also passes with YJIT. This is a green
correctness matrix with dependency overlays, not unchanged-bundle support.
The initial unchanged-bundle failure study below is retained as evidence.
The compatibility prerequisite for ZJIT measurement is satisfied; no
performance cohort is credited by these correctness results.
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

Historical step-1 checks: full 4.0.7 `rake test` **101 runs / 1,203 assertions, zero
failures/errors, 20 skips**. 4.1 own-code suite (`--exclude '/Corpus/'`)
**98 / 1,124, zero failures/errors, 21 skips**. The three excluded tests boot
the original corpus bundles and still fail at the documented dependency
boundary. Step 2 below supersedes this partial run with the full suite, without
exclusions; this earlier exclusion was not a support gate.

## Follow-up step 2: source dependency workaround and correctness

**Dependency workaround, not an application support claim.** Original
`.corpus` pins, Gemfiles and lockfiles were not edited; all five original
lock hashes still match the initial study below. Copies are under
`.corpus/ruby41-source/APP`, with separate `.lowrail`, test databases and JS
outputs. No application or Rails source patch, dependency version upgrade,
gemspec edit or global `BUNDLE_FORCE_RUBY_PLATFORM` was used in the successful
matrix. Redprints also requires the separately authorized FFI/SQLite source
overrides and Bundler 4.0.20, described below.

Nokogiri was explicitly forced to the source platform in each copied Gemfile:

```ruby
gem "nokogiri", "= 1.19.4", force_ruby_platform: true
```

`bundle lock --update nokogiri` adds **mini_portile2 2.8.9**. Nokogiri's source
gem SHA256 is `50c951611c92bca05c51411aef45f1cbc50f2821c4802758c5c6d34696533ab5`;
mini_portile2's is `0cd7c7f824e010c072e33f68bc02d85a00aeb6fce05bb4819c03dfd3c140c289`.
Build tools, libxml/libxslt build inputs and mini_portile2 are dependency
setup, not Lowrail passes. `bundle install` alone is insufficient evidence:
it sometimes exits zero while a subsequent `bundle exec ruby` cannot find
the native variants in its frozen lock.

For blog, Campfire, PingCRM and Starter, `bundle lock --add-platform ruby`
then `BUNDLE_FROZEN=true bundle install` makes compatible source variants
available **without forcing other gems**. Actual loaded variants: blog
FFI 1.17.4 / SQLite 2.10.1; Campfire FFI 1.17.2 / SQLite 2.9.6;
PingCRM FFI 1.17.4 / PG 1.7.0; Starter SQLite 2.9.6, all platform `ruby`.
All load Nokogiri 1.19.4 and mini_portile2 2.8.9 as platform `ruby`.
Existing gem version numbers are unchanged; lock differences are source
variants/dependencies, platform/checksum metadata and the Nokogiri declaration.
Final successful runs use the original Bundler versions: blog 4.0.20,
Campfire **4.0.13**, PingCRM 4.0.21, Starter 4.0.3.

**Redprints: recovered Rails-on-4.1 dependency boundary, not a Lowrail failure.** Its
Bundler 2.6.8 install rejects `ffi-1.17.4-x86_64-linux-gnu`'s
`>= 3.0, < 4.1.dev` constraint; SQLite 2.9.5's locked native variant also
cannot be materialized. Adding platform `ruby` fails because locked
`bundlebun-0.5.0.1.3.14` has no Ruby-platform package. A diagnostic
`BUNDLE_VERSION=4.0.20` install and its suggested `bundle lock
--normalize-platforms` both exit zero, but **runtime still fails** with
`Could not find sqlite3-2.9.5-x86_64-linux-gnu,
ffi-1.17.4-x86_64-linux-gnu`. The initial and normalized attempts are both
failed setup, not recovered support. Build and both RSpec verify commands
initially failed before Rails/outcome recording.

After explicit authorization, the disposable Redprints copy adds
`gem "ffi", "= 1.17.4", force_ruby_platform: true` and applies
`force_ruby_platform: true` to its existing SQLite 2.9.5 declaration.
`BUNDLE_VERSION=4.0.20 bundle lock --update nokogiri ffi sqlite3` followed by
a frozen install loads those exact source versions successfully. Bundlebun
is retained. Create the disposable copy's `log` and `tmp` directories before
assets/test preparation (Avo requires `log`). Both RSpec suites then pass
with and without Lowrail, as recorded below. This is a dependency workaround,
not a change to corpus pins or an unchanged-bundle support claim.

### Executed checks

`LOWRAIL_TEST_CORPUS_ROOT` selects disposable fixtures for the gem and Rust
tests; unset, it preserves the existing `.corpus` default. It does not select
a VM, change a corpus pin, bypass a test or reuse another VM's facts. Rust now
preserves `linking_decline` in its facts schema and observation merge and
prints the refusal in `facts` summaries. Its real-blog regression still
requires identity links on 4.0; on 4.1 it requires the explicit refusal,
no `script` tags and no identity-based template attribution. The existing
location-based **source display** remains labeled `Via::Location`; it is not
compilation provenance or a lowering certificate.

| Check | Ruby 4.0.7 (primary) | Ruby 4.1 preview (second correctness target) |
|---|---|---|
| Full gem `rake test`, no exclusions, integrated with `51686b7` | 118 runs / 1,291 assertions; 0 failures/errors; 19 skips | **118 / 4,132; 0 failures/errors; 7 skips** |
| Full `cargo test` | **34 unit + 1 types/MCP + 2 verify pass** | **34 + 1 + 2 pass**, fresh preview facts |

These counts include the separately landed compiler and sealed regressions. The
initial 4.1 Rust corpus test failed its old template-link assumption after
booting successfully; the refusal-aware regression passes, rather than
skipping the corpus. Different optional-gem availability explains differing
gem-suite skip counts; neither version's passing tests were excluded.
The sealed test requires `minitest/mock`: declare `minitest-mock ~> 5.27`
as a gem development dependency, and let `.agents/setup` install declared
development dependencies. Isolated fresh GEM_HOME installs resolve 5.27.0
and load `minitest/mock` on both VMs; no manual preinstallation is required.
The 4.0 run uses the original corpus, the preview uses its disposable overlay.
An initial 4.0 rerun mistakenly selected the preview corpus and failed three
boot tests because that VM lacked the source Nokogiri/mini_portile2 packages;
correcting the test axis, not changing code or excluding tests, yields the
full passing run above.

All app builds select **all-opt-in**, with interpreter flags
`--disable-yjit --disable-zjit`, frozen copied bundles, test environment,
seed **41231**, full SQL recording and serial Minitest workers. Browser
dependencies: PingCRM/Redprints `bun install --frozen-lockfile`, Starter
`npm ci`; test assets precompiled. Selenium uses the installed Chrome via
`SE_CHROME_PATH`; it provisions its matching driver. PingCRM uses the local
disposable PostgreSQL database `lowrail_ruby41_pingcrm_test`. No production
database is involved.

| App / mode | Build | On/off outcomes | Own-thread SQL | Fast-path hits / units | Fallbacks |
|---|---|---|---|---|---|
| Blog / interpreter | pass | **21/21 pass**, identical | 125, identical | **44 / 5** | 1 |
| Campfire / interpreter | pass | **632 pass + 2 skip**, identical | 15,109, identical | **3,718 / 15** | 4,035 |
| PingCRM / interpreter (models + system) | pass | **26/26 pass**, identical | 812, identical | **717 / 7** | 1 |
| Redprints / interpreter, default | pass | **50/50 pass**, identical | 692, identical | **277 / 7** | 0 |
| Redprints / interpreter, system | same build | **12/12 pass**, identical | 260, identical | **417 / 7** | 0 |
| Starter / interpreter (includes system) | pass | **36/36 pass**, identical | 264, identical | **163 / 4** | 0 |
| Blog / YJIT | reused compatible preview build | **21/21 pass**, identical | 125, identical | **44 / 5** | 1 |

Each executed outcome writer reports the pinned preview, and diagnostics
confirm both JITs off for interpreter verification, only YJIT on for blog's
YJIT run. These are correctness runs, not timing comparisons. The initial
Campfire build had no model schema and zero hits; its tests created the
schema. That run is retained as a setup failure for coverage, not credited.
After preparing its DB, refreshing facts (19 models) and rebuilding with the
pinned Bundler, the table records actual covered units. It is not evidence
that changing Bundler improved performance.

**Differences and limitations, not suppressed:** PingCRM records other-thread
SQL differences in nine browser tests; Campfire in one concurrency test.
They remain advisory thread-interleaving differences, separate from the exact
own-thread SQL check. Campfire's two existing skips remain. Its fallback
totals include four instantiate units with no hits; there is no all-unit
support claim. Blog retains a recorded `template_certificate` refusal for
show (`compiled template depends on lexical scope`); the positive endpoint
regression does not authorize bypassing this separate refusal. Digest
file-memo still refuses 3.3.0 (`digest_version`), unlike the separately
audited expression certificate. Route/view quarantine remains in force.
These are **Lowrail-on-4.1 safe refusals**, not Rails test failures.

**Disposition:** own-code compatibility is green on both targets; the five-app
preview correctness matrix is green with the recorded dependency overlays.
No observed Rails 8.1.4 runtime failure is patched locally. Proceed to step 3's
ZJIT seam/cohorts; the singleton-guard alternative still requires complete-check
pricing before implementation. Do not infer performance from these tests.

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
mise exec ruby@4.1.0-preview1 -- ruby -v    # second correctness column
mise exec ruby@4.1.0-preview1 -- ruby --disable-yjit --disable-zjit -e 'p [RubyVM::YJIT.enabled?, RubyVM::ZJIT.enabled?]'
mise exec ruby@4.1.0-preview1 -- ruby --yjit --disable-zjit -e 'p [RubyVM::YJIT.enabled?, RubyVM::ZJIT.enabled?]'
mise exec ruby@4.1.0-preview1 -- ruby --zjit --disable-yjit -e 'p [RubyVM::YJIT.enabled?, RubyVM::ZJIT.enabled?]'
```

These print `[false, false]`, `[true, false]`, `[false, true]`.
Do not reuse facts, generated scripts or manifests across versions. The
manifest's existing interpreter guard refuses mismatched binaries, but cached
facts alone are not a matrix run. Use separate disposable corpus copies per
version and build each one under its own interpreter before verify/bench.
The unchanged-bundle study made no lock changes; step 2's dependency workarounds
change **only the disposable locks**, so do not compare them to unchanged
4.0 bundles as if Ruby alone were the changed variable in a speed study.

```sh
# From gem/, with an absolute path to the prepared disposable corpus:
export LOWRAIL_TEST_CORPUS_ROOT=/home/user/workspace/repo/.corpus/ruby41-source
mise exec ruby@4.1.0-preview1 -- rake test
# Back at the repository root, retaining the same environment:
mise exec ruby@4.1.0-preview1 -- cargo test
export BUNDLE_FROZEN=true RAILS_ENV=test PARALLEL_WORKERS=1 SEED=41231
export LOWRAIL_SQL_TRACE=full LOWRAIL_JIT_DIAGNOSTICS=1
export SE_CHROME_PATH="$HOME/.agent-browser/browsers/chrome-155.0.8059.79/chrome"
export RUBYOPT='--disable-yjit --disable-zjit'
for app in real-blog-r4 campfire pingcrm redprints-cfp react-starter-kit; do
  (
    unset DATABASE_URL
    if [ "$app" = pingcrm ]; then
      export DATABASE_URL=postgresql:///lowrail_ruby41_pingcrm_test
    fi
    # Prepare DB/schema first. Refresh facts; do not reuse a pre-schema dump.
    mise exec ruby@4.1.0-preview1 -- target/debug/lowrail facts "$LOWRAIL_TEST_CORPUS_ROOT/$app"
    LOWRAIL_BUILD_JIT=0 mise exec ruby@4.1.0-preview1 -- \
      target/debug/lowrail build "$LOWRAIL_TEST_CORPUS_ROOT/$app" --env test --passes all-opt-in
    case "$app" in
      pingcrm)
        mise exec ruby@4.1.0-preview1 -- target/debug/lowrail verify "$LOWRAIL_TEST_CORPUS_ROOT/$app" -- \
          bin/rails test test/models test/system --seed 41231 ;;
      redprints-cfp|react-starter-kit)
        mise exec ruby@4.1.0-preview1 -- target/debug/lowrail verify "$LOWRAIL_TEST_CORPUS_ROOT/$app" -- \
          bundle exec rspec --seed 41231 ;;
      *) mise exec ruby@4.1.0-preview1 -- target/debug/lowrail verify "$LOWRAIL_TEST_CORPUS_ROOT/$app" ;;
    esac
    if [ "$app" = redprints-cfp ]; then
      mise exec ruby@4.1.0-preview1 -- target/debug/lowrail verify "$LOWRAIL_TEST_CORPUS_ROOT/$app" -- \
        bundle exec rspec spec/system --seed 41231
    fi
  )
done
RUBYOPT='--yjit --disable-zjit' mise exec ruby@4.1.0-preview1 -- \
  target/debug/lowrail verify "$LOWRAIL_TEST_CORPUS_ROOT/real-blog-r4"
# Once compatibility is fixed, bench uses the identical version axis:
BENCH_JIT=1 mise exec ruby@4.1.0-preview1 -- target/debug/lowrail bench \
  "$LOWRAIL_TEST_CORPUS_ROOT/real-blog-r4" --pass ar_instantiate --path /articles --out /tmp/new-41-cohort
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
| Blog index/show: off vs historical default, L2/L2_events | not started | five-app prerequisite still blocked at Redprints; no numbers or accepted/rejected measurement cohort |

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
