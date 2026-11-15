---
id: ZS1
repo: ruby/ruby
kind: perf
area: ZJIT, sends with a Symbol block argument
reviewer: "tekknolagi and k0kubun (ZJIT), rafaelfranca (author of the branch the first commit comes from)"
branch: thomasklemm/zjit-symbol-block-arg
head: "89e2da1571"
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
note: "reopened 2026-11-15 after skipkayhil closed rails/rails#59803 with 'Let's fix this in the JITs?'; first commit is the Symbol part of Rafael França's Shopify/ruby zjit-perf/blockarg-direct-send (3f17d8950e), he is its author (coordinator: the design is his); the coordinator opens the draft after the three passes approve on the head; earlier heads dcd4bd2b79, 7eddd8bfce, 09d8e5308e (arm64 green on all three, ARM1); 89e2da1571 differs from 09d8e5308e in two tests, a rename, a comment and the bindgen entry, no generated code; run_benchmarks output and stats diff still to be added to the body; record docs/upstream/zjit-symbol-block.md"
waived:
  - {reviewer: thermos, head: "89e2da1571", by: "coordinator, 2026-11-15", reason: "three independent passes on the exact head (Fable adversarial on exactness and invalidation, with a readability and ZJIT-style note), a mutation check of every guard, and arm64 coverage by ARM1"}
passes:
  - {reviewer: opus, head: "7eddd8bfce", orb: T-01a1e02a-4640-708d-8a07-4487c093fc18, date: 2026-11-15, verdict: changes, open: "no behaviour difference found; must-fix: body called Array#map a C method and gave one fallback reason for both callee kinds, and a profiled-Symbol guard was emitted in front of a C-callee send that stays dynamic (splat, kwargs); all three fixed in 09d8e5308e, with the optional points taken: one helper for the patch points, behaviour test for the C-callee patch points, trivial-inliner skip removed, CCallVariadic prints its block"}
  - {reviewer: fable, head: "7eddd8bfce", orb: T-01a1e02a-5156-7535-b82d-6fdecf19860d, date: 2026-11-15, verdict: changes, open: "must-fix: with RUBY_BOX=1 a box that redefines Symbol#to_proc got the plain Symbol as block handler; fixed in 09d8e5308e (no specialization once a non-root box exists, RootBoxOnly patch point, CLI test). Leaf-call, GC and invalidation questions settled with source lines and runs; readability: reads like the surrounding code, asked for the patch-point helper and the CCallVariadic printer, both done"}
  - {reviewer: claude-code, head: "7eddd8bfce", orb: T-01a1e02a-30a2-77f9-9d94-33f157e1623d, date: 2026-11-15, verdict: changes, open: "must-fix: Symbol.define_method(:to_proc, Symbol.instance_method(:to_proc)) clears the basic flag in place without invalidating the entry, so the patch point never fired and compiled code kept the refined lambda; fixed in 09d8e5308e (the conversion checks the watched entry's flag and exits, with a test). Body Array#map sentence fixed"}
  - {reviewer: opus, head: "09d8e5308e", orb: T-01a1e02a-4640-708d-8a07-4487c093fc18, date: 2026-11-15, verdict: nits, open: "no must-fix; the three earlier must-fixes are resolved and the flag check and box check read correctly; found that removing PatchPoint RootBoxOnly fails no test and that no program needs it; optional points taken in 89e2da1571: commit message wording (line length, 'no box has been created with Ruby::Box.new'), cfunc_callee renamed, zjit.c comment shortened; not taken: carrying the to_proc entry in BlockArgSymbol"}
  - {reviewer: claude-code, head: "09d8e5308e", orb: T-01a1e02a-30a2-77f9-9d94-33f157e1623d, date: 2026-11-15, verdict: nits, open: "no must-fix; flag check equivalent to rb_method_basic_definition_p in 16 single changes, 8 sequences with GC.compact and under RUBY_BOX=1; exit after the leaf call right; nits taken in 89e2da1571: the self-redefinition test now fails on all three paths (proc and Proc.new as C callees), the redefined-after-compile warm-up, the bindgen allowlist entry, commit message line length"}
---

# ZJIT: Send Symbol block arguments directly

Under ZJIT, a send with a Symbol block argument such as `foo(&:sym)` stays a dynamic send. rails/rails#59803 worked around that in Active Record's first attribute read, `cast_value(name, index, &:value!)`, and was closed with ["Let's fix this in the JITs?"](https://github.com/rails/rails/pull/59803#issuecomment-6895904455). This is the send side of that fix, the Symbol case that #18180 left for later (Shopify/ruby#1014).

When the block argument is a static Symbol, the send now compiles to `SendDirect` for ISEQ callees and to `CCallWithFrame` or `CCallVariadic` for C functions such as `Array#reject` and `Array#sum`. The Symbol becomes the block handler through the code `vm_caller_setup_arg_block` already runs for it, moved into a function, so refinements in the caller behave as in the interpreter. Patch points cover a redefined `Symbol#to_proc` and a newly created `Ruby::Box`. Other block arguments are handled as before, and the callee's `yield` to the Symbol is unchanged.

The first commit is the Symbol part of Rafael Mendonça França's [`zjit-perf/blockarg-direct-send`](https://github.com/Shopify/ruby/tree/zjit-perf/blockarg-direct-send) branch, ported to master. His branch also sends forwarded block parameters directly; that part is left to Shopify/ruby#1039.
