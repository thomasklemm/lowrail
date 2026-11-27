# RK3 RDoc and YARD confirmation

**Nits on [3ca13466](https://github.com/thomasklemm/rack/commit/3ca13466d56965731d4419cd465ad6e33dce9ace); approve its commit message and revised two-sentence reply unchanged.** The requested documentation fixes work, including older RDoc, and the separator changes none of the following attributes. No runtime, security or maintainability must-fix remains. One optional YARD exception-tag preservation nit is described below.

This is a short direct confirmation after the [previous pass](../fc894812/README.md), not another independent Thermos pair or a review of the approved optimization commits. No new thread or reviewer was created. Exact fork branch: `unescape-cgi-7`; sole parent: [e26338b40a](https://github.com/thomasklemm/rack/commit/e26338b40a0c5bc83cb4eba645e5954fc264b699). Thomas Klemm `<github@tklemm.eu>` remains author and committer, the author date remains `2026-11-27T12:10:36Z`, and there are no trailers.

## The documentation repair works

Independently parsed **all `lib/**/*.rb`** in the parent, [fc894812](https://github.com/thomasklemm/rack/commit/fc894812dd7269da65685b4aea5b5d6cae3fbbeb) and this exact head, in separate processes per tree. The kept `documentation_dump.rb` exports docstrings, parameters/call sequences, visibility, attribute read/write flags, and YARD tags; `compare_documentation.py` compares the raw records. This is a fresh local YARD 0.9.46 execution, not a claim that rubydoc.info has rebuilt this fork.

* **YARD 0.9.46 / Ruby 4.0.9:** both `Rack::Utils.unescape` and `Rack::Utils#unescape` now have exactly the parent's parameters and original prose. The class method remains public, the instance method private. The previous head had empty parameters and docstrings.
* **RDoc 8.1.0 / Ruby 4.0.9:** all exported method/attribute records are identical to fc894812, including `unescape`. Keep `:method:`, preserving the parent reference's instance-style entry.
* **RDoc 7.2.0 / Ruby 2.7.3 and RDoc 7.0.4 / Ruby 4.0.9:** the entry is restored as a public `GhostMethod` with the correct explicit call sequence and original prose. Raw records have a leading docstring newline and trailing call-sequence newline; those are retained, not reported as byte-identical metadata. Their displayed content agrees with the parent.
* The actual Rack documentation command on Ruby 2.7.3 and 4.0.9 exits 0, each producing exactly one `method-i-unescape` HTML anchor. The previous older-RDoc nit is resolved.
* **The `##` before `class << self` changes nothing in the following attributes.** All four tool/version configurations have byte-equal exported records against both parent and previous head for `multipart_total_part_limit`, `multipart_file_limit`, their writers, and both `multipart_part_limit` aliases: six YARD records, or two RDoc read/write attribute records plus two alias records. No directive prose or signature leaks into those records.

The parent-versus-head RDoc differences are confined to `Utils#unescape`'s explicit meta-method signature/record form. YARD additionally shows the expected private method relocation from QueryParser to the nested module and the module's `:nodoc:` text. The builder's exhaustive-differences claim misses the inferred exception tag below. No unrelated method, namespace or attribute documentation difference was found in the exported fields.

## Optional nit: preserve YARD's inferred exception tag

On the parent, public `Rack::Utils.unescape` has YARD tag `@raise [ArgumentError]`, inferred from the method body. At this head, the tag list is empty even though the restored docstring and parameters match. The actual exception behavior is unchanged. This is a nonblocking loss of generated exception metadata, not another missing-method or wrong-signature defect.

**Smallest optional fix:** add `#   @raise [ArgumentError]` to the standalone YARD method block. Executed that one-line diagnostic in a separate scratch copy: the complete exported public Utils method record then equals the parent's, and every exported RDoc record remains unchanged in all three versions. YARD also adds that tag to the private Utils instance copy, whose base record had no inferred tag. No fix was applied to the target checkout or fork.

## Added comments and message/reply audit

| Added comment line | Keep/drop |
| --- | --- |
| `# @!method self.unescape(s, encoding = Encoding::UTF_8)` | **Keep:** creates the missing YARD method signature. |
| `#   Unescapes a URI escaped string with +encoding+. +encoding+ will be the` | **Keep:** original API prose for YARD's separate entry. |
| `#   target encoding of the string returned, and it defaults to UTF-8` | **Keep:** completes that API documentation. |
| `##` before `class << self` | **Keep:** functional documentation separation, with no attribute metadata change. |

The earlier comment decisions still apply. The new lines are API documentation/metadata rather than architecture narration. The module name, nesting, same-file location, privacy and adjacent include/export need no change. The amended commit sentence, “Its documentation stays in Utils as RDoc and YARD method entries,” is now directly supported by both parsers. Every other message sentence is unchanged from the approved wording and remains supported by the prior runtime checks.

**Reply approved unchanged:**

> Moved `unescape` into `Rack::QueryParser::Unescape`, which `QueryParser` and `Utils` include; `Utils` exports it with `module_function :unescape` ([3ca1346](https://github.com/thomasklemm/rack/commit/3ca13466d56965731d4419cd465ad6e33dce9ace)). For ASCII-only strings with invalid %-encoding, this also restores URI's error-message encoding; the local raise in `utils.rb` had made it binary.

Sentence one accurately names the shared implementation, exports and exact head. Sentence two preserves the verified ASCII-only scope, source-encoding cause and URI comparison. Neither sentence leaks internal details, and neither requires wording changes. This approval does not authorize posting.

## Fresh checks and limitations

* `CI=spec RUBYOPT='' bundle exec rake` and the `RUBYOPT=-rcgi/util` variant on Ruby **2.7.3 and 4.0.9**: four final full commands exit 0 with `All test files passed`. The 2.7 rows are 1,315 runs / 5,725 assertions; the 4.0 rows 1,317 / 6,421; all have 0 failures/errors and 2 skips. Reused the previously kept per-Ruby dependency locks; 2.7 uses Bundler 2.4.22.
* **An initial 2.7 clean run did fail:** unchanged `Rack::Deflater` gzip-mtime assertion, `1795783625 >= 1795783626`, with 1 failure / 0 errors. The failing log is kept as `suite-2.7.3-clean-first.log`. Read the assertion and implementation and confirmed neither changes in this commit. A bounded full rerun passed. The timing failure's underlying cause was not established; this is not an all-attempts-green claim.
* `documentation_dump.rb` and `compare_documentation.py`: whole-lib results above; no false byte-equality claim for older RDoc's surrounding whitespace. API parameter/prose checks and following-attribute checks all pass. YARD emits the same pre-existing unknown `@returns` warning in request.rb in every tree.
* `CI=spec bundle exec rdoc --op OUTPUT --main README.md --template-stylesheets contrib/rdoc.css`: real HTML generation and anchor check on both Rubies pass.
* `contracts.rb`: all 12 visibility, override, `super`, module-function snapshot, frozen-object and fiber-coercion checks pass on each Ruby.
* Ripper runtime tokens and the first two magic-header lines of both touched files are identical to fc894812; no new require or executable token exists. The prior independent runtime differential therefore carries forward; no fresh 91,388-call replay is claimed for this comment-only amendment.
* `git diff --check HEAD^ HEAD`: clean. RuboCop: exactly the same five existing offense identities and source lines as parent, exit 1. The optional maintenance group was not active for an initial bundled RuboCop invocation; the successful comparison uses the already installed CLI directly with Rack's configuration.

`receipts.tar.xz` retains the complete raw documentation dumps and diffs for all three trees, both reusable documentation harnesses, the optional diagnostic patch/output, all five suite attempts, contracts, tokens, identity, HTML generator logs and lint output. Runtime contract source and dependency locks remain in `../0046982320/`. No new intermediate-MRI suite, JRuby, TruffleRuby, YARD version other than 0.9.46, or upstream-hosted documentation rebuild is claimed.

Only this Lowrail report/receipts are delivered. The Rack target checkout is clean; no fork/PR branch push, GitHub post or RK3 queue edit occurred.
