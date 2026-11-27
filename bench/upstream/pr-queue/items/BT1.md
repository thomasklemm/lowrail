---
id: BT1
repo: ruby/ruby
kind: fix
area: vm_backtrace.c, location_format (Exception#backtrace, Kernel#caller, Location#to_s)
reviewer: "nobu (author of b9ad19da12 in #17882)"
branch: thomasklemm/backtrace-format-length
head: "afb18cccd9da322700048f40467a1c6780123f8e"
base: master
built_on: "274cfe719a"
introduced_by: 17882
depends_on: []
tracker: []
stacked_on:
alternative_of:
impact: "Ruby 4.1 regression: formatting a backtrace location got about 25% slower than 4.0.9 (Kernel#caller and Exception#backtrace on a 150-frame stack, 0.86M to 1.09M instructions per call), and a file path containing NUL makes backtrace, caller_locations#to_s and full_message raise ArgumentError; the fix appends file and method name by length, back to 4.0.9's cost and output"
rank: 2
risky: false
state: candidate
pr:
note: "2026-11-27: found by the Ruby 4.1 differential (docs/upstream/ruby41-differential-409.md, Finding 3). Not posted anywhere; needs both reviews, then Thomas decides (DECISIONS: ruby/ruby PRs only for items he names). Explanation for Thomas: since b9ad19da12 (nobu, 'Format backtrace locations as Ruby strings', merged in #17882 'Fix for String without terminators', 2026-07-15) location_format writes file and method name through \"%\"PRIsVALUE; rb_str_catf then runs each through ruby__sfvextra, which calls rb_obj_as_string, rb_enc_compatible and StringValueCStr. StringValueCStr scans the whole string for NUL (search_nonascii, str_null_check) and raises for a path with NUL, which the old RSTRING_PTR %s path simply truncated at the NUL. The fix keeps the commit's intent (no reliance on NUL termination) and appends both strings by RSTRING_LEN, with the same encoding choice as ruby__sfvextra (rb_enc_compatible, else convert with replacement). Found from react-starter-kit GET home (+9% Ir, A/A 0.35%): Rack::Test::CookieJar#for and Net::HTTP#connect grew, both on lines that build a backtrace (Vite's dev-server probe raises ECONNREFUSED and re-raises with a message). Callgrind per call (bt.rb, 150-frame stack, N=300 minus N=100 over 200): caller 861,187 (4.0.9), 1,088,976 (master f3e180b5eb), 849,991 (master + fix); e.backtrace 872,662 / 1,102,106 / 861,574; raise without backtrace 45,025 / 47,253 / 47,354. make benchmark ITEM=vm_backtrace_to_s (new, 50 frames, 10 repeats, pinned core): master 45.2k i/s, fix 53.3k i/s (1.18x); a 4-way run gave 4.0.9 50.8k, master 38.6k, master again 42.0k (A/A 1.09x: wall time on this orb is noisy, Callgrind is the primary evidence), fix 52.2k. In-app (cpu-census interp, fixed heap, A/A pair): react-starter-kit GET home master 8,514,606 / 8,532,556, fix 8,341,609 / 8,369,881 (-2.0%, A/A 0.2-0.3%); hackatime GET dashboard master 51,423,684 / 51,407,823, fix 51,677,191 / 51,257,252 (within A/A). Exactness: differential probe btdiff.rb, 2,728 cases (8 file-name encodings x 7 raw byte strings + UTF-8 and 300-char paths, x every method-name symbol that the encodings allow; caller, caller_locations to_s and inspect, Exception#backtrace; cfunc frames; full_message): master and fix byte-identical including encodings, valid_encoding? and ascii_only?. NUL path (btnul.rb): 4.0.9 truncates ('a:1:in ...'), master raises ArgumentError, fix keeps the full path ('a\\u0000b.rb:1:in ...'), as Location#path already returns it. Tests on the fix: make test-all ruby/test_backtrace.rb test_exception.rb test_eval.rb test_beginendblock.rb 186 tests, 5266 assertions, 0 failures; new test_backtrace_with_nul_in_path raises on master and passes on the fix. Ownership: no Redmine issue or ruby/ruby PR on backtrace speed or NUL paths since 2026-07 (searched backtrace slow/performance/regression, caller slower, location_format, null byte backtrace); open #17978 (Bug #22197) touches backtrace labels, not location_format. Not run: btest, full test-all, YJIT/ZJIT micro, hosted CI. Evidence: bench/upstream/ruby-differential/evidence/backtrace-format."
ownership: {date: 2026-11-27, checked: ["open PRs cross-referencing #17882","open PRs naming deep that change benchmark/vm_backtrace_to_s.yml, vm_backtrace.c"], hits: []}
passes: []
---

# Append backtrace location strings by length

Since `location_format` switched to `"%"PRIsVALUE`, every backtrace line goes through `ruby__sfvextra`, which converts, encoding-checks and `StringValueCStr`s the file and method name. That makes `Kernel#caller` and `Exception#backtrace` about 25% slower than in 4.0 on a deep stack, and a file path that contains a NUL byte now raises while the backtrace is built:

```ruby
eval("raise 'boom'", nil, "a\0b.rb")
# 4.0.9:  a:1:in '<main>': boom (RuntimeError)
# master: string contains null byte (ArgumentError)
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
