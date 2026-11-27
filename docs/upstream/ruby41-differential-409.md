# Ruby 4.1 differential against 4.0.9: census app suites on 4.0.9 and master (2026-11-27)

Ruby 4.1 ships on 2026-12-25. This round runs each census app's own test suite on Ruby 4.0.9 and on Ruby master with the same app, lockfile and Rails, and compares outcomes per test (result and exception class). It reuses `script/ruby-differential` ([round 1](ruby41-differential-1.md)), with the light apps added to its `APPS`, and compares two builds with [`cross.rb`](../../bench/upstream/ruby-differential/cross.rb) and new warning lines with [`warnings.rb`](../../bench/upstream/ruby-differential/warnings.rb). The heavy apps (Discourse, Mastodon, Sure, Loomio, CASA, Lobsters, Chatwoot, Flow, Lago, Docuseal) ran in a parallel slice, [ruby41-differential-409-heavy.md](ruby41-differential-409-heavy.md). Nothing was posted, filed or pushed outside Lowrail.

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

## Heavy slice: four master-only differences, two of them Ruby regressions

Details in [ruby41-differential-409-heavy.md](ruby41-differential-409-heavy.md). Per mode, same counts on both Rubies (interp, yjit, interpW, plus master zjit against 4.0.9 interp): Discourse 22,128, Sure 14,236, Flow 9,714, Mastodon 7,748, Loomio 3,660, CASA 2,992, Lobsters 927, Docuseal 107; Lago interp only, 20,484 common tests, identical. Chatwoot not run (commonmarker 0.23.12 does not build on master; the C-branch port was declined; develop still locks it). Each difference below fails 3/3 alone on master in interp, yjit and zjit and passes 3/3 on 4.0.9; none is JIT-specific.

| Difference | Cause | Verdict |
| --- | --- | --- |
| Flow, 1 test: `Time.iso8601` keeps Feb 30 | `77d0d22b59` (time 0.5.0) reaching Bug #21301 | Finding 2, fixed by TN1 (ruby/ruby#20208, ready) |
| Sure, 2 tests: `Ractor::IsolationError` from Mocha `ENV.stubs` | `73055acd57`, Bug #22291, intentional | Finding 1, MO1 (freerange/mocha#809) |
| Discourse, 17 tests: `FrozenError` from `sub!` on `Symbol#to_s` | `2c574ca7e2`, Feature #22137, intentional; 4.0.9 `-W:deprecated` warns 17x | App bug, still on Discourse main |
| CASA, 1 test: child `ruby -rrspec/core` activates master's newer default erb/json before bundler/setup | Default-gem bumps plus the test's load order | Not a Ruby bug |

