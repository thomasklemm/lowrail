# RK3 shared-unescape Thermos review

**Verdict: changes on [0046982320](https://github.com/thomasklemm/rack/commit/0046982320094e11d80d2ec19bf0ab69f05ba41b), for documentation and comments only.** No introduced runtime correctness or security blocker was demonstrated. Restore the public `Rack::Utils.unescape` documentation and remove the new architecture comment. The extraction, name, privacy, export and load order are otherwise acceptable. The disclosed error-message encoding correction is real, so this is not literal equivalence to the parent in every observable property.

Reviewed on 2026-11-27 in [this thread](https://ampcode.com/threads/T-01a21cee-48a3-76b0-a597-da463e562b1a). Exact base: [e26338b40a](https://github.com/thomasklemm/rack/commit/e26338b40a0c5bc83cb4eba645e5954fc264b699); head has that single parent. `thermos` was loaded. Two independent, read-only Task reviewers applied correctness/security and maintainability rubrics in parallel; the reviewing agent inspected the diff, ran the checks below and synthesized the result here. No other threads were created.

The correctness reviewer returned **nits**, treating lost docs as P3 and the architecture comment as useful; the maintainability reviewer returned **changes**, treating lost docs as P2 and the comment as a mandatory removal. The unified verdict follows the demonstrated public-documentation regression and DECISIONS' explicit comment gate. No runtime disagreement remains. This is not a fresh review of the already-approved two optimization commits or their performance claims.

## Must-fix findings

### P2: Preserve the public unescape documentation

Introduced at `lib/rack/utils.rb:62–63` and `lib/rack/query_parser.rb:42–47`.

The two existing API-doc lines moved from `Utils.unescape` into a `:nodoc:` module above a private method. RDoc does not synthesize a documented Utils method from `include` plus `module_function :unescape`. The public method disappears from the generated API reference; `unescape_path` still tells its reader to consult it.

Executed both an RDoc store probe and Rack's main-documentation generator on base and head, using Ruby 4.0.9 / RDoc 8.1.0. Base has one `unescape` entry and HTML method anchor; head has none. Both documentation commands exit 0, so successful generation alone does not detect this loss. See `rdoc-probe.log`, `rdoc-ci-*.log`, and `documentation-summary.txt` in the receipts.

**Smallest fix:** keep the shared module hidden, but move the original API prose back to the Utils export. Mark that generated method for RDoc rather than adding a runtime forwarding method. This diagnostic-only version restored a public singleton-method entry with the original prose and a call signature:

```ruby
include QueryParser::Unescape

##
# :singleton-method: unescape
# :call-seq:
#   unescape(s, encoding = Encoding::UTF_8) -> String
#
# Unescapes a URI escaped string with +encoding+. +encoding+ will be the
# target encoding of the string returned, and it defaults to UTF-8
module_function :unescape
```

The diagnostic lives only in scratch copies, not the reviewed checkout. RDoc directives here describe the public API; they are not explanatory implementation comments. RDoc was checked; YARD was not.

### P3: Remove the new architecture comment

Introduced at `lib/rack/query_parser.rb:41`:

```ruby
# Also included in Rack::Utils, which requires this file.
```

**Smallest fix:** delete that line. It describes the consumer and require wiring that Utils already states in code; it does not explain a non-obvious correctness constraint at this location. The commit message is the right home for the placement explanation. Rack's in-place `Response::Helpers` extraction is a close precedent without an equivalent consumer comment.

The correctness reviewer considered the line useful orientation. On the stricter rule Thomas specifically requested, its information is redundant with the two includes and existing require, so it does not justify an additional upstream comment. DECISIONS classifies a superfluous comment as **changes**, not a nit. This is a Lowrail standards finding, not a claim that either maintainer has objected to the line.

## Maintainer idiom and placement

**Would ioquatix and jeremyevans name and place it this way?** This is a plausible, proportionate Rack-style extraction; source history supports the pattern, but cannot prove either person's preferred exact name. Do not rename or add a file merely to guess their preference.

| Decision | Judgment and evidence |
| --- | --- |
| `Unescape` | Keep. A small operation-specific name for the one shared method is clear. Rack's nested helpers use several naming forms; there is no demonstrated requirement to call this `Helpers` or `Unescaper`. |
| Nested under `QueryParser`, in query_parser.rb | Keep. Utils already requires QueryParser; QueryParser already owns both decoder dependencies. Rack extracts shared `Request::Helpers` and `Response::Helpers` in their owner's files. No new require or Rack autoload is needed. |
| New file or top-level `Rack::Unescape` | Not justified for this extraction. A separate file adds loader work without removing a dependency problem. Top-level shared modules exist in Rack, so the builder's middleware argument is only a heuristic, not a naming rule. |
| `private` in the module | Keep. The contributed method should be private for QueryParser and ordinary Utils inclusion. It does not prevent a subclass from overriding and calling `super`. No redundant `private :unescape` is needed in QueryParser. |
| Inline `# :nodoc:` | Keep on the module declaration. This is implementation detail and should not become another public API page. |
| Two-line API comment inside the hidden module | Keep its content, but move it back to the public Utils export with RDoc metadata. Its current location causes the documentation regression. |
| The one-line consumer comment | Drop, as above. The commit message already explains the placement. |
| `include Unescape` immediately after the module | Keep. `Response` similarly includes `Helpers` immediately after its definition. |
| Utils include/export at the former method location | Keep the pair together there; insert the public API documentation between include and export. The explicit named `module_function` is needed for an included method. The earlier argumentless `module_function` applies to subsequent definitions and does not export this include by itself. |

History inspected by the maintainability reviewer: [7f889ec3](https://github.com/rack/rack/commit/7f889ec35dfb7dd90828e12af5e1b2d7859f9384) (`Response::Helpers` extraction), [7f1fcde2](https://github.com/rack/rack/commit/7f1fcde28785051886b9d88dc66db32c932d94d2) (`Request::Helpers`), Samuel Williams' [dbced5bf](https://github.com/rack/rack/commit/dbced5bfaa06904ef89ad8a7d29d4605c4041062) (work inside `Response::Helpers`) and [59d9ba90](https://github.com/rack/rack/commit/59d9ba903fdb50cf8db708c8263a7b2a79de83fb) (make QueryParser independent of Utils), Jeremy Evans' [7e7a3890](https://github.com/rack/rack/commit/7e7a3890449b5cf5b86929c79373506e5f1909fb) (QueryParser extraction) and [c07e1b96](https://github.com/rack/rack/commit/c07e1b96cc15bd943000670330e5cc824c47ae4f) (argumentless module_function). These support the ownership and export choices, not a prediction of personal naming preference.

### Every added comment line

| Head line | Exact comment | Keep/drop |
| --- | --- | --- |
| query_parser.rb:41 | `# Also included in Rack::Utils, which requires this file.` | **Drop.** Redundant topology narration; P3 above. |
| query_parser.rb:42 | `# :nodoc:` on `module Unescape` | **Keep.** Hides implementation detail in Rack's inline directive style. |
| query_parser.rb:45 | `# Unescapes a URI escaped string with +encoding+. +encoding+ will be the` | **Keep and relocate** to Utils' public API documentation. |
| query_parser.rb:46 | `# target encoding of the string returned, and it defaults to UTF-8` | **Keep and relocate** with the preceding line. |

No comment lines are added to Utils in this head. The older MRI escape comment is unchanged and is not an added comment in this review.

### Surviving guards and cold read

No new guard or runtime branch is introduced. The shared method sends non-plain Strings and ASCII-incompatible encodings to URI; it rejects malformed percent escapes before calling CGI; otherwise it decodes into binary bytes and applies the requested output encoding once, after decoding. Utils exports that same method as a module-function snapshot; QueryParser finds it through inclusion.

* `instance_of?(String)` preserves URI handling of subclasses and their object state. The accepted parent already has the BasicObject boundary; it is not introduced here.
* `encoding.ascii_compatible?` preserves the existing URI fallback for incompatible input encodings. Moving code is not a reason to change this guard.
* `/%(?!\h\h)/.match?(s)` rejects invalid escapes because CGI would accept them. This is an existing validation boundary.

No guard for method owner, reflection, loader state or hypothetical future consumers is needed. Readability is L0 for runtime code: one implementation replaces two, without a new algorithm, wrapper or conditional. The declaration and public-documentation concerns above are separate from runtime complexity.

## Independent executed evidence

Commands were run from `.amp/in/orb-backup/rk3-0046982320/` unless noted. `rack/` is the exact candidate and `base/` is its exact parent. Both Rack worktrees remained clean. Raw outputs are in `receipts.tar.xz`; reproducible probe sources, lockfiles and the candidate patch are retained alongside this report.

### Full suites on the actual minimum and Ruby 4.0

`rack.gemspec` declares Ruby `>= 2.7.3`. Installed the official `ruby/ruby-builder` `toolcache` release artifact `ruby-2.7.3-ubuntu-24.04.tar.gz` (SHA-256 `a3167308e6d194f81d933561b88651b274b6523811a6d705aa78c514dea56f62`) at its expected `/opt/hostedtoolcache/Ruby/2.7.3/x64` prefix. Ruby 4.0.9 is the installed mise binary, revision `3e93b23afc`.

Ran `CI=spec RUBYOPT='' bundle exec rake` and `CI=spec RUBYOPT=-rcgi/util bundle exec rake` in both checkouts, with the same dependency lock per Ruby. On 2.7.3 used Bundler 2.4.22; on 4.0.9 used Bundler 4.0.20. All eight full commands exited 0 and finished with **All test files passed**, including Rack's separate-file require tests:

| Ruby | Base and head, each clean and cgi/util | Result |
| --- | --- | --- |
| 2.7.3p183 | 1,315 runs, 5,725 assertions | 0 failures, 0 errors, 2 skips |
| 4.0.9 | 1,317 runs, 6,421 assertions | 0 failures, 0 errors, 2 skips |

These are the aggregate regular-suite rows, not a sum of the additional separate-file runs. Resolved dependencies are kept in `Gemfile-2.7.3.lock` and `Gemfile-4.0.9.lock`. The 2.7 bundle includes CGI 0.5.2 through ERB; default-native CGI was also independently exercised in the differential below.

### My own adversarial differential

Ran `ruby -I "$tree/lib" probe.rb` for each tree and `python3 compare.py BASE.jsonl HEAD.jsonl`. This is an independent harness, not the builder's generator. It compares successful class/bytes/encoding/frozen/validity/ivar signatures, exceptions and their message bytes/encoding, input state after the call, and callback traces. It uses all non-dummy runtime encodings, four explicit dummy encodings, valid and malformed escapes, invalid bytes, ASCII-incompatible/non-ASCII edge cases, frozen inputs, seeded random fragments, String subclasses, singleton overrides, non-String scalars/collections, BasicObject, private/public conversions, method_missing, once-only and input-mutating encoding conversion, all four decoder routes, both escape routes and representative query/cookie parsing.

| Ruby / mode | Compared calls | Message-encoding-only changes | Unexpected differences |
| --- | ---: | ---: | ---: |
| 2.7.3 normal gem resolution, clean | 90,742 | 12,094 | 0 |
| 2.7.3 normal gem resolution, cgi/util | 90,742 | 12,094 | 0 |
| 2.7.3 isolated GEM_HOME/GEM_PATH, native CGI, clean | 90,742 | 12,094 | 0 |
| 2.7.3 isolated GEM_HOME/GEM_PATH, native CGI, cgi/util | 90,742 | 12,094 | 0 |
| 4.0.9 native CGI, clean | 91,388 | 12,206 | 0 |
| 4.0.9 native CGI, cgi/util | 91,388 | 12,206 | 0 |

Total: **545,744 compared calls, no unexpected difference**. The classifier accepts only Utils/mixin `ArgumentError` messages starting with `invalid %-encoding`, with identical message bytes and all other fields identical, whose encoding changes from ASCII-8BIT to UTF-8. It does not normalize successful results or other exceptions. `NoMethodError#original_message` excludes Ruby's source-location highlight decoration; process-specific addresses in exception text are normalized.

No returned value, escape result, exception class, message bytes or callback trace differed. The only runtime difference demonstrated is the explicitly disclosed encoding of malformed-ASCII Utils error messages. The separate reflection probe confirms QueryParser's parameter name changes `string` → `s` and its owner becomes the mixin; reflection ownership and direct-method listings necessarily change with this extraction.

`contracts.rb` passed all 12 checks on both Rubies and both trees: singleton/public vs instance/private visibility, arity, QueryParser subclass and prepend overrides with `super` through parsing, Utils includer override with `super`, frozen receiver/argument behavior, late single encoding conversion suspended in a fiber while the input mutates, later Utils module functions, singleton prepend, and module-function snapshot semantics after an instance-side replacement. All nine require/autoload scenarios matched on 4.0.9 (`loading-summary.txt`), including standalone query_parser without Utils, both require orders and root-Rack lazy loading.

The independent correctness reviewer additionally exercised concurrent loading, all three parsing entry points through subclass overrides, and large/dense/early/late malformed inputs. Those are secondary review observations, not additional executions claimed by this agent or primary raw receipts here.

### Exactness checklist coverage

1. **Singleton methods, extend/prepend and missing methods:** singleton String dispatch and missing/private conversions were compared; subclass/prepend/singleton-Utils overrides with super were executed. No new call on a supplied object is introduced by the move.
2. **Subclasses:** tagged String subclasses were compared through every decoder/escape route. Hash/Array arguments were included; collection-subclass iteration overrides are not relevant to this diff because it adds or changes no iteration or collection conversion.
3. **Implicit conversion:** public/private to_s and to_str, callback traces, once-only encoding coercion and mutation were checked. No to_a/to_ary/to_hash operation is introduced or removed.
4. **Added/skipped dispatch:** the decoder expression sequence is unchanged apart from the parameter name and lexical source encoding. The differential compares callback traces and explicitly checks that source-encoding effect.
5. **Copies and accumulators:** return class/ivars/frozen state and input state were compared. No new accumulator or adoption of a user-returned collection exists here.
6. **Mutation and fibers:** input mutation during encoding coercion was compared; a suspended coercion resumed after mutation still yields the already-decoded original value exactly once.
7. **Frozen objects and exceptions:** frozen arguments/receivers, malformed escapes, invalid encodings, exception class/message bytes/message encoding were exercised. The disclosed error-message encoding correction is not hidden as equality.
8. **Loading:** standalone component requires, both require orders and Rack's lazy autoload state were compared. No changed configuration read or new require was found.

### Builder claims checked, not adopted wholesale

Read the builder's README and harnesses, extracted its committed `suite-logs.tar.xz`, and checked all 28 log summaries against `suites.txt`: the reported rows and separate-file success markers match. That is an audit of the existing receipts, not my own rerun on the five intermediate Rubies.

Also independently reran the builder's `replay.rb suite-inputs.rec` on base/head on 2.7.3 and 4.0.9. Each emitted **204,073 lines**; the base/head comparison found 9,767 differing lines: 9,764 with only the disclosed message encoding, two process-specific addresses inside escaped Object#to_s, and one QueryParser parameter-name reflection line. The three non-encoding lines were inspected directly (`builder-replay-compare-*.txt`). The comparator's `other differences: 3` is not a runtime failure. The five intermediate Rubies and builder's entire 16-mode replay matrix were not re-executed here.

Direct `message-encodings.log` probes on 2.7.3 and 4.0.9 show `Utils.unescape("%")`: base message ASCII-8BIT; head, QueryParser and URI UTF-8; bytes and exception class identical. Non-ASCII UTF-8 and ISO-8859-1 examples retain their original matching message encodings. Source inspection establishes why: utils.rb declares binary source encoding; query_parser.rb and URI use UTF-8 source strings. The discrepancy began with the earlier local raise, not with this extraction. “Again” is supported because pre-optimization Utils delegated to URI.

### Documentation, static checks and metrics

Ran `ruby rdoc_probe.rb BASE HEAD DOCFIX`: base has the documented method, head has none, scratch DOCFIX has a public singleton `unescape` with the original prose. Ran Rack's actual main-documentation command from both worktrees, changing only the output directory: `bundle exec rdoc --op OUTPUT --main README.md --template-stylesheets contrib/rdoc.css`. Both exit 0; base `Rack/Utils.html` has an unescape method anchor and head does not. The existing `unescape_path` reference is unresolved at head.

`git diff --check BASE HEAD` passes. Rack's RuboCop config on the two touched files reports the same **five existing offense identities** on base/head, exit 1, not a clean lint claim. RuboCop 1.93.0 `--only Metrics` reports zero offenses both times. Flog 4.10.0 gives 10.3 to each former decoder and 10.3 to the single shared method; no per-method increase. Full-file totals include declarations and are not used as a performance measure. No runtime benchmark, allocation, instruction or time claim was made or revalidated for this refactor.

### Review execution corrections and limitations

An initial suite wrapper invoked Rake outside its checkout and failed before tests because gem_tasks could not find a gemspec; it was corrected to `rake -C CHECKOUT`. A later reporting wrapper could not find `rg` after replacing PATH; the completed test log was preserved and subsequent commands retained the original PATH. The initial independent probe had two nondeterministic escaped default-Object addresses; it was corrected to undefine Object#to_s in the method_missing fixture, so that fixture actually exercises the intended deterministic conversion. Final archived probe outputs are from the corrected harness, not filtered earlier failures.

JRuby, TruffleRuby, macOS, Ruby master, YARD, and the full suite on the five intermediate MRI pins were not run here. Existing builder evidence for those intermediate MRIs was audited as described. This pass does not claim global equivalence for arbitrary Ruby metaprogramming, nor does it approve later heads automatically.

## Commit message sentence audit

The commit has Thomas Klemm `<github@tklemm.eu>` as author and committer, an SSH signature, and no trailers. Its exact message and patch are retained.

| Sentence | Verdict |
| --- | --- |
| Title: “Share unescape between Utils and QueryParser” | Keep. Plain and accurate. |
| “Rack::Utils.unescape and QueryParser#unescape had the same body.” | Nit: same decoding logic, not literally the same source text or all string-literal semantics. Prefer “duplicated the decoding logic.” Their parameter names differed and the later paragraph correctly explains the source-encoding difference. |
| “Utils requires query_parser, so QueryParser cannot take the method from Utils.” | Nit: too absolute; historical QueryParser delegated to Utils. Say “Utils already requires query_parser, so keep the shared method in query_parser.rb” or qualify the circular eager-loading concern. No runtime fix follows from this wording nit. |
| “Move unescape into a module in query_parser.rb that both include.” | Keep. Exact code shape. |
| “Utils makes it a module function as before, so Rack::Utils.unescape still works and including Utils still gives a private unescape, and QueryParser subclasses can still override it.” | Keep as factual, optionally split for readability. All asserted runtime properties were executed, including super and snapshot semantics. |
| “utils.rb is a binary source file, so the ArgumentError that Utils.unescape raised for an invalid %-encoding of an ASCII-only string had a binary message.” | Keep. Verified on both Rubies; the ASCII-only qualification matters. This is a parent regression being corrected, not a new head defect. |
| “It now has the encoding of URI's message, as QueryParser#unescape's already did.” | Keep. Verified class, bytes and encoding against actual URI in both runtimes. |

No internal queue, Lowrail, review-process or attribution information leaks in this message. The optional first-paragraph wording improvements do not change the documentation/comment must-fixes.

## Reply draft sentence audit

1. “Moved it into a `Rack::QueryParser::Unescape` module that `QueryParser` includes and `Utils` includes with `module_function :unescape`, in 0046982.” **Factually correct.** The full exact head and both includes were inspected. Slightly repetitive; can be shorter. The SHA is upstream-relevant, not an internal ID.
2. “This also makes the encoding of `Utils.unescape`'s invalid %-encoding message match URI's again; it had picked up utils.rb's binary source encoding.” **Supported.** Add “For ASCII-only strings” to make the scope explicit rather than suggesting all malformed inputs previously had binary messages. “Again” is supported by the pre-optimization URI delegation. No internal information is present.

**Verdict on draft: nits, no factual or tone blocker.** Suggested two-sentence wording for this exact head:

> Moved `unescape` into `Rack::QueryParser::Unescape`, which `QueryParser` and `Utils` include; `Utils` exports it with `module_function :unescape` (0046982). For ASCII-only strings with invalid %-encoding, this also restores URI's error-message encoding; the local raise in `utils.rb` had made it binary.

If the builder amends the code, replace the SHA and confirm the new exact head before posting. This pass does not authorize posting. GitHub's read-only API confirmed jeremyevans's approval is for e26338b40a, and his inline comment requests the shared-module approach; that approval is not being attributed to the new commit.

## Delivery and scope

Only this Lowrail report and its receipts are changed. The queue item, Rack checkouts, fork branch and PR branch are untouched; nothing was posted on GitHub. The requested Lowrail-only commit/pull-rebase/push is permitted by the task. The coordinator still owns obtaining the code/doc fixes, any exact-head confirmation and Thomas's approval of the eventual upstream reply.
