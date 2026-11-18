---
id: DS1
repo: discourse/discourse
kind: fix
area: "chat plugin, Category associations"
reviewer:
branch: thomasklemm/category-channels-association
head: "75526aa95c"
base: main
built_on:
depends_on: []
stacked_on:
alternative_of:
impact: see docs/upstream/contributions.md
rank:
risky: false
state: ready
pr: 45658
note: "2026-11-18 (rules review, docs/upstream/rules-review-2026-11-18-ecosystem.md): body without the test-run paragraph, unposted; code unchanged. opened 2026-11-05; the Queue table still listed it as blocked on the CLA"
passes:
  - {reviewer: claude-code, head: "75526aa95c", orb: T-01a1ded6-4813-7653-94e8-9b8375d70deb, date: 2026-11-15, verdict: approve, open: "Footer cleanup (DECISIONS 4eb18bee, Fixed parts): reviewed the old and new body word diff. Only the <sub> footer and Lowrail links are removed and, where useful, one how-found clause is added; numbers, tables, scripts and wording unchanged; no internal labels or private names. Added clause backed by app-suites.md DS1."}
  - {reviewer: thermos-sol, orb: "T-01a1ee72-6d4f-7377-b2ff-f1240d8bebeb", head: "75526aa95c", date: 2026-11-18, verdict: approve, open: "body only; live/generated bodies, source, record and upstream template checked; both rubrics self-performed, no delegation. Association mapping, serialization and deliberately unchanged destroy behavior agree with source and Rails compatibility record; permalinks retained. No body correction needed; not a new code approval."}
---

# FIX: Scope Category#category_channels to the category's channels

`Category#category_channels` is declared with [`foreign_key: %i[chatable_id chatable_type]`](https://github.com/discourse/discourse/blob/de34d8ac4f9d31eea2d4c3e2de397f60e239ee88/plugins/chat/lib/chat/category_extension.rb#L14-L18), which maps the category's one-column primary key onto two columns. On Rails 8.1 the association quietly queries `chatable_id IS NULL AND chatable_type IS NULL`, so [`has_chat_channels`](https://github.com/discourse/discourse/blob/de34d8ac4f9d31eea2d4c3e2de397f60e239ee88/plugins/chat/plugin.rb#L419-L423) in the category serializer is always false. Running Discourse's test suite on Rails main, I found that the same declaration raises `ArgumentError: Key mappings must have the same number of columns` on every read (since rails/rails#59120), so with chat enabled every category save fails and `db:migrate` can't seed the Uncategorized category.

This declares it with `as: :chatable`, like `has_one :category_channel` above it. Nothing in the frontend reads `has_chat_channels`, so on 8.1 the only change is that category JSON, MessageBus and webhook payloads report `true` for categories with channels; the query count stays the same. I dropped `dependent: :destroy` from the `has_many`, so deleting a category still destroys only the one channel `has_one :category_channel` destroys today. Keeping it would now also destroy the category's other channels, including ones with messages.
