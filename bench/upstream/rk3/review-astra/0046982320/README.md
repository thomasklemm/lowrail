# RK3 adversarial Astra review and confirmations

**Current verdict: approve `e3d53cfdb2f9689646dc754ea20885bf29169e6a`.** The standalone `Rack::Unescape` extraction
passes the renewed adversarial load-order, input, lookup, Ractor and documentation checks below. No must-fix or nit.
The explicitly recorded error-message, lookup and namespace boundaries are not a claim of total Ruby equivalence.

**Previous verdict: approve `3ca13466d56965731d4419cd465ad6e33dce9ace`.** The YARD documentation finding was fixed;
the later move to a standalone module responds to Thomas's placement preference, not an additional docs defect.

**Earlier verdict on fc894812: changes, for missing YARD API documentation.** The redundant comment was fixed and
RDoc 8.1.0 documentation was restored, but YARD still produced an undocumented, parameterless stub.

**Original verdict on 0046982320: changes, for public documentation and one unnecessary comment.** The additional
method-table differences below are recorded explicitly; none establishes a normal request/security failure.

Original reviewed head: `0046982320094e11d80d2ec19bf0ab69f05ba41b`, whose sole parent is
`e26338b40a0c5bc83cb4eba645e5954fc264b699`. This pass covers only that third commit, not a new performance review of
the earlier CGI changes. Self-performed in thread `T-01a21cee-55cd-73c2-8f95-9e7cd65e2243`; no delegation.

## Standalone-module review on e3d53cfd

Reviewed exact head `e3d53cfdb2f9689646dc754ea20885bf29169e6a`, fork branch `unescape-cgi-8`, with the single parent
`e26338b40a0c5bc83cb4eba645e5954fc264b699`. The first two commits are therefore unchanged. Compared with 3ca13466,
the private module moves to `lib/rack/unescape.rb`, is renamed `Rack::Unescape`, owns the URI/CGI requirements, and
is explicitly required/included by both consumers. No `rack.rb` autoload is added. No Rack files were edited here.

**No new ordinary-call or request regression demonstrated.** Fresh 204,073-record clean replays on 2.7.3, 3.0.7,
3.1.7, 3.2.9, 3.3.9, 3.4.6 and 4.0.9 reproduce the same 9,764 ASCII-only error-message encoding differences and one
parameter-name difference per pin against e26338b40a. Two Object-address lines are fixture noise. On 3.1.7 there are
now six different error_highlight excerpts versus base, not the original head's twelve: the moved decoder's
indentation now matches Utils' original indentation, while the QueryParser parameter spelling still changes.
Versus 0046982320 there are twelve indentation-only excerpt changes. No other replay output differs.

Fresh independent probes on all seven pins cover the original encoding sweep, overrides, prepends, aliases,
custom default parsers, frozen inputs/receivers, conversions, fibers and method visibility. Against 0046982320 their
only differences are the owner's name and one added loaded file. All original lookup findings below still apply,
with owner `Rack::Unescape`: replacing a local definition with `super` now reaches an ancestor; `remove_method`
fails on inherited methods; the constructed subclass-plus-Utils include collision still selects the parent
override. These do not justify a wrapper, guard, or opaque self-alias without an actual affected caller.

`load-surface.rb` runs fresh forked processes without URI preloaded. On **both 2.7.3 and 4.0.9**, every one of the
120 permutations of `rack`, `rack/query_parser`, `rack/utils`, `rack/request` and `rack/mock_request` matches base
step-by-step: the entire ordered loaded-feature list, consumer defined/autoload states and final decoding/escaping/
query results match after removing only the new `rack/unescape.rb` feature. All **720** permutations including the
new entry point pass; requiring the helper never eagerly defines or autoloads either consumer. Standalone helper
loading works, keeps its method private, and subsequent `require 'rack'` installs the expected consumer autoloads.
`require 'rack'` alone still leaves `Rack::Unescape` unavailable; this is intentional for an internal dependency.

Additional executed namespace boundaries, not inferred failures:

