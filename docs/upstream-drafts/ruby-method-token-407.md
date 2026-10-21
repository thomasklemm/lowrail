# Ruby 4.0.7 token fork: protocol before measurements

This is a fork-only experiment for Ruby #22459. No upstream post or PR is
authorized. The master patch remains available separately. The 4.0.7 backport
uses the existing callcache, not an epoch, registry or Ruby core token class.

## Fixed decision rule

* Run the real retained Rails 8.1.4 blog `GET /articles/1` and the six pinned
  Fizzy GETs, with fresh matching-mode artifacts and the existing disposable
  database/entropy fixtures. Preserve all status/body/header comparisons,
  including both off arms. Do not normalize differing bytes or retry gates
  until green. Keep private fixture data out of Git and release assets.
* `script/screen`: three fresh-process rounds, 20 vector warmups and 30 samples
  per route, CPU 2; separate stats-enabled coverage workers. Arms are off-A,
  existing guards (`on`), tokens, public reflection and off-B. No unsafe guard
  removal in these cohorts. Interpreter and native YJIT have separate artifacts.
* Report allocations/request and the actual native wall distributions. A wall
  benefit requires full exactness, an A/A 95% interval contained within ±2%,
  flat measured YJIT compilation/invalidation counters, and the token/hook
  interval wholly below three times the observed A/A noise floor. Otherwise
  the wall result is inconclusive, even if its point estimate is attractive.
* Compare the same guards on the same patched executable; do not attribute a
  stock/patched Ruby build difference to tokens. Record source, binary,
  artifact and fixture hashes. Run one RPS cohort when bet A's harness exists.
* A per-unit micro prices a complete captured method set, including public
  reflection for Module holders (the C API only accepts Class). It is not a
  request speedup. Public reflection is a correctness-capable alternative;
  hooks are cheaper but miss suppressed callbacks and own-class visibility.
* Suppressed-hook, visibility, prepend and refinement probes must distinguish
  invalidation from scope: tokens do not certify lexical refinements, actual
  receiver identity, mutable values or arbitrary reentry. The sealed contract
  and all existing value/holder/continuation checks remain. Extra lookup
  witnesses do not turn a sealed unit into an unrestricted specialization.
* Only a unit that cannot reasonably be a generic framework patch, cannot be
  handled by the existing JIT, AND demonstrates a gated end-to-end benefit is
  an upstream use case. No qualifying rows means say **none**, not a proposal
  to expose the primitive because it is small.

## Prior ceiling evidence (not token measurements)

Bet U's blog guard ceiling is 73 objects/request out of a gross 416 saving
(17.55%). It includes non-method checks that tokens cannot remove. Fizzy's
block-link suffix guard costs 1,220 objects/vector against a gross ceiling of
59.5 (about 0.028% of off); its full exactness gate is red even off/off.
Block-link remains killed. These observations motivate a cost comparison,
not a token speed claim or permission to remove unrelated checks.
