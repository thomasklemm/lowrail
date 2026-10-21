# Lowrail

**Make an existing Rails app faster without rewriting it, and prove that
nothing changed.**

Lowrail boots your Rails application, learns what is fixed after boot (schema,
routes, config, method definitions, templates), and delivers specialized Ruby
for the parts it can prove equivalent, as MRI instruction sequences (ISeqs).
The real Rails and every gem keep running. Anything Lowrail cannot prove stays
your app's own code, and every refusal is recorded with its reason.

It is deeply inspired by [Roundhouse](https://github.com/rubys/roundhouse) by
Sam Ruby, which transpiles Rails apps into standalone programs in many
languages and types them without annotations. Lowrail makes a different bet:
keep the real framework, target only lowered Ruby, lower only what can be
guarded exactly, and measure every claim. See [Acknowledgements](#acknowledgements)
for the other projects we learned from.

> **Research prototype.** Lowrail is not published as a gem and gives no
> production speedup by default today. Use it on a copy of your app or in CI.

## How it works

```
 your Rails app ──► lowrail facts  ──► boot facts (schema, routes, config,
 (source + boot)                       method table, templates, loaders)
                         │
                         ▼
                   lowrail build   ──► .lowrail/  manifest + lowered ISeqs,
                         │                        each with the guards it assumes
                         ▼
 RUBYOPT=-rlowrail/setup ──► at boot: certify guards, install what is exact,
                              refuse the rest (visibly), keep originals as fallback
                         │
                         ▼
                   lowrail verify  ──► your own suite, Lowrail off vs on:
                                       identical per-test outcomes + ordered SQL
```

The Rust CLI parses with [Prism](https://github.com/ruby/prism) and indexes
with [Rubydex](https://github.com/Shopify/rubydex). The Ruby gem in `gem/` is
the runtime that boots the app, certifies facts and installs lowered code.

## Quick start

Requirements: a Rust toolchain, Ruby 4.0.7 (pinned in `mise.toml`), and a
Rails 8.1 app whose test suite passes.

```sh
git clone https://github.com/thomasklemm/lowrail && cd lowrail
cargo build --release                       # CLI at target/release/lowrail
(cd gem && mise exec -- rake compile)       # optional native predicate

lowrail doctor path/to/app                  # boot, JIT mode, tracing checks
lowrail facts  path/to/app                  # what Lowrail learns at boot
lowrail build  path/to/app                  # writes path/to/app/.lowrail/
lowrail verify path/to/app                  # your suite off vs on
lowrail explain path/to/app                 # what was lowered, refused and why
lowrail types --rbs path/to/app             # RBS with per-slot evidence
```

Run your app with the runtime loaded, without Gemfile changes:

```sh
RUBYOPT="-I/path/to/lowrail/gem/lib -rlowrail/setup" bin/rails test
```

`LOWRAIL=0` disables it, `LOWRAIL_DEBUG=1` prints refusals. A missing, stale
or incompatible build is a silent no-op. More options are in the
[reference](#reference) below.

## Status (2026-10-21)

- **Correctness machinery works.** `lowrail verify` compares per-test outcomes
  and ordered SQL with Lowrail off and on. The pinned Rails 8.1.4 framework
  suites are a standing gate ([rails-suite.md](docs/rails-suite.md)). Real apps
  including Fizzy, Writebook, CASA, CodeTriage, Wikino, RubyToolbox and Fat
  Free CRM keep identical outcomes ([compat.md](docs/compat.md)). Green
  comparisons are not a universal support claim.
- **The default build lowers nothing.** Every guarded specialization tried so
  far was either unsafe under mid-request mutation or its guard cost more than
  it saved; for example the guarded props variant loses 22.6 % because its
  checks cost 6.9× the saving ([DECISIONS](docs/DECISIONS.md)).
- **The sealed tier (opt-in, production only) has measured wins** in
  interpreter instruction counts: the new-comment form scaffold −14.5 % per
  show request and `inertia/config_bind` −10.2 % per JSON request, plus
  isolated operations (hidden tokens −11.1 %, collection fusion −9.9 %).
  Admission must be passive, so the form is currently refused until passive
  activation lands; `link_to` admits again through the native predicate
  ([sealed-verification.md](docs/sealed-verification.md)).
- **YJIT measurement is not yet trustworthy.** Late JIT compilation in
  unrelated framework code rejects whole-request YJIT cohorts, including
  Lowrail-off arms ([bench.md](docs/bench.md)).
- **Types and MCP work.** `lowrail types`, `lowrail explain` and
  `lowrail mcp` serve boot facts, per-slot types (proven, static, observed or
  unknown), refusal reasons and recorded hits ([types.md](docs/types.md)).

Every pursued, parked and rejected idea is in
[docs/DECISIONS.md](docs/DECISIONS.md). Dated evidence is in
[docs/STATUS.md](docs/STATUS.md).

## Direction

Two tiers, so that every app keeps running and apps that opt in can go
further:

| Tier | Who | Promise | State |
|---|---|---|---|
| **guarded** (default) | any Rails app, any gem | identical test outcomes; specializations guarded and refused when not exact | works; currently lowers nothing by default |
| **sealed** (opt-in) | apps that accept a contract: no code, subscriber, config or route mutation after boot, among others | compile endpoints ahead of time without per-call checks; `lowrail seal-check` runs the app's suite and lists every violation with `file:line` and the code change that fixes it | opt-in research: measured interpreter wins; admission must be passive ([sealed.md](docs/sealed.md), [decision](docs/DECISIONS.md#architecture)) |

Apps that do not meet the sealed contract still run in the guarded tier. The
tooling explains why and what to change.

## Target matrix

| Axis | Primary | Secondary / diagnostic |
|---|---|---|
| Rails | 8.1.4 | 8.2 alpha (Campfire's pin) |
| Ruby (minimum 4.0) | 4.0.7 (`mise.toml`) | 4.1 preview ([separate compatibility matrix](docs/ruby-4.1.md)) |
| Execution | interpreter instruction counts (Callgrind, fixed heap, A/A controls) | YJIT under a strict JIT-flat gate; ZJIT being added, diagnostic only |

How to read and reproduce measurements: [docs/bench.md](docs/bench.md).

## Reference

All commands, from a checkout:

```sh
# 1. Toolchain: a Rust toolchain and the Ruby pinned in mise.toml
cargo build --release            # CLI at target/release/lowrail

# 2. Boot facts and a build (writes APP/.lowrail/)
lowrail facts path/to/app
lowrail build path/to/app [--env test|production]   # default selection
lowrail build path/to/app --passes default,+props,+endpoint

# 3. Prove it: your suite off vs on, per-test outcomes + ordered SQL
lowrail verify path/to/app     # prints its test seed to stderr; SEED=… to fix it

# 4. Types and tooling
lowrail explain path/to/app    # current selection, guards, refusals and recorded stats
lowrail observe path/to/app    # record observed types from a test run
lowrail types --rbs path/to/app # standalone RBS to stdout, with per-slot evidence
lowrail types path/to/app --rbs sig/lowrail
lowrail mcp path/to/app        # read-only MCP server over stdio

# 5. Measurements (see docs/bench.md before trusting a number)
lowrail bench path/to/app --pass NAME
```

The runtime loads without app or Gemfile changes:

```sh
RUBYOPT="-I/path/to/lowrail/gem/lib -rlowrail/setup" bin/rails test
```

Alternatively, add `require "lowrail/setup"` in `config/boot.rb`, before or
after Bootsnap. `LOWRAIL=0` disables it. A missing, stale or incompatible build
is a silent no-op, and an artifact containing quarantined passes is refused
with `Lowrail.refusal_reason`. In development it is off unless `LOWRAIL=1`.
`LOWRAIL_DEBUG=1` prints refusals.

Sealed link's optional native holder prototype is built explicitly with
`rake compile` from `gem/`, under each chosen Ruby (headers and C compiler
required). It is loaded equally on/off, never compiled during app boot, and
never loads objspace. A missing/unloadable build keeps the original path with
a visible refusal. [Contract and bounded validation](docs/sealed-verification.md#optional-native-holder-prototype-link-coverage-recovered).

`LOWRAIL_ROOT` names the real app root (default: the working directory).
`LOWRAIL_DIR` optionally selects a separate artifact directory containing
`manifest.json` (default: `LOWRAIL_ROOT/.lowrail`). Benchmark snapshots use
this separation; relocation/source certificates still check the real app root.

Build for the deployment's **startup JIT mode**:

```sh
lowrail build path/to/app --env production --jit yjit
RUBY_YJIT_ENABLE=1 RUBYOPT="-I/path/to/lowrail/gem/lib -rlowrail/setup" bin/rails server
```

`--jit interpreter|yjit|zjit` configures certification, not the deployed app.
Without it, the build observes the app's mode (legacy `LOWRAIL_BUILD_JIT=0/1`
still works). Each artifact records `certification_jit`; a different actual
mode at admission, or missing mode metadata, refuses the whole artifact before
installers run. Rebuild old artifacts. For YJIT, start the process with
`RUBY_YJIT_ENABLE=1` or `--yjit`, not only Rails' late `config.yjit` switch.
Late changes at `initialize!` completion are reported as mode drift in
`LOWRAIL_DEBUG`, stats, verify and bench; guards remain fail-closed, with no
uninstall or mode forcing. Doctor compares startup/after-boot modes separately.

`--passes` must start with `default` or `all-opt-in`, then applies
`+name`/`-name` in order. Names are the stable
`area/name` identifiers in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
Short aliases are `memo`, `preload_plans`, `ar_instantiate`, `ar_plans`,
`digest_memo`, `inertia_config`, `props` and `endpoint`, but only `props` and
`endpoint` remain eligible for guarded selection. The others refuse even in
`all-opt-in`; old mixed artifacts refuse as a whole. Sealed research builds
use `--sealed --env production` and require explicit production acceptance
of the [sealed contract](docs/sealed.md); test processes stay original-only.
File formats are documented in [docs/FORMATS.md](docs/FORMATS.md).

`LOWRAIL_VERIFY_LOADS=1 lowrail verify APP` also compares non-autoloading
constant censuses, Zeitwerk-loaded paths and executed Active Support load
hooks at the first test and after the suite, including load/hook order.
Reproducible differences fail verification and automatically probe each pass;
off/off and on/on variation is reported separately as advisory noise.
This observer is opt-in because its snapshots and boot hooks have a cost;
the corpus compatibility checks enable it. Snapshot time is in the report.

## Complementary optimizations

Lowrail only applies changes it can guard exactly. These stay the app's own
decision, and Lowrail works next to them:

- **YJIT** (`RUBY_YJIT_ENABLE=1`): recommended in production. Lowrail measures
  under it too, but its primary gate is interpreter instruction counts,
  because whole-request YJIT windows do not yet pass our compiler-state gate.
- **Bootsnap**: works in any load order. Bootsnap caches the original
  bytecode, and Lowrail serves its lowered bytecode.
- **Frozen string literals** (`# frozen_string_literal: true` or
  [Freezolite](https://github.com/ruby-next/freezolite)): fewer allocations,
  but mutating a literal then raises. Enable it only after your suite passes
  with it. Lowrail compiles each file with the same options the app's loaders
  use ([loaders.md](docs/loaders.md)).

## Docs

| Read | For |
|---|---|
| [PLAN.md](docs/PLAN.md) | goals, contract, why this design |
| [ARCHITECTURE.md](docs/ARCHITECTURE.md) | pipeline, pass contract, registry |
| [DECISIONS.md](docs/DECISIONS.md) | what is pursued, parked or rejected, plus the stacking backlog |
| [STATUS.md](docs/STATUS.md) | dated evidence log |
| [compat.md](docs/compat.md) | pinned real apps, gem breadth, baseline failures, load-order findings and verify results |
| [bench.md](docs/bench.md) | measurement protocol and results |
| [types.md](docs/types.md) | typed facts, MCP and RBS |
| [docs/passes/](docs/passes/) | one study per pass or idea |
| [rails-suite.md](docs/rails-suite.md), [ar-equivalence.md](docs/ar-equivalence.md) | framework-suite and Active Record gates |

## Acknowledgements

Lowrail stands on other people's work. Thank you to the authors and
maintainers of:

- [Roundhouse](https://github.com/rubys/roundhouse) (Sam Ruby): the
  inspiration for this project, its lowering pipeline and unsupported-code
  ledger, whole-program typing without annotations, the MCP tools, and the
  real-blog fixture we still use as our first corpus app.
- [Prism](https://github.com/ruby/prism) and its `ruby-prism` crate (Kevin
  Newton and the Ruby core team): parsing.
- [Rubydex](https://github.com/Shopify/rubydex) (Shopify): code indexing and
  its arena/typed-ID design.
- [Ruby](https://github.com/ruby/ruby), YJIT and ZJIT: the VM, `RubyVM::InstructionSequence`
  and the JITs we measure under.
- [Rails](https://github.com/rails/rails), [Zeitwerk](https://github.com/fxn/zeitwerk)
  and [Bootsnap](https://github.com/rails/bootsnap): the framework, loader and
  cache Lowrail has to stay exact with.
- Loader prior art: [require-hooks](https://github.com/ruby-next/require-hooks)
  and [Ruby Next](https://github.com/ruby-next/ruby-next) (Vladimir Dementyev),
  [Yomikomu](https://github.com/ko1/yomikomu) (Koichi Sasada),
  [Vernacular](https://github.com/kddnewton/vernacular) (Kevin Newton),
  [Tapioca](https://github.com/Shopify/tapioca) and
  [Freezolite](https://github.com/ruby-next/freezolite) ([loaders.md](docs/loaders.md)).
- [Inertia Rails](https://github.com/inertiajs/inertia-rails),
  [Herb](https://github.com/marcoroth/herb) and
  [ReActionView](https://github.com/marcoroth/reactionview).
- The open-source apps in our corpus: [Campfire](https://github.com/basecamp/once-campfire),
  [Fizzy](https://github.com/basecamp/fizzy), [Writebook](https://github.com/basecamp/writebook),
  [CASA](https://github.com/rubyforgood/casa), [CodeTriage](https://github.com/codetriage/codetriage),
  [PingCRM](https://github.com/ledermann/pingcrm),
  [Redprints CFP](https://github.com/evilmartians/redprints-cfp),
  [Inertia React starter kit](https://github.com/inertia-rails/react-starter-kit),
  [Wikino](https://github.com/wikinoapp/wikino),
  [RubyToolbox](https://github.com/rubytoolbox/rubytoolbox) and
  [Fat Free CRM](https://github.com/fatfreecrm/fat_free_crm).
- [Valgrind](https://valgrind.org/)'s Callgrind, which makes our instruction
  counts reproducible.

## License

MIT, see [LICENSE](LICENSE).