| Repro in `load-surface.rb` | Base → e3d53cfd | Disposition / smallest remedy |
| --- | --- | --- |
| Predefine `Rack::Unescape = 17` or `Class.new`, then require Utils | Ordinary calls succeed → `TypeError: Unescape is not a module`. | A newly owned Rack constant can collide with an application's invented constant. No known caller or documented extension point; no Rack guard requested. Such an application should rename its foreign constant. |
| Predefine `Rack::Unescape = Module.new.freeze`, then require Utils | Ordinary calls succeed → `FrozenError`. | Same namespace boundary, not a failure on a frozen decoder input/receiver. No Rack shim. |
| Predefine a mutable module with `included` callback, then require Utils | Callback never runs → callback sees QueryParser then Utils; decoding still correct. | Expected inclusion semantics. No fix requested. |
| Require helper, redefine its private `unescape`, then load Utils | New entry point unavailable on base; new head returns the replacement through all three consumers. | New internal monkey-patch surface, not an old caller regression. |
| After loading Utils, redefine the helper's private method | Base has no helper to reopen; new head changes QueryParser/includer dispatch but not Utils' singleton copy. | Verified `module_function` snapshot behavior. Patch the desired consumer, or explicitly re-export, if replacing it intentionally. No runtime wrapper requested. |

The namespace failure controls were run against base on 2.7.3 and 4.0.9; all new-head special scenarios were run
on every pin. Concurrent requires pass on all pins. Both the original opt-in Rack Ractor probe and a new standalone
helper-only Ractor probe pass on 3.0.7–4.0.9. The latter decodes correctly without loading Utils or QueryParser;
Ruby 2.7.3 has no Ractor. This is not a universal Ractor-safety claim for configurable Rack globals.

Six fresh full `CI=spec bundle exec rake` runs on **this exact head**, 2.7.3/3.4.6/4.0.9 × clean/`-rcgi/util`, pass:
1,315 runs / 5,725 assertions on 2.7.3; 1,317 / 6,421 on the other two; zero failures/errors, two skips each, and
every separate test file passes. Version-specific lockfiles match the retained base suite lockfiles. The other
four pins received new input/lookup/Ractor probes, not fresh full suites in this follow-up. Broad util/pure-CGI
replays, hosted CI, non-MRI engines and benchmarks were not rerun here; earlier results stay attributed to their heads.

Full-library YARD 0.9.46 dumps retain exactly the approved Utils singleton and instance documentation/parameters/
visibility; only the internal module and method names change versus 3ca13466. RDoc 7.0.4, 7.2.0 and 8.1.0 dumps
are byte-for-byte equal as parsed JSON to that approved head. Public API docs remain restored. The new file adds
only the frozen-string directive and `:nodoc:` comment; retained Utils directives are functional documentation.
The existing exact-class/ASCII-compatible and malformed-percent guards are unchanged; no new guard is warranted.

**Name and placement:** `Rack::Unescape` in `rack/unescape.rb` is clear for a one-method internal mixin shared by
two peers. QueryParser's top-of-class include is conventional and independent of the surrounding constants.
Removing its direct URI require is sound because the explicitly required helper loads URI before its method can
run. Keeping the explicit helper require in Utils makes that dependency visible even though QueryParser already
loads it. No autoload is needed for an internal module that both consumers explicitly require. Rack's shared
helpers and standalone internal files support this shape, but `BadRequest` does have an autoload: it is not an
exact no-autoload precedent. This is a maintainer-style judgment, not a claim that ioquatix or jeremyevans approved
the new name. Thomas's requested neutral placement is satisfied without a forwarding wrapper.

**Commit and reply:** the commit's mechanism, visibility, subclass-override and documentation claims were checked
against the source and fresh probes. The latest reply below is accurate and plain; no correction or nit remains:

> Moved `unescape` into a `Rack::Unescape` module in its own file, which `QueryParser` and `Utils` include; `Utils`
> exports it with `module_function :unescape` (e3d53cf). For ASCII-only strings with invalid %-encoding, this also
> restores URI's error-message encoding; the local raise in `utils.rb` had made it binary.

