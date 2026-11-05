---
id: SC1
repo: pond/scimitar
kind: fix
area: SCIM JSON parser registration
reviewer: pond
branch: thomasklemm/register-parser-with-writer
head: "e81365a6e0f09c13d8c20996bf78f98c4bf5faa2"
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
---

# Register the SCIM parser through the parameter parser writer

Register the SCIM JSON parser with `ActionDispatch::Request.parameter_parsers=` instead of mutating the returned hash. Rails main freezes that hash, so loading Scimitar currently raises `FrozenError` before the application boots.

Merge the existing parsers into the replacement so other content types keep their parsers. The SCIM parser still calls `JSON.parse` on the request body. This follows the registration example in Rails' parameter-parser documentation and also works on released Rails.

On Ruby 4.0.9 with PostgreSQL, all 530 existing examples pass on both Rails main and Rails 8.1.4.1, including the SCIM JSON request specs. Without the change, the Rails-main suite cannot load.

---
<sub>Found through Lowrail's [Rails-main gem census](https://github.com/thomasklemm/lowrail/blob/main/docs/upstream/gem-side-candidates.md#sc1-scimitar-parser-registration).</sub>
