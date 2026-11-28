# slack-ruby-client: the Hashie warning override is dead under Hashie 6 (SRC1)

Found in round 2 of the hashie work ([record](../hashie_perf/round2/README.md)) while checking which dependents
allow hashie 6. Queue item: [SRC1](../pr-queue/items/SRC1.md). No performance claim is made here.

## What is wrong

`Slack::Messages::Message < Hashie::Mash` is the class of every Web API response (`connection.response :mashify,
mash_class: Slack::Messages::Message`). Since 2017 (slack-ruby-client issue 132, commit `ffef2a8`) it silences
Hashie's warning about keys that are also method names by overriding the private `log_built_in_message` with an empty
method. Hashie 6.0.0 (2026-11-11) renamed that method to `_log_built_in_message` (hashie commit `9f7c514`), so the
override is never called and the warning is back:

```
$ bundle exec ruby -Ilib -e 'require "slack-ruby-client"; Slack::Messages::Message.new("file" => { "size" => 1 })'
# hashie 5.2.0, slack-ruby-client master 0f1757e: no output
# hashie 6.0.0, slack-ruby-client master 0f1757e:
W, [...]  WARN -- : You are setting a key that conflicts with a built-in method Slack::Messages::Message#size defined in Hash. This can cause unexpected behavior when accessing the key as a property. You can still access the key via the #[] method.
```

The gemspec has `s.add_dependency 'hashie'` without a constraint, and faraday-mashify allows any hashie, so a fresh
`bundle install` on Ruby 3.0 or newer resolves hashie 6.0.0.

## Searched first (2026-11-28)

* slack-ruby/slack-ruby-client: no open or closed issue or PR names the dead override or hashie 6. Issue 132 (closed
  2017-02-09) is the original warning, fixed then by the override. Issues 294 and 371 are open and unrelated. No PRs
  are open. The latest number is 619, so the PR would be 620.
* GitHub code search for `def log_built_in_message` outside vendored hashie copies finds two projects: this one and
  phacks/notion-ruby-client (`lib/notion/messages/message.rb`), which is not part of this item.
* `lib/` has one `Hashie::Mash` subclass, `Slack::Messages::Message`; nothing in `lib/` subclasses `Message`.

## The fix

Branch `thomasklemm/message-disable-warnings` on thomasklemm/slack-ruby-client, head
`dfbf7013bfaf7abf982a09ef29d732e6b452de71`, one commit on master `0f1757e` ([patch](head-dfbf701.patch)):

* `Message` calls `disable_warnings`, Hashie's public switch, and the private override and its comment go.
* The gemspec requires `hashie >= 3.5.3`.
* `spec/slack/messages/message_spec.rb` expects no `Hashie.logger.warn` when a `Message` is built with a `size` key.
* A CHANGELOG line for #620, and `thomasklemm` in `.spellcheck.txt` (the lint task spell-checks contributor handles).

### Why `>= 3.5.3` (my decision)

| hashie | what `disable_warnings` does |
| --- | --- |
| before 3.5.2 | does not exist (`NameError` on 3.5.0 and 3.5.1; 3.4.6 has no `Hashie.logger` either) |
| 3.5.2 | exists, but subclasses do not inherit it: a subclass of `Message` warns (1,528 of 2,880 rows differ) |
| 3.5.3 (2017-02-11) | subclasses inherit it (hashie commit `9636f68`): no row differs |
| 4.0.0 | takes method names (`disable_warnings(:zip)`) |

An earlier head (`54c6b98`) required 3.5.2, the floor omniauth and zendesk_api use; the differential on 3.5.2 showed
the subclass difference, so the floor moved to 3.5.3.

## Suites ([out/matrix.txt](out/matrix.txt))

`matrix.sh RUBY [full] -- VERSIONS...` pins hashie through a Gemfile that evaluates the tree's own, and runs the new
spec and, with `full`, `rake spec`, on master `0f1757e` with the new spec copied in ("slack-base") and on the head.

