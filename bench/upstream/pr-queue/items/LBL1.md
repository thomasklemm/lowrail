---
id: LBL1
repo: rails/rails
kind: perf
area: Action View, form builder labels
reviewer: "Action View maintainers (Tags::Translator is unchanged since 2018)"
branch:
head:
base: main
built_on: "4617bd9"
depends_on: []
stacked_on:
alternative_of:
impact: "f.label looks up its own key twice when the form's object name is the model's i18n_key (the usual case); dropping that default: 77 -> 68 objects and 4 -> 3 lookups per label, one MissingTranslation fewer"
rank: 30
risky: false
state: held
pr:
note: "not built yet (Thomas, 2026-11-16: queue it). Prototype and 3,600-call equivalence check (Simple and Fallbacks backends) in bench/upstream/form_helper_stack (candidate L). Build after the orb reset on 2026-11-18 with Callgrind; only a backend that logs or counts lookups sees a difference. rails/rails is at 15/15 non-draft, so draft only."
passes: []
---

# Look up a label's translation key once
