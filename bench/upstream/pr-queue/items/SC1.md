---
id: SC1
repo: pond/scimitar
kind: fix
area: SCIM JSON parser registration
reviewer: pond
branch: thomasklemm/register-parser-with-writer
head: "a302bc09b8555d6da525adb51f64df26eb9651da"
base: main
built_on: "a7edc24d208ef4d2316c982c48bd2a5fe4fdcb5d"
depends_on: []
impact: Allow Scimitar to boot with Rails main's frozen parameter-parser registry
rank: 15
risky: true
state: in-review
note: Prepared only; coordinator runs Sol and Astra; no upstream submission authorized in this worker
passes:
  - {reviewer: skeptic, head: "e81365a6e0f09c13d8c20996bf78f98c4bf5faa2", date: 2026-11-05, verdict: approve, open: "L0; registry replacement boundary disclosed; no required changes"}
  - {reviewer: sol, head: "e81365a6e0f09c13d8c20996bf78f98c4bf5faa2", date: 2026-11-05, verdict: changes, open: "P2; preserve earlier references to mutable parameter_parsers"}
  - {reviewer: astra, head: "e81365a6e0f09c13d8c20996bf78f98c4bf5faa2", date: 2026-11-05, verdict: changes, open: "P2; later app configuration through retained registry stops taking effect"}
  - {reviewer: skeptic, head: "a302bc09b8555d6da525adb51f64df26eb9651da", date: 2026-11-05, verdict: approve, open: "Mutable references and frozen registration verified through request parsing; revised body approved"}
---

# Register the SCIM parser through the parameter parser writer

Use `ActionDispatch::Request.parameter_parsers=` only when the registry is frozen; keep the existing in-place registration for a mutable registry. On Ruby 4.0.9 with Rails main at `1e235cee11b0a7aecb189d8837534807626287aa`, loading Scimitar currently raises `FrozenError` before the application boots.

For a frozen registry, copy its entries, add the SCIM parser and pass the copy to Rails' writer. Existing parser Procs are preserved. On Rails 8.1.4.1, the mutable registry keeps its identity, so an application that retains it before loading Scimitar can still configure a custom SCIM parser through that reference. JSON decoding is unchanged.

With Ruby 4.0.9 and PostgreSQL, `bundle exec rspec` passes 532 examples on Rails 8.1.4.1; the pinned Rails-main bundle passes 532 examples with one pending (the mutable-registry-only example). Two added examples exercise registration in fresh processes and parse requests through `ActionDispatch::Request`: a retained mutable reference configured after loading, and an initially frozen registry. Without the fix, the latter raises `FrozenError` even on released Rails.

---
<sub>Found through Lowrail's [Rails-main gem census](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/gem-side-candidates.md#sc1-scimitar-parser-registration).</sub>
