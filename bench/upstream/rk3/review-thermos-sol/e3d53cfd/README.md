# RK3 neutral shared-decoder Thermos review

**Verdict: nits on [e3d53cfd](https://github.com/thomasklemm/rack/commit/e3d53cfdb2f9689646dc754ea20885bf29169e6a). No must-fix. Approve the revised two-sentence reply unchanged.** The neutral `Rack::Unescape` file, both direct requires, privacy and export are appropriate. Two optional nits remain: YARD's formerly inferred exception tag and a garden-path sentence in the commit message. The private-composition difference below is real, not hidden by the verdict.

Reviewed on 2026-11-27 in [this thread](https://ampcode.com/threads/T-01a21cee-48a3-76b0-a597-da463e562b1a), with `thermos` loaded and two independent, read-only Task reviewers running the correctness/security and maintainability skills in parallel. No other threads were created. This is a full new pass on the third commit, not just a carry-forward from the earlier documentation confirmation.

Exact fork branch: `unescape-cgi-8`. Head: `e3d53cfdb2f9689646dc754ea20885bf29169e6a`; sole parent: `e26338b40a0c5bc83cb4eba645e5954fc264b699`. `git rev-list --count BASE..HEAD` is 1. Therefore the two approved optimization commits are unchanged ancestors. Thomas Klemm `<github@tklemm.eu>` is author and committer, both dates are `2026-11-27T13:06:54Z`, an SSH signature is present, and there are no trailers.

## Findings and reviewer disagreement

### No required fix; record the changed private-method precedence

The correctness reviewer returned **changes**, grading this P2 at `query_parser.rb:8` and `utils.rb:63–72`: an included implementation sits below methods defined in its consumer, whereas the former local definition masked methods supplied by other includes. The maintainability reviewer returned **approve**, with one optional message wording nit. The unified verdict is **nits**, after independently reproducing and assessing the correctness finding, not a claim that both reviewers approved.

Reproduction on Ruby 2.7.3 and 4.0.9, each against base, previous extraction `3ca13466`, and current head:

```ruby
require 'rack/utils'
module OtherDecoder
  private
  def unescape(value, encoding = Encoding::UTF_8)
    CGI.unescape(value, encoding)
  end
end
Rack::QueryParser.include OtherDecoder
Rack::QueryParser.make_default(32).parse_query('a=%zz')
```

Base raises `Rack::QueryParser::InvalidParameterError`; both extraction heads return `{"a" => "%zz"}`. An included wrapper using `super` similarly starts participating where it was previously masked. A QueryParser grandchild including Utils can also encounter shared-ancestor deduplication and reach its parent's custom decoder during mixed-in cookie parsing. The reviewer demonstrated both effects and an in-memory method-copy repair. My `precedence_check_e3d53cfd.rb` and rerun of the reviewer's composition harness independently reproduce the outputs on both pins; raw output is `precedence-independent.log`.

**Disposition: nonblocking private-composition boundary, not an unmodified-Rack validation bypass.** The parser rejects the malformed input on all three trees until the application installs another private decoder. No in-tree production caller or working normal custom-parser request was shown to depend on the old masking. Ordinary subclass overrides, included/prepended wrappers in subclasses, and `super` continue working. Utils' exported singleton snapshot still rejects the malformed input even after the QueryParser include. The escaping-sensitive boundary was exercised rather than dismissed without a check.

The grandchild/Utils collision was already explicitly recorded and accepted without an opaque local alias in the [earlier Astra review](../../review-astra/0046982320/README.md#demonstrated-differences-and-their-disposition). Both effects are present in `3ca13466`; neither is a consequence of neutral ownership or the new file. This attribution does not make them equal to the named parent. It explains why this pass does not silently reopen the previously accepted extraction boundary while reviewing the placement change.

The smallest repair **if preserving arbitrary private include precedence becomes a requirement** is to install the shared `UnboundMethod` locally in both consumers with `define_method`, keep it private, and retain Utils' named `module_function` export. The reviewer verified that repair in memory. I do not request it here: it adds method-copying machinery instead of the included-module dispatch the maintainer requested, without a real caller requiring the former private masking. There is no claim of equivalence under arbitrary monkey-patching.

### Optional nit: YARD loses its inferred exception tag

At `utils.rb:74–76`, the public YARD method has the correct original prose, parameters, scope and visibility, but its tags are empty. Base has an inferred `@raise [ArgumentError]` from the old local method body. This is the same nonblocking metadata nit as `3ca13466`, not a missing API method or an exception-behavior regression.

**Smallest optional fix:** `#   @raise [ArgumentError]` in the YARD method block. The previous pass executed that one-line diagnostic and established that it restores the public record while leaving RDoc records unchanged. This pass freshly confirms the missing tag and identical current/previous Utils documentation records; it does not claim a new execution of that diagnostic patch. No change was applied to Rack.

### Optional nit: clarify one commit-message sentence

“including Utils still gives” initially reads as a list rather than mixing in the module. Optionally replace the long sentence with: “Utils still exports it as a module function and provides a private method when included. QueryParser subclasses can still override it.” Its existing factual claims are correct. Neither nit alone justifies rebuilding an otherwise approved exact head.

## Maintainer idiom: neutral ownership fits this revision

**Would ioquatix and jeremyevans name and place it this way?** This is a defensible Rack-style implementation of the requested shared module. Source and history support it; neither person's exact naming preference can be proven. Thomas's neutral-ownership requirement supersedes the earlier report's preference for avoiding a new file.

| Decision | Judgment |
| --- | --- |
| `Rack::Unescape` | **Keep.** Names its one operation and gives neither consumer ownership of the other. A singleton decoder object or forwarding wrapper is unnecessary. |
| `lib/rack/unescape.rb` | **Keep.** A small provider used by two consumers owns its URI/CGI dependencies. Defining a top-level module inside QueryParser's file would retain consumer-owned physical placement. |
| No autoload in rack.rb | **Keep.** rack.rb promises autoloads for modules meant for applications. This `:nodoc:` implementation is required directly by both users; it is not another advertised root entry point. Root-only loading remains lazy. |
| QueryParser include at class top | **Keep.** Standard external-mixin placement makes the dependency clear. Rack's ContentLength and ContentType do this. Request/Response include locally defined Helpers later because those modules must first be defined; that is not a rule for this external provider. |
| Utils include at old decoder location | **Keep.** Inclusion, export and API documentation remain together. A top-of-module move would also work but does not remove a problem. |
| Direct helper require in both files | **Keep.** Both name the helper, so both declare the dependency. QueryParser's current transitive load is not a reason for Utils to hide its dependency. |
| Remove QueryParser's direct URI/CGI requires | **Keep.** Its remaining implementation uses neither; the provider explicitly requires both before its definition. Utils retains its own requires because its remaining escape methods still use them. |
| `private` in provider | **Keep.** Makes the inherited instance method private for both consumers and permits overrides with `super`. It does not change other methods' visibility in the consumers. |
| Inline `# :nodoc:` | **Keep.** Rack's declaration-level directive marks implementation detail without another method-level directive. |
| API docs in Utils, named export adjacent | **Keep.** RDoc/YARD describe the public consumer where readers expect it. `module_function :unescape` is required: the earlier argumentless mode does not export an included method by itself. Subsequent Utils methods remain module functions. |

History inspected by the maintainability reviewer includes Samuel Williams' [723b5384](https://github.com/rack/rack/commit/723b5384f2dcd6541477a42262f75e45276b595c), “Add general Rack::BadRequest.” It supports a neutral Rack-level shared module in a separate file with consumer requires. **It also added a root autoload:** BadRequest is a documented exception marker applications rescue, unlike this internal decoder. It does not justify claiming all small shared modules omit autoloads. Other inspected commits cover standalone component requires (`2833813b`), circular/multipart loading (`cd4b3c93`), QueryParser's independence from Utils (`59d9ba90`) and unused-require removal (`0e454ec4`).

**Rejected Utils nesting was checked, not assumed.** In my isolated namespace experiment, defining Utils before root Rack suppresses its later autoload and leaves public unescape absent; opening Utils after root Rack triggers its autoload eagerly. The reviewer additionally tried the proposed nesting at the actual helper-loading point: it raises `NameError: uninitialized constant Rack::Utils::QueryParser`, because the QueryParser class has not yet been declared. This is not proof that every carefully rearranged Utils-nested design is impossible. It shows why that alternative is not a cost-free rename and conflicts with the ownership goal.

### Every added comment line: all keep

| Head location | Exact added comment | Keep/drop |
| --- | --- | --- |
| unescape.rb:1 | `# frozen_string_literal: true` | **Keep:** functional magic comment and Rack convention. |
| unescape.rb:7 | `# :nodoc:` inline on module | **Keep:** marks the implementation module non-API. |
| utils.rb:65 | `##` | **Keep:** RDoc metaprogrammed-method marker. |
| utils.rb:66 | `# :method: unescape` | **Keep:** declares the generated RDoc method, including older RDoc. |
| utils.rb:67 | `# :call-seq:` | **Keep:** explicit signature metadata after removing the local def. |
| utils.rb:68 | `#   unescape(s, encoding = Encoding::UTF_8)` | **Keep:** that public signature. |
| utils.rb:69 | `#` | **Keep:** separates call sequence from prose. |
| utils.rb:74 | `# @!method self.unescape(s, encoding = Encoding::UTF_8)` | **Keep:** creates the YARD method/signature. |
| utils.rb:75 | `#   Unescapes a URI escaped string with +encoding+. +encoding+ will be the` | **Keep:** public API prose for that YARD entry. |
| utils.rb:76 | `#   target encoding of the string returned, and it defaults to UTF-8` | **Keep:** completes that API contract. |
| utils.rb:78 | `##` | **Keep:** functional boundary before the singleton-class attributes. |

The two original RDoc prose lines at utils.rb:70–71 are retained, not added. No architecture narration or one-line consumer comment remains. The reviewer removed individual directives in fragment probes: losing the first marker removed RDoc 8.1's entry; losing `:method:` removed RDoc 7.0.4's; losing the final separator erased YARD's parameters/prose. Full-library output below confirms the complete blocks and following attributes work together.

### Guards, cold read and complexity

No new algorithm or guard is introduced. The shared method sends non-plain Strings and ASCII-incompatible inputs to URI, rejects malformed percent escapes before CGI, then decodes binary bytes and applies the requested encoding after decoding. QueryParser includes that private implementation; Utils includes and exports its module-function snapshot.

* `instance_of?(String)` retains the accepted URI handling of subclasses and their state; the parent's BasicObject boundary is not introduced by this commit.
* `encoding.ascii_compatible?` retains URI's handling of incompatible input encodings rather than sending them through the fast path.
* `/%(?!\h\h)/` is the existing strict invalid-percent validator CGI lacks.
* Binary decoding followed by `force_encoding(encoding)` is not another guard: it preserves bytes and the late, once-only requested-encoding conversion.

The extraction is **L0**: one implementation replaces two, with ordinary require/include/export declarations and no speculative guard. Independent reviewer measurements: Flog **10.3** for each old decoder and the shared decoder; ABC **8.54**, cyclomatic/perceived **4/4**, method lines **3**, parameters **2** including one optional, unchanged. These are static complexity observations, not performance measurements. No benchmark, allocation, instruction or time claim is made for this refactor.

## Fresh independent executions on this exact head

Scratch root `S` was `/home/user/workspace/repo/.amp/in/orb-backup/rk3-0046982320`; `base/` is the exact parent and `confirm-e3d53cfd/` the exact detached head. Reused source harnesses are independent of the builder's generator. Complete raw output, scripts, locks and both reviewers' focused receipts are in `receipts.tar.xz`, with archive checksum in `SHA256SUMS`. The target worktrees remain clean.

### Full suite: actual oldest supported Ruby and 4.0

Ran in the candidate worktree, preserving PATH while selecting the appropriate Ruby:

```sh
CI=spec RUBYOPT='' bundle _2.4.22_ exec rake       # Ruby 2.7.3
CI=spec RUBYOPT=-rcgi/util bundle _2.4.22_ exec rake
CI=spec RUBYOPT='' bundle exec rake                # Ruby 4.0.9
CI=spec RUBYOPT=-rcgi/util bundle exec rake
```

Ruby 4 used `BUNDLE_LOCKFILE=$S/Gemfile-4.0.9.lock`; Ruby 2.7 used its copied ignored lockfile and Bundler 2.4.22. Ruby 2.7.3 is the official ruby/ruby-builder toolcache binary at `/opt/hostedtoolcache/Ruby/2.7.3/x64`; 4.0.9 is the installed mise binary. Rack declares `>= 2.7.3`.

| Ruby | Clean and cgi/util, each | Decisive result |
| --- | --- | --- |
| 2.7.3p183 | 1,315 runs / 5,725 assertions | 0 failures, 0 errors, 2 skips; All test files passed |
| 4.0.9 | 1,317 runs / 6,421 assertions | 0 failures, 0 errors, 2 skips; All test files passed |

All four commands exited 0 on their first attempts for this head, including the additional separate-file require tests. This does not relabel the previous head's retained gzip-mtime failure as passing. The aggregate rows above do not sum separate-file runs. The old base full-suite receipts remain in the original review; this pass freshly reran the candidate's four configurations and both sides of every differential below.

### Adversarial unescape and escape differential

Ran each Ruby with and without `-rcgi/util`, using `ruby -I "$tree/lib" "$S/probe.rb"`, then `python3 "$S/compare.py" BASE.jsonl HEAD.jsonl`.

| Ruby / mode | Compared calls | Disclosed message-encoding-only differences | Unexpected |
| --- | ---: | ---: | ---: |
| 2.7.3 clean | 90,742 | 12,094 | 0 |
| 2.7.3 cgi/util | 90,742 | 12,094 | 0 |
| 4.0.9 clean | 91,388 | 12,206 | 0 |
| 4.0.9 cgi/util | 91,388 | 12,206 | 0 |
| Total | 364,260 | 48,600 | 0 |

The harness covers every available non-dummy encoding plus four explicit dummy encodings; malformed %, invalid bytes, non-ASCII/ASCII-incompatible inputs, target encodings, frozen inputs, seeded adversarial mixes, String subclasses with state, singleton overrides, non-Strings including BasicObject, public/private and missing conversions, once-only and mutating encoding coercion. It checks four decoding routes, both escaping routes, and representative query/cookie calls. Outputs record result class/bytes/encoding/validity/frozen/ivars, input state, conversion traces and exception class/message bytes/message encoding. Process addresses and Ruby's error-highlight decoration are normalized, not successful results.

The classifier allows only Utils/includer `ArgumentError` messages beginning `invalid %-encoding`, with all other fields identical and message encoding ASCII-8BIT → UTF-8. This is not literal equality to base. The source move from binary utils.rb into a UTF-8 helper explains the correction, and direct probes show URI and QueryParser already produce UTF-8. Escape outputs and ordinary validation remain unchanged. Reflection changes include owner, own-method lists and QueryParser's parameter name `string` → `s`.

`contracts.rb` freshly passes all 12 checks on **both trees, both Rubies, both preload modes**: public singleton/private instance visibility, arity, subclass and prepend overrides with super through parsing, Utils includer override with super, frozen receiver/input, fiber-suspended late single conversion, later module functions, singleton prepend and module-function snapshot after instance redefinition. These do not claim arbitrary include precedence is unchanged; that separate counterexample is recorded above.

### Loading, lazy state and concurrency

`python3 run_loading_e3d53cfd.py` passes **13 base/head require scenarios per Ruby/preload configuration**. It compares ordered loaded features, Rack constants/autoloads, consumer loading before use, visibility and asymmetric decode/parse outputs. Equality removes **only** the new `rack/unescape.rb` feature and `Rack::Unescape` constant. No old feature-order or lazy-consumer difference remains. The scenarios include root/component standalone entry points, both QueryParser/Utils require orders, and Request/MockRequest entry points.

Three additional orders per configuration (`rack/unescape` alone, before root Rack, and after root Rack) leave both consumers unloaded until used. The provider therefore introduces no eager reverse dependency. The independent correctness reviewer additionally held the helper definition while QueryParser and Utils entered loading: direct-require and root-autoload variants completed on both Rubies. Its raw concurrency receipt is kept; it is secondary reviewer execution, not another primary matrix run.

### Documentation and style

`documentation_dump.rb` freshly parses **all `lib/**/*.rb`** in base, `3ca13466`, and this head in separate processes. `python3 compare_docs_e3d53cfd.py` checks the exported records and preserves raw diffs:

* **YARD 0.9.46 / Ruby 4.0.9:** both Utils method forms retain base's parameters, original prose and visibility. Every exported Utils method/attribute record is identical to `3ca13466`. Whole-library differences from base are the private method relocation, new provider module/method, and the public method's inferred exception tag described above. No unrelated record differs.
* **RDoc 8.1.0 / Ruby 4.0.9 and RDoc 7.2.0 / Ruby 2.7.3:** every exported method/attribute record is identical to `3ca13466`. Against base, only Utils' explicit meta-method record differs; displayed signature/prose and public visibility agree. Surrounding whitespace and GhostMethod metadata are retained in the raw data, not called byte-identical.
* All following multipart accessors, writers and aliases are byte-identical to base in the exported fields: six YARD records, or four RDoc records grouping read/write attributes. The separator causes no attribute regression.
* Rack's actual command `CI=spec bundle exec rdoc --op OUTPUT --main README.md --template-stylesheets contrib/rdoc.css` freshly exits 0 on both Rubies and generates exactly **one** `id="method-i-unescape"` anchor each. This is local generation, not a hosted-doc rebuild.
* YARD reports the same existing unknown `@returns` warning in request.rb for every tree.

`git diff --check HEAD^ HEAD` passes. A fresh full RuboCop 1.93.0 run with Rack's config on both base files and all three head files exits **1** on both sides: exactly the same five offense identities/messages/source lines, none in the new helper. This is **not** a clean-lint claim. The reviewer's deliberately zero-threshold Metrics probe exposes the unchanged values above; its exit 1 is not passing lint either.

### Exactness checklist and limits

1. Singleton dispatch, private/missing conversions, prepends, subclass overrides and super were exercised; extension-precedence differences are disclosed, not normalized away.
2. String subclasses, ivars and non-String Array/Hash inputs were compared. Collection-subclass iteration overrides are not implicated because this extraction changes no iteration or collection conversion.
3. Public/private to_s/to_str and conversion traces were compared; requested encoding is converted once and late. No to_a/to_ary/to_hash operation is added or removed.
4. No decoder operation is added/skipped apart from dispatch ownership and literal source encoding; their effects were checked separately.
5. Result class/state and input state were compared. No new accumulator or adoption of a user-owned collection exists.
6. Input mutation during conversion and fiber suspension were exercised.
7. Frozen inputs/receivers and exception class, bytes and encoding were exercised, with the disclosed message correction kept visible.
8. Standalone requires, load order and lazy state were tested on both endpoints and preload modes. No configuration-read timing changed.

The original builder's seven-Ruby suite and 204,073-call replay claims were audited and endpoint-replayed during the first review, whose raw receipts remain committed at `../0046982320/`. Those claims describe the earlier nested extraction, not this exact new file layout. This pass does not transfer their loading or whole-matrix certification to the new head: it supplies the fresh endpoint checks above. Intermediate-MRI full suites, JRuby, TruffleRuby, macOS, Ruby master, other YARD versions, hosted fork CI and performance were not independently rerun for this head.

One documentation-command wrapper initially constructed S relative to the candidate working directory, so shell redirection failed before executing RDoc. It was corrected to the absolute scratch root; both real generators then passed. One inspection used `.yml` instead of the repository's `.yaml` workflow suffix; reading the actual workflow confirmed the documented command. No test failure was filtered or suppressed.

## Commit message: sentence audit

The exact message and candidate patch are in the receipts. It contains no Lowrail, queue, reviewer or other internal text and makes no performance claim.

| Sentence | Verdict |
| --- | --- |
| Title: “Share unescape between Utils and QueryParser” | **Keep:** accurate and plainly scoped. |
| “Rack::Utils.unescape and QueryParser#unescape duplicated the decoding logic.” | **Keep:** confirmed in parent. It does not claim literal source identity. |
| “Move it into a Rack::Unescape module in its own file, which query_parser.rb and utils.rb require and both include, together with the uri and cgi/escape requires it needs.” | **Keep:** the helper owns those dependencies and both consumers directly require/include it. Utils also retains direct dependencies it still uses. |
| “Utils makes it a module function as before, so Rack::Utils.unescape still works, including Utils still gives a private unescape, and QueryParser subclasses can still override it.” | **Factually keep; optional readability nit** above. Visibility/export/ordinary subclass super were executed. This is not a claim that every private include collision is identical. |
| “Its documentation stays in Utils as RDoc and YARD method entries.” | **Keep:** freshly confirmed by both tools, including correct parameters/prose and following attributes. This does not promise identical inferred YARD tags. |
| “utils.rb is a binary source file, so the ArgumentError that Utils.unescape raised for an invalid %-encoding of an ASCII-only string had a binary message.” | **Keep:** source and actual endpoint message encodings confirm the scoped claim. |
| “It now has the encoding of URI's message, as QueryParser#unescape's already did.” | **Keep:** direct probes confirm class/bytes/encoding. |

## Reply draft: approve unchanged

> Moved `unescape` into a `Rack::Unescape` module in its own file, which `QueryParser` and `Utils` include; `Utils` exports it with `module_function :unescape` (e3d53cf). For ASCII-only strings with invalid %-encoding, this also restores URI's error-message encoding; the local raise in `utils.rb` had made it binary.

1. **Approve sentence one.** Exact module name, file placement, both includes, named export and short head are verified. The short SHA is upstream-relevant. No internal detail appears.
2. **Approve sentence two.** The ASCII-only qualifier, source-encoding cause, URI comparison and restoration are supported. “Again” is warranted because pre-optimization Utils delegated to URI. No additional wording fix is needed.

This review does not edit the existing GitHub reply or authorize this reviewer to post. The coordinator owns any later exact-head publication and CI gates.

## Delivery

Only this Lowrail report and archived receipts are delivered, using the task's permission for `script/commit`, signed pull-rebase and a Lowrail main push. No Rack/fork/PR branch was pushed, no GitHub comment was posted or edited, and the queue item was not changed by this thread. Raw receipts and harnesses are retained before reporting completion; no upstream fix was applied.
