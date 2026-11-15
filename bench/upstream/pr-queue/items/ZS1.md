---
id: ZS1
repo: ruby/ruby
kind: perf
area: ZJIT, sends with a Symbol block argument
reviewer: "tekknolagi and k0kubun (ZJIT), rafaelfranca (author of the branch the first commit comes from)"
branch: thomasklemm/zjit-symbol-block-arg
head: "dcd4bd2b79"
base: master
built_on: "3be2b028a7"
depends_on: []
stacked_on:
alternative_of:
impact: "foo(&:sym) to ISEQ and C callees no longer falls back to a dynamic send under ZJIT; railsbench on Rails main: 42,441 of 115,090 block-arg fallbacks per iteration"
rank: 1
risky: true
state: in-review
pr:
note: "reopened 2026-11-15 after skipkayhil closed rails/rails#59803 with 'Let's fix this in the JITs?'; first commit is the Symbol part of Rafael França's Shopify/ruby zjit-perf/blockarg-direct-send (3f17d8950e), he is its author; the coordinator opens the draft after the three passes and ARM1's arm64 run; run_benchmarks output and stats diff still to be added to the body; record docs/upstream/zjit-symbol-block.md"
passes: []
---

# ZJIT: Send Symbol block arguments directly

`foo(&:sym)` is everywhere in Ruby code, and under ZJIT every such send falls back to a dynamic send ("block argument is not nil"). rails/rails#59803 worked around that in Active Record's first attribute read, `cast_value(&:value!)`, and was closed with ["Let's fix this in the JITs?"](https://github.com/rails/rails/pull/59803#issuecomment-6895904455). This is the send side of that fix, and the Symbol step that Shopify/ruby#1014 and #18180 left open.

A send whose block argument is a static Symbol now compiles to `SendDirect` for ISEQ callees and to a C call with a frame for C methods such as `Array#map`. The Symbol becomes the block handler through the code `vm_caller_setup_arg_block` already runs, moved into a function, so refinements in the caller behave as in the interpreter. A patch point on `Symbol#to_proc` covers its redefinition. Dynamic Symbols and other block argument objects fall back as before, and the callee's `yield` to the Symbol is unchanged.

The first commit is the Symbol part of Rafael Mendonça França's [`zjit-perf/blockarg-direct-send`](https://github.com/Shopify/ruby/tree/zjit-perf/blockarg-direct-send) branch, ported to master. His branch also sends forwarded block parameters directly; that part is left to Shopify/ruby#1039.
