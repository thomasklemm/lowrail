---
id: CW2
repo: rails/rails
kind: restore
area:
reviewer:
branch: thomasklemm/resolver-find-all-hook
head: "0d3ef774bd"
base: main
built_on:
depends_on: []
stacked_on:
alternative_of:
impact: see docs/upstream/contributions.md
rank:
risky: false
state: closed
pr: 59644
note: "2026-11-18 (Thomas): closed with comment (issuecomment-6994087583) after the slot triage (rails-slot-triage-2026-11-18.md): real break, but restoring the private _find_all hook is the wrong repair site. 2026-11-18 (rules review adopted after thermos-sol confirm, Lowrail 9f494264): shortened body; the FileSystemResolver/godmin/rbexy paragraph removed as the confirm required; body PATCHed. 2026-11-18 (rules review, docs/upstream/rules-review-2026-11-18-rails-ruby.md): proposed body added (body corrected in this item only, not PATCHed (live body unchanged)): 176 -> 141 words; the test-shape sentence and the Chatwoot spec count are cut, the FileSystemResolver boundary kept in one clause."
passes:
  - {reviewer: claude-code, head: "0d3ef774bd", orb: T-01a1ded6-4813-7653-94e8-9b8375d70deb, date: 2026-11-15, verdict: approve, open: "Footer cleanup (DECISIONS 4eb18bee, Fixed parts): reviewed the old and new body word diff. Only the <sub> footer and Lowrail links are removed and, where useful, one how-found clause is added; numbers, tables, scripts and wording unchanged; no internal labels or private names. Added clause backed by app-suites.md CW2."}
  - reviewer: thermos-sol
    orb: T-01a1ee60-a4df-75cc-9428-abffe636e31c
    head: "0d3ef774bd115ede07048bd0194a27c2bafc03de"
    date: 2026-11-18
    verdict: changes
    open: >-
      Both Thermos rubrics applied personally; code is correct, body-only
      must-fix. Cut the final FileSystemResolver/godmin/rbexy paragraph: although
      factually correct, it is exactly the unrelated private override boundary
      excluded by PR descriptions / Leave out. The central Resolver hook and
      its real broken callers belong in the compatibility explanation; the
      optimized subclass's unchanged exclusion does not. Opened all linked
      callers; Chatwoot calls inherited _find_all and view_component-cache_digest
      overrides it. No surviving added guards or comments, no structural
      regression. Ruby 4.0.9 view_paths_test passes 18 runs/46 assertions.
      Raw cat-file: one commit on 7a78da5a55, Thomas author/committer, author
      date 1793825951 +0000, no trailers. No upstream edits or posts made.
---

# Call a custom resolver's _find_all again

Running Chatwoot's test suite on Rails main, I found that since #58279, [`Resolver#find_all`](https://github.com/rails/rails/blob/7a78da5a5576d7ab7549b10fb13156788478ba35/actionview/lib/action_view/template/resolver.rb#L68-L70) calls `find_templates` directly, so private `_find_all` overrides on direct `Resolver` subclasses are bypassed; without `find_templates`, every lookup raises `NotImplementedError`. `_find_all` is private, but custom resolvers use it, and the removal is unreleased:

- Chatwoot's [`EmailTemplates::DbResolverService`](https://github.com/chatwoot/chatwoot/blob/a8364f9c4385b12b4f217649c1dad23755459215/app/services/email_templates/db_resolver_service.rb#L28) (develop) overrides `find_all` and calls the inherited `_find_all`, which no longer exists, so its mailer specs fail with `NoMethodError` on main.
- view_component-cache_digest's [`Resolver`](https://github.com/tildeio/view_component-cache_digest/blob/82da53b3b092a256841858ed6a482ae0bd80b385/lib/view_component/cache_digest/resolver.rb#L10) (main) overrides `_find_all`, which is now bypassed.

This restores the hook in `Resolver`: `find_all` passes its six arguments to `_find_all`, whose default calls `find_templates`. `Resolver#find` still goes through `find_all`, so overrides of `find_all`, `_find_all` and `find_templates` all keep working.
