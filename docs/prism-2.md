# Prism 2 adoption — 2026-10-21

**Adopted for Ruby development/build/discovery tooling and the Rust CLI.
Not forced into app bundles. Parsing uses the target Ruby grammar, never a
silent latest/nearest fallback. No new lowering, admission, witness or
type-recovery policy.** [Prism 2 release](https://github.com/ruby/prism/releases/tag/v2.0.0).

Baseline: clean `main` after `git pull --rebase`,
[`060f85e`](https://github.com/thomasklemm/lowrail/commit/060f85e21e35f192ac6312f6bb2499b130b32dac).
Ruby implementation:
[`6f13674`](https://github.com/thomasklemm/lowrail/commit/6f13674862cd7e786daea46dd7c895b94311a014).
Rust repin/mechanics:
[`ffb43fd`](https://github.com/thomasklemm/lowrail/commit/ffb43fd1d58a7e0167a70326c8e0334d73f7f841);
target grammar:
[`8a87712`](https://github.com/thomasklemm/lowrail/commit/8a87712f99b282debac55cbd87d667ff14af8047).
The [machine evidence](prism-2-evidence.json) contains full digests, every
timing/RSS sample, exact manifest differences and read-only find counts.
The accompanying thread evidence archive retains raw before/after census,
delivered files/manifests, probe source/results and gate logs.

## Taken and deferred

- Pin Ruby Prism **2.0.0 as a development dependency only**. A locked app may
  retain 1.9; the gem's no-op/missing-build contract does not acquire a new
  mandatory parser dependency. This is not a forced upgrade of application
  bundles, Ruby's built-in compiler or their certified pins.
- All 29 Ruby parse/lex call sites in `gem/`, `script/helper-census` and
  `bench/` explicitly request `version: "current"`. Prism 2 defaults to
  `"nearest"`, which silently clamps an unknown future runtime. Exact syntax
  or an explicit refusal is preferable. No new parse wrapper is necessary.
- Keep token-body certificates exact within each parser version. `Token#first`
  is Prism 2's documented compatibility alias, so extracting tokens this way
  also handles 1.9's `[token, state]` pairs. Ignore `NEWLINE_TERMINATOR` with
  the already-ignored whitespace/comment/separator tokens. Do **not** flatten
  the new semantic grouping/hash/argument token distinctions.
- `attach_comments` could help a later comment-type recovery proposal, but
  is not adopted here. No current Ruby caller uses `attach_comments!` or
  comment relocation/attachment APIs. The shipped RBS/RBI describes Prism's
  APIs, not application type evidence; it is not imported into MCP exports.
- `Prism.find` is probed separately below, not adopted. It does not authorize
  runtime provenance inference or replace the actual-ISeq block association.

### Breaking-change inventory

| Change | Lowrail dependency / disposition |
|---|---|
| Ruby default latest → nearest; 4.1 `&nil`, trailing signatures, void checks | Explicit current on every Ruby call; regression compares 4.1-only `&nil` against the actual RubyVM compiler on both VMs. |
| Unsupported current runtime | Public census regression injects future syntax `99.0` at the current-version lookup boundary, retaining the real parser's rejection; nonzero exit and an explicit error, not silently accepted rows. It does not modify Ruby's binary/version or pretend to run a future VM. |
| `MissingNode` → `ErrorRecoveryNode` | No named dependency in Lowrail. Syntax-error census regression remains; Rust invalid-tree behavior is not expanded. |
| Renamed location fields (`InNode`, loop/match/conditional nodes), nil optional locations | No use of renamed fields. Existing optional call-operator locations are checked; no traversal changes. |
| `Prism.lex` returns Tokens, splits parentheses/braces/backticks/newlines/word separators | Three token comparators need token extraction/newline changes above; the remaining `.first.type` consumer already works. Stock-body and mutation regressions retain exact refusal. |
| Removed `ParseResult#attach_comments!`, comment/location relocation fields, changed result constructors and `Source.for` arguments | No current dependency. No compatibility shim. |
| Removed `Prism::Pack` | No current dependency. |
| Rust slice locations, arena allocation, byte diagnostic messages, block parameter union | Mechanical adaptations below; all Rust parses share an explicitly versioned parser. |

## Artifact comparison

Both arms use Ruby **4.0.7**, Rails **8.1.4**, the same prepared blog path,
freshly built artifacts and a fixed denylist isolating the four sealed units
(link, form, token, collection). The other eight apps use `script/corpus`
source-only pins. No old certificate was accepted to obtain these results.

**Comparison-harness constraint:** an external production-only Gemfile keeps
the original gem versions, selects the same **Minitest 5.27.0 in both arms**,
excludes development-only RuboCop and changes only Prism 1.9.0 ↔ 2.0.0.
Minitest 6's `prism ~> 1.5` constraint otherwise prevents this comparison.
This overlay is not copied into the app, used to relax certificates, or
claimed as unchanged-bundle support. Original blog lock remains
`a0b681d52555b3493ff62ef3f9b6ef386ed09ca314f89d807d2f3a7129fec8a2`.

- **Nine-app census:** 1,693 files; 742 sites = 537 `link_to`, 57 `button_to`,
  141 `form_with`, 7 `form_for`. Complete `apps` payload is byte-identical
  when compact-JSON serialized, SHA256
  `ba8f7595b8f7e7253511a9876682352dacadaabcfaa7e77bf3758014b1d1fd7b`.
  Full reports differ **only** in reported Prism version and analyzer SHA.
  Published `docs/helper-census.json` was not regenerated.
- **Delivered ISeqs:** byte-identical, SHA256
  `bea055e8ea8afac34d1238fee4bfcac12c93db0877d639becd28eda70ac52dd0`
  and `d95122f02b64e784fad19dafc584994af03c337fad436ee8ead437003c997e3c`.
  Both lowered source files and their original bodies are byte-identical;
  individual hashes are in the machine evidence. Ledger, facts, typed facts
  and all 1,959 captured generated sources also match.
- **Manifest:** baseline SHA256
  `58a5e2ec1fb502fc475e5745faff804ec5966355f8efe8a6247efb6597f62c9a`;
  upgraded `17f2d7b81b7b586b7b3075d359a4342d6e2b93167c66c3ee191f15fa92f6bd86`.
  All three repeats per arm have the same manifest. Exactly two intentional
  differences: `sealed_build.rb` and `form_scaffold_build.rb` source hashes
  after their parse-option edits. `units.json` repeats the same two changes.
  App/framework sources, ISeq digests and body certificates do not change.
  Rebuild normally: do not whitelist stale build-source pins.

The denylist avoids unrelated process-to-process AR-fact array ordering in
an initial broader build. This proof covers the four named sealed units,
not byte stability of every optional pass. No manifest normalization or
diagnostic suppression was used.

### Wall clock and memory (not a speed claim)

Linux x86-64 orb, interpreter primary, sequential warm-cache processes;
`/usr/bin/time -f '%e %M'`. RSS is its reported maximum for the command's
process tree, not a sum or parser-only allocation measure. Census includes
template compilation; full build includes boot, facts and compilation.
Small samples, no accepted performance cohort, no Callgrind or retry-until-green.

| Workload | Samples/arm | Before median seconds / RSS KiB | After median seconds / RSS KiB |
|---|---:|---:|---:|
| Nine-app Ruby census, 1,693 files | 5 | 0.79 / 39,112 | 0.79 / 39,120 |
| Blog sealed build, four units/two files | 3 | 6.14 / 168,124 | 6.24 / 168,504 |
| Rust `lowrail parse`, 1,162 Ruby files (unchanged 1.9 control) | 5 | 0.05 / 5,252 | 0.05 / 5,268 |

The control row deliberately uses **unchanged Prism 1.9 on both sides**.
The separate Rust migration measurements appear below. Neither is a speed claim.

## Correctness axes and fixture provenance

- `mise exec ruby@4.0.7 -- cargo test --locked` and
  `mise exec ruby@4.1.0-preview1 -- cargo test --locked`: each **39 unit +
  2 types/MCP + 8 integration tests pass** (one includes the real blog).
- Affected gem suite covers helper census, sealed link (including the existing
  UTF-8/byte-offset regression), AR plans, Inertia config/props, digest memo,
  endpoint, compiler and seal. Final 4.0.7: **37 tests / 2,869 assertions**, no
  skips; preview: **37 / 2,737**, one named 4.0-only sealed-link fixture skip.
- New grammar/refusal regressions: **4 tests / 33 assertions** on 4.0.7,
  **4 / 34** on preview. Bench AR diagnostic tests: **2 / 16** on each.
- Retained published fixture: form suite with `LOWRAIL_STRICT_GATES=1`
  **2 tests / 114 assertions** in the first capture, **2 / 123** after
  integrating the owner's published continuation regression; no failures,
  errors or skips on 4.0.7. Preview
  retains the two existing named 4.0-only form skips, not form-pilot support.
- Ruby descriptions: `ruby 4.0.7 (2026-09-15 revision 229531a6cf)` and
  `ruby 4.1.0preview1 (2026-10-11 master 2d08b5f42f)`, both PRISM/x86-64.
  Preview is the exact [pinned target](ruby-4.1.md), not an inferred version.

**The supplied regenerated fixture is not the published production fixture.**
The passive production test refuses at `seed-0-off1`, Lowrail off,
`fixtures/corpus/blog_production.rb:183`: `app source pin mismatch`.
The identical test on clean baseline `060f85e` with that same supplied app
refuses identically. This is fixture provenance, not a Prism regression.
The source and lock policy was not relaxed.

The sealed owner supplied the matching retained source archive. Selecting it
with `LOWRAIL_TEST_CORPUS_ROOT` passes both form tests without a dependency
overlay or old DB/seed. The test prepares its own BlogShowGetOnly rows.
The final rerun installs its originally locked Minitest 6.0.6 in an isolated
gem directory; no app Gemfile/lock or certificate changes. A missing-gem
attempt and a mixed-Minitest zero-test attempt are retained, not counted as
successful gates. Only the subsequent complete **2/123** run counts.
Archive SHA256s:

```text
blog-census.tar                    5469bef570e25be29f8bf6b80e856faf2fc6f8dd9e258327c6b60a5ba3dd3454
real-blog-r4.tgz                   96f89628b82e1a8e8e4c019618f405de64172a505f5685d23c6698bc6d83334e
retained-blog-source-86ebd4a8.tar.gz 56d74970a6531ff667e62a8a32c396c8cddb6e78991f5b2a7825c1dfcd7a180c
```

Retained published app source pin:
`86ebd4a8c0b4acd8ecb302f81ee61e593bc2288ea8a44cb532c00c43a2c5f1cf`;
lock: `570c9c31129469dc2679780a9f7f7d26aca93e57e4e119250735322741ac8596`.

## Read-only `Prism.find` probe (after the implementation commit)

- **17/17** source-backed blog controller/framework helper definitions agree
  with existing name/start-line selection on node type and full byte span.
  Bound `Method` and `UnboundMethod` give identical answers on 4.0.7.
- **263 ERB files / 657 helper sites**: a disposable generated method is
  compiled at the real template path, without executing its body. Find
  returns **nil for every generated method** on both VMs.
- **438 block sites**: isolated Proc literals compiled from those generated
  blocks also return **nil on both VMs**; every probed line has one current
  helper-call candidate. These are generated-source boundary probes, **not
  actual live template blocks or compilation-identity evidence**.
- Remaining **85 Ruby/Slim sites**, same-line ambiguous Ruby blocks and
  `Backtrace::Location` are not covered. Full preview blog boot for this probe
  is blocked by uninstalled original-bundle dependencies; only its census
  generated-source probe ran. The preview's own-code tests are independent.

Prism finds nodes by ISeq node ID against a newly parsed file on CRuby;
reparsing `.erb` as Ruby does not reconstruct the evaluated generated string
([implementation](https://github.com/ruby/prism/blob/v2.0.0/lib/prism/node_find.rb)).
These results support at most a separate source-backed lookup proposal, not
replacing a provenance witness. Sent to discovery and types owners; discovery
explicitly declined adoption in its current specimen slice.

## Rust migration and explicit grammar boundary

`ruby-prism` **2.0.0 is published** on crates.io. The initial trial against
Lowrail's old Rubydex pin has this resolver failure (full output retained):

```text
error: failed to select a version for `ruby-prism-sys`.
    ... required by package `ruby-prism v1.9.0`
    ... which satisfies dependency `ruby-prism = "^1.9.0"` of package `rubydex v0.4.1 (https://github.com/Shopify/rubydex?rev=d8ff47595223571588ae40cb748f43cef6a9dfaf#d8ff4759)`
versions that meet the requirements `^1.9.0` are: 1.9.0
package `ruby-prism-sys` links to the native library `prism`, but it conflicts with a previous package which links to `prism` as well:
package `ruby-prism-sys v2.0.0`
note: only one package in the dependency graph may specify the same links value to ensure that only one copy of a native library is linked in the final binary
```

The separately authorized exact-main trial **does resolve**: Rubydex
[`c69a742c9097a2a5c13f97726abda55b0507121b`](https://github.com/Shopify/rubydex/commit/c69a742c9097a2a5c13f97726abda55b0507121b),
v0.4.2, with one `ruby-prism` / `ruby-prism-sys` **2.0.0** pair. Its
`^2.0.0-rc.2` range already accepts stable; open
[#1078](https://github.com/Shopify/rubydex/pull/1078) is **not a prerequisite**.
Merged [#1077](https://github.com/Shopify/rubydex/pull/1077) owns that upstream
migration. No duplicate issue/PR. Lowrail currently makes no Rubydex API calls.

The initial `cargo check --locked` produced **36 mechanical errors**: removed
`Location::start_offset/end_offset` (now `u32` `start/end` slices), byte-message
display (two consumers), and `ParametersNode::block` returning `Node` rather
than a typed block parameter. These are fixed in a separate mechanical
commit: `start/end` are byte offsets cast to `usize` at indexing boundaries;
the two diagnostic displays use UTF-8 lossy conversion, preserving the old
string display; block parameters are downcast from the new node union and
unsupported forms still refuse. Arena allocation needs no Lowrail adapter.

**Pre-existing boundary:** all 13 Rust parse sites, including a test assertion,
used `parse()` without runtime version input. Both **1.9 and 2.0 already select
latest**, not the running Ruby. At both tags, Rust passes null options and
parser init chooses `PM_OPTIONS_VERSION_LATEST`, aliased to CRuby 4.1:
[1.9 entry](https://github.com/ruby/prism/blob/v1.9.0/rust/ruby-prism/src/lib.rs#L693-L698),
[1.9 default](https://github.com/ruby/prism/blob/v1.9.0/src/prism.c#L22103-L22107),
[2.0 entry](https://github.com/ruby/prism/blob/v2.0.0/rust/ruby-prism/src/lib.rs#L351-L366),
[2.0 default](https://github.com/ruby/prism/blob/v2.0.0/src/prism.c#L23410-L23414).
The grammar commit closes that boundary with **one shared `Parser`**, owning
`ParseOptions` so returned ASTs cannot outlive their options. Every production
Rust parse calls `parse_with_options`; none calls plain `parse` or `Latest`.

- Recorded `ruby_description` in boot facts selects parsing for build, facts,
  types and MCP. Observation comparison uses the runtime recorded by each
  capture. A build also checks the live compiler/oracle grammar against facts
  before lowering; exact patch-level identity remains a manifest check.
- `4.0.x` maps to `Version::CRuby3_5` (Prism's name for C
  `PM_OPTIONS_VERSION_CRUBY_4_0`); `4.1.x` maps to `CRuby4_1`. Normal releases,
  `previewN`, `rcN`, `dev` and patchlevel suffixes are recognized. Missing,
  malformed, 3.5 and unknown versions refuse explicitly.
- Standalone parsing requires `lowrail parse --ruby-version VERSION FILE...`.
  There is no host subprocess, `.ruby-version`/lock inference or unstated
  default. `types`, facts and MCP require the recorded runtime; callers with
  old incomplete facts must refresh them rather than guess a grammar.
- Source and generated caches borrow a validated parser. Type inference,
  Sorbet recursion and MCP spans share it; path-only RBS export does not
  construct a parser. No recovered tree gains lowering/admission authority.
- Public regression uses `def value(&nil); 7; end`, rejected under 4.0 and
  accepted under 4.1, and checks parse/types plus unknown-version MCP errors.
  Replacing the shared entry with plain `parse()` makes it fail as expected.
- Thermos correctness/security and maintainability ran independently before
  publication and again after simplifying parser ownership/error propagation:
  no medium/high correctness/security finding or maintainability blocker.
  Existing advisory origin/generated indexing of recovery trees is not new
  and is not lowering admission.

### Separate Rust paired capture

Rust control is the published Ruby migration with Rust Prism 1.9; upgraded
arm has Rust Prism 2 plus explicit 4.0 grammar. Same Ruby 4.0.7, app path,
facts, denylist and external Minitest 5.27 overlay as each other. Complete
build trees (including manifest, units, facts, typed facts and generated
sources) match, not just delivered files. Census payload and source/ISeq
hashes above remain identical. Full hashes and wall/RSS samples are in the
machine evidence.

| Workload | Samples/arm | Before median seconds / RSS KiB | Final median seconds / RSS KiB |
|---|---:|---:|---:|
| Blog sealed build, Rust 1.9 → 2.0 + explicit 4.0 grammar | 3 | 6.00 / 168,056 | 6.17 / 168,232 |
| Nine-app census, Ruby 2 unchanged control | 5 | 0.79 / 39,120 | 0.77 / 39,168 |
| Rust parse, 1,162 Ruby files, latest → explicit 4.0 | 5 | 0.05 / 5,260 | 0.04 / 5,784 |

These are sequential wall/RSS diagnostics, not instruction counts or accepted
speed cohorts. Earlier pre-simplification Rust samples are retained too.
Rust paired manifest SHA256 is
`22f5831c942b5d4b84263404b25797d01619a80bdcefff0a9704cbb31fca9151`.
Facts summary, types and MCP response hashes respectively:
`53e485af4ed2ea29b36a308febe4beed35aca5247d3d2e7d0c5a20efd9b5ee98`,
`601e1a8caf4dbc2e905c72831ec9a3d522432fba870128c6eb2afc70e6daf3eb`,
`0f83271a4ae1c6edee0bc2d9ddfac6e86b7d280faaf348d139d7585002023a56`.

The original Ruby comparison predates the independently published
[`ea44cf3`](https://github.com/thomasklemm/lowrail/commit/ea44cf3)
token/collection continuation fix. That integration changes three
`render_units.rb` source-pin occurrences plus the collection observer's ISeq
and source line (209 → 211); therefore its later manifest digest differs
from `17f2d7…`. The Rust paired arms both include that fix and have the same
manifest. These are named intervening changes, not effects of Prism. Delivered
blog ISeqs and sources remain identical across both pairs.

Valid corpus parse stdout/stderr and the malformed UTF-8 source diagnostic
fixture are byte-identical. A mechanical-only/latest-grammar trial briefly
omitted one redundant comma diagnostic; the explicit 4.0 grammar restores
the baseline diagnostic, so no diagnostic difference is accepted silently.

### Upstream naming hint

Opened exactly one informational issue after checking conventions, searching
duplicates and oracle-reviewing the text:
[ruby/prism#4297](https://github.com/ruby/prism/issues/4297).
`Version::CRuby3_5` is documented “3.5.x / 4.0.x” and passes `"3.5"`, while C
uses `PM_OPTIONS_VERSION_CRUBY_4_0` and accepts `"4.0"`. Suggested a consistent
`CRuby4_0` name while retaining deprecated compatibility; **no behavior bug
claimed and no PR opened**. The naming persisted from the reverse-sync
rename through v2.0.0/master. See [decision register](DECISIONS.md#prism-2-adoption-and-target-grammar-2026-10-21).
