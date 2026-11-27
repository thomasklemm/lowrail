# RK3 shared-unescape confirmation

**Nits on [fc894812](https://github.com/thomasklemm/rack/commit/fc894812dd7269da65685b4aea5b5d6cae3fbbeb). Approve the revised two-sentence reply.** The runtime extraction remains approved, the redundant comment is gone, and the public docs are restored with Rack's current generator. One older-generator compatibility nit remains; no required code or wording change is requested for Rack's documented workflow.

This is a short exact-head confirmation of that Thermos pass, performed directly in [the same review thread](https://ampcode.com/threads/T-01a21cee-48a3-76b0-a597-da463e562b1a), without new threads or delegated reviewers. It checks the amendment against the previously reviewed head and reruns the relevant documentation, contracts, differential and suites. It is not another audit of the earlier optimization commits or their speed claims.

## The amendment fixes the findings

* The `Also included in Rack::Utils` comment is gone. The hidden module no longer contains the public API prose.
* Utils retains the two original API-doc lines above `module_function :unescape`, with RDoc's meta-method block between the include and export.
* **Keep `:method:`, not my earlier proposed `:singleton-method:`.** RDoc 8.1.0 on Ruby 4.0.9 records `singleton=false`, public visibility, the original prose, and the explicit `unescape(s, encoding = Encoding::UTF_8)` call sequence. Base's methods are documented in this instance-style form. The generated HTML restores `method-i-unescape`, preserving the existing anchor rather than changing it to a class-method anchor. The parser's internal params field is `()` for the meta-method; its rendered signature correctly comes from call_seq.
* The shared module name, nesting, file location, privacy, and adjacent include/export remain appropriate for the reasons already recorded. There is no new runtime guard or mechanism.

### Nit: RDoc 7.2 still loses the entry

The real-file probe on Ruby 2.7.3 / RDoc 7.2.0 finds base's `unescape` entry but none at either extraction head. Running Rack's full documentation command with that bundle exits 0 but produces **zero** `method-i-unescape` anchors. This is a generator-version limitation, not a Ruby runtime failure. RDoc 7.2's Ruby parser handles `module_function` as visibility syntax before metaprogrammed-method comments; the older parser never creates this ghost entry at its current location.

I do **not** require a runtime wrapper, a new file, or `:singleton-method:` to address this. Rack's `.github/workflows/documentation.yaml` generates the canonical reference on `ruby`, which resolves the current RDoc 8 generator tested above. Keeping that reference intact resolves the original blocking documentation finding. The project also permits RDoc 7 in older-Ruby/JRuby development bundles, so record the limitation rather than saying every supported toolchain's docs are unchanged. If legacy-generator documentation becomes a requirement, a separately verified RDoc-only layout is needed; this pass has not established a minimal compatible layout.

### Every added comment line at this head

| Location | Comment | Decision |
| --- | --- | --- |
| query_parser.rb:41 | Inline `# :nodoc:` on the module | Keep: hides implementation detail. |
| utils.rb:64 | `##` | Keep: enables the RDoc meta-method entry. |
| utils.rb:65 | `# :method: unescape` | Keep: names the entry in the same form as base. |
| utils.rb:66 | `# :call-seq:` | Keep: introduces the actual API signature. |
| utils.rb:67 | `#   unescape(s, encoding = Encoding::UTF_8)` | Keep: prevents an empty-argument signature. |
| utils.rb:68 | `#` | Keep: separates the directive from the prose. |
| utils.rb:69 | `# Unescapes a URI escaped string with +encoding+. +encoding+ will be the` | Keep: original public API documentation, now at its consumer. |
| utils.rb:70 | `# target encoding of the string returned, and it defaults to UTF-8` | Keep: original public API documentation. |

The added block is functional API documentation, not implementation narration. The documented decoder's default, optional encoding and return behavior were already exercised; this amendment changes none of them.

## Exact-head checks executed

Fresh checkout: fork `unescape-cgi-6` resolves to the exact full head above. Its sole parent is [e26338b40a](https://github.com/thomasklemm/rack/commit/e26338b40a0c5bc83cb4eba645e5954fc264b699). Author and committer are Thomas Klemm `<github@tklemm.eu>`, no trailers; author date is unchanged at `2026-11-27T12:10:36Z`.

| Executed check | Decisive result |
| --- | --- |
| Diff against [0046982320](https://github.com/thomasklemm/rack/commit/0046982320094e11d80d2ec19bf0ab69f05ba41b), plus Ripper token/magic-header comparison of both files | Only the stated documentation/comment edits; runtime tokens and magic headers are identical. |
| `CI=spec RUBYOPT='' bundle exec rake` and `CI=spec RUBYOPT=-rcgi/util bundle exec rake`, Ruby 2.7.3 | Both exit 0: 1,315 runs, 5,725 assertions, 0 failures/errors, 2 skips; both finish `All test files passed`. |
| Same two full-suite commands, Ruby 4.0.9 | Both exit 0: 1,317 runs, 6,421 assertions, 0 failures/errors, 2 skips; both finish `All test files passed`. |
| `ruby rdoc_probe.rb BASE OLD NEW`, both Rubies | RDoc 8.1: base entry present, old head absent, new entry restored with instance-style metadata, original prose and explicit signature. RDoc 7.2: base present, both extraction heads absent. |
| Rack's actual `bundle exec rdoc --op OUTPUT --main README.md --template-stylesheets contrib/rdoc.css`, 4.0.9 | Exit 0; exactly one `method-i-unescape` anchor at the new head. |
| Same documentation command on 2.7.3 with `CI=spec bundle _2.4.22_ exec` | Exit 0; zero `method-i-unescape` anchors at the new head. |
| Prior `contracts.rb` on new head, both Rubies | All 12 checks pass, including private inclusion, public module function, snapshot semantics, subclass/prepend `super`, frozen objects and fiber-interleaved late coercion. |
| Independent `probe.rb` on new head, compared by `compare.py` against the kept old-head 4.0.9 output | 91,388 compared calls, **zero differences**, including exception-message encoding. |
| Rack RuboCop config on the two files | Same five existing offenses, exit 1; not a new lint failure or a clean-lint claim. |
| `git diff --check HEAD^ HEAD` | Clean. |

The previous base-vs-old-head adversarial results, loader checks and accepted malformed-ASCII error-message encoding correction therefore remain applicable; this is not a claim of literal equivalence to the pre-extraction parent. No additional load dependency was added. The four fresh full suites use the exact dependency locks retained in the previous review.

Receipts are retained in `receipts.tar.xz`; harness sources and dependency locks are in `../0046982320/`. Reused old-head differential output is in that review's archive as `probe-rack-4.0.9-clean.jsonl`. The new archive includes the full new-head differential output, documentation probes/generator logs, suite logs, contracts, token comparison, identity and both diffs. An initial documentation retry omitted `CI=spec` and failed on the excluded `bake-test-external` dependency before generation; the corrected run above completed. No fresh JRuby, TruffleRuby, macOS, Ruby master or YARD run is claimed.

## Commit message and reply

Sentence audit: the title remains accurate; “duplicated the decoding logic” fixes the literal-body nit; the `utils.rb` → `query_parser.rb` dependency sentence now states the existing direction without an absolute impossibility claim; the module-function/privacy/subclass sentence remains supported by both runtime contract checks; the new RDoc method-entry sentence is demonstrated by RDoc 8.1 and its HTML output, with the older-generator limit recorded above; the two error-message encoding sentences remain accurate and properly scoped to ASCII-only malformed inputs. No internal information is introduced.

**Reply approved as written, with no remaining nit:**

> Moved `unescape` into `Rack::QueryParser::Unescape`, which `QueryParser` and `Utils` include; `Utils` exports it with `module_function :unescape` ([fc89481](https://github.com/thomasklemm/rack/commit/fc894812dd7269da65685b4aea5b5d6cae3fbbeb)). For ASCII-only strings with invalid %-encoding, this also restores URI's error-message encoding; the local raise in `utils.rb` had made it binary.

Sentence one matches this exact head's sharing/export and identifies it correctly. Sentence two retains the already-demonstrated ASCII-only scope, cause and restoration to URI's message encoding. Both are short, neutral, and contain no internal details. Approval is a review verdict, not permission to post.

Only this Lowrail record and receipts are added. The Rack fork/PR branches, target checkout and RK3 queue item are untouched; no GitHub comment or review was posted.
