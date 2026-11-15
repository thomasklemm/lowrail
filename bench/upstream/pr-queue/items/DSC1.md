---
id: DSC1
repo: discourse/discourse
kind: compat
area: "lib/freedom_patches/erb_util.rb: invalid UTF-8 repair before HTML escaping"
reviewer:
branch:
head:
base: main
built_on:
depends_on: []
stacked_on:
alternative_of:
impact: "On Rails main since rails#59570, a bare <%= str %> with invalid UTF-8 tagged as UTF-8 skips Discourse's ERB::Util prepend and renders the invalid bytes (8.1 + patch rendered them repaired). No new exception, no escaping change; h(), html_escape, html_escape_once and tag attributes still repair. Reach low: PG UTF8 and ActionDispatch params reject invalid bytes; files, subprocesses, Redis and exception messages remain."
rank: 40
risky: false
state: held
pr:
note: "From VM1's side finding on rails#59570 (docs/upstream/vm-share.md, '#59570 and Discourse's UTF-8 repair'; Lowrail b8424e7). Rails side: no change (option a; boundary disclosed in #59570, a guard costs every app +3.3% to +8.1% per unsafe append, exact check is worse than before #59570). Fix: also prepend OutputBuffer#<<, concat and append= (bench/upstream/vm1/discourse_erb/discourse_output_buffer_sketch.rb; 23 cases match 8.1 + patch on 8.1 and main), with a spec that renders a template. Held until the Rails 8.2 beta (DECISIONS: no compatibility PRs for Rails main before it); works on 8.1 too, so it may open earlier if Thomas says so. Needs a branch, two passes and Discourse's contribution rules checked before opening."
passes: []
---

# Keep the invalid UTF-8 repair for template output on Rails 8.2

(Body to be written when the branch is built.)
