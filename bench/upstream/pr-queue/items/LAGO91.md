---
id: LAGO91
repo: getlago/lago-expression
kind: fix
area: Ruby extension build
reviewer:
branch: ruby-4.1
head: "d23823a03ea55204dae64d4d593b5b0cf50e5838"
base: main
built_on: "0b4fe839f71db9c7d3a93c843dd406dd0eba7aa7"
depends_on: []
stacked_on:
alternative_of:
impact:
rank:
risky: false
state: ready
pr: 91
note: "2026-11-18 (rules review, docs/upstream/rules-review-2026-11-18-ecosystem.md): body without Testing section and pins, unposted; code unchanged. Opened before the queue tracked it; item added 2026-11-14 so status watches it. built_on is the merge base GitHub reports for head. Passes and record: docs/upstream/contributions.md."
passes:
  - {reviewer: thermos-sol, orb: "T-01a1ee72-6d4f-7377-b2ff-f1240d8bebeb", head: "d23823a03ea55204dae64d4d593b5b0cf50e5838", date: 2026-11-18, verdict: approve, open: "body only; live/generated bodies, source, record and upstream template checked; both rubrics self-performed, no delegation. Cut headings, arrows and pins; kept actual required_ruby_version constraint, unchanged minimum and rb-sys compiled fallback. Not a new code approval."}
---

# fix(ruby): allow building on Ruby 4.1

The gem can't be installed on Ruby 4.1: `required_ruby_version = '~> 4.0.2'` rejects it, and rb-sys has no precompiled stable API for it yet. Without the compiled fallback, the build stops with "No Rust stable API implementation found for Ruby 4.1.0".

This allows Ruby `>= 4.0.2` and enables rb-sys's `stable-api-compiled-fallback`, so unknown Ruby versions use the compiled C shim. The minimum supported Ruby stays the same.
