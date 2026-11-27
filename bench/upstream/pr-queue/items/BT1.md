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
impact: "Ruby 4.1 regression: formatting a backtrace location got about 25% slower than 4.0.9 (Kernel#caller and Exception#backtrace on a 150-frame stack, 0.86M to 1.09M instructions per call), and a file path containing NUL makes backtrace, caller_locations#to_s and full_message raise ArgumentError; the fix appends file and method name by length, back to 4.0.9's cost and output"
rank: 2
risky: true
state: candidate
pr:
note: "2026-11-27 (after Astra changes on afb18cccd9): new head e75b1f0109, tree identical to afb18cccd9 (code, test, benchmark unchanged), commit message without the 25% (an instruction-count figure, not time). Body: the example now rescues and prints e.backtrace (uncaught, master prints -e: boom, not ArgumentError); the percentage is gone, the make benchmark table stays (DECISIONS: ruby/ruby bodies lead with benchmark/*.yml). Coverage claim corrected: btdiff.rb formats its own block frame, so its 2,728 identical cases do not vary the eval file name or method; Astra real-frame oracle (3,335 cases: 402 intended NUL fixes, 2,739 cached-coderange-only differences, 194 identical, no other public-output difference) is the exactness evidence (evidence/backtrace-format/astra). risky: true for a VM change. 2026-11-27: found by the Ruby 4.1 differential (docs/upstream/ruby41-differential-409.md, Finding 3). Not posted anywhere; needs both reviews, then Thomas decides (DECISIONS: ruby/ruby PRs only for items he names). Explanation for Thomas: since b9ad19da12 (nobu, 'Format backtrace locations as Ruby strings', merged in #17882 'Fix for String without terminators', 2026-07-15) location_format writes file and method name through \"%\"PRIsVALUE; rb_str_catf then runs each through ruby__sfvextra, which calls rb_obj_as_string, rb_enc_compatible and StringValueCStr. StringValueCStr scans the whole string for NUL (search_nonascii, str_null_check) and raises for a path with NUL, which the old RSTRING_PTR %s path simply truncated at the NUL. The fix keeps the commit's intent (no reliance on NUL termination) and appends both strings by RSTRING_LEN, with the same encoding choice as ruby__sfvextra (rb_enc_compatible, else convert with replacement). Found from react-starter-kit GET home (+9% Ir, A/A 0.35%): Rack::Test::CookieJar#for and Net::HTTP#connect grew, both on lines that build a backtrace (Vite's dev-server probe raises ECONNREFUSED and re-raises with a message). Callgrind per call (bt.rb, 150-frame stack, N=300 minus N=100 over 200): caller 861,187 (4.0.9), 1,088,976 (master f3e180b5eb), 849,991 (master + fix); e.backtrace 872,662 / 1,102,106 / 861,574; raise without backtrace 45,025 / 47,253 / 47,354. make benchmark ITEM=vm_backtrace_to_s (new, 50 frames, 10 repeats, pinned core): master 45.2k i/s, fix 53.3k i/s (1.18x); a 4-way run gave 4.0.9 50.8k, master 38.6k, master again 42.0k (A/A 1.09x: wall time on this orb is noisy, Callgrind is the primary evidence), fix 52.2k. In-app (cpu-census interp, fixed heap, A/A pair): react-starter-kit GET home master 8,514,606 / 8,532,556, fix 8,341,609 / 8,369,881 (-2.0%, A/A 0.2-0.3%); hackatime GET dashboard master 51,423,684 / 51,407,823, fix 51,677,191 / 51,257,252 (within A/A). Exactness: differential probe btdiff.rb, 2,728 cases (8 file-name encodings x 7 raw byte strings + UTF-8 and 300-char paths, x every method-name symbol that the encodings allow; caller, caller_locations to_s and inspect, Exception#backtrace; cfunc frames; full_message): master and fix byte-identical including encodings, valid_encoding? and ascii_only?. NUL path (btnul.rb): 4.0.9 truncates ('a:1:in ...'), master raises ArgumentError, fix keeps the full path ('a\\u0000b.rb:1:in ...'), as Location#path already returns it. Tests on the fix: make test-all ruby/test_backtrace.rb test_exception.rb test_eval.rb test_beginendblock.rb 186 tests, 5266 assertions, 0 failures; new test_backtrace_with_nul_in_path raises on master and passes on the fix. Ownership: no Redmine issue or ruby/ruby PR on backtrace speed or NUL paths since 2026-07 (searched backtrace slow/performance/regression, caller slower, location_format, null byte backtrace); open #17978 (Bug #22197) touches backtrace labels, not location_format. Not run: btest, full test-all, YJIT/ZJIT micro, hosted CI. Evidence: bench/upstream/ruby-differential/evidence/backtrace-format."
ownership: {date: 2026-11-27, checked: ["open PRs cross-referencing #17882","open PRs naming deep that change benchmark/vm_backtrace_to_s.yml, vm_backtrace.c"], hits: []}
evidence:
  - bench/upstream/ruby-differential/evidence/backtrace-format
  - bench/upstream/ruby-differential/evidence/backtrace-format/astra
passes:
  - reviewer: astra
    orb: T-01a21dcc-1fab-7104-9ca4-c62537a6cf82
    head: "e75b1f0109959b3df53738e68c273f812b8283d1"
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
---

# Append backtrace location strings by length

Since `location_format` switched to `"%"PRIsVALUE`, every backtrace line goes through `ruby__sfvextra`, which converts, encoding-checks and `StringValueCStr`s the file and method name. That made `Kernel#caller` and `Exception#backtrace` slower than in 4.0, and a backtrace whose file path contains a NUL byte can no longer be built:

```ruby
begin
  eval("raise 'boom'", nil, "a\0b.rb")
rescue => e
  p e.backtrace[0]
end
# 4.0.9:  "a:1:in '<main>'"
# master: string contains null byte (ArgumentError) from Exception#backtrace
# this:   "a\u0000b.rb:1:in '<main>'"
```

This appends both strings by their length instead, choosing the encoding the same way `ruby__sfvextra` does, so it still doesn't depend on NUL termination. The output is unchanged for other paths and names.

```
compare-ruby: ruby 4.1.0dev (2026-11-27T09:42:55Z HEAD f3e180b5eb) +PRISM [x86_64-linux]
built-ruby: ruby 4.1.0dev (2026-11-27T13:11:57Z HEAD 274cfe719a) +PRISM [x86_64-linux]
# Iteration per second (i/s)

|                   |compare-ruby|built-ruby|
|:------------------|-----------:|---------:|
|vm_backtrace_to_s  |     45.247k|   53.269k|
|                   |           -|     1.18x|
```

Ruby 4.0.9 runs the same benchmark at about the built ruby's speed.
