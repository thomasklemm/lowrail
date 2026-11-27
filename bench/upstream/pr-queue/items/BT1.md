---
id: BT1
repo: ruby/ruby
kind: fix
area: vm_backtrace.c, location_format (Exception#backtrace, Kernel#caller, Location#to_s)
reviewer: "nobu (author of b9ad19da12 in #17882)"
branch: thomasklemm/backtrace-format-length
head: "e75b1f0109959b3df53738e68c273f812b8283d1"
base: master
built_on: "274cfe719a"
introduced_by: 17882
depends_on: []
tracker: []
stacked_on:
alternative_of:
impact: "Ruby 4.1 regression: formatting a backtrace location takes about 26% more instructions than on 4.0.9 (Kernel#caller and Exception#backtrace on a 150-frame stack, 0.86M vs 1.09M Ir per call, A/A under 0.03%), and a file path containing NUL makes Exception#backtrace, caller and caller_locations#to_s raise ArgumentError; the fix appends file and method name by length, back to 4.0.9's instruction count, and prints such a path in full (4.0.9 truncated it at the NUL)"
rank: 2
risky: true
state: ready
pr: 20261
note: "2026-11-27 (coordinator, option b): body revision for #20261 with one Callgrind line on exact builds (caller per call: base 274cfe719a 1,090,474/1,090,297, head e75b1f0109 851,150/851,094, 4.0.9 861,004/861,212; backtrace 1,103,356/1,103,301, 862,437/862,421, 872,652/872,691; evidence/backtrace-format/callgrind-body-line.txt) and a note that benchmark/vm_backtrace_to_s.yml is for wall time, which our VMs cannot measure steadily (body-bench-2026-11-27, A/A 1.00x to 1.16x). The NUL example now prints e.backtrace[0].sub with <NUL>, because GitHub stores the literal text backslash-u0000 as backslash-caret-at even through --input JSON; expected outputs checked on 4.0.9, master and the head. Needs thermos-sol and Astra on this exact body, then PATCH. 2026-11-27 (Thomas): opened as ruby/ruby#20261 as an exception to the ruby/ruby pace cap, because of the Ruby 4.1 release on 2026-12-25. 2026-11-27: thermos-sol (retry, narrow brief) and Astra both approve head e75b1f0109 and body 0043078758; stays candidate, not opened (ruby/ruby: Thomas names the item, pace cap used this week). The first thermos-sol thread was stopped by the model safety check, not by a finding. 2026-11-27 (after Astra changes on afb18cccd9): new head e75b1f0109, tree identical to afb18cccd9 (code, test, benchmark unchanged), commit message without the 25% (an instruction-count figure, not time). Body: the example now rescues and prints e.backtrace (uncaught, master prints -e: boom, not ArgumentError); the percentage is gone, then, after Astra's confirm, the make benchmark table moved out of the body too (DECISIONS, Correctness fixes: no numbers in the body; it stays in evidence/backtrace-format/make-benchmark.txt). Coverage claim corrected: btdiff.rb formats its own block frame, so its 2,728 identical cases do not vary the eval file name or method; Astra real-frame oracle (3,335 cases: 402 intended NUL fixes, 2,739 cached-coderange-only differences, 194 identical, no other public-output difference) is the exactness evidence (evidence/backtrace-format/astra). risky: true for a VM change. 2026-11-27: found by the Ruby 4.1 differential (docs/upstream/ruby41-differential-409.md, Finding 3). Not posted anywhere; needs both reviews, then Thomas decides (DECISIONS: ruby/ruby PRs only for items he names). Explanation for Thomas: since b9ad19da12 (nobu, 'Format backtrace locations as Ruby strings', merged in #17882 'Fix for String without terminators', 2026-07-15) location_format writes file and method name through \"%\"PRIsVALUE; rb_str_catf then runs each through ruby__sfvextra, which calls rb_obj_as_string, rb_enc_compatible and StringValueCStr. StringValueCStr scans the whole string for NUL (search_nonascii, str_null_check) and raises for a path with NUL, which the old RSTRING_PTR %s path simply truncated at the NUL. The fix keeps the commit's intent (no reliance on NUL termination) and appends both strings by RSTRING_LEN, with the same encoding choice as ruby__sfvextra (rb_enc_compatible, else convert with replacement). Found from react-starter-kit GET home (+9% Ir, A/A 0.35%): Rack::Test::CookieJar#for and Net::HTTP#connect grew, both on lines that build a backtrace (Vite's dev-server probe raises ECONNREFUSED and re-raises with a message). Callgrind per call (bt.rb, 150-frame stack, N=300 minus N=100 over 200): caller 861,187 (4.0.9), 1,088,976 (master f3e180b5eb), 849,991 (master + fix); e.backtrace 872,662 / 1,102,106 / 861,574; raise without backtrace 45,025 / 47,253 / 47,354. make benchmark ITEM=vm_backtrace_to_s (new, 50 frames, 10 repeats, pinned core): master 45.2k i/s, fix 53.3k i/s (1.18x); a 4-way run gave 4.0.9 50.8k, master 38.6k, master again 42.0k (A/A 1.09x: wall time on this orb is noisy, Callgrind is the primary evidence), fix 52.2k. In-app (cpu-census interp, fixed heap, A/A pair): react-starter-kit GET home master 8,514,606 / 8,532,556, fix 8,341,609 / 8,369,881 (-2.0%, A/A 0.2-0.3%); hackatime GET dashboard master 51,423,684 / 51,407,823, fix 51,677,191 / 51,257,252 (within A/A). Exactness: differential probe btdiff.rb, 2,728 cases (8 file-name encodings x 7 raw byte strings + UTF-8 and 300-char paths, x every method-name symbol that the encodings allow; caller, caller_locations to_s and inspect, Exception#backtrace; cfunc frames; full_message): master and fix byte-identical including encodings, valid_encoding? and ascii_only?. NUL path (btnul.rb): 4.0.9 truncates ('a:1:in ...'), master raises ArgumentError, fix keeps the full path ('a\\u0000b.rb:1:in ...'), as Location#path already returns it. Tests on the fix: make test-all ruby/test_backtrace.rb test_exception.rb test_eval.rb test_beginendblock.rb 186 tests, 5266 assertions, 0 failures; new test_backtrace_with_nul_in_path raises on master and passes on the fix. Ownership: no Redmine issue or ruby/ruby PR on backtrace speed or NUL paths since 2026-07 (searched backtrace slow/performance/regression, caller slower, location_format, null byte backtrace); open #17978 (Bug #22197) touches backtrace labels, not location_format. Not run: btest, full test-all, YJIT/ZJIT micro, hosted CI. Evidence: bench/upstream/ruby-differential/evidence/backtrace-format."
ownership: {date: 2026-11-27, checked: ["open PRs cross-referencing #17882","open PRs naming deep that change benchmark/vm_backtrace_to_s.yml, vm_backtrace.c"], hits: []}
evidence:
  - bench/upstream/ruby-differential/evidence/backtrace-format
  - bench/upstream/ruby-differential/evidence/backtrace-format/astra
  - bench/upstream/ruby-differential/evidence/backtrace-format/thermos-sol
passes:
  - reviewer: astra
    orb: T-01a21dcc-1fab-7104-9ca4-c62537a6cf82
    head: "afb18cccd9da322700048f40467a1c6780123f8e"
    date: 2026-11-27
    verdict: changes
    open: >-
      No C correctness defect demonstrated, but text/evidence need correction. The body's exact uncaught-eval
      example prints '-e: boom (RuntimeError)' on master, not ArgumentError; explicitly call e.backtrace or
      caller in the example. Remove '25% slower' from body/commit: the 150-frame figures are instructions,
      not elapsed time; keep this correctness body's numbers in the record per DECISIONS. Replace the old
      btdiff coverage claim: its block formats the harness frame, not the varied file/name. Mark this VM item
      risky. Independent fresh base/head builds passed test_backtrace/test_exception and btest; the added
      behavior-only test errors with string contains null byte on base and passes on head. New 3335-case
      oracle plus selected GC.stress repeat found only intended NUL fixes and cached-coderange differences,
      with equal bytes/encoding/valid_encoding?/rescanned coderange elsewhere. Callgrind A/A supports the
      instruction win; pinned benchmark-driver confirms the throughput direction. Full findings, smallest
      fixes, commands, limitations and raw archive: bench/upstream/ruby-differential/evidence/backtrace-format/astra/review.md.
  - reviewer: astra
    orb: T-01a21dcc-1fab-7104-9ca4-c62537a6cf82
    head: "e75b1f0109959b3df53738e68c273f812b8283d1"
    date: 2026-11-27
    verdict: changes
    open: >-
      Confirm pass against Lowrail 61879acc: verified equal Git trees and parents for e75b1f0109 and
      afb18cccd9; prior code/test/oracle evidence applies without rebuilding. Revised commit message is
      acceptable, and rerunning the exact revised example gives the annotated results on release/base/head.
      The corrected coverage note and risky:true are accepted. Remaining body blocker: DECISIONS explicitly
      says 'a correctness PR has no numbers' (PR descriptions) and 'no numbers in the body' (Correctness fixes).
      Its general benchmark-format paragraph specifies how to present performance evidence, not an exception
      for this correctness fix. Remove the table and closing version-speed sentence; keep both in the record.
      Also correct stale impact wording ('25% slower' should describe instructions; NUL output is deliberately
      different from 4.0.9), and restore the preceding historical Astra pass to afb18cccd9: 61879acc rewrote
      its head to e75b1f0109, although that pass reviewed afb18cccd9. No source-code change or repeat build is
      requested. Details: bench/upstream/ruby-differential/evidence/backtrace-format/astra/review.md, confirm section.
  - reviewer: astra
    orb: T-01a21dcc-1fab-7104-9ca4-c62537a6cf82
    head: "e75b1f0109959b3df53738e68c273f812b8283d1"
    date: 2026-11-27
    verdict: approve
    open: >-
      None. Final text-only confirm against Lowrail 8d9d6857. Verified supplied body SHA-256
      0043078758ad9a6b3833a484273efa9c4c321634de3a2b7b21a6bab4f4feb601 (without title, two trailing newlines);
      script/pr-queue's parsed body hashes to db9a3ad32c3c4e6006bc6d2b3afbb9117a6e3be00d99df75b8b8cd64d8d2286a
      (one trailing newline). The table and closing speed sentence are removed; benchmark evidence is retained.
      Impact now distinguishes instructions from time and full NUL paths from 4.0.9 truncation. Historical
      pass attribution is restored. Remote head remains e75b1f0109; prior verified tree identity, fresh-build
      suites, oracle, GC.stress and corrected-example evidence apply. No further code/text findings and no
      rebuild or test rerun for this text-only confirm. Approval is for this exact head and body, not permission
      to open upstream outside the queue's remaining gates.
  - reviewer: thermos-sol
    orb: T-01a21dd5-050e-70b3-9097-842e5d974661
    head: "e75b1f0109959b3df53738e68c273f812b8283d1"
    date: 2026-11-27
    verdict: approve
    open: >-
      No must-fixes. Reviewed the number-free body at Lowrail 8d9d6857, SHA-256
      0043078758ad9a6b3833a484273efa9c4c321634de3a2b7b21a6bab4f4feb601, and the revised commit message;
      ran its exact rescued-backtrace example on release, base and head and confirmed all annotated results.
      Applied both Thermos correctness/security and maintainability rubrics personally, without extra reviewers
      as requested. Verified that afb18cccd9 and e75b1f0109 have identical trees and the same parent. Built base
      274cfe719a and the change with GCC 14.2.0, -O3, JITs disabled; reran both requested test files after the
      message-only head update: 132 tests, 4633 assertions, no failures/errors/skips. Base has 131 tests and
      4630 assertions, also clean. Both builds pass all 2148 btests, with the same fiber-count skip. The added
      test fails once on base with ArgumentError and passes once on head; it checks the complete public caller
      string, not implementation counts. The benchmark measures formatting captured locations, not stack capture.
      No added code comments. Independent real-frame probes cover 12668 Ruby-method/eval/conversion cases and
      5922 C-method cases: 13504 identical public results and 5086 NUL errors replaced by output, no other
      differences in bytes, encoding, validity, ascii_only?, result class or frozen state where checked. Cases
      include encoded and invalid paths, real encoded Ruby names, arbitrary C-method symbol bytes, cfunc frames,
      full_message in both orders, zero/negative/large line numbers, frozen String subclasses, once-only duck
      conversion and independent mutable outputs. NUL in an anonymous C-method name is accepted too, as intended
      by appending both inputs by length. Eight selected GC.stress cases also preserve the six non-NUL results
      and fix two NUL cases without crashing. Inputs remain ISEQ-owned; no Ruby callbacks or loading/configuration
      boundary is added, and the converted temporary and method name retain GC guards. The helper keeps the same
      compatible-encoding selection and replacement fallback as ruby__sfvextra. Cold read: make the same encoded
      accumulator; use a compatible ASCII-compatible encoding, otherwise convert with replacement; copy by
      length; add the existing punctuation. L1, no unjustified abstraction: rb_str_dup changes encoding behavior,
      rb_str_buf_append rejects incompatible encodings, and changing ruby__sfvextra would broaden the fix to all
      PRIsVALUE callers. No smaller equally scoped equivalent found; Flog/RuboCop method metrics do not apply to C.
      Fixed-heap Callgrind A/A confirms caller 1093072/1093116 to 849713/849741 Ir/call and raise-plus-backtrace
      1105867/1105931 to 860942/860985; raise-only remains within A/A. Installed 4.0.9 gives about 883088 and
      894755 respectively, historical context rather than an identically configured release build. The required
      pinned make benchmark, ten repeats, gives 30.594k to 36.931k i/s. Four-way driver control gives release
      34.888k, base 30.247k, base again 30.492k, head 36.064k. A 16/128/1048576-byte sweep with non-ASCII or invalid
      UTF-8 absent/early/late, also consuming valid_encoding?, found no slowdown; the smallest head-to-faster-base
      ratio is 1.048 on the large invalid-early validity-consumer row, with noisy rows retained. Numbers are not
      claimed as elapsed-time gains for caller/backtrace. Raw profiles, differential output, build/test/stress and
      benchmark logs are retained under evidence/backtrace-format/thermos-sol, with results.txt as the index;
      probe scripts stay in this orb backup. Not run: full test-all, JIT builds, sanitizers, other architectures,
      app corpus or hosted Ruby CI. No upstream post or fork push.
---

# Append backtrace location strings by length

Since `location_format` switched to `"%"PRIsVALUE`, every backtrace line goes through `ruby__sfvextra`, which converts, encoding-checks and `StringValueCStr`s the file and method name. That made `Kernel#caller` and `Exception#backtrace` slower than in 4.0, and a backtrace whose file path contains a NUL byte can no longer be built:

```ruby
begin
  eval("raise 'boom'", nil, "a\0b.rb")
rescue => e
  p e.backtrace[0].sub("\0", "<NUL>")
end
# 4.0.9:  "a:1:in '<main>'"
# master: string contains null byte (ArgumentError) from Exception#backtrace
# this:   "a<NUL>b.rb:1:in '<main>'"
```

This appends both strings by their length instead, choosing the encoding the same way `ruby__sfvextra` does, so it still doesn't depend on NUL termination. The output is unchanged for other paths and names.

Under Callgrind, one `caller` on a 150-frame stack takes 1.09M instructions on master, 0.85M with this change and 0.86M on Ruby 4.0.9 (`Exception#backtrace`: 1.10M, 0.86M and 0.87M), with repeated runs within 0.03%. `benchmark/vm_backtrace_to_s.yml` is included for a wall-time comparison; I couldn't get stable wall times on the VMs I have, so no timing is quoted here.

