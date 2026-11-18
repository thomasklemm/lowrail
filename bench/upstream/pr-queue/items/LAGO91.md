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
passes: []
---

# fix(ruby): allow building on Ruby 4.1

## Context

The gem can't be installed on Ruby 4.1:

- `required_ruby_version = '~> 4.0.2'` rejects 4.1.
- rb-sys has no stable API for 4.1 yet. Without the compiled fallback, the build stops with "No Rust stable API implementation found for Ruby 4.1.0".

## Change

- `required_ruby_version` `~> 4.0.2` → `>= 4.0.2`.
- Depend on rb-sys with `stable-api-compiled-fallback`, as commonmarker and tiktoken_ruby do, so unknown Ruby versions use the compiled C shim (Cargo.toml plus one Cargo.lock line).
