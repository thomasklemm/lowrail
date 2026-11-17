---
id: ZSD1
repo: ruby/ruby
kind: perf
area: ZJIT, String#dup
reviewer: "tekknolagi (filed Shopify/ruby#1106)"
branch: thomasklemm/zjit-string-dup
head: "c71669b114"
base: master
built_on: "7919a47d46"
depends_on: []
stacked_on:
alternative_of:
impact: "String#dup on a bare String becomes StringCopy without a frame: micro 388 -> 359 Ir per call (A/A 388); String#dup C calls per iteration railsbench 25,218 -> 0, lobsters 4,243 -> 43, shipit 5,663 -> 12; no app-level claim (about 0.015% of a railsbench iteration)"
rank: 3
risky: false
state: built
pr:
note: "Built 2026-11-17 night; not opened (ZS1 waits for a response). Stated ask (Shopify/ruby#1106, tekknolagi, unassigned, no comments, no PR). The binding constant was added by hand because zjit-bindgen fails in this orb (gcc-configured build); CI's bindgen check would catch a mismatch. The release build used for numbers is be01989e4d, which differs from the head only in two accepted HIR snapshots. Comment draft in docs/upstream/zjit-shortlist.md. No review passes yet."
passes: []
---

# ZJIT: Inline String#dup on bare Strings

`String#dup` on a String whose class is exactly String and whose shape has no ivars copies it with `str_duplicate()` and doesn't call `initialize_copy` (`rb_str_dup_m`). ZJIT called it with a frame. It now guards `StringExact` and a shape without ivars, and emits the `StringCopy` that `dupstring` already uses, which calls `rb_ec_str_resurrect()` without a frame. Other receivers keep the C call, and a receiver profiled with ivars is not inlined, so the guard doesn't side-exit on every call.

Fixes Shopify/ruby#1106

`StringCopy` embeds an embedded source of any length, while `str_duplicate()` shares a buffer for embedded sources above 256 bytes; the contents, encoding and flags are the same.

A compiled loop that keeps `s.dup` of a 20-byte String (Callgrind, `--zjit-call-threshold=2`, slope over 200,000 calls, `master-aa` a second build of master):

```
master:     388 Ir per call
master-aa:  388 Ir per call
branch:     359 Ir per call
```

ZJIT stats per iteration for railsbench, lobsters, then shipit, leaving out counters that move as much between two runs of master:

```diff
-ccall_String#dup: 25,218
+ccall_String#dup: 0 (-25218)
-ccall_rb_ec_str_resurrect: 625
+ccall_rb_ec_str_resurrect: 25,852 (+25227)
```

```diff
-ccall_String#dup: 4,243
+ccall_String#dup: 43 (-4200)
-ccall_rb_ec_str_resurrect: 2,041
+ccall_rb_ec_str_resurrect: 6,202 (+4162)
```

```diff
-ccall_String#dup: 5,663
+ccall_String#dup: 12 (-5651)
-ccall_rb_ec_str_resurrect: 56
+ccall_rb_ec_str_resurrect: 5,726 (+5670)
```