| Ruby | hashie | master + new spec | head |
| --- | --- | --- | --- |
| 3.4.7 | 3.5.3, 3.6.0, 4.1.0, 5.0.0, 5.1.0, 5.2.0 | 702 examples, 0 failures | 702, 0 |
| 3.4.7 | 6.0.0 | 702, **1 failure** (the new spec) | 702, 0 |
| 3.0.7 | 5.1.0 | 699, 0 | 699, 0 |
| 3.0.7 | 6.0.0 | 699, **1 failure** (the new spec) | 699, 0 |
| 4.0.9 | 6.0.0 | 702, **1 failure** (the new spec) | 702, 0 |
| 3.4.7 | 3.5.0, 3.5.1, 3.5.2 | new spec passes | bundler refuses (below the floor) |
| 3.4.7 | 3.4.6 | new spec errors (`Hashie.logger` is missing) | bundler refuses |

`bundle exec rake lint` on the head (Ruby 3.4.7, hashie 6.0.0): 105 files inspected, no offenses.
Not run: Ruby 2.7 (slack-ruby-client's CI runs it; hashie 6 needs Ruby 3.0, so 2.7 resolves hashie 5), JRuby,
ruby-head.

## Differential ([out/diff-summary.txt](out/diff-summary.txt), rows in `out/diff-rows.tar.xz`)

`run_diff.sh RUBY VERSIONS...` runs [message_diff.rb](message_diff.rb) on both trees: four classes (`Message`, a plain
subclass, a subclass with its own method, a subclass that calls `disable_warnings(:zip)`; the last only from hashie
4.0.0), 3 seeds, 16 keys, 10 operations (new, `[]=`, setter, merge, update, dup, read, `to_s`, `to_hash`, `to_json`),
frozen and not. A row is the result, its class, the message afterwards and the warnings logged, or the exception.

| Ruby | hashie | rows | rows that differ | which |
| --- | --- | ---: | ---: | --- |
| 3.4.7 | 3.5.3, 3.6.0 | 2,880 | 0 | |
| 3.4.7 | 4.1.0, 5.0.0, 5.1.0, 5.2.0 | 3,840 | 726 | only the `disable_warnings(:zip)` subclass |
| 3.0.7 | 5.1.0 | 3,840 | 726 | only the `disable_warnings(:zip)` subclass |
| 3.4.7, 3.0.7, 4.0.9 | 6.0.0 | 3,840 | 2,316 | `Message` 764, subclass 764, subclass with own method 788 |

In every cell the rows differ only in the warning count: results, classes, the message afterwards and exceptions are
the same.

* **Hashie 6.0.0:** master warns and the head does not, which is the fix. The `disable_warnings(:zip)` subclass is the
  same on both (it warns for keys other than `zip`), because the override is dead on master.
* **Hashie 4.0.0 to 5.2.0, one behaviour difference:** a subclass of `Message` that itself calls
  `disable_warnings(:zip)` replaces the inherited "all keys" with its own list, so on the head it warns for other
  conflicting keys; on master the override kept it silent whatever the subclass declared. Nothing in the gem does
  this; an application's own subclass could.
* **A subclass that overrides `log_built_in_message` and calls `super`:** on hashie 6.0.0 master warns once and the
  head does not; on hashie 3.5.3 to 5.2.0 neither warns.
* **Reflection differs as intended:** `disable_warnings?` is true on the head, and the private
  `log_built_in_message` is no longer defined on `Message`.
* **Ractor:** building a `Message` in a non-main Ractor gives the same result on master and head in every cell: it
  works on hashie 3.5.3, raises `Ractor::IsolationError` with or without a conflicting key on 3.6.0 and 4.1.0, and
  raises it only for a conflicting key on 5.2.0 and 6.0.0, with warnings disabled or not.

## Astra SRC1: changes on dfbf7013bfaf7abf982a09ef29d732e6b452de71

2026-11-28, thread `T-01a2221b-8e76-742f-8bca-1918a5fb40a4`. Reviewed directly, without delegation.
Base: `0f1757ebd856c2fea0ba168420fdaddecec8bf5c`; fetched fork head and upstream master matched these SHAs.
Evidence: [astra-SRC1-dfbf701.tar.gz](astra-SRC1-dfbf701.tar.gz). The archive contains scripts, dependency locks,
raw stdout/stderr, API responses and `source-checks.txt`; it contains no timing or performance claim.

### Findings and smallest fix

1. **R1 — real exception regression on Ruby 3.0.7 / Hashie 3.5.3 and 3.5.4.** After requiring the gem:

   ```ruby
   Ractor.new { Slack::Messages::Message.new('size' => 7).to_hash }.take
   ```

   Master returns `{"size"=>7}`; head raises `Ractor::RemoteError`, caused by `Ractor::IsolationError` in
   `Hashie::Mash.disable_warnings?`: Ruby 3.0 disallows reading class instance variables outside the main Ractor.
   The deleted no-op previously bypassed that read. `repros.rb ractor`, `ractor-3.0.7.txt` and the 3.0.7
   adversarial rows reproduce it; the minimal script warms one message on the main Ractor first, but warming is
   not required. A caller constructing messages inside a Ractor can hit this without overriding any method.
   Ractors are experimental in this Ruby, and no affected application was found; nevertheless this is a newly
   failing operation on a declared-supported Ruby/dependency combination, not just different warning output.
   It does not reproduce with Hashie 3.5.3 on the tested Ruby 3.1.7 and newer. The earlier Ractor summary above
   must not be read as covering this previously untested cell.

2. **R2 — the selective-warning boundary is public and needs disclosure if retained.** On Hashie 4.0.0,
   4.1.0, 5.0.0, 5.1.0 and 5.2.0:

   ```ruby
   klass = Class.new(Slack::Messages::Message) { disable_warnings(:zip) }
   klass.new('size' => 7)
   ```

   Master is silent; head warns. `Slack::Messages::Message.quiet(:zip).new('size' => 7)` also reaches this,
   without writing a subclass declaration. With `Hashie.logger` set to an object whose `warn` raises
   `IOError, 'logger failed'`, master returns the message and head raises; `repros.rb partial-error` is the
   minimal reproducer. An application using Hashie's documented selective setting or `quiet` can hit it;
   nothing in this gem itself does so, and no downstream application using this combination was established.
   The warning is consistent with the caller's explicit setting, so accepting it is reasonable, but silently
   omitting it from this exact body is not. Smallest text if it stays: “Subclasses that explicitly disable only
   selected warnings now follow Hashie's setting for other conflicting keys.” Hashie 6 already behaves this
   way on master; the change is confined to the older versions tested.

3. **R3 — `impact` overstates the trigger.** On Hashie 6 master,
   `Slack::Messages::Message.new('empty?' => true)` does not warn, although `empty?` is a Mash/Hash method.
   `repros.rb impact-counterexample` checks the method's existence and captures empty logger output. Also,
   the real 500 response path raises before mashification; not every response becomes a `Message`.
   Replace “every Slack Web API response with a key that is also a Mash method” with “Slack Web API responses
   containing conflicting keys such as a file's size”. The file-size example itself is verified.

**Recommended code correction:** retain the original private `def log_built_in_message(*); end` alongside the
new `disable_warnings` call. Do not add an override of `_log_built_in_message`. The five-line scratch
`retain-legacy.rb` restores R1 and R2 while the Hashie 6 body example stays silent (`proposed-fix.txt`).
This is a compatibility shim with demonstrated callers, not a speculative second override. No fork file was
changed. If that correction is applied, R2 needs no boundary sentence because its difference disappears;
R1 should have a regression check on Ruby 3.0. A changed head needs another pass.

### Floor and API judgment

`>= 3.5.3` is the right minimum for a change relying on inherited warning configuration. `git show` of
Hashie 3.5.1/3.5.2/3.5.3 and commit `9636f68`, the README's documented subclass example, and the executed
3.5.2/3.5.3 probes establish why. 3.5.2 supplies the method but fails to carry the setting into subclasses.
The 3.5.2 direct-load probe intentionally bypasses the head's dependency constraint; it is not a successful
installation of that head.

The constraint **does reject previously resolving setups**: the retained runtime Gemfile with `hashie = 3.5.2`
resolves on master and fails resolution on head (`floor-resolution.txt`, both bundle logs). A lock or another
dependency requiring `< 3.5.3` must change before upgrading. That is an explicit, justified minimum-version
change, not evidence that a Ruby release was dropped: Ruby 2.7.8 resolves and runs with 3.5.3 and 5.1.0;
Hashie 6 refuses Ruby 2.7 on both trees because its own requirement is Ruby >= 3.0. An unpinned Ruby 3.0.7
bundle actually selected Hashie 6 on both trees (`unpinned-3.0.7.txt` and its lockfiles).

Prefer the documented `disable_warnings` API over following a renamed internal helper. Hashie labels it
`@api semipublic`, but exposes it as a public Ruby method and documents it in the README; the body's “public
setting” is defensible. Keeping the *old* no-op for the demonstrated compatibility cases does not require
following future private renames. The new code otherwise reads plainly, and the only added spec comment is
the repository's frozen-string directive; there are no superfluous added comments.

### Runs and limits

* `run.sh 3.4.7 3.5.2 3.5.3 3.6.0 4.0.0 4.1.0 5.0.0 5.1.0 5.2.0 6.0.0` and a second invocation for
  3.5.4–3.5.7 ran the exact new spec, original `message_diff.rb`, and the independent `adversarial.rb` on
  both trees. Thus every released Hashie version from 3.5.3 through 6.0.0 was exercised on Ruby 3.4.7.
* `install-run.sh` ran the same checks on Ruby 3.0.7 (3.5.3–3.5.5, 3.5.7, 3.6.0, 5.1.0, 6.0.0),
  Ruby 3.1.7, 3.2.9, 3.3.10 and 4.0.9 (3.5.3, 5.2.0, 6.0.0). Ruby 2.7.8 ran the independent probe
  and exact new spec on 3.5.3, 4.1.0 and 5.1.0; the original probe uses endless methods unavailable on 2.7.
* In all runnable cells the new spec passes on head. On master it fails **only with Hashie 6**, on the
  forbidden `Hashie.logger.warn` call for the nested file's `size`, not loading or an unrelated assertion.
  The initial Ruby 4 run lacked `ostruct` in the scratch test bundle; those failures are retained separately,
  and adding this test-only dependency allowed the actual spec to run. No upstream workaround was applied.
* Ruby 3.4.7 / Hashie 6: `bundle exec rspec spec` produced **699 examples, 1 failure** on master plus the
  new spec, and **699 examples, 0 failures** on head. `SuiteGemfile` retains runtime and test dependencies,
  but excludes release tooling, so the three conditional release-tool specs did not run. These are not
  claimed as the original record's 702-example full-development bundle. No new lint or hosted CI claim.
* The independent probe covers subclasses/grandchildren, a public conversion prepend, dynamic method lookup,
  Hash/Array/String subclasses, frozen values and receivers, singleton conversion with call traces, mutation
  during input iteration, a yielding conversion fiber, concurrent construction, reload and raising loggers.
  `load-order.rb` additionally tests standalone require, Hashie/Mash first, logger before/after loading and
  concurrent requires. Bare `require 'slack/messages/message'` without Hashie fails equally on both trees.
  Result values, nested classes, identity, exceptions and warning counts are retained separately.
* `Slack::Web::Client` with WebMock intercepting only the HTTP transport exercised the actual
  `connection.response :mashify, mash_class: Slack::Messages::Message` stack and faraday-mashify: `files.info`,
  `rtm.connect`, `rtm.start`, API errors, 429, 500 and malformed JSON. Values and error envelopes match;
  the Hashie 6 warning disappears where the message reaches mashification. No real Slack request was made.
* There is **no RealTime client on either exact tree**: `Slack::RealTime::Client` raises `NameError` on both.
  `git show e5e4983`, UPGRADING and README establish removal in 2.0.0. The remaining RTM Web endpoints above
  are not a claim of testing an RTM socket client. JRuby, Ruby master/ZJIT and other patch releases were not run.

Other demonstrated differences are improvements, not reasons to retain bugs: `Class.new(Message).freeze.new('size'
=> 7)` changes from `FrozenError` to a message on tested Hashie 3.5.6–6.0.0 / Ruby 3.4.7; a frozen subclass is
a possible application setup. On Ruby 3.4.7 / Hashie 3.5.6, 3.5.7 and 3.6.0, a Ractor constructing only `size`
now succeeds instead of raising, but nonconflicting keys can still hit Hashie's unshareable suffix constant.
Nested probes therefore cannot establish blanket Ractor support. On Hashie 6 a raising warning logger stops
breaking ordinary Message construction, an intended consequence of removing the warning. Each is in
`comparison.txt`; `repros.rb frozen`, `ractor` and `adversarial.rb` retain the minimal/isolated cases.

### Sentence-by-sentence claim check and currency

| Text checked | Executed or opened evidence; result |
| --- | --- |
| Title: fixes Hashie 6 warnings for Message | Exact new spec on both trees; `repros.rb body`; actual Web response path. Correct. |
| Body first sentence and printed warning | `repros.rb body` on Hashie 6 master emits the quoted message, apart from the intentionally omitted timestamp/process prefix; head is silent. The archived issue 294 also shows a real file-size key. |
| Body: silenced since issue 132 using private override | GitHub issue 132 and comments; `git show ffef2a8` adds the private no-op and names 132. Correct. |
| Body: Hashie 6 renamed it in Hashie PR 639, so override is bypassed | GitHub PR 639 and its complete files; merged commit `9f7c5148b75124a5e7eb488f7e15c5f0c3f917a9` renames both definition and call. `git tag --contains` returns only v6.0.0; v5.2.0 still uses the old name. Correct; first shipped in 6.0.0. |
| Body: calls the public setting instead | Exact diff, Hashie README's `disable_warnings` example, public method invocation. Correct with the semipublic annotation noted above. |
| Body: subclasses inherit from 3.5.3; gemspec previously unconstrained, now requires that version | Exact gemspec diff, `git show 9636f68`, version-tag sources and subclass probes. Correct as “at least 3.5.3”; selective reconfiguration needs R2's disclosure. |
| Body: new spec fails on master with 6 and passes with 5 | Independently executed exact spec on the cells above; confirmed for 5.0.0, 5.1.0 and 5.2.0. |
| Commit subject and both paragraphs | Same direct-load repro, source diff, inherited-setting probe and dependency resolution establish every sentence; no timing claim. |
| CHANGELOG: fix, minimum version, contributor, prospective number 620 | Exact diff and commit author Thomas Klemm; spec and resolver above. Latest public issue/PR is 619, no open PRs: 620 is the apparent next number, not reserved or guaranteed against another submission. Recheck at opening. |
| Impact: 6.0.0 released 2026-11-11, resolves on Ruby >= 3.0; 96M downloads | RubyGems version metadata and live downloads below; actual unpinned Ruby 3.0.7 resolution. Correct. The universal “every” trigger is contradicted by R3. Remaining API/minimum/rename claims are checked above. |

All API snapshots are dated 2026-11-28 (the main facts refresh at 12:29:55 UTC). Reach, in descending downloads:

| Project | GitHub stars | RubyGems total downloads | Latest release | Last GitHub push |
| --- | ---: | ---: | --- | --- |
| hashie/hashie | 3,035 | 507,129,000 | 6.0.0, 2026-11-11 | 2026-11-27 |
| slack-ruby/slack-ruby-client | 1,259 | 96,277,616 | 3.4.0, 2026-11-24 | 2026-11-24 |
| sue445/faraday-mashify | 4 | 26,818,049 | 1.0.3, 2026-08-23 | 2026-11-07 |

Sources are `gh api repos/OWNER/REPO`, `https://rubygems.org/api/v1/gems/NAME.json` and
`https://rubygems.org/api/v1/versions/NAME.json`, executed by retained `facts.sh`. None of these repositories is archived.
Faraday-mashify has few stars but is the actual declared response middleware and has substantial downloads;
it is relevant evidence, not a niche example added to inflate reach. The body is about its own gem and
Hashie, rather than a list of downstream projects needing reordering.

Searches of all-state Slack issues/PRs for `hashie`, `log_built_in_message`, `disable_warnings` and conflict
warnings, plus the latest issues and all open PRs, found no report or fix for this Hashie 6 regression.
Issue 132 is the historical warning; open 294 concerns `file.size` versus `file['size']`, and 371 proposes
OpenStruct. Neither fixes this. At the captured head, Actions runs and check-runs both return zero; absence
of hosted CI is not a passing result. The exact body, impact and record need the corrections above before opening.
