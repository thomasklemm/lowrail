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
`66b1ec68dd3996621d229d3f6d6e53406c37c586`, one commit on master `0f1757e` ([patch](head-66b1ec6.patch)):

* `Message` calls `disable_warnings`, Hashie's public switch. The private `log_built_in_message` override stays, with
  a comment that says Hashie before 6.0.0 warns through it.
* The gemspec requires `hashie >= 3.5.2`.
* `spec/slack/messages/message_spec.rb` expects no `Hashie.logger.warn` when a `Message` is built with a `size` key.
* A CHANGELOG line for #620, and `thomasklemm` in `.spellcheck.txt` (the lint task spell-checks contributor handles).

### Heads

| head | shape | why it was replaced |
| --- | --- | --- |
| `54c6b98` (not pushed) | `disable_warnings`, override removed, hashie `>= 3.5.2` | on hashie 3.5.2 a subclass of `Message` warned: subclasses inherit the setting only from 3.5.3 |
| `dfbf701` | same, hashie `>= 3.5.3` | Astra, verdict changes ([below](#astra-src1-changes-on-dfbf7013bfaf7abf982a09ef29d732e6b452de71)): R1, on Ruby 3.0.7 with hashie 3.5.3 or 3.5.4 a `Message` with a conflicting key built in a Ractor raised where master worked; R2, on hashie 4.0.0 to 5.2.0 a subclass with `disable_warnings(:zip)` or `Message.quiet(:zip)` warned for other keys, and raised when the logger raised. Both reproduced here before the head changed. |
| `66b1ec6` | `disable_warnings` added, override kept, hashie `>= 3.5.2` | current |

### Why the override stays and the floor is `>= 3.5.2` (my decisions)

With the old no-op kept, Hashie before 6.0.0 takes the same path as on master, so R1 and R2 are gone and no sentence
about them is needed in the body; Hashie 6.0.0 never calls the old method and is silenced by `disable_warnings`. The
head does not override the renamed `_log_built_in_message`.

`disable_warnings` does not exist before hashie 3.5.2 (`NameError` on 3.5.0 and 3.5.1), so that is the lowest floor
that loads. Subclasses inherit the setting only from 3.5.3 (hashie commit `9636f68`), which is why `dfbf701` required
3.5.3; with the override kept, a subclass on 3.5.2 is silent through the override, as on master (0 of 2,880 rows
differ). 3.5.2 rejects fewer setups that resolve today than 3.5.3 does. Both reviewers judged 3.5.3 right for
`dfbf701`; whether 3.5.2 is right for this head is theirs to judge again.

## Suites ([out/matrix.txt](out/matrix.txt))

`matrix.sh RUBY [full] -- VERSIONS...` pins hashie through a Gemfile that evaluates the tree's own, and runs the new
spec and, with `full`, `rake spec`, on master `0f1757e` with the new spec copied in ("slack-base") and on the head
`66b1ec6`.

| Ruby | hashie | master + new spec | head |
| --- | --- | --- | --- |
| 3.4.7 | 3.5.2, 3.5.3, 3.6.0, 4.1.0, 5.0.0, 5.1.0, 5.2.0 | 702 examples, 0 failures | 702, 0 |
| 3.4.7 | 6.0.0 | 702, **1 failure** (the new spec) | 702, 0 |
| 3.0.7 | 3.5.3, 5.1.0 | 699, 0 | 699, 0 |
| 3.0.7 | 6.0.0 | 699, **1 failure** (the new spec) | 699, 0 |
| 4.0.9 | 6.0.0 | 702, **1 failure** (the new spec) | 702, 0 |
| 3.4.7 | 3.5.0, 3.5.1 | new spec passes | bundler refuses (below the floor) |
| 3.4.7 | 3.4.6 | new spec errors (`Hashie.logger` is missing) | bundler refuses |

`bundle exec rake lint` on the head (Ruby 3.4.7, hashie 6.0.0): 105 files inspected, no offenses.
Not run here: Ruby 2.7 (Astra ran 2.7.8 on `dfbf701`; hashie 6 needs Ruby 3.0, so 2.7 resolves hashie 5), JRuby,
ruby-head. The fork's Actions do not run on a push, so there is no hosted CI result for this head.

## Differential ([out/diff-summary.txt](out/diff-summary.txt), rows in `out/diff-rows.tar.xz`)

`run_diff.sh RUBY VERSIONS...` runs [message_diff.rb](message_diff.rb) on both trees: five classes (`Message`, a plain
subclass, a subclass with its own method, a subclass that calls `disable_warnings(:zip)` from hashie 4.0.0, and
`Message.quiet(:zip)` from 4.1.0), 3 seeds, 16 keys, 10 operations (new, `[]=`, setter, merge, update, dup, read,
`to_s`, `to_hash`, `to_json`), frozen and not. A row is the result, its class, the message afterwards and the warnings
logged, or the exception.

| Ruby | hashie | rows | rows that differ | which |
| --- | --- | ---: | ---: | --- |
| 3.4.7 | 3.5.2, 3.5.3, 3.6.0 | 2,880 | 0 | |
| 3.4.7 | 4.1.0, 5.0.0, 5.1.0, 5.2.0 | 4,800 | 0 | |
| 3.0.7 | 3.5.3, 3.5.4 | 2,880 | 0 | |
| 3.0.7 | 5.1.0 | 4,800 | 0 | |
| 3.4.7, 3.0.7, 4.0.9 | 6.0.0 | 4,800 | 2,316 | `Message` 764, subclass 764, subclass with own method 788 |

* **Hashie before 6.0.0:** no row differs, the selective subclass and `quiet(:zip)` included (R2).
* **Hashie 6.0.0:** the rows differ only in the warning count: master warns and the head does not, which is the fix.
  The `disable_warnings(:zip)` subclass and `quiet(:zip)` are the same on both; they warn for keys other than `zip`,
  as Hashie 6 has them do on master already.
* **A subclass that overrides `log_built_in_message` and calls `super`:** on hashie 6.0.0 master warns once and the
  head does not; before 6.0.0 neither warns.
* **Reflection differs as intended:** `disable_warnings?` is true on the head. `log_built_in_message` is still a
  private method of `Message`.

### The reviewers' cases ([out/repro-summary.txt](out/repro-summary.txt), raw in `out/repro.txt`)

`repro.sh RUBY VERSIONS...` runs [repro.rb](repro.rb) on both trees: a plain and a nested `size` key, a frozen
subclass, a `disable_warnings(:zip)` subclass and `quiet(:zip)` with a normal and with a raising logger, and a
`Message` built in a Ractor with and without a conflicting key. Cells: Ruby 3.4.7 with hashie 3.5.2, 3.5.3, 3.5.4,
3.6.0, 4.0.0, 4.1.0, 5.0.0, 5.1.0, 5.2.0 and 6.0.0; Ruby 3.0.7 with 3.5.2, 3.5.3, 3.5.4, 5.1.0 and 6.0.0; Ruby 4.0.9
with 5.2.0 and 6.0.0.

* **R1 is gone:** Ruby 3.0.7 with hashie 3.5.2, 3.5.3 and 3.5.4: 0 of 5 cases differ; the Ractor with a `size` key
  returns `{"size"=>7}` on both.
* **R2 is gone:** on hashie 4.0.0 to 5.2.0 the selective subclass, `quiet(:zip)` and the raising logger give the same
  result on both.
* **What still differs before 6.0.0, both where master raises and the head does not:** a frozen subclass of `Message`
  given a `size` key raises `FrozenError` on master from hashie 3.6.0 to 5.2.0, because Hashie memoizes the
  subclass's setting on first use, and the head inherits it at definition; and on Ruby 3.4.7 with hashie 3.6.0 a
  Ractor with a `size` key raises `Ractor::IsolationError` on master for the same write.
* **Hashie 6.0.0:** the plain and nested keys stop warning, the frozen subclass stops raising, and a raising logger
  is no longer reached for a plain `Message`.

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

## thermos-sol SRC1: changes on dfbf7013bfaf7abf982a09ef29d732e6b452de71

2026-11-28, orb `T-01a2221b-855f-7661-a87e-59f64efb922f`. Applied both Thermos rubrics directly in this thread,
without delegating or creating other threads, as requested. The exact fork head has one commit on
`0f1757ebd856c2fea0ba168420fdaddecec8bf5c`; the kept patch and fetched head have the same stable patch ID
`388bbcc90b86098c1b73339737088d722e8f9fec`. No fork push, upstream PR, comment, or upstream workflow was triggered.

**Verdict: changes for a compatibility regression and text.** Keep `disable_warnings` and `hashie >= 3.5.3`, but
retain the original legacy no-op as well. My initial main-Ractor matrix supported a documentation-only verdict;
the concurrent Astra review arrived during rebase and identified an untested Ruby 3.0/old-Hashie combination.
I independently reproduced it and the smallest correction below before publishing this pass. There is also a
public selective-warning boundary if the original deletion stays, and an overstatement in `impact`.

### Findings and smallest fixes

1. **P2: retain the legacy no-op to preserve Ruby 3.0 Ractor construction.** On Ruby 3.0.7/Hashie 3.5.3 and 3.5.4, after
   requiring the gem:

   ```ruby
   Ractor.new { Slack::Messages::Message.new('size' => 17).to_hash }.take
   ```

   Base returns `{"size"=>17}`; head raises `Ractor::RemoteError`, caused by `Ractor::IsolationError` in
   `Hashie::Mash.disable_warnings?`. Ruby 3.0 forbids this class-instance-variable read outside the main Ractor;
   the original private no-op bypassed it. `bash scripts/late_cells.sh 3.0.7 3.5.3 ractor` runs the actual full
   project bundle, without warming a message first, and retains the exception stack. A real caller constructing
   messages in a Ractor can hit it without a monkeypatch; no downstream application was established, and Ractor
   is experimental on this Ruby. The smallest code fix is to retain the original private
   `def log_built_in_message(*); end` alongside `disable_warnings`, not add `_log_built_in_message`. A scratch
   preload of that exact old method restores the result. This is a concrete compatibility shim, not a reason to
   follow further private renames. Credit for discovering this cell belongs to the concurrent Astra pass.
   The same driver with `4.0.9 6.0.0 body` confirms the original nested file example remains silent with the shim.

2. **P2: disclose selective warnings in the body and README if retaining their changed behavior.** Not just subclasses:
   applications can call the documented public setting on `Message` itself, or use `Message.quiet(:zip)`. On
   Hashie 4 and 5, the old no-op override still suppressed every conflict warning after a selective setting;
   the head obeys that setting. A real application using custom message classes or configuring `Message` can hit it.
   This follows Hashie's documented setting, but is not an implementation-only detail. Minimal repro, run on base
   and head (`scripts/warnings.rb` in the archive captures it):

   ```ruby
   require 'slack-ruby-client'
   Slack::Messages::Message.disable_warnings(:zip)
   Slack::Messages::Message.new('zip' => 11, 'size' => 17)
   ```

   With Hashie 4.0.0, base logs nothing; head logs one `#size` warning and no `#zip` warning, storing both values
   unchanged. The same subclass and `quiet` behavior is in the extended differential. Hashie 6 already behaves this
   way on base, so this is not another Hashie 6 regression. Smallest fix: replace the body's final test-status
   sentence with “On Hashie 4 and 5, calling `disable_warnings` with specific keys now allows warnings for other
   conflicting keys, including in subclasses.” Add the same configuration boundary to README's Message Handling
   section. No new README heading/TOC entry or UPGRADING section is necessary; an optional floor note can accompany it.
   The concurrent Astra pass additionally pointed out a raising logger; my `late_cells.sh 4.0.9 5.2.0 selective`
   confirms that a custom `warn` raising `IOError, 'logger failed'` changes this from a returned message on base to
   an exception on head. Restoring the old hook as in finding 1 removes both the warning and exception difference,
   so no boundary sentence is needed if that correction is chosen.

3. **P3: qualify `impact`'s “every ... key that is also a Mash method.”** On base/Hashie 6, `size` logs once, but
   `empty?` logs zero times, although both methods belong to Hash and both values are stored (`scripts/impact.rb`).
   Hashie deliberately excludes predicate/other affixed method names. A caller constructing a Message with such a key
   can hit it; no current Slack endpoint emitting that predicate key was established. This is an overbroad internal
   claim, not an additional bug: use “responses with conflicting keys, such as a file's size.”

One further demonstrated **warning-only load-order boundary**, not a must-fix: predeclare
`Slack::Messages::Message < Hashie::Mash`, then a child, before requiring the gem (`scripts/load_order.rb`). On
Hashie 3.5.3, the early child warns once on head versus zero on base; a child declared after require stays silent.
The flag is copied at inheritance, whereas the old instance-method override is inherited dynamically. This requires
predeclaring the gem-owned class before loading it, not ordinary `require` then subclassing. No supported caller for
that predeclaration was established. Normal loaded-class reload, subclasses with their own methods, and unrelated
Mash subclasses created before and after require were also exercised. This boundary alone would not justify
compatibility plumbing; finding 1 supplies a supported-version construction failure that does.

One non-warning **improvement**, also suggested by Astra and independently reproduced: on Ruby 4.0.9/Hashie 3.5.6,
`Class.new(Slack::Messages::Message).freeze.new('size' => 17).to_hash` raises `FrozenError` on base and returns
`{"size"=>17}` on head. A caller can freeze a message subclass; this is not a new failure or a reason to undo the fix.
`late_cells.sh 4.0.9 3.5.6 frozen` records both trees and the retained-hook variant, which also succeeds.

### Correctness, security, and exactness

The original 14-cell extended main-Ractor probes found no changes to message values, classes, Marshal bytes, copy
behavior, or exceptions after removing the warning field. The targeted follow-up above demonstrates the exception
boundaries that matrix missed; full-suite success is not proof of those cases. `scripts/extended.rb` covers the actual
`Slack::Web::Client#auth_test` response stack using Faraday's test adapter, nested hashes/arrays, custom Hash/Array/
String subclasses, duck-typed inputs, singleton conversion methods and call traces, a prepended writer, mutation
across a suspended Fiber, frozen inputs/receivers, `dup`, `clone`, Marshal round trips/defaults/default-proc errors,
custom loggers, public selective configuration, and reload. `scripts/middleware.rb` independently runs the real
faraday-mashify JSON stack over mixed top-level arrays and nested arrays; values and classes match. The Slack
wrapper's pre-existing rejection of top-level array/scalar bodies is the same on both trees, not a new finding.

The existing `message_diff.rb` was also rerun, unmodified, including its Ractor and private-super probes. Its ordinary
operation rows match after removing warning counts. The new probe records full exception strings and Marshal bytes
that the original does not. A custom `Hashie.logger` remains the same object; its explicit application warning and
the conflict warnings of base `Hashie::Mash` and unrelated pre/post-load subclasses remain available. No global
logger silencing or security/feature-gate change was found. Reflection/configuration changes are intentional.

The exactness checklist's user-method/conversion, subclass, ownership/copy, mutation/Fiber, frozen/error, and
load/configuration boundaries were checked in those probes; no new runtime guard or calls on message payloads were
added. Private-hook overrides are not a preservation contract. This is not a claim about every possible monkeypatch.

There is **no current RealTime client or its models to exercise**: `git ls-tree` contains no such code;
`defined?(Slack::RealTime)` is nil on both trees. The actual removal is commit `e5e4983` merged by PR 573;
UPGRADING says 3.0.0. README's historical “2.0.0” is an existing inconsistency, left untouched. The retained Web API
`rtm.*` endpoints are covered by the ordinary suite, but are not a RealTime client.

### Floor, test, and maintainability decisions

`scripts/floors.sh` executes the tagged Hashie sources: 3.5.1 cannot load the head because the setting does not
exist; 3.5.2 silences Message but not a normal child; 3.5.3 silences both. Commit `9636f68` adds the inheritance hook
and first appears in tag v3.5.3. A full-Gemfile install pinned to 3.5.2 succeeds on base and Bundler correctly refuses
head. Raising the floor intentionally requires applications pinned below 3.5.3 to update Hashie. The gemspec is the
right place to express that requirement; this project previously raised its Faraday minimum for a dependency bug
in commit `c0168ae`. No Ruby floor increase, fallback runtime branch, or upper Hashie bound is needed.

The cold read of the head is one sentence: Message asks Hashie to suppress its conflict warnings, and the gemspec
ensures that subclasses inherit the setting. This is simpler than adding a second version-sensitive logging override,
but deleting the original override is not exact on the demonstrated Ruby 3.0 Ractor path. Keep that old no-op for
compatibility and use the public switch for Hashie 6 rather than adding an underscore-hook override.
The warning policy belongs on Message, shared by direct construction, nested conversion, and faraday-mashify, not
in individual response consumers. No new helper, conditional, abstraction, or duplicated implementation was added.
Flog reports `to_s` 8.2 on both trees (total 9.2 on both); RuboCop Metrics reports no offenses before or after.
The largest touched file is CHANGELOG at 501 lines; no file-size boundary is crossed. The sole added comment is
the suite-standard frozen-string magic comment. The spec's `describe`, `described_class`, expectations, and logger
expectation match existing message and Web client specs. It checks warning emission and preserved bracket access,
not Hashie's private implementation. Selecting only `:zip` in a scratch preload makes the new spec fail on `size`,
so it catches a plausible wrong implementation as well as the original regression.

### Commands, results, and claim audit

Scripts, full raw logs, resolved Gemfiles/lockfiles, source/API snapshots and the sentence-by-sentence
`claim-checklist.md` are retained in
[`thermos-sol-SRC1-dfbf701.tar.gz`](thermos-sol-SRC1-dfbf701.tar.gz). The drivers evaluate each tree's own Gemfile,
copy only the new spec to base, use separate per-Ruby bundle paths, and record the selected Hashie and Ruby.

* `bash scripts/run.sh 4.0.9 VERSION all` and `bash scripts/extras.sh 4.0.9 VERSION`: Hashie 3.5.3, 3.6.0, 4.0.0,
  4.1.0, 5.0.0, 5.1.0 and 5.2.0, plus the separately run 6.0.0 cell. The 6.0.0 base full suite is 702 examples,
  one failure at `Hashie::Mash#_log_built_in_message`; head is 702/0. Earlier supported versions pass the new spec
  on both trees. The extended comparison and original differential summaries are in `out/extended-summary.txt`.
* After reading the concurrent Astra pass: `run.sh`/`extras.sh` with Ruby 3.0.7 and Hashie 3.5.3/3.5.4, plus
  Ruby 4.0.9/Hashie 3.5.6. All three added cells pass the new spec and full suites on both trees (699 examples
  on Ruby 3.0, 702 on Ruby 4.0); their main-Ractor extended comparisons match. The final matrix therefore contains
  17 cells, all full head suites passing. Separate `late_cells.sh` Ractor, selective, frozen and body modes record
  the differences above and test the smallest correction as a scratch preload, without changing the fork tree.
* `bash scripts/run.sh RUBY latest all` and `bash scripts/extras.sh RUBY latest`: Ruby 2.7.8 resolves Hashie 5.1.0,
  Faraday 2.8.1 and ActiveSupport 7.1.6; both trees pass all 699 examples, including the new spec. Ruby 3.0.7, 3.1.7,
  3.2.9, 3.3.10 and 3.4.7 resolve Hashie 6.0.0 from the unconstrained/full project Gemfile. Head suites pass
  (699 examples on 3.0–3.2, 702 on 3.3/3.4); base fails only the added warning spec. Therefore the declared Ruby
  2.7+ support, Gemfile conditionals, and tested MRI CI entries still resolve with the new floor.
* `bundle exec rake lint` on Ruby 4.0.9/Hashie 6.0.0: 105 files inspected, no offenses. The new-spec mutation run
  fails as intended with one `#size` warning. No warnings were suppressed to make a suite pass.
* `bash scripts/claims.sh`, fetched Git history/tags, RubyGems APIs and `scripts/warning_text.rb`: the title, all
  body/commit/CHANGELOG factual clauses, literal warning, “since #132,” rename in hashie/hashie PR 639, first release
  6.0.0 on 2026-11-11, public API visibility, original unconstrained gemspec and approximately 96M downloads were
  checked directly. The `impact` universal needs correction; the selective boundary needs text only if retained.
  The Ractor finding concerns the code's behavior, not a false factual sentence in the submitted text.
* Fresh all-state issue/PR searches for Hashie, the old hook, `disable_warnings`, and key conflicts found no existing
  current report/fix for this regression. Issue 132 is the historical fix; issues 294 and 371 concern different
  behavior. No PR is open. The highest visible issue/PR remains 619 and GET issue 620 is 404: **620 is still the
  expected next number**, not a reservation or a guarantee against invisible/deleted allocations. Recheck on opening.
* CONTRIBUTING, AGENTS, Dangerfile, README, UPGRADING, Gemfile, gemspec and CI workflows were read. The changelog's
  Next-section placement, retained placeholder, author link and spellcheck vocabulary follow the contribution rules.
  Danger checks changelog/TOC; hosted Danger cannot be claimed before a PR exists. No fork Actions runs, check runs,
  or commit statuses exist for this exact head (an empty status list's aggregate “pending” is not a running check).

Tooling/limits: historical mise lookups timed out and hit unauthenticated GitHub rate limits. The completed Ruby
2.7–3.1 checks use ruby/ruby-builder's Ubuntu 22.04 toolcache binaries, with download URLs, SHA-256 hashes and version
lines retained; source-build attempts are not counted as passing checks. The original differential uses Ruby 3
endless definitions, so Ruby 2.7 ran the compatible extended probe instead. A driver edit during the first Hashie
5.1.0 run caused a shell EOF after the suites completed; the entire cell was rerun cleanly in `out/rerun-5.1.0.txt`.
All final extended probes were rerun after adding nested-copy mutation, logger identity and live Fiber-mutation
checks. Their comparison reports no non-warning differences, and every original operation row compares equal after
removing warning counts. JRuby, Ruby master and ZJIT were not run; no performance conclusion is claimed.

## Astra SRC1 second pass: approve on 66b1ec68dd3996621d229d3f6d6e53406c37c586

2026-11-28, thread `T-01a2221b-8e76-742f-8bca-1918a5fb40a4`. Independently fetched the exact fork head,
checked its single commit against `0f1757ebd856c2fea0ba168420fdaddecec8bf5c`, and reran the probes; no delegation
or upstream writes. Evidence: [astra-SRC1-66b1ec6.tar.gz](astra-SRC1-66b1ec6.tar.gz), including the reviewed item,
scripts, locks, raw results, source checks and refreshed GitHub/RubyGems responses.

**R1, R2 and R3 are closed.** On Ruby 3.0.7 with Hashie 3.5.2, 3.5.3 and 3.5.4, the cold minimal
`Ractor.new { Slack::Messages::Message.new('size' => 7).to_hash }.take` returns `{"size"=>7}` on both trees.
Selective subclasses and `Message.quiet(:zip)` on Hashie 4.0.0–5.2.0 stay silent for `size`, including with a
raising warning logger; no selective-warning sentence is needed now. The narrowed impact no longer asserts
that every method-named key or every response reaches a warning. No new failing operation was found.

**The 3.5.2 floor is appropriate for this shape.** Actual bundles resolve on Ruby 2.7.8, 3.0.7 and 4.0.9
with Hashie 3.5.2; ordinary subclasses and grandchildren retain the no-op even though the setting itself does
not propagate in 3.5.2. Direct loading with 3.5.1 works on master but raises `NameError` for `disable_warnings`
on head, so a lower minimum would permit a broken installation. The 3.5.2 tag contains the method, and the
3.5.1 tag does not. Existing constraints below 3.5.2 are intentionally no longer compatible; unlike the
previous head, a 3.5.2 pin is accepted. No extra `_log_built_in_message` override is needed.

**No upstream Ractor spec is required for this correction.** The original implementation of the legacy
no-op is restored; this evidence retains the exact failing case and its successful rerun. A test that only
runs under the normal modern Hashie resolution would not catch R1. Useful ongoing coverage would require
an explicit old-Hashie/Ruby-3.0 dependency cell, not an unexercised conditional test or a mock of private
implementation. I do not make that matrix expansion a condition of this small fix. The new one-line comment
is useful: without it, the old override looks redundant beside `disable_warnings` and is easy to remove again.

**Remaining differences are not blanket equivalence.** On Ruby 3.4.7, `Class.new(Message).freeze.new('size'
=> 7)` stops raising `FrozenError` with Hashie 3.5.6–6.0.0. A Ractor constructing just `size` stops raising
with Hashie 3.5.6, 3.5.7 and 3.6.0; other keys still encounter existing Ractor limitations. On Hashie 6,
`Message.new('size' => 7)` no longer raises when `Hashie.logger.warn` raises, because it no longer logs.
These are reproduced improvements, not regressions to restore. The independent probe also tried creating
a subclass inside a Ruby 3.0.7 Ractor with Hashie 3.5.3: both trees already raise the same isolation error.
The earlier record's “same path” wording applies to the retained legacy warning override, not all class
configuration reads. Also, `quiet(:zip)` was exercised successfully on Hashie 4.0.0, not only 4.1.0 onward.

Correction to my first pass, identified by the concurrent Thermos review and verified against UPGRADING and
`git tag --contains e5e4983`: the RealTime client was removed in **3.0.0**, not 2.0.0 as README claims.
Its absence on both reviewed trees and the validation limit are unchanged.

Runs on **this exact head**, using the previous pass's independent harness plus the updated original probe:

* Ruby 3.4.7: every released Hashie version from 3.5.2 through 6.0.0; Ruby 2.7.8: 3.5.2, 3.5.3, 5.1.0;
  Ruby 3.0.7: 3.5.2, 3.5.3, 3.5.4, 5.1.0, 6.0.0; Ruby 4.0.9: 3.5.2, 5.2.0, 6.0.0.
* The exact new spec passes on head in every cell, and on master fails only with Hashie 6, on the nested
  file-size `warn` call. The original differential has zero changed operation rows before 6 and only warning
  counts changed on 6. The independent harness separately retains the exception differences above.
* Ruby 3.4.7 / Hashie 6, runtime/test-only bundle: `bundle exec rspec spec` gives 699 examples, 1 failure
  on master plus the new spec; 699 examples, 0 failures on head. Three conditional release-tool examples
  remain outside this bundle; no new lint claim. Ruby 3.1–3.3, JRuby and Ruby master/ZJIT were not rerun.
* Actual Slack/Faraday mashification, RTM Web endpoints, API errors, 429/500 and invalid JSON were exercised
  through WebMock again, together with subclasses, prepends, conversions, mutation, frozen inputs, threads,
  fibers and reload. Hashie/Mash-first, logger-before/after and concurrent requires were rerun at 3.5.2 and 6.

Changed-claim checks: the exact diff and `source-checks.txt` verify “also calls”, the retained private no-op,
absence of an underscore override, the formerly unconstrained gemspec and new `>= 3.5.2` requirement in body,
commit and CHANGELOG. Executed floor/subclass cases verify the revised minimum argument. Hashie's released
sources verify the comment's old warning entry point; its original issue-394 URL was opened via GitHub's API
and redirects to the genuine “Hashie warnings and Rails” issue. This is a necessary compatibility comment,
not an unnecessary implementation note. The spec executions verify the last body sentence. The historical
132/639 claims, warning text and project-currency reads were also rechecked; no unchecked changed claim remains.

The refreshed snapshot at **12:57:05 UTC** still has latest public Slack issue/PR **619** and no open PRs:
**620 is still the apparent next number**, subject to another submission. No existing Hashie-6 report/fix
was found. Hashie, slack-ruby-client and faraday-mashify retain the stars/downloads/latest-release/last-push
values recorded in the first pass's table; none is archived. Both check-runs and Actions runs on this exact
fork head are empty. Local approval is not a claim of hosted upstream CI.

## thermos-sol SRC1: changes on 66b1ec68dd3996621d229d3f6d6e53406c37c586

2026-11-28, orb `T-01a2221b-855f-7661-a87e-59f64efb922f`. Second pass, applying both Thermos rubrics directly
in this thread, without delegation. Reviewed the exact one-commit head against
`0f1757ebd856c2fea0ba168420fdaddecec8bf5c`, the complete updated SRC1 text, commit message, CHANGELOG and comment.
The fetched diff and kept patch have stable patch ID `0316aaca03fe2bb76ea98b40845d4f6bde45541d`.
The first-head pass and its archive above remain historical; this is not an approval of the new head.

### Must-fix: defining a Message subclass inside a Ractor can now raise

**P2, `lib/slack/messages/message.rb:5`:** the unconditional `disable_warnings` call changes Hashie's inheritance
hook even with the legacy instance-method override retained. On Ruby 3.4.7 with Hashie 3.5.3, and Ruby 4.0.9 with
Hashie 3.5.3, 3.5.4 and 3.5.5, the following returns `{"size"=>17}` on master but raises `Ractor::RemoteError`
caused by `Ractor::IsolationError` on this head:

```ruby
require 'slack-ruby-client'
ractor = Ractor.new { Class.new(Slack::Messages::Message).new('size' => 17).to_hash }
ractor.take # Ruby 3.4; use ractor.value on Ruby 4
```

Hashie's `inherited` sees the newly true flag and calls `subclass.disable_warnings`; that writes a class instance
variable in the non-main Ractor, raising `can not set instance variables of classes/modules by non-main Ractors`.
This needs no monkeypatch, private-method override or predeclaration of Slack's class. A caller dynamically defining
a message subclass inside a worker Ractor can hit it. No downstream app doing so was established, and Ractor remains
experimental; it is nevertheless a newly failing public subclass operation inside the requested Ruby/Hashie range.
The new spec and the main-Ractor differential do not exercise it. It is distinct from the first head's fixed
Ruby 3.0 direct-construction regression.

`bash scripts/ractor_subclass.sh RUBY HASHIE` retains the complete stack and both-tree results. Controls:
Hashie 3.5.2 succeeds on both trees (Ruby 3.0.7 and 4.0.9); Hashie 3.5.3/3.5.4 already fail on both trees on Ruby
3.0.7; Hashie 3.6.0 already fails on both on Ruby 3.4.7/4.0.9; Hashie 6 already fails on both on Ruby 4.0.9.
Where both fail, the flag can change the exception's internal site/message; these are not newly working-to-failing
paths. The archive records those differences rather than claiming blanket Ractor exactness or support.

**Smallest demonstrated correction:** call the public switch only on Hashie 6+, leaving older releases' working
hook and class state alone. `scripts/version_gate.rb` tests the one-line load-time condition
`disable_warnings if Gem::Version.new(Hashie::VERSION) >= Gem::Version.new('6.0.0')` entirely in a scratch preload.
It restores all four failing subclass cells. Four full variant suites also pass: Ruby 2.7.8/Hashie 3.5.2,
Ruby 3.0.7/3.5.3, Ruby 3.4.7/3.5.3 and Ruby 4.0.9/6.0.0, including the new warning spec. This does not repair
pre-existing Ractor failures, nor claim to. The unconditional call's `>= 3.5.2` floor is valid, but a 6+-only call
no longer needs that floor for API availability; reconsider the constraint and corresponding prose with that fix.
No fork file was changed. Do not add another `_log_built_in_message` override merely to follow the rename.

### Resolved first-pass findings and remaining behavior

Retaining the original no-op restores the first head's direct `Message.new` Ractor cases on Ruby 3.0.7/Hashie
3.5.3 and 3.5.4; the new minimum 3.5.2 succeeds too. It also restores all-key silence after public selective `disable_warnings(:zip)` and
`quiet(:zip)` on Message and its subclasses on Hashie 4 and 5, including a custom logger whose `warn` raises.
The first-pass body/README selective-warning sentence is therefore no longer needed. The narrowed `impact` fixes
the universal-key overstatement. The unsupported early predeclaration load-order difference is also gone.

Two demonstrated non-warning improvements remain, not blockers: on Ruby 4.0.9, a frozen Message subclass given
`'size' => 17` raises `FrozenError` on master but succeeds on head with Hashie 3.5.6 through 6.0.0; on Ruby 3.4.7
and 4.0.9 with Hashie 3.6.0, direct Message construction inside a Ractor changes from `IsolationError` to success.
The minimal expressions are `Class.new(Slack::Messages::Message).freeze.new('size' => 17).to_hash` and
`Ractor.new { Slack::Messages::Message.new('size' => 17).to_hash }` followed by take/value. Real callers can freeze
subclasses or construct messages in workers, but no actual downstream use was established. `late_cells.sh` records
both trees. Hashie 3.5.2–3.5.5 frozen-subclass controls already succeed on master.

### Correctness, security, tests and maintainability

`python3 scripts/validate.py` validates **24 passing full head suites and 25 matching extended data comparisons**.
Every Hashie release from 3.5.2 through 6.0.0 ran on Ruby 4.0.9; Ruby 2.7.8, 3.0.7, 3.1.7, 3.2.9, 3.3.10 and
3.4.7 ran the full project Gemfile's latest resolution, with minimum/compatibility cells including the new
3.4.7/3.5.3 cell. Ruby 2.7's latest resolution selects Hashie 5.1.0; both that cell and the pinned 3.5.2 cell pass all 699 examples.
Ruby 3.0+ resolves Hashie 6.0.0. Head suites have 699 or 702 examples, zero failures. Base, with only the unchanged
new spec copied over, fails only with Hashie 6, at the forbidden `#size` warning in `_log_built_in_message`.
Earlier versions pass that spec on both trees. A scratch `disable_warnings(:zip)` mutation with Hashie 6 fails the
spec as intended. Its nested bracket-value assertion also checks preserved data, and its style matches the suite.
The test protects the warning fix, not every subclass/Ractor configuration boundary.

The extended probe, original differential and real middleware probe cover the exactness checklist: Hash/Array/String
subclasses and duck types; singleton conversions, call traces and prepended writers; nested hashes and mixed arrays;
copy/Marshal bytes/defaults; custom logger identity and unrelated warnings; Fiber mutation, frozen/error cases,
reload and before/after-load subclasses. The actual Web client's Faraday test response path and the real
faraday-mashify JSON/mixed-array stack preserve values and classes; the expected Hashie 6 warning disappears.
All original ordinary-operation rows match before 6, and match after removing warning counts on 6. These comparisons
do not subsume the separately demonstrated Ractor-subclass regression. Base Mash and unrelated subclasses retain
their warnings. No added payload call, global warning suppression, security issue or feature-gate leak was found.
No RealTime client or its models exist at this base: the first pass verified their removal and the retained Web
`rtm.*` endpoints. No live Slack traffic was sent.

The gemspec correctly expresses the unconditional API requirement: tagged 3.5.1 lacks `disable_warnings`, 3.5.2
provides it, and the retained hook silences ordinary subclasses even before flag inheritance arrived in 3.5.3.
This floor still resolves on the declared MRI range and tested CI/Gemfile combinations; no Ruby minimum or upper
Hashie constraint is needed for this head. It does not prevent the new Ractor failure above.
The maintainability cold read is “Message sets Hashie's warning policy and keeps its legacy hook for older releases.”
The public setting belongs on the shared Message class, not in each consumer; following private renames is worse.
The old hook now has concrete compatibility evidence. One load-time compatibility condition is preferable to new
hooks or consumer-specific wrappers if correcting the new failure. No structural decomposition, extra helper or
file split is warranted. Flog's unchanged `to_s` is 8.2; total rises from 9.2 to 10.2 for the added class-body call,
not new instance complexity. Correct RuboCop Metrics checks pass on both trees; head lint inspects 105 files with
no offenses. No touched upstream file exceeds 501 lines. The one-line version-boundary comment usefully prevents deleting
an apparently dead hook when reading Hashie 6; the frozen-string magic comment follows suite style.

### Claims, contribution rules and retained evidence

`claim-checklist.md` maps every title/body/commit/CHANGELOG/comment/impact clause to executed commands or opened
sources. The literal warning matches the body's nested file example; issue 132 and commit `ffef2a8` establish the
old fix; Hashie PR 639, its source diff and tag containment establish the rename and first release in 6.0.0.
Fresh RubyGems data confirms the 2026-11-11 release, Ruby 3.0 minimum and approximately 96M client downloads.
The comment's literal issue-394 link was opened and documents both the old no-op and the 3.5.2 API introduction.
No unchecked factual sentence remains. Optional prose nit: cut the body's final spec-status sentence, which is true
but test narration. If the new Ractor boundary is retained rather than fixed, it needs explicit acceptance/disclosure;
the existing “override stays” sentence does not disclose it.

Fresh all-state issue/PR searches for Hashie, the private hook, `disable_warnings` and key conflicts found no current
duplicate report/fix. Latest visible issue/PR is 619, issue 620 returns 404 and no PR is open: **620 remains the
apparent next number, not reserved or guaranteed**; recheck when opening. CONTRIBUTING, AGENTS, Dangerfile, README,
UPGRADING, Gemfile and CI requirements were checked. The CHANGELOG Next entry, retained placeholder, credit and
spellcheck addition follow the project rules. No additional README/UPGRADING change is needed for the now-preserved
selective-warning policy. There is no hosted Actions/check/status result for the exact fork head; empty statuses
are not passing CI, and hosted Danger has not run.

Scripts, raw outputs, resolved full-project Gemfiles/locks, source/API snapshots and claim audit are in
[`thermos-sol-SRC1-66b1ec6.tar.gz`](thermos-sol-SRC1-66b1ec6.tar.gz). Drivers are `review_matrix.sh`,
`canonical_run.sh`, `extras.sh`, `second_checks.sh`, `ractor_subclass.sh`, `gate_check.sh`, `claims.sh` and
`validate.py`. Initial symlink-Gemfile duplicate-version warnings, invalid tooling invocations, the Ruby 4 take/value
harness error and an old-Ruby preload-before-Bundler error are retained under `out/attempts/`, with corrected reruns
and explanations in `archive-notes.md`; none count as passing checks, and no warning or assertion was suppressed.
Toolchains reuse the first pass's recorded binaries/pins. JRuby, Ruby master/ZJIT, live Slack, performance and hosted
CI were not run. No upstream post, fork push or workflow dispatch was made.
