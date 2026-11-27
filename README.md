# Lowrail

**Lowrail measures real open-source Rails apps on Rails main and upstreams small, exact fixes for the avoidable work
it finds**: in Rails, in Ruby and ZJIT, and in the gems apps use (Rack, drivers, inertia-rails, hashie and others).
Results are allocation and instruction counts against the same code without the change, each with an A/A control; no
request speedup is claimed. If you came here from a PR, [method.md](docs/upstream/method.md) explains where its
numbers come from.

Until November 2026 Lowrail was a prototype that lowered Rails apps to specialized Ruby. That engine is
[paused](#paused-the-lowering-engine).

## What it does

1. **Measure.** [`script/census`](docs/upstream/census.md) moves about 20 open-source apps (Mastodon, Discourse,
   Lobsters, Chatwoot, Campfire, Fizzy, Writebook and others) onto one pinned Rails main commit, runs their request,
   job and mailer workloads on Ruby 4.0.9 and pinned Ruby master (interpreter, YJIT, ZJIT), and counts objects per
   source line, every round as an A/A pair. ZJIT stats passes and app-suite differentials run beside it.
2. **Find.** Lines are ranked by how many apps reach them, then by cost. Open and closed upstream PRs on a line are
   searched before anything is built.
3. **Fix.** The smallest change that behaves exactly as before for every caller, checked by a differential harness
   and the project's own suites, priced with [`script/upstream-bench`](docs/upstream/body-numbers.md) (objects and
   Callgrind instructions per call, base measured twice) and on ruby-bench, then reviewed before it opens.
4. **Upstream.** Candidates wait in the [PR queue](bench/upstream/pr-queue/README.md); `script/pr-queue` opens one
   only when its repository has room and every review pass approves the exact head.

Counted on 2026-11-27 (PRs opened since 2026-05-01, GitHub search): 84 merged in rails/rails and 17 in ruby/ruby, and
more in Rack, Prism, sqlite3-ruby, hashie, inertia-rails, ruby-bench and other gems. The
[contributions ledger](docs/upstream/contributions.md) lists every merged, open and closed PR with its measured result
and caveats, and the candidates investigated and not submitted, with the reasons. Our merged Rails PRs measured
together save 5.48% of allocations across 104 workloads in eleven apps
([combined effect](docs/upstream/combined-effect.md), round 3).

## Reproduce

