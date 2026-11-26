# lowrail-profile compare

Base: `bin/rails test test/controllers -v`. Head: `bin/rails test test/controllers -v`.

Objects per request (all, by run): base 11561.3 / 11560.4, head 11561.7 / 11560.6.

A change counts when it exceeds the noise floor: twice the larger run-to-run spread in either report and for a line at least 1.0 objects per request (warm); for an action at least 0.1% of its objects and at least 20.0. Compared: request.

**Not a gate (exit 0): no A/A pair.** The spread inside one capture misses how much invocations differ, so what this lists is a place to look. Profile the base twice and pass the second with `--aa` to gate.

## Regressions: 0

None.

## Improvements: 0

None.

Not compared: 26 actions (26 no warm value).
