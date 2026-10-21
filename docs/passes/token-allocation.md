# Production token allocation diagnosis

The dispatch-corrected token unit alone added about **32 objects/request**
on blog `GET /articles/1`, with four hits and no fallbacks. This is an
allocation diagnosis, not an instruction or latency price. The default tier,
admission, native API and the shared dispatch certificate are unchanged.

## Cause, measured rather than inferred

At `62f8a6b`, the large captured `instance_exec` block creates seven Ruby
constant-cache objects per token hit; four captured Kernel-owned
`instance_variable_get.bind_call` reads create eight method-entry objects,
and the context dispatch adds a Proc, environment and CREF. These outweigh
the enumerable objects saved by literal tag construction. No warm witness
objects are present. Merely spelling constants with `::` does not fix it.

A bounded ObjectSpace census after 200 warmups, 20 requests with GC disabled,
and separate ordinary-GC blocks (three blocks of 100 requests) gives:

| Objects/request, on minus off | Before | Final prefix/suffix split |
|---|---:|---:|
| Internal method entries (`imemo_ment`) | +32 | +24 |
| Internal constant caches | +28 | +4 |
| Environment + CREF | +8 | +8 |
| Enumerable objects, approximately | −36 | −36 |
| Ordinary-GC total, approximately | **+32** | **0** |

Before ordinary-GC blocks: off **2285.20/2285.04/2284.89**, on
**2317.60/2317.14/2317.41**. Final: off **2285.38/2284.91/2285.28**,
on **2285.84/2285.16/2285.00**. These are separate untimed processes;
the logger is fatal, explaining why absolute totals differ from bet S's
2412 → 2444 screen. All on traces have four token hits and zero fallbacks.
Do not turn the tiny final difference into an allocation win.

A component probe on the actual naturally rendered view isolates the
remaining method entries: 100 `IVAR.bind_call` reads allocate **200 method
entries**, whether captured from Object or the receiver class. The native
actual-holder predicate allocates **zero**; an empty captured context costs
three objects/call (Proc/environment/CREF). No strings, witness scans or
per-hit guard arrays explain the +32.

## Small fix, same semantics

Keep the live protection/generation/name/config prefix in the captured
native view context, and move holder/epoch checks, escaping and literal
construction back to the normal unit context. This removes six of the seven
constant-cache sites. Read `@tag_builder` literally at the same boundary in
the existing view context: stock Rails' cached `tag_builder` uses that ivar,
not an overridable `instance_variable_get`. This removes one of the four
allocating reflective reads. The config accessor remains after name
conversion and before the builder read; it is not hoisted across app code.

The other three reads remain: two run before a view context exists, and one
reads the builder's `@view_context`, not the view's ivar. An extra captured
context would cost more than the read. No new native getter, retained request
or unsafe public/reflective helper substitution is introduced. A foreign
value/builder or retired epoch still continues through an implicit `tag`
with the saved values, never regenerating or converting again.

Existing production regressions: **2 tests / 201 assertions**, strict,
zero failures/errors/skips. Independent Thermos correctness and
maintainability reviews find no introduced blocker. Those reviews are
source/semantic checks, not request or performance measurements. The fresh
pre/post cold, 192-pair, native and deopt gates are prerequisites of the
separately authorized new interpreter cohort.

The unchanged certificate **7/118** and link **2/162** strict suites also pass.
An initial Rust run is retained as **38/39**: the production-only fixture has
no test `articles` table, so facts cannot generate `Article#title`. After
preparing the test database in a separate disposable copy, the full unchanged
Rust suite passes **39+2+8**. These are separate runs, not one all-green run.

**Conclusion:** the token unit is now approximately allocation-neutral on
this endpoint. It is not a standalone allocation win. The three-unit stack
must be priced separately; no instruction saving follows from this trace.

Retained private trace archive SHA-256:
`750122f1a6d21a8ab6bc11a80aca4f8f681189d01e78c275f600265abeb0379f`.
It contains both before/final census tables, component probes, the production
and broader check logs (including the failed run), and the exact runtime diff;
no timing or Ir samples.