`shared-e3d53cfd.txt` contains the assertion-backed comparison summary. `shared-e3d53cfd.tar.xz` retains the new
load-surface and comparison scripts, documentation script/dumps, complete independent/special/permutation outputs,
suite logs, head/message/diff, and replay deltas plus SHA-256 hashes. Reconstruct replay outputs from the original
archive's `results/rack-VERSION-clean-replay.txt` with the matching unified delta; all other fresh outputs are kept
in full. Run `ruby -I /path/to/rack/lib load-surface.rb common`, `six`, or `special` for the isolated new probes.
No fork/PR push, GitHub post, queue edit, or new thread was made by this review.

## Short confirmation on 3ca13466

Fetched `unescape-cgi-7` and confirmed exact head `3ca13466d56965731d4419cd465ad6e33dce9ace`, with the single parent
`e26338b40a0c5bc83cb4eba645e5954fc264b699`. Its only source change against fc894812 is the five tested documentation
lines in Utils. Both changed files have equal executable token streams against fc894812.

The complete-library YARD 0.9.46 registry dump now gives **both** `Rack::Utils.unescape` and `Rack::Utils#unescape`
exactly the base's parameters, description and visibility. Its only changed records concern the moved private
QueryParser method and new `:nodoc:` mixin/method. Complete-library RDoc dumps on 7.0.4 and 8.1.0 (Ruby 4.0.9), and
7.2.0 (Ruby 2.7.3), all contain the original public prose and `unescape(s, encoding = Encoding::UTF_8)` call sequence.
Their only changed record is Utils' unescape entry using call-seq instead of parsed parameters; the RDoc 7 raw
comment/call-seq strings also gain leading/trailing newlines. No unrelated public documentation changed.

Fresh independent adversarial probes on 2.7.3 and 4.0.9 are byte-identical to fc894812, including the 4.0.9 Ractor
probe. A fresh full `CI=spec bundle exec rake` on **3ca13466**, Ruby 4.0.9 clean, passes: 1,317 runs, 6,421 assertions,
zero failures/errors, two skips, and every separate test file passes. This short confirmation does not rerun the
entire version/preload matrix or the broad random replay; those results below belong to their explicitly named heads.

The updated commit message's RDoc/YARD claim is now supported. The supplied reply draft with `(3ca1346)` is accurate
and appropriately toned; no edit is requested. The documentation directives are functional API documentation,
including the tested separator, not a new unnecessary explanatory comment. The name and placement remain acceptable.

Raw whole-library dumps, the dump script, the fresh suite/probe outputs and the comparisons are retained in
`confirm-3ca13466.tar.xz`; `confirm-3ca13466.txt` lists every documentation difference. No Rack source change or
public posting was made by this confirmation.

## Follow-up on fc894812

The revised head also has the single parent `e26338b40a0c5bc83cb4eba645e5954fc264b699`. Its diff against 0046982320
changes only comments. Ripper confirms equal executable token streams in both files. The dependency comment and
the private module method's doc comment are gone; Utils now has an RDoc method/call-sequence block.

