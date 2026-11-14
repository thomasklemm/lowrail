---
id: ZL3
repo: ruby/ruby
kind: perf
area: ZJIT polymorphic send fallback
reviewer: "k0kubun (exit recompilation, #1031)"
branch: thomasklemm/zjit-poly-miss-recompile
head: "fc8d729709"
base: master
built_on: "88ea6fd282"
depends_on: []
stacked_on:
alternative_of:
impact: "ZJIT Callgrind, master vs this (A/A <= 0.03%): shipit -0.98%, railsbench -0.16%, lobsters -0.06%; lead 3 repro 352.6 -> 137.3 Ir per call (YJIT 100.8); Rails main 4 models -9.8% / -25.5% Ir per op. Costs: +1.9% / +4.4% / +4.5% compiled ISEQs, sites with more than 8 receiver classes lose their arms (+44% in a 12-class micro)."
rank: 9
risky: true
state: held
pr:
note: "Lead 3 PR attempt stopped at a design question (docs/upstream/zjit-leads.md, 2026-11-14 evening): k0kubun ruled out side exits at polymorphic misses for invokeblock (#18211) and his zjit-lobsters7 rows 24/27 make this fallback cheaper instead. Ask first with the drafted answer on Shopify/ruby#776 (Thomas); open only if the team wants the recompile. No review passes were run; before opening: claude-code and fable passes, test-all and btest at --zjit-call-threshold=1/2, run_benchmarks.rb output and a ZJIT stats diff."
passes: []
---

# ZJIT: Recompile once when a receiver class misses a polymorphic send's profile

A polymorphic send dispatches the receiver classes from its profiled calls. Any other class goes to a generic send that never recompiles, so a class that first shows up after compilation stays on it (Shopify/ruby#776):

```ruby
class Model; def self.types = 1; end
MODELS = Array.new(4) { Class.new(Model) }
def read(m) = m.types
100.times { read(MODELS[0]); read(MODELS[1]) } # compiled with arms for 2 classes
100.times { MODELS.each { read(_1) } }         # master: 200 of these 400 calls take the fallback
```

In an ISEQ's first version, this side-exits at that fallback instead, as `NoProfileSend` does, so the next version gets an arm for the class. Later versions keep the generic send, so these misses spend at most one version. A site that sees more than 8 classes turns megamorphic after the recompile and loses its arms.

Callgrind instructions per iteration, ruby-bench with ZJIT:

| | master | this change |
|---|---:|---:|
| railsbench | 4,903M | 4,896M |
| lobsters | 2,499M | 2,497M |
| shipit | 3,762M | 3,725M |
