---
id: PM2
repo: rails/rails
kind: perf
area: Action View, tag helper
reviewer: flavorjones (author of 99a3247ebc)
branch: thomasklemm/tag-options-blank-once
head: "ddd44b197e"
base: main
built_on: "1e235cee11"
depends_on: []
stacked_on:
alternative_of:
impact: none left in an exact form; the inexact shortcut saved 2.0% per tag call with String keys
rank:
risky: false
state: closed
pr:
note: "not opened: every exact form makes main's three calls (key.blank?, key.to_s, name.blank?), so there is nothing to save; the shortcut is observable with a stateful singleton blank? (pm2_exact.rb)"
passes:
  - {reviewer: skeptic, head: "02f567ab81", date: 2026-11-05, verdict: approve, open: ""}
  - {reviewer: sol, head: "02f567ab81", date: 2026-11-05, verdict: changes, open: "skipped key.blank? on Strings and Symbols"}
  - {reviewer: skeptic, head: "2dc1231b26", date: 2026-11-05, verdict: approve, open: "disclose the purity assumption"}
  - {reviewer: sol, head: "2dc1231b26", date: 2026-11-05, verdict: changes, open: "20:09: not exact (stateful blank?, to_s returning self, overridden equal?); the smallest exact fix drops the shortcut"}
---

# Skip the second blank check when a tag attribute's name is its key

Not opened. On main 1e235cee11, `tag_options` calls `key.blank?`, then `key.to_s`, then `blank?` on the result,
and a String key can override each of them: a frozen String with singleton methods survives as a Hash key. A
shortcut that skips the second `blank?` when `to_s` returned the key changes what such a key renders
([`pm2_exact.rb`](../../perf_round/pm2_exact.rb), Lowrail a06703e89d, Ruby 4.0.9):

| key | main | branch ddd44b197e |
| --- | --- | --- |
| `"title"` with a counting `blank?` | `<img title="x" />`, `blank?` ×3 | same, `blank?` ×2 |
| `blank?` false, then true | `<img />` | `<img ="x" />` |
| `to_s` returns self, `blank?` false then true | `<img />` | `<img ="x" />` |
| `to_s` returns a blank String whose `equal?` is always true | `<img />` | `<img ="x" />` |

An exact version has to make the same three calls in the same order, which is main's code, so there is no gain left
to claim. The shortcut measured −2.0% per `content_tag` call with String keys (58,550 → 57,406 Ir, mean of three
runs; A/A within 0.03%) and nothing with Symbol keys (56,728 → 56,654, within run-to-run spread), from
`percall.sh cases/tg_none.rb tag_str|tag_sym 2000 3`. Reopen only if Rails decides that `blank?` on attribute keys
may be assumed pure.
