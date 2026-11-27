# Ruby 4.1 differential against 4.0.9: census app suites on 4.0.9 and master (2026-11-27)

Ruby 4.1 ships on 2026-12-25. This round runs each census app's own test suite on Ruby 4.0.9 and on Ruby master with the same app, lockfile and Rails, and compares outcomes per test (result and exception class). It reuses `script/ruby-differential` ([round 1](ruby41-differential-1.md)), with the light apps added to its `APPS`, and compares two builds with [`cross.rb`](../../bench/upstream/ruby-differential/cross.rb) and new warning lines with [`warnings.rb`](../../bench/upstream/ruby-differential/warnings.rb). The heavy apps (Discourse, Mastodon, Sure, Loomio, CASA, Lobsters, Chatwoot, Flow, Lago, Docuseal) run in a parallel slice, [ruby41-differential-409-heavy.md](ruby41-differential-409-heavy.md). Nothing was posted, filed or pushed outside Lowrail.

## Pins

* Ruby master [`f3e180b5eb`](https://github.com/ruby/ruby/commit/f3e180b5eb) (2026-11-27 09:42 UTC) and Ruby 4.0.9 from tag `v4.0.9` (`3e93b23afc`), both release builds from `script/ruby-differential build` (`--enable-zjit --enable-yjit`, the same GCC and rustc 1.100.0).
* Apps as in round 1 (Campfire, Writebook and Fizzy on their Rails 8.2 pins; the rest through `script/census setup --corpus censusrd` on Rails main `cf0325a832` with the master overlays). Each Ruby uses a byte-identical copy of the same lock, so gems and Rails are equal.
* Modes: `interp`, `yjit` (compared with 4.0.9 in the same mode), `interpw` (`-W:deprecated`, for warning lines), and master `zjit` against 4.0.9 `interp` as a diagnostic column. Seed 41231, one worker.

## Light slice: no outcome differences

| App | Tests | 4.0.9 = master (interp, yjit, interpw) | master zjit vs 4.0.9 interp |
| --- | ---: | --- | --- |
| Blog | 21 | identical | identical |
| Campfire | 634 | identical | identical |
| CodeTriage | 219 | identical | identical |
| Fizzy | 1,787 | identical (4 errors on both: `CGI.parse` removed from cgi on Ruby 4.0, webmock) | identical |
| Writebook | 310 | identical (1 known `request_uri` error on both) | identical |
| Hackatime | 794 | identical | identical |
| Thinkroom | 833 | identical (3 app failures on both) | identical |
| React starter kit | 35 | identical | identical |
| Redprints CFP | 50 | identical (3 app failures on both) | identical |

36 of 36 comparisons show 0 differing tests ([`cross-409.json`](../../bench/upstream/ruby-differential/runs/2026-11-27-vs409-master-f3e180b5eb/cross-409.json)). React starter kit and Redprints needed round 1's `rspec_rails_fix.rb` (Rails main's frozen `default_url_options`), on both Rubies. Lobsters stops in `harness prepare` (`User has no attribute prefers_color_scheme`, round 1's known Rails-main error) and runs in the heavy slice on its own Rails. PingCRM has only Selenium system tests and is not in the correctness set.

New warnings on master, every one from a gem and every one a deprecation, not an error: mocha 3.1.0 (`alias` of `method` falling back to Object, Bug #22276; owned by open freerange/mocha#804) and skylight 7.1.1 (the same for `singleton_class`). Both were already in [round 3](ruby-master-round-3.md).

## Finding 1: stubbing ENV with Mocha raises on master (MO1)

Reported by the heavy slice from Sure (`Provider::JevTest`, 2 tests: pass on 4.0.9, `Ractor::IsolationError` on master in interp, yjit and zjit), and confirmed here with a standalone Minitest file ([`mocha_env_stub_test.rb`](../../bench/upstream/ruby-differential/repros/mocha_env_stub_test.rb)): 4.0.9 passes, master raises `can't modify instance variables of a shareable Object`.

* **Cause.** [Bug #22291](https://bugs.ruby-lang.org/issues/22291) (jhawthorn, `73055acd57`, 2026-09-16) forbids instance variables on objects that are shareable but not frozen; `ENV` is one. Mocha's `ObjectMethods#mocha` keeps the stubbed object's mock in `@mocha` (mocha 3.1.0 and main `99da677165`). First bad commit `73055acd57` (heavy slice, miniruby bisect); its parent passes.
* **Ownership.** A deliberate spec change. Matz accepted it asking to "check the impact on existing code that sets instance variables on it"; jhawthorn's survey found only environment_helpers. Mocha is not mentioned there, and freerange/mocha has no issue or PR on this (searched shareable, Ractor, IsolationError, ENV).
* **Reach.** Every Mocha suite that stubs ENV; current callers include [Sure](https://github.com/we-promise/sure/blob/12cd4e1a57f029d4ff59cce5dda7950d08221940/test/models/provider/jev_test.rb#L359-L360) (18k stars, 10 test files) and [Capistrano](https://github.com/capistrano/capistrano/blob/b54b02fa0ecdf18fad97e7ccbacd4b8d4e342c83/spec/lib/capistrano/configuration/servers_spec.rb#L275-L276) (13k stars). Mocha has 101.6M downloads. rspec-mocks does not store ivars on ENV and is unaffected.
* **Fix.** Mocha keeps the mock of a shareable non-Module object in an identity Hash (`ObjectMethods::SHAREABLE_MOCKS`), set and cleared where `@mocha` was. Queue item [MO1](../../bench/upstream/pr-queue/items/MO1.md); patch [evidence/mocha-env](../../bench/upstream/ruby-differential/evidence/mocha-env). Units and acceptance pass on 4.0.9 and master with it; without it only the 3 new acceptance tests fail on master.

Redmine note, optional, for Thomas to decide (on Bug #22291, not a new ticket):

> Heads-up in case it's useful: Mocha keeps a stubbed object's mock in an instance variable, so `ENV.stubs(:[])` and `ENV.expects` now raise `Ractor::IsolationError` in Mocha 3.1.0. A fix for Mocha is ready to propose.

## Performance

In progress: per-workload Callgrind instructions (`script/cpu-census`, fixed heap, A/A pair per Ruby) for interp, YJIT and ZJIT with the JIT-flat gate, now extended to ZJIT in `cpu_harness.rb`.