**The remaining required change is the public YARD documentation.** Parsing the revised head's complete `lib/**/*.rb`
with YARD 0.9.46 still gives `parameters == []` and `docstring == ""` for `Rack::Utils.unescape`, where the base gives
the two parameters and original description. Rack's gemspec points to RubyDoc.info; its
[About page](https://rubydoc.info/about), opened in this review, explicitly says it uses YARD. This is not a request
to support an unrelated documentation tool. RDoc 8.1.0 now produces the entry correctly. RDoc 7.0.4 still does not;
that older-generator observation is secondary, not a separate must-fix demand.

Smallest tested additive remedy on fc894812: a standalone YARD `@!method self.unescape(s, encoding = Encoding::UTF_8)`
block with the original two-line description **after** `module_function`, separated from the next `class << self`
by `##`. This restores both YARD parameters and description, leaves RDoc 8.1.0's entry intact, and changes no
executable code. Without that separator YARD still ignored the block. `yard-fix.diff`, `yard-fix.txt`, and
`rdoc-fix-check.txt` in the revised receipts show the exact tested experiment. The builder may prefer a less
duplicated documentation form; no runtime wrapper or added dispatch guard is needed.

All original runtime findings below apply unchanged. Fresh independent probes on all seven Rubies produce
byte-identical output to 0046982320, including the Ractor probes. Fourteen fresh builder replays (clean/util on all
seven pins) have only the two nondeterministic Object-address differences versus 0046982320, with 204,073 records
each. Four full `CI=spec bundle exec rake` suites on **fc894812**, 2.7.3 and 4.0.9, clean and with `cgi/util`, pass
with the same counts and two skips, including all separate test files. The seven-pin full-suite matrix and
pure-CGI runs below were on 0046982320; they were not all repeated on this comment-only follow-up.

The revised reply supplied by the coordinator is accurate and appropriately toned. No wording correction is
needed. If the remaining documentation fix changes the commit, replace `(fc89481)` with that actual reviewed head.
The module's name and placement remain reasonable; no naming nit or additional runtime fix is requested.

`revised-receipts.tar.xz` holds the new probes, suite logs and documentation evidence. Its replay outputs are stored
as lossless unified diffs against `results/rack-VERSION-MODE-replay.txt` in the original `receipts.tar.xz`, with both
file hashes in `replay-hashes.json`; the full new files also remain in the orb backup. This avoids storing the same
large corpus a second time. `revised-comparison.txt` gives the fourteen comparisons.

## Original required changes on 0046982320

1. **Preserve the public `Rack::Utils.unescape` documentation and signature.** On YARD 0.9.46, parsing all `lib/**/*.rb`
   gives the original description and `[["s", nil], ["encoding", "Encoding::UTF_8"]]` on base. On head it creates
   an empty-description, empty-parameter stub. RDoc 7.0.4 likewise loses Utils' `unescape` entry entirely. The
   `unescape_path` documentation still refers readers to it. Moving the doc comment into a private method in a
   `:nodoc:` module does not preserve the public docs. This matters especially because rack.gemspec advertises
   rubydoc.info as its documentation URI.

   Smallest remedy: retain an explicit generated-method API declaration and the description under Utils, rather
   than adding a runtime delegation wrapper. A standalone YARD `@!method self.unescape(s, encoding = Encoding::UTF_8)`
   declaration after `module_function`, plus an RDoc ghost-method declaration, restores the documentation without
   changing Ruby execution. The scratch experiment in `doc-fix-experiment.diff` proves both parsers can recover it;
   it is not a polished proposed patch (RDoc also displays the YARD annotation). Merely putting the old comment
   immediately above `module_function :unescape` did **not** work. The builder should choose the smallest acceptable
   documentation form, then rerun the parser checks.

2. **Delete `# Also included in Rack::Utils, which requires this file.`** This new line restates the include and
   require topology, already visible in Utils; it does not protect a non-obvious condition in the method. The
   dependency explanation belongs in the commit message, where it already is. Under DECISIONS' explicit added-comment
   gate this is a required deletion, not an invented runtime defect. Keep `# :nodoc:` and the actual public API docs.

## Demonstrated differences and their disposition

Run `ruby -I /path/to/rack/lib boundaries.rb MODE` once for each tree. `adversarial.rb` runs isolated processes for
the broader method-lookup and loading probes. The receipts contain full outputs on all seven Ruby pins.

| Repro / observation | Base → head | Smallest fix / disposition |
| --- | --- | --- |
| `boundaries.rb error`: rescue `Rack::Utils.unescape("%")`, inspect `message.encoding` | ASCII-8BIT → UTF-8; exception class and bytes stay `ArgumentError`, `invalid %-encoding (%)`. Also applies through Utils includers/extend. QueryParser and URI already use UTF-8. Non-ASCII message content retains the input's encoding. | Accept the explicitly disclosed restoration of URI's behavior; no runtime fix requested. |
| `boundaries.rb reflection` | Both private instance methods' owner becomes `Rack::QueryParser::Unescape`; Utils' own-private-method list loses `unescape`; QueryParser's required parameter name becomes `s` instead of `string`. Utils' public Method object retains its parameters and arity. | Expected extraction metadata; do not add wrappers or rename parameters just to preserve it. |
| `boundaries.rb super`: reopen Utils or QueryParser and replace `unescape` with a wrapper calling `super` | Such a replacement raises `NoMethodError` on base; on head it reaches the inherited implementation. Utils' singleton copy remains independent of the instance replacement. | Expected new ancestor lookup, not failure of a previously working wrapper. No fix requested. Ordinary subclass and prepend wrappers calling `super` work identically. |
| `boundaries.rb remove`: `Rack::Utils.send(:remove_method, :unescape)` and the same on QueryParser | Succeeds on base; raises `NameError` on head because the method is now inherited. `undef_method` still works identically. | Removing an owned method is not the same operation after extraction. A caller that wants to disable inherited lookup can use `undef_method`. No Rack shim requested without an actual caller. |
| `boundaries.rb ancestor`: a QueryParser subclass overrides `unescape`; its child includes Utils and invokes the private method | Base returns `"a b"`; head returns the parent's `"parent:a+b"`. Ruby deduplicates the shared Unescape module already in the superclass chain, so Utils no longer supplies a nearer local definition. | This is a real but constructed include/ancestor collision. A local `alias_method :unescape, :unescape` in Utils after inclusion restores the old result; tested on all seven pins. Do not add that opaque alias without a real caller. This constructed class already has a private `parse_query` from Utils on both trees, so it does not demonstrate a previously working normal custom-parser request failing. |
| Ruby 3.1.7 replay, BasicObject guard errors | Twelve diagnostic lines per configuration show different `error_highlight` source excerpts (`string`/old location versus `s`/new location). | Expected source-move diagnostics, not a new coercion failure. Do not promise identical complete diagnostic bytes across a refactor. |
| YARD/RDoc commands below | Public description/signature disappears as described above. | Restore the public generated-method docs. |

The replay's two escaped Object-address differences are nondeterministic fixture output, not a Rack behavior change.
The new mixin constant and ancestor entries are inherent in the requested extraction, not extra API promises.

## What passed, and what was not tested

The independent probes cover public module calls and `method(:unescape)`, private instance visibility, class/module
inclusion, object/class/module extension, singleton and instance replacements, alias wrappers, Utils singleton/instance
prepends, QueryParser prepends, rerunning `module_function` after a replacement or prepend, frozen receivers,
QueryParser subclass overrides with and without `super`, and replacement of `default_query_parser` with those subclasses.

Loading probes compare the complete newly loaded file lists, autoload state and first use for `rack`,
`rack/query_parser`, `rack/utils`, `rack/request`, and `rack/mock_request`. They match. Standalone QueryParser does
not load Utils. Repeated `load` of both files works on both trees. The thread probe returns six `true` results on
each pin; the encoding-conversion fiber still suspends once, decodes `"%41"` to `"A"`, and then mutates the input to
`"%ZZ"`, identically on base and head.

Rack has opt-in Ractor support (`rack/ractorize`, introduced by `f52cf2d2`, made idempotent by `dcb69623`). After
preloading and opting in, both trees decode/escape, parse simple and nested queries using a parser local to the
Ractor, and decode through a Utils includer in a non-main Ractor on 3.0.7–4.0.9. Ruby 2.7.3 has no Ractor. This is
not a claim that every Rack API, including its configurable global default parser, is universally Ractor-safe.

The builder's full replay was independently rerun: 204,073 output records in each of 16 paired configurations
(seven Rubies, clean and `cgi/util`, plus pure-Ruby CGI on 3.4.6 and 4.0.9). Each has 9,764 message-encoding-only
differences, one parameter-name difference, and two Object-address differences. Only 3.1.7 has the twelve additional
error_highlight records. An independent sweep uses every `Encoding.list` entry, invalid and valid escapes,
non-ASCII and invalid bytes, and frozen inputs. Its only input/output differences are that same Utils error-message
encoding change (267 rows on 2.7.3, 270 on later Rubies).

The input coverage also includes the builder's recorded suite arguments, seeded malformed-percent mixes,
UTF-16/32/UTF-7, nil/numbers/Symbols/Arrays/Hashes, String subclasses and ivars, frozen strings, BasicObjects,
duck conversion, stateful/input-mutating encoding conversion, and singleton String methods. These probes check
returned bytes/encoding/class/frozen state and exceptions; they do not prove equivalence for every Ruby object.

All 28 `CI=spec bundle exec rake` runs passed, including every separately run test file, with zero failures/errors
and two skips in each aggregate suite. Base and head have identical counts: 1,315 runs / 5,725 assertions on 2.7.3;
1,317 / 5,729 on 3.0.7 and 3.1.7; 1,317 / 6,421 on 3.2.9–4.0.9. The raw output is in `suite-summary.txt` and the
archive. Each pin has equal base/head Gemfile.lock files. No Rack hosted CI, JRuby, TruffleRuby, macOS, RuboCop,
or speed/allocation benchmark was run in this review. The builder's RuboCop count is not independently endorsed,
and the earlier PR's performance numbers were not remeasured.

## Module shape and comment/guard audit

The placement is reasonable: Utils already requires QueryParser, and standalone QueryParser must not start
requiring Utils. A nested, internal module avoids a new require/autoload and a new Rack top-level constant. Rack
already nests shared methods in `Request::Helpers` and `Response::Helpers`; the latter is also included in `Raw`.
`Unescape` is specific enough for this one-method module. There is no demonstrated reason to insist on `Helpers`,
another file, or another name.

Jeremy's actual inline suggestion was fetched and matches the brief, and his approved review names the exact base
head. His `c07e1b96` commit introduced Utils' no-argument `module_function` idiom; this file also uses named
`module_function :forwarded_values`. The explicit named call for an inherited method is appropriate here. This
supports saying the shape fits Rack, **not** claiming either jeremyevans or ioquatix has approved this name/head.

The exact-String/ASCII-compatible guard and invalid-percent check are unchanged, not new guards introduced by this
commit. They preserve the accepted URI fallback and malformed-input rejection; no additional guards are warranted
by this extraction. The private method's copied API comment is real documentation, not a prohibited implementation
note, but it no longer reaches the public API documentation. The new dependency comment is the only added
explanatory comment to delete.

## Original draft reply

The draft's mechanism and source-encoding explanation are accurate, and its tone is plain and non-defensive.
Qualify the error-message sentence with the ASCII-only case; avoid implying full equivalence of method tables or
diagnostic source excerpts. Do not send a stale commit ID after the requested changes.

> Moved it into `Rack::QueryParser::Unescape`, included by `QueryParser` and `Utils`, with `module_function :unescape`
> in `Utils`. For ASCII-only input, `Utils.unescape`'s invalid %-encoding message is now UTF-8, matching URI again;
> it had inherited utils.rb's binary source encoding.

No third-party app/gem reach claims are added by this reply. It is a draft only, for Thomas to approve before posting.

## Reproduction and receipts

The checked-out copies were `.amp/in/orb-backup/rk3-astra/base` and `.../rack`, detached at the exact base and head.
Official ruby-builder `toolcache` release archives for ubuntu-24.04 supplied 2.7.3, 3.0.7, 3.1.7, 3.2.9, 3.3.9 and
3.4.6; mise supplied 4.0.9. `run-replay.sh`, `run-extras.sh` and `run-suites.sh` preserve the commands and expected scratch paths.
The existing `bench/upstream/rk3/module/replay.rb`, `suite-inputs.rec` and `compare.rb` were read and reused without
changing them. `summarize.py` checks the full raw results, refusing unclassified replay differences.

```sh
ruby -I /path/to/rack/lib bench/upstream/rk3/review-astra/0046982320/adversarial.rb
ruby -I /path/to/rack/lib bench/upstream/rk3/review-astra/0046982320/boundaries.rb ancestor
ruby -ryard -e 'YARD.parse(ARGV); o=YARD::Registry.at("Rack::Utils.unescape"); p [o.parameters, o.docstring.to_s]' '/path/to/rack/lib/**/*.rb'
rdoc --quiet --op /path/to/output /path/to/rack/lib/rack/utils.rb /path/to/rack/lib/rack/query_parser.rb
```

Raw replay outputs, independent probe outputs, complete suite logs/lockfiles, metadata, fetched review/comments,
and documentation checks are in `receipts.tar.xz`. The initial attempt to use the pre-4.0 pure-CGI loader on 4.0.9
stopped at its own `C escape still loaded` assertion without running any cases; that is not a passed test. The final
4.0.9 run uses the builder's Ruby-4 loader and records a Ruby `cgi/escape.rb` source location for `CGI.unescape`.

No Rack source changes, fork/PR pushes, queue-item edits, or GitHub comments were made. Only the Lowrail review
record and receipts are deliverables from this thread.
