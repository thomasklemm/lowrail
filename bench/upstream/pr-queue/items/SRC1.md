---
id: SRC1
repo: slack-ruby/slack-ruby-client
fork: thomasklemm/slack-ruby-client
kind: fix
area: Slack::Messages::Message (lib/slack/messages/message.rb), gemspec hashie dependency
reviewer: dblock
branch: thomasklemm/message-disable-warnings
head: "dfbf7013bfaf7abf982a09ef29d732e6b452de71"
base: master
built_on: "0f1757ebd8"
tracker: []
depends_on: []
stacked_on:
alternative_of:
impact: "With hashie 6.0.0 (2026-11-11), which the unconstrained gemspec resolves on Ruby 3.0 and newer, every Slack Web API response with a key that is also a Mash method (a file's size, for one) logs Hashie's key conflict warning again: Message silenced it by overriding the private log_built_in_message, which hashie 6.0.0 renamed. slack-ruby-client has 96M downloads. The fix calls Hashie's public disable_warnings and requires hashie 3.5.3, the first version whose subclasses inherit it."
evidence: [bench/upstream/slack_hashie6]
rank: 1
risky: false
state: built
pr:
note: "2026-11-28: a clear bugfix PR, no ticket (Thomas). The hashie floor 3.5.3 is the builder's decision (record, Why >= 3.5.3). One behaviour difference on hashie 4.0.0 to 5.2.0 is in the record and not in the body: a subclass of Message that calls disable_warnings with method names warns for other keys, where the dead-on-6 override kept it silent. The problem was introduced by hashie commit 9f7c514 (hashie 6.0.0), which renamed the private method; introduced_by stays empty because it names commits of this repo."
ownership: {date: 2026-11-28, checked: ["open PRs naming log_built_in_message that change .spellcheck.txt, CHANGELOG.md, lib/slack/messages/message.rb, slack-ruby-client.gemspec"], hits: []}
passes:
  - {reviewer: astra, head: "dfbf7013bfaf7abf982a09ef29d732e6b452de71", date: 2026-11-28, orb: T-01a2221b-8e76-742f-8bca-1918a5fb40a4, verdict: changes, open: "R1 Ruby 3.0.7 with Hashie 3.5.3/3.5.4 gains a Ractor::IsolationError; R2 selective-warning subclasses can warn or raise through a logger on Hashie 4-5.2 and need disclosure if retained; R3 impact's universal warning trigger is false. Retaining the original legacy no-op alongside disable_warnings fixed R1/R2 in isolated probes; do not add a new underscore-helper override. See Astra section and astra-SRC1-dfbf701.tar.gz."}
---

# Fix Hashie 6 key conflict warnings for Slack::Messages::Message

With Hashie 6.0.0, a response with a key that is also a method name, such as a file's `size`, logs a warning again:

```ruby
Slack::Messages::Message.new('file' => { 'size' => 1 })
# WARN -- : You are setting a key that conflicts with a built-in method Slack::Messages::Message#size defined in Hash. This can cause unexpected behavior when accessing the key as a property. You can still access the key via the #[] method.
```

`Message` has silenced this since #132 by overriding Hashie's private `log_built_in_message`. Hashie 6.0.0 renamed that method (hashie/hashie#639), so the override is no longer called.

This calls `disable_warnings` instead, Hashie's public setting for this. Subclasses inherit it from Hashie 3.5.3 on, so the gemspec, which had no constraint, now requires that version. The new spec fails on master with Hashie 6.0.0 and passes with Hashie 5.