Flakes that pass alone on both Rubies: Discourse x16, Mastodon `featured_tag` x2 (Redis), Flow `WorkspaceSignupTicketTest` (urlsafe token split on `--`, ~12% on both), Lago `clickhouse_rake_spec` (hour boundary). New warnings on master are deprecations only: alias fallback to Object (Feature #22276) in mocha, Loomio, active_model_serializers, mini_sql and irb 1.18.0 (fixed in 1.19.0), and aliasing a method from a prepended module (Bug #22273) in Discourse's `safe_buffer.rb`.

## Finding 1: stubbing ENV with Mocha raises on master (MO1)

Reported by the heavy slice from Sure (`Provider::JevTest`, 2 tests: pass on 4.0.9, `Ractor::IsolationError` on master in interp, yjit and zjit), and confirmed here with a standalone Minitest file ([`mocha_env_stub_test.rb`](../../bench/upstream/ruby-differential/repros/mocha_env_stub_test.rb)): 4.0.9 passes, master raises `can't modify instance variables of a shareable Object`.

* **Cause.** [Bug #22291](https://bugs.ruby-lang.org/issues/22291) (jhawthorn, `73055acd57`, 2026-09-16) forbids instance variables on objects that are shareable but not frozen; `ENV` is one. Mocha's `ObjectMethods#mocha` keeps the stubbed object's mock in `@mocha` (mocha 3.1.0 and main `99da677165`). First bad commit `73055acd57` (heavy slice, miniruby bisect); its parent passes.
* **Ownership.** A deliberate spec change. Matz accepted it asking to "check the impact on existing code that sets instance variables on it"; jhawthorn's survey found only environment_helpers. Mocha is not mentioned there, and freerange/mocha has no issue or PR on this (searched shareable, Ractor, IsolationError, ENV).
* **Reach.** Every Mocha suite that stubs ENV; current callers include [Capistrano](https://github.com/capistrano/capistrano/blob/f40817b449c113a4fce039a318b92e63e1d10c85/spec/lib/capistrano/configuration/servers_spec.rb#L275-L276) (13k stars, v3.20.1) and [Sure](https://github.com/we-promise/sure/blob/c241a66da7634118b485a9ee561f7c94bbe4efc3/test/models/provider/jev_test.rb#L359-L360) (18k stars, v0.7.6-hotfix.2). Mocha has 101.6M downloads. rspec-mocks does not store ivars on ENV and is unaffected.
* **Fix.** Mocha keeps the mock of a shareable non-Module object in an identity Hash (`ObjectMethods::SHAREABLE_MOCKS`), set and cleared where `@mocha` was. Queue item [MO1](../../bench/upstream/pr-queue/items/MO1.md); patch [evidence/mocha-env](../../bench/upstream/ruby-differential/evidence/mocha-env). Units and acceptance pass on 4.0.9 and master with it; without it only the 3 new acceptance tests fail on master.

Redmine note on Bug #22291, drafted and **not sent** (Thomas, 2026-11-27: Mocha zu wenig relevant):

> Heads-up in case it's useful: Mocha keeps a stubbed object's mock in an instance variable, so `ENV.stubs(:[])` and `ENV.expects` now raise `Ractor::IsolationError` in Mocha 3.1.0. A fix for Mocha is ready to propose.

## Finding 2: Time.iso8601 keeps impossible dates on master (time 0.5.0; covered by TN1)

Reported by the heavy slice from Flow (`runner_protocol_conformance_test.rb`, one test, fails on master in every mode). On master `Time.iso8601("2026-02-30T00:00:00Z")` returns a Time whose fields read February 30 (`iso8601` prints `2026-02-30T00:00:00Z`), while its instant is March 2; time 0.4.2 on 4.0.9 gives 2026-03-02. First bad commit `77d0d22b59` "[ruby/time] Optimize Time.xmlschema" (time 0.5.0, the default gem 4.1 ships), which now calls `Time.new(string)` and so inherits [Bug #21301](https://bugs.ruby-lang.org/issues/21301) (open; [Bug #22375](https://bugs.ruby-lang.org/issues/22375) reports this very `Time.iso8601` case and is marked its duplicate).

Cases ([evidence/time-iso8601](../../bench/upstream/ruby-differential/evidence/time-iso8601)): with `Z`/UTC and the date-only form master keeps day 30 or 31 in the fields (wrong `iso8601`, `mon`, `day`; right `to_i`); with `+09:00` all three agree; with `-05:00` master is right and 4.0.9 was two days early. Master with only TN1's `time.c` (head `2e061793aa`, our draft ruby/ruby#20208 on top of khasinski's #16469) gives the March/May dates in every case, so no new item: the fix exists and is in review. What this adds for Thomas: since time 0.5.0 the bug reaches `Time.iso8601`/`Time.xmlschema` on every Ruby 4.1, which strengthens the case for landing #16469/#20208 before 2026-12-25; Thomas approved a one-sentence body update to #20208 naming it; done 2026-11-27, and the PR is marked ready (TN1).

## Finding 3: backtrace location formatting is ~25% slower and raises on NUL paths (BT1)

Found from the perf matrix: react-starter-kit `GET home` (+9% interp Ir, A/A 0.35%) grew in `Rack::Test::CookieJar#for` and `Net::HTTP#connect`, both on lines that build a backtrace (Vite's dev-server probe raises `ECONNREFUSED` and re-raises with a message). Reduced to `caller`/`Exception#backtrace` on a 150-frame stack ([evidence/backtrace-format](../../bench/upstream/ruby-differential/evidence/backtrace-format)): 861,187 Ir per `caller` on 4.0.9, 1,088,976 on master (+26%), 849,991 with the fix; a raise without a backtrace is unchanged (45k vs 47k).

* **Cause.** `b9ad19da12` (nobu, "Format backtrace locations as Ruby strings", merged in ruby/ruby#17882, 2026-07-15) makes `location_format` use `"%"PRIsVALUE`, so each file and method name goes through `ruby__sfvextra` (`rb_obj_as_string`, `rb_enc_compatible`, `StringValueCStr`). `StringValueCStr` also raises `ArgumentError` for a path with a NUL byte: `eval("raise 'boom'", nil, "a\0b.rb")` has no printable backtrace on master (4.0.9 truncated at the NUL).
* **Ownership.** Nothing on Redmine or in ruby/ruby PRs about backtrace speed or NUL paths since 2026-07; open #17978 (Bug #22197) touches labels, not `location_format`.
* **Fix.** Append both strings by length with `ruby__sfvextra`'s encoding choice (`vm_backtrace.c` +20/-2, a test, `benchmark/vm_backtrace_to_s.yml`): `make benchmark` 1.18x over master, back to 4.0.9; react-starter-kit `GET home` -2.0% in-app (A/A 0.3%); a 2,728-case encoding probe is byte-identical to master; NUL paths now print in full. Queue item [BT1](../../bench/upstream/pr-queue/items/BT1.md), branch `thomasklemm/backtrace-format-length` on the fork, not opened; thermos-sol and Astra reviews running.

## Performance

Per-workload Callgrind instructions (`script/cpu-census run --aa`, fixed heap, A/A pair per Ruby, JIT-flat gate for YJIT and ZJIT in `cpu_harness.rb`).

**Interpreter, 6 censusrd apps, 54 workloads (complete):** median +0.56%; 10 flagged slower (beyond 2x A/A and 1%), 4 faster. The largest, blog `GET articles` (+5.9%) and react-starter-kit `GET home` (+9.0%), move with warmup count on both Rubies (blog master 10.21M at warmup 200, 9.68M at 600; 4.0.9 9.62M/9.57M): glibc malloc state (`malloc_consolidate`, `_int_malloc`) under the fixed heap, not Ruby code; not reported. What remains attributed to Ruby: Finding 3 (react-starter-kit, hackatime `GET dashboard` via the same backtrace lines), and `String.new` without arguments +174 Ir (12%) in the interpreter since `14285dee21` (byroot, "Optimize `String.new(capacity:)`", deliberate; `String.new(capacity:)` and `encoding:` got 10-20% faster), worth +0.8% on thinkroom `GET api doc`; not a regression report.

**YJIT, 6 censusrd apps:** 9 of 45 workloads pass the JIT-flat gate in all four runs (the rest still compile in the measured window on at least one run and are excluded, per docs/bench.md). Of those 9, median -1.22%; 1 flagged slower, codetriage `perform SendSingleTriageEmailJob` +1.31% (A/A 0.13%), 5 faster. react-starter-kit is missing one 4.0.9 run (`GET /settings/sessions` got HTTP 302 during warmup in one of four runs; to rerun after the matrix). No YJIT regression worth a bisect so far.

**ZJIT:** running (`pall` service); census41 apps (Campfire, Writebook, PingCRM) follow. Fizzy is not in the perf set: `script/census setup --corpus census41` on Rails main `cf0325a832` fails in `harness prepare` with `SystemStackError` from the app's own `config/initializers/uuid_primary_keys.rb` (its `build_schema_context` override calls `primary_key`, which on Rails main builds the schema context again); an app/Rails-main interaction, independent of Ruby.
