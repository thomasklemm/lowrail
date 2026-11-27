---
id: MO1
repo: freerange/mocha
fork: thomasklemm/mocha
kind: fix
area: lib/mocha/object_methods.rb (ObjectMethods#mocha, #reset_mocha)
reviewer: floehopper
branch: thomasklemm/stub-shareable-env
head: "a3134958dc38c52d9c498a09d9bcd269184ee1dd"
base: main
built_on: "99da677165"
tracker: []
depends_on: []
stacked_on:
alternative_of:
evidence: [bench/upstream/ruby-differential/evidence/mocha-env, bench/upstream/ruby-differential/repros/mocha_env_stub_test.rb]
impact: "Ruby 4.1: ENV.stubs / ENV.expects raise Ractor::IsolationError in every Mocha suite (Mocha 3.1.0 and main), because Ruby master forbids ivars on unfrozen shareable objects (Bug #22291, 73055acd57) and Mocha keeps a stubbed object's mock in @mocha. Found by the 4.0.9-vs-master census differential: Sure's Provider::JevTest (2 tests) pass on 4.0.9 and error on master in every mode. The fix keeps the mock of a shareable non-Module object in an identity Hash instead."
rank: 1
risky: true
state: in-review
note: "2026-11-27 (after thermos-sol on 2db1c86782, verdict changes): new head a3134958dc (b5c60e0b12 plus trailing blank lines stripped from the message; same tree) applies its two code must-fixes: mocha() has explicit create and read branches for shareable objects (no assignment inside an if-modifier), and the helper keeps one why-comment (classes and modules can still have instance variables when shareable); the Ruby 4.1 background stays in the commit message (unchanged). Its third (version labels) was already applied after Astra. On that tree: rake test 457/448 0 failures on 4.0.9 and master, test:isolated 128 files, minitest and test-unit integration, lint clean; with only the old object_methods.rb restored, exactly the 3 new acceptance tests fail on master; the ENV repro passes on master in interp, YJIT and ZJIT. Astra approved 2db1c86782 (labels confirm); confirm passes on a3134958dc requested from both. 2026-11-27 (after Astra on 3d3f63b4c1): new head 2db1c86782, tree identical (git diff 3d3f63b4c1 2db1c86782 empty), message identical without the Amp-Thread-ID trailer (amended with script/commit, signed); patch regenerated. Body: Capistrano cited at v3.20.1 (f40817b449) and Sure at v0.7.6-hotfix.2 (c241a66da7), Capistrano first; the 'same as before on every Ruby' sentence cut; risky: true (Ractor/memoization). Confirm passes requested from thermos-sol and Astra on 2db1c86782. Thomas (via coordinator, 2026-11-27) authorized fork, push and opening ready with maintainer edits once both approve the exact head. Redmine note on Bug #22291: not sent, Thomas 2026-11-27: Mocha zu wenig relevant. 2026-11-27: built and tested in orb T-01a21ca4-eb07-7134-a138-0909fab59394 on mocha main 99da677165 (the fork does not exist yet; the patch is evidence/mocha-env/0001-*.patch, `git am` on 99da677165 gives 3d3f63b4c1). Not pushed, nothing posted. Ruby side: deliberate spec change; matz accepted Bug #22291 asking to check impact on code that sets ivars on ENV; jhawthorn's survey (note 6) found only environment_helpers; Mocha not mentioned; no Redmine, mocha issue or PR on this (searched shareable, Ractor, IsolationError, ENV). Tests: rake test (units 457, acceptance 448) 0 failures on 4.0.9 and master f3e180b5eb with the fix; on master without it the 3 new acceptance tests fail (and only those); test:isolated 128 files pass on master; minitest and test-unit integration suites pass on master; rake lint clean. Sure's failing tests pass with the fix on the load path. Callers checked for the body (DECISIONS 2026-11-27 citation rule): we-promise/sure 18.2k stars, pushed 2026-11-27; capistrano/capistrano 13.0k stars, pushed 2026-11-02, uses Mocha as its RSpec mock framework. Discourse's code search hits were stale (none on main 5eb2603b38). mocha: 1.28k stars, 101.6M downloads, 3.1.0 released 2026-03-14, last push 2026-09-22. Related, separate: mocha's other 4.1 warning (alias of 'method' falling back to Object, Bug #22276) is owned by open freerange/mocha#804."
passes:
  - {reviewer: astra, orb: T-01a21cf3-0e32-7607-8de3-82fe7c0058b5, head: "3d3f63b4c136e807c6f532f97fc90794080ba364", date: 2026-11-27, verdict: changes, open: "No supported-behavior regression demonstrated in 37 differential scenarios; all requested suites pass on both Ruby pins. Must fix: remove the candidate commit's Amp trailer; cite Capistrano 3.20.1 at its release commit, name the Sure ref and order callers by reach; cut the universal equivalence claim (three demonstrated private-helper collisions, accepted by the checklist but contradicting that claim); set risky true. Exact-head evidence, commands, full results and limits: bench/upstream/ruby-differential/evidence/mocha-env/astra-review.md and astra-review.tar.gz."}
  - {reviewer: astra, orb: T-01a21cf3-0e32-7607-8de3-82fe7c0058b5, head: "2db1c867821c6ea4af94348c772afacd62c6e519", date: 2026-11-27, verdict: changes, open: "Limited confirm: regenerated patch applies to the identical reviewed tree b415c4733d630d458bf9be4ccfe889851ff63ac1; message matches except removed Amp trailer and has no trailers; caller SHAs/lines and ordering verified by fresh raw fetches; blanket equivalence claim removed; risky true. Sole remaining must-fix from the prior citation finding: body link labels still say only Capistrano and Sure. Name the releases in the link text, Capistrano 3.20.1 and Sure v0.7.6-hotfix.2, as DECISIONS requires. No new code finding; suites not rerun for unchanged code. See astra-review.md confirmation section."}
  - {reviewer: astra, orb: T-01a21cf3-0e32-7607-8de3-82fe7c0058b5, head: "2db1c867821c6ea4af94348c772afacd62c6e519", date: 2026-11-27, verdict: approve, open: "None. Body-only confirmation: labels now name Capistrano 3.20.1 and Sure v0.7.6-hotfix.2; previously verified URLs and their order are unchanged. Diff since the preceding confirm changes only these labels; candidate patch and head are unchanged. All prior Astra must-fixes are closed. Prior exact-tree verification and full-suite evidence remain applicable; no suite rerun for this text-only correction."}
---

# Keep mocks of shareable objects such as ENV out of instance variables

On Ruby master (4.1), stubbing a method on `ENV` raises:

```ruby
ENV.stubs(:[]).with("API_KEY").returns("secret")
# Ractor::IsolationError: can't modify instance variables of a shareable Object
```

Ruby 4.1 no longer allows instance variables on objects that are Ractor-shareable but not frozen ([Bug #22291](https://bugs.ruby-lang.org/issues/22291)), and `ENV` is one. Mocha keeps a stubbed object's mock in `@mocha`, so every `ENV.stubs` and `ENV.expects` fails. Tests in [Capistrano 3.20.1](https://github.com/capistrano/capistrano/blob/f40817b449c113a4fce039a318b92e63e1d10c85/spec/lib/capistrano/configuration/servers_spec.rb#L275-L276) and [Sure v0.7.6-hotfix.2](https://github.com/we-promise/sure/blob/c241a66da7634118b485a9ee561f7c94bbe4efc3/test/models/provider/jev_test.rb#L359-L360) do this.

For such objects the mock now lives in a Hash keyed by identity, set and cleared where `@mocha` was. Classes and modules are shareable but still take instance variables, so they keep `@mocha`, as does every other object.
