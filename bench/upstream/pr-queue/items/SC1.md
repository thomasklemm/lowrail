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
state: draft
pr: 172
note: "stays a draft (Thomas, 2026-11-05): the fix belongs at the source, Rails main freezing parameter_parsers; F1 investigates. Evidence in docs/upstream/gem-side-candidates.md"
passes:
  - {reviewer: skeptic, head: "e81365a6e0f09c13d8c20996bf78f98c4bf5faa2", date: 2026-11-05, verdict: approve, open: "L0; registry replacement boundary disclosed; no required changes"}
  - {reviewer: sol, head: "e81365a6e0f09c13d8c20996bf78f98c4bf5faa2", date: 2026-11-05, verdict: changes, open: "P2; preserve earlier references to mutable parameter_parsers"}
  - {reviewer: astra, head: "e81365a6e0f09c13d8c20996bf78f98c4bf5faa2", date: 2026-11-05, verdict: changes, open: "P2; later app configuration through retained registry stops taking effect"}
  - {reviewer: skeptic, head: "a302bc09b8555d6da525adb51f64df26eb9651da", date: 2026-11-05, verdict: approve, open: "Mutable references and frozen registration verified through request parsing; revised body approved"}
  - {reviewer: sol, head: "a302bc09b8", date: 2026-11-05, verdict: approve, open: "confirm: earlier findings addressed, no new finding"}
  - {reviewer: astra, head: "a302bc09b8", date: 2026-11-05, verdict: approve, open: "confirm: earlier findings addressed; optional title nit: 'Register the SCIM parser with frozen parameter registries'; not applied"}
---

# Register the SCIM parser through the parameter parser writer

On Rails main, `ActionDispatch::Request.parameter_parsers` is frozen, so adding the SCIM parser to it raises `FrozenError` and an app using Scimitar doesn't boot.

When the registry is frozen, this adds the parser to a copy and sets it with `parameter_parsers=`, as the Rails docs suggest. On released Rails the registry isn't frozen, and the parser is added in place as before.

I'll keep this as a draft until the Rails 8.2 beta, since Rails may still keep this registry writable, and update it then.

---
<sub>Found through Lowrail's [Rails-main gem census](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/gem-side-candidates.md#sc1-scimitar-parser-registration).</sub>
