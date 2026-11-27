# Draft: prism shareable constant hash literal with a key after `**`

Status, 2026-11-27: **draft, nothing posted.** Thomas posts the report (or approves posting) and approves opening the
PR. The PR cites the Redmine ticket, so the ticket goes first; replace `NNNNN` with its number in the PR body and add
`[Bug #NNNNN]` to the commit subject before opening.

Fix head: [`2bda3f18fa`](https://github.com/thomasklemm/ruby/commit/2bda3f18fa) on
`thomasklemm/ruby:fix-prism-shareable-hash-merge`, one commit on ruby/ruby master `0d399335b7`. Raw data, repros and
probes: [bench/upstream/ruby-bugs-2026-11-27](../../bench/upstream/ruby-bugs-2026-11-27/).

## Redmine report

**Title:** Hash literal with a key after `**` in a shareable constant raises NoMethodError with prism

**Description:**

With prism, a hash literal assigned to a constant under `# shareable_constant_value` raises NoMethodError for an
internal method when a key follows a double splat:

```ruby
# shareable_constant_value: experimental_everything
H = { b: 2 }
X = { **H, a: 1 }
p X
```

Actual:

```
test.rb:3:in '<main>': undefined method 'core#hash_merge_bang_ptr' for an instance of Hash (NoMethodError)
```

Ruby 4.0.10 and 3.4.13 name `core#hash_merge_ptr` instead. Expected, as with `--parser=parse.y`:

```
{b: 2, a: 1}
```

The same error happens with `experimental_copy` and `literal`, and for hash literals with more than 128 pairs in
these modes unless all of them are static literals. `{ a: 1, **H }` works.

In `pm_compile_hash_elements`, the shareable branch compiles each key and value into `ret` instead of `anchor`, so in
every chunk after the first the pairs end up below the receiver of `core#hash_merge_*`. This came with 391b6746cd for
[Bug #20916](https://bugs.ruby-lang.org/issues/20916).

Tested with prism and parse.y on 3.4.13, 4.0.10 and master (0d399335b7). In both experimental modes, prism raises
NoMethodError on all three versions while parse.y returns the hash. In literal mode, parse.y raises
Ractor::IsolationError instead.

## Pull request

**Title:** Fix shareable constant hash literals with keys after `**` in prism

**Body:**

[Bug #NNNNN](https://bugs.ruby-lang.org/issues/NNNNN)

With prism, `X = { **h, a: 1 }` under `# shareable_constant_value: experimental_everything` (or `experimental_copy`)
raises NoMethodError for `core#hash_merge_bang_ptr`. For shareable constants, `pm_compile_hash_elements`
compiled each key and value into `ret` instead of `anchor`, so every chunk after the first had its pairs below the
receiver of the merge call. Hash literals with more than 128 pairs that are not all static literals failed the same
way.

This compiles them into `anchor`, as the non-shareable path does. The elements are still evaluated in source order,
and the results now match parse.y in the `experimental_everything` and `experimental_copy` modes.

**Commit message** (subject gets `[Bug #NNNNN]` once the ticket exists):

```
Fix hash literals with pairs after a chunk under shareable_constant_value

pm_compile_hash_elements collects the key and value of each pair in
`anchor` and inserts them when a chunk is flushed, after the receiver
and the hash to merge into. For a shareable constant the pairs were
compiled straight into `ret` instead, so they came before the receiver.
The first chunk still worked, but any later one, such as the pairs after
a double splat in `X = { **h, a: 1 }`, sent core#hash_merge_bang_ptr
or core#hash_merge_ptr to the hash and raised NoMethodError. The same
happened to hash literals with more than 128 pairs unless all of them
were static literals.

Compile the pairs into `anchor` as in the non-shareable case.
```

**Diff:** `prism_compile.c` (2 lines, `ret` to `anchor` for the key and value) and one more constant in the existing
`test_shareable_constant_value_hash_with_keyword_splat` in `test/ruby/test_parse.rb`
([patch](../../bench/upstream/ruby-bugs-2026-11-27/2bda3f18fa.patch)).

## Evidence

**Reproduced** ([shareable_kwsplat_min.rb](../../bench/upstream/ruby-bugs-2026-11-27/shareable_kwsplat_min.rb), [shareable_kwsplat_modes.txt](../../bench/upstream/ruby-bugs-2026-11-27/shareable_kwsplat_modes.txt)):
`{ **H, a: 1 }` on 3.4.13, 4.0.10 and master `0d399335b7`, prism and parse.y, all four modes. Prism raises
NoMethodError in `literal`, `experimental_everything` and `experimental_copy` on all three; `none` works. parse.y
returns the shareable hash in both experimental modes and raises Ractor::IsolationError in `literal` (as it does for
every hash literal with `**` in that mode).

**Cause, verified:** `--dump=insns` on master shows `putobject :a`, `putspecialobject 1`, `putobject 1`,
`send core#hash_merge_bang_ptr, argc:3`, so the receiver is the hash built from `**H`. The shareable branch at
`prism_compile.c:1606-1607` passes `ret`; the non-shareable branch above it passes `anchor`. `FLUSH_CHUNK` pushes
`putspecialobject VMCORE; swap` and then the anchor, which is empty here. Introduced by 391b6746cd (Kevin Newton,
2024-12-20, "Provide Ractor support for **", Bug #20916), so in every release since 3.4.0. The prism library parses
correctly; the fix belongs in `prism_compile.c` in ruby/ruby. parse.y compiles shareable hashes in its own path and is
not affected.

**Fix probe** ([shareable_probe.rb](../../bench/upstream/ruby-bugs-2026-11-27/shareable_probe.rb), outputs in the same
directory): 15 hash shapes (pairs, splats in every position, `**nil`, `**{}`, nested, duplicate keys, 130 pairs with and
without a splat, a constant splat, literal values) with side-effect logs, in all four modes. Base to head: only
NoMethodError rows change, to values; `none` mode is identical. Head with prism equals head with parse.y in `none`,
`experimental_everything` and `experimental_copy`, values and evaluation order included. In `literal`, head prism
returns a shareable `{b: 2, a: 1}` for `{ **H, a: 1 }` where parse.y raises IsolationError; prism already did this for
`{ **H }` and `{ a: 1, **H }` before the change (3.4.13 and master), so that parser difference is older and separate.

**Tests on the head** (build with `--enable-yjit --enable-zjit`; run on `9b8a037535`, which differs from the head only
in the commit message):

* New assertion fails without the fix (`NoMethodError: undefined method 'core#hash_merge_bang_ptr'`), passes with it.
* `test/ruby/test_parse.rb test_iseq.rb test_compile_prism.rb test_syntax.rb test_keyword.rb test_ractor.rb`: 778
  tests, 0 failures. `test_parse.rb test_iseq.rb` with `--parser=parse.y`: 190 tests, 0 failures.
* `make btest`: PASS all 2148.
* `make test-all TESTS=ruby -j8`: 11761 tests, 1 failure, `TestThread#test_handle_interrupt_masks_sigint`, which
  fails the same way on unmodified master in this orb.

**Existing reports:** none for this error. Searched bugs.ruby-lang.org (`hash_merge_ptr`, `shareable_constant_value`
open issues) and GitHub ruby/ruby and ruby/prism PRs and issues (`hash_merge_ptr`, `shareable_constant_value hash`,
`shareable kwsplat`). Related but different: [Bug #20472](https://bugs.ruby-lang.org/issues/20472) (open, `A = { **a }`
under `experimental_copy` crashed in 2024; that shape works now), [Bug #20927](https://bugs.ruby-lang.org/issues/20927)
(parse.y, fixed), [Bug #22646](https://bugs.ruby-lang.org/issues/22646) (open, parse.y stack underflow for a braceless
hash). Not fixed on master `0d399335b7`; no later commit touches these lines.
