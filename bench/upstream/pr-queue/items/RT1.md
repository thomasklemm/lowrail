---
id: RT1
repo: setdef/RatatuiRuby
kind: compat
area: ext/ratatui_ruby/Cargo.lock (rb-sys crate)
reviewer:
branch:
head:
base: stable
built_on:
introduced_by:
tracker: []
depends_on: []
stacked_on:
alternative_of:
evidence: [bench/upstream/gem-differential/runs/compare-v4.0.10-master-a1a9f45587.json]
impact: "ratatui_ruby 1.5.2 (76,875 downloads, 11 reverse dependencies) does not compile on Ruby 4.1: its Cargo.lock pins the rb-sys crate at 0.9.123, whose bindgen fails on the incomplete `struct rb_matchext_struct`; rb-sys >= 0.9.128 builds (ruby-4.1-ecosystem.md). There is no precompiled 4.1 binary, so every install on 4.1 builds from source. In the gem differential it only blocks sidekiq's optional `:tui` Gemfile group, so sidekiq's suite cannot install on master."
rank: 3
risky: false
state: held
pr:
note: "2026-11-27: held per DECISIONS (fixes for niche gems are recorded, not opened). The default branch `stable` (pushed 2026-10-28) still locks rb-sys 0.9.123; no issue or PR mentions 4.1, rb-sys or rb_matchext; the two outside PRs on GitHub are open without a maintainer reply. The fix would be `cargo update -p rb-sys` in ext/ratatui_ruby (and a 4.1 entry in its cross-compile list, the maintainers' call). Not built."
ownership: {date: 2026-11-27, checked: ["setdef/RatatuiRuby issues and PRs (4.1, rb_matchext, rb-sys)", "Lowrail ledger"], hits: []}
passes: []
---

# Build with rb-sys >= 0.9.128 so the extension compiles on Ruby 4.1

Not written: the item is held.
