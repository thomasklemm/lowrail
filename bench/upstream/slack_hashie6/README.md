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