Requirements: Git, [mise](https://mise.jdx.dev), network access, and the services an app needs (see
[census.md](docs/upstream/census.md#services-and-apps)). The Blog needs none:

```sh
git clone https://github.com/thomasklemm/lowrail && cd lowrail
mise exec -- script/census setup --rails main --apps blog     # app copy on Rails main, smoke-tested
mise exec -- script/census run --label base --aa --apps blog  # A/A pair: base and base2
mise exec -- script/census rank --label base2                 # Rails lines by breadth, then objects
mise exec -- script/census compare --base base2 --aa base     # the A/A noise floor
```

Omit `--apps` for every app; measure a Rails branch under a new label with `--rails OWNER/REPO@BRANCH`. Each report
under [docs/upstream/](docs/upstream/) lists its pins and commands.

## Your own app

Both tools read `lowrail/workloads.rb`, your requests in the words of an integration test
([format](docs/upstream/census.md#workloads-file)), and count work, not time.

**`lowrail-profile`** is a gem without lowering code that runs inside your app: your own suite (or the workloads
file) with exact allocation counts per request, job, mail and Action Cable action, by source line in your code and in
the Rails, Ruby and gem code it calls, with the upstream PRs that change a costly line. It is 0.1.0.rc1 and not on
rubygems.org yet; supported: Ruby 3.3–4.0, Rails 7.2–8.1, Linux and macOS ([gem/README-profile.md](gem/README-profile.md)).

```ruby
gem "lowrail-profile", git: "https://github.com/thomasklemm/lowrail", glob: "gem/lowrail-profile.gemspec", group: [:development, :test], require: false
```

```sh
bundle exec lowrail-profile -- bin/rails test                  # your suite, run twice (or: -- bundle exec rspec)
bundle exec lowrail-profile --record -- bin/rails test         # ... and write its frequent requests as lowrail/workloads.rb
RAILS_ENV=production bundle exec lowrail-profile --workloads   # the file's GETs, warmed, full stack (writes: --allow-writes)
bundle exec lowrail-profile compare base/report.json head/report.json --aa base2/report.json
```

Reports land in `tmp/lowrail-profile/`. `compare` is a report, not a CI gate in 0.1: it exits 0 whatever it lists and
2 when the captures are not valid evidence. `--record` applies the app's `filter_parameters`; check the file for
secrets before committing it. Run `--workloads` only against disposable databases, queues and mail delivery
([profile.md](docs/profile.md#run-it)).

**`script/census app`** (this repository, on a copy of your app) is the measurement: production mode, warmed, an A/A
pair, instructions when the patched Valgrind is built, and `--rails main` for what an upgrade changes. Your checkout is
only read; it refuses what it cannot run safely.

```sh
mise exec -- script/census app ~/src/myapp --init        # a starter lowrail/workloads.rb from the routes
mise exec -- script/census app ~/src/myapp --rails main  # measure the file on the app's Rails and on main
```

## Measuring speed

Instruction counts under Callgrind with a fixed heap and passing A/A controls are the primary evidence; YJIT and ZJIT
numbers count only when every window passes the JIT-flat gate. The protocol is [docs/bench.md](docs/bench.md); build
its pinned Valgrind once with `script/bench-valgrind PREFIX`.

* **Per call**, for a PR body: `script/upstream-bench --base TREE --candidate TREE … SCRIPT`
  ([usage](docs/upstream/body-numbers.md)) measures base twice in every cell and prints no change inside its A/A.
* **Per request**: `bench/request_pairs.rb APP OUTDIR GET:/path` with `BENCH_COUNTER=callgrind BENCH_HEAP_MODE=fixed`
  runs rotated off/on rounds in warm processes; `BENCH_VARIANT_APP` names the patched copy
  ([example](bench/upstream/hotline_candidates/README.md)).
* **`lowrail bench APP --pass NAME`** is the paused Rust CLI's wrapper around that driver. It prices lowering passes
  and refuses a build with no lowered units, so upstream work calls the driver directly.

## Where the records live

| Record | Where |
| --- | --- |
| Rules in force and why | [docs/DECISIONS.md](docs/DECISIONS.md); history in [decisions-archive.md](docs/decisions-archive.md) |
| Upstream PRs, results, caveats | [docs/upstream/contributions.md](docs/upstream/contributions.md) |
| Prepared PRs, review passes, state | [bench/upstream/pr-queue/items/](bench/upstream/pr-queue/items) (`script/pr-queue status`) |
| Census rounds, bets, leads | [docs/upstream/](docs/upstream/) (index of bets in [DECISIONS](docs/DECISIONS.md#bets)) |
| Raw data behind body numbers | `bench/upstream/<topic>/`, named in each queue item's `evidence:` |
| Explainers per open PR | [docs/upstream/explainers.md](docs/upstream/explainers.md) |
| lowrail-profile design and release | [docs/profile.md](docs/profile.md), [profile-release-plan.md](docs/profile-release-plan.md) |

## Paused: the lowering engine

The Rust core in `src/` (Prism via `ruby-prism`, Rubydex) and the lowering runtime in `gem/` (`lowrail.gemspec`,
`lowrail/setup`) boot an app, learn what is fixed after boot, and install guarded, specialized Ruby for what they can
prove equivalent. The default build lowers nothing, and no whole-request YJIT gain was established, so Lowrail turned
to upstream fixes on 2026-11-02, and the engine has been paused since 2026-11-27: it stays in the tree unchanged and
is not developed. Its plan and contract are in [docs/PLAN.md](docs/PLAN.md), its results, commands and reference in
[docs/prototype.md](docs/prototype.md), its decisions in [decisions-prototype.md](docs/decisions-prototype.md).

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
