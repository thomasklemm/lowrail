---
id: SRC1
repo: slack-ruby/slack-ruby-client
fork: thomasklemm/slack-ruby-client
kind: fix
area: Slack::Messages::Message (lib/slack/messages/message.rb), gemspec hashie dependency
reviewer: dblock
branch: thomasklemm/message-disable-warnings
head: "66b1ec68dd3996621d229d3f6d6e53406c37c586"
base: master
built_on: "0f1757ebd8"
tracker: []
depends_on: []
stacked_on:
alternative_of:
impact: "With hashie 6.0.0 (2026-11-11), which the unconstrained gemspec resolves on Ruby 3.0 and newer, Slack Web API responses containing conflicting keys such as a file's size log Hashie's key conflict warning again: Message silenced it by overriding the private log_built_in_message, which hashie 6.0.0 renamed. slack-ruby-client has 96M downloads. The fix also calls Hashie's public disable_warnings, keeps the override for hashie before 6.0.0, and requires hashie 3.5.2, the first version that has disable_warnings."
evidence: [bench/upstream/slack_hashie6]
rank: 1
risky: false
state: built
pr:
note: "2026-11-28: a clear bugfix PR, no ticket (Thomas). New head 66b1ec68dd after Astra's changes verdict on dfbf7013bf (R1 Ractor on Ruby 3.0.7 with hashie 3.5.3/3.5.4, R2 selective disable_warnings and quiet on hashie 4.0.0 to 5.2.0, R3 impact wording; R1 and R2 reproduced by the builder): the old no-op override stays next to disable_warnings, so hashie before 6.0.0 behaves as on master (0 differential rows differ) and the body needs no boundary sentence; impact narrowed. The hashie floor is 3.5.2 again, the builder's decision (record, Why the override stays). Still different before 6.0.0, master raises and the head does not: a frozen subclass given a conflicting key (hashie 3.6.0 to 5.2.0). The problem was introduced by hashie commit 9f7c514 (hashie 6.0.0), which renamed the private method; introduced_by stays empty because it names commits of this repo."
ownership: {date: 2026-11-28, checked: ["open PRs naming to_s that change .spellcheck.txt, CHANGELOG.md, lib/slack/messages/message.rb, slack-ruby-client.gemspec"], hits: []}
passes:
  - {reviewer: astra, head: "dfbf7013bfaf7abf982a09ef29d732e6b452de71", date: 2026-11-28, orb: T-01a2221b-8e76-742f-8bca-1918a5fb40a4, verdict: changes, open: "R1 Ruby 3.0.7 with Hashie 3.5.3/3.5.4 gains a Ractor::IsolationError; R2 selective-warning subclasses can warn or raise through a logger on Hashie 4-5.2 and need disclosure if retained; R3 impact's universal warning trigger is false. Retaining the original legacy no-op alongside disable_warnings fixed R1/R2 in isolated probes; do not add a new underscore-helper override. See Astra section and astra-SRC1-dfbf701.tar.gz."}
  - {reviewer: thermos-sol, head: "dfbf7013bfaf7abf982a09ef29d732e6b452de71", date: 2026-11-28, orb: T-01a2221b-855f-7661-a87e-59f64efb922f, verdict: changes, open: "P2: reproduced Astra's Ruby 3.0/Hashie 3.5.3 Ractor exception; retain the original legacy no-op alongside disable_warnings. P2: selective settings on Hashie 4-5 can now warn or raise through a custom logger; disclose in body/README if retained, or restore the old hook. P3: qualify impact's every-method-key claim. Keep the 3.5.3 floor; no underscore-hook override. Repros and raw runs in the record/archive."}
---

# Fix Hashie 6 key conflict warnings for Slack::Messages::Message

With Hashie 6.0.0, a response with a key that is also a method name, such as a file's `size`, logs a warning again:

```ruby
Slack::Messages::Message.new('file' => { 'size' => 1 })
# WARN -- : You are setting a key that conflicts with a built-in method Slack::Messages::Message#size defined in Hash. This can cause unexpected behavior when accessing the key as a property. You can still access the key via the #[] method.
```

`Message` has silenced this since #132 by overriding Hashie's private `log_built_in_message`. Hashie 6.0.0 renamed that method (hashie/hashie#639), so the override is no longer called.

This also calls `disable_warnings`, Hashie's public setting for this. It exists from Hashie 3.5.2 on, so the gemspec, which had no constraint, now requires that version. The override stays for Hashie before 6.0.0. The new spec fails on master with Hashie 6.0.0 and passes with Hashie 5.
