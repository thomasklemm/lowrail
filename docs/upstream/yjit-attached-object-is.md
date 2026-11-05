# YJIT attached-object predicate

Rework of [ruby/ruby#19648](https://github.com/ruby/ruby/pull/19648), following
[XrXr's direction](https://github.com/ruby/ruby/pull/19648#issuecomment-6671260846).
The existing PR and its branch are left untouched; Thomas decides on the update after the coordinator's review.

## Proposed title

YJIT: Check singleton attached-object identity in C

## Proposed body

YJIT only needs an identity comparison when deciding whether to guard a singleton-class receiver by identity.
Replace the `rb_class_attached_object()` call with `rb_yjit_attached_object_is(klass, object)`, which checks
the singleton flag and compares the attached-object pointer in C. Rust receives only a boolean. The predicate
cannot raise, allocate, or take locks; the generated guards are unchanged.

The proposed fix in #19740 addresses the block-param proxy Ractor failure. This is the follow-up hygiene
change XrXr suggested, keeping the compile-time check trivially leaf. Thanks to XrXr for the direction.

## Implementation and evidence

The original PR head is `e8c12f76a82abd110c8be2af9e29a3d94749cd34`. The fresh base is ruby/ruby master
`f6996b73a27b2a424402bbda594eb80697e79c07`.
The reviewed replacement is
[`3c26a692c903f63875e8a86b911c8ca5c365779f`](https://github.com/thomasklemm/ruby/commit/3c26a692c903f63875e8a86b911c8ca5c365779f),
on the new [fork branch](https://github.com/thomasklemm/ruby/tree/thomasklemm/yjit-attached-object-is).
The patch touches only four YJIT files: nine insertions and four deletions. No VM, bootstrap test, Ruby test,
shared JIT or ZJIT changes are included. The proxy regression test belongs to #19740, not this patch.

Plain reading: check whether the class is a singleton class; if so, compare its attached-object pointer
with the sampled receiver. Keep the existing IO exclusion and generated guards unchanged.

The helper belongs in `yjit.c`, as requested in k0kubun's earlier review. `yjit/src/cruby.rs` re-exports
the generated bindings; the allowlist in `yjit/bindgen/src/main.rs` controls the C entry points.
Bindings were generated with `make yjit-bindgen`, not hand-edited, using Clang 14 and a separate
`--enable-yjit=dev --enable-zjit` configuration so the checked-in instruction constants stay intact.
The earlier generator error (`no line to replace: pub type ruby_rstruct_flags = u32;`) reproduced with
missing `rustfmt`; installing that tool resolved it without changing the generator. Repeating generation
on the final head leaves the source clean. Release-object disassembly contains only reads, comparisons,
branches and returns for the predicate, with no calls.

The proposed title says "in C" rather than "without reading it": C still reads the pointer, but no attached
object is returned to Rust. "The generated guards are unchanged" deliberately avoids claiming unchanged
compilation behavior on master before #19740.

### Verification

GCC 12.2 builds both `--enable-yjit` and `--enable-yjit=dev`, with ZJIT disabled. The latter defines
`RUBY_DEBUG=1` and includes YJIT runtime checks. All final-head commands below exit successfully. Because
these are out-of-tree builds, `TESTS` and `BTESTS` use absolute source paths; the first attempt with a
build-relative `test/ruby/test_yjit.rb` was rejected before running tests, then corrected.

| Check | Result |
| --- | --- |
| `make test-all TESTS=<source>/test/ruby/test_yjit.rb`, debug | 150 tests, 711 assertions, no failures/errors, 1 skip |
| Same YJIT suite, release | 150 tests, 711 assertions, no failures/errors, 1 skip |
| `make test-all TESTS=<source>/test/ruby/test_ractor.rb RUN_OPTS=--yjit-call-threshold=1`, debug | 88 tests, 924 assertions, no failures/errors/skips |
| Same Ractor suite, release | 88 tests, 924 assertions, no failures/errors/skips |
| `make btest` with YJIT and Ractor bootstrap files, debug, threshold 1 | All 583 tests pass |
| `cargo test --all-features --manifest-path yjit/Cargo.toml`, final head | 374 pass, no failures/ignored tests; doc tests pass |
| Ordinary, singleton and non-materialized metaclass sends, debug, threshold 1, `--yjit-verify-ctx` | Expected results survive 30 rounds of full GC and compaction |

On the unmodified base, a `--enable-yjit=dev` build reproduces the original assertion:
`rb_vm_check_ints:ec->assert_critical_section_entered == 0` (exit 134), with
`def call_block(&block) = block.call; p Ractor.new { call_block { :ok } }.value` at call threshold 1.
Master plus only #19740 returns `:ok` in a debug build with the original YJIT accessor still in place.
This independently confirms that #19740 fixes the immediate repro; this patch need not carry its test.

### Combination with the proxy fix

`git merge-tree --write-tree 97371f6489abc8c70c8329b895005e4c29d6b480 3c26a692c903f63875e8a86b911c8ca5c365779f`
merges cleanly (exit 0), producing tree `62d5368a5b70d79f8a19a30db17782afdb406d84`. A separate worktree
containing master plus the two patches has exactly that index tree, verified with `git write-tree`.
Its `--enable-yjit=dev` build passes the YJIT suite (150 tests, 711 assertions, no failures/errors, 1 skip)
and the YJIT plus Ractor bootstrap files at threshold 1 (all 584 tests pass, including #19740's new test).

### Independent reviews

Both skeptical reviewers approve exact head `3c26a692c903f63875e8a86b911c8ca5c365779f` with no must-fix findings.
They reran their passes after removing the duplicate proxy test and rewriting the commit and body.

The code reviewer checked leafness, C/Rust ABI, all 17 guard call sites, argument rooting and VM lock/barrier
assumptions, ordinary classes, matching and mismatched singleton attachments, lazy metaclasses, IO reopen,
bindings and existing test coverage. The sampled receiver remains on the VM stack and its class is reachable;
the predicate introduces no allocation or safepoint, retains nothing and returns only a boolean. Existing
compilation synchronization protects its reads. The singleton check short-circuits before accessing the
attachment union for an ordinary class; the IO exclusion remains essential and stays in Rust.

The wording reviewer checked the final title, two-paragraph body and commit message against the actual diff,
XrXr's comment and still-open #19740. The initial wording was corrected to avoid implying #19740 had merged.
The final proposal makes no speed claim or broad claim of Ractor safety.

ZJIT's ordinary exact-class guard compares the receiver's class pointer, so it does not have this particular
attachment-fetching guard. Its unused `is_metaclass` and `qualified_method_name` still call
`rb_class_attached_object`; the latter is used for formatting and the inline denylist, not only diagnostics.
Those calls remain potential raising-accessor hazards, but no concrete failing ZJIT case was demonstrated.
Nothing here certifies them leaf-safe or changes them. This stays a YJIT-only concern.

Sol and Astra review of this exact head remains with the coordinator. The public PR and its original branch
must remain unchanged until that review and Thomas's update decision.
